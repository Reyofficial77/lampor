extends Node

signal voice_chunk_ready(b64_data: String, sample_rate: int, rms: float)
signal speaking_state_changed(local_speaking: bool, active_speakers: Dictionary)

const VOICE_SAMPLE_RATE: int = 8000
const CAPTURE_SINK_BUS_NAME: String = "VoiceMicSink"
const CAPTURE_BUS_NAME: String = "VoiceMicCapture"
const CHUNK_INTERVAL_SEC: float = 0.20
const MAX_CHUNK_SAMPLES: int = 1600
const VOICE_RMS_THRESHOLD: float = 0.0020
const VOICE_HANGOVER_SEC: float = 0.55
const PEER_SPEAK_DECAY_SEC: float = 0.65
const MIC_GAIN: float = 2.4
const PEER_BUFFER_LENGTH_SEC: float = 1.5
const CHUNK_EDGE_FADE_SAMPLES: int = 24

const ULAW_BIAS: int = 0x84
const ULAW_CLIP: int = 32635

var mic_enabled: bool = false
var local_speaking: bool = false
var local_rms: float = 0.0
var active_speakers: Dictionary = {}

var _is_headless: bool = false
var _sink_bus_idx: int = -1
var _capture_bus_idx: int = -1
var _capture_effect: AudioEffectCapture = null
var _mic_player: AudioStreamPlayer = null
var _resample_accum: float = 0.0
var _resample_sum: float = 0.0
var _resample_count: int = 0
var _pending_pcm: PackedFloat32Array = PackedFloat32Array()
var _chunk_timer: float = 0.0
var _hangover_timer: float = 0.0
var _peer_players: Dictionary = {}
var _last_emitted_local_speaking: bool = false
var _last_emitted_speaker_keys: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_is_headless = DisplayServer.get_name() == "headless"

static func _linear_to_ulaw(pcm: int) -> int:
	var sample_val: int = pcm
	var sign_bit: int = 0x80 if sample_val < 0 else 0
	if sample_val < 0:
		sample_val = -sample_val
	if sample_val > ULAW_CLIP:
		sample_val = ULAW_CLIP
	sample_val += ULAW_BIAS
	var exponent: int = 7
	var exp_mask: int = 0x4000
	while exponent > 0 and (sample_val & exp_mask) == 0:
		exponent -= 1
		exp_mask >>= 1
	var mantissa: int = (sample_val >> (exponent + 3)) & 0x0F
	return (~(sign_bit | (exponent << 4) | mantissa)) & 0xFF

static func _ulaw_to_linear(ulaw_byte: int) -> float:
	var u: int = (~ulaw_byte) & 0xFF
	var sign_bit: int = u & 0x80
	var exponent: int = (u >> 4) & 0x07
	var mantissa: int = u & 0x0F
	var sample_val: int = ((mantissa << 3) + ULAW_BIAS) << exponent
	sample_val -= ULAW_BIAS
	if sign_bit != 0:
		sample_val = -sample_val
	return clampf(float(sample_val) / 32768.0, -1.0, 1.0)

static func encode_pcm_to_ulaw_b64(samples: PackedFloat32Array) -> String:
	if samples.is_empty():
		return ""
	var buf := PackedByteArray()
	buf.resize(samples.size())
	for i: int in range(samples.size()):
		var pcm_i16: int = clampi(int(round(clampf(samples[i], -1.0, 1.0) * 32767.0)), -32768, 32767)
		buf[i] = _linear_to_ulaw(pcm_i16)
	return Marshalls.raw_to_base64(buf)

static func decode_ulaw_b64_to_pcm(b64: String) -> PackedFloat32Array:
	var cleaned: String = b64.strip_edges()
	if cleaned.is_empty():
		return PackedFloat32Array()
	var buf: PackedByteArray = Marshalls.base64_to_raw(cleaned)
	var out := PackedFloat32Array()
	out.resize(buf.size())
	for i: int in range(buf.size()):
		out[i] = _ulaw_to_linear(buf[i])
	return out

func set_mic_enabled(enabled: bool) -> bool:
	if enabled == mic_enabled:
		return mic_enabled
	if _is_headless:
		mic_enabled = enabled
		if not mic_enabled:
			_reset_local_capture_state()
		SignalBus.voice_mic_toggled.emit(mic_enabled)
		_emit_speaking_if_changed(true)
		return mic_enabled

	if enabled:
		if OS.get_name().to_lower() == "android":
			OS.request_permission("android.permission.RECORD_AUDIO")
		_ensure_capture_pipeline()
		if _capture_effect != null:
			_capture_effect.clear_buffer()
		if _mic_player != null and not _mic_player.playing:
			_mic_player.play()
		mic_enabled = true
	else:
		mic_enabled = false
		_reset_local_capture_state()
		if _mic_player != null and _mic_player.playing:
			_mic_player.stop()
		if _capture_effect != null:
			_capture_effect.clear_buffer()

	SignalBus.voice_mic_toggled.emit(mic_enabled)
	_emit_speaking_if_changed(true)
	return mic_enabled

func toggle_mic() -> bool:
	return set_mic_enabled(not mic_enabled)

func is_peer_speaking(user_id: String) -> bool:
	var uid: String = user_id.strip_edges()
	if uid.is_empty():
		return false
	return active_speakers.has(uid)

func clear_peer_audio() -> void:
	active_speakers.clear()
	for uid: Variant in _peer_players.keys():
		var player: Node = _peer_players[uid] as Node
		if is_instance_valid(player):
			player.queue_free()
	_peer_players.clear()
	_emit_speaking_if_changed(true)

func decode_and_route_peer_audio(sender_uid: String, payload: Dictionary, remote_players: Dictionary) -> void:
	var uid: String = sender_uid.strip_edges()
	if uid.is_empty():
		return
	var b64: String = str(payload.get("d", payload.get("data", ""))).strip_edges()
	if b64.is_empty():
		return
	var samples: PackedFloat32Array = decode_ulaw_b64_to_pcm(b64)
	if samples.is_empty():
		return

	active_speakers[uid] = PEER_SPEAK_DECAY_SEC
	_emit_speaking_if_changed(false)

	if _is_headless:
		return

	_push_peer_voice(uid, samples, remote_players)

func _reset_local_capture_state() -> void:
	local_speaking = false
	local_rms = 0.0
	_pending_pcm = PackedFloat32Array()
	_resample_accum = 0.0
	_resample_sum = 0.0
	_resample_count = 0
	_chunk_timer = 0.0
	_hangover_timer = 0.0

func _ensure_capture_pipeline() -> void:
	if _is_headless:
		return

	# Buat bus sink yang di-mute lebih dulu supaya index bus-nya lebih kecil
	# daripada VoiceMicCapture (syarat AudioServer.set_bus_send di Godot 4).
	_sink_bus_idx = AudioServer.get_bus_index(CAPTURE_SINK_BUS_NAME)
	if _sink_bus_idx == -1:
		_sink_bus_idx = AudioServer.bus_count
		AudioServer.add_bus(_sink_bus_idx)
		AudioServer.set_bus_name(_sink_bus_idx, CAPTURE_SINK_BUS_NAME)
		AudioServer.set_bus_send(_sink_bus_idx, &"Master")
	AudioServer.set_bus_mute(_sink_bus_idx, true)

	_capture_bus_idx = AudioServer.get_bus_index(CAPTURE_BUS_NAME)
	if _capture_bus_idx == -1:
		_capture_bus_idx = AudioServer.bus_count
		AudioServer.add_bus(_capture_bus_idx)
		AudioServer.set_bus_name(_capture_bus_idx, CAPTURE_BUS_NAME)
	# PENTING: Jangan mute bus capture secara langsung, karena di Godot 4 bus yang di-mute
	# tidak memproses AudioEffectCapture. Audio diarahkan ke sink yang di-mute + amplify -80dB.
	AudioServer.set_bus_mute(_capture_bus_idx, false)
	if _sink_bus_idx >= 0 and _sink_bus_idx < _capture_bus_idx:
		AudioServer.set_bus_send(_capture_bus_idx, StringName(CAPTURE_SINK_BUS_NAME))

	_capture_effect = null
	var has_silence_amp: bool = false
	var eff_count: int = AudioServer.get_bus_effect_count(_capture_bus_idx)
	for i: int in range(eff_count):
		var eff: AudioEffect = AudioServer.get_bus_effect(_capture_bus_idx, i)
		if eff is AudioEffectCapture and _capture_effect == null:
			_capture_effect = eff as AudioEffectCapture
		elif eff is AudioEffectAmplify:
			(eff as AudioEffectAmplify).volume_db = -80.0
			has_silence_amp = true
	if _capture_effect == null:
		_capture_effect = AudioEffectCapture.new()
		_capture_effect.buffer_length = 0.6
		AudioServer.add_bus_effect(_capture_bus_idx, _capture_effect, 0)
	if not has_silence_amp:
		var silent_amp := AudioEffectAmplify.new()
		silent_amp.volume_db = -80.0
		AudioServer.add_bus_effect(_capture_bus_idx, silent_amp)

	if not is_instance_valid(_mic_player):
		_mic_player = AudioStreamPlayer.new()
		_mic_player.name = "VoiceMicInputPlayer"
		_mic_player.stream = AudioStreamMicrophone.new()
		_mic_player.bus = StringName(CAPTURE_BUS_NAME)
		_mic_player.volume_db = 0.0
		add_child(_mic_player)

func _compute_peer_voice_volume_db(uid: String, remote_players: Dictionary) -> float:
	if remote_players.has(uid) and is_instance_valid(remote_players[uid]) and remote_players[uid] is Node3D:
		var local_pc: Node3D = GameManager.player_character as Node3D
		if is_instance_valid(local_pc):
			var dist: float = (remote_players[uid] as Node3D).global_position.distance_to(local_pc.global_position)
			return lerpf(4.0, -4.0, clampf(dist / 75.0, 0.0, 1.0))
	return 3.0

func _push_peer_voice(uid: String, samples: PackedFloat32Array, remote_players: Dictionary) -> void:
	if _is_headless or samples.is_empty():
		return
	var player: AudioStreamPlayer = _peer_players.get(uid, null) as AudioStreamPlayer
	if not is_instance_valid(player):
		player = AudioStreamPlayer.new()
		player.name = "PeerVoice_" + uid
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = float(VOICE_SAMPLE_RATE)
		gen.buffer_length = PEER_BUFFER_LENGTH_SEC
		player.stream = gen
		player.bus = &"Master"
		player.volume_db = _compute_peer_voice_volume_db(uid, remote_players)
		add_child(player)
		player.play()
		_peer_players[uid] = player
	else:
		player.volume_db = _compute_peer_voice_volume_db(uid, remote_players)
		if not player.playing:
			player.play()

	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var max_push: int = mini(playback.get_frames_available(), samples.size())
	if max_push <= 0:
		return
	var fade_len: int = mini(CHUNK_EDGE_FADE_SAMPLES, max_push / 2)
	for i: int in range(max_push):
		var s: float = samples[i]
		if fade_len > 0:
			if i < fade_len:
				s *= float(i + 1) / float(fade_len)
			elif i >= max_push - fade_len:
				s *= float(max_push - i) / float(fade_len)
		playback.push_frame(Vector2(s, s))

func _process(delta: float) -> void:
	if not active_speakers.is_empty():
		var expired: Array[String] = []
		for uid_var: Variant in active_speakers.keys():
			var uid: String = str(uid_var)
			var rem: float = float(active_speakers[uid]) - delta
			if rem <= 0.0:
				expired.append(uid)
			else:
				active_speakers[uid] = rem
		for uid: String in expired:
			active_speakers.erase(uid)

	if _is_headless:
		_emit_speaking_if_changed(false)
		return

	if mic_enabled and _capture_effect != null:
		if is_instance_valid(_mic_player) and not _mic_player.playing:
			_mic_player.play()
		var avail: int = _capture_effect.get_frames_available()
		if avail > 0:
			var frames: PackedVector2Array = _capture_effect.get_buffer(avail)
			var mix_rate: float = maxf(float(VOICE_SAMPLE_RATE), AudioServer.get_mix_rate())
			var step: float = float(VOICE_SAMPLE_RATE) / mix_rate
			var sum_sq: float = 0.0
			for i: int in range(frames.size()):
				var f: Vector2 = frames[i]
				var mono: float = clampf((f.x + f.y) * 0.5, -1.0, 1.0)
				sum_sq += mono * mono
				_resample_sum += mono
				_resample_count += 1
				_resample_accum += step
				if _resample_accum >= 1.0:
					var avg_sample: float = _resample_sum / float(maxi(1, _resample_count))
					var boosted: float = avg_sample * MIC_GAIN
					var shaped: float = clampf(boosted / (1.0 + absf(boosted) * 0.25), -1.0, 1.0)
					_pending_pcm.append(shaped)
					_resample_sum = 0.0
					_resample_count = 0
					_resample_accum -= 1.0
			local_rms = sqrt(sum_sq / float(maxi(1, frames.size())))
			if local_rms >= VOICE_RMS_THRESHOLD:
				_hangover_timer = VOICE_HANGOVER_SEC
				local_speaking = true
			else:
				_hangover_timer = maxf(0.0, _hangover_timer - delta)
				local_speaking = _hangover_timer > 0.0
		else:
			_hangover_timer = maxf(0.0, _hangover_timer - delta)
			local_speaking = _hangover_timer > 0.0
			if not local_speaking:
				local_rms = 0.0

		_chunk_timer += delta
		if _chunk_timer >= CHUNK_INTERVAL_SEC:
			_chunk_timer = 0.0
			if _pending_pcm.size() > 0:
				if local_speaking:
					var chunk: PackedFloat32Array = _pending_pcm.slice(0, MAX_CHUNK_SAMPLES) if _pending_pcm.size() > MAX_CHUNK_SAMPLES else _pending_pcm
					var b64: String = encode_pcm_to_ulaw_b64(chunk)
					if not b64.is_empty():
						voice_chunk_ready.emit(b64, VOICE_SAMPLE_RATE, snappedf(local_rms, 0.001))
				_pending_pcm = PackedFloat32Array()
	else:
		local_speaking = false
		local_rms = 0.0

	_emit_speaking_if_changed(false)

func _emit_speaking_if_changed(force: bool) -> void:
	var keys: Array = active_speakers.keys()
	keys.sort()
	var keys_sig: String = ",".join(keys)
	if force or local_speaking != _last_emitted_local_speaking or keys_sig != _last_emitted_speaker_keys:
		_last_emitted_local_speaking = local_speaking
		_last_emitted_speaker_keys = keys_sig
		speaking_state_changed.emit(local_speaking, active_speakers.duplicate())

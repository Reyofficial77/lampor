extends Node

const LocScript = preload("res://scripts/systems/Loc.gd")

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
var _awaiting_os_permission: bool = false
var _android_runtime_granted: bool = false
var _web_mic_pending: bool = false
var _web_poll_accum: float = 0.0
var _no_frame_elapsed: float = 0.0
var _tried_fallback_device: bool = false
var _no_frame_warned: bool = false
var last_permission_error: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_is_headless = DisplayServer.get_name() == "headless"
	var tree: SceneTree = get_tree()
	if tree and tree.has_signal("on_request_permissions_result"):
		tree.connect("on_request_permissions_result", _on_android_permission_result)

func _exit_tree() -> void:
	if OS.has_feature("web") and not _is_headless:
		_stop_web_mic_capture()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and _awaiting_os_permission and has_os_mic_permission():
		_awaiting_os_permission = false
		_android_runtime_granted = true
		_activate_native_capture(true)

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

func has_os_mic_permission() -> bool:
	if OS.get_name().to_lower() == "android":
		if _android_runtime_granted:
			return true
		var granted_list: PackedStringArray = OS.get_granted_permissions()
		for perm: String in granted_list:
			if perm == "android.permission.RECORD_AUDIO" or perm.ends_with("RECORD_AUDIO"):
				return true
		return false
	if OS.has_feature("web") and not _is_headless:
		return mic_enabled
	return true

func has_mic_permission() -> bool:
	return has_os_mic_permission()

func get_available_input_devices() -> PackedStringArray:
	if _is_headless:
		return PackedStringArray()
	return AudioServer.get_input_device_list()

func get_active_input_device_name() -> String:
	if _is_headless:
		return "Default"
	var active: String = AudioServer.input_device.strip_edges()
	var devices: PackedStringArray = get_available_input_devices()
	if not active.is_empty() and (devices.is_empty() or devices.has(active)):
		return active
	var saved_dev: String = SettingsManager.mic_input_device.strip_edges()
	if not saved_dev.is_empty() and devices.has(saved_dev):
		return saved_dev
	if not devices.is_empty():
		return devices[0]
	return "Default"

func _select_best_input_device(is_android: bool, exclude_device: String = "") -> String:
	var devices: PackedStringArray = AudioServer.get_input_device_list()
	var filtered: Array[String] = []
	for dev_name: String in devices:
		if exclude_device.is_empty() or dev_name != exclude_device:
			filtered.append(dev_name)
	if filtered.is_empty():
		return "Default" if is_android and exclude_device.is_empty() else ""
	var saved_dev: String = SettingsManager.mic_input_device.strip_edges()
	if not saved_dev.is_empty() and filtered.has(saved_dev):
		return saved_dev
	if exclude_device.is_empty() and filtered.has("Default"):
		return "Default"
	return filtered[0]

func _recreate_mic_player() -> void:
	if _is_headless:
		return
	if is_instance_valid(_mic_player):
		if _mic_player.playing:
			_mic_player.stop()
		_mic_player.queue_free()
		_mic_player = null
	_ensure_capture_pipeline()

func request_mic_permission_and_enable() -> String:
	last_permission_error = ""
	if _is_headless:
		set_mic_enabled(true)
		return "enabled"

	var os_name: String = OS.get_name().to_lower()
	if os_name == "android":
		if not has_os_mic_permission():
			var already_granted: bool = OS.request_permission("android.permission.RECORD_AUDIO")
			if already_granted:
				_android_runtime_granted = true
			else:
				_awaiting_os_permission = true
				return "pending_os"
		return _activate_native_capture(true)
	if OS.has_feature("web"):
		_web_mic_pending = true
		_start_web_mic_capture()
		return "pending_os"
	return _activate_native_capture(false)

func _activate_native_capture(is_android: bool) -> String:
	last_permission_error = ""
	if _is_headless:
		set_mic_enabled(true)
		return "enabled"
	var chosen: String = _select_best_input_device(is_android)
	if chosen.is_empty():
		last_permission_error = LocScript.pick("Mikrofon perangkat tidak terdeteksi.", "Device microphone not detected.")
		SignalBus.voice_mic_permission_status.emit(false, last_permission_error)
		return "no_device"
	AudioServer.input_device = chosen
	_recreate_mic_player()
	_no_frame_elapsed = 0.0
	_tried_fallback_device = false
	_no_frame_warned = false
	set_mic_enabled(true)
	SignalBus.voice_mic_permission_status.emit(true, LocScript.pick("Mikrofon aktif.", "Microphone active."))
	return "enabled"

func _start_web_mic_capture() -> void:
	if _is_headless or not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("""(function(){
		try {
			if (!window.__lamporMic) {
				function linearToUlaw(pcm) {
					var sign = pcm < 0 ? 128 : 0;
					if (pcm < 0) pcm = -pcm;
					if (pcm > 32635) pcm = 32635;
					pcm += 132;
					var exp = 7;
					var mask = 16384;
					while (exp > 0 && (pcm & mask) === 0) {
						exp--;
						mask >>= 1;
					}
					var mant = (pcm >> (exp + 3)) & 15;
					return (~(sign | (exp << 4) | mant)) & 255;
				}
				function u8ToB64(u8) {
					var bin = '';
					for (var i = 0; i < u8.length; i++) bin += String.fromCharCode(u8[i]);
					return btoa(bin);
				}
				window.__lamporMic = {
					state: 'idle',
					err: '',
					aborted: false,
					stream: null,
					ctx: null,
					proc: null,
					src: null,
					gain: null,
					chunks: [],
					pending: [],
					rAccum: 0,
					rSum: 0,
					rCount: 0,
					rms: 0,
					speaking: false,
					hangoverUntil: 0,
					lastEmit: 0,
					stop: function() {
						this.aborted = true;
						this.state = 'idle';
						this.speaking = false;
						this.rms = 0;
						this.chunks = [];
						this.pending = [];
						this.rAccum = 0;
						this.rSum = 0;
						this.rCount = 0;
						try { if (this.proc) this.proc.disconnect(); } catch (_e) {}
						try { if (this.src) this.src.disconnect(); } catch (_e) {}
						try { if (this.gain) this.gain.disconnect(); } catch (_e) {}
						this.proc = null; this.src = null; this.gain = null;
						if (this.stream && this.stream.getTracks) {
							this.stream.getTracks().forEach(function(t){ try { t.stop(); } catch (_e) {} });
						}
						this.stream = null;
						if (this.ctx && this.ctx.close) {
							try { this.ctx.close(); } catch (_e) {}
						}
						this.ctx = null;
					},
					start: function() {
						var mgr = this;
						mgr.stop();
						mgr.aborted = false;
						mgr.err = '';
						if (!navigator || !navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
							mgr.state = 'error';
							mgr.err = 'Browser does not support microphone capture (requires HTTPS).';
							return;
						}
						mgr.state = 'pending';
						navigator.mediaDevices.getUserMedia({
							audio: { echoCancellation: true, noiseSuppression: true, autoGainControl: true }
						}).then(function(stream) {
							if (mgr.aborted) {
								if (stream && stream.getTracks) {
									stream.getTracks().forEach(function(t){ try { t.stop(); } catch (_e) {} });
								}
								return;
							}
							var AC = window.AudioContext || window.webkitAudioContext;
							if (!AC) {
								mgr.state = 'error';
								mgr.err = 'AudioContext unavailable.';
								return;
							}
							var ctx = new AC();
							if (ctx.state === 'suspended' && ctx.resume) ctx.resume();
							mgr.stream = stream;
							mgr.ctx = ctx;
							mgr.src = ctx.createMediaStreamSource(stream);
							mgr.proc = ctx.createScriptProcessor(2048, 1, 1);
							mgr.gain = ctx.createGain();
							mgr.gain.gain.value = 0;
							mgr.lastEmit = performance.now();
							mgr.proc.onaudioprocess = function(ev) {
								if (mgr.state !== 'active') return;
								var data = ev.inputBuffer.getChannelData(0);
								var mixRate = Math.max(8000, ctx.sampleRate || 48000);
								var step = 8000 / mixRate;
								var sumSq = 0;
								for (var i = 0; i < data.length; i++) {
									var s = data[i];
									if (s > 1) s = 1; else if (s < -1) s = -1;
									sumSq += s * s;
									mgr.rSum += s;
									mgr.rCount += 1;
									mgr.rAccum += step;
									if (mgr.rAccum >= 1.0) {
										var avg = mgr.rSum / Math.max(1, mgr.rCount);
										var boosted = avg * 2.4;
										var shaped = boosted / (1.0 + Math.abs(boosted) * 0.25);
										if (shaped > 1) shaped = 1; else if (shaped < -1) shaped = -1;
										mgr.pending.push(shaped);
										mgr.rSum = 0;
										mgr.rCount = 0;
										mgr.rAccum -= 1.0;
									}
								}
								var frameRms = Math.sqrt(sumSq / Math.max(1, data.length));
								mgr.rms = frameRms;
								var now = performance.now();
								if (frameRms >= 0.0020) {
									mgr.hangoverUntil = now + 550;
									mgr.speaking = true;
								} else {
									mgr.speaking = now < mgr.hangoverUntil;
								}
								if (now - mgr.lastEmit >= 200 || mgr.pending.length >= 1600) {
									if (mgr.pending.length > 0 && mgr.speaking) {
										var len = Math.min(1600, mgr.pending.length);
										var u8 = new Uint8Array(len);
										for (var j = 0; j < len; j++) {
											var pcm = Math.round(mgr.pending[j] * 32767.0);
											if (pcm > 32767) pcm = 32767; else if (pcm < -32768) pcm = -32768;
											u8[j] = linearToUlaw(pcm);
										}
										if (mgr.chunks.length >= 6) mgr.chunks.shift();
										mgr.chunks.push({ d: u8ToB64(u8), rms: Math.round(mgr.rms * 1000.0) / 1000.0 });
									}
									mgr.pending = [];
									mgr.lastEmit = now;
								}
							};
							mgr.src.connect(mgr.proc);
							mgr.proc.connect(mgr.gain);
							mgr.gain.connect(ctx.destination);
							mgr.state = 'active';
						}).catch(function(err) {
							if (mgr.aborted) return;
							var n = (err && err.name) ? String(err.name) : '';
							mgr.state = (n === 'NotAllowedError' || n === 'PermissionDeniedError') ? 'denied' : 'error';
							mgr.err = (err && err.message) ? String(err.message) : n;
						});
					},
					poll: function() {
						var out = this.chunks.splice(0, this.chunks.length);
						return JSON.stringify({ state: this.state, err: this.err, rms: this.rms, spk: this.speaking, chunks: out });
					}
				};
			}
			window.__lamporMic.start();
		} catch (e) {}
	})()""")

func _stop_web_mic_capture() -> void:
	_web_mic_pending = false
	if _is_headless or not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("if (window.__lamporMic) window.__lamporMic.stop();")

func _poll_web_mic_capture() -> void:
	if _is_headless or not OS.has_feature("web"):
		return
	var raw_var: Variant = JavaScriptBridge.eval("window.__lamporMic ? window.__lamporMic.poll() : ''")
	if not (raw_var is String) or (raw_var as String).is_empty():
		return
	var parsed: Variant = JSON.parse_string(raw_var as String)
	if not (parsed is Dictionary):
		return
	var data: Dictionary = parsed as Dictionary
	var st: String = str(data.get("state", "idle"))
	if st == "active":
		if _web_mic_pending:
			_web_mic_pending = false
			mic_enabled = true
			SignalBus.voice_mic_toggled.emit(true)
			SignalBus.voice_mic_permission_status.emit(true, LocScript.pick("Mikrofon aktif.", "Microphone active."))
			_emit_speaking_if_changed(true)
		local_rms = float(data.get("rms", 0.0))
		local_speaking = bool(data.get("spk", false))
		var chunks_var: Variant = data.get("chunks", [])
		if chunks_var is Array:
			for c_var: Variant in (chunks_var as Array):
				if c_var is Dictionary:
					var c_dict: Dictionary = c_var as Dictionary
					var b64: String = str(c_dict.get("d", ""))
					if not b64.is_empty():
						voice_chunk_ready.emit(b64, VOICE_SAMPLE_RATE, snappedf(float(c_dict.get("rms", local_rms)), 0.001))
	elif st == "denied" or st == "error":
		var was_active_or_pending: bool = _web_mic_pending or mic_enabled
		_web_mic_pending = false
		if was_active_or_pending:
			mic_enabled = false
			_reset_local_capture_state()
			var err_txt: String = str(data.get("err", "")).strip_edges()
			if st == "denied":
				last_permission_error = LocScript.pick("Izin mikrofon browser ditolak. Izinkan mikrofon di pengaturan browser.", "Browser microphone permission denied. Allow microphone in browser settings.")
			else:
				last_permission_error = err_txt if not err_txt.is_empty() else LocScript.pick("Mikrofon browser tidak dapat diakses.", "Browser microphone unavailable.")
			SignalBus.voice_mic_toggled.emit(false)
			SignalBus.voice_mic_permission_status.emit(false, last_permission_error)
			_emit_speaking_if_changed(true)

func _on_android_permission_result(permission: String, granted: bool) -> void:
	if permission.ends_with("RECORD_AUDIO"):
		_awaiting_os_permission = false
		if granted:
			_android_runtime_granted = true
			if _is_headless:
				set_mic_enabled(true)
			else:
				_activate_native_capture(true)
		else:
			_android_runtime_granted = false
			last_permission_error = LocScript.pick("Izin mikrofon ditolak oleh sistem Android. Aktifkan di Pengaturan Perangkat.", "Microphone permission denied by Android. Enable it in Device Settings.")
			set_mic_enabled(false)
			SignalBus.voice_mic_permission_status.emit(false, last_permission_error)

func set_mic_enabled(enabled: bool) -> bool:
	if enabled == mic_enabled:
		return mic_enabled
	if enabled and not _is_headless:
		if OS.has_feature("web"):
			request_mic_permission_and_enable()
			return mic_enabled
		if not has_os_mic_permission():
			request_mic_permission_and_enable()
			return mic_enabled
	if _is_headless:
		mic_enabled = enabled
		if not mic_enabled:
			_reset_local_capture_state()
		SignalBus.voice_mic_toggled.emit(mic_enabled)
		_emit_speaking_if_changed(true)
		return mic_enabled

	if enabled:
		_ensure_capture_pipeline()
		if _capture_effect != null:
			_capture_effect.clear_buffer()
		if _mic_player != null and not _mic_player.playing:
			_mic_player.play()
		_no_frame_elapsed = 0.0
		_tried_fallback_device = false
		_no_frame_warned = false
		mic_enabled = true
	else:
		mic_enabled = false
		_web_mic_pending = false
		_reset_local_capture_state()
		if OS.has_feature("web"):
			_stop_web_mic_capture()
		else:
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

	if OS.has_feature("web"):
		if _web_mic_pending or mic_enabled:
			_web_poll_accum += delta
			if _web_poll_accum >= 0.05:
				_web_poll_accum = 0.0
				_poll_web_mic_capture()
		else:
			local_speaking = false
			local_rms = 0.0
		_emit_speaking_if_changed(false)
		return

	if mic_enabled and _capture_effect != null:
		if is_instance_valid(_mic_player) and not _mic_player.playing:
			_mic_player.play()
		var avail: int = _capture_effect.get_frames_available()
		if avail > 0:
			_no_frame_elapsed = 0.0
			_no_frame_warned = false
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
			_no_frame_elapsed += delta
			if _no_frame_elapsed >= 3.0 and not _tried_fallback_device:
				_tried_fallback_device = true
				_no_frame_elapsed = 0.0
				var is_and: bool = OS.get_name().to_lower() == "android"
				var alt_dev: String = _select_best_input_device(is_and, AudioServer.input_device)
				if not alt_dev.is_empty():
					AudioServer.input_device = alt_dev
					_recreate_mic_player()
					if is_instance_valid(_mic_player):
						_mic_player.play()
			elif _no_frame_elapsed >= 2.5 and _tried_fallback_device and not _no_frame_warned:
				_no_frame_warned = true
				last_permission_error = LocScript.pick("Mikrofon tidak menerima suara. Periksa izin mikrofon di Pengaturan Perangkat/OS.", "Microphone is not receiving audio. Check microphone permission in Device/OS Settings.")
				SignalBus.voice_mic_permission_status.emit(false, last_permission_error)
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

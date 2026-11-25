extends Node

# Audio Manager Singleton

var ambient_player: AudioStreamPlayer
var heartbeat_player: AudioStreamPlayer
var whisper_player: AudioStreamPlayer
var sfx_pool: Array[AudioStreamPlayer] = []
var ending_player: AudioStreamPlayer
var rooster_player: AudioStreamPlayer
var jumpscare_player: AudioStreamPlayer
var voice_player: AudioStreamPlayer
const POOL_SIZE: int = 8
const VOICE_MANIFEST_PATH: String = "res://assets/audio/voice/voice_manifest.json"

var sound_streams: Dictionary = {}
var _voice_clips_by_id: Dictionary = {}
var _voice_exact_text_to_id: Dictionary = {}
var _voice_prefix_rules: Array[Dictionary] = []
var _voice_stream_cache: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_sounds()
	_load_voice_manifest()
	_setup_audio_players()
	play_ambient()
	
	SignalBus.lampor_screamer_triggered.connect(_on_screamer)
	SignalBus.player_death_requested.connect(_on_player_death_requested)
	SignalBus.game_won.connect(_on_game_won)


func _on_player_death_requested(reason: String) -> void:
	stop_voice()
	set_heartbeat_intensity(0.0)
	set_whisper_intensity(0.0)
	# Kematian oleh Lampor memakai jumpscare.wav (dikelola GameManager),
	# jadi sting biasa hanya dimainkan untuk kematian non-Lampor (mis. fajar).
	if not GameManager.is_lampor_kill(reason):
		play_sound("game_over_sting", -2.0)

func _load_sounds() -> void:
	var sound_files: Dictionary = {
		"ambient_night": "res://assets/audio/ambient_night.wav",
		"lampor_bell": "res://assets/audio/lampor_bell.wav",
		"lampor_roar": "res://assets/audio/lampor_roar.wav",
		"footstep_dirt": "res://assets/audio/footstep_dirt.wav",
		"footstep_wood": "res://assets/audio/footstep_wood.wav",
		"heartbeat": "res://assets/audio/heartbeat.wav",
		"lighter_ignite": "res://assets/audio/lighter_ignite.wav",
		"item_pickup": "res://assets/audio/item_pickup.wav",
		"door_creak": "res://assets/audio/door_creak.wav",
		"barricade_hammer": "res://assets/audio/barricade_hammer.wav",
		"sanity_whisper": "res://assets/audio/sanity_whisper.wav",
		"victory_chime": "res://assets/audio/victory_chime.wav",
		"rooster_crow": "res://assets/audio/rooster_crow.wav",
		"azan_subuh": "res://assets/audio/azan_subuh.wav",
		"game_over_sting": "res://assets/audio/game_over_sting.wav",
		"jumpscare": "res://assets/audio/jumpscare.wav",
		"kentongan": "res://assets/audio/kentongan.wav",
		"energy_drink": "res://assets/audio/energy_drink.wav",
		"ufo_beam": "res://assets/audio/ufo_beam.wav"
	}
	
	for key: String in sound_files:
		var path: String = sound_files[key]
		if ResourceLoader.exists(path):
			var res: AudioStream = load(path)
			sound_streams[key] = res

func _setup_audio_players() -> void:
	ambient_player = AudioStreamPlayer.new()
	ambient_player.name = "AmbientPlayer"
	if sound_streams.has("ambient_night"):
		ambient_player.stream = sound_streams["ambient_night"]
	ambient_player.volume_db = -6.0
	ambient_player.finished.connect(_on_ambient_finished)
	add_child(ambient_player)
	
	heartbeat_player = AudioStreamPlayer.new()
	heartbeat_player.name = "HeartbeatPlayer"
	if sound_streams.has("heartbeat"):
		heartbeat_player.stream = sound_streams["heartbeat"]
	heartbeat_player.volume_db = -80.0
	heartbeat_player.autoplay = false
	heartbeat_player.finished.connect(func() -> void:
		if heartbeat_player.volume_db > -40.0:
			heartbeat_player.play()
	)
	add_child(heartbeat_player)
	
	whisper_player = AudioStreamPlayer.new()
	whisper_player.name = "WhisperPlayer"
	if sound_streams.has("sanity_whisper"):
		whisper_player.stream = sound_streams["sanity_whisper"]
	whisper_player.volume_db = -80.0
	whisper_player.autoplay = false
	whisper_player.finished.connect(func() -> void:
		if whisper_player.volume_db > -30.0:
			whisper_player.play()
	)
	add_child(whisper_player)
	
	# Pemutar khusus ending supaya tidak terpotong oleh SFX lain
	rooster_player = AudioStreamPlayer.new()
	rooster_player.name = "RoosterPlayer"
	add_child(rooster_player)
	ending_player = AudioStreamPlayer.new()
	ending_player.name = "EndingPlayer"
	add_child(ending_player)

	# Pemutar khusus agar audio jumpscare tidak tertimpa SFX lain dan tetap
	# berjalan ketika SceneTree dijeda selama rangkaian kematian.
	jumpscare_player = AudioStreamPlayer.new()
	jumpscare_player.name = "JumpscarePlayer"
	jumpscare_player.process_mode = Node.PROCESS_MODE_ALWAYS
	jumpscare_player.volume_db = -1.0
	add_child(jumpscare_player)

	voice_player = AudioStreamPlayer.new()
	voice_player.name = "VoicePlayer"
	voice_player.process_mode = Node.PROCESS_MODE_ALWAYS
	voice_player.volume_db = 3.5
	voice_player.finished.connect(_on_voice_finished)
	add_child(voice_player)

	for i in range(POOL_SIZE):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.name = "SFXPlayer_" + str(i)
		add_child(p)
		sfx_pool.append(p)

func play_ambient() -> void:
	if ambient_player and ambient_player.stream:
		if not ambient_player.playing:
			ambient_player.play()

func _on_ambient_finished() -> void:
	ambient_player.play()

func _get_jumpscare_stream() -> AudioStream:
	var stream: AudioStream = sound_streams.get("jumpscare") as AudioStream
	if stream == null and ResourceLoader.exists("res://assets/audio/jumpscare.wav"):
		stream = load("res://assets/audio/jumpscare.wav") as AudioStream
		if stream:
			sound_streams["jumpscare"] = stream
	return stream

func get_jumpscare_duration() -> float:
	var stream: AudioStream = _get_jumpscare_stream()
	return stream.get_length() if stream else 3.55

func play_jumpscare_and_wait() -> void:
	if jumpscare_player == null:
		push_error("JumpscarePlayer belum dibuat; tidak dapat memutar audio jumpscare.")
		await get_tree().create_timer(3.55, true).timeout
		return
	var stream: AudioStream = _get_jumpscare_stream()
	if stream == null:
		push_error("File res://assets/audio/jumpscare.wav tidak ditemukan; menggunakan jeda fallback.")
		await get_tree().create_timer(3.55, true).timeout
		return
	jumpscare_player.stop()
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
	jumpscare_player.stream = stream
	jumpscare_player.volume_db = 0.0
	jumpscare_player.pitch_scale = 1.0
	# Putar audio melalui player khusus yang tetap aktif saat game dijeda.
	# Timer berdasarkan durasi stream menjadi watchdog agar urutan kematian tidak
	# macet bila backend audio gagal mengirim sinyal finished pada perangkat tertentu.
	var duration: float = maxf(stream.get_length(), 0.1)
	jumpscare_player.play()
	await get_tree().create_timer(duration + 0.12, true, false, true).timeout
	if jumpscare_player and jumpscare_player.playing:
		jumpscare_player.stop()

func stop_jumpscare() -> void:
	if jumpscare_player and jumpscare_player.playing:
		jumpscare_player.stop()

func play_sound(sound_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not sound_streams.has(sound_name):
		return
	var stream: AudioStream = sound_streams[sound_name]
	for p: AudioStreamPlayer in sfx_pool:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.pitch_scale = pitch_scale
			p.play()
			return
	# If all busy, reuse first player
	if sfx_pool.size() > 0:
		var p: AudioStreamPlayer = sfx_pool[0]
		p.stream = stream
		p.volume_db = volume_db
		p.pitch_scale = pitch_scale
		p.play()

func stop_sound(sound_name: String) -> void:
	if not sound_streams.has(sound_name):
		return
	var stream: AudioStream = sound_streams[sound_name]
	for p: AudioStreamPlayer in sfx_pool:
		if p.playing and p.stream == stream:
			p.stop()

func set_heartbeat_intensity(intensity: float) -> void:
	# intensity from 0.0 to 1.0
	if intensity <= 0.05:
		if heartbeat_player.playing:
			heartbeat_player.stop()
		heartbeat_player.volume_db = -80.0
	else:
		heartbeat_player.volume_db = lerp(-24.0, 4.0, intensity)
		heartbeat_player.pitch_scale = lerp(0.8, 1.4, intensity)
		if not heartbeat_player.playing:
			heartbeat_player.play()

func set_whisper_intensity(intensity: float) -> void:
	if intensity <= 0.1:
		if whisper_player.playing:
			whisper_player.stop()
		whisper_player.volume_db = -80.0
	else:
		whisper_player.volume_db = lerp(-20.0, 0.0, intensity)
		if not whisper_player.playing:
			whisper_player.play()

func _on_game_won() -> void:
	# Ending baik: fajar tiba, ayam berkokok lalu azan subuh berkumandang
	if ambient_player:
		ambient_player.stop()
		ambient_player.finished.disconnect(_on_ambient_finished)
	set_heartbeat_intensity(0.0)
	set_whisper_intensity(0.0)

	play_sound("victory_chime", -6.0)
	if sound_streams.has("rooster_crow"):
		rooster_player.stream = sound_streams["rooster_crow"]
		rooster_player.volume_db = 0.0
		rooster_player.play()
	if sound_streams.has("azan_subuh"):
		await get_tree().create_timer(1.5).timeout
		ending_player.stream = sound_streams["azan_subuh"]
		ending_player.volume_db = -2.0
		ending_player.play()

func stop_ending_audio() -> void:
	stop_voice()
	if rooster_player:
		rooster_player.stop()
	if ending_player:
		ending_player.stop()
	# Ambient malam dihidupkan lagi untuk permainan berikutnya
	if ambient_player and not ambient_player.finished.is_connected(_on_ambient_finished):
		ambient_player.finished.connect(_on_ambient_finished)
	play_ambient()

func _on_screamer() -> void:
	play_sound("lampor_roar", 6.0, randf_range(0.9, 1.1))

func _load_voice_manifest() -> void:
	_voice_clips_by_id.clear()
	_voice_exact_text_to_id.clear()
	_voice_prefix_rules.clear()
	var parsed: Variant = null
	if FileAccess.file_exists(VOICE_MANIFEST_PATH):
		var fa: FileAccess = FileAccess.open(VOICE_MANIFEST_PATH, FileAccess.READ)
		if fa != null:
			parsed = JSON.parse_string(fa.get_as_text())
			fa.close()
	if not (parsed is Dictionary) and ResourceLoader.exists(VOICE_MANIFEST_PATH):
		var json_res: Resource = ResourceLoader.load(VOICE_MANIFEST_PATH)
		if json_res is JSON:
			parsed = (json_res as JSON).data
	if not (parsed is Dictionary):
		return
	var clips_raw: Variant = (parsed as Dictionary).get("clips", [])
	if not (clips_raw is Array):
		return
	for entry_raw: Variant in (clips_raw as Array):
		if not (entry_raw is Dictionary):
			continue
		var entry: Dictionary = entry_raw as Dictionary
		var clip_id: String = str(entry.get("id", "")).strip_edges()
		if clip_id.is_empty():
			continue
		_voice_clips_by_id[clip_id] = entry
		for field_name: String in ["text_id", "text_en", "tts_text_id", "tts_text_en"]:
			var raw_text: String = str(entry.get(field_name, "")).strip_edges()
			if raw_text.is_empty():
				continue
			if raw_text.contains("%"):
				var rule: Dictionary = _build_voice_template_rule(raw_text, clip_id)
				if not rule.is_empty():
					_voice_prefix_rules.append(rule)
			else:
				_voice_exact_text_to_id[raw_text] = clip_id
				var norm_raw: String = _normalize_voice_text(raw_text)
				if not _voice_exact_text_to_id.has(norm_raw):
					_voice_exact_text_to_id[norm_raw] = clip_id
	_voice_prefix_rules.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("score", 0)) > int(b.get("score", 0))
	)

func _normalize_voice_text(text_value: String) -> String:
	return text_value.strip_edges().replace("—", "-").replace("–", "-")

func _build_voice_template_rule(tpl_text: String, clip_id: String) -> Dictionary:
	var pct_pos: int = tpl_text.find("%")
	if pct_pos < 0:
		return {}
	var prefix: String = tpl_text.substr(0, pct_pos)
	var after_start: int = pct_pos + 1
	while after_start < tpl_text.length():
		var ch: String = tpl_text.substr(after_start, 1)
		after_start += 1
		if ch == "s" or ch == "d" or ch == "f":
			break
	var rest: String = tpl_text.substr(after_start)
	var next_pct: int = rest.find("%")
	var tail: String = rest.substr(0, next_pct) if next_pct >= 0 else rest
	if prefix.length() + tail.length() < 6:
		return {}
	return {
		"prefix": prefix,
		"tail": tail,
		"prefix_norm": _normalize_voice_text(prefix),
		"tail_norm": _normalize_voice_text(tail),
		"clip_id": clip_id,
		"score": prefix.length() + tail.length()
	}

func resolve_voice_clip_id_for_text(text_value: String) -> String:
	var clean_text: String = text_value.strip_edges()
	if clean_text.is_empty():
		return ""
	if _voice_exact_text_to_id.has(clean_text):
		return str(_voice_exact_text_to_id[clean_text])
	var norm_text: String = _normalize_voice_text(clean_text)
	if _voice_exact_text_to_id.has(norm_text):
		return str(_voice_exact_text_to_id[norm_text])
	for rule: Dictionary in _voice_prefix_rules:
		var prefix: String = str(rule.get("prefix", ""))
		var tail: String = str(rule.get("tail", ""))
		if (prefix.is_empty() or clean_text.begins_with(prefix)) and (tail.is_empty() or clean_text.contains(tail)) and (not prefix.is_empty() or not tail.is_empty()):
			return str(rule.get("clip_id", ""))
		var prefix_norm: String = str(rule.get("prefix_norm", ""))
		var tail_norm: String = str(rule.get("tail_norm", ""))
		if (prefix_norm.is_empty() or norm_text.begins_with(prefix_norm)) and (tail_norm.is_empty() or norm_text.contains(tail_norm)) and (not prefix_norm.is_empty() or not tail_norm.is_empty()):
			return str(rule.get("clip_id", ""))
	return ""

func resolve_voice_path(clip_id: String, gender_override: String = "", lang_override: String = "") -> String:
	if not _voice_clips_by_id.has(clip_id):
		return ""
	var entry: Dictionary = _voice_clips_by_id[clip_id] as Dictionary
	var filename: String = str(entry.get("filename", "")).strip_edges()
	if filename.is_empty():
		return ""
	var lang: String = lang_override.strip_edges().to_lower()
	if lang != "id" and lang != "en":
		lang = "en" if SettingsManager.is_en() else "id"
	var speaker: String = str(entry.get("speaker", "Narrator"))
	var role: String = "narrator"
	if speaker.begins_with("Player"):
		var raw_gender: String = gender_override.strip_edges()
		if raw_gender.is_empty():
			raw_gender = SettingsManager.character_model
		role = SettingsManager.normalize_character_model(raw_gender)
	return "res://assets/audio/voice/%s/%s/%s" % [lang, role, filename]

func _voice_candidate_paths(clip_id: String) -> Array[String]:
	if not _voice_clips_by_id.has(clip_id):
		return []
	var entry: Dictionary = _voice_clips_by_id[clip_id] as Dictionary
	var filename: String = str(entry.get("filename", "")).strip_edges()
	if filename.is_empty():
		return []
	var stem: String = filename.get_basename()
	var pref_lang: String = "en" if SettingsManager.is_en() else "id"
	var speaker: String = str(entry.get("speaker", "Narrator"))
	var is_player: bool = speaker.begins_with("Player")
	var cur_role: String = SettingsManager.normalize_character_model(SettingsManager.character_model) if is_player else "narrator"
	var alt_role: String = ("female" if cur_role == "male" else "male") if is_player else ""

	var pairs: Array[Array] = [[pref_lang, cur_role]]
	if pref_lang != "id":
		pairs.append(["id", cur_role])
	if is_player and not alt_role.is_empty():
		pairs.append(["id", alt_role])
	if cur_role != "narrator":
		pairs.append(["id", "narrator"])

	var candidates: Array[String] = []
	for pair: Array in pairs:
		var l_code: String = str(pair[0])
		var r_code: String = str(pair[1])
		for ext: String in ["wav", "mp3"]:
			var cand: String = "res://assets/audio/voice/%s/%s/%s.%s" % [l_code, r_code, stem, ext]
			if not candidates.has(cand):
				candidates.append(cand)
	return candidates

func _set_ambient_ducked(ducked: bool) -> void:
	if ambient_player:
		ambient_player.volume_db = -12.0 if ducked else -6.0

func _on_voice_finished() -> void:
	_set_ambient_ducked(false)

func play_voice_by_id(clip_id: String, volume_db: float = 3.5) -> bool:
	if voice_player == null:
		return false
	var chosen_path: String = ""
	for cand: String in _voice_candidate_paths(clip_id):
		if ResourceLoader.exists(cand):
			chosen_path = cand
			break
	if chosen_path.is_empty():
		return false
	var stream: AudioStream = _voice_stream_cache.get(chosen_path, null) as AudioStream
	if stream == null:
		stream = load(chosen_path) as AudioStream
		if stream == null:
			return false
		_voice_stream_cache[chosen_path] = stream
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = false
	voice_player.stop()
	voice_player.stream = stream
	voice_player.volume_db = volume_db
	_set_ambient_ducked(true)
	voice_player.play()
	return true

func play_voice_for_dialog_text(text_value: String, volume_db: float = 3.5) -> bool:
	var clip_id: String = resolve_voice_clip_id_for_text(text_value)
	if clip_id.is_empty():
		return false
	return play_voice_by_id(clip_id, volume_db)

func stop_voice() -> void:
	if voice_player and voice_player.playing:
		voice_player.stop()
	_set_ambient_ducked(false)

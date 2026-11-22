extends Node

# Audio Manager Singleton

var ambient_player: AudioStreamPlayer
var heartbeat_player: AudioStreamPlayer
var whisper_player: AudioStreamPlayer
var sfx_pool: Array[AudioStreamPlayer] = []
var ending_player: AudioStreamPlayer
var rooster_player: AudioStreamPlayer
var jumpscare_player: AudioStreamPlayer
const POOL_SIZE: int = 8

var sound_streams: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_sounds()
	_setup_audio_players()
	play_ambient()
	
	SignalBus.lampor_screamer_triggered.connect(_on_screamer)
	SignalBus.player_death_requested.connect(_on_player_death_requested)
	SignalBus.game_won.connect(_on_game_won)


func _on_player_death_requested(reason: String) -> void:
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
		"kentongan": "res://assets/audio/kentongan.wav"
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

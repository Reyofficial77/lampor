class_name SanitySystem
extends Node

var max_sanity: float = 100.0
var current_sanity: float = 100.0

# Sumber zona aman (obor/tungku) yang sedang melindungi pemain.
# Pakai Dictionary supaya keluar dari satu obor tidak mematikan zona aman obor lain.
var safe_sources: Dictionary = {}
var in_safe_zone: bool:
	get:
		return not safe_sources.is_empty()

var lampor_distance: float = 999.0
var is_staring_at_lampor: bool = false
var flashlight_is_on: bool = false

# Dimuat dari GameManager sesuai tingkat kesulitan
var dark_drain_light: float = 1.0
var dark_drain_dark: float = 2.5
var proximity_drain: float = 8.0
var stare_drain: float = 28.0
var safe_zone_regen: float = 12.0
var house_dark_factor: float = 1.0

func _ready() -> void:
	var cfg: Dictionary = GameManager.get_sanity_settings_for_difficulty(GameManager.selected_difficulty)
	dark_drain_light = cfg.get("dark_light", 1.0)
	dark_drain_dark = cfg.get("dark_dark", 2.5)
	proximity_drain = cfg.get("prox", 8.0)
	stare_drain = cfg.get("stare", 28.0)
	safe_zone_regen = cfg.get("regen", 12.0)
	house_dark_factor = cfg.get("house_dark", 1.0)

	SignalBus.lampor_nearby.connect(_on_lampor_nearby)
	SignalBus.lampor_stare_detected.connect(_on_lampor_stare)
	SignalBus.flashlight_toggled.connect(func(is_on: bool) -> void: flashlight_is_on = is_on)

func set_safe_source(source: Object, active: bool) -> void:
	if active:
		safe_sources[source] = true
	else:
		safe_sources.erase(source)

func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING or get_tree().paused:
		return

	var delta_sanity: float = 0.0

	if in_safe_zone:
		delta_sanity += safe_zone_regen * delta
	else:
		# Darkness drain
		var darkness_drain: float = dark_drain_light if flashlight_is_on else dark_drain_dark
		var owner_player: PlayerController = get_parent() as PlayerController
		if owner_player and owner_player.is_inside_house:
			darkness_drain *= house_dark_factor
		delta_sanity -= darkness_drain * delta

	# Lampor proximity drain
	if lampor_distance < 20.0:
		var prox_factor: float = clamp(1.0 - (lampor_distance / 20.0), 0.0, 1.0)
		delta_sanity -= prox_factor * proximity_drain * delta

	# Stare drain (heavy penalty for looking at Lampor)
	if is_staring_at_lampor:
		delta_sanity -= stare_drain * delta

	current_sanity = clamp(current_sanity + delta_sanity, 0.0, max_sanity)
	SignalBus.player_sanity_changed.emit(current_sanity, max_sanity)

	# Update audio tension
	var fear_ratio: float = 1.0 - (current_sanity / max_sanity)
	AudioManager.set_heartbeat_intensity(fear_ratio if fear_ratio > 0.4 else 0.0)
	AudioManager.set_whisper_intensity(fear_ratio if fear_ratio > 0.55 else 0.0)

	if current_sanity <= 0.0:
		SignalBus.player_death_requested.emit("Kewarasanmu hancur total karena menatap Lampor!")

func _on_lampor_nearby(dist: float) -> void:
	lampor_distance = dist

func _on_lampor_stare(intensity: float) -> void:
	is_staring_at_lampor = intensity > 0.3

func restore_sanity(amount: float) -> void:
	current_sanity = clamp(current_sanity + amount, 0.0, max_sanity)
	SignalBus.player_sanity_changed.emit(current_sanity, max_sanity)

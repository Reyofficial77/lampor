class_name SanitySystem
extends Node

const LocScript = preload("res://scripts/systems/Loc.gd")

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

var _sanity_tier: int = 0
var _sanity_dialog_cooldown: float = 0.0
var _safezone_relief_cooldown: float = 0.0
var _was_low_sanity_before_safezone: bool = false

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

func _pick_random_dialog(category: String) -> String:
	var pool: Array[String] = LocScript.dialogue_pool(category)
	if pool.is_empty():
		return ""
	return pool[randi() % pool.size()]

func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING or get_tree().paused or GameManager.is_fate_card_selection_blocking():
		return
	_sanity_dialog_cooldown = maxf(0.0, _sanity_dialog_cooldown - delta)
	_safezone_relief_cooldown = maxf(0.0, _safezone_relief_cooldown - delta)
	if "admin_god_mode" in GameManager and bool(GameManager.get("admin_god_mode")):
		if current_sanity < max_sanity:
			current_sanity = max_sanity
			SignalBus.player_sanity_changed.emit(current_sanity, max_sanity)
		AudioManager.set_heartbeat_intensity(0.0)
		AudioManager.set_whisper_intensity(0.0)
		return

	var no_drain: bool = ("sandbox_no_sanity_drain" in GameManager) and bool(GameManager.get("sandbox_no_sanity_drain"))
	var fate_sanity_regen: float = GameManager.get_fate_modifier("sanity_regen_mult", 1.0)
	var fate_sanity_drain: float = GameManager.get_fate_modifier("sanity_drain_mult", 1.0)
	var fate_stare_drain: float = GameManager.get_fate_modifier("stare_drain_mult", 1.0)
	var delta_sanity: float = 0.0

	if in_safe_zone:
		delta_sanity += safe_zone_regen * fate_sanity_regen * delta
		if _was_low_sanity_before_safezone and _safezone_relief_cooldown <= 0.0:
			_was_low_sanity_before_safezone = false
			_safezone_relief_cooldown = 32.0
			var relief_line: String = _pick_random_dialog("safezone_relief")
			if not relief_line.is_empty():
				SignalBus.dialog_requested.emit(relief_line, 3.0)
	elif not no_drain:
		# Darkness drain
		var darkness_drain: float = dark_drain_light if flashlight_is_on else dark_drain_dark
		var owner_player: PlayerController = get_parent() as PlayerController
		if owner_player and owner_player.is_inside_house:
			darkness_drain *= house_dark_factor
		delta_sanity -= darkness_drain * fate_sanity_drain * delta

	if not no_drain:
		# Lampor proximity drain
		if lampor_distance < 20.0:
			var prox_factor: float = clamp(1.0 - (lampor_distance / 20.0), 0.0, 1.0)
			delta_sanity -= prox_factor * proximity_drain * fate_sanity_drain * delta

		# Stare drain (heavy penalty for looking at Lampor)
		if is_staring_at_lampor:
			delta_sanity -= stare_drain * fate_stare_drain * delta

	current_sanity = clamp(current_sanity + delta_sanity, 0.0, max_sanity)
	SignalBus.player_sanity_changed.emit(current_sanity, max_sanity)

	if current_sanity < 50.0:
		_was_low_sanity_before_safezone = true
	elif current_sanity >= 72.0:
		_was_low_sanity_before_safezone = false
		_sanity_tier = 0

	if not in_safe_zone and current_sanity > 0.0:
		var target_tier: int = 0
		var cat: String = ""
		if current_sanity <= 18.0:
			target_tier = 3
			cat = "sanity_critical"
		elif current_sanity <= 35.0:
			target_tier = 2
			cat = "sanity_low"
		elif current_sanity <= 55.0:
			target_tier = 1
			cat = "sanity_mid"
		if target_tier > 0 and ((target_tier > _sanity_tier and _sanity_dialog_cooldown <= 4.0) or (target_tier >= 2 and _sanity_dialog_cooldown <= 0.0)):
			_sanity_tier = maxi(_sanity_tier, target_tier)
			_sanity_dialog_cooldown = 18.0
			var sanity_line: String = _pick_random_dialog(cat)
			if not sanity_line.is_empty():
				SignalBus.dialog_requested.emit(sanity_line, 3.4)

	# Update audio tension
	var fear_ratio: float = 1.0 - (current_sanity / max_sanity)
	AudioManager.set_heartbeat_intensity(fear_ratio if fear_ratio > 0.4 else 0.0)
	AudioManager.set_whisper_intensity(fear_ratio if fear_ratio > 0.55 else 0.0)

	if not no_drain and current_sanity <= 0.0:
		SignalBus.player_death_requested.emit(LocScript.pick(
			"Kewarasanmu hancur total karena menatap Lampor!",
			"Your sanity shattered completely from staring at Lampor!"
		))

func _on_lampor_nearby(dist: float) -> void:
	lampor_distance = dist

func _on_lampor_stare(intensity: float) -> void:
	is_staring_at_lampor = intensity > 0.3

func restore_sanity(amount: float) -> void:
	current_sanity = clamp(current_sanity + amount, 0.0, max_sanity)
	SignalBus.player_sanity_changed.emit(current_sanity, max_sanity)
	if current_sanity >= 65.0:
		_sanity_tier = 0

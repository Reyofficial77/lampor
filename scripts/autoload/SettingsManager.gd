extends Node

const CONFIG_PATH: String = "user://lampor_settings.cfg"
const DEFAULT_MOUSE_SENSITIVITY: float = 1.0
const DEFAULT_CAMERA_SENSITIVITY: float = 1.0
const DEFAULT_GRAPHICS_QUALITY: String = "auto"
const DEFAULT_BRIGHTNESS: float = 1.0
const DEFAULT_AUTO_UPDATE: bool = false
const DEFAULT_MOBILE_BUTTON_SCALE: float = 1.0
const DEFAULT_MOBILE_JOYSTICK_SCALE: float = 1.0

var mouse_sensitivity: float = DEFAULT_MOUSE_SENSITIVITY
var camera_sensitivity: float = DEFAULT_CAMERA_SENSITIVITY
var graphics_quality: String = DEFAULT_GRAPHICS_QUALITY
var brightness: float = DEFAULT_BRIGHTNESS
var recommended_graphics_quality: String = "medium"
var auto_update: bool = DEFAULT_AUTO_UPDATE
var mobile_button_scale: float = DEFAULT_MOBILE_BUTTON_SCALE
var mobile_joystick_scale: float = DEFAULT_MOBILE_JOYSTICK_SCALE
var mobile_joystick_position: Vector2 = Vector2(-1.0, -1.0)
var mobile_button_positions: Array = []
var _pending_graphics_apply: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	recommended_graphics_quality = _detect_recommended_graphics_quality()
	_apply_graphics_quality()
	_apply_brightness_overlay()
	get_tree().node_added.connect(_on_node_added)

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	mouse_sensitivity = clampf(float(config.get_value("controls", "mouse_sensitivity", DEFAULT_MOUSE_SENSITIVITY)), 0.25, 2.0)
	camera_sensitivity = clampf(float(config.get_value("controls", "camera_sensitivity", DEFAULT_CAMERA_SENSITIVITY)), 0.25, 2.0)
	graphics_quality = str(config.get_value("video", "graphics_quality", DEFAULT_GRAPHICS_QUALITY)).to_lower()
	if graphics_quality not in ["auto", "low", "medium", "high"]:
		graphics_quality = DEFAULT_GRAPHICS_QUALITY
	brightness = clampf(float(config.get_value("video", "brightness", DEFAULT_BRIGHTNESS)), 0.5, 1.5)
	auto_update = bool(config.get_value("update", "auto_update", DEFAULT_AUTO_UPDATE))
	mobile_button_scale = clampf(float(config.get_value("mobile", "button_scale", DEFAULT_MOBILE_BUTTON_SCALE)), 0.75, 1.5)
	mobile_joystick_scale = clampf(float(config.get_value("mobile", "joystick_scale", DEFAULT_MOBILE_JOYSTICK_SCALE)), 0.8, 1.4)
	var loaded_joystick_position: Variant = config.get_value("mobile", "joystick_position", Vector2(-1.0, -1.0))
	if loaded_joystick_position is Vector2:
		mobile_joystick_position = loaded_joystick_position
	var loaded_button_positions: Variant = config.get_value("mobile", "button_positions", [])
	if loaded_button_positions is Array:
		mobile_button_positions = loaded_button_positions.duplicate(true)

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("controls", "camera_sensitivity", camera_sensitivity)
	config.set_value("video", "graphics_quality", graphics_quality)
	config.set_value("video", "brightness", brightness)
	config.set_value("update", "auto_update", auto_update)
	config.set_value("mobile", "button_scale", mobile_button_scale)
	config.set_value("mobile", "joystick_scale", mobile_joystick_scale)
	config.set_value("mobile", "joystick_position", mobile_joystick_position)
	config.set_value("mobile", "button_positions", mobile_button_positions)
	config.save(CONFIG_PATH)

func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value, 0.25, 2.0)
	_apply_to_active_player()
	_save_settings()

func set_camera_sensitivity(value: float) -> void:
	camera_sensitivity = clampf(value, 0.25, 2.0)
	_apply_to_active_player()
	_save_settings()

func set_graphics_quality(value: String) -> void:
	var normalized: String = value.to_lower()
	if normalized not in ["auto", "low", "medium", "high"]:
		return
	graphics_quality = normalized
	_apply_graphics_quality()
	_save_settings()

func set_brightness(value: float) -> void:
	brightness = clampf(value, 0.5, 1.5)
	_apply_brightness_overlay()
	_save_settings()

func set_auto_update(enabled: bool) -> void:
	auto_update = enabled
	_save_settings()
	if auto_update:
		UpdateManager.check_for_updates(true)

func set_mobile_button_scale(value: float) -> void:
	mobile_button_scale = clampf(value, 0.75, 1.5)
	_save_settings()

func set_mobile_joystick_scale(value: float) -> void:
	mobile_joystick_scale = clampf(value, 0.8, 1.4)
	_save_settings()

func set_mobile_control_layout(joystick_position: Vector2, button_positions: Array) -> void:
	mobile_joystick_position = joystick_position
	mobile_button_positions = button_positions.duplicate(true)
	_save_settings()

func reset_mobile_control_layout() -> void:
	mobile_joystick_position = Vector2(-1.0, -1.0)
	mobile_button_positions.clear()
	mobile_button_scale = DEFAULT_MOBILE_BUTTON_SCALE
	mobile_joystick_scale = DEFAULT_MOBILE_JOYSTICK_SCALE
	_save_settings()

func apply_player_settings(player: Node) -> void:
	if not is_instance_valid(player):
		return
	# Hindari referensi class PlayerController dari autoload agar tidak membuat
	# circular dependency saat Godot memuat singleton dan skrip pemain.
	var available_properties: Dictionary = {}
	for property_info: Dictionary in player.get_property_list():
		available_properties[str(property_info.get("name", ""))] = true
	if available_properties.has("mouse_sensitivity"):
		player.set("mouse_sensitivity", 0.0025 * mouse_sensitivity)
	if available_properties.has("camera_sensitivity"):
		player.set("camera_sensitivity", 0.0025 * camera_sensitivity)

func _apply_to_active_player() -> void:
	if is_instance_valid(GameManager.player_character):
		apply_player_settings(GameManager.player_character)

func get_effective_graphics_quality() -> String:
	return recommended_graphics_quality if graphics_quality == "auto" else graphics_quality

func _detect_recommended_graphics_quality() -> String:
	var cores: int = OS.get_processor_count()
	var platform: String = OS.get_name().to_lower()
	var adapter: String = RenderingServer.get_video_adapter_name().to_lower()
	var is_mobile: bool = platform in ["android", "ios"]
	var integrated_gpu_terms: Array[String] = ["intel", "uhd", "iris", "vega", "radeon graphics", "mali", "adreno", "powervr"]
	var integrated_gpu: bool = false
	for term: String in integrated_gpu_terms:
		if adapter.contains(term):
			integrated_gpu = true
			break
	if is_mobile:
		return "low" if cores <= 4 else "medium"
	if cores <= 4 or integrated_gpu:
		return "low"
	if cores >= 8 and not integrated_gpu:
		return "high"
	return "medium"

func _apply_graphics_deferred() -> void:
	_pending_graphics_apply = false
	_apply_graphics_quality()

func _apply_graphics_quality() -> void:
	var viewport: Viewport = get_viewport()
	var effective: String = get_effective_graphics_quality()
	var is_compat: bool = RenderingServer.get_current_rendering_method() == "gl_compatibility"
	match effective:
		"low":
			viewport.scaling_3d_scale = 0.55
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			viewport.positional_shadow_atlas_size = 0
			RenderingServer.directional_shadow_atlas_set_size(256, false)
		"medium":
			viewport.scaling_3d_scale = 0.80
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED if is_compat else Viewport.SCREEN_SPACE_AA_FXAA
			viewport.positional_shadow_atlas_size = 1024
			RenderingServer.directional_shadow_atlas_set_size(1024, true)
		"high":
			viewport.scaling_3d_scale = 1.0
			viewport.msaa_3d = Viewport.MSAA_2X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED if is_compat else Viewport.SCREEN_SPACE_AA_FXAA
			viewport.positional_shadow_atlas_size = 2048
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
	_apply_scene_graphics_optimizations(effective)

func _apply_scene_graphics_optimizations(quality: String) -> void:
	var root_node: Node = get_tree().root
	if not root_node:
		return

	var horror_overlay: CanvasItem = root_node.find_child("HorrorOverlay", true, false) as CanvasItem
	if horror_overlay:
		horror_overlay.visible = (quality != "low")

	var cam_far: float = 70.0 if quality == "low" else (105.0 if quality == "medium" else 150.0)
	for cam_node: Node in root_node.find_children("*", "Camera3D", true, false):
		var cam: Camera3D = cam_node as Camera3D
		if cam:
			cam.far = cam_far

	for dir_node: Node in root_node.find_children("*", "DirectionalLight3D", true, false):
		var dlight: DirectionalLight3D = dir_node as DirectionalLight3D
		if dlight:
			dlight.shadow_enabled = (quality != "low")
			dlight.light_energy = 0.90 if quality == "low" else 0.60

	for spot_node: Node in root_node.find_children("*", "SpotLight3D", true, false):
		var slight: SpotLight3D = spot_node as SpotLight3D
		if slight:
			slight.shadow_enabled = (quality == "high")

	for omni_node: Node in root_node.find_children("ItemLight", "OmniLight3D", true, false):
		var ilight: OmniLight3D = omni_node as OmniLight3D
		if not ilight:
			continue
		var visuals_node: Node = ilight.get_parent()
		var item_node: Node = visuals_node.get_parent() if visuals_node else null
		var is_ritual: bool = item_node != null and "is_ritual_item" in item_node and bool(item_node.get("is_ritual_item"))
		var is_unlocked_ritual: bool = is_ritual and item_node is Node3D and (item_node as Node3D).visible
		if quality == "low":
			ilight.visible = is_unlocked_ritual
			if is_unlocked_ritual:
				ilight.light_energy = 0.45
		else:
			ilight.visible = true
			if is_unlocked_ritual:
				ilight.light_energy = 1.5

	for env_node: Node in root_node.find_children("*", "WorldEnvironment", true, false):
		var we: WorldEnvironment = env_node as WorldEnvironment
		if we and we.environment:
			we.environment.fog_enabled = (quality != "low")
			if quality == "low":
				we.environment.ambient_light_color = Color(0.18, 0.21, 0.28, 1.0)
				we.environment.ambient_light_energy = 1.25
			else:
				we.environment.ambient_light_color = Color(0.11, 0.13, 0.19, 1.0)
				we.environment.ambient_light_energy = 0.85
			we.environment.glow_enabled = false
			we.environment.ssao_enabled = false
			we.environment.ssil_enabled = false
			we.environment.sdfgi_enabled = false

func _apply_brightness_overlay() -> void:
	var overlay: ColorRect = get_tree().root.find_child("BrightnessOverlay", true, false) as ColorRect
	if not overlay:
		return
	overlay.visible = not is_equal_approx(brightness, 1.0)
	if brightness < 1.0:
		overlay.color = Color(0.0, 0.0, 0.0, (1.0 - brightness) * 0.72)
	else:
		overlay.color = Color(1.0, 1.0, 1.0, (brightness - 1.0) * 0.34)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_node_added(node: Node) -> void:
	if node.name == "BrightnessOverlay":
		call_deferred("_apply_brightness_overlay")
	if node is WorldEnvironment or node is DirectionalLight3D or node is Camera3D or node.name == "HorrorOverlay" or "is_ritual_item" in node:
		if not _pending_graphics_apply:
			_pending_graphics_apply = true
			call_deferred("_apply_graphics_deferred")

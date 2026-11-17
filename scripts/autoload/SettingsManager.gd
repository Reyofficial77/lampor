extends Node

const CONFIG_PATH: String = "user://lampor_settings.cfg"
const DEFAULT_MOUSE_SENSITIVITY: float = 1.0
const DEFAULT_CAMERA_SENSITIVITY: float = 1.0
const DEFAULT_GRAPHICS_QUALITY: String = "auto"
const DEFAULT_BRIGHTNESS: float = 1.0

var mouse_sensitivity: float = DEFAULT_MOUSE_SENSITIVITY
var camera_sensitivity: float = DEFAULT_CAMERA_SENSITIVITY
var graphics_quality: String = DEFAULT_GRAPHICS_QUALITY
var brightness: float = DEFAULT_BRIGHTNESS
var recommended_graphics_quality: String = "medium"

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

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("controls", "camera_sensitivity", camera_sensitivity)
	config.set_value("video", "graphics_quality", graphics_quality)
	config.set_value("video", "brightness", brightness)
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

func _apply_graphics_quality() -> void:
	var viewport: Viewport = get_viewport()
	match get_effective_graphics_quality():
		"low":
			viewport.scaling_3d_scale = 0.7
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		"medium":
			viewport.scaling_3d_scale = 0.85
			viewport.msaa_3d = Viewport.MSAA_2X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		"high":
			viewport.scaling_3d_scale = 1.0
			viewport.msaa_3d = Viewport.MSAA_4X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA

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

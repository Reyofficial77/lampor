extends Node

const LocScript = preload("res://scripts/systems/Loc.gd")

signal keybinds_changed()
signal language_changed(new_language: String)
signal character_model_changed(model_id: String)
signal graphics_quality_changed(effective_quality: String)
signal allow_friend_join_singleplayer_changed(enabled: bool)

const CONFIG_PATH: String = "user://lampor_settings.cfg"
const WEB_SETTINGS_STORAGE_KEY: String = "lampor_settings_v1"
const DEFAULT_MOUSE_SENSITIVITY: float = 1.0
const DEFAULT_CAMERA_SENSITIVITY: float = 1.0
const DEFAULT_GRAPHICS_QUALITY: String = "auto"
const DEFAULT_BRIGHTNESS: float = 1.0
const DEFAULT_AUTO_UPDATE: bool = true
const DEFAULT_MOBILE_BUTTON_SCALE: float = 1.0
const DEFAULT_MOBILE_JOYSTICK_SCALE: float = 1.0
const DEFAULT_LANGUAGE: String = "id"
const DEFAULT_CHARACTER_MODEL: String = "male"
const DEFAULT_ALLOW_FRIEND_JOIN_SINGLEPLAYER: bool = true
const CHARACTER_MODEL_PATHS: Dictionary = {
	"male": "res://assets/models/player/adult_male.glb",
	"female": "res://assets/models/player/adult_female.glb"
}
const DEFAULT_SERVER_URL: String = "https://lamporofficial.vercel.app"

const REBINDABLE_ACTIONS: Array[String] = [
	"move_forward",
	"move_backward",
	"move_left",
	"move_right",
	"sprint",
	"interact",
	"flashlight",
	"toggle_inventory",
	"drop_item",
	"slot_1",
	"slot_2",
	"slot_3",
	"slot_4",
	"slot_5"
]

const FALLBACK_KEYBINDS: Dictionary = {
	"move_forward": {"type": "key", "keycode": KEY_W},
	"move_backward": {"type": "key", "keycode": KEY_S},
	"move_left": {"type": "key", "keycode": KEY_A},
	"move_right": {"type": "key", "keycode": KEY_D},
	"sprint": {"type": "key", "keycode": KEY_SHIFT},
	"interact": {"type": "key", "keycode": KEY_E},
	"flashlight": {"type": "key", "keycode": KEY_F},
	"toggle_inventory": {"type": "key", "keycode": KEY_TAB},
	"drop_item": {"type": "key", "keycode": KEY_G},
	"slot_1": {"type": "key", "keycode": KEY_1},
	"slot_2": {"type": "key", "keycode": KEY_2},
	"slot_3": {"type": "key", "keycode": KEY_3},
	"slot_4": {"type": "key", "keycode": KEY_4},
	"slot_5": {"type": "key", "keycode": KEY_5}
}

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
var language: String = DEFAULT_LANGUAGE
var character_model: String = DEFAULT_CHARACTER_MODEL
var mic_input_device: String = "Default"
var allow_friend_join_singleplayer: bool = DEFAULT_ALLOW_FRIEND_JOIN_SINGLEPLAYER
var server_base_url: String = DEFAULT_SERVER_URL
var keybinds: Dictionary = {}
var _default_input_map_events: Dictionary = {}
var _pending_graphics_apply: bool = false
var _web_sync_pending: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_capture_default_keybinds()
	_load_settings()
	LocScript.set_language(language)
	_apply_all_keybinds()
	recommended_graphics_quality = _detect_recommended_graphics_quality()
	_apply_graphics_quality()
	_apply_brightness_overlay()
	get_tree().node_added.connect(_on_node_added)
	if OS.has_feature("web"):
		call_deferred("_schedule_web_reconcile")
	GameManager.ensure_online_managers()

func _capture_default_keybinds() -> void:
	_default_input_map_events.clear()
	keybinds.clear()
	for action: String in REBINDABLE_ACTIONS:
		var ev_list: Array = []
		if InputMap.has_action(action):
			for ev: InputEvent in InputMap.action_get_events(action):
				ev_list.append(ev.duplicate())
		_default_input_map_events[action] = ev_list
		var fallback_entry: Dictionary = FALLBACK_KEYBINDS.get(action, {"type": "key", "keycode": KEY_NONE})
		if not ev_list.is_empty():
			var serialized: Dictionary = _serialize_event(ev_list[0])
			if not serialized.is_empty():
				keybinds[action] = serialized
				continue
		keybinds[action] = fallback_entry.duplicate()

func _load_settings() -> void:
	var config := ConfigFile.new()
	var loaded_ok: bool = (config.load(CONFIG_PATH) == OK)
	if not loaded_ok and OS.has_feature("web"):
		loaded_ok = _try_restore_config_from_web_storage(config)
	if not loaded_ok:
		return
	_apply_config_values(config)

func _apply_config_values(config: ConfigFile) -> void:
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
	language = LocScript.normalize_language(str(config.get_value("general", "language", DEFAULT_LANGUAGE)))
	character_model = normalize_character_model(str(config.get_value("general", "character_model", DEFAULT_CHARACTER_MODEL)))
	mic_input_device = str(config.get_value("audio", "mic_input_device", "Default"))
	allow_friend_join_singleplayer = bool(config.get_value("multiplayer", "allow_friend_join_singleplayer", DEFAULT_ALLOW_FRIEND_JOIN_SINGLEPLAYER))
	server_base_url = DEFAULT_SERVER_URL
	_sync_server_url_to_account_manager()
	for action: String in REBINDABLE_ACTIONS:
		if config.has_section_key("keybinds", action):
			var saved_bind: Variant = config.get_value("keybinds", action, {})
			if saved_bind is Dictionary and not (saved_bind as Dictionary).is_empty():
				var normalized_bind: Dictionary = _normalize_serialized_event(saved_bind)
				if not normalized_bind.is_empty():
					keybinds[action] = normalized_bind

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("general", "language", language)
	config.set_value("general", "character_model", character_model)
	config.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("controls", "camera_sensitivity", camera_sensitivity)
	config.set_value("video", "graphics_quality", graphics_quality)
	config.set_value("video", "brightness", brightness)
	config.set_value("update", "auto_update", auto_update)
	config.set_value("mobile", "button_scale", mobile_button_scale)
	config.set_value("mobile", "joystick_scale", mobile_joystick_scale)
	config.set_value("mobile", "joystick_position", mobile_joystick_position)
	config.set_value("mobile", "button_positions", mobile_button_positions)
	config.set_value("audio", "mic_input_device", mic_input_device)
	config.set_value("multiplayer", "allow_friend_join_singleplayer", allow_friend_join_singleplayer)
	for action: String in REBINDABLE_ACTIONS:
		if keybinds.has(action):
			config.set_value("keybinds", action, keybinds[action])
	config.save(CONFIG_PATH)
	if OS.has_feature("web"):
		_mirror_config_to_web_storage(config.encode_to_text())
		_sync_web_idbfs()

func _try_restore_config_from_web_storage(config: ConfigFile) -> bool:
	if not OS.has_feature("web"):
		return false
	var js_code: String = """(function(){
		try {
			var v = window.localStorage.getItem('%s');
			if (!v) return '';
			var bytes = new TextEncoder().encode(v);
			var bin = '';
			for (var i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
			return btoa(bin);
		} catch (e) { return ''; }
	})()""" % WEB_SETTINGS_STORAGE_KEY
	var b64: Variant = JavaScriptBridge.eval(js_code)
	if not (b64 is String) or (b64 as String).is_empty():
		return false
	var decoded: String = Marshalls.base64_to_utf8(b64 as String)
	if decoded.is_empty():
		return false
	return config.parse(decoded) == OK

func _mirror_config_to_web_storage(cfg_text: String) -> void:
	if not OS.has_feature("web") or cfg_text.is_empty():
		return
	var b64: String = Marshalls.utf8_to_base64(cfg_text)
	var js_code: String = """(function(){
		try {
			var bin = atob('%s');
			var bytes = new Uint8Array(bin.length);
			for (var i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
			var txt = new TextDecoder('utf-8').decode(bytes);
			window.localStorage.setItem('%s', txt);
		} catch (e) {}
	})()""" % [b64, WEB_SETTINGS_STORAGE_KEY]
	JavaScriptBridge.eval(js_code)

func _sync_web_idbfs() -> void:
	if not OS.has_feature("web") or _web_sync_pending:
		return
	_web_sync_pending = true
	JavaScriptBridge.eval("""(function(){
		try {
			if (typeof FS !== 'undefined' && typeof FS.syncfs === 'function') {
				FS.syncfs(false, function(err){});
			}
		} catch (e) {}
	})()""")
	get_tree().create_timer(0.25, true, false, true).timeout.connect(func() -> void:
		_web_sync_pending = false
	)

func _schedule_web_reconcile() -> void:
	if not OS.has_feature("web"):
		return
	await get_tree().create_timer(0.6, true, false, true).timeout
	var disk_cfg := ConfigFile.new()
	if disk_cfg.load(CONFIG_PATH) == OK:
		_apply_config_values(disk_cfg)
		LocScript.set_language(language)
		_apply_all_keybinds()
		_apply_to_active_player()
		_apply_graphics_quality()
		_apply_brightness_overlay()
		language_changed.emit(language)
		character_model_changed.emit(character_model)
		keybinds_changed.emit()

func t(id_text: String, en_text: String) -> String:
	return LocScript.pick(id_text, en_text)

func is_en() -> bool:
	return language == LocScript.LANG_EN_US

func set_language(code: String) -> void:
	var normalized: String = LocScript.normalize_language(code)
	if language == normalized and LocScript.get_language() == normalized:
		return
	language = normalized
	LocScript.set_language(language)
	_save_settings()
	language_changed.emit(language)

func normalize_character_model(model_id: String) -> String:
	var cleaned: String = model_id.strip_edges().to_lower()
	if cleaned in ["female", "perempuan", "woman", "cewek"]:
		return "female"
	return "male"

func set_character_model(model_id: String) -> void:
	character_model = normalize_character_model(model_id)
	_save_settings()
	character_model_changed.emit(character_model)

func set_mic_input_device(device_name: String) -> void:
	var cleaned: String = device_name.strip_edges()
	mic_input_device = cleaned if not cleaned.is_empty() else "Default"
	_save_settings()

func set_allow_friend_join_singleplayer(enabled: bool) -> void:
	allow_friend_join_singleplayer = enabled
	_save_settings()
	allow_friend_join_singleplayer_changed.emit(allow_friend_join_singleplayer)

func get_character_model_path(model_id: String = "") -> String:
	var raw_id: String = character_model if model_id.strip_edges().is_empty() else model_id
	var normalized: String = normalize_character_model(raw_id)
	return str(CHARACTER_MODEL_PATHS.get(normalized, CHARACTER_MODEL_PATHS[DEFAULT_CHARACTER_MODEL]))

func _sanitize_server_url(url: String) -> String:
	var cleaned: String = url.strip_edges()
	while cleaned.ends_with("/"):
		cleaned = cleaned.left(cleaned.length() - 1)
	var lower: String = cleaned.to_lower()
	if not (lower.begins_with("http://") or lower.begins_with("https://")):
		return ""
	var scheme_end: int = cleaned.find("://")
	if scheme_end < 0:
		return ""
	var scheme: String = cleaned.left(scheme_end).to_lower()
	var rest: String = cleaned.substr(scheme_end + 3)
	if rest.is_empty() or rest.begins_with("/") or rest.contains(" ") or rest.contains("\t"):
		return ""
	return scheme + "://" + rest

func _sync_server_url_to_account_manager() -> void:
	var am: Variant = GameManager.get_account_manager(false)
	if am and "server_base_url" in am:
		am.set("server_base_url", server_base_url)

func set_server_base_url(url: String) -> String:
	var cleaned: String = _sanitize_server_url(url)
	if cleaned.is_empty():
		return ""
	server_base_url = cleaned
	_sync_server_url_to_account_manager()
	_save_settings()
	return server_base_url

func _serialize_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var ev_key: InputEventKey = event as InputEventKey
		var code: int = int(ev_key.physical_keycode) if ev_key.physical_keycode != KEY_NONE else int(ev_key.keycode)
		if code == KEY_NONE:
			return {}
		return {"type": "key", "keycode": code}
	elif event is InputEventMouseButton:
		var ev_mb: InputEventMouseButton = event as InputEventMouseButton
		if ev_mb.button_index == MOUSE_BUTTON_NONE:
			return {}
		return {"type": "mouse", "button_index": int(ev_mb.button_index)}
	return {}

func _normalize_serialized_event(entry: Dictionary) -> Dictionary:
	var entry_type: String = str(entry.get("type", "key")).to_lower()
	if entry_type == "mouse":
		var btn_idx: int = int(entry.get("button_index", MOUSE_BUTTON_NONE))
		if btn_idx <= 0:
			return {}
		return {"type": "mouse", "button_index": btn_idx}
	var keycode: int = int(entry.get("keycode", KEY_NONE))
	if keycode <= 0:
		return {}
	return {"type": "key", "keycode": keycode}

func _deserialize_event(entry: Dictionary) -> InputEvent:
	var normalized: Dictionary = _normalize_serialized_event(entry)
	if normalized.is_empty():
		return null
	if normalized["type"] == "mouse":
		var ev_mb := InputEventMouseButton.new()
		ev_mb.button_index = int(normalized["button_index"]) as MouseButton
		return ev_mb
	var ev_key := InputEventKey.new()
	var kc: int = int(normalized["keycode"])
	ev_key.physical_keycode = kc as Key
	ev_key.keycode = kc as Key
	return ev_key

func _bind_entries_match(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty():
		return false
	if str(a.get("type", "")) != str(b.get("type", "")):
		return false
	if str(a.get("type", "")) == "mouse":
		return int(a.get("button_index", -1)) == int(b.get("button_index", -2))
	return int(a.get("keycode", -1)) == int(b.get("keycode", -2))

func _apply_all_keybinds() -> void:
	for action: String in REBINDABLE_ACTIONS:
		_apply_action_keybind(action)

func _apply_action_keybind(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	var entry: Dictionary = keybinds.get(action, FALLBACK_KEYBINDS.get(action, {}))
	var ev: InputEvent = _deserialize_event(entry)
	if ev != null:
		InputMap.action_add_event(action, ev)
	var default_entry: Dictionary = {}
	if _default_input_map_events.has(action):
		var def_events: Array = _default_input_map_events[action]
		if not def_events.is_empty():
			default_entry = _serialize_event(def_events[0])
		if not def_events.is_empty() and not default_entry.is_empty() and _bind_entries_match(entry, default_entry):
			for i: int in range(1, def_events.size()):
				InputMap.action_add_event(action, (def_events[i] as InputEvent).duplicate())
		elif not def_events.is_empty():
			for i: int in range(1, def_events.size()):
				var sec_ev: InputEvent = def_events[i] as InputEvent
				if sec_ev is InputEventJoypadButton or sec_ev is InputEventJoypadMotion:
					InputMap.action_add_event(action, sec_ev.duplicate())

func rebind_action(action: String, event: InputEvent) -> bool:
	if action not in REBINDABLE_ACTIONS:
		return false
	var serialized: Dictionary = _serialize_event(event)
	if serialized.is_empty():
		return false
	var previous: Dictionary = keybinds.get(action, {}).duplicate()
	for other_action: String in REBINDABLE_ACTIONS:
		if other_action == action:
			continue
		var other_bind: Dictionary = keybinds.get(other_action, {})
		if _bind_entries_match(other_bind, serialized):
			if not previous.is_empty():
				keybinds[other_action] = previous
			break
	keybinds[action] = serialized
	_apply_all_keybinds()
	_save_settings()
	keybinds_changed.emit()
	return true

func reset_keybinds() -> void:
	for action: String in REBINDABLE_ACTIONS:
		var def_events: Array = _default_input_map_events.get(action, [])
		if not def_events.is_empty():
			var serialized: Dictionary = _serialize_event(def_events[0])
			if not serialized.is_empty():
				keybinds[action] = serialized
				continue
		keybinds[action] = (FALLBACK_KEYBINDS.get(action, {}) as Dictionary).duplicate()
	_apply_all_keybinds()
	_save_settings()
	keybinds_changed.emit()

func format_event_label(event: InputEvent) -> String:
	if event is InputEventMouseButton:
		var btn: int = (event as InputEventMouseButton).button_index
		match btn:
			MOUSE_BUTTON_LEFT: return "LMB"
			MOUSE_BUTTON_RIGHT: return "RMB"
			MOUSE_BUTTON_MIDDLE: return "MMB"
			MOUSE_BUTTON_XBUTTON1: return "MB4"
			MOUSE_BUTTON_XBUTTON2: return "MB5"
			_: return "M%d" % btn
	if event is InputEventKey:
		var ev_key: InputEventKey = event as InputEventKey
		var kc: int = int(ev_key.physical_keycode) if ev_key.physical_keycode != KEY_NONE else int(ev_key.keycode)
		match kc:
			KEY_SHIFT: return "SHIFT"
			KEY_CTRL: return "CTRL"
			KEY_ALT: return "ALT"
			KEY_TAB: return "TAB"
			KEY_SPACE: return "SPACE"
			KEY_ESCAPE: return "ESC"
			KEY_ENTER, KEY_KP_ENTER: return "ENTER"
			KEY_BACKSPACE: return "BKSP"
			KEY_UP: return "UP"
			KEY_DOWN: return "DOWN"
			KEY_LEFT: return "LEFT"
			KEY_RIGHT: return "RIGHT"
			_:
				var raw: String = OS.get_keycode_string(kc as Key).strip_edges()
				return raw.to_upper() if not raw.is_empty() else "?"
	return "?"

func get_action_key_text(action: String) -> String:
	if keybinds.has(action):
		var ev: InputEvent = _deserialize_event(keybinds[action])
		if ev != null:
			return format_event_label(ev)
	if InputMap.has_action(action):
		var events: Array = InputMap.action_get_events(action)
		if not events.is_empty():
			return format_event_label(events[0])
	return "?"

func get_move_keys_summary() -> String:
	var w: String = get_action_key_text("move_forward")
	var a: String = get_action_key_text("move_left")
	var s: String = get_action_key_text("move_backward")
	var d: String = get_action_key_text("move_right")
	if w == "W" and a == "A" and s == "S" and d == "D":
		return "WASD"
	return "%s/%s/%s/%s" % [w, a, s, d]

func is_action_hardware_pressed(action: String) -> bool:
	if not InputMap.has_action(action):
		return false
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var ev_key: InputEventKey = ev as InputEventKey
			if ev_key.physical_keycode != KEY_NONE and Input.is_physical_key_pressed(ev_key.physical_keycode):
				return true
			if ev_key.keycode != KEY_NONE and Input.is_key_pressed(ev_key.keycode):
				return true
		elif ev is InputEventMouseButton:
			if Input.is_mouse_button_pressed((ev as InputEventMouseButton).button_index):
				return true
		elif ev is InputEventJoypadButton:
			if Input.is_joy_button_pressed(0, (ev as InputEventJoypadButton).button_index):
				return true
	return false

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
	var is_mobile: bool = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or DisplayServer.is_touchscreen_available()
	match effective:
		"low":
			viewport.scaling_3d_scale = 0.55 if is_mobile else 0.68
			viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			viewport.mesh_lod_threshold = 4.0
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			viewport.positional_shadow_atlas_size = 0
			RenderingServer.directional_shadow_atlas_set_size(0, false)
		"medium":
			viewport.scaling_3d_scale = 0.85
			viewport.mesh_lod_threshold = 1.0
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED if is_compat else Viewport.SCREEN_SPACE_AA_FXAA
			viewport.positional_shadow_atlas_size = 1024
			RenderingServer.directional_shadow_atlas_set_size(1024, true)
		"high":
			viewport.scaling_3d_scale = 1.0
			viewport.mesh_lod_threshold = 1.0
			viewport.msaa_3d = Viewport.MSAA_2X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED if is_compat else Viewport.SCREEN_SPACE_AA_FXAA
			viewport.positional_shadow_atlas_size = 2048
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
	_apply_scene_graphics_optimizations(effective, is_mobile)
	graphics_quality_changed.emit(effective)

func _apply_scene_graphics_optimizations(quality: String, is_mobile: bool = false) -> void:
	var root_node: Node = get_tree().root
	if not root_node:
		return

	var is_low: bool = (quality == "low")
	var is_mobile_low: bool = is_low and is_mobile

	var horror_overlay: CanvasItem = root_node.find_child("HorrorOverlay", true, false) as CanvasItem
	if horror_overlay:
		horror_overlay.set_meta("low_quality_mode", is_low)
		horror_overlay.set_meta("mobile_low_mode", is_mobile_low)
		if horror_overlay.material is ShaderMaterial:
			var mat := horror_overlay.material as ShaderMaterial
			mat.set_shader_parameter("grain_multiplier", 0.0 if is_low else 1.0)
			mat.set_shader_parameter("fast_mode", 1.0 if is_low else 0.0)
		horror_overlay.visible = not is_low

	var cam_far: float = (58.0 if is_mobile_low else 68.0) if is_low else (105.0 if quality == "medium" else 150.0)
	for cam_node: Node in root_node.find_children("*", "Camera3D", true, false):
		var cam: Camera3D = cam_node as Camera3D
		if cam:
			cam.far = cam_far

	for dir_node: Node in root_node.find_children("*", "DirectionalLight3D", true, false):
		var dlight: DirectionalLight3D = dir_node as DirectionalLight3D
		if dlight:
			dlight.shadow_enabled = not is_low
			dlight.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if is_low else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			dlight.directional_shadow_max_distance = 55.0 if is_low else 95.0
			dlight.shadow_bias = 0.08 if is_low else 0.04
			dlight.shadow_normal_bias = 1.5 if is_low else 1.0
			dlight.light_energy = 0.55

	for spot_node: Node in root_node.find_children("*", "SpotLight3D", true, false):
		var slight: SpotLight3D = spot_node as SpotLight3D
		if slight:
			if not slight.has_meta("_base_shadow"):
				slight.set_meta("_base_shadow", slight.shadow_enabled)
			slight.shadow_enabled = (quality == "high") and bool(slight.get_meta("_base_shadow", true))
			if slight.name == "RemoteFlashlight":
				slight.spot_range = 14.0 if is_low else 30.0

	for omni_node: Node in root_node.find_children("*", "OmniLight3D", true, false):
		var olight: OmniLight3D = omni_node as OmniLight3D
		if not olight:
			continue
		if not olight.has_meta("_base_shadow"):
			olight.set_meta("_base_shadow", olight.shadow_enabled)
		if not olight.has_meta("_base_range"):
			olight.set_meta("_base_range", olight.omni_range)
		olight.shadow_enabled = false if is_low else bool(olight.get_meta("_base_shadow", false))
		var base_range: float = float(olight.get_meta("_base_range", olight.omni_range))
		olight.omni_range = minf(base_range, 9.0) if is_low else base_range
		if olight.name == "ItemLight":
			var visuals_node: Node = olight.get_parent()
			var item_node: Node = visuals_node.get_parent() if visuals_node else null
			var is_ritual: bool = item_node != null and "is_ritual_item" in item_node and bool(item_node.get("is_ritual_item"))
			var is_unlocked_ritual: bool = is_ritual and item_node is Node3D and (item_node as Node3D).visible
			olight.visible = is_unlocked_ritual if is_low else ((not is_ritual) or is_unlocked_ritual)
			olight.distance_fade_enabled = true
			olight.distance_fade_begin = 14.0 if is_low else 22.0
			olight.distance_fade_length = 5.0
			if is_unlocked_ritual:
				olight.light_energy = 1.1 if is_low else 1.5

	for mesh_node: Node in root_node.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = mesh_node as MeshInstance3D
		if mi:
			if not mi.has_meta("_base_cast_shadow"):
				mi.set_meta("_base_cast_shadow", int(mi.cast_shadow))
			if is_low:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			else:
				mi.cast_shadow = int(mi.get_meta("_base_cast_shadow", GeometryInstance3D.SHADOW_CASTING_SETTING_ON)) as GeometryInstance3D.ShadowCastingSetting

	for env_node: Node in root_node.find_children("*", "WorldEnvironment", true, false):
		var we: WorldEnvironment = env_node as WorldEnvironment
		if we and we.environment:
			if not we.has_meta("_base_bg_mode"):
				we.set_meta("_base_bg_mode", int(we.environment.background_mode))
			if is_low:
				we.environment.background_mode = Environment.BG_COLOR
				we.environment.background_color = Color(0.015, 0.02, 0.035, 1.0)
			else:
				we.environment.background_mode = int(we.get_meta("_base_bg_mode", Environment.BG_SKY)) as Environment.BGMode
			we.environment.fog_enabled = true
			we.environment.ambient_light_color = Color(0.11, 0.13, 0.19, 1.0)
			we.environment.ambient_light_energy = 0.85 if is_low else 0.80
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
	if node is WorldEnvironment or node is DirectionalLight3D or node is OmniLight3D or node is SpotLight3D or node is Camera3D or node.name == "HorrorOverlay" or "is_ritual_item" in node:
		if not _pending_graphics_apply:
			_pending_graphics_apply = true
			call_deferred("_apply_graphics_deferred")

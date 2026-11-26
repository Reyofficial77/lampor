extends Node

const LocScript = preload("res://scripts/systems/Loc.gd")
const ProfanityFilterScript = preload("res://scripts/systems/ProfanityFilter.gd")
const REMOTE_PLAYER_SCRIPT = preload("res://scripts/player/RemotePlayer.gd")
const VOICE_CHAT_SCRIPT = preload("res://scripts/systems/VoiceChatSystem.gd")

const LOBBY_POLL_INTERVAL: float = 1.0
const LOBBY_VOICE_POLL_INTERVAL: float = 0.22
const GAME_POLL_INTERVAL: float = 0.22
const GAME_POLL_INTERVAL_LOW: float = 0.35
const GAME_POLL_INTERVAL_MOBILE_LOW: float = 0.45
const MAX_PENDING_EVENTS: int = 10
const MAX_PENDING_VOICE_EVENTS: int = 4
const MAX_SYNC_EVENTS_TOTAL: int = 14
const MAX_CHAT_HISTORY: int = 80

var session_mode: String = "singleplayer"
var is_online_session: bool = false
var current_room: Dictionary = {}
var room_players: Array = []
var world_state: Dictionary = {}
var is_room_owner: bool = false
var ping_ms: int = 0
var last_event_seq: int = 0
var server_announcement: String = ""
var remote_players: Dictionary = {}
var lobby_chat_history: Array[Dictionary] = []

var _poll_elapsed: float = 0.0
var _sync_in_flight: bool = false
var _is_leaving: bool = false
var _last_room_status: String = ""
var is_friend_joinable_singleplayer: bool = false
var _pending_events: Array[Dictionary] = []
var _pending_voice_events: Array[Dictionary] = []
var voice_chat: Node = null

func _am() -> Variant:
	return GameManager.get_account_manager()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SignalBus.account_state_changed.connect(_on_account_state_changed)
	voice_chat = VOICE_CHAT_SCRIPT.new()
	voice_chat.name = "VoiceChatSystem"
	add_child(voice_chat)
	voice_chat.voice_chunk_ready.connect(_on_voice_chunk_ready)
	voice_chat.speaking_state_changed.connect(_on_voice_speaking_state_changed)

func _on_account_state_changed() -> void:
	var am: Variant = _am()
	if is_online_session and (am == null or not am.can_access_online_modes()) and not _sync_in_flight and not _is_leaving:
		var am_err: String = str(am.last_error) if am != null else ""
		var reason: String = am_err if not am_err.is_empty() else LocScript.network_error_label(401)
		reset_to_singleplayer()
		SignalBus.multiplayer_disconnected.emit(reason)

func _process(delta: float) -> void:
	var am: Variant = _am()
	if not is_online_session or am == null or not am.can_access_online_modes() or current_room.is_empty():
		return
	if _sync_in_flight or _is_leaving:
		return
	var status_str: String = str(current_room.get("status", "lobby")).to_lower()
	var eff_q: String = SettingsManager.get_effective_graphics_quality()
	var is_mobile: bool = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or DisplayServer.is_touchscreen_available()
	var game_interval: float = GAME_POLL_INTERVAL_MOBILE_LOW if (is_mobile and eff_q == "low") else (GAME_POLL_INTERVAL_LOW if eff_q == "low" else GAME_POLL_INTERVAL)
	var voice_active: bool = is_mic_enabled() or not _pending_voice_events.is_empty() or (voice_chat != null and not (voice_chat.get("active_speakers") as Dictionary).is_empty())
	var lobby_interval: float = LOBBY_VOICE_POLL_INTERVAL if voice_active else LOBBY_POLL_INTERVAL
	var interval: float = game_interval if status_str == "playing" else lobby_interval
	_poll_elapsed += delta
	if _poll_elapsed >= interval:
		_poll_elapsed = 0.0
		_sync_tick()

func check_server_health() -> Dictionary:
	var am: Variant = _am()
	if am == null:
		return {"ok": false, "status": 0, "data": {}, "message": LocScript.pick("Sistem akun tidak tersedia.", "Account system unavailable.")}
	var started_ms: int = Time.get_ticks_msec()
	var res: Dictionary = await am.api_request("GET", "/api/health", null, false)
	if bool(res.get("ok", false)):
		ping_ms = maxi(1, Time.get_ticks_msec() - started_ms)
	return res

func list_rooms(mode_filter: String = "all") -> Dictionary:
	var am: Variant = _am()
	if am == null:
		return {"ok": false, "status": 0, "data": {}, "message": LocScript.pick("Sistem akun tidak tersedia.", "Account system unavailable.")}
	var safe_mode: String = mode_filter.strip_edges().to_lower()
	if safe_mode not in ["all", "multiplayer", "sandbox"]:
		safe_mode = "all"
	var res: Dictionary = await am.api_request("GET", "/api/rooms/list?mode=" + safe_mode, null, true)
	if bool(res.get("ok", false)):
		var data: Dictionary = res.get("data", {})
		var rooms_raw: Variant = data.get("rooms", [])
		var rooms_arr: Array = rooms_raw if rooms_raw is Array else []
		SignalBus.multiplayer_rooms_updated.emit(rooms_arr)
	return res

func create_room(config: Dictionary) -> Dictionary:
	var mode_val: String = str(config.get("mode", "multiplayer")).strip_edges().to_lower()
	if mode_val not in ["multiplayer", "sandbox"]:
		mode_val = "multiplayer"
	var diff_val: String = str(config.get("difficulty", "normal")).strip_edges().to_lower()
	if diff_val not in ["easy", "normal", "hard", "nightmare"]:
		diff_val = "normal"

	var room_name: String = str(config.get("name", "Desa Lampor")).strip_edges()
	if room_name.length() < 2:
		room_name = "Desa Lampor"
	var body: Dictionary = {
		"name": room_name,
		"mode": mode_val,
		"maxPlayers": clampi(int(config.get("maxPlayers", 4)), 1, 4),
		"difficulty": diff_val,
		"canUseShopItems": bool(config.get("canUseShopItems", true))
	}
	var pwd: String = str(config.get("password", ""))
	if not pwd.is_empty():
		body["password"] = pwd
	var late_join: bool = bool(config.get("allowLateJoin", false))
	if config.get("settings") is Dictionary:
		var settings_copy: Dictionary = (config["settings"] as Dictionary).duplicate(true)
		if settings_copy.has("allowLateJoin"):
			late_join = bool(settings_copy.get("allowLateJoin", late_join))
		body["settings"] = settings_copy
	body["allowLateJoin"] = late_join

	var am: Variant = _am()
	if am == null:
		return {"ok": false, "status": 0, "data": {}, "message": LocScript.pick("Sistem akun tidak tersedia.", "Account system unavailable.")}
	var res: Dictionary = await am.api_request("POST", "/api/rooms/create", body, true)
	if bool(res.get("ok", false)):
		_apply_room_response(res.get("data", {}), true)
		is_room_owner = true
		SignalBus.multiplayer_room_updated.emit(current_room, room_players)
	return res

func join_room(room_id_or_code: String, password: String = "") -> Dictionary:
	var trimmed: String = room_id_or_code.strip_edges()
	var body: Dictionary = {}
	if trimmed.length() == 36 and trimmed.contains("-"):
		body["roomId"] = trimmed
	else:
		body["roomCode"] = trimmed.to_upper()
	if not password.is_empty():
		body["password"] = password

	var am: Variant = _am()
	if am == null:
		return {"ok": false, "status": 0, "data": {}, "message": LocScript.pick("Sistem akun tidak tersedia.", "Account system unavailable.")}
	var res: Dictionary = await am.api_request("POST", "/api/rooms/join", body, true)
	if bool(res.get("ok", false)):
		_apply_room_response(res.get("data", {}), true)
		SignalBus.multiplayer_room_updated.emit(current_room, room_players)
		if str(current_room.get("status", "lobby")).to_lower() == "playing":
			SignalBus.multiplayer_game_started.emit(current_room)
	return res

func leave_room() -> void:
	if _is_leaving:
		return
	var am: Variant = _am()
	var room_id: String = _get_current_room_id()
	var should_notify_server: bool = is_online_session and not room_id.is_empty() and am != null and am.can_access_online_modes()
	_is_leaving = true
	reset_to_singleplayer()
	if should_notify_server and am != null:
		await am.api_request("POST", "/api/rooms/leave", {"roomId": room_id}, true)
	_is_leaving = false

func set_ready(ready: bool) -> Dictionary:
	var am: Variant = _am()
	if am == null:
		return {"ok": false, "status": 0, "data": {}, "message": LocScript.pick("Sistem akun tidak tersedia.", "Account system unavailable.")}
	var room_id: String = _get_current_room_id()
	if room_id.is_empty():
		return {"ok": false, "status": 0, "data": {}, "message": LocScript.pick("Tidak sedang berada di room.", "Not currently in a room.")}
	var res: Dictionary = await am.api_request("POST", "/api/rooms/ready", {"roomId": room_id, "isReady": ready}, true)
	if bool(res.get("ok", false)):
		_apply_room_response(res.get("data", {}), false)
		SignalBus.multiplayer_room_updated.emit(current_room, room_players)
	return res

func start_room_game() -> Dictionary:
	var am: Variant = _am()
	if am == null:
		return {"ok": false, "status": 0, "data": {}, "message": LocScript.pick("Sistem akun tidak tersedia.", "Account system unavailable.")}
	var room_id: String = _get_current_room_id()
	if room_id.is_empty():
		return {"ok": false, "status": 0, "data": {}, "message": LocScript.pick("Tidak sedang berada di room.", "Not currently in a room.")}
	var res: Dictionary = await am.api_request("POST", "/api/rooms/start", {"roomId": room_id}, true)
	if bool(res.get("ok", false)):
		var prev_status: String = _last_room_status
		_apply_room_response(res.get("data", {}), false)
		SignalBus.multiplayer_room_updated.emit(current_room, room_players)
		if prev_status != "playing" and str(current_room.get("status", "")).to_lower() == "playing":
			SignalBus.multiplayer_game_started.emit(current_room)
	return res

func kick_player(target_user_id: String) -> Dictionary:
	var am: Variant = _am()
	if am == null:
		return {"ok": false, "status": 0, "data": {}, "message": LocScript.pick("Sistem akun tidak tersedia.", "Account system unavailable.")}
	var room_id: String = _get_current_room_id()
	if room_id.is_empty():
		return {"ok": false, "status": 0, "data": {}, "message": LocScript.pick("Tidak sedang berada di room.", "Not currently in a room.")}
	var res: Dictionary = await am.api_request("POST", "/api/rooms/kick", {"roomId": room_id, "targetUserId": target_user_id}, true)
	if bool(res.get("ok", false)):
		_apply_room_response(res.get("data", {}), false)
		SignalBus.multiplayer_room_updated.emit(current_room, room_players)
	return res

func push_event(event_type: String, payload: Dictionary = {}) -> void:
	if not is_online_session or _get_current_room_id().is_empty():
		return
	if _pending_events.size() >= MAX_PENDING_EVENTS:
		_pending_events.remove_at(0)
	_pending_events.append({
		"type": event_type,
		"payload": payload.duplicate(true)
	})

func send_chat_message(text: String) -> void:
	var cleaned: String = ProfanityFilterScript.censor(text.strip_edges())
	if cleaned.is_empty():
		return
	if cleaned.length() > 300:
		cleaned = cleaned.left(300)
	push_event("chat", {"text": cleaned})
	_poll_elapsed = LOBBY_POLL_INTERVAL

func send_sandbox_command(cmd: String, params: Dictionary = {}) -> void:
	push_event("sandbox_cmd", {
		"cmd": cmd,
		"params": params.duplicate(true)
	})
	_poll_elapsed = GAME_POLL_INTERVAL

func can_use_shop_items() -> bool:
	if not is_online_session:
		return true
	return bool(current_room.get("canUseShopItems", current_room.get("can_use_shop_items", true)))

func get_room_setting(key: String, default_val: Variant) -> Variant:
	var settings_raw: Variant = current_room.get("settings", {})
	if settings_raw is Dictionary and (settings_raw as Dictionary).has(key):
		return (settings_raw as Dictionary).get(key, default_val)
	if current_room.has(key):
		return current_room.get(key, default_val)
	return default_val

func is_mic_enabled() -> bool:
	return voice_chat != null and bool(voice_chat.get("mic_enabled"))

func set_mic_enabled(enabled: bool) -> bool:
	if voice_chat == null:
		return false
	return bool(voice_chat.call("set_mic_enabled", enabled))

func toggle_mic() -> bool:
	if voice_chat == null:
		return false
	return bool(voice_chat.call("toggle_mic"))

func has_mic_permission() -> bool:
	return voice_chat != null and bool(voice_chat.call("has_mic_permission"))

func request_mic_permission_and_enable() -> String:
	if voice_chat == null:
		return "unavailable"
	return str(voice_chat.call("request_mic_permission_and_enable"))

func confirm_mic_permission_grant() -> String:
	if voice_chat == null:
		return "unavailable"
	return str(voice_chat.call("confirm_mic_permission_grant"))

func deny_mic_permission() -> void:
	if voice_chat != null:
		voice_chat.call("deny_mic_permission")

func get_active_mic_device_name() -> String:
	if voice_chat == null:
		return "Default"
	return str(voice_chat.call("get_active_input_device_name"))

func is_local_speaking() -> bool:
	return voice_chat != null and bool(voice_chat.get("local_speaking"))

func is_peer_speaking(user_id: String) -> bool:
	if voice_chat == null:
		return false
	return bool(voice_chat.call("is_peer_speaking", user_id))

func _on_voice_chunk_ready(b64_data: String, sample_rate: int, rms: float) -> void:
	if not is_online_session or _get_current_room_id().is_empty():
		return
	if _pending_voice_events.size() >= MAX_PENDING_VOICE_EVENTS:
		_pending_voice_events.remove_at(0)
	_pending_voice_events.append({
		"type": "voice",
		"payload": {
			"d": b64_data,
			"sr": sample_rate,
			"rms": rms
		}
	})
	if _poll_elapsed >= 0.18 and not _sync_in_flight:
		_poll_elapsed = 1.0

func _on_voice_speaking_state_changed(local_spk: bool, active_spk: Dictionary) -> void:
	SignalBus.voice_activity_updated.emit(local_spk, active_spk)

func reset_to_singleplayer() -> void:
	if voice_chat != null:
		voice_chat.call("set_mic_enabled", false)
		voice_chat.call("clear_peer_audio")
	_pending_voice_events.clear()
	_clear_remote_players()
	current_room.clear()
	room_players.clear()
	world_state.clear()
	lobby_chat_history.clear()
	_pending_events.clear()
	session_mode = "singleplayer"
	is_online_session = false
	is_room_owner = false
	is_friend_joinable_singleplayer = false
	ping_ms = 0
	last_event_seq = 0
	server_announcement = ""
	_poll_elapsed = 0.0
	_sync_in_flight = false
	_last_room_status = ""

func has_remote_peers_joined() -> bool:
	return room_players.size() > 1 or not remote_players.is_empty()

func open_singleplayer_for_friends(difficulty_str: String, initial_act: int = 1, furnace_burning_val: bool = false) -> Dictionary:
	if DisplayServer.get_name() == "headless":
		return {"ok": false, "skipped": true}
	if not SettingsManager.allow_friend_join_singleplayer:
		return {"ok": false, "skipped": true}
	if GameManager.is_tutorial_mode or GameManager.is_sandbox_mode:
		return {"ok": false, "skipped": true}
	if initial_act >= 3 or furnace_burning_val:
		return {"ok": false, "skipped": true}
	var am: Variant = _am()
	if am == null or not am.can_access_online_modes():
		return {"ok": false, "skipped": true}
	if is_online_session:
		return {"ok": true, "alreadyOpen": true}

	var diff_norm: String = difficulty_str.strip_edges().to_lower()
	if diff_norm not in ["easy", "normal", "hard", "nightmare"]:
		diff_norm = "normal"
	var disp_name: String = str(am.call("get_effective_display_name")) if am.has_method("get_effective_display_name") else str(am.get("username"))
	if disp_name.strip_edges().is_empty():
		disp_name = "Pemain"

	var body: Dictionary = {
		"name": ("Solo " + disp_name).left(40),
		"mode": "multiplayer",
		"maxPlayers": 4,
		"difficulty": diff_norm,
		"canUseShopItems": true,
		"allowLateJoin": true,
		"friendsOnly": true,
		"startImmediately": true,
		"initialWorldState": {
			"act": clampi(initial_act, 1, 3),
			"furnaceBurning": furnace_burning_val,
			"hour": GameManager.current_hour,
			"minute": GameManager.current_minute
		}
	}
	var res: Dictionary = await am.api_request("POST", "/api/rooms/create", body, true)
	if not bool(res.get("ok", false)):
		return res
	var data: Dictionary = res.get("data", {})
	_apply_room_response(data, true)
	if GameManager.current_state != GameManager.GameState.PLAYING or GameManager.is_sandbox_mode or GameManager.is_tutorial_mode or not SettingsManager.allow_friend_join_singleplayer:
		await leave_room()
		return {"ok": false, "cancelled": true}
	is_online_session = true
	is_room_owner = true
	session_mode = "multiplayer"
	is_friend_joinable_singleplayer = true
	_last_room_status = "playing"
	SignalBus.multiplayer_room_updated.emit(current_room, room_players)
	return res

func close_singleplayer_for_friends_if_solo() -> void:
	if is_online_session and is_friend_joinable_singleplayer and not has_remote_peers_joined():
		await leave_room()

func _get_current_room_id() -> String:
	return str(current_room.get("id", current_room.get("roomId", ""))).strip_edges()

func _apply_room_response(data: Dictionary, is_new_session: bool) -> void:
	if data.get("room") is Dictionary:
		current_room = (data["room"] as Dictionary).duplicate(true)
	if data.get("players") is Array:
		room_players = (data["players"] as Array).duplicate(true)
	if data.get("worldState") is Dictionary:
		world_state = (data["worldState"] as Dictionary).duplicate(true)
	elif is_new_session and current_room.get("worldState") is Dictionary:
		world_state = (current_room["worldState"] as Dictionary).duplicate(true)
	if data.has("announcement"):
		server_announcement = str(data.get("announcement", ""))

	var host_uid: String = str(current_room.get("hostUserId", current_room.get("host_user_id", ""))).strip_edges().to_lower()
	var host_uname: String = str(current_room.get("hostUsername", current_room.get("host_username", ""))).strip_edges().to_lower()
	var am: Variant = _am()
	var my_uid: String = str(am.user_id).strip_edges().to_lower() if am != null else ""
	var my_uname: String = str(am.username).strip_edges().to_lower() if am != null else ""
	var owner_match: bool = false
	if not my_uid.is_empty() and not host_uid.is_empty() and host_uid == my_uid:
		owner_match = true
	elif not my_uname.is_empty() and not host_uname.is_empty() and host_uname == my_uname:
		owner_match = true
	else:
		for p_item: Variant in room_players:
			if p_item is Dictionary:
				var pd: Dictionary = p_item as Dictionary
				var p_uid: String = str(pd.get("userId", pd.get("user_id", pd.get("id", "")))).strip_edges().to_lower()
				var p_uname: String = str(pd.get("username", "")).strip_edges().to_lower()
				if ((not my_uid.is_empty() and p_uid == my_uid) or (not my_uname.is_empty() and p_uname == my_uname)) and bool(pd.get("isHost", pd.get("is_host", false))):
					owner_match = true
					break
	if not owner_match and host_uid.is_empty() and host_uname.is_empty() and is_room_owner:
		owner_match = true
	is_room_owner = owner_match
	is_online_session = not current_room.is_empty()
	session_mode = str(current_room.get("mode", "multiplayer")).strip_edges().to_lower()
	if session_mode == "sandbox" and is_online_session and not GameManager.is_sandbox_mode:
		GameManager.is_sandbox_mode = true
	_last_room_status = str(current_room.get("status", "lobby")).strip_edges().to_lower()

	if is_new_session:
		lobby_chat_history.clear()
		_pending_events.clear()
		last_event_seq = int(data.get("lastEventSeq", current_room.get("lastEventSeq", 0)))
		_poll_elapsed = 0.0

func _collect_local_player_state() -> Dictionary:
	var pc: Node = GameManager.player_character
	if not is_instance_valid(pc) or not (pc is Node3D):
		return {}
	var pc_3d: Node3D = pc as Node3D
	var pos: Vector3 = pc_3d.global_position
	var rot_y: float = pc_3d.rotation.y
	var head_node: Node3D = pc.get("head") as Node3D
	var pitch: float = head_node.rotation.x if is_instance_valid(head_node) else 0.0
	var anim_name: String = str(pc.get("current_anim_name")) if "current_anim_name" in pc else "idle"
	if anim_name.is_empty():
		anim_name = "idle"
	var flash_on: bool = bool(pc.get("flashlight_on")) if "flashlight_on" in pc else false
	var eq_item: String = str(pc.get("equipped_item_id")) if "equipped_item_id" in pc else ""
	var sanity_val: float = 100.0
	var sanity_sys: Node = pc.get("sanity_system") as Node
	if is_instance_valid(sanity_sys) and "current_sanity" in sanity_sys:
		sanity_val = float(sanity_sys.get("current_sanity"))
	var hiding: bool = bool(pc.get("is_hiding")) if "is_hiding" in pc else false
	var caught: bool = bool(pc.get("is_caught")) if "is_caught" in pc else false

	return {
		"pos": [snappedf(pos.x, 0.001), snappedf(pos.y, 0.001), snappedf(pos.z, 0.001)],
		"rotY": snappedf(rot_y, 0.001),
		"pitch": snappedf(pitch, 0.001),
		"anim": anim_name,
		"flashlightOn": flash_on,
		"equippedItem": eq_item,
		"character": SettingsManager.character_model,
		"sanity": snappedf(sanity_val, 0.1),
		"isHiding": hiding,
		"isAlive": not caught,
		"micOn": is_mic_enabled(),
		"speaking": is_local_speaking()
	}

func _collect_owner_world_state() -> Dictionary:
	var lampor_dict: Dictionary = {"pos": [0.0, 45.0, 0.0], "rotY": 0.0, "state": 0}
	var lampor_nodes: Array[Node] = get_tree().get_nodes_in_group("lampor")
	if not lampor_nodes.is_empty() and lampor_nodes[0] is Node3D:
		var ln: Node3D = lampor_nodes[0] as Node3D
		var l_state: int = int(ln.get("current_state")) if "current_state" in ln else 0
		lampor_dict = {
			"pos": [snappedf(ln.global_position.x, 0.001), snappedf(ln.global_position.y, 0.001), snappedf(ln.global_position.z, 0.001)],
			"rotY": snappedf(ln.rotation.y, 0.001),
			"state": l_state
		}

	var freeze_lampor: bool = bool(GameManager.get("sandbox_freeze_lampor")) if "sandbox_freeze_lampor" in GameManager else false
	var pause_clock: bool = bool(GameManager.get("sandbox_pause_clock")) if "sandbox_pause_clock" in GameManager else false
	var fog_enabled: bool = bool(GameManager.get("sandbox_fog_enabled")) if "sandbox_fog_enabled" in GameManager else true

	return {
		"hour": GameManager.current_hour,
		"minute": GameManager.current_minute,
		"act": GameManager.get_current_act_number(),
		"torchesLit": GameManager.torches_lit,
		"doorsBarricaded": GameManager.doors_barricaded,
		"furnaceBurning": GameManager.furnace_burning,
		"furnaceTimeLeft": snappedf(GameManager.furnace_time_left, 0.1),
		"ritualItems": GameManager.ritual_items.duplicate(true),
		"lampor": lampor_dict,
		"sandbox": {
			"freezeLampor": freeze_lampor,
			"pauseClock": pause_clock,
			"fogEnabled": fog_enabled
		}
	}

func _sync_tick() -> void:
	var am: Variant = _am()
	if _sync_in_flight or _is_leaving or not is_online_session or am == null or not am.can_access_online_modes():
		return
	var active_room_id: String = _get_current_room_id()
	if active_room_id.is_empty():
		return

	_sync_in_flight = true
	var events_to_send: Array = _pending_events.slice(0, MAX_PENDING_EVENTS)
	for _i: int in range(events_to_send.size()):
		_pending_events.remove_at(0)
	var voice_cap: int = mini(MAX_PENDING_VOICE_EVENTS, MAX_SYNC_EVENTS_TOTAL - events_to_send.size())
	var voice_to_send: Array = _pending_voice_events.slice(0, maxi(0, voice_cap))
	for _j: int in range(voice_to_send.size()):
		_pending_voice_events.remove_at(0)
	events_to_send.append_array(voice_to_send)
	var body: Dictionary = {
		"roomId": active_room_id,
		"lastEventSeq": last_event_seq
	}
	if not events_to_send.is_empty():
		body["events"] = events_to_send

	var in_village: bool = GameManager.is_in_active_gameplay()
	if in_village:
		var pstate: Dictionary = _collect_local_player_state()
		if not pstate.is_empty():
			body["playerState"] = pstate
		if is_room_owner:
			body["worldState"] = _collect_owner_world_state()

	var started_ms: int = Time.get_ticks_msec()
	var res: Dictionary = await am.api_request("POST", "/api/rooms/sync", body, true)
	_sync_in_flight = false

	if _is_leaving or not is_online_session or _get_current_room_id() != active_room_id:
		return

	var status_code: int = int(res.get("status", 0))
	if status_code == 401 or status_code == 403 or status_code == 410:
		var reason: String = str(res.get("message", "")).strip_edges()
		if reason.is_empty():
			reason = LocScript.network_error_label(status_code)
		reset_to_singleplayer()
		SignalBus.multiplayer_disconnected.emit(reason)
		return

	if not bool(res.get("ok", false)):
		# Re-queue unsent non-voice events ahead of newly queued ones, keeping cap at MAX_PENDING_EVENTS.
		var restored: Array[Dictionary] = []
		for ev_item: Variant in events_to_send:
			if ev_item is Dictionary and str((ev_item as Dictionary).get("type", "")) != "voice":
				restored.append(ev_item as Dictionary)
		restored.append_array(_pending_events)
		if restored.size() > MAX_PENDING_EVENTS:
			restored = restored.slice(restored.size() - MAX_PENDING_EVENTS)
		_pending_events = restored
		return

	ping_ms = maxi(1, Time.get_ticks_msec() - started_ms)
	var data: Dictionary = res.get("data", {})
	if data.get("user") is Dictionary and am.has_method("apply_live_server_user"):
		am.call("apply_live_server_user", data["user"])
	var prev_status: String = _last_room_status
	var prev_seq: int = last_event_seq

	_apply_room_response(data, false)
	SignalBus.multiplayer_room_updated.emit(current_room, room_players)

	var new_status: String = str(current_room.get("status", "")).to_lower()
	if prev_status == "lobby" and new_status == "playing":
		SignalBus.multiplayer_game_started.emit(current_room)

	var raw_events: Variant = data.get("events", [])
	if raw_events is Array:
		for ev: Variant in (raw_events as Array):
			if not ev is Dictionary:
				continue
			var ev_dict: Dictionary = ev as Dictionary
			var ev_seq: int = int(ev_dict.get("seq", ev_dict.get("id", 0)))
			if ev_seq > 0 and ev_seq <= prev_seq:
				continue
			if ev_seq > last_event_seq:
				last_event_seq = ev_seq
			var ev_type: String = str(ev_dict.get("type", ev_dict.get("eventType", "")))
			var raw_payload: Variant = ev_dict.get("payload", {})
			var ev_payload: Dictionary = raw_payload if raw_payload is Dictionary else {}
			var sender_name: String = ProfanityFilterScript.censor(str(ev_dict.get("senderUsername", ev_dict.get("senderName", ev_dict.get("username", "")))))
			if ev_type == "chat":
				var chat_txt: String = ProfanityFilterScript.censor(str(ev_payload.get("text", "")))
				var sender_v: bool = bool(ev_dict.get("senderIsVerified", ev_payload.get("senderIsVerified", false)))
				lobby_chat_history.append({
					"seq": ev_seq,
					"sender": sender_name,
					"is_verified": sender_v,
					"text": chat_txt,
					"time": str(ev_dict.get("createdAt", ""))
				})
				if lobby_chat_history.size() > MAX_CHAT_HISTORY:
					lobby_chat_history.remove_at(0)
			elif ev_type == "voice":
				var sender_uid: String = str(ev_dict.get("senderUserId", ev_dict.get("sender_user_id", ev_dict.get("senderId", ev_dict.get("userId", ""))))).strip_edges()
				var my_uid_str: String = str(am.user_id).strip_edges() if am != null else ""
				if not sender_uid.is_empty() and sender_uid.to_lower() != my_uid_str.to_lower() and voice_chat != null:
					voice_chat.call("decode_and_route_peer_audio", sender_uid, ev_payload, remote_players)
			SignalBus.multiplayer_event_received.emit(ev_type, ev_payload, sender_name)

	if data.has("lastEventSeq"):
		last_event_seq = maxi(last_event_seq, int(data.get("lastEventSeq", last_event_seq)))

	_sync_remote_players()

func _clear_remote_players() -> void:
	for uid: Variant in remote_players.keys():
		var rp: Node = remote_players[uid] as Node
		if is_instance_valid(rp):
			rp.queue_free()
	remote_players.clear()

func _sync_remote_players() -> void:
	if not GameManager.is_in_active_gameplay():
		if not remote_players.is_empty():
			_clear_remote_players()
		return

	var world_root: Node = get_tree().current_scene
	if world_root == null:
		return

	var active_remote_ids: Dictionary = {}
	var host_uid: String = str(current_room.get("hostUserId", current_room.get("host_user_id", "")))
	var am: Variant = _am()
	var my_uid: String = str(am.user_id) if am != null else ""

	for p: Variant in room_players:
		if not p is Dictionary:
			continue
		var p_dict: Dictionary = p as Dictionary
		var uid: String = str(p_dict.get("userId", p_dict.get("user_id", p_dict.get("id", "")))).strip_edges()
		if uid.is_empty() or uid == my_uid:
			continue
		active_remote_ids[uid] = true

		var rp: Node3D = remote_players.get(uid, null) as Node3D
		if not is_instance_valid(rp) or rp.get_parent() != world_root:
			if is_instance_valid(rp):
				rp.queue_free()
			rp = REMOTE_PLAYER_SCRIPT.new() as Node3D
			rp.name = "RemotePlayer_" + uid
			world_root.add_child(rp)
			remote_players[uid] = rp

		var raw_state: Variant = p_dict.get("playerState", p_dict.get("state", {}))
		var merged_state: Dictionary = (raw_state as Dictionary).duplicate(true) if raw_state is Dictionary else {}
		merged_state["userId"] = uid
		merged_state["username"] = ProfanityFilterScript.censor(str(p_dict.get("username", "Player")))
		merged_state["isHost"] = bool(p_dict.get("isHost", not host_uid.is_empty() and uid.to_lower() == host_uid.to_lower()))
		merged_state["isVerified"] = bool(p_dict.get("isVerified", p_dict.get("is_verified", false)))
		if rp.has_method("apply_network_state"):
			rp.call("apply_network_state", merged_state)

	var stale_uids: Array = []
	for existing_uid: Variant in remote_players.keys():
		if not active_remote_ids.has(existing_uid):
			stale_uids.append(existing_uid)
	for stale_uid: Variant in stale_uids:
		var old_rp: Node = remote_players[stale_uid] as Node
		if is_instance_valid(old_rp):
			old_rp.queue_free()
		remote_players.erase(stale_uid)

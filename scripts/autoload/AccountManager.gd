extends Node

const LocScript = preload("res://scripts/systems/Loc.gd")
const ProfanityFilterScript = preload("res://scripts/systems/ProfanityFilter.gd")

const ACCOUNT_CFG_PATH: String = "user://lampor_account.cfg"
const WEB_ACCOUNT_KEY: String = "lampor_account_v1"
const REQUEST_TIMEOUT_SEC: float = 10.0
const POW_YIELD_INTERVAL: int = 250
const POW_MAX_ITERATIONS: int = 250000

var is_logged_in: bool = false
var is_guest_mode: bool = false
var account_gate_resolved: bool = false
var user_id: String = ""
var username: String = ""
var display_name: String = ""
var bio: String = ""
var avatar_url: String = ""
var role: String = "player"
var is_verified: bool = false
var session_token: String = ""
var is_busy: bool = false
var last_error: String = ""
var server_base_url: String = ""
var friends_list: Array = []
var incoming_friend_requests: Array = []
var outgoing_friend_requests: Array = []
var players_directory: Array = []
var inbox_messages: Array = []
var unread_inbox_count: int = 0

var _is_syncing_profile: bool = false
var _pending_profile_sync: bool = false
var _applying_cloud_profile: bool = false
var _me_refresh_in_flight: bool = false
var _inbox_fetch_in_flight: bool = false
var _session_verified_with_server: bool = false
var _realtime_poll_accum: float = 0.0
var _web_sync_pending: bool = false
var _rx_username: RegEx = null
var _rx_letter: RegEx = null
var _rx_digit: RegEx = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_regexes()
	server_base_url = SettingsManager.server_base_url
	_load_account_storage()
	if OS.has_feature("web"):
		call_deferred("_schedule_web_account_reconcile")

func _process(delta: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not can_access_online_modes() or is_busy or _me_refresh_in_flight or _is_syncing_profile:
		return
	var mp: Variant = GameManager.get_multiplayer_manager(false)
	if mp != null and bool(mp.get("is_online_session")):
		return
	var interval: float = 2.0 if GameManager.is_in_active_gameplay() else 1.0
	_realtime_poll_accum += delta
	if _realtime_poll_accum >= interval:
		_realtime_poll_accum = 0.0
		refresh_profile_from_server()

func _ensure_regexes() -> void:
	if _rx_username == null:
		_rx_username = RegEx.new()
		_rx_username.compile("^[a-zA-Z0-9_]{3,24}$")
	if _rx_letter == null:
		_rx_letter = RegEx.new()
		_rx_letter.compile("[a-zA-Z]")
	if _rx_digit == null:
		_rx_digit = RegEx.new()
		_rx_digit.compile("[0-9]")

func can_access_online_modes() -> bool:
	return is_logged_in and not is_guest_mode and not session_token.is_empty()

func is_admin() -> bool:
	return can_access_online_modes() and role.strip_edges().to_lower() == "admin"

func get_effective_display_name() -> String:
	var clean_disp: String = display_name.strip_edges()
	if not clean_disp.is_empty():
		return ProfanityFilterScript.censor(clean_disp)
	return ProfanityFilterScript.censor(username)

func generate_safe_avatar_filename(ext: String = "jpg") -> String:
	var safe_ext: String = ext.strip_edges().to_lower()
	if safe_ext not in ["jpg", "png", "webp"]:
		safe_ext = "jpg"
	var crypto := Crypto.new()
	var hex: String = crypto.generate_random_bytes(8).hex_encode()
	if hex.length() < 8:
		hex = "%08x%08x" % [randi(), int(Time.get_ticks_usec())]
	return "avatar_%s.%s" % [hex.left(16), safe_ext]

func validate_credentials_format(uname: String, pwd: String, is_register: bool) -> String:
	_ensure_regexes()
	var clean_uname: String = uname.strip_edges()
	if clean_uname.is_empty():
		return LocScript.pick("Username wajib diisi.", "Username is required.")
	if clean_uname.to_lower() == "admin_lampor":
		return LocScript.pick(
			"Akun admin_lampor khusus akses Admin Dashboard web dan tidak dapat dimainkan di dalam game.",
			"The admin_lampor account is reserved for the web Admin Dashboard and cannot be played in-game."
		)
	if _rx_username.search(clean_uname) == null:
		return LocScript.pick(
			"Username harus 3-24 karakter (huruf, angka, atau underscore _).",
			"Username must be 3-24 characters (letters, numbers, or underscore _)."
		)
	if pwd.is_empty():
		return LocScript.pick("Password wajib diisi.", "Password is required.")
	if is_register:
		if ProfanityFilterScript.contains_profanity(clean_uname):
			return LocScript.pick(
				"Username mengandung kata kasar yang tidak diizinkan.",
				"Username contains disallowed profanity."
			)
		if pwd.length() < 8 or pwd.length() > 72:
			return LocScript.pick(
				"Password minimal 8 karakter dan maksimal 72 karakter.",
				"Password must be between 8 and 72 characters."
			)
		if _rx_letter.search(pwd) == null:
			return LocScript.pick(
				"Password wajib mengandung minimal 1 huruf.",
				"Password must include at least 1 letter."
			)
		if _rx_digit.search(pwd) == null:
			return LocScript.pick(
				"Password wajib mengandung minimal 1 angka.",
				"Password must include at least 1 digit."
			)
	elif pwd.length() > 72:
		return LocScript.pick(
			"Password maksimal 72 karakter.",
			"Password must be at most 72 characters."
		)
	return ""

func _get_effective_base_url() -> String:
	var base: String = SettingsManager.DEFAULT_SERVER_URL.strip_edges()
	while base.ends_with("/"):
		base = base.left(base.length() - 1)
	return base

func _transport_error_message(result_code: int) -> String:
	match result_code:
		HTTPRequest.RESULT_TIMEOUT:
			return LocScript.pick(
				"Koneksi ke server timeout (melebihi 10 detik).",
				"Server request timed out (exceeded 10 seconds)."
			)
		HTTPRequest.RESULT_CANT_RESOLVE:
			return LocScript.pick(
				"Alamat server tidak dapat ditemukan (DNS gagal).",
				"Could not resolve server host name."
			)
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return LocScript.pick(
				"Koneksi aman HTTPS/TLS ke server gagal.",
				"Secure HTTPS/TLS handshake failed."
			)
		HTTPRequest.RESULT_CANT_CONNECT:
			return LocScript.pick(
				"Tidak dapat terhubung ke server. Pastikan server aktif atau URL benar.",
				"Cannot connect to server. Verify server status or URL."
			)
		_:
			return LocScript.pick(
				"Koneksi jaringan terganggu (kode %d)." % result_code,
				"Network connection failed (code %d)." % result_code
			)

func api_request(method: String, path: String, body: Variant = null, use_auth: bool = true) -> Dictionary:
	var method_upper: String = method.strip_edges().to_upper()
	var http_method: HTTPClient.Method = HTTPClient.METHOD_GET
	match method_upper:
		"POST":
			http_method = HTTPClient.METHOD_POST
		"PUT":
			http_method = HTTPClient.METHOD_PUT
		"DELETE":
			http_method = HTTPClient.METHOD_DELETE
		"PATCH":
			http_method = HTTPClient.METHOD_PATCH
		_:
			http_method = HTTPClient.METHOD_GET

	var url: String = path
	if not (path.begins_with("http://") or path.begins_with("https://")):
		var normalized_path: String = path if path.begins_with("/") else "/" + path
		url = _get_effective_base_url() + normalized_path

	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json",
		"Cache-Control: no-cache",
		"X-Lampor-Client-Version: 1.3.1"
	])
	var used_token: String = session_token if (use_auth and not session_token.is_empty()) else ""
	if not used_token.is_empty():
		headers.append("Authorization: Bearer " + used_token)

	var payload_str: String = ""
	if body != null:
		payload_str = body if body is String else JSON.stringify(body)
	elif http_method in [HTTPClient.METHOD_POST, HTTPClient.METHOD_PUT, HTTPClient.METHOD_PATCH]:
		payload_str = "{}"

	var req := HTTPRequest.new()
	req.timeout = REQUEST_TIMEOUT_SEC
	req.max_redirects = 8
	req.use_threads = not OS.has_feature("web")
	add_child(req)

	var start_err: Error = req.request(url, headers, http_method, payload_str)
	if start_err != OK:
		req.queue_free()
		return {
			"ok": false,
			"status": 0,
			"data": {},
			"message": LocScript.pick(
				"Gagal memulai permintaan ke server (kode %d)." % start_err,
				"Failed to initiate request (code %d)." % start_err
			)
		}

	var completed: Array = await req.request_completed
	if is_instance_valid(req):
		req.queue_free()

	var result_code: int = int(completed[0]) if completed.size() > 0 else HTTPRequest.RESULT_CONNECTION_ERROR
	var status_code: int = int(completed[1]) if completed.size() > 1 else 0
	var raw_bytes: PackedByteArray = completed[3] if completed.size() > 3 and completed[3] is PackedByteArray else PackedByteArray()

	if result_code != HTTPRequest.RESULT_SUCCESS:
		return {
			"ok": false,
			"status": status_code,
			"data": {},
			"message": _transport_error_message(result_code)
		}

	var body_text: String = raw_bytes.get_string_from_utf8()
	var parsed_data: Dictionary = {}
	if not body_text.strip_edges().is_empty():
		var json := JSON.new()
		if json.parse(body_text) == OK and json.data is Dictionary:
			parsed_data = json.data as Dictionary

	var http_ok: bool = status_code >= 200 and status_code < 300
	var body_ok: bool = bool(parsed_data.get("ok", http_ok)) if not parsed_data.is_empty() else http_ok
	var final_ok: bool = http_ok and body_ok

	var raw_err: Variant = parsed_data.get("message", parsed_data.get("error", ""))
	var msg: String = ""
	if raw_err is Dictionary:
		msg = str((raw_err as Dictionary).get("message", (raw_err as Dictionary).get("error", ""))).strip_edges()
	else:
		msg = str(raw_err).strip_edges()
	var ban_reason: String = str(parsed_data.get("reason", "")).strip_edges()
	if not ban_reason.is_empty() and not msg.contains(ban_reason):
		msg = (msg + " (" + ban_reason + ")") if not msg.is_empty() else ban_reason
	if msg.is_empty() and not final_ok:
		msg = LocScript.network_error_label(status_code)

	var api_code: String = str(parsed_data.get("code", "")).strip_edges().to_upper()
	if status_code == 401 and not used_token.is_empty() and session_token == used_token and api_code in ["", "SESSION_EXPIRED", "UNAUTHORIZED", "INVALID_SESSION"]:
		_handle_session_expired(msg)

	return {
		"ok": final_ok,
		"status": status_code,
		"data": parsed_data,
		"message": msg
	}

func _clear_session_local() -> void:
	is_logged_in = false
	is_guest_mode = false
	account_gate_resolved = false
	session_token = ""
	user_id = ""
	username = ""
	display_name = ""
	bio = ""
	avatar_url = ""
	role = "player"
	is_verified = false
	friends_list.clear()
	incoming_friend_requests.clear()
	outgoing_friend_requests.clear()
	players_directory.clear()
	inbox_messages = []
	unread_inbox_count = 0

func _handle_session_expired(reason_msg: String) -> void:
	_clear_session_local()
	last_error = reason_msg if not reason_msg.is_empty() else LocScript.network_error_label(401)
	_clear_account_storage()
	SignalBus.account_state_changed.emit()
	SignalBus.inbox_messages_updated.emit(inbox_messages, unread_inbox_count)

func solve_pow_challenge() -> Dictionary:
	var res: Dictionary = await api_request("GET", "/api/auth/challenge", null, false)
	if not bool(res.get("ok", false)):
		return {
			"ok": false,
			"message": str(res.get("message", LocScript.pick("Gagal mengambil verifikasi anti-bot.", "Failed to fetch anti-bot challenge.")))
		}
	var d: Dictionary = res.get("data", {})
	var challenge_id: String = str(d.get("challengeId", ""))
	var salt: String = str(d.get("salt", ""))
	var difficulty: int = clampi(int(d.get("difficulty", 3)), 1, 6)
	var expires_at: int = int(d.get("expiresAt", 0))
	var signature: String = str(d.get("signature", ""))
	if challenge_id.is_empty() or salt.is_empty() or signature.is_empty() or expires_at <= 0:
		return {
			"ok": false,
			"message": LocScript.pick("Format tantangan anti-bot dari server tidak valid.", "Invalid anti-bot challenge payload from server.")
		}

	var prefix: String = "0".repeat(difficulty)
	var nonce: int = 0
	while nonce < POW_MAX_ITERATIONS:
		var ctx := HashingContext.new()
		ctx.start(HashingContext.HASH_SHA256)
		ctx.update(("%s:%d" % [salt, nonce]).to_utf8_buffer())
		var digest_hex: String = ctx.finish().hex_encode()
		if digest_hex.begins_with(prefix):
			return {
				"ok": true,
				"challengeId": challenge_id,
				"salt": salt,
				"difficulty": difficulty,
				"expiresAt": expires_at,
				"signature": signature,
				"nonce": nonce
			}
		nonce += 1
		if nonce % POW_YIELD_INTERVAL == 0:
			if not is_inside_tree():
				return {"ok": false, "message": LocScript.pick("Verifikasi dibatalkan.", "Verification cancelled.")}
			await get_tree().process_frame

	return {
		"ok": false,
		"message": LocScript.pick("Verifikasi anti-bot melebihi batas percobaan.", "Anti-bot proof-of-work exceeded iteration limit.")
	}

func _submit_auth_request(endpoint: String, uname: String, pwd: String, is_register: bool) -> Dictionary:
	if is_busy:
		return {
			"ok": false,
			"status": 0,
			"message": LocScript.pick("Permintaan akun sedang diproses, tunggu sebentar...", "An account request is already in progress...")
		}
	var clean_uname: String = uname.strip_edges()
	var format_err: String = validate_credentials_format(clean_uname, pwd, is_register)
	if not format_err.is_empty():
		last_error = format_err
		return {"ok": false, "status": 400, "message": format_err}

	is_busy = true
	last_error = ""

	var pow_res: Dictionary = await solve_pow_challenge()
	if not bool(pow_res.get("ok", false)):
		is_busy = false
		last_error = str(pow_res.get("message", ""))
		return {"ok": false, "status": 0, "message": last_error}

	var challenge_payload: Dictionary = {
		"challengeId": str(pow_res.get("challengeId", "")),
		"salt": str(pow_res.get("salt", "")),
		"difficulty": int(pow_res.get("difficulty", 3)),
		"expiresAt": int(pow_res.get("expiresAt", 0)),
		"signature": str(pow_res.get("signature", "")),
		"nonce": int(pow_res.get("nonce", 0))
	}
	var body: Dictionary = {
		"username": clean_uname,
		"password": pwd,
		"challenge": challenge_payload,
		"website": ""
	}
	var res: Dictionary = await api_request("POST", endpoint, body, false)
	is_busy = false

	if not bool(res.get("ok", false)):
		last_error = str(res.get("message", ""))
		return {
			"ok": false,
			"status": int(res.get("status", 0)),
			"message": last_error,
			"data": res.get("data", {})
		}

	var data: Dictionary = res.get("data", {})
	var token: String = str(data.get("token", "")).strip_edges()
	var user_dict: Dictionary = data.get("user", {}) if data.get("user") is Dictionary else {}
	if token.is_empty() or user_dict.is_empty():
		last_error = LocScript.pick("Respons sesi server tidak lengkap.", "Incomplete session response from server.")
		return {"ok": false, "status": int(res.get("status", 500)), "message": last_error}
	if str(user_dict.get("username", "")).strip_edges().to_lower() == "admin_lampor":
		last_error = LocScript.pick(
			"Akun admin_lampor khusus akses Admin Dashboard web dan tidak dapat dimainkan di dalam game.",
			"The admin_lampor account is reserved for the web Admin Dashboard and cannot be played in-game."
		)
		return {"ok": false, "status": 403, "message": last_error}

	session_token = token
	is_logged_in = true
	is_guest_mode = false
	account_gate_resolved = true
	last_error = ""
	_extract_identity_from_user(user_dict)
	_save_account_storage()
	_apply_server_user_to_game_manager(user_dict)
	SignalBus.account_state_changed.emit()
	if DisplayServer.get_name() != "headless":
		call_deferred("fetch_inbox_messages")

	return {
		"ok": true,
		"status": int(res.get("status", 200)),
		"message": str(res.get("message", "")),
		"user": user_dict
	}

func register_account(uname: String, pwd: String) -> Dictionary:
	return await _submit_auth_request("/api/auth/register", uname, pwd, true)

func login_account(uname: String, pwd: String) -> Dictionary:
	return await _submit_auth_request("/api/auth/login", uname, pwd, false)

func verify_saved_session() -> bool:
	if DisplayServer.get_name() == "headless":
		return can_access_online_modes()
	if session_token.is_empty():
		return false
	if _me_refresh_in_flight:
		return is_logged_in
	is_busy = true
	var res: Dictionary = {}
	for attempt: int in range(2):
		res = await api_request("GET", "/api/auth/me", null, true)
		if bool(res.get("ok", false)):
			break
		var st_try: int = int(res.get("status", 0))
		if st_try == 401 or st_try == 403:
			break
		if attempt == 0 and is_inside_tree():
			await get_tree().create_timer(0.8, true, false, true).timeout
	is_busy = false

	if bool(res.get("ok", false)):
		var data: Dictionary = res.get("data", {})
		var user_dict: Dictionary = data.get("user", {}) if data.get("user") is Dictionary else {}
		if not user_dict.is_empty():
			if str(user_dict.get("username", "")).strip_edges().to_lower() == "admin_lampor":
				_handle_session_expired(LocScript.pick(
					"Akun admin_lampor khusus akses Admin Dashboard web dan tidak dapat dimainkan di dalam game.",
					"The admin_lampor account is reserved for the web Admin Dashboard and cannot be played in-game."
				))
				return false
			_session_verified_with_server = true
			is_logged_in = true
			is_guest_mode = false
			account_gate_resolved = true
			last_error = ""
			_extract_identity_from_user(user_dict)
			_save_account_storage()
			_apply_server_user_to_game_manager(user_dict)
			SignalBus.account_state_changed.emit()
			if DisplayServer.get_name() != "headless":
				call_deferred("fetch_inbox_messages")
			return true

	var status_code: int = int(res.get("status", 0))
	var res_data: Dictionary = res.get("data", {}) if res.get("data") is Dictionary else {}
	if status_code == 401 or status_code == 403 or str(res_data.get("code", "")) == "ADMIN_DASHBOARD_ONLY":
		_handle_session_expired(str(res.get("message", "")))
		return false

	# Pertahankan sesi lokal saat gangguan jaringan/timeout/cold-start server agar pemain
	# tidak dipaksa login ulang setiap kali membuka game.
	last_error = str(res.get("message", ""))
	if not session_token.is_empty():
		is_logged_in = true
		is_guest_mode = false
		account_gate_resolved = true
		return true
	is_logged_in = false
	account_gate_resolved = false
	return false

func enter_guest_mode() -> void:
	_clear_session_local()
	is_guest_mode = true
	account_gate_resolved = true
	username = "Guest"
	last_error = ""
	_save_account_storage()
	SignalBus.account_state_changed.emit()
	SignalBus.inbox_messages_updated.emit(inbox_messages, unread_inbox_count)

func logout_account() -> void:
	var mp: Variant = GameManager.get_multiplayer_manager(false)
	if mp and bool(mp.get("is_online_session")) and mp.has_method("leave_room"):
		await mp.call("leave_room")
	elif mp and mp.has_method("reset_to_singleplayer"):
		mp.call("reset_to_singleplayer")

	if not session_token.is_empty():
		is_busy = true
		await api_request("POST", "/api/auth/logout", {}, true)
		is_busy = false

	_clear_session_local()
	last_error = ""
	_clear_account_storage()
	SignalBus.account_state_changed.emit()
	SignalBus.inbox_messages_updated.emit(inbox_messages, unread_inbox_count)

func fetch_friends_and_directory(search_query: String = "") -> Dictionary:
	if not can_access_online_modes():
		return {
			"ok": false,
			"status": 401,
			"friends": [],
			"incomingRequests": [],
			"outgoingRequests": [],
			"directory": [],
			"message": LocScript.pick("Masuk ke akun LAMPOR terlebih dahulu.", "Sign in to a LAMPOR account first.")
		}
	var cleaned_query: String = search_query.strip_edges()
	var path: String = "/api/friends/list"
	if not cleaned_query.is_empty():
		path += "?search=" + cleaned_query.uri_encode()
	var res: Dictionary = await api_request("GET", path, null, true)
	if not bool(res.get("ok", false)):
		return {
			"ok": false,
			"status": int(res.get("status", 0)),
			"friends": friends_list,
			"incomingRequests": incoming_friend_requests,
			"outgoingRequests": outgoing_friend_requests,
			"directory": players_directory,
			"message": str(res.get("message", LocScript.pick("Gagal memuat daftar teman.", "Failed to load friends list.")))
		}
	var data: Dictionary = res.get("data", {})
	var f_raw: Variant = data.get("friends", [])
	var ir_raw: Variant = data.get("incomingRequests", [])
	var or_raw: Variant = data.get("outgoingRequests", [])
	var d_raw: Variant = data.get("directory", [])
	friends_list = (f_raw as Array).duplicate(true) if f_raw is Array else []
	incoming_friend_requests = (ir_raw as Array).duplicate(true) if ir_raw is Array else []
	outgoing_friend_requests = (or_raw as Array).duplicate(true) if or_raw is Array else []
	players_directory = (d_raw as Array).duplicate(true) if d_raw is Array else []
	SignalBus.friends_updated.emit(friends_list, players_directory)
	return {
		"ok": true,
		"status": int(res.get("status", 200)),
		"friends": friends_list,
		"incomingRequests": incoming_friend_requests,
		"outgoingRequests": outgoing_friend_requests,
		"directory": players_directory,
		"message": str(res.get("message", ""))
	}

func add_friend_by_username(target_username: String) -> Dictionary:
	if not can_access_online_modes():
		return {
			"ok": false,
			"status": 401,
			"message": LocScript.pick("Masuk ke akun LAMPOR terlebih dahulu.", "Sign in to a LAMPOR account first.")
		}
	var cleaned: String = target_username.strip_edges()
	if cleaned.is_empty():
		return {
			"ok": false,
			"status": 400,
			"message": LocScript.pick("Masukkan username pemain.", "Enter a player username.")
		}
	var res: Dictionary = await api_request("POST", "/api/friends/add", {"username": cleaned}, true)
	return {
		"ok": bool(res.get("ok", false)),
		"status": int(res.get("status", 0)),
		"data": res.get("data", {}),
		"message": str(res.get("message", ""))
	}

func accept_friend_request(requester_user_id: String) -> Dictionary:
	if not can_access_online_modes():
		return {
			"ok": false,
			"status": 401,
			"message": LocScript.pick("Masuk ke akun LAMPOR terlebih dahulu.", "Sign in to a LAMPOR account first.")
		}
	var cleaned: String = requester_user_id.strip_edges()
	if cleaned.is_empty():
		return {
			"ok": false,
			"status": 400,
			"message": LocScript.pick("ID pengirim permintaan tidak valid.", "Invalid requester ID.")
		}
	var res: Dictionary = await api_request("POST", "/api/friends/accept", {"requesterUserId": cleaned}, true)
	return {
		"ok": bool(res.get("ok", false)),
		"status": int(res.get("status", 0)),
		"data": res.get("data", {}),
		"message": str(res.get("message", ""))
	}

func decline_friend_request(target_user_id: String) -> Dictionary:
	if not can_access_online_modes():
		return {
			"ok": false,
			"status": 401,
			"message": LocScript.pick("Masuk ke akun LAMPOR terlebih dahulu.", "Sign in to a LAMPOR account first.")
		}
	var cleaned: String = target_user_id.strip_edges()
	if cleaned.is_empty():
		return {
			"ok": false,
			"status": 400,
			"message": LocScript.pick("ID pemain tidak valid.", "Invalid player ID.")
		}
	var res: Dictionary = await api_request("POST", "/api/friends/decline", {"targetUserId": cleaned}, true)
	return {
		"ok": bool(res.get("ok", false)),
		"status": int(res.get("status", 0)),
		"data": res.get("data", {}),
		"message": str(res.get("message", ""))
	}

func remove_friend(friend_user_id: String) -> Dictionary:
	if not can_access_online_modes():
		return {
			"ok": false,
			"status": 401,
			"message": LocScript.pick("Masuk ke akun LAMPOR terlebih dahulu.", "Sign in to a LAMPOR account first.")
		}
	var cleaned: String = friend_user_id.strip_edges()
	if cleaned.is_empty():
		return {
			"ok": false,
			"status": 400,
			"message": LocScript.pick("ID teman tidak valid.", "Invalid friend ID.")
		}
	var res: Dictionary = await api_request("POST", "/api/friends/remove", {"friendUserId": cleaned}, true)
	return {
		"ok": bool(res.get("ok", false)),
		"status": int(res.get("status", 0)),
		"data": res.get("data", {}),
		"message": str(res.get("message", ""))
	}

func fetch_player_profile(target_user_id: String = "", target_username: String = "") -> Dictionary:
	if not can_access_online_modes():
		return {
			"ok": false,
			"status": 401,
			"message": LocScript.pick("Masuk ke akun LAMPOR untuk melihat profil pemain.", "Sign in to a LAMPOR account to view player profiles.")
		}
	var clean_uid: String = target_user_id.strip_edges()
	var clean_uname: String = target_username.strip_edges()
	var q: String = ""
	if not clean_uid.is_empty():
		q = "userId=" + clean_uid.uri_encode()
	elif not clean_uname.is_empty():
		q = "username=" + clean_uname.uri_encode()
	else:
		return {"ok": false, "status": 400, "message": "Target tidak valid."}
	var res: Dictionary = await api_request("GET", "/api/friends/profile?" + q, null, true)
	var data: Dictionary = res.get("data", {}) if res.get("data") is Dictionary else {}
	if bool(res.get("ok", false)):
		return {
			"ok": true,
			"profile": data.get("profile", {})
		}
	return {
		"ok": false,
		"status": int(res.get("status", 0)),
		"data": data,
		"message": str(res.get("message", LocScript.pick("Gagal memuat profil pemain.", "Failed to load player profile.")))
	}

func update_profile(new_display_name: String, new_bio: String, new_avatar_url: String, _raw_avatar_filename: String = "") -> Dictionary:
	if not can_access_online_modes():
		var auth_msg: String = LocScript.pick("Masuk ke akun LAMPOR untuk mengedit profil.", "Sign in to a LAMPOR account to edit your profile.")
		last_error = auth_msg
		return {"ok": false, "status": 401, "message": auth_msg}
	if is_busy:
		var busy_msg: String = LocScript.pick("Permintaan akun sedang diproses, tunggu sebentar...", "An account request is already in progress...")
		return {"ok": false, "status": 0, "message": busy_msg}

	is_busy = true
	last_error = ""
	var clean_disp: String = ProfanityFilterScript.censor(new_display_name.strip_edges().left(32))
	var clean_bio: String = ProfanityFilterScript.censor(new_bio.strip_edges().left(200))
	var clean_avatar: String = new_avatar_url.strip_edges()
	var body: Dictionary = {
		"displayName": clean_disp,
		"bio": clean_bio,
		"avatarUrl": clean_avatar
	}
	if clean_avatar.begins_with("data:image/"):
		var ext: String = "png" if clean_avatar.begins_with("data:image/png") else ("webp" if clean_avatar.begins_with("data:image/webp") else "jpg")
		body["avatarFilename"] = generate_safe_avatar_filename(ext)
	var res: Dictionary = await api_request("POST", "/api/auth/profile", body, true)
	is_busy = false

	if not bool(res.get("ok", false)):
		last_error = str(res.get("message", LocScript.pick("Gagal menyimpan perubahan profil.", "Failed to save profile changes.")))
		return {
			"ok": false,
			"status": int(res.get("status", 0)),
			"message": last_error,
			"data": res.get("data", {})
		}

	var data: Dictionary = res.get("data", {})
	var user_dict: Dictionary = data.get("user", {}) if data.get("user") is Dictionary else {}
	if not user_dict.is_empty():
		_extract_identity_from_user(user_dict)
	else:
		display_name = str(body["displayName"])
		bio = str(body["bio"])
		avatar_url = str(body["avatarUrl"])
	_save_account_storage()
	SignalBus.account_state_changed.emit()
	return {
		"ok": true,
		"status": int(res.get("status", 200)),
		"user": user_dict
	}

func sync_profile_to_cloud() -> void:
	if not can_access_online_modes() or _applying_cloud_profile:
		return
	if _is_syncing_profile:
		_pending_profile_sync = true
		return

	_is_syncing_profile = true
	last_error = ""
	while true:
		_pending_profile_sync = false
		if not can_access_online_modes():
			break
		var stash_payload: Dictionary = {
			"jamu": clampi(int(GameManager.item_stash.get("jamu", 0)), 0, GameManager.MAX_SHOP_ITEM_QTY),
			"baterai": clampi(int(GameManager.item_stash.get("baterai", 0)), 0, GameManager.MAX_SHOP_ITEM_QTY),
			"energy_drink": clampi(int(GameManager.item_stash.get("energy_drink", 0)), 0, GameManager.MAX_SHOP_ITEM_QTY),
			"kentongan": clampi(int(GameManager.item_stash.get("kentongan", 0)), 0, GameManager.MAX_SHOP_ITEM_QTY)
		}
		var codes_payload: Array = []
		for code_entry: String in GameManager.redeemed_codes:
			codes_payload.append(code_entry)
		var body: Dictionary = {
			"coins": clampi(GameManager.coins, 0, GameManager.MAX_COINS),
			"totalWins": maxi(0, GameManager.total_wins),
			"extraLives": clampi(GameManager.extra_lives, 0, GameManager.MAX_EXTRA_LIVES),
			"itemStash": stash_payload,
			"redeemedCodes": codes_payload,
			"saveSeq": maxi(0, GameManager.save_seq),
			"tutorialCompleted": GameManager.tutorial_completed
		}
		var res: Dictionary = await api_request("POST", "/api/auth/sync", body, true)
		if bool(res.get("ok", false)):
			last_error = ""
			var data: Dictionary = res.get("data", {})
			if data.get("user") is Dictionary and not _pending_profile_sync:
				var server_user: Dictionary = data["user"] as Dictionary
				var server_seq: int = int(server_user.get("saveSeq", server_user.get("save_seq", 0)))
				if server_seq > GameManager.save_seq:
					_apply_server_user_to_game_manager(server_user)
					SignalBus.account_state_changed.emit()
		else:
			last_error = str(res.get("message", LocScript.pick("Gagal menyinkronkan profil ke cloud.", "Failed to sync profile to cloud.")))
		if not _pending_profile_sync:
			break
	_is_syncing_profile = false

func refresh_profile_from_server() -> Dictionary:
	if not can_access_online_modes() or _me_refresh_in_flight or _is_syncing_profile:
		return {}
	_me_refresh_in_flight = true
	var res: Dictionary = await api_request("GET", "/api/auth/me", null, true)
	_me_refresh_in_flight = false
	if not bool(res.get("ok", false)):
		var err_status: int = int(res.get("status", 0))
		var err_data: Dictionary = res.get("data", {}) if res.get("data") is Dictionary else {}
		if err_status == 403 and str(err_data.get("code", "")) == "ADMIN_DASHBOARD_ONLY":
			_handle_session_expired(str(res.get("message", "")))
		return res
	var data: Dictionary = res.get("data", {})
	var user_dict: Dictionary = data.get("user", {}) if data.get("user") is Dictionary else {}
	if not user_dict.is_empty():
		apply_live_server_user(user_dict)
	if data.has("unreadMessagesCount"):
		var next_unread: int = maxi(0, int(data.get("unreadMessagesCount", unread_inbox_count)))
		if next_unread != unread_inbox_count:
			unread_inbox_count = next_unread
			SignalBus.inbox_messages_updated.emit(inbox_messages, unread_inbox_count)
	return res

func fetch_inbox_messages() -> Dictionary:
	if _inbox_fetch_in_flight:
		return {
			"ok": false,
			"status": 0,
			"messages": inbox_messages,
			"unreadCount": unread_inbox_count
		}
	_inbox_fetch_in_flight = true
	var use_auth: bool = can_access_online_modes()
	var path: String = "/api/auth/messages" if use_auth else "/api/auth/global-messages"
	var res: Dictionary = await api_request("GET", path, null, use_auth)
	_inbox_fetch_in_flight = false
	if bool(res.get("ok", false)):
		var data: Dictionary = res.get("data", {}) if res.get("data") is Dictionary else {}
		var msgs_raw: Variant = data.get("messages", [])
		var next_msgs: Array = []
		if msgs_raw is Array:
			for item: Variant in (msgs_raw as Array):
				if item is Dictionary:
					next_msgs.append((item as Dictionary).duplicate(true))
		inbox_messages = next_msgs
		if can_access_online_modes():
			if data.has("unreadCount"):
				unread_inbox_count = maxi(0, int(data.get("unreadCount", 0)))
			else:
				var computed_unread: int = 0
				for msg: Dictionary in next_msgs:
					if not bool(msg.get("isRead", false)):
						computed_unread += 1
				unread_inbox_count = computed_unread
		else:
			unread_inbox_count = 0
		SignalBus.inbox_messages_updated.emit(inbox_messages, unread_inbox_count)
	return res

func mark_inbox_messages_read(message_ids: Array = []) -> Dictionary:
	if not can_access_online_modes():
		return {"ok": false}
	var payload: Dictionary = {"action": "mark_read"}
	if not message_ids.is_empty():
		payload["messageIds"] = message_ids
	var res: Dictionary = await api_request("POST", "/api/auth/messages", payload, true)
	if bool(res.get("ok", false)):
		var mark_all: bool = message_ids.is_empty()
		var id_set: Dictionary = {}
		for raw_id: Variant in message_ids:
			var s_id: String = str(raw_id).strip_edges()
			if not s_id.is_empty():
				id_set[s_id] = true
		for i: int in range(inbox_messages.size()):
			if inbox_messages[i] is Dictionary:
				var msg: Dictionary = inbox_messages[i] as Dictionary
				var msg_id: String = str(msg.get("id", msg.get("_id", msg.get("messageId", "")))).strip_edges()
				if mark_all or id_set.has(msg_id):
					msg["isRead"] = true
					inbox_messages[i] = msg
		var data: Dictionary = res.get("data", {}) if res.get("data") is Dictionary else {}
		if data.has("unreadCount"):
			unread_inbox_count = maxi(0, int(data.get("unreadCount", 0)))
		else:
			var remaining_unread: int = 0
			for item: Variant in inbox_messages:
				if item is Dictionary and not bool((item as Dictionary).get("isRead", false)):
					remaining_unread += 1
			unread_inbox_count = remaining_unread
		SignalBus.inbox_messages_updated.emit(inbox_messages, unread_inbox_count)
	return res

func apply_live_server_user(user_dict: Dictionary) -> void:
	if user_dict.is_empty():
		return
	if str(user_dict.get("username", "")).strip_edges().to_lower() == "admin_lampor":
		_handle_session_expired(LocScript.pick(
			"Akun admin_lampor khusus akses Admin Dashboard web dan tidak dapat dimainkan di dalam game.",
			"The admin_lampor account is reserved for the web Admin Dashboard and cannot be played in-game."
		))
		return
	var prev_role: String = role
	var prev_verified: bool = is_verified
	var prev_disp: String = display_name
	var prev_bio: String = bio
	var prev_avatar: String = avatar_url
	_extract_identity_from_user(user_dict)
	var server_seq: int = user_data_seq(user_dict)
	var server_coins: int = clampi(int(user_dict.get("coins", GameManager.coins)), 0, GameManager.MAX_COINS)
	var server_wins: int = maxi(0, int(user_dict.get("totalWins", user_dict.get("total_wins", GameManager.total_wins))))
	var server_lives: int = clampi(int(user_dict.get("extraLives", user_dict.get("extra_lives", GameManager.extra_lives))), 0, GameManager.MAX_EXTRA_LIVES)
	var progress_differs: bool = (server_coins != GameManager.coins or server_wins != GameManager.total_wins or server_lives != GameManager.extra_lives)
	var should_apply: bool = (server_seq > GameManager.save_seq) or ((not _is_syncing_profile) and (not _pending_profile_sync) and server_seq >= GameManager.save_seq and progress_differs)
	if should_apply:
		_apply_server_user_to_game_manager(user_dict)
	var identity_changed: bool = (prev_role != role or prev_verified != is_verified or prev_disp != display_name or prev_bio != bio or prev_avatar != avatar_url)
	if should_apply or identity_changed:
		_save_account_storage()
		SignalBus.account_state_changed.emit()

func user_data_seq(user_data: Dictionary) -> int:
	return maxi(0, int(user_data.get("saveSeq", user_data.get("save_seq", 0))))

func redeem_cloud_code(code: String) -> Dictionary:
	if not can_access_online_modes():
		return {
			"ok": false,
			"success": false,
			"message": LocScript.pick("Masuk ke akun LAMPOR untuk menukar kode cloud.", "Log in to a LAMPOR account to redeem cloud codes.")
		}
	var cleaned: String = code.strip_edges().to_upper()
	if cleaned.is_empty():
		return {
			"ok": false,
			"success": false,
			"message": LocScript.pick("Masukkan kode redeem terlebih dahulu.", "Enter a redeem code first.")
		}
	var res: Dictionary = await api_request("POST", "/api/redeem", {"code": cleaned}, true)
	if not bool(res.get("ok", false)):
		return {
			"ok": false,
			"success": false,
			"status": int(res.get("status", 0)),
			"message": str(res.get("message", LocScript.pick("Kode redeem gagal diproses.", "Failed to redeem code.")))
		}

	var data: Dictionary = res.get("data", {})
	var user_dict: Variant = data.get("user", null)
	if user_dict is Dictionary:
		_apply_server_user_to_game_manager(user_dict as Dictionary)
	elif data.get("reward") is Dictionary:
		var raw_reward: Dictionary = data["reward"] as Dictionary
		var normalized_reward: Dictionary = {
			"type": str(raw_reward.get("type", raw_reward.get("rewardType", ""))),
			"item_id": str(raw_reward.get("item_id", raw_reward.get("itemId", ""))),
			"quantity": int(raw_reward.get("quantity", 1))
		}
		GameManager.apply_reward(normalized_reward)
		if not GameManager.redeemed_codes.has(cleaned):
			GameManager.redeemed_codes.append(cleaned)
		_applying_cloud_profile = true
		GameManager.save_game_data(true)
		_applying_cloud_profile = false
		SignalBus.coins_changed.emit(GameManager.coins)
	SignalBus.account_state_changed.emit()

	return {
		"ok": true,
		"success": true,
		"status": int(res.get("status", 200)),
		"message": str(res.get("message", data.get("message", LocScript.pick("Kode berhasil ditukarkan.", "Code redeemed successfully.")))),
		"reward": data.get("reward", {}),
		"data": data
	}

func _extract_identity_from_user(user_data: Dictionary) -> void:
	var uid_val: String = str(user_data.get("id", user_data.get("userId", user_id))).strip_edges()
	if not uid_val.is_empty():
		user_id = uid_val
	var uname_val: String = str(user_data.get("username", username)).strip_edges()
	if not uname_val.is_empty():
		username = uname_val
	if user_data.has("displayName") or user_data.has("display_name"):
		display_name = str(user_data.get("displayName", user_data.get("display_name", ""))).strip_edges()
	if user_data.has("bio"):
		bio = str(user_data.get("bio", "")).strip_edges()
	if user_data.has("avatarUrl") or user_data.has("avatar_url"):
		avatar_url = str(user_data.get("avatarUrl", user_data.get("avatar_url", ""))).strip_edges()
	role = str(user_data.get("role", "player")).strip_edges().to_lower()
	if role.is_empty():
		role = "player"
	if user_data.has("isVerified") or user_data.has("is_verified"):
		is_verified = bool(user_data.get("isVerified", user_data.get("is_verified", false)))

func _apply_server_user_to_game_manager(user_data: Dictionary) -> void:
	if user_data.is_empty():
		return
	_applying_cloud_profile = true
	GameManager.coins = clampi(int(user_data.get("coins", 0)), 0, GameManager.MAX_COINS)
	GameManager.total_wins = maxi(0, int(user_data.get("totalWins", user_data.get("total_wins", 0))))
	GameManager.extra_lives = clampi(int(user_data.get("extraLives", user_data.get("extra_lives", 0))), 0, GameManager.MAX_EXTRA_LIVES)
	var server_seq: int = maxi(0, int(user_data.get("saveSeq", user_data.get("save_seq", 0))))
	GameManager.save_seq = server_seq

	var stash_raw: Variant = user_data.get("itemStash", user_data.get("item_stash", {}))
	for item_key: String in ["jamu", "baterai", "energy_drink", "kentongan"]:
		var qty: int = 0
		if stash_raw is Dictionary:
			qty = clampi(int((stash_raw as Dictionary).get(item_key, 0)), 0, GameManager.MAX_SHOP_ITEM_QTY)
		GameManager.item_stash[item_key] = qty

	GameManager.redeemed_codes.clear()
	var codes_raw: Variant = user_data.get("redeemedCodes", user_data.get("redeemed_codes", []))
	if codes_raw is Array:
		for c: Variant in (codes_raw as Array):
			var norm_code: String = str(c).strip_edges().to_upper()
			if not norm_code.is_empty() and not GameManager.redeemed_codes.has(norm_code):
				GameManager.redeemed_codes.append(norm_code)

	GameManager.save_game_data(true, false, false)
	_applying_cloud_profile = false
	SignalBus.coins_changed.emit(GameManager.coins)

func _save_account_storage() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var cfg := ConfigFile.new()
	cfg.set_value("account", "token", session_token)
	cfg.set_value("account", "user_id", user_id)
	cfg.set_value("account", "username", username)
	cfg.set_value("account", "display_name", display_name)
	cfg.set_value("account", "bio", bio)
	cfg.set_value("account", "avatar_url", avatar_url)
	cfg.set_value("account", "role", role)
	cfg.set_value("account", "is_verified", is_verified)
	cfg.set_value("account", "is_guest", is_guest_mode)
	cfg.save(ACCOUNT_CFG_PATH)
	if OS.has_feature("web"):
		_mirror_account_to_web_storage(cfg.encode_to_text())
		_sync_web_idbfs()

func _load_account_storage() -> void:
	var cfg := ConfigFile.new()
	var loaded_ok: bool = (cfg.load(ACCOUNT_CFG_PATH) == OK)
	if not loaded_ok and OS.has_feature("web"):
		loaded_ok = _restore_account_from_web_storage(cfg)
	if not loaded_ok:
		return

	var saved_token: String = str(cfg.get_value("account", "token", "")).strip_edges()
	var saved_uid: String = str(cfg.get_value("account", "user_id", "")).strip_edges()
	var saved_uname: String = str(cfg.get_value("account", "username", "")).strip_edges()
	var saved_disp: String = str(cfg.get_value("account", "display_name", "")).strip_edges()
	var saved_bio: String = str(cfg.get_value("account", "bio", "")).strip_edges()
	var saved_avatar: String = str(cfg.get_value("account", "avatar_url", "")).strip_edges()
	var saved_role: String = str(cfg.get_value("account", "role", "player")).strip_edges().to_lower()
	var saved_verified: bool = bool(cfg.get_value("account", "is_verified", false))
	var saved_guest: bool = bool(cfg.get_value("account", "is_guest", false))

	if not saved_token.is_empty() and saved_uname.to_lower() != "admin_lampor":
		session_token = saved_token
		user_id = saved_uid
		username = saved_uname
		display_name = saved_disp
		bio = saved_bio
		avatar_url = saved_avatar
		role = saved_role if not saved_role.is_empty() else "player"
		is_verified = saved_verified
		is_logged_in = true
		is_guest_mode = false
		account_gate_resolved = true
		_session_verified_with_server = false
	elif saved_guest:
		session_token = ""
		user_id = ""
		username = "Guest"
		display_name = ""
		bio = ""
		avatar_url = ""
		role = "player"
		is_logged_in = false
		is_guest_mode = true
		account_gate_resolved = true

func _clear_account_storage() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if FileAccess.file_exists(ACCOUNT_CFG_PATH):
		var abs_path: String = ProjectSettings.globalize_path(ACCOUNT_CFG_PATH)
		if DirAccess.remove_absolute(abs_path) != OK:
			var empty_cfg := ConfigFile.new()
			empty_cfg.set_value("account", "token", "")
			empty_cfg.set_value("account", "is_guest", false)
			empty_cfg.save(ACCOUNT_CFG_PATH)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("try{window.localStorage.removeItem('%s');}catch(e){}" % WEB_ACCOUNT_KEY)
		_sync_web_idbfs()

func _mirror_account_to_web_storage(cfg_text: String) -> void:
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
	})()""" % [b64, WEB_ACCOUNT_KEY]
	JavaScriptBridge.eval(js_code)

func _restore_account_from_web_storage(cfg: ConfigFile) -> bool:
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
	})()""" % WEB_ACCOUNT_KEY
	var b64: Variant = JavaScriptBridge.eval(js_code)
	if not (b64 is String) or (b64 as String).is_empty():
		return false
	var decoded: String = Marshalls.base64_to_utf8(b64 as String)
	if decoded.is_empty():
		return false
	return cfg.parse(decoded) == OK

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

func _schedule_web_account_reconcile() -> void:
	if not OS.has_feature("web"):
		return
	await get_tree().create_timer(0.65, true, false, true).timeout
	if not is_inside_tree() or account_gate_resolved or is_busy or not session_token.is_empty():
		return
	var disk_cfg := ConfigFile.new()
	if disk_cfg.load(ACCOUNT_CFG_PATH) == OK:
		_load_account_storage()
		if account_gate_resolved:
			SignalBus.account_state_changed.emit()
			if can_access_online_modes():
				verify_saved_session()

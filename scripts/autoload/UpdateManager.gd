extends Node

signal update_available(commit_sha: String, commit_message: String)
signal update_downloaded(file_path: String, commit_sha: String)
signal update_failed(message: String)
signal up_to_date(commit_sha: String)

const BUILD_COMMIT: String = "aaf147bf8428d017a09a7e58d4e2a59a5c9e95b7"
const API_URL: String = "https://api.github.com/repos/Reyofficial77/lampor/commits/main"
const ATOM_URL: String = "https://github.com/Reyofficial77/lampor/commits/main.atom"
const ARCHIVE_URL: String = "https://codeload.github.com/Reyofficial77/lampor/zip/"
const UPDATE_CONFIG_PATH: String = "user://lampor_update.cfg"

var latest_commit: String = ""
var latest_message: String = ""
var has_update: bool = false
var is_checking: bool = false
var is_downloading: bool = false
var using_atom_fallback: bool = false
var downloaded_commit: String = ""
var downloaded_path: String = ""
var last_error: String = ""
var api_request: HTTPRequest
var fallback_request: HTTPRequest
var download_request: HTTPRequest

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	api_request = HTTPRequest.new()
	api_request.timeout = 45.0
	api_request.max_redirects = 12
	api_request.use_threads = true
	add_child(api_request)
	api_request.request_completed.connect(_on_api_request_completed)
	fallback_request = HTTPRequest.new()
	fallback_request.timeout = 45.0
	fallback_request.max_redirects = 12
	fallback_request.use_threads = true
	add_child(fallback_request)
	fallback_request.request_completed.connect(_on_atom_request_completed)
	download_request = HTTPRequest.new()
	download_request.timeout = 240.0
	download_request.max_redirects = 12
	download_request.use_threads = true
	add_child(download_request)
	download_request.request_completed.connect(_on_download_request_completed)
	_load_update_state()

func _load_update_state() -> void:
	var config := ConfigFile.new()
	if config.load(UPDATE_CONFIG_PATH) == OK:
		downloaded_commit = str(config.get_value("update", "downloaded_commit", ""))
		downloaded_path = str(config.get_value("update", "downloaded_path", ""))

func _save_update_state() -> void:
	var config := ConfigFile.new()
	config.set_value("update", "downloaded_commit", downloaded_commit)
	config.set_value("update", "downloaded_path", downloaded_path)
	config.save(UPDATE_CONFIG_PATH)

func check_for_updates(force: bool = false) -> void:
	if is_checking or is_downloading:
		return
	if not force and has_update and downloaded_commit == latest_commit:
		return
	is_checking = true
	using_atom_fallback = false
	last_error = ""
	var headers: PackedStringArray = ["User-Agent: Lampor-Game", "Accept: application/vnd.github+json", "X-GitHub-Api-Version: 2022-11-28"]
	var error: Error = api_request.request(API_URL, headers)
	if error != OK:
		_request_atom_fallback(HTTPRequest.RESULT_CANT_CONNECT)

func _request_atom_fallback(previous_result: int) -> void:
	using_atom_fallback = true
	var headers: PackedStringArray = ["User-Agent: Lampor-Game", "Accept: application/atom+xml"]
	var error: Error = fallback_request.request(ATOM_URL, headers)
	if error != OK:
		using_atom_fallback = false
		is_checking = false
		_fail(_format_network_error(previous_result, 0, "GitHub API dan jalur alternatif"))

func download_update() -> void:
	if is_downloading:
		return
	if latest_commit.is_empty():
		check_for_updates(true)
		return
	var update_dir: String = OS.get_user_data_dir().path_join("updates")
	var make_dir_error: Error = DirAccess.make_dir_recursive_absolute(update_dir)
	if make_dir_error != OK and make_dir_error != ERR_ALREADY_EXISTS:
		_fail("Folder update tidak dapat dibuat (kode %d)." % make_dir_error)
		return
	downloaded_path = update_dir.path_join("lampor-%s.zip" % latest_commit.substr(0, 10))
	if FileAccess.file_exists(downloaded_path):
		DirAccess.remove_absolute(downloaded_path)
	download_request.download_file = downloaded_path
	var headers: PackedStringArray = ["User-Agent: Lampor-Game", "Accept: application/zip"]
	var error: Error = download_request.request(ARCHIVE_URL + latest_commit, headers)
	if error != OK:
		download_request.download_file = ""
		_fail("Tidak dapat memulai unduhan update (kode %d)." % error)
		return
	is_downloading = true

func open_downloaded_package() -> void:
	if downloaded_path.is_empty() or not FileAccess.file_exists(downloaded_path):
		return
	OS.shell_open(ProjectSettings.globalize_path(downloaded_path))

func _on_api_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_request_atom_fallback(result)
		return
	is_checking = false
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		_fail("Respons GitHub tidak valid (JSON tidak dapat dibaca).")
		return
	var commit_sha: String = str(parsed.get("sha", ""))
	var commit_data: Dictionary = parsed.get("commit", {})
	var commit_message: String = str(commit_data.get("message", "Pembaruan Lampor"))
	_handle_latest_commit(commit_sha, commit_message)

func _on_atom_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	using_atom_fallback = false
	is_checking = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_fail(_format_network_error(result, response_code, "jalur alternatif GitHub (Atom)"))
		return
	_parse_atom_response(body)

func _parse_atom_response(body: PackedByteArray) -> void:
	var feed_text: String = body.get_string_from_utf8()
	var sha_regex := RegEx.new()
	if sha_regex.compile("<id>[^<]*([0-9a-f]{40})</id>") != OK:
		_fail("Parser cadangan GitHub gagal disiapkan.")
		return
	var matches: Array[RegExMatch] = sha_regex.search_all(feed_text)
	if matches.is_empty():
		_fail("GitHub merespons, tetapi commit terbaru tidak ditemukan pada feed cadangan.")
		return
	var commit_sha: String = matches[0].get_string(1)
	var message: String = "Commit terbaru dari GitHub"
	var title_regex := RegEx.new()
	if title_regex.compile("(?s)<entry>.*?<title>(.*?)</title>") == OK:
		var title_match: RegExMatch = title_regex.search(feed_text)
		if title_match:
			message = title_match.get_string(1).strip_edges()
	_handle_latest_commit(commit_sha, message)

func _handle_latest_commit(commit_sha: String, commit_message: String) -> void:
	latest_commit = commit_sha.strip_edges()
	latest_message = commit_message
	if latest_commit.is_empty():
		_fail("GitHub tidak mengembalikan identitas commit.")
		return
	has_update = latest_commit != BUILD_COMMIT
	if has_update:
		update_available.emit(latest_commit, latest_message)
		if SettingsManager.auto_update and downloaded_commit != latest_commit:
			download_update()
	else:
		up_to_date.emit(latest_commit)

func _on_download_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	is_downloading = false
	download_request.download_file = ""
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200 or not FileAccess.file_exists(downloaded_path):
		if FileAccess.file_exists(downloaded_path):
			DirAccess.remove_absolute(downloaded_path)
		_fail(_format_network_error(result, response_code, "unduhan paket game"))
		return
	var archive_bytes: PackedByteArray = FileAccess.get_file_as_bytes(downloaded_path)
	if archive_bytes.size() < 4 or archive_bytes[0] != 0x50 or archive_bytes[1] != 0x4B:
		DirAccess.remove_absolute(downloaded_path)
		_fail("GitHub tidak mengirim arsip ZIP yang valid. Periksa koneksi lalu coba lagi.")
		return
	downloaded_commit = latest_commit
	_save_update_state()
	update_downloaded.emit(downloaded_path, downloaded_commit)

func _format_network_error(result: int, response_code: int, service: String) -> String:
	var detail: String = ""
	match result:
		HTTPRequest.RESULT_SUCCESS:
			detail = "Permintaan selesai, tetapi server mengembalikan HTTP %d." % response_code
		HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH:
			detail = "Transfer respons terpotong atau ukuran data tidak cocok."
		HTTPRequest.RESULT_CANT_CONNECT:
			detail = "Tidak dapat terhubung ke server (periksa internet, firewall, atau proxy)."
		HTTPRequest.RESULT_CANT_RESOLVE:
			detail = "Alamat server tidak dapat ditemukan oleh DNS."
		HTTPRequest.RESULT_CONNECTION_ERROR:
			detail = "Koneksi terputus sebelum transfer selesai."
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			detail = "Negosiasi TLS/sertifikat HTTPS gagal. Periksa tanggal perangkat dan sertifikat sistem."
		HTTPRequest.RESULT_NO_RESPONSE:
			detail = "Server tidak memberikan respons."
		HTTPRequest.RESULT_TIMEOUT:
			detail = "Koneksi melewati batas waktu."
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
			detail = "Ukuran respons melebihi batas HTTPRequest."
		HTTPRequest.RESULT_REQUEST_FAILED:
			detail = "Permintaan jaringan gagal diproses oleh HTTPRequest."
		HTTPRequest.RESULT_BODY_DECOMPRESS_FAILED:
			detail = "Respons server gagal dibuka/dekompresi."
		HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN:
			detail = "File tujuan unduhan tidak dapat dibuka. Periksa ruang penyimpanan dan izin folder."
		HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
			detail = "File unduhan gagal ditulis. Periksa ruang penyimpanan."
		HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED:
			detail = "Server terlalu banyak mengalihkan permintaan."
		_:
			detail = "Kesalahan transport jaringan (kode %d)." % result
	var message: String = "%s gagal. %s" % [service, detail]
	if response_code == 0:
		message += " HTTP 0 bukan status dari GitHub; koneksi gagal sebelum menerima header HTTP (umumnya izin INTERNET Android, DNS, TLS, VPN, atau jaringan)."
	if OS.has_feature("android"):
		message += " Pastikan Android Export Preset > Permissions > INTERNET aktif, lalu ekspor ulang APK. Periksa juga tanggal/waktu perangkat dan coba jaringan lain."
	message += " Coba jaringan Wi-Fi/data lain bila masalah berlanjut."
	return message

func _fail(message: String) -> void:
	last_error = message
	update_failed.emit(message)

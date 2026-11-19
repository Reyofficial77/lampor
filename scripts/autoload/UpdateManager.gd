extends Node

signal update_available(commit_sha: String, commit_message: String)
signal update_installed(destination_path: String, commit_sha: String, applied_to_project: bool)
signal update_failed(message: String)
signal up_to_date(commit_sha: String)

const FULL_TREE_SYNC_VERSION: int = 1
const BUILD_COMMIT: String = "a71d2525629a13768bc27ceeaf6414162438e32c"
const API_URL: String = "https://api.github.com/repos/Reyofficial77/lampor/commits/main"
const ATOM_URL: String = "https://github.com/Reyofficial77/lampor/commits/main.atom"
const ARCHIVE_URL: String = "https://codeload.github.com/Reyofficial77/lampor/zip/"
const UPDATE_CONFIG_PATH: String = "user://lampor_update.cfg"
const UPDATE_ROOT: String = "user://updates"
const FIX_NOTES_CACHE_PATH: String = "user://lampor_fix_notes.md"
const REQUIRED_UPDATE_FILES: PackedStringArray = ["project.godot", "scripts/autoload/UpdateManager.gd", "FIX_NOTES.md"]

var latest_commit: String = ""
var latest_message: String = ""
var installed_commit: String = BUILD_COMMIT
var has_update: bool = false
var is_checking: bool = false
var is_downloading: bool = false
var using_atom_fallback: bool = false
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
	download_request.timeout = 300.0
	download_request.max_redirects = 12
	download_request.use_threads = true
	add_child(download_request)
	download_request.request_completed.connect(_on_download_request_completed)
	_load_update_state()

func _load_update_state() -> void:
	var config := ConfigFile.new()
	if config.load(UPDATE_CONFIG_PATH) == OK:
		installed_commit = str(config.get_value("update", "installed_commit", config.get_value("update", "processed_commit", BUILD_COMMIT)))

func _save_update_state() -> void:
	var config := ConfigFile.new()
	config.set_value("update", "installed_commit", installed_commit)
	config.save(UPDATE_CONFIG_PATH)

func check_for_updates(force: bool = false) -> void:
	if is_checking or is_downloading:
		return
	if not force and not has_update and not installed_commit.is_empty():
		return
	is_checking = true
	using_atom_fallback = false
	last_error = ""
	latest_commit = ""
	latest_message = ""
	var headers: PackedStringArray = ["User-Agent: Lampor-Game", "Accept: application/vnd.github+json", "X-GitHub-Api-Version: 2022-11-28"]
	var request_error: Error = api_request.request(API_URL, headers)
	if request_error != OK:
		_request_atom_fallback(HTTPRequest.RESULT_CANT_CONNECT)

func _request_atom_fallback(previous_result: int) -> void:
	using_atom_fallback = true
	var headers: PackedStringArray = ["User-Agent: Lampor-Game", "Accept: application/atom+xml"]
	var request_error: Error = fallback_request.request(ATOM_URL, headers)
	if request_error != OK:
		using_atom_fallback = false
		is_checking = false
		_fail(_format_network_error(previous_result, 0, "GitHub API dan jalur alternatif"))

func download_update() -> void:
	if is_downloading:
		return
	if latest_commit.is_empty():
		check_for_updates(true)
		return
	if not _can_write_project_source():
		_fail("Pemasangan sinkronisasi source hanya dapat dilakukan pada folder proyek Godot yang dapat ditulis. APK Android/EXE hasil ekspor tidak dapat mengubah isi APK/PCK yang sedang berjalan; jangan menandai update sebagai berhasil.")
		return
	if is_update_processed():
		up_to_date.emit(latest_commit)
		return
	var update_dir: String = ProjectSettings.globalize_path(UPDATE_ROOT)
	var make_dir_error: Error = DirAccess.make_dir_recursive_absolute(update_dir)
	if make_dir_error != OK and make_dir_error != ERR_ALREADY_EXISTS:
		_fail("Folder sementara update tidak dapat dibuat (kode %d)." % make_dir_error)
		return
	downloaded_path = update_dir.path_join("lampor-%s.zip" % latest_commit.substr(0, 10))
	if FileAccess.file_exists(downloaded_path):
		DirAccess.remove_absolute(downloaded_path)
	download_request.download_file = downloaded_path
	var headers: PackedStringArray = ["User-Agent: Lampor-Game", "Accept: application/zip"]
	var request_error: Error = download_request.request(ARCHIVE_URL + latest_commit, headers)
	if request_error != OK:
		download_request.download_file = ""
		_fail("Tidak dapat memulai unduhan update (kode %d)." % request_error)
		return
	is_downloading = true

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
	var message: String = "Commit terbaru dari GitHub"
	var title_regex := RegEx.new()
	if title_regex.compile("(?s)<entry>.*?<title>(.*?)</title>") == OK:
		var title_match: RegExMatch = title_regex.search(feed_text)
		if title_match:
			message = title_match.get_string(1).strip_edges()
	_handle_latest_commit(matches[0].get_string(1), message)

func _handle_latest_commit(commit_sha: String, commit_message: String) -> void:
	latest_commit = commit_sha.strip_edges()
	latest_message = commit_message
	if latest_commit.is_empty():
		_fail("GitHub tidak mengembalikan identitas commit.")
		return
	has_update = latest_commit != installed_commit
	if has_update:
		update_available.emit(latest_commit, latest_message)
		if SettingsManager.auto_update:
			download_update()
	else:
		up_to_date.emit(latest_commit)

func _on_download_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	is_downloading = false
	download_request.download_file = ""
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200 or not FileAccess.file_exists(downloaded_path):
		if FileAccess.file_exists(downloaded_path):
			DirAccess.remove_absolute(downloaded_path)
		_fail(_format_network_error(result, response_code, "unduhan paket update"))
		return
	var archive_bytes: PackedByteArray = FileAccess.get_file_as_bytes(downloaded_path)
	if archive_bytes.size() < 4 or archive_bytes[0] != 0x50 or archive_bytes[1] != 0x4B:
		DirAccess.remove_absolute(downloaded_path)
		_fail("Server tidak mengirim arsip ZIP yang valid. Update dibatalkan.")
		return
	_install_update_archive()

func _install_update_archive() -> void:
	var staging_path: String = UPDATE_ROOT.path_join("staging-%s" % latest_commit.substr(0, 10))
	var staging_absolute: String = ProjectSettings.globalize_path(staging_path)
	_remove_directory_recursive(staging_absolute)
	var extract_result: Error = _extract_zip_safely(downloaded_path, staging_absolute)
	if extract_result != OK:
		_remove_directory_recursive(staging_absolute)
		_fail("Paket update tidak dapat diekstrak dengan aman (kode %d). Arsip proyek tidak diubah." % extract_result)
		return
	for required_path in REQUIRED_UPDATE_FILES:
		if not FileAccess.file_exists(staging_absolute.path_join(required_path)):
			_remove_directory_recursive(staging_absolute)
			_fail("Update ditolak: file wajib %s tidak ada di commit GitHub. Tambahkan FIX_NOTES.md dan updater sinkronisasi penuh ke branch main sebelum update dapat diterapkan." % required_path)
			return
	var staged_updater: String = FileAccess.get_file_as_string(staging_absolute.path_join("scripts/autoload/UpdateManager.gd"))
	if not staged_updater.contains("const FULL_TREE_SYNC_VERSION: int = 1") or not staged_updater.contains("func _apply_staged_project"):
		_remove_directory_recursive(staging_absolute)
		_fail("Update ditolak untuk mencegah updater rusak: branch main masih berisi updater versi lama. Commit UpdateManager.gd versi full-sync ini ke repository terlebih dahulu.")
		return
	var notes_text: String = FileAccess.get_file_as_string(staging_absolute.path_join("FIX_NOTES.md"))
	if notes_text.strip_edges().is_empty():
		_remove_directory_recursive(staging_absolute)
		_fail("Update ditolak: FIX_NOTES.md kosong. Setiap commit update wajib menyertakan catatan perubahan Markdown.")
		return
	var project_root: String = ProjectSettings.globalize_path("res://")
	if not _apply_staged_project(staging_absolute, project_root):
		_remove_directory_recursive(staging_absolute)
		return
	# Cache is outside the project tree so the repo mirror remains exact.
	_write_absolute_file(ProjectSettings.globalize_path(FIX_NOTES_CACHE_PATH), notes_text.to_utf8_buffer())
	_remove_directory_recursive(staging_absolute)
	if FileAccess.file_exists(downloaded_path):
		DirAccess.remove_absolute(downloaded_path)
	downloaded_path = ""
	installed_commit = latest_commit
	_save_update_state()
	has_update = false
	update_installed.emit(project_root, latest_commit, true)

func _extract_zip_safely(archive_path: String, destination_root: String) -> Error:
	var reader := ZIPReader.new()
	var open_error: Error = reader.open(archive_path)
	if open_error != OK:
		return open_error
	var entries: PackedStringArray = reader.get_files()
	var archive_prefix: String = ""
	for entry in entries:
		if entry.ends_with("/"):
			continue
		var parts: PackedStringArray = entry.split("/", false)
		if parts.size() > 1:
			archive_prefix = parts[0] + "/"
			break
	var found_manifest: bool = false
	var write_error: Error = DirAccess.make_dir_recursive_absolute(destination_root)
	if write_error != OK and write_error != ERR_ALREADY_EXISTS:
		reader.close()
		return write_error
	for entry in entries:
		var relative_path: String = entry
		if not archive_prefix.is_empty() and relative_path.begins_with(archive_prefix):
			relative_path = relative_path.substr(archive_prefix.length())
		if relative_path.is_empty():
			continue
		if relative_path.contains("\\") or relative_path.contains(":") or relative_path.begins_with("/"):
			write_error = ERR_INVALID_DATA
			break
		var segments: PackedStringArray = relative_path.split("/", false)
		if segments.has("..") or segments.has(".") or segments.has(""):
			write_error = ERR_INVALID_DATA
			break
		if segments.has(".git") or segments.has(".godot"):
			continue
		var target_path: String = destination_root.path_join(relative_path.trim_suffix("/"))
		if entry.ends_with("/"):
			var dir_error: Error = DirAccess.make_dir_recursive_absolute(target_path)
			if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
				write_error = dir_error
				break
			continue
		var bytes: PackedByteArray = reader.read_file(entry)
		if relative_path == "project.godot":
			found_manifest = true
		var make_dir_error: Error = DirAccess.make_dir_recursive_absolute(target_path.get_base_dir())
		if make_dir_error != OK and make_dir_error != ERR_ALREADY_EXISTS:
			write_error = make_dir_error
			break
		var file := FileAccess.open(target_path, FileAccess.WRITE)
		if file == null:
			write_error = FileAccess.get_open_error()
			break
		file.store_buffer(bytes)
		var file_error: Error = file.get_error()
		file.close()
		if file_error != OK:
			write_error = file_error
			break
	reader.close()
	if write_error != OK:
		return write_error
	if not found_manifest:
		return ERR_FILE_NOT_FOUND
	return OK

func _can_write_project_source() -> bool:
	var root: String = ProjectSettings.globalize_path("res://")
	if not FileAccess.file_exists(root.path_join("project.godot")) or not DirAccess.dir_exists_absolute(root.path_join("scripts")):
		return false
	var probe_path: String = root.path_join(".lampor_update_write_test")
	var probe := FileAccess.open(probe_path, FileAccess.WRITE)
	if probe == null:
		return false
	probe.close()
	DirAccess.remove_absolute(probe_path)
	return true

func is_update_processed() -> bool:
	return not latest_commit.is_empty() and installed_commit == latest_commit

func _apply_staged_project(staging_root: String, project_root: String) -> bool:
	var incoming_files: Array[String] = []
	var original_files: Array[String] = []
	_collect_files_recursive(staging_root, "", incoming_files)
	_collect_files_recursive(project_root, "", original_files)
	incoming_files.sort()
	original_files.sort()
	var backup_root: String = OS.get_user_data_dir().path_join("updates/backups/%s" % latest_commit)
	_remove_directory_recursive(backup_root)
	for relative_path in original_files:
		var old_bytes: PackedByteArray = FileAccess.get_file_as_bytes(project_root.path_join(relative_path))
		if not _write_absolute_file(backup_root.path_join(relative_path), old_bytes):
			_fail("Backup gagal dibuat untuk %s. Tidak ada file proyek yang diubah." % relative_path)
			return false
	# Hapus seluruh file proyek lama kecuali isi .git dan .godot.
	for relative_path in original_files:
		var delete_error: Error = DirAccess.remove_absolute(project_root.path_join(relative_path))
		if delete_error != OK and delete_error != ERR_DOES_NOT_EXIST:
			_rollback_project(project_root, backup_root, original_files)
			_fail("Tidak dapat menghapus file lama %s (kode %d). Proyek dipulihkan dari backup." % [relative_path, delete_error])
			return false
	_remove_empty_directories_recursive(project_root)
	# Salin seluruh tree dari commit. Ini sekaligus menambahkan, mengubah, dan menyelaraskan file.
	for relative_path in incoming_files:
		var source_path: String = staging_root.path_join(relative_path)
		var target_path: String = project_root.path_join(relative_path)
		if not _write_absolute_file(target_path, FileAccess.get_file_as_bytes(source_path)):
			_rollback_project(project_root, backup_root, original_files)
			_fail("Gagal memasang %s. Semua file lama dipulihkan dari backup." % relative_path)
			return false
	return true

func _rollback_project(project_root: String, backup_root: String, original_files: Array[String]) -> void:
	var current_files: Array[String] = []
	_collect_files_recursive(project_root, "", current_files)
	for relative_path in current_files:
		DirAccess.remove_absolute(project_root.path_join(relative_path))
	_remove_empty_directories_recursive(project_root)
	for relative_path in original_files:
		var backup_path: String = backup_root.path_join(relative_path)
		if FileAccess.file_exists(backup_path):
			_write_absolute_file(project_root.path_join(relative_path), FileAccess.get_file_as_bytes(backup_path))

func _collect_files_recursive(directory_path: String, relative_prefix: String, output: Array[String]) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	directory.include_hidden = true
	for file_name in directory.get_files():
		var relative_file: String = relative_prefix.path_join(file_name) if not relative_prefix.is_empty() else file_name
		var segments: PackedStringArray = relative_file.split("/", false)
		if segments.has(".git") or segments.has(".godot"):
			continue
		output.append(relative_file)
	for directory_name in directory.get_directories():
		if directory_name in [".git", ".godot"]:
			continue
		var child_relative: String = relative_prefix.path_join(directory_name) if not relative_prefix.is_empty() else directory_name
		_collect_files_recursive(directory_path.path_join(directory_name), child_relative, output)

func _remove_empty_directories_recursive(directory_path: String) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	directory.include_hidden = true
	for directory_name in directory.get_directories():
		if directory_name in [".git", ".godot"]:
			continue
		var child_path: String = directory_path.path_join(directory_name)
		_remove_empty_directories_recursive(child_path)
		var child := DirAccess.open(child_path)
		if child != null and child.get_files().is_empty() and child.get_directories().is_empty():
			DirAccess.remove_absolute(child_path)

func _write_absolute_file(path: String, bytes: PackedByteArray) -> bool:
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	var write_error: Error = file.get_error()
	file.close()
	return write_error == OK

func _remove_directory_recursive(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.include_hidden = true
	for file_name in directory.get_files():
		DirAccess.remove_absolute(path.path_join(file_name))
	for directory_name in directory.get_directories():
		_remove_directory_recursive(path.path_join(directory_name))
	DirAccess.remove_absolute(path)

func get_fix_notes_markdown() -> String:
	if FileAccess.file_exists("res://FIX_NOTES.md"):
		return FileAccess.get_file_as_string("res://FIX_NOTES.md")
	if FileAccess.file_exists(FIX_NOTES_CACHE_PATH):
		return FileAccess.get_file_as_string(FIX_NOTES_CACHE_PATH)
	return "# Catatan Pembaruan\n\nBelum ada `FIX_NOTES.md` pada paket game ini. Repository wajib menyertakan file tersebut pada setiap commit update."

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
			detail = "File sementara unduhan tidak dapat dibuka. Periksa ruang penyimpanan."
		HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
			detail = "File unduhan gagal ditulis. Periksa ruang penyimpanan."
		HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED:
			detail = "Server terlalu banyak mengalihkan permintaan."
		_:
			detail = "Kesalahan transport jaringan (kode %d)." % result
	var message: String = "%s gagal. %s" % [service, detail]
	if response_code == 0:
		message += " HTTP 0 bukan status GitHub; koneksi gagal sebelum menerima header HTTP."
	if OS.has_feature("android"):
		message += " Pastikan permission INTERNET aktif pada Android Export Preset."
	return message

func _fail(message: String) -> void:
	is_checking = false
	is_downloading = false
	using_atom_fallback = false
	if download_request:
		download_request.download_file = ""
	last_error = message
	update_failed.emit(message)

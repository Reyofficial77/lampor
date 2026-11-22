extends Node

const REDEMPTION_CODES = preload("res://scripts/systems/RedemptionCodes.gd")
const ADMIN_PANEL_SCRIPT = preload("res://scripts/ui/AdminPanel.gd")
const LocScript = preload("res://scripts/systems/Loc.gd")

# Game Manager Singleton

enum GameState { MENU, PLAYING, PAUSED, GAMEOVER, VICTORY }
var current_state: GameState = GameState.MENU

enum Act { BABAK_1, BABAK_2, BABAK_3 }
var current_act: Act = Act.BABAK_1

enum Difficulty { EASY, NORMAL, HARD, NIGHTMARE }
var selected_difficulty: Difficulty = Difficulty.NORMAL

# Time management (01:00 to 05:00)
var current_hour: int = 1
var current_minute: int = 0
var time_accumulator: float = 0.0
var dawn_reached: bool = false

# 1 game minute = 3.0 real seconds for Normal mode (scaled per difficulty)
var seconds_per_game_minute: float = 3.0

# Objectives tracking
var torches_lit: int = 0
const REQUIRED_TORCHES: int = 5

var doors_barricaded: int = 0
const REQUIRED_BARRICADES: int = 3

var ritual_items: Dictionary = {
	"Kemenyan": false,
	"Bunga Tujuh Rupa": false,
	"Keris Pusaka": false,
	"Tanah Kuburan": false
}
const TOTAL_RITUAL_ITEMS: int = 4

var furnace_burning: bool = false
var furnace_time_left: float = 45.0
var furnace_total_time: float = 45.0
var last_furnace_elapsed_sec: int = -1
const FURNACE_TOTAL_TIME: float = 45.0

var player_character: Node = null
var last_death_reason: String = ""
var death_sequence_active: bool = false
var victory_sequence_active: bool = false

# Save Data
var total_wins: int = 0
var coins: int = 0
var extra_lives: int = 0
const MAX_COINS: int = 999999999
const MAX_EXTRA_LIVES: int = 5
const MAX_SHOP_ITEM_QTY: int = 5
var item_stash: Dictionary = {"jamu": 0, "baterai": 0, "energy_drink": 0, "kentongan": 0}
var redeemed_codes: Array[String] = []
var run_reward_awarded: bool = false
var last_run_coin_reward: int = 0
const WIN_COIN_REWARD: int = 120
const LOSS_COIN_REWARD: int = 25
const SAVE_PATH: String = "user://lampor_save.json"
const SAVE_TEMP_PATH: String = "user://lampor_save.json.tmp"
const SAVE_BACKUP_PATH: String = "user://lampor_save.json.bak"
const WEB_SAVE_STORAGE_KEY: String = "lampor_save_v1"
const SETTINGS_CONFIG_PATH: String = "user://lampor_settings.cfg"
const RUN_SAVE_PATH: String = "user://lampor_run.json"
const RUN_SAVE_TEMP_PATH: String = "user://lampor_run.json.tmp"
const RUN_SAVE_BACKUP_PATH: String = "user://lampor_run.json.bak"
const AUTOSAVE_INTERVAL: float = 5.0
var autosave_elapsed: float = 0.0
var autosave_last_success_unix: int = 0
var has_saved_run_cache: bool = false
var is_resuming_saved_run: bool = false
var tutorial_completed: bool = false
var is_tutorial_mode: bool = false
var install_tutorial_state: String = ""
var tutorial_origin_version: String = ""
var tutorial_origin_commit: String = ""
var admin_god_mode: bool = false
var admin_panel: CanvasLayer = null
var save_seq: int = 0
var _save_load_failed: bool = false
var _web_save_sync_pending: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_save_data()
	has_saved_run_cache = not _read_run_snapshot().is_empty()
	SignalBus.torch_lit.connect(_on_torch_lit)
	SignalBus.ritual_item_collected.connect(_on_ritual_item_collected)
	SignalBus.player_death_requested.connect(_on_player_death_requested)
	SettingsManager.language_changed.connect(_on_language_changed)
	call_deferred("_setup_admin_panel")
	if OS.has_feature("web"):
		call_deferred("_schedule_web_save_reconcile")

func _on_language_changed(_lang: String) -> void:
	if current_state == GameState.PLAYING or current_state == GameState.PAUSED:
		SignalBus.act_started.emit(get_current_act_number(), get_current_act_title())
		broadcast_all_objectives()

func _setup_admin_panel() -> void:
	if admin_panel == null and ADMIN_PANEL_SCRIPT != null:
		admin_panel = ADMIN_PANEL_SCRIPT.new()
		add_child(admin_panel)

func _read_save_dict_from_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var raw: String = file.get_as_text()
	file.close()
	return _parse_save_dict_text(raw)

func _parse_save_dict_text(raw: String) -> Dictionary:
	if raw.strip_edges().is_empty():
		return {}
	var json := JSON.new()
	if json.parse(raw) != OK or not (json.data is Dictionary):
		return {}
	return json.data as Dictionary

func _read_save_dict_from_web_storage() -> Dictionary:
	if not OS.has_feature("web"):
		return {}
	var js_code: String = """(function(){
		try {
			var v = window.localStorage.getItem('%s');
			if (!v) return '';
			var bytes = new TextEncoder().encode(v);
			var bin = '';
			for (var i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
			return btoa(bin);
		} catch (e) { return ''; }
	})()""" % WEB_SAVE_STORAGE_KEY
	var b64: Variant = JavaScriptBridge.eval(js_code)
	if not (b64 is String) or (b64 as String).is_empty():
		return {}
	return _parse_save_dict_text(Marshalls.base64_to_utf8(b64 as String))

func _mirror_save_to_web_storage(json_text: String) -> void:
	if not OS.has_feature("web") or json_text.is_empty():
		return
	var b64: String = Marshalls.utf8_to_base64(json_text)
	var js_code: String = """(function(){
		try {
			var bin = atob('%s');
			var bytes = new Uint8Array(bin.length);
			for (var i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
			var txt = new TextDecoder('utf-8').decode(bytes);
			window.localStorage.setItem('%s', txt);
		} catch (e) {}
	})()""" % [b64, WEB_SAVE_STORAGE_KEY]
	JavaScriptBridge.eval(js_code)

func _sync_web_save_idbfs() -> void:
	if not OS.has_feature("web") or _web_save_sync_pending:
		return
	_web_save_sync_pending = true
	JavaScriptBridge.eval("""(function(){
		try {
			if (typeof FS !== 'undefined' && typeof FS.syncfs === 'function') {
				FS.syncfs(false, function(err){});
			}
		} catch (e) {}
	})()""")
	get_tree().create_timer(0.25, true, false, true).timeout.connect(func() -> void:
		_web_save_sync_pending = false
	)

func _pick_best_save_candidate() -> Dictionary:
	var candidates: Array[Dictionary] = []
	var primary: Dictionary = _read_save_dict_from_file(SAVE_PATH)
	var backup: Dictionary = _read_save_dict_from_file(SAVE_BACKUP_PATH)
	var web_data: Dictionary = _read_save_dict_from_web_storage()
	for cand: Dictionary in [primary, backup, web_data]:
		if not cand.is_empty():
			candidates.append(cand)
	if candidates.is_empty():
		return {}
	var best: Dictionary = candidates[0]
	var best_seq: int = int(best.get("save_seq", 0))
	var best_score: int = int(best.get("coins", 0)) + int(best.get("total_wins", 0)) * 1000 + int(best.get("extra_lives", 0)) * 100
	for i: int in range(1, candidates.size()):
		var c: Dictionary = candidates[i]
		var c_seq: int = int(c.get("save_seq", 0))
		var c_score: int = int(c.get("coins", 0)) + int(c.get("total_wins", 0)) * 1000 + int(c.get("extra_lives", 0)) * 100
		if c_seq > best_seq or (c_seq == best_seq and c_score > best_score):
			best = c
			best_seq = c_seq
			best_score = c_score
	return best

func _schedule_web_save_reconcile() -> void:
	if not OS.has_feature("web"):
		return
	await get_tree().create_timer(0.75, true, false, true).timeout
	var disk_cand: Dictionary = _read_save_dict_from_file(SAVE_PATH)
	if disk_cand.is_empty():
		disk_cand = _read_save_dict_from_file(SAVE_BACKUP_PATH)
	if disk_cand.is_empty():
		return
	var disk_seq: int = int(disk_cand.get("save_seq", 0))
	var disk_coins: int = clampi(int(disk_cand.get("coins", 0)), 0, MAX_COINS)
	if disk_seq > save_seq or (save_seq <= 1 and coins == 0 and disk_coins > 0):
		load_save_data()
		SignalBus.coins_changed.emit(coins)

func load_save_data() -> void:
	var current_version: String = str(ProjectSettings.get_setting("application/config/version", ""))
	var current_commit: String = UpdateManager.BUILD_COMMIT
	var has_prior_footprint: bool = UpdateManager.had_prior_user_data \
		or UpdateManager.updated_on_this_boot \
		or UpdateManager.pck_loaded_this_session \
		or FileAccess.file_exists(SETTINGS_CONFIG_PATH) \
		or FileAccess.file_exists(SAVE_BACKUP_PATH) \
		or not _read_run_snapshot().is_empty()

	_save_load_failed = false
	var primary_exists: bool = FileAccess.file_exists(SAVE_PATH)
	var data: Dictionary = _pick_best_save_candidate()
	if data.is_empty():
		if primary_exists:
			# Primary save existed on disk but could not be opened/parsed cleanly: do not overwrite with 0 coins!
			_save_load_failed = true
			tutorial_completed = true
			install_tutorial_state = "skipped_on_update"
			push_warning("[GameManager] Save utama tidak dapat dibaca; menunda penimpaan agar koin tidak ter-reset.")
			return
		total_wins = 0
		coins = 0
		extra_lives = 0
		save_seq = 0
		if has_prior_footprint:
			tutorial_completed = true
			install_tutorial_state = "skipped_on_update"
		else:
			tutorial_completed = false
			install_tutorial_state = "fresh_pending"
			tutorial_origin_version = current_version
			tutorial_origin_commit = current_commit
		save_game_data()
		return

	save_seq = maxi(save_seq, int(data.get("save_seq", 0)))
	total_wins = maxi(0, int(data.get("total_wins", 0)))
	var raw_coins: int = int(data.get("coins", 0))
	if raw_coins < 0 or raw_coins > MAX_COINS:
		raw_coins = MAX_COINS if raw_coins < 0 else clampi(raw_coins, 0, MAX_COINS)
	coins = clampi(raw_coins, 0, MAX_COINS)
	extra_lives = clampi(int(data.get("extra_lives", 0)), 0, MAX_EXTRA_LIVES)
	var saved_stash: Variant = data.get("item_stash", {})
	if saved_stash is Dictionary:
		item_stash["jamu"] = clampi(int(saved_stash.get("jamu", 0)), 0, MAX_SHOP_ITEM_QTY)
		item_stash["baterai"] = clampi(int(saved_stash.get("baterai", 0)), 0, MAX_SHOP_ITEM_QTY)
		item_stash["energy_drink"] = clampi(int(saved_stash.get("energy_drink", 0)), 0, MAX_SHOP_ITEM_QTY)
		item_stash["kentongan"] = clampi(int(saved_stash.get("kentongan", 0)), 0, MAX_SHOP_ITEM_QTY)
	var saved_codes: Variant = data.get("redeemed_codes", [])
	if saved_codes is Array:
		for code: Variant in saved_codes:
			var normalized: String = str(code).to_upper()
			if not normalized.is_empty() and not redeemed_codes.has(normalized):
				redeemed_codes.append(normalized)

	var saved_tutorial_done: bool = bool(data.get("tutorial_completed", false))
	var saved_tutorial_state: String = str(data.get("install_tutorial_state", ""))
	tutorial_origin_version = str(data.get("tutorial_origin_version", ""))
	tutorial_origin_commit = str(data.get("tutorial_origin_commit", ""))

	var needs_migration_save: bool = not primary_exists
	if saved_tutorial_state == "admin_forced":
		tutorial_completed = saved_tutorial_done
		install_tutorial_state = "admin_forced"
	elif saved_tutorial_state.is_empty():
		tutorial_completed = true
		install_tutorial_state = "completed" if saved_tutorial_done else "skipped_on_update"
		needs_migration_save = true
	elif saved_tutorial_done or saved_tutorial_state == "completed" or saved_tutorial_state == "skipped_on_update":
		tutorial_completed = true
		install_tutorial_state = "completed" if saved_tutorial_done else saved_tutorial_state
	elif saved_tutorial_state == "fresh_pending":
		var is_updated_build: bool = UpdateManager.updated_on_this_boot \
			or UpdateManager.pck_loaded_this_session \
			or (not tutorial_origin_version.is_empty() and tutorial_origin_version != current_version) \
			or (not tutorial_origin_commit.is_empty() and tutorial_origin_commit != current_commit)
		if is_updated_build or total_wins > 0:
			tutorial_completed = true
			install_tutorial_state = "skipped_on_update"
			needs_migration_save = true
		else:
			tutorial_completed = false
			install_tutorial_state = "fresh_pending"
	else:
		tutorial_completed = true
		install_tutorial_state = "skipped_on_update"
		needs_migration_save = true

	if needs_migration_save:
		save_game_data()

func save_game_data() -> void:
	coins = clampi(coins, 0, MAX_COINS)
	var disk_best: Dictionary = _pick_best_save_candidate()
	if not disk_best.is_empty():
		var disk_seq: int = int(disk_best.get("save_seq", 0))
		if _save_load_failed and coins == 0 and int(disk_best.get("coins", 0)) > 0:
			push_warning("[GameManager] Mencegah save kosong menimpa data koin yang tersimpan.")
			return
		save_seq = maxi(save_seq, disk_seq)
	_save_load_failed = false
	save_seq += 1
	var data: Dictionary = {
		"save_version": 2,
		"save_seq": save_seq,
		"total_wins": total_wins,
		"coins": coins,
		"extra_lives": extra_lives,
		"tutorial_completed": tutorial_completed,
		"install_tutorial_state": install_tutorial_state,
		"tutorial_origin_version": tutorial_origin_version,
		"tutorial_origin_commit": tutorial_origin_commit,
		"item_stash": item_stash,
		"redeemed_codes": redeemed_codes
	}
	var json_text: String = JSON.stringify(data)
	var temp_file: FileAccess = FileAccess.open(SAVE_TEMP_PATH, FileAccess.WRITE)
	if temp_file == null:
		push_warning("[GameManager] Gagal membuka file save sementara: %s" % FileAccess.get_open_error())
		return
	temp_file.store_string(json_text)
	temp_file.flush()
	temp_file.close()

	var save_abs: String = ProjectSettings.globalize_path(SAVE_PATH)
	var temp_abs: String = ProjectSettings.globalize_path(SAVE_TEMP_PATH)
	var backup_abs: String = ProjectSettings.globalize_path(SAVE_BACKUP_PATH)
	if FileAccess.file_exists(SAVE_PATH):
		if FileAccess.file_exists(SAVE_BACKUP_PATH):
			DirAccess.remove_absolute(backup_abs)
		var backup_err: Error = DirAccess.rename_absolute(save_abs, backup_abs)
		if backup_err != OK:
			push_warning("[GameManager] Gagal memindahkan cadangan save: %d" % backup_err)
			return
	var commit_err: Error = DirAccess.rename_absolute(temp_abs, save_abs)
	if commit_err != OK:
		if FileAccess.file_exists(SAVE_BACKUP_PATH) and not FileAccess.file_exists(SAVE_PATH):
			DirAccess.rename_absolute(backup_abs, save_abs)
		push_warning("[GameManager] Gagal memasang save baru: %d" % commit_err)
		return
	if not FileAccess.file_exists(SAVE_BACKUP_PATH):
		var bak_file: FileAccess = FileAccess.open(SAVE_BACKUP_PATH, FileAccess.WRITE)
		if bak_file != null:
			bak_file.store_string(json_text)
			bak_file.flush()
			bak_file.close()

	if OS.has_feature("web"):
		_mirror_save_to_web_storage(json_text)
		_sync_web_save_idbfs()

func mark_tutorial_completed() -> void:
	if not tutorial_completed or install_tutorial_state != "completed":
		tutorial_completed = true
		install_tutorial_state = "completed"
		save_game_data()

func set_tutorial_completed_override(completed: bool) -> void:
	tutorial_completed = completed
	install_tutorial_state = "completed" if completed else "admin_forced"
	save_game_data()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		# Flush a final checkpoint when Android backgrounds the app or the user exits.
		save_active_run()
		save_game_data()

func _read_snapshot_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	var parse_error: Error = json.parse(file.get_as_text())
	file.close()
	if parse_error != OK or not json.data is Dictionary:
		return {}
	var snapshot: Dictionary = json.data
	if int(snapshot.get("run_version", 0)) != 1 or not snapshot.has("player"):
		return {}
	return snapshot

func _read_run_snapshot() -> Dictionary:
	# Pulihkan cadangan jika proses aplikasi terhenti saat file utama ditulis.
	for path: String in [RUN_SAVE_PATH, RUN_SAVE_TEMP_PATH, RUN_SAVE_BACKUP_PATH]:
		var snapshot: Dictionary = _read_snapshot_file(path)
		if not snapshot.is_empty():
			return snapshot
	return {}

func _write_run_snapshot(snapshot: Dictionary) -> bool:
	var temp_file: FileAccess = FileAccess.open(RUN_SAVE_TEMP_PATH, FileAccess.WRITE)
	if temp_file == null:
		push_warning("[GameManager] Gagal membuka file autosave sementara: %s" % FileAccess.get_open_error())
		return false
	temp_file.store_string(JSON.stringify(snapshot))
	temp_file.flush()
	temp_file.close()
	var save_absolute: String = ProjectSettings.globalize_path(RUN_SAVE_PATH)
	var temp_absolute: String = ProjectSettings.globalize_path(RUN_SAVE_TEMP_PATH)
	var backup_absolute: String = ProjectSettings.globalize_path(RUN_SAVE_BACKUP_PATH)
	if FileAccess.file_exists(RUN_SAVE_BACKUP_PATH):
		DirAccess.remove_absolute(backup_absolute)
	if FileAccess.file_exists(RUN_SAVE_PATH):
		var backup_error: Error = DirAccess.rename_absolute(save_absolute, backup_absolute)
		if backup_error != OK:
			push_warning("[GameManager] Gagal membuat cadangan autosave: %d" % backup_error)
			return false
	var commit_error: Error = DirAccess.rename_absolute(temp_absolute, save_absolute)
	if commit_error != OK:
		if FileAccess.file_exists(RUN_SAVE_BACKUP_PATH) and not FileAccess.file_exists(RUN_SAVE_PATH):
			DirAccess.rename_absolute(backup_absolute, save_absolute)
		push_warning("[GameManager] Gagal memasang autosave baru: %d" % commit_error)
		return false
	if FileAccess.file_exists(RUN_SAVE_BACKUP_PATH):
		DirAccess.remove_absolute(backup_absolute)
	return true

func has_saved_run() -> bool:
	var snapshot: Dictionary = _read_run_snapshot()
	has_saved_run_cache = not snapshot.is_empty()
	return has_saved_run_cache

func clear_run_save() -> void:
	for path: String in [RUN_SAVE_PATH, RUN_SAVE_TEMP_PATH, RUN_SAVE_BACKUP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	has_saved_run_cache = false
	autosave_elapsed = 0.0

func _vector3_to_array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _array_to_vector3(value: Variant, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return fallback

func _capture_world_snapshot(world_root: Node) -> Dictionary:
	var world_data: Dictionary = {"torches": [], "doors": [], "pickups": [], "lampor": []}
	for node: Node in get_tree().get_nodes_in_group("torch"):
		if node is SafeZoneTorch and world_root.is_ancestor_of(node):
			var torch: SafeZoneTorch = node as SafeZoneTorch
			world_data["torches"].append({"path": str(world_root.get_path_to(torch)), "is_lit": torch.is_lit})
	for node: Node in get_tree().get_nodes_in_group("interactable"):
		if node is Door and world_root.is_ancestor_of(node):
			var door: Door = node as Door
			world_data["doors"].append({"path": str(world_root.get_path_to(door)), "is_open": door.is_open, "is_barricaded": door.is_barricaded})
		elif node is PickupItem and world_root.is_ancestor_of(node):
			var item: PickupItem = node as PickupItem
			var entry: Dictionary = {
				"path": str(world_root.get_path_to(item)),
				"item_id": item.item_id,
				"item_name": item.item_name,
				"item_type": item.item_type,
				"is_ritual_item": item.is_ritual_item,
				"ritual_display_name": item.ritual_display_name,
				"position": _vector3_to_array(item.global_position),
				"dynamic": item.has_meta("autosave_dynamic")
			}
			world_data["pickups"].append(entry)
	for node: Node in get_tree().get_nodes_in_group("lampor"):
		if node is LamporStateMachine and world_root.is_ancestor_of(node):
			var lampor: LamporStateMachine = node as LamporStateMachine
			world_data["lampor"].append({
				"path": str(world_root.get_path_to(lampor)),
				"position": _vector3_to_array(lampor.global_position),
				"rotation": _vector3_to_array(lampor.rotation),
				"state": int(lampor.current_state),
				"waypoint": lampor.current_waypoint_idx,
				"target": _vector3_to_array(lampor.target_position),
				"chase_timer": lampor.chase_timer,
				"lost_sight_timer": lampor.lost_sight_timer,
				"chase_cooldown": lampor.chase_cooldown,
				"stare_timer": lampor.stare_timer,
				"stare_punish_timer": lampor.stare_punish_timer,
				"repel_timer": lampor.repel_timer,
				"hover_time": lampor.hover_time
			})
	return world_data

func save_active_run() -> bool:
	if current_state != GameState.PLAYING or not is_instance_valid(player_character) or not (player_character is PlayerController):
		return false
	var player: PlayerController = player_character as PlayerController
	if player.is_caught:
		return false
	var world_root: Node = get_tree().current_scene
	if world_root == null or world_root.scene_file_path != "res://scenes/world/VillageMap.tscn":
		return false
	var save_position: Vector3 = player.global_position
	if player.is_hiding and is_instance_valid(player.hiding_spot) and player.hiding_spot.has_node("ExitPoint"):
		save_position = (player.hiding_spot.get_node("ExitPoint") as Node3D).global_position
	var house_path: String = ""
	if is_instance_valid(player.current_house):
		house_path = str(world_root.get_path_to(player.current_house))
	var inventory_data: Array = []
	var active_slot: int = 0
	if is_instance_valid(player.inventory_system):
		inventory_data = player.inventory_system.slots.duplicate(true)
		active_slot = player.inventory_system.active_slot
	var snapshot: Dictionary = {
		"run_version": 1,
		"saved_at": Time.get_unix_time_from_system(),
		"selected_difficulty": int(selected_difficulty),
		"is_tutorial_mode": is_tutorial_mode,
		"current_act": int(current_act),
		"current_hour": current_hour,
		"current_minute": current_minute,
		"time_accumulator": time_accumulator,
		"dawn_reached": dawn_reached,
		"torches_lit": torches_lit,
		"doors_barricaded": doors_barricaded,
		"ritual_items": ritual_items.duplicate(true),
		"furnace_burning": furnace_burning,
		"furnace_time_left": furnace_time_left,
		"player": {
			"position": _vector3_to_array(save_position),
			"rotation_y": player.rotation.y,
			"head_pitch": player.head.rotation.x,
			"stamina": player.current_stamina,
			"sanity": player.sanity_system.current_sanity,
			"flashlight_battery": player.flashlight_battery,
			"flashlight_on": player.flashlight_on,
			"energy_drink_timer": player.energy_drink_timer,
			"energy_drink_cooldown": player.energy_drink_cooldown,
			"inventory": inventory_data,
			"active_slot": active_slot,
			"inside_house": player.is_inside_house,
			"house_path": house_path
		},
		"world": _capture_world_snapshot(world_root)
	}
	if not _write_run_snapshot(snapshot):
		return false
	has_saved_run_cache = true
	autosave_last_success_unix = int(Time.get_unix_time_from_system())
	return true

func _saved_difficulty(value: int) -> Difficulty:
	match clampi(value, Difficulty.EASY, Difficulty.NIGHTMARE):
		Difficulty.EASY: return Difficulty.EASY
		Difficulty.NORMAL: return Difficulty.NORMAL
		Difficulty.HARD: return Difficulty.HARD
		Difficulty.NIGHTMARE: return Difficulty.NIGHTMARE
	return Difficulty.NORMAL

func _saved_act(value: int) -> Act:
	match clampi(value, Act.BABAK_1, Act.BABAK_3):
		Act.BABAK_1: return Act.BABAK_1
		Act.BABAK_2: return Act.BABAK_2
		Act.BABAK_3: return Act.BABAK_3
	return Act.BABAK_1

func resume_saved_game() -> void:
	var snapshot: Dictionary = _read_run_snapshot()
	if snapshot.is_empty():
		clear_run_save()
		return
	selected_difficulty = _saved_difficulty(int(snapshot.get("selected_difficulty", Difficulty.NORMAL)))
	is_tutorial_mode = bool(snapshot.get("is_tutorial_mode", false))
	seconds_per_game_minute = get_seconds_per_minute_for_difficulty(selected_difficulty)
	furnace_total_time = get_furnace_duration_for_difficulty(selected_difficulty)
	current_act = _saved_act(int(snapshot.get("current_act", Act.BABAK_1)))
	current_hour = clampi(int(snapshot.get("current_hour", 1)), 1, 5)
	current_minute = clampi(int(snapshot.get("current_minute", 0)), 0, 59)
	time_accumulator = maxf(0.0, float(snapshot.get("time_accumulator", 0.0)))
	dawn_reached = bool(snapshot.get("dawn_reached", false))
	if current_act == Act.BABAK_2:
		_fast_forward_clock_to(2, 30)
	elif current_act == Act.BABAK_3:
		_fast_forward_clock_to(4, 0)
	torches_lit = clampi(int(snapshot.get("torches_lit", 0)), 0, REQUIRED_TORCHES)
	doors_barricaded = clampi(int(snapshot.get("doors_barricaded", 0)), 0, REQUIRED_BARRICADES)
	var saved_ritual: Variant = snapshot.get("ritual_items", {})
	for ritual_name: String in ritual_items.keys():
		ritual_items[ritual_name] = bool(saved_ritual.get(ritual_name, false)) if saved_ritual is Dictionary else false
	furnace_burning = bool(snapshot.get("furnace_burning", false))
	furnace_time_left = clampf(float(snapshot.get("furnace_time_left", furnace_total_time)), 0.0, furnace_total_time)
	last_furnace_elapsed_sec = int(furnace_total_time - furnace_time_left) if furnace_burning else -1
	death_sequence_active = false
	victory_sequence_active = false
	last_death_reason = ""
	is_resuming_saved_run = true
	current_state = GameState.PLAYING
	get_tree().paused = false
	var scene_error: Error = get_tree().change_scene_to_file("res://scenes/world/VillageMap.tscn")
	if scene_error != OK:
		var packed_map: PackedScene = load("res://scenes/world/VillageMap.tscn") as PackedScene
		if packed_map != null:
			scene_error = get_tree().change_scene_to_packed(packed_map)
	if scene_error != OK:
		is_resuming_saved_run = false
		current_state = GameState.MENU
		push_error("[GameManager] Gagal memuat map untuk melanjutkan permainan: %d" % scene_error)
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var world_root: Node = get_tree().current_scene
	if world_root == null:
		is_resuming_saved_run = false
		current_state = GameState.MENU
		return
	_restore_world_snapshot(world_root, snapshot.get("world", {}))
	_restore_player_snapshot(world_root, snapshot.get("player", {}))
	_broadcast_resumed_run_state()
	_restore_lampor_snapshot(world_root, snapshot.get("world", {}))
	is_resuming_saved_run = false
	autosave_elapsed = 0.0

func _restore_world_snapshot(world_root: Node, raw_world: Variant) -> void:
	if not raw_world is Dictionary:
		return
	var world_data: Dictionary = raw_world
	for entry: Variant in world_data.get("torches", []):
		if not entry is Dictionary:
			continue
		var torch: SafeZoneTorch = world_root.get_node_or_null(NodePath(str(entry.get("path", "")))) as SafeZoneTorch
		if torch:
			torch.is_lit = bool(entry.get("is_lit", false))
			torch._update_visuals()
	for entry: Variant in world_data.get("doors", []):
		if not entry is Dictionary:
			continue
		var door: Door = world_root.get_node_or_null(NodePath(str(entry.get("path", "")))) as Door
		if door:
			door.is_open = bool(entry.get("is_open", false))
			door.is_barricaded = bool(entry.get("is_barricaded", false))
			door.target_rotation_y = deg_to_rad(door.open_angle) if door.is_open else 0.0
			door.hinge.rotation.y = door.target_rotation_y
			if door.barricade_visual:
				door.barricade_visual.visible = door.is_barricaded
			door._update_blocker()
	var saved_static_pickups: Dictionary = {}
	var saved_dynamic_pickups: Array = []
	for entry: Variant in world_data.get("pickups", []):
		if not entry is Dictionary:
			continue
		if bool(entry.get("dynamic", false)):
			saved_dynamic_pickups.append(entry)
		else:
			saved_static_pickups[str(entry.get("path", ""))] = entry
	for node: Node in get_tree().get_nodes_in_group("interactable"):
		if not node is PickupItem or not world_root.is_ancestor_of(node):
			continue
		var item: PickupItem = node as PickupItem
		if item.has_meta("autosave_dynamic"):
			item.queue_free()
			continue
		var node_path: String = str(world_root.get_path_to(item))
		if not saved_static_pickups.has(node_path):
			item.queue_free()
			continue
		var saved_item: Dictionary = saved_static_pickups[node_path]
		item.global_position = _array_to_vector3(saved_item.get("position", []), item.global_position)
		item.is_picked_up = false
	for entry: Dictionary in saved_dynamic_pickups:
		var pickup_scene: PackedScene = load("res://scenes/items/PickupItem.tscn") as PackedScene
		if pickup_scene == null:
			continue
		var item: PickupItem = pickup_scene.instantiate() as PickupItem
		if item == null:
			continue
		item.item_id = str(entry.get("item_id", "minyak_tanah"))
		item.item_name = str(entry.get("item_name", "Barang"))
		item.item_type = str(entry.get("item_type", "resource"))
		item.is_ritual_item = bool(entry.get("is_ritual_item", false))
		item.ritual_display_name = str(entry.get("ritual_display_name", ""))
		item.set_meta("autosave_dynamic", true)
		world_root.add_child(item)
		item.global_position = _array_to_vector3(entry.get("position", []), Vector3.ZERO)

func _restore_lampor_snapshot(world_root: Node, raw_world: Variant) -> void:
	if not raw_world is Dictionary:
		return
	var lampor_entries: Variant = raw_world.get("lampor", [])
	if not lampor_entries is Array or lampor_entries.is_empty():
		return
	for entry: Variant in lampor_entries:
		if not entry is Dictionary:
			continue
		var lampor: LamporStateMachine = world_root.get_node_or_null(NodePath(str(entry.get("path", "")))) as LamporStateMachine
		if lampor == null:
			continue
		lampor.global_position = _array_to_vector3(entry.get("position", []), lampor.global_position)
		lampor.rotation = _array_to_vector3(entry.get("rotation", []), lampor.rotation)
		var saved_state_number: int = int(entry.get("state", LamporStateMachine.State.PATROL))
		# Tween descent tidak diserialisasi; lanjutkan dari posisi tersimpan sebagai patroli.
		if saved_state_number == LamporStateMachine.State.DESCENDING:
			saved_state_number = LamporStateMachine.State.PATROL
		var restored_state: LamporStateMachine.State = LamporStateMachine.State.PATROL
		match saved_state_number:
			LamporStateMachine.State.DORMANT_SKY: restored_state = LamporStateMachine.State.DORMANT_SKY
			LamporStateMachine.State.PATROL: restored_state = LamporStateMachine.State.PATROL
			LamporStateMachine.State.INVESTIGATE: restored_state = LamporStateMachine.State.INVESTIGATE
			LamporStateMachine.State.STARE_PUNISHMENT: restored_state = LamporStateMachine.State.STARE_PUNISHMENT
			LamporStateMachine.State.CHASE: restored_state = LamporStateMachine.State.CHASE
			LamporStateMachine.State.REPELLED: restored_state = LamporStateMachine.State.REPELLED
			LamporStateMachine.State.BANISHED: restored_state = LamporStateMachine.State.BANISHED
		lampor.is_descending = false
		lampor.is_catching = false
		lampor.current_waypoint_idx = clampi(int(entry.get("waypoint", 0)), 0, maxi(0, lampor.waypoints.size() - 1))
		lampor.target_position = _array_to_vector3(entry.get("target", []), lampor.target_position)
		lampor._set_state(restored_state)
		lampor.chase_timer = maxf(0.0, float(entry.get("chase_timer", 0.0)))
		lampor.lost_sight_timer = maxf(0.0, float(entry.get("lost_sight_timer", 0.0)))
		lampor.chase_cooldown = maxf(0.0, float(entry.get("chase_cooldown", 0.0)))
		lampor.stare_timer = maxf(0.0, float(entry.get("stare_timer", 0.0)))
		lampor.stare_punish_timer = maxf(0.0, float(entry.get("stare_punish_timer", 0.0)))
		lampor.repel_timer = maxf(0.0, float(entry.get("repel_timer", 0.0)))
		lampor.hover_time = maxf(0.0, float(entry.get("hover_time", 0.0)))
		lampor.velocity = Vector3.ZERO
		if lampor.collision_shape:
			lampor.collision_shape.disabled = restored_state == LamporStateMachine.State.DORMANT_SKY

func _restore_player_snapshot(world_root: Node, raw_player: Variant) -> void:
	if not raw_player is Dictionary:
		return
	var saved_player: Dictionary = raw_player
	var player: PlayerController = get_tree().get_first_node_in_group("player") as PlayerController
	if player == null:
		return
	player.global_position = _array_to_vector3(saved_player.get("position", []), player.global_position)
	player.rotation.y = float(saved_player.get("rotation_y", player.rotation.y))
	player.head.rotation.x = clampf(float(saved_player.get("head_pitch", 0.0)), deg_to_rad(-80.0), deg_to_rad(80.0))
	player.velocity = Vector3.ZERO
	player.current_stamina = clampf(float(saved_player.get("stamina", 100.0)), 0.0, player.max_stamina)
	player.sanity_system.current_sanity = clampf(float(saved_player.get("sanity", 100.0)), 0.0, player.sanity_system.max_sanity)
	player.flashlight_battery = clampf(float(saved_player.get("flashlight_battery", 100.0)), 0.0, 100.0)
	player.flashlight_preferred_on = bool(saved_player.get("flashlight_on", true))
	player.flashlight_on = player.flashlight_preferred_on and player.flashlight_battery > 0.0
	player.flashlight.visible = player.flashlight_on
	player.energy_drink_timer = clampf(float(saved_player.get("energy_drink_timer", 0.0)), 0.0, PlayerController.ENERGY_DRINK_DURATION)
	player.energy_drink_cooldown = clampf(float(saved_player.get("energy_drink_cooldown", 0.0)), 0.0, PlayerController.ENERGY_DRINK_COOLDOWN)
	player.is_hiding = false
	player.hiding_spot = null
	player.is_inside_house = bool(saved_player.get("inside_house", false))
	var house_path: String = str(saved_player.get("house_path", ""))
	player.current_house = world_root.get_node_or_null(NodePath(house_path)) if not house_path.is_empty() else null
	var saved_inventory: Variant = saved_player.get("inventory", [])
	if saved_inventory is Array and is_instance_valid(player.inventory_system):
		player.inventory_system.slots = saved_inventory.duplicate(true)
		player.inventory_system.slots.resize(InventorySystem.TOTAL_SLOTS)
		for i in range(InventorySystem.TOTAL_SLOTS):
			if player.inventory_system.slots[i] == null:
				player.inventory_system.slots[i] = {}
		player.inventory_system.active_slot = clampi(int(saved_player.get("active_slot", 0)), 0, InventorySystem.HOTBAR_SLOTS - 1)
		SignalBus.inventory_updated.emit(player.inventory_system.slots)
		SignalBus.item_equipped.emit(player.inventory_system.active_slot, player.inventory_system.get_equipped_item())
	SignalBus.player_sanity_changed.emit(player.sanity_system.current_sanity, player.sanity_system.max_sanity)
	SignalBus.player_stamina_changed.emit(player.current_stamina, player.max_stamina)
	SignalBus.flashlight_battery_changed.emit(player.flashlight_battery, 100.0)
	SignalBus.flashlight_toggled.emit(player.flashlight_on)

func get_current_act_number() -> int:
	match current_act:
		Act.BABAK_1: return 1
		Act.BABAK_2: return 2
		Act.BABAK_3: return 3
	return 1

func get_current_act_title() -> String:
	match current_act:
		Act.BABAK_1:
			return LocScript.pick("Babak I: Pertahanan Awal (01.00 - 02.30)", "Act I: Early Defense (01:00 - 02:30)")
		Act.BABAK_2:
			if current_hour >= 4:
				return LocScript.pick("Babak II: Ritual Pemutus Kutukan (02.30 - 05.00)", "Act II: Curse-Breaking Ritual (02:30 - 05:00)")
			return LocScript.pick("Babak II: Ritual Pemutus Kutukan (02.30 - 04.00)", "Act II: Curse-Breaking Ritual (02:30 - 04:00)")
		Act.BABAK_3:
			return LocScript.pick("Babak III: Klimaks Pembakaran (04.00 - 05.00)", "Act III: Burning Climax (04:00 - 05:00)")
	return LocScript.pick("Babak I: Pertahanan Awal (01.00 - 02.30)", "Act I: Early Defense (01:00 - 02:30)")

func get_current_objectives_data() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	match current_act:
		Act.BABAK_1:
			list.append({
				"id": "torches",
				"text": LocScript.pick("Nyalakan 5 Obor Penolak Bala", "Light 5 Repellent Torches"),
				"current": torches_lit,
				"required": REQUIRED_TORCHES,
				"completed": torches_lit >= REQUIRED_TORCHES
			})
			list.append({
				"id": "barricades",
				"text": LocScript.pick("Barikade 3 Pintu Rumah dengan Papan & Paku", "Barricade 3 House Doors with Planks & Nails"),
				"current": doors_barricaded,
				"required": REQUIRED_BARRICADES,
				"completed": doors_barricaded >= REQUIRED_BARRICADES
			})
		Act.BABAK_2:
			var ritual_count: int = get_ritual_item_count()
			list.append({
				"id": "ritual_items",
				"text": LocScript.pick("Kumpulkan 4 Benda Ritual (Kemenyan, Bunga 7 Rupa, Keris, Tanah)", "Collect 4 Ritual Relics (Incense, Flowers, Keris, Soil)"),
				"current": ritual_count,
				"required": TOTAL_RITUAL_ITEMS,
				"completed": ritual_count >= TOTAL_RITUAL_ITEMS
			})
			list.append({
				"id": "beware_lampor",
				"text": LocScript.pick("Hati-hati: Lampor berpatroli! Dilarang menatap langsung!", "Beware: Lampor is patrolling! Never stare directly!"),
				"current": 0,
				"required": 1,
				"completed": false
			})
		Act.BABAK_3:
			var survive_elapsed: int = clampi(int(furnace_total_time - furnace_time_left), 0, int(furnace_total_time)) if furnace_burning else 0
			list.append({
				"id": "burn_ritual",
				"text": LocScript.pick("Bakar semua benda ritual di Tungku Balai Desa", "Burn all ritual relics at the Village Hall Furnace"),
				"current": 1 if furnace_burning else 0,
				"required": 1,
				"completed": furnace_burning
			})
			list.append({
				"id": "survive_furnace",
				"text": LocScript.pick("Bertahan hidup dari amukan Lampor hingga ritual selesai", "Survive Lampor's fury until the ritual finishes"),
				"current": survive_elapsed,
				"required": int(furnace_total_time),
				"completed": furnace_burning and furnace_time_left <= 0.0
			})
	return list

func broadcast_all_objectives() -> void:
	for obj: Dictionary in get_current_objectives_data():
		SignalBus.objective_updated.emit(
			str(obj.get("id", "")),
			str(obj.get("text", "")),
			int(obj.get("current", 0)),
			int(obj.get("required", 1)),
			bool(obj.get("completed", false))
		)

func _broadcast_resumed_run_state() -> void:
	SignalBus.time_tick.emit("%02d:%02d" % [current_hour, current_minute], current_hour, current_minute)
	SignalBus.act_started.emit(get_current_act_number(), get_current_act_title())
	broadcast_all_objectives()
	if current_act >= Act.BABAK_2:
		SignalBus.lampor_state_changed.emit("CHASE" if furnace_burning else "PATROL")
	if furnace_burning:
		SignalBus.furnace_progress_updated.emit(furnace_time_left, furnace_total_time)

func purchase_shop_item(item_id: String, quantity: int = 1) -> Dictionary:
	var safe_quantity: int = clampi(quantity, 1, 3)
	var price: int = 0
	match item_id:
		"jamu":
			price = 30 * safe_quantity
		"baterai":
			price = 20 * safe_quantity
		"energy_drink":
			price = 25 * safe_quantity
		"kentongan":
			price = 250 * safe_quantity
		"extra_life":
			price = 80 if safe_quantity == 1 else (150 if safe_quantity == 2 else 210)
		_:
			return {"success": false, "message": LocScript.pick("Item tidak tersedia di toko.", "Item is not available in the shop.")}

	# Periksa batas maksimal kuantitas (maksimal 5 per item dan nyawa)
	if item_id == "extra_life":
		if extra_lives >= MAX_EXTRA_LIVES:
			return {"success": false, "message": LocScript.pick("Batas maksimal nyawa tambahan (%d) sudah tercapai." % MAX_EXTRA_LIVES, "Maximum extra lives limit (%d) reached." % MAX_EXTRA_LIVES)}
		if extra_lives + safe_quantity > MAX_EXTRA_LIVES:
			return {"success": false, "message": LocScript.pick("Pembelian melebihi batas maksimal %d nyawa (saat ini: %d)." % [MAX_EXTRA_LIVES, extra_lives], "Purchase exceeds maximum %d lives (current: %d)." % [MAX_EXTRA_LIVES, extra_lives])}
	else:
		var current_qty: int = int(item_stash.get(item_id, 0))
		if current_qty >= MAX_SHOP_ITEM_QTY:
			return {"success": false, "message": LocScript.pick("Batas maksimal persediaan (%d) untuk item ini sudah tercapai." % MAX_SHOP_ITEM_QTY, "Maximum stock (%d) for this item already reached." % MAX_SHOP_ITEM_QTY)}
		if current_qty + safe_quantity > MAX_SHOP_ITEM_QTY:
			return {"success": false, "message": LocScript.pick("Pembelian melebihi batas maksimal %d untuk item ini (saat ini: %d)." % [MAX_SHOP_ITEM_QTY, current_qty], "Purchase exceeds maximum %d for this item (current: %d)." % [MAX_SHOP_ITEM_QTY, current_qty])}

	if coins < price:
		return {"success": false, "message": LocScript.pick("Koin tidak cukup. Dibutuhkan %d koin." % price, "Not enough coins. Requires %d coins." % price)}
	coins -= price
	if item_id == "extra_life":
		extra_lives += safe_quantity
	else:
		item_stash[item_id] = maxi(0, int(item_stash.get(item_id, 0))) + safe_quantity
	save_game_data()
	var item_label: String = LocScript.item_name(item_id, item_id)
	return {"success": true, "message": LocScript.pick("%s x%d berhasil dibeli." % [item_label, safe_quantity], "%s x%d purchased." % [item_label, safe_quantity]), "price": price}

func redeem_code(raw_code: String) -> Dictionary:
	var codes_script: Variant = ResourceLoader.load("res://scripts/systems/RedemptionCodes.gd", "", ResourceLoader.CACHE_MODE_IGNORE)
	if codes_script == null:
		codes_script = REDEMPTION_CODES
	var normalized: String = codes_script.normalize_code(raw_code)
	if normalized.is_empty():
		return {"success": false, "message": LocScript.pick("Masukkan kode redeem terlebih dahulu.", "Enter a redeem code first.")}
	if redeemed_codes.has(normalized):
		return {"success": false, "message": LocScript.pick("Kode ini sudah pernah digunakan.", "This code has already been redeemed.")}
	var reward: Dictionary = codes_script.get_reward(normalized)
	if reward.is_empty():
		return {"success": false, "message": LocScript.pick("Kode redeem tidak valid.", "Invalid redeem code.")}
	apply_reward(reward)
	redeemed_codes.append(normalized)
	save_game_data()
	var desc: String = str(reward.get("description_en", reward.get("description", "Reward claimed"))) if LocScript.is_en() else str(reward.get("description", "Hadiah diterima"))
	return {"success": true, "message": LocScript.pick("Berhasil menukarkan kode: %s." % desc, "Redeemed code: %s." % desc)}

func apply_reward(reward: Dictionary) -> void:
	var quantity: int = maxi(1, int(reward.get("quantity", 1)))
	match str(reward.get("type", "")):
		"coins":
			coins = clampi(coins + quantity, 0, MAX_COINS)
		"lives":
			extra_lives = mini(MAX_EXTRA_LIVES, extra_lives + quantity)
		"item":
			var item_id: String = str(reward.get("item_id", ""))
			if item_id in ["jamu", "baterai", "energy_drink", "kentongan"]:
				item_stash[item_id] = mini(MAX_SHOP_ITEM_QTY, maxi(0, int(item_stash.get(item_id, 0))) + quantity)

func deliver_stored_items(inventory: Node) -> void:
	if is_resuming_saved_run:
		return
	if not is_instance_valid(inventory) or not inventory.has_method("add_item"):
		return
	var stash_changed: bool = false
	var stash_names: Dictionary = {
		"jamu": "Jamu Tolak Bala",
		"baterai": "Baterai Senter",
		"energy_drink": "Energy Drink",
		"kentongan": "Kentongan"
	}
	for item_id: String in ["jamu", "baterai", "energy_drink", "kentongan"]:
		var remaining: int = maxi(0, int(item_stash.get(item_id, 0)))
		if remaining <= 0:
			continue
		stash_changed = true
		var item_name: String = str(stash_names.get(item_id, "Barang"))
		# Batas maksimal yang dapat dibawa/digunakan saat permainan adalah 5
		var deliver_qty: int = mini(MAX_SHOP_ITEM_QTY, remaining)
		while deliver_qty > 0:
			var accepted: bool = bool(inventory.add_item({"id": item_id, "name": item_name, "type": "consumable", "quantity": 1}))
			if not accepted:
				break
			deliver_qty -= 1
			remaining -= 1
		item_stash[item_id] = remaining
	if stash_changed:
		save_game_data()

func _award_run_coins(amount: int) -> void:
	if run_reward_awarded:
		return
	run_reward_awarded = true
	last_run_coin_reward = maxi(0, amount)
	if coins < 0 or coins > MAX_COINS:
		coins = MAX_COINS
	coins = clampi(coins + last_run_coin_reward, 0, MAX_COINS)
	save_game_data()

func is_nightmare_unlocked() -> bool:
	return total_wins >= 5

func get_seconds_per_minute_for_difficulty(diff: Difficulty) -> float:
	match diff:
		Difficulty.EASY:
			return 4.5 # Waktu lebih santai
		Difficulty.NORMAL:
			return 3.0 # Standar sesuai permintaan user
		Difficulty.HARD:
			return 1.0 # Hard: 1 menit game = 1 detik nyata
		Difficulty.NIGHTMARE:
			return 0.5 # Nightmare: 1 menit game = 0,5 detik nyata
	return 3.0

# Durasi pembakaran ritual di Tungku Balai Desa disesuaikan secara proporsional
# dengan laju jam per tingkat kesulitan (~13-16 menit waktu game) agar pemain
# tidak terlahap batas pukul 05.00 WIB saat membakar di mode cepat (Hard/Nightmare).
func get_furnace_duration_for_difficulty(diff: Difficulty) -> float:
	match diff:
		Difficulty.EASY:
			return 60.0 # ~13,3 menit game (1 menit = 4,5 dtk)
		Difficulty.NORMAL:
			return 45.0 # 15 menit game (1 menit = 3,0 dtk)
		Difficulty.HARD:
			return 15.0 # 15 menit game (1 menit = 1,0 dtk)
		Difficulty.NIGHTMARE:
			return 8.0 # 16 menit game (1 menit = 0,5 dtk)
	return 45.0

func get_lampor_speeds_for_difficulty(diff: Difficulty) -> Dictionary:
	match diff:
		Difficulty.EASY:
			return { "patrol": 2.4, "chase": 4.8, "hearing": 18.0 }
		Difficulty.NORMAL:
			return { "patrol": 3.2, "chase": 6.8, "hearing": 24.0 }
		Difficulty.HARD:
			return { "patrol": 4.2, "chase": 8.8, "hearing": 30.0 }
		Difficulty.NIGHTMARE:
			return { "patrol": 5.4, "chase": 11.0, "hearing": 36.0 }
	return { "patrol": 3.2, "chase": 6.8, "hearing": 24.0 }

# Pengaturan sanity & senter per tingkat kesulitan.
# dark_light  = drain/detik di gelap saat senter MENYALA
# dark_dark   = drain/detik di gelap saat senter MATI
# prox        = drain maksimum/detik saat Lampor sangat dekat
# stare       = drain/detik saat menatap Lampor
# regen       = pemulihan/detik di zona aman (obor/tungku)
# house_dark  = pengali drain kegelapan saat berada di dalam rumah (0 = aman total)
# flash_drain = pengurasan baterai senter per detik
func get_sanity_settings_for_difficulty(diff: Difficulty) -> Dictionary:
	match diff:
		Difficulty.EASY:
			return {
				"dark_light": 0.02, "dark_dark": 0.12, "prox": 2.0, "stare": 8.0,
				"regen": 18.0, "house_dark": 0.0, "flash_drain": 0.14
			}
		Difficulty.HARD:
			return {
				"dark_light": 0.12, "dark_dark": 0.60, "prox": 4.5, "stare": 18.0,
				"regen": 12.0, "house_dark": 0.20, "flash_drain": 0.24
			}
		Difficulty.NIGHTMARE:
			return {
				"dark_light": 0.18, "dark_dark": 0.85, "prox": 6.0, "stare": 22.0,
				"regen": 10.0, "house_dark": 0.35, "flash_drain": 0.28
			}
	# NORMAL: seimbang untuk durasi permainan multi-babak
	return {
		"dark_light": 0.06, "dark_dark": 0.35, "prox": 3.2, "stare": 14.0,
		"regen": 15.0, "house_dark": 0.05, "flash_drain": 0.20
	}

func get_difficulty_name(diff: Difficulty) -> String:
	match diff:
		Difficulty.EASY: return "EASY"
		Difficulty.NORMAL: return "NORMAL"
		Difficulty.HARD: return "HARD"
		Difficulty.NIGHTMARE: return "NIGHTMARE"
	return "NORMAL"

func start_tutorial_game() -> void:
	start_new_game(Difficulty.EASY, true)

func start_new_game(diff: Difficulty = Difficulty.NORMAL, tutorial: bool = false) -> void:
	clear_run_save()
	is_resuming_saved_run = false
	is_tutorial_mode = tutorial
	selected_difficulty = diff
	run_reward_awarded = false
	last_run_coin_reward = 0
	seconds_per_game_minute = get_seconds_per_minute_for_difficulty(selected_difficulty)
	furnace_total_time = get_furnace_duration_for_difficulty(selected_difficulty)
	
	current_state = GameState.PLAYING
	current_act = Act.BABAK_1
	current_hour = 1
	current_minute = 0
	time_accumulator = 0.0
	dawn_reached = false
	torches_lit = 0
	doors_barricaded = 0
	furnace_burning = false
	furnace_time_left = furnace_total_time
	last_furnace_elapsed_sec = -1
	
	last_death_reason = ""
	death_sequence_active = false
	victory_sequence_active = false
	for k: String in ritual_items.keys():
		ritual_items[k] = false
		
	get_tree().paused = false
	var scene_error: Error = get_tree().change_scene_to_file("res://scenes/world/VillageMap.tscn")
	if scene_error != OK:
		var packed_map: PackedScene = load("res://scenes/world/VillageMap.tscn") as PackedScene
		if packed_map != null:
			scene_error = get_tree().change_scene_to_packed(packed_map)
	if scene_error != OK:
		current_state = GameState.MENU
		push_error("[GameManager] Gagal memuat map permainan: %d" % scene_error)
		return
	await get_tree().process_frame
	await get_tree().process_frame
	_enter_act_1()

func _sync_babak_1_progress() -> void:
	if current_act != Act.BABAK_1:
		return
	var world_root: Node = get_tree().current_scene
	if world_root == null or world_root.scene_file_path != "res://scenes/world/VillageMap.tscn":
		return
	var actual_torches: int = 0
	for node: Node in get_tree().get_nodes_in_group("torch"):
		if node is SafeZoneTorch and (node as SafeZoneTorch).is_lit:
			actual_torches += 1
	var actual_barricades: int = 0
	for node: Node in get_tree().get_nodes_in_group("interactable"):
		if node is Door and (node as Door).is_barricaded:
			actual_barricades += 1
	if actual_torches > torches_lit:
		torches_lit = actual_torches
		SignalBus.objective_updated.emit(
			"torches",
			"Nyalakan 5 Obor Penolak Bala",
			torches_lit,
			REQUIRED_TORCHES,
			torches_lit >= REQUIRED_TORCHES
		)
	if actual_barricades > doors_barricaded:
		doors_barricaded = actual_barricades
		SignalBus.objective_updated.emit(
			"barricades",
			"Barikade 3 Pintu Rumah dengan Papan & Paku",
			doors_barricaded,
			REQUIRED_BARRICADES,
			doors_barricaded >= REQUIRED_BARRICADES
		)

func _process(delta: float) -> void:
	if current_state == GameState.PLAYING:
		autosave_elapsed += delta
		if autosave_elapsed >= AUTOSAVE_INTERVAL:
			if save_active_run():
				autosave_elapsed = 0.0
			else:
				# Retry after roughly one second if the world is not ready or save I/O failed.
				autosave_elapsed = AUTOSAVE_INTERVAL - 1.0
	else:
		autosave_elapsed = 0.0
	if current_state != GameState.PLAYING or get_tree().paused:
		return
	if current_act == Act.BABAK_1:
		_sync_babak_1_progress()
		if torches_lit >= REQUIRED_TORCHES and doors_barricaded >= REQUIRED_BARRICADES:
			_enter_act_2()
	if not dawn_reached:
		time_accumulator += delta
		while time_accumulator >= seconds_per_game_minute and not dawn_reached:
			time_accumulator -= seconds_per_game_minute
			_advance_time(1)
	if furnace_burning:
		furnace_time_left = maxf(0.0, furnace_time_left - delta)
		SignalBus.furnace_progress_updated.emit(furnace_time_left, furnace_total_time)
		var elapsed_sec: int = clampi(int(furnace_total_time - furnace_time_left), 0, int(furnace_total_time))
		if elapsed_sec != last_furnace_elapsed_sec:
			last_furnace_elapsed_sec = elapsed_sec
			SignalBus.objective_updated.emit(
				"survive_furnace",
				LocScript.pick("Bertahan hidup dari amukan Lampor hingga ritual selesai", "Survive Lampor's fury until the ritual finishes"),
				elapsed_sec,
				int(furnace_total_time),
				furnace_time_left <= 0.0
			)
		if furnace_time_left <= 0.0:
			trigger_victory()

func _fast_forward_clock_to(target_hour: int, target_minute: int) -> bool:
	var current_total: int = current_hour * 60 + current_minute
	var target_total: int = target_hour * 60 + target_minute
	if current_total >= target_total:
		return false
	current_hour = target_hour
	current_minute = target_minute
	time_accumulator = 0.0
	dawn_reached = current_hour >= 5
	return true

func _sync_act_with_time(prev_hour: int) -> void:
	if current_act == Act.BABAK_1 and (current_hour * 60 + current_minute) >= (2 * 60 + 30):
		# Batas waktu tetap memajukan babak bila objektif Babak I belum selesai.
		_enter_act_2()
	if current_act == Act.BABAK_2 and current_hour >= 4:
		if get_ritual_item_count() >= TOTAL_RITUAL_ITEMS:
			_enter_act_3()
		elif prev_hour < 4 and not dawn_reached:
			SignalBus.dialog_requested.emit(LocScript.pick(
				"Pukul 04.00 WIB tiba! Segera lengkapi Benda Ritual sebelum pukul 05.00 WIB!",
				"It's 04:00 WIB! Gather the remaining Ritual Relics before 05:00 WIB!"
			), 4.0)

func _advance_time(minutes: int) -> void:
	if dawn_reached or current_state != GameState.PLAYING:
		return
	var prev_hour: int = current_hour
	current_minute += minutes
	while current_minute >= 60:
		current_minute -= 60
		current_hour += 1
	if current_hour >= 5:
		current_hour = 5
		current_minute = 0
		dawn_reached = true
	var time_str: String = "%02d:%02d" % [current_hour, current_minute]
	SignalBus.time_tick.emit(time_str, current_hour, current_minute)

	_sync_act_with_time(prev_hour)

	if not dawn_reached and current_hour > prev_hour:
		if current_hour == 2:
			var p2: Array[String] = LocScript.dialogue_pool("time_02")
			if not p2.is_empty():
				SignalBus.dialog_requested.emit(p2[0], 3.2)
		elif current_hour == 3:
			var p3: Array[String] = LocScript.dialogue_pool("time_03")
			if not p3.is_empty():
				SignalBus.dialog_requested.emit(p3[0], 3.2)

	if dawn_reached:
		trigger_dawn_lampor_devour()

func trigger_dawn_lampor_devour() -> void:
	if current_state != GameState.PLAYING or death_sequence_active:
		return
	if admin_god_mode:
		SignalBus.dialog_requested.emit(LocScript.pick(
			"[GOD MODE] Pukul 05.00 WIB terlewati tanpa dilahap Lampor.",
			"[GOD MODE] Passed 05:00 WIB without being devoured by Lampor."
		), 3.0)
		return
	furnace_burning = false
	_execute_player_death(LocScript.pick(
		"Waktu telah menunjukkan pukul 05.00 WIB sebelum ritual penolak bala tuntas! Keranda Lampor langsung melahap dan menyeret jiwamu ke dalam kegelapan abadi.",
		"05:00 WIB struck before the warding ritual was complete! Lampor's coffin devoured your soul into eternal darkness."
	), true, false)

func _enter_act_1() -> void:
	current_act = Act.BABAK_1
	SignalBus.time_tick.emit("%02d:%02d" % [current_hour, current_minute], current_hour, current_minute)
	SignalBus.act_started.emit(1, get_current_act_title())
	broadcast_all_objectives()
	if not is_resuming_saved_run and not is_tutorial_mode:
		SignalBus.dialog_requested.emit(LocScript.pick(
			"Malam mencekam dimulai... Nyalakan 5 obor penolak bala dan barikade 3 pintu sebelum pukul 02.30 WIB!",
			"The cursed night begins... Light 5 repellent torches and barricade 3 doors before 02:30 WIB!"
		), 4.0)

func _enter_act_2() -> void:
	if current_act >= Act.BABAK_2:
		return
	current_act = Act.BABAK_2
	# Jika semua misi Babak I selesai sebelum pukul 02.30, langsung fast-forward ke 02.30
	var fast_forwarded: bool = _fast_forward_clock_to(2, 30)
	SignalBus.time_tick.emit("%02d:%02d" % [current_hour, current_minute], current_hour, current_minute)
	if fast_forwarded:
		SignalBus.dialog_requested.emit(LocScript.pick(
			"Semua misi Babak I selesai! Waktu dipercepat ke 02.30 WIB — Babak II dimulai, Lampor turun ke desa!",
			"All Act I objectives complete! Time advances to 02:30 WIB — Act II begins, Lampor descends into the village!"
		), 4.0)
	else:
		SignalBus.dialog_requested.emit(LocScript.pick(
			"Lampor telah turun ke desa. Jangan menatap kerandanya!",
			"Lampor has descended into the village. Do not stare at its coffin!"
		), 3.5)
	# Sinkronkan waktu dan seluruh misi ke scene HUD yang aktif.
	SignalBus.act_started.emit(2, get_current_act_title())
	broadcast_all_objectives()

func _enter_act_3() -> void:
	if current_act == Act.BABAK_3:
		return
	current_act = Act.BABAK_3
	# Jika semua benda ritual terkumpul sebelum pukul 04.00, langsung fast-forward ke 04.00
	var fast_forwarded: bool = _fast_forward_clock_to(4, 0)
	SignalBus.time_tick.emit("%02d:%02d" % [current_hour, current_minute], current_hour, current_minute)
	if fast_forwarded:
		SignalBus.dialog_requested.emit(LocScript.pick(
			"Semua benda ritual terkumpul! Waktu dipercepat ke 04.00 WIB — Bakar semuanya di Tungku Balai Desa!",
			"All ritual relics gathered! Time advances to 04:00 WIB — Burn them all at the Village Hall Furnace!"
		), 4.0)
	else:
		SignalBus.dialog_requested.emit(LocScript.pick(
			"Waktunya memutus kutukan. Bakar semua benda ritual!",
			"Time to break the curse. Burn all ritual relics at the furnace!"
		), 3.5)
	SignalBus.act_started.emit(3, get_current_act_title())
	broadcast_all_objectives()

# Dipanggil altar saat pemain menekan [E]. Mengembalikan true jika ritual berjalan.
func try_start_ritual() -> bool:
	if furnace_burning:
		return true
	if get_ritual_item_count() < TOTAL_RITUAL_ITEMS:
		return false
	# Semua benda ritual sudah terkumpul tapi Babak 3 belum dimulai (misal benda
	# diambil lebih awal) -> majukan ke Babak 3 sekarang
	if current_act == Act.BABAK_2:
		_enter_act_3()
	if current_act != Act.BABAK_3:
		return false
	start_furnace_burning()
	return furnace_burning

func start_furnace_burning() -> void:
	if not furnace_burning and current_act == Act.BABAK_3:
		furnace_total_time = get_furnace_duration_for_difficulty(selected_difficulty)
		furnace_burning = true
		furnace_time_left = furnace_total_time
		last_furnace_elapsed_sec = 0
		broadcast_all_objectives()
		SignalBus.lampor_state_changed.emit("CHASE")

func _on_torch_lit(_torch_id: int, total_lit: int, _req: int) -> void:
	torches_lit = total_lit
	if current_act == Act.BABAK_1:
		SignalBus.objective_updated.emit(
			"torches",
			"Nyalakan 5 Obor Penolak Bala",
			torches_lit,
			REQUIRED_TORCHES,
			torches_lit >= REQUIRED_TORCHES
		)
	if current_act == Act.BABAK_1 and torches_lit >= REQUIRED_TORCHES and doors_barricaded >= REQUIRED_BARRICADES:
		_enter_act_2()
		return
	if total_lit == REQUIRED_TORCHES - 1:
		SignalBus.dialog_requested.emit(LocScript.pick(
			"Ayo semangat, sedikit lagi! Obor penolak bala sudah 4/5 menyala.",
			"Almost there! 4/5 repellent torches are now lit."
		), 3.2)
	elif total_lit >= REQUIRED_TORCHES:
		SignalBus.dialog_requested.emit(LocScript.pick(
			"Kelima obor telah menyala. Sekarang amankan pintu rumah!",
			"All 5 torches are lit! Now secure the remaining house doors!"
		), 3.2)

func record_door_barricaded() -> void:
	doors_barricaded += 1
	if current_act == Act.BABAK_1:
		SignalBus.objective_updated.emit(
			"barricades",
			LocScript.pick("Barikade 3 Pintu Rumah dengan Papan & Paku", "Barricade 3 House Doors with Planks & Nails"),
			doors_barricaded,
			REQUIRED_BARRICADES,
			doors_barricaded >= REQUIRED_BARRICADES
		)
	if current_act == Act.BABAK_1 and torches_lit >= REQUIRED_TORCHES and doors_barricaded >= REQUIRED_BARRICADES:
		_enter_act_2()
		return
	if doors_barricaded == REQUIRED_BARRICADES - 1:
		SignalBus.dialog_requested.emit(LocScript.pick(
			"Ayo semangat, sedikit lagi! Dua dari tiga pintu sudah diamankan.",
			"Keep going! Two out of three doors are now barricaded."
		), 3.2)
	elif doors_barricaded >= REQUIRED_BARRICADES:
		SignalBus.dialog_requested.emit(LocScript.pick(
			"Semua pintu penting sudah dibarikade. Nyalakan seluruh obor penolak bala!",
			"All key doors barricaded! Light every repellent torch!"
		), 3.2)

func record_door_unbarricaded() -> void:
	doors_barricaded = maxi(0, doors_barricaded - 1)
	if current_act == Act.BABAK_1:
		SignalBus.objective_updated.emit(
			"barricades",
			LocScript.pick("Barikade 3 Pintu Rumah dengan Papan & Paku", "Barricade 3 House Doors with Planks & Nails"),
			doors_barricaded,
			REQUIRED_BARRICADES,
			doors_barricaded >= REQUIRED_BARRICADES
		)

func _on_ritual_item_collected(item_name: String, count: int, total: int) -> void:
	ritual_items[item_name] = true
	if current_act == Act.BABAK_2:
		SignalBus.objective_updated.emit(
			"ritual_items",
			LocScript.pick("Kumpulkan 4 Benda Ritual (Kemenyan, Bunga 7 Rupa, Keris, Tanah)", "Collect 4 Ritual Relics (Incense, Flowers, Keris, Soil)"),
			count,
			total,
			count >= total
		)
	if count >= total and current_act == Act.BABAK_2:
		_enter_act_3()
		return
	if count == total - 1:
		SignalBus.dialog_requested.emit(LocScript.pick(
			"Tinggal satu benda ritual lagi. Jangan lengah, Lampor semakin dekat!",
			"Only one ritual relic left! Stay alert, Lampor draws nearer!"
		), 3.5)
	elif count >= total:
		SignalBus.dialog_requested.emit(LocScript.pick(
			"Semua benda ritual terkumpul. Kembali ke tungku balai desa!",
			"All ritual relics collected! Return to the Village Hall furnace!"
		), 3.5)

func get_ritual_item_count() -> int:
	var count: int = 0
	for collected: bool in ritual_items.values():
		if collected:
			count += 1
	return count

func trigger_victory() -> void:
	if victory_sequence_active or death_sequence_active or current_state == GameState.GAMEOVER or current_state == GameState.VICTORY:
		return
	victory_sequence_active = true
	furnace_burning = false
	clear_run_save()
	if is_tutorial_mode:
		mark_tutorial_completed()
	current_state = GameState.PAUSED
	get_tree().paused = true
	var world_root: Node = get_tree().current_scene
	var hud: Node = world_root.find_child("HUD", true, false) if is_instance_valid(world_root) else null
	if hud and hud.has_method("play_victory_cutscene_and_wait"):
		await hud.play_victory_cutscene_and_wait()
	if not is_inside_tree():
		victory_sequence_active = false
		return
	get_tree().paused = false
	current_state = GameState.VICTORY
	total_wins += 1
	_award_run_coins(WIN_COIN_REWARD)
	save_game_data()
	SignalBus.game_won.emit()
	victory_sequence_active = false
	get_tree().change_scene_to_file("res://scenes/ui/VictoryScreen.tscn")

# True jika kematian disebabkan Lampor (ditangkap keranda atau kewarasan habis
# karena Lampor). Dipakai untuk memutuskan apakah jumpscare dimainkan.
func is_lampor_kill(reason: String) -> bool:
	var lower: String = reason.to_lower()
	return lower.contains("keranda") or lower.contains("ditarik") or lower.contains("lampor") or lower.contains("dilahap")

func _on_player_death_requested(reason: String) -> void:
	_execute_player_death(reason, false, false)

func _execute_player_death(reason: String, ignore_extra_lives: bool = false, bypass_god_mode: bool = false) -> void:
	if death_sequence_active or victory_sequence_active or current_state == GameState.GAMEOVER or current_state == GameState.VICTORY:
		return
	if admin_god_mode and not bypass_god_mode:
		return
	death_sequence_active = true
	current_state = GameState.PAUSED
	last_death_reason = reason
	var keranda_kill: bool = is_lampor_kill(reason)
	# Hentikan simulasi dan input, tetapi biarkan autoload audio/visual berjalan.
	get_tree().paused = true
	if keranda_kill:
		await JumpscareManager.play_jumpscare_and_wait()
	else:
		await get_tree().create_timer(0.65, true).timeout
	if not is_inside_tree():
		death_sequence_active = false
		return
	# Nyawa tambahan menghidupkan kembali pemain di titik awal desa (kecuali batas pukul 05.00 atau force lose).
	if not ignore_extra_lives and extra_lives > 0 and is_instance_valid(player_character) and player_character.has_method("revive_from_extra_life"):
		extra_lives -= 1
		save_game_data()
		current_state = GameState.PLAYING
		player_character.revive_from_extra_life()
		for lampor_node: Node in get_tree().get_nodes_in_group("lampor"):
			if lampor_node.has_method("reset_after_player_revive"):
				lampor_node.reset_after_player_revive()
		get_tree().paused = false
		death_sequence_active = false
		SignalBus.dialog_requested.emit(LocScript.pick(
			"Nyawa tambahan terpakai! Kamu kembali ke desa. Sisa nyawa: %d" % extra_lives,
			"Extra life used! You returned to the village. Lives left: %d" % extra_lives
		), 4.0)
		return
	# Cutscene kekalahan: pemain diangkat dan dibawa pergi oleh Lampor sebelum layar kalah tampil.
	var world_root: Node = get_tree().current_scene
	var hud: Node = world_root.find_child("HUD", true, false) if is_instance_valid(world_root) else null
	if hud and hud.has_method("play_death_cutscene_and_wait"):
		await hud.play_death_cutscene_and_wait()
	if not is_inside_tree():
		death_sequence_active = false
		return
	# Koin kekalahan hanya diberikan ketika permainan benar-benar berakhir.
	if is_tutorial_mode:
		mark_tutorial_completed()
	_award_run_coins(LOSS_COIN_REWARD)
	clear_run_save()
	current_state = GameState.GAMEOVER
	SignalBus.player_died.emit(reason)
	SignalBus.game_over.emit(reason)
	get_tree().paused = false
	death_sequence_active = false
	get_tree().change_scene_to_file("res://scenes/ui/GameOverScreen.tscn")

# ---------- Fungsi Bantuan Admin & Tester Panel (Alt+F2) ----------

func is_in_active_gameplay() -> bool:
	var world_root: Node = get_tree().current_scene
	return world_root != null and world_root.scene_file_path == "res://scenes/world/VillageMap.tscn"

func admin_instant_win() -> bool:
	if not is_in_active_gameplay() or victory_sequence_active or death_sequence_active:
		return false
	get_tree().paused = false
	current_state = GameState.PLAYING
	trigger_victory()
	return true

func admin_instant_lose() -> bool:
	if not is_in_active_gameplay() or victory_sequence_active or death_sequence_active:
		return false
	get_tree().paused = false
	current_state = GameState.PLAYING
	_execute_player_death("Ditelan Keranda Lampor secara instan melalui Admin Panel.", true, true)
	return true

func admin_set_coins(new_coins: int) -> void:
	coins = clampi(new_coins, 0, MAX_COINS)
	save_game_data()

func admin_set_extra_lives(new_lives: int) -> void:
	extra_lives = clampi(new_lives, 0, MAX_EXTRA_LIVES)
	save_game_data()

func admin_set_total_wins(new_wins: int) -> void:
	total_wins = clampi(new_wins, 0, 999999)
	save_game_data()

func admin_set_time(hour: int, minute: int) -> bool:
	if not is_in_active_gameplay():
		return false
	var prev_hour: int = current_hour
	current_hour = clampi(hour, 1, 5)
	current_minute = clampi(minute, 0, 59)
	time_accumulator = 0.0
	dawn_reached = (current_hour >= 5)
	if dawn_reached:
		current_hour = 5
		current_minute = 0
	var time_str: String = "%02d:%02d" % [current_hour, current_minute]
	SignalBus.time_tick.emit(time_str, current_hour, current_minute)
	if dawn_reached:
		trigger_dawn_lampor_devour()
	else:
		_sync_act_with_time(prev_hour)
	return true

func admin_jump_to_act(target_act: int) -> bool:
	if not is_in_active_gameplay():
		return false
	if target_act <= 1:
		current_act = Act.BABAK_1
		current_hour = 1
		current_minute = 0
		time_accumulator = 0.0
		dawn_reached = false
		furnace_burning = false
		_enter_act_1()
	elif target_act == 2:
		admin_complete_babak_1_objectives()
		if current_act < Act.BABAK_2:
			_enter_act_2()
	elif target_act >= 3:
		admin_complete_babak_1_objectives()
		if current_act < Act.BABAK_2:
			_enter_act_2()
		admin_collect_all_ritual_items()
		if current_act < Act.BABAK_3:
			_enter_act_3()
	return true

func admin_complete_babak_1_objectives() -> void:
	for node: Node in get_tree().get_nodes_in_group("torch"):
		if node is SafeZoneTorch:
			var t := node as SafeZoneTorch
			t.is_lit = true
			t._update_visuals()
	torches_lit = REQUIRED_TORCHES
	var count_d: int = 0
	for node: Node in get_tree().get_nodes_in_group("interactable"):
		if node is Door and count_d < REQUIRED_BARRICADES:
			var d := node as Door
			d.is_open = false
			d.is_barricaded = true
			d.target_rotation_y = 0.0
			if d.hinge:
				d.hinge.rotation.y = 0.0
			if d.barricade_visual:
				d.barricade_visual.visible = true
			d._update_blocker()
			count_d += 1
	doors_barricaded = REQUIRED_BARRICADES
	broadcast_all_objectives()

func admin_collect_all_ritual_items() -> void:
	for k: String in ritual_items.keys():
		ritual_items[k] = true
	for node: Node in get_tree().get_nodes_in_group("interactable"):
		if node is PickupItem and (node as PickupItem).is_ritual_item:
			node.queue_free()
	SignalBus.ritual_item_collected.emit("Keris Pusaka", TOTAL_RITUAL_ITEMS, TOTAL_RITUAL_ITEMS)
	broadcast_all_objectives()

func admin_give_all_items() -> void:
	if not is_instance_valid(player_character):
		return
	var inv: InventorySystem = player_character.get_node_or_null("InventorySystem") as InventorySystem
	if not inv:
		return
	inv.add_item({"id": "minyak_tanah", "name": "Minyak Tanah & Korek", "type": "resource", "quantity": 5})
	inv.add_item({"id": "papan_paku", "name": "Papan & Paku", "type": "resource", "quantity": 4})
	inv.add_item({"id": "jamu", "name": "Jamu Tolak Bala", "type": "consumable", "quantity": 5})
	inv.add_item({"id": "baterai", "name": "Baterai Senter", "type": "consumable", "quantity": 5})
	inv.add_item({"id": "energy_drink", "name": "Energy Drink", "type": "consumable", "quantity": 5})
	inv.add_item({"id": "kentongan", "name": "Kentongan", "type": "consumable", "quantity": 5})

func admin_refill_player_stats() -> void:
	if not is_instance_valid(player_character) or not (player_character is PlayerController):
		return
	var pc := player_character as PlayerController
	pc.current_stamina = pc.max_stamina
	pc.flashlight_battery = 100.0
	if pc.sanity_system:
		pc.sanity_system.current_sanity = pc.sanity_system.max_sanity
		SignalBus.player_sanity_changed.emit(pc.sanity_system.current_sanity, pc.sanity_system.max_sanity)
	SignalBus.player_stamina_changed.emit(pc.current_stamina, pc.max_stamina)
	SignalBus.flashlight_battery_changed.emit(pc.flashlight_battery, 100.0)

func admin_teleport_to_altar() -> void:
	if not is_instance_valid(player_character) or not (player_character is PlayerController):
		return
	var world_root: Node = get_tree().current_scene
	if not world_root:
		return
	var altar: Node3D = world_root.find_child("RitualAltar", true, false) as Node3D
	if altar:
		var pc := player_character as PlayerController
		if pc.is_hiding:
			pc.exit_hiding()
		pc.global_position = altar.global_position + Vector3(0.0, 0.3, 2.2)
		pc.velocity = Vector3.ZERO

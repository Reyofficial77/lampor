extends Node

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
var furnace_time_left: float = 90.0
const FURNACE_TOTAL_TIME: float = 90.0

var player_character: Node = null

# Save Data
var total_wins: int = 0
const SAVE_PATH: String = "user://lampor_save.json"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_save_data()
	SignalBus.torch_lit.connect(_on_torch_lit)
	SignalBus.ritual_item_collected.connect(_on_ritual_item_collected)
	SignalBus.player_died.connect(_on_player_died)

func load_save_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		total_wins = 0
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var content: String = file.get_as_text()
		var json: JSON = JSON.new()
		var parse_result: Error = json.parse(content)
		if parse_result == OK and json.data is Dictionary:
			total_wins = int(json.data.get("total_wins", 0))

func save_game_data() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var data: Dictionary = {
			"total_wins": total_wins
		}
		file.store_string(JSON.stringify(data))

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
				"dark_light": 0.12, "dark_dark": 0.5, "prox": 3.5, "stare": 12.0,
				"regen": 16.0, "house_dark": 0.0, "flash_drain": 0.35
			}
	# NORMAL, HARD, NIGHTMARE: nilai standar
	return {
		"dark_light": 1.0, "dark_dark": 2.5, "prox": 8.0, "stare": 28.0,
		"regen": 12.0, "house_dark": 1.0, "flash_drain": 0.7
	}

func get_difficulty_name(diff: Difficulty) -> String:
	match diff:
		Difficulty.EASY: return "EASY"
		Difficulty.NORMAL: return "NORMAL"
		Difficulty.HARD: return "HARD"
		Difficulty.NIGHTMARE: return "NIGHTMARE"
	return "NORMAL"

func start_new_game(diff: Difficulty = Difficulty.NORMAL) -> void:
	selected_difficulty = diff
	seconds_per_game_minute = get_seconds_per_minute_for_difficulty(selected_difficulty)
	
	current_state = GameState.PLAYING
	current_act = Act.BABAK_1
	current_hour = 1
	current_minute = 0
	time_accumulator = 0.0
	torches_lit = 0
	doors_barricaded = 0
	furnace_burning = false
	furnace_time_left = FURNACE_TOTAL_TIME
	
	for k: String in ritual_items.keys():
		ritual_items[k] = false
		
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/world/VillageMap.tscn")
	
	await get_tree().create_timer(0.5).timeout
	_enter_act_1()

func _process(delta: float) -> void:
	# GameManager berjalan PROCESS_MODE_ALWAYS, jadi harus berhenti manual saat pause
	if current_state != GameState.PLAYING or get_tree().paused:
		return
		
	# Update in-game time
	time_accumulator += delta
	if time_accumulator >= seconds_per_game_minute:
		time_accumulator -= seconds_per_game_minute
		_advance_time(1)
		
	# Act 3 countdown
	if furnace_burning:
		furnace_time_left -= delta
		SignalBus.furnace_progress_updated.emit(max(0.0, furnace_time_left), FURNACE_TOTAL_TIME)
		if furnace_time_left <= 0.0:
			trigger_victory()

func _advance_time(minutes: int) -> void:
	current_minute += minutes
	if current_minute >= 60:
		current_minute -= 60
		current_hour += 1
		
	var time_str: String = "%02d:%02d" % [current_hour, current_minute]
	SignalBus.time_tick.emit(time_str, current_hour, current_minute)
	
	# Check time-based act triggers
	if current_act == Act.BABAK_1 and (current_hour > 2 or (current_hour == 2 and current_minute >= 30)):
		if torches_lit >= REQUIRED_TORCHES:
			_enter_act_2()
	elif current_act == Act.BABAK_2 and (current_hour >= 4):
		if get_ritual_item_count() >= TOTAL_RITUAL_ITEMS:
			_enter_act_3()
	elif current_hour >= 5:
		trigger_victory()

func _enter_act_1() -> void:
	current_act = Act.BABAK_1
	SignalBus.act_started.emit(1, "Babak I: Pertahanan Awal (01.00 - 02.30)")
	SignalBus.objective_updated.emit(
		"torches",
		"Nyalakan 5 Obor Penolak Bala",
		torches_lit,
		REQUIRED_TORCHES,
		torches_lit >= REQUIRED_TORCHES
	)
	SignalBus.objective_updated.emit(
		"barricades",
		"Barikade 3 Pintu Rumah dengan Papan & Paku",
		doors_barricaded,
		REQUIRED_BARRICADES,
		doors_barricaded >= REQUIRED_BARRICADES
	)

func _enter_act_2() -> void:
	current_act = Act.BABAK_2
	current_hour = 2
	current_minute = 30
	SignalBus.act_started.emit(2, "Babak II: Ritual Pemutus Kutukan (02.30 - 04.00)")
	SignalBus.objective_updated.emit(
		"ritual_items",
		"Kumpulkan 4 Benda Ritual (Kemenyan, Bunga 7 Rupa, Keris, Tanah)",
		get_ritual_item_count(),
		TOTAL_RITUAL_ITEMS,
		get_ritual_item_count() >= TOTAL_RITUAL_ITEMS
	)
	SignalBus.objective_updated.emit(
		"beware_lampor",
		"Hati-hati: Lampor berpatroli! Dilarang menatap langsung!",
		0,
		1,
		false
	)
	# Benda ritual yang sudah terkumpul sejak Babak 1 tidak boleh membuat ritual macet
	if get_ritual_item_count() >= TOTAL_RITUAL_ITEMS:
		_enter_act_3()

func _enter_act_3() -> void:
	if current_act == Act.BABAK_3:
		return
	current_act = Act.BABAK_3
	current_hour = 4
	current_minute = 0
	SignalBus.act_started.emit(3, "Babak III: Klimaks Pembakaran (04.00 - 05.00)")
	SignalBus.objective_updated.emit(
		"burn_ritual",
		"Bakar semua benda ritual di Tungku Balai Desa!",
		0,
		1,
		false
	)

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
		furnace_burning = true
		furnace_time_left = FURNACE_TOTAL_TIME
		SignalBus.objective_updated.emit(
			"survive_furnace",
			"Bertahan hidup dari amukan Lampor hingga fajar tiba!",
			int(FURNACE_TOTAL_TIME - furnace_time_left),
			int(FURNACE_TOTAL_TIME),
			false
		)
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
		if torches_lit >= REQUIRED_TORCHES and doors_barricaded >= REQUIRED_BARRICADES:
			_enter_act_2()

func record_door_barricaded() -> void:
	doors_barricaded += 1
	if current_act == Act.BABAK_1:
		SignalBus.objective_updated.emit(
			"barricades",
			"Barikade 3 Pintu Rumah dengan Papan & Paku",
			doors_barricaded,
			REQUIRED_BARRICADES,
			doors_barricaded >= REQUIRED_BARRICADES
		)
		if torches_lit >= REQUIRED_TORCHES and doors_barricaded >= REQUIRED_BARRICADES:
			_enter_act_2()

func record_door_unbarricaded() -> void:
	doors_barricaded = maxi(0, doors_barricaded - 1)
	if current_act == Act.BABAK_1:
		SignalBus.objective_updated.emit(
			"barricades",
			"Barikade 3 Pintu Rumah dengan Papan & Paku",
			doors_barricaded,
			REQUIRED_BARRICADES,
			doors_barricaded >= REQUIRED_BARRICADES
		)

func _on_ritual_item_collected(item_name: String, count: int, total: int) -> void:
	ritual_items[item_name] = true
	SignalBus.objective_updated.emit(
		"ritual_items",
		"Kumpulkan 4 Benda Ritual (Kemenyan, Bunga 7 Rupa, Keris, Tanah)",
		count,
		total,
		count >= total
	)
	if count >= total and current_act == Act.BABAK_2:
		_enter_act_3()

func get_ritual_item_count() -> int:
	var count: int = 0
	for collected: bool in ritual_items.values():
		if collected:
			count += 1
	return count

func trigger_victory() -> void:
	if current_state == GameState.GAMEOVER or current_state == GameState.VICTORY:
		return
	current_state = GameState.VICTORY
	total_wins += 1
	save_game_data()
	SignalBus.game_won.emit()
	get_tree().change_scene_to_file("res://scenes/ui/VictoryScreen.tscn")

func _on_player_died(reason: String) -> void:
	if current_state == GameState.GAMEOVER or current_state == GameState.VICTORY:
		return
	current_state = GameState.GAMEOVER
	SignalBus.game_over.emit(reason)
	await get_tree().create_timer(1.2).timeout
	get_tree().change_scene_to_file("res://scenes/ui/GameOverScreen.tscn")

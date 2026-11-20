class_name Door
extends Area3D

@export var is_open: bool = false
@export var is_barricaded: bool = false
@export var open_angle: float = 90.0

@onready var hinge: Node3D = $Hinge
@onready var blocker_collision: CollisionShape3D = $PhysicalBlocker/BlockerCollision
@onready var barricade_visual: Node3D = $Hinge/DoorMesh/BarricadeVisual

var target_rotation_y: float = 0.0

func _ready() -> void:
	collision_layer = 1
	collision_mask = 2
	target_rotation_y = deg_to_rad(open_angle) if is_open else 0.0
	hinge.rotation.y = target_rotation_y
	if barricade_visual:
		barricade_visual.visible = is_barricaded
	_update_blocker()

func _process(delta: float) -> void:
	hinge.rotation.y = lerp_angle(hinge.rotation.y, target_rotation_y, delta * 6.0)

func _update_blocker() -> void:
	if blocker_collision:
		# Saat terbuka dan tidak dipalang, blocker dimatikan supaya pemain bisa lewat
		blocker_collision.disabled = is_open and not is_barricaded

func is_player_inside(player: Node) -> bool:
	if not player:
		return false
	var local_pos: Vector3 = to_local(player.global_position)
	# Pintu menghadap keluar sepanjang +Z. Bagian dalam rumah adalah -Z
	return local_pos.z < -0.2

# True jika pemain berdiri di ambang pintu (area blocker + radius kapsul pemain).
# Menutup/memalang pintu saat itu akan membuat pemain tersangkut di dalam collision.
func is_doorway_occupied() -> bool:
	for p: Node in get_tree().get_nodes_in_group("player"):
		var body: Node3D = p as Node3D
		if body == null:
			continue
		var l: Vector3 = to_local(body.global_position)
		# Blocker berpusat di x=0.5 (lebar 1.05, tebal 0.15); kapsul pemain beradius 0.4
		if abs(l.z) < 0.5 and abs(l.x - 0.5) < 0.95 and l.y > -0.5 and l.y < 2.5:
			return true
	return false

func get_interaction_prompt(player: Node) -> String:
	if is_barricaded:
		if is_player_inside(player):
			return "[E] Bongkar Palang (dari dalam)"
		return "Pintu Kayu (Sudah Dipalang Kokoh)"

	if is_open:
		if is_doorway_occupied():
			return "Menyingkir dari ambang pintu untuk menutupnya"
		return "[E] Tutup Pintu"

	var inv: InventorySystem = player.get_node_or_null("InventorySystem")
	if inv:
		var equipped: Dictionary = inv.get_equipped_item()
		if equipped.get("id") == "papan_paku":
			if is_player_inside(player):
				return "[E] Palang Pintu (PERINGATAN: Kamu di dalam rumah!)"
			return "[E] Palang Pintu dengan Papan & Paku"
		elif inv.has_item_id("papan_paku"):
			return "[E] Buka Pintu | Pilih Slot Papan [1-5] untuk Memalang"

	return "[E] Buka Pintu"

func interact(player: Node) -> void:
	# Pintu terpalang: dari luar tidak bisa dibuka, dari dalam bisa dibongkar (anti-terkurung)
	if is_barricaded:
		if is_player_inside(player):
			_dismantle_barricade(player)
		return

	var inv: InventorySystem = player.get_node_or_null("InventorySystem")

	# Pemain memegang papan & pintu tertutup -> mau memalang
	if inv and not is_open:
		var equipped: Dictionary = inv.get_equipped_item()
		if equipped.get("id") == "papan_paku":
			if is_doorway_occupied():
				return
			if is_player_inside(player):
				# Pemain di dalam: tampilkan dialog peringatan
				SignalBus.request_barricade_warning.emit(self, player)
			else:
				confirm_barricade(player)
			return

	# Buka / tutup biasa
	if is_open and is_doorway_occupied():
		# Jangan tutup pintu di atas pemain, nanti tersangkut
		return

	is_open = not is_open
	target_rotation_y = deg_to_rad(open_angle) if is_open else 0.0
	_update_blocker()
	AudioManager.play_sound("door_creak", -4.0, randf_range(0.95, 1.05))

func confirm_barricade(player: Node) -> void:
	if is_barricaded or is_open or is_doorway_occupied():
		return
	var inv: InventorySystem = player.get_node_or_null("InventorySystem")
	if inv and inv.has_item_id("papan_paku"):
		is_barricaded = true
		inv.consume_item_by_id("papan_paku")
		AudioManager.play_sound("barricade_hammer", 0.0)
		GameManager.record_door_barricaded()
		if barricade_visual:
			barricade_visual.visible = true
		_update_blocker()

func _dismantle_barricade(player: Node) -> void:
	is_barricaded = false
	if barricade_visual:
		barricade_visual.visible = false
	_update_blocker()
	GameManager.record_door_unbarricaded()

	# Kembalikan papan ke inventaris (kalau penuh, papan hilang - pintu tetap terbuka)
	var inv: InventorySystem = player.get_node_or_null("InventorySystem")
	if inv:
		inv.add_item({
			"id": "papan_paku",
			"name": "Papan & Paku",
			"type": "resource",
			"quantity": 1
		})

	# Membongkar itu berisik
	AudioManager.play_sound("barricade_hammer", -2.0, 0.8)
	SignalBus.player_noise_made.emit(0.9, player.global_position)

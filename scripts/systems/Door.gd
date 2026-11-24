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
	var occupants: Array[Node] = []
	occupants.append_array(get_tree().get_nodes_in_group("player"))
	occupants.append_array(get_tree().get_nodes_in_group("remote_player"))
	for p: Node in occupants:
		var body: Node3D = p as Node3D
		if body == null or not is_instance_valid(body):
			continue
		var l: Vector3 = to_local(body.global_position)
		# Blocker berpusat di x=0.5 (lebar 1.05, tebal 0.15); kapsul pemain beradius 0.4
		if abs(l.z) < 0.5 and abs(l.x - 0.5) < 0.95 and l.y > -0.5 and l.y < 2.5:
			return true
	return false

const LocScript = preload("res://scripts/systems/Loc.gd")

func get_interaction_prompt(player: Node) -> String:
	var key_interact: String = SettingsManager.get_action_key_text("interact")
	if is_barricaded:
		if is_player_inside(player):
			return LocScript.pick("[%s] Bongkar Palang (dari dalam)" % key_interact, "[%s] Dismantle Barricade (from inside)" % key_interact)
		return LocScript.pick("Pintu Kayu (Sudah Dipalang Kokoh)", "Wooden Door (Firmly Barricaded)")

	if is_open:
		if is_doorway_occupied():
			return LocScript.pick("Menyingkir dari ambang pintu untuk menutupnya", "Step clear of the doorway to close the door")
		return LocScript.pick("[%s] Tutup Pintu" % key_interact, "[%s] Close Door" % key_interact)

	var inv: InventorySystem = player.get_node_or_null("InventorySystem")
	if inv:
		var equipped: Dictionary = inv.get_equipped_item()
		if equipped.get("id") == "papan_paku":
			if is_player_inside(player):
				return LocScript.pick("[%s] Palang Pintu (PERINGATAN: Kamu di dalam rumah!)" % key_interact, "[%s] Barricade Door (WARNING: You are inside!)" % key_interact)
			return LocScript.pick("[%s] Palang Pintu dengan Papan & Paku" % key_interact, "[%s] Barricade Door with Planks & Nails" % key_interact)
		elif inv.has_item_id("papan_paku"):
			var slot_keys: String = "%s-%s" % [SettingsManager.get_action_key_text("slot_1"), SettingsManager.get_action_key_text("slot_5")]
			return LocScript.pick("[%s] Buka Pintu | Pilih Slot Papan [%s] untuk Memalang" % [key_interact, slot_keys], "[%s] Open Door | Select Planks [%s] to Barricade" % [key_interact, slot_keys])

	return LocScript.pick("[%s] Buka Pintu" % key_interact, "[%s] Open Door" % key_interact)

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
	_broadcast_door_state()

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
		_broadcast_door_state()

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
	_broadcast_door_state()

func _get_scene_node_path() -> String:
	var root: Node = get_tree().current_scene
	if root and root.is_ancestor_of(self):
		return str(root.get_path_to(self))
	return name

func _broadcast_door_state() -> void:
	if not MultiplayerManager.is_online_session:
		return
	MultiplayerManager.push_event("door_state", {
		"node_path": _get_scene_node_path(),
		"is_open": is_open,
		"is_barricaded": is_barricaded
	})

func apply_network_state(open_state: bool, barricaded_state: bool, instant: bool = false) -> void:
	var changed: bool = (is_open != open_state) or (is_barricaded != barricaded_state)
	is_open = open_state
	is_barricaded = barricaded_state
	target_rotation_y = deg_to_rad(open_angle) if is_open else 0.0
	if instant and hinge:
		hinge.rotation.y = target_rotation_y
	if barricade_visual:
		barricade_visual.visible = is_barricaded
	_update_blocker()
	if changed:
		if is_barricaded:
			AudioManager.play_sound("barricade_hammer", -4.0)
		else:
			AudioManager.play_sound("door_creak", -6.0, randf_range(0.95, 1.05))

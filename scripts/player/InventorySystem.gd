class_name InventorySystem
extends Node

const HOTBAR_SLOTS: int = 5
const INVENTORY_ROWS: int = 3
const INVENTORY_COLS: int = 5
const INVENTORY_SLOTS: int = INVENTORY_ROWS * INVENTORY_COLS # 15 slot penyimpanan
const TOTAL_SLOTS: int = HOTBAR_SLOTS + INVENTORY_SLOTS # 20 slot total
const MAX_SLOTS: int = TOTAL_SLOTS

var slots: Array = []
var active_slot: int = 0

const STACK_LIMITS: Dictionary = {
	"minyak_tanah": 5,
	"papan_paku": 4,
	"jamu": 10,
	"baterai": 10,
	"energy_drink": 10,
	"kentongan": 5
}

const TOTAL_ITEM_CAPS: Dictionary = {
	"kentongan": 5
}

func _ready() -> void:
	slots.resize(TOTAL_SLOTS)
	for i in range(TOTAL_SLOTS):
		slots[i] = {}
	
	# Mulai dengan Senter di hotbar slot 0 dan 1 Jamu di hotbar slot 1
	slots[0] = {
		"id": "flashlight",
		"name": "Senter",
		"type": "tool",
		"battery": 100.0,
		"max_battery": 100.0
	}
	slots[1] = {
		"id": "jamu",
		"name": "Jamu Tolak Bala",
		"type": "consumable",
		"quantity": 1
	}
	
	call_deferred("_initial_update")

func _initial_update() -> void:
	SignalBus.inventory_updated.emit(slots)
	SignalBus.item_equipped.emit(active_slot, get_equipped_item())

func select_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= HOTBAR_SLOTS:
		return
	active_slot = slot_index
	SignalBus.item_equipped.emit(active_slot, get_equipped_item())

func get_equipped_item() -> Dictionary:
	if active_slot >= 0 and active_slot < HOTBAR_SLOTS and active_slot < slots.size():
		return slots[active_slot]
	return {}

func can_add_item(item_id: String, qty: int = 1) -> bool:
	var max_stack: int = STACK_LIMITS.get(item_id, 1)
	if TOTAL_ITEM_CAPS.has(item_id):
		if get_item_quantity(item_id) + qty > int(TOTAL_ITEM_CAPS[item_id]):
			return false
	
	# Periksa stack yang sudah ada di semua slot
	for i in range(TOTAL_SLOTS):
		if not slots[i].is_empty() and slots[i].get("id") == item_id:
			var current_qty: int = slots[i].get("quantity", 1)
			if current_qty + qty <= max_stack:
				return true
				
	# Periksa slot kosong
	for i in range(TOTAL_SLOTS):
		if slots[i].is_empty():
			return true
			
	return false

func add_item(item_data: Dictionary) -> bool:
	var item_id: String = item_data.get("id", "")
	var qty: int = item_data.get("quantity", 1)
	var max_stack: int = STACK_LIMITS.get(item_id, 1)
	if TOTAL_ITEM_CAPS.has(item_id):
		var remaining_cap: int = int(TOTAL_ITEM_CAPS[item_id]) - get_item_quantity(item_id)
		if remaining_cap <= 0:
			return false
		qty = mini(qty, remaining_cap)

	# Coba stack ke item yang sama (prioritaskan hotbar lalu inventaris)
	for i in range(TOTAL_SLOTS):
		if not slots[i].is_empty() and slots[i].get("id") == item_id:
			if slots[i].has("quantity"):
				var current_qty: int = slots[i]["quantity"]
				if current_qty < max_stack:
					var add_qty: int = min(qty, max_stack - current_qty)
					slots[i]["quantity"] += add_qty
					qty -= add_qty
					if qty <= 0:
						SignalBus.inventory_updated.emit(slots)
						SignalBus.item_equipped.emit(active_slot, get_equipped_item())
						AudioManager.play_sound("item_pickup")
						return true

	# Masukkan ke slot kosong pertama
	for i in range(TOTAL_SLOTS):
		if slots[i].is_empty():
			var new_item: Dictionary = item_data.duplicate(true)
			new_item["quantity"] = qty
			slots[i] = new_item
			SignalBus.inventory_updated.emit(slots)
			SignalBus.item_equipped.emit(active_slot, get_equipped_item())
			AudioManager.play_sound("item_pickup")
			return true

	return false

func move_or_swap_slots(from_index: int, to_index: int) -> bool:
	if from_index < 0 or from_index >= TOTAL_SLOTS or to_index < 0 or to_index >= TOTAL_SLOTS:
		return false
	if from_index == to_index:
		return false
	if slots[from_index].is_empty():
		return false

	var source_item: Dictionary = slots[from_index]
	var target_item: Dictionary = slots[to_index]

	# Jika target kosong, pindahkan item
	if target_item.is_empty():
		slots[to_index] = source_item
		slots[from_index] = {}
		SignalBus.inventory_updated.emit(slots)
		SignalBus.item_equipped.emit(active_slot, get_equipped_item())
		return true

	# Jika target item bertipe sama dan memiliki kuantitas, coba gabungkan (stack)
	var source_id: String = str(source_item.get("id", ""))
	var target_id: String = str(target_item.get("id", ""))
	if source_id == target_id and source_item.has("quantity") and target_item.has("quantity"):
		var max_stack: int = STACK_LIMITS.get(source_id, 1)
		var current_target_qty: int = int(target_item.get("quantity", 1))
		if current_target_qty < max_stack:
			var source_qty: int = int(source_item.get("quantity", 1))
			var space: int = max_stack - current_target_qty
			if source_qty <= space:
				target_item["quantity"] = current_target_qty + source_qty
				slots[from_index] = {}
			else:
				target_item["quantity"] = max_stack
				source_item["quantity"] = source_qty - space
			SignalBus.inventory_updated.emit(slots)
			SignalBus.item_equipped.emit(active_slot, get_equipped_item())
			return true

	# Jika slot sudah ada isinya (atau beda item), tukar tempat (mirip sistem inventory Minecraft)
	var temp: Dictionary = slots[to_index]
	slots[to_index] = slots[from_index]
	slots[from_index] = temp

	SignalBus.inventory_updated.emit(slots)
	SignalBus.item_equipped.emit(active_slot, get_equipped_item())
	return true

func has_item_id(item_id: String) -> bool:
	for slot: Dictionary in slots:
		if not slot.is_empty() and slot.get("id") == item_id:
			return true
	return false

func get_item_quantity(item_id: String) -> int:
	var total: int = 0
	for slot: Dictionary in slots:
		if not slot.is_empty() and slot.get("id") == item_id:
			total += slot.get("quantity", 1)
	return total

func consume_item_by_id(item_id: String) -> bool:
	for i in range(TOTAL_SLOTS):
		if not slots[i].is_empty() and slots[i].get("id") == item_id:
			if slots[i].has("quantity") and slots[i]["quantity"] > 1:
				slots[i]["quantity"] -= 1
			else:
				slots[i] = {}
			SignalBus.inventory_updated.emit(slots)
			SignalBus.item_equipped.emit(active_slot, get_equipped_item())
			return true
	return false

func consume_equipped_item() -> bool:
	var item: Dictionary = get_equipped_item()
	if item.is_empty():
		return false
	if active_slot >= 0 and active_slot < HOTBAR_SLOTS and active_slot < slots.size():
		if slots[active_slot].has("quantity") and int(slots[active_slot]["quantity"]) > 1:
			slots[active_slot]["quantity"] = int(slots[active_slot]["quantity"]) - 1
		else:
			slots[active_slot] = {}
		SignalBus.inventory_updated.emit(slots)
		SignalBus.item_equipped.emit(active_slot, get_equipped_item())
		return true
	return consume_item_by_id(item.get("id", ""))

func drop_equipped_item(drop_position: Vector3) -> bool:
	if not is_inside_tree():
		return false
	var world: Node = get_tree().current_scene
	if not is_instance_valid(world):
		return false
	var item: Dictionary = get_equipped_item()
	if item.is_empty() or item.get("id") == "flashlight":
		return false
	var pickup_scene: PackedScene = load("res://scenes/items/PickupItem.tscn")
	if pickup_scene == null:
		return false
	var dropped_item_data: Dictionary = item.duplicate(true)
	var inst: PickupItem = pickup_scene.instantiate() as PickupItem
	if inst == null:
		return false
	inst.item_id = dropped_item_data.get("id", "minyak_tanah")
	inst.item_name = dropped_item_data.get("name", "Barang")
	inst.item_type = dropped_item_data.get("type", "resource")
	inst.set_meta("autosave_dynamic", true)
	# global_position baru valid setelah Node3D masuk SceneTree.
	world.add_child(inst)
	inst.global_position = drop_position

	# Jika jumlah > 1, kurangi 1 kuantitas agar sisa stack tidak hilang
	if slots[active_slot].has("quantity") and slots[active_slot]["quantity"] > 1:
		slots[active_slot]["quantity"] -= 1
	else:
		slots[active_slot] = {}

	SignalBus.inventory_updated.emit(slots)
	SignalBus.item_equipped.emit(active_slot, get_equipped_item())
	AudioManager.play_sound("item_pickup", -6.0, 0.8)
	return true

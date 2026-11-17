class_name InventorySystem
extends Node

const MAX_SLOTS: int = 4
var slots: Array = []
var active_slot: int = 0

const STACK_LIMITS: Dictionary = {
	"minyak_tanah": 5,
	"papan_paku": 4,
	"jamu": 3,
	"baterai": 3
}

func _ready() -> void:
	slots.resize(MAX_SLOTS)
	for i in range(MAX_SLOTS):
		slots[i] = {}
	
	# Start player with Flashlight in slot 0 and 1 Jamu in slot 1
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
	if slot_index < 0 or slot_index >= MAX_SLOTS:
		return
	active_slot = slot_index
	SignalBus.item_equipped.emit(active_slot, get_equipped_item())

func get_equipped_item() -> Dictionary:
	if active_slot >= 0 and active_slot < slots.size():
		return slots[active_slot]
	return {}

func can_add_item(item_id: String, qty: int = 1) -> bool:
	var max_stack: int = STACK_LIMITS.get(item_id, 1)
	
	# Check existing stack
	for i in range(MAX_SLOTS):
		if not slots[i].is_empty() and slots[i].get("id") == item_id:
			var current_qty: int = slots[i].get("quantity", 1)
			if current_qty + qty <= max_stack:
				return true
				
	# Check empty slot
	for i in range(MAX_SLOTS):
		if slots[i].is_empty():
			return true
			
	return false

func add_item(item_data: Dictionary) -> bool:
	var item_id: String = item_data.get("id", "")
	var qty: int = item_data.get("quantity", 1)
	var max_stack: int = STACK_LIMITS.get(item_id, 1)

	# Try to stack onto existing item
	for i in range(MAX_SLOTS):
		if not slots[i].is_empty() and slots[i].get("id") == item_id:
			if slots[i].has("quantity"):
				var current_qty: int = slots[i]["quantity"]
				if current_qty < max_stack:
					var add_qty: int = min(qty, max_stack - current_qty)
					slots[i]["quantity"] += add_qty
					SignalBus.inventory_updated.emit(slots)
					SignalBus.item_equipped.emit(active_slot, get_equipped_item())
					AudioManager.play_sound("item_pickup")
					return true

	# Put in first empty slot
	for i in range(MAX_SLOTS):
		if slots[i].is_empty():
			slots[i] = item_data.duplicate(true)
			SignalBus.inventory_updated.emit(slots)
			SignalBus.item_equipped.emit(active_slot, get_equipped_item())
			AudioManager.play_sound("item_pickup")
			return true

	return false

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
	for i in range(MAX_SLOTS):
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
	return consume_item_by_id(item.get("id", ""))

func drop_equipped_item(drop_position: Vector3) -> bool:
	var item: Dictionary = get_equipped_item()
	if item.is_empty():
		return false
	if item.get("id") == "flashlight":
		# Do not drop flashlight
		return false

	var dropped_item_data: Dictionary = item.duplicate(true)
	slots[active_slot] = {}
	SignalBus.inventory_updated.emit(slots)
	SignalBus.item_equipped.emit(active_slot, get_equipped_item())

	# Spawn pickup item in world
	var pickup_scene: PackedScene = load("res://scenes/items/PickupItem.tscn")
	if pickup_scene:
		var inst: PickupItem = pickup_scene.instantiate() as PickupItem
		inst.item_id = dropped_item_data.get("id", "minyak_tanah")
		inst.item_name = dropped_item_data.get("name", "Barang")
		inst.item_type = dropped_item_data.get("type", "resource")
		inst.global_position = drop_position
		get_tree().current_scene.add_child(inst)
		AudioManager.play_sound("item_pickup", -6.0, 0.8)
		return true

	return false

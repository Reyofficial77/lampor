extends Node3D

# Barang bantu dipusatkan di empat rumah. Benda ritual tetap berada di lokasi
# misinya agar pemain masih harus menjelajahi makam, sumur, dan rumpun bambu.
const ITEM_MIN_GAP: float = 1.5
const MAX_INDOOR_SUPPLIES_PER_HOUSE: int = 2
const MAX_OUTDOOR_SUPPLIES: int = 4
const HOUSE_HALF_SIZE: float = 4.8
const ITEM_Y: float = 0.3
const INDOOR_LOCAL_SLOTS: Array[Vector3] = [
	Vector3(1.65, 0.0, -1.65), Vector3(-0.1, 0.0, -1.65),
	Vector3(1.65, 0.0, 0.05), Vector3(-0.1, 0.0, 0.05),
	Vector3(1.65, 0.0, 1.7), Vector3(-0.1, 0.0, 1.7)
]
const OUTDOOR_ANCHORS: Array[Vector2] = [
	Vector2(0.0, 12.0), Vector2(0.0, -12.0),
	Vector2(13.0, 3.5), Vector2(-13.0, 3.5)
]

var _blocked: Array[Dictionary] = []
var _houses: Array[Node3D] = []

func _ready() -> void:
	call_deferred("_randomize_items")

func _randomize_items() -> void:
	var map_root: Node = get_parent()
	if map_root == null:
		return
	_collect_zones(map_root)
	var ritual_items: Array[PickupItem] = []
	var supplies: Array[PickupItem] = []
	_gather_items(map_root, ritual_items, supplies)
	if _houses.is_empty():
		push_warning("[ItemRandomizer] Rumah tidak ditemukan; posisi barang bawaan dipertahankan.")
		return

	# Ritual item tidak dipindahkan: landmark-nya merupakan bagian dari alur misi.
	var indoor_counts: Array[int] = []
	var slot_offsets: Array[int] = []
	for _house: Node3D in _houses:
		indoor_counts.append(0)
		slot_offsets.append(randi_range(0, INDOOR_LOCAL_SLOTS.size() - 1))

	supplies.shuffle()
	var placed: Array[Vector3] = []
	var indoor_count: int = 0
	var outdoor_count: int = 0
	for i: int in range(supplies.size()):
		var item: PickupItem = supplies[i]
		var spot: Vector3 = Vector3.INF
		var preferred_house: int = i % _houses.size()
		for offset: int in range(_houses.size()):
			var house_index: int = (preferred_house + offset) % _houses.size()
			if indoor_counts[house_index] >= MAX_INDOOR_SUPPLIES_PER_HOUSE:
				continue
			var slot_index: int = (slot_offsets[house_index] + indoor_counts[house_index] * 3) % INDOOR_LOCAL_SLOTS.size()
			spot = _houses[house_index].to_global(INDOOR_LOCAL_SLOTS[slot_index])
			indoor_counts[house_index] += 1
			break
		if spot != Vector3.INF:
			indoor_count += 1
		elif outdoor_count < MAX_OUTDOOR_SUPPLIES:
			spot = _pick_outdoor_point(placed)
			if spot != Vector3.INF:
				outdoor_count += 1
		if spot == Vector3.INF:
			push_warning("[ItemRandomizer] Tidak ada slot untuk %s; posisi awal dipertahankan." % item.item_name)
			continue
		item.global_position = Vector3(spot.x, ITEM_Y, spot.z)
		placed.append(spot)

	print("[ItemRandomizer] %d barang bantu di rumah, %d di luar, %d benda ritual tetap di lokasi misi." % [indoor_count, outdoor_count, ritual_items.size()])

func _gather_items(node: Node, ritual: Array[PickupItem], supplies: Array[PickupItem]) -> void:
	for child: Node in node.get_children():
		if child is PickupItem:
			var item: PickupItem = child as PickupItem
			if item.is_ritual_item:
				ritual.append(item)
			else:
				supplies.append(item)
		_gather_items(child, ritual, supplies)

func _collect_zones(root: Node) -> void:
	_blocked.clear()
	_houses.clear()
	for child: Node in root.get_children():
		if child is VillageHouse:
			_houses.append(child as Node3D)
	_add_zone(root.get_node_or_null("BalaiDesa/RitualAltar"), 5.0)
	_add_zone(root.get_node_or_null("Cemetery"), 5.0)
	_add_zone(root.get_node_or_null("AncientWell"), 4.0)
	_add_zone(root.get_node_or_null("BambooNorth"), 4.0)
	_add_zone(root.get_node_or_null("BambooSouth"), 4.0)
	var torches: Node = root.get_node_or_null("Torches")
	if torches:
		for torch: Node in torches.get_children():
			_add_zone(torch, 3.0)

func _add_zone(node: Node, radius: float) -> void:
	var node_3d: Node3D = node as Node3D
	if node_3d == null:
		return
	_blocked.append({"pos": Vector2(node_3d.global_position.x, node_3d.global_position.z), "r": radius})

func _is_free(point: Vector2) -> bool:
	for zone: Dictionary in _blocked:
		var zone_position: Vector2 = zone["pos"]
		if point.distance_to(zone_position) < float(zone["r"]):
			return false
	for house: Node3D in _houses:
		var house_position: Vector3 = house.global_position
		if absf(point.x - house_position.x) < HOUSE_HALF_SIZE and absf(point.y - house_position.z) < HOUSE_HALF_SIZE:
			return false
	return true

func _too_close(point: Vector2, placed: Array[Vector3]) -> bool:
	for previous: Vector3 in placed:
		if point.distance_to(Vector2(previous.x, previous.z)) < ITEM_MIN_GAP:
			return true
	return false

func _pick_outdoor_point(placed: Array[Vector3]) -> Vector3:
	var anchors: Array[Vector2] = OUTDOOR_ANCHORS.duplicate()
	anchors.shuffle()
	for anchor: Vector2 in anchors:
		var candidate_2d: Vector2 = anchor + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
		if _is_free(candidate_2d) and not _too_close(candidate_2d, placed):
			return Vector3(candidate_2d.x, 0.0, candidate_2d.y)
	return Vector3.INF

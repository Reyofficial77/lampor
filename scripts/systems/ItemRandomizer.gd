extends Node3D

# Mengacak posisi semua item (benda ritual, minyak, papan, jamu) setiap permainan baru.
# - Area acak dekat pusat desa supaya item tidak terlalu jauh
# - Benda ritual boleh di luar ruangan ATAU di dalam rumah (maksimal MAX_RITUAL_INDOOR)
# - Item tidak menumpuk di satu tempat
# - Item tidak muncul di dalam dinding rumah, dekat altar, obor, sumur, makam, bambu, lemari, atau pemain

const MAP_LIMIT: float = 28.0
const RITUAL_MIN_GAP: float = 10.0
const ITEM_MIN_GAP: float = 5.0
const INDOOR_GAP: float = 1.6
# Mayoritas item sengaja ditaruh di DALAM rumah supaya tidak banyak berserakan di luar.
# Ada 4 rumah x 4 titik = 16 slot dalam rumah, untuk 14 item (4 ritual + 10 lainnya).
const RITUAL_INDOOR_CHANCE: float = 0.85
const OTHER_INDOOR_CHANCE: float = 0.8
const MAX_RITUAL_INDOOR: int = 3
const HOUSE_HALF_SIZE: float = 4.8
const MAX_TRIES: int = 500
const RITUAL_Y: float = 0.45
const ITEM_Y: float = 0.3

# Titik di dalam rumah (koordinat lokal rumah). Lemari ada di sekitar (-2.1, -2.0), jadi dihindari.
const INDOOR_LOCAL_SLOTS: Array[Vector3] = [
	Vector3(1.8, 0.0, -1.8),
	Vector3(1.8, 0.0, 1.0),
	Vector3(-1.8, 0.0, 1.0),
	Vector3(0.2, 0.0, -1.0)
]

var _blocked: Array[Dictionary] = []
var _houses: Array[Node3D] = []

func _ready() -> void:
	# Ditunda satu frame supaya semua node peta (rumah, obor, item) sudah ada di tree
	call_deferred('_randomize_items')

func _randomize_items() -> void:
	var map_root: Node = get_parent()
	if map_root == null:
		return
	_collect_zones(map_root)

	var ritual_items: Array[PickupItem] = []
	var other_items: Array[PickupItem] = []
	_gather_items(map_root, ritual_items, other_items)

	var placed: Array[Vector3] = []

	# Kumpulkan semua titik di dalam rumah lalu acak urutannya
	var indoor_slots: Array[Vector3] = []
	for house: Node3D in _houses:
		for local_pos: Vector3 in INDOOR_LOCAL_SLOTS:
			indoor_slots.append(house.to_global(local_pos))
	indoor_slots.shuffle()

	# 1) Benda ritual: sebagian boleh di dalam rumah, sisanya di luar ruangan
	ritual_items.shuffle()
	var ritual_indoor: int = 0
	for item: PickupItem in ritual_items:
		var spot: Vector3 = Vector3.INF
		if ritual_indoor < MAX_RITUAL_INDOOR and not indoor_slots.is_empty() and randf() < RITUAL_INDOOR_CHANCE:
			spot = _take_indoor_slot(indoor_slots, placed)
			if spot != Vector3.INF:
				ritual_indoor += 1
		if spot == Vector3.INF:
			spot = _pick_outdoor_point(RITUAL_MIN_GAP, placed)
		if spot != Vector3.INF:
			item.global_position = Vector3(spot.x, RITUAL_Y, spot.z)
			placed.append(spot)
			print('[ItemRandomizer] %s -> (%.1f, %.1f)' % [item.item_name, spot.x, spot.z])

	# 2) Item lain (minyak, papan, jamu): campur dalam dan luar rumah
	other_items.shuffle()
	for item: PickupItem in other_items:
		var spot2: Vector3 = Vector3.INF
		if not indoor_slots.is_empty() and randf() < OTHER_INDOOR_CHANCE:
			spot2 = _take_indoor_slot(indoor_slots, placed)
		if spot2 == Vector3.INF:
			spot2 = _pick_outdoor_point(ITEM_MIN_GAP, placed)
		if spot2 != Vector3.INF:
			item.global_position = Vector3(spot2.x, ITEM_Y, spot2.z)
			placed.append(spot2)
			print('[ItemRandomizer] %s -> (%.1f, %.1f)' % [item.item_name, spot2.x, spot2.z])

func _take_indoor_slot(slots: Array[Vector3], placed: Array[Vector3]) -> Vector3:
	while not slots.is_empty():
		var slot: Vector3 = slots.pop_back()
		if not _too_close(slot, INDOOR_GAP, placed):
			return slot
	return Vector3.INF

func _gather_items(node: Node, ritual: Array[PickupItem], other: Array[PickupItem]) -> void:
	for child: Node in node.get_children():
		if child is PickupItem:
			var item: PickupItem = child as PickupItem
			if item.is_ritual_item:
				ritual.append(item)
			else:
				other.append(item)
		_gather_items(child, ritual, other)

func _collect_zones(root: Node) -> void:
	_blocked.clear()
	_houses.clear()
	for child: Node in root.get_children():
		if child is VillageHouse:
			_houses.append(child as Node3D)
	_add_zone(root.get_node_or_null('BalaiDesa/RitualAltar'), 5.0)
	_add_zone(root.get_node_or_null('Cemetery'), 5.0)
	_add_zone(root.get_node_or_null('AncientWell'), 4.0)
	_add_zone(root.get_node_or_null('BambooNorth'), 4.0)
	_add_zone(root.get_node_or_null('BambooSouth'), 4.0)
	var torches: Node = root.get_node_or_null('Torches')
	if torches:
		for t: Node in torches.get_children():
			_add_zone(t, 3.0)
	_add_zone(get_tree().get_first_node_in_group('player'), 4.0)

func _add_zone(node: Node, radius: float) -> void:
	var n3: Node3D = node as Node3D
	if n3 == null:
		return
	_blocked.append({'pos': Vector2(n3.global_position.x, n3.global_position.z), 'r': radius})

func _is_free(p: Vector2) -> bool:
	for zone: Dictionary in _blocked:
		var zp: Vector2 = zone['pos']
		var zr: float = zone['r']
		if p.distance_to(zp) < zr:
			return false
	for house: Node3D in _houses:
		var hp: Vector3 = house.global_position
		if absf(p.x - hp.x) < HOUSE_HALF_SIZE and absf(p.y - hp.z) < HOUSE_HALF_SIZE:
			return false
	return true

func _too_close(p: Vector3, gap: float, placed: Array[Vector3]) -> bool:
	var p2: Vector2 = Vector2(p.x, p.z)
	for q: Vector3 in placed:
		if p2.distance_to(Vector2(q.x, q.z)) < gap:
			return true
	return false

func _pick_outdoor_point(min_gap: float, placed: Array[Vector3]) -> Vector3:
	for i: int in range(MAX_TRIES):
		var p: Vector2 = Vector2(randf_range(-MAP_LIMIT, MAP_LIMIT), randf_range(-MAP_LIMIT, MAP_LIMIT))
		if not _is_free(p):
			continue
		var candidate: Vector3 = Vector3(p.x, 0.0, p.y)
		if _too_close(candidate, min_gap, placed):
			continue
		return candidate
	return Vector3.INF

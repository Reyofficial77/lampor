class_name PickupItem
extends Area3D

@export var item_id: String = "minyak_tanah"
@export var item_name: String = "Minyak Tanah & Korek"
@export var item_type: String = "resource"
@export var is_ritual_item: bool = false
@export var ritual_display_name: String = ""

@onready var visual_node: Node3D = $Visuals
@onready var item_light: OmniLight3D = $Visuals/ItemLight
var is_picked_up: bool = false

func _ready() -> void:
	collision_layer = 1
	collision_mask = 2
	_update_model_appearance()

func _update_model_appearance() -> void:
	var target_name: String = "GenericVisual"
	match item_id:
		"keris":
			target_name = "KerisVisual"
			if item_light:
				item_light.light_color = Color(1.0, 0.85, 0.3)
				item_light.light_energy = 1.6
		"minyak_tanah":
			target_name = "MinyakVisual"
			if item_light:
				item_light.light_color = Color(1.0, 0.65, 0.2)
				item_light.light_energy = 0.9
		"papan_paku":
			target_name = "PapanVisual"
			if item_light:
				item_light.light_color = Color(0.9, 0.8, 0.6)
				item_light.light_energy = 0.7
		"jamu":
			target_name = "JamuVisual"
			if item_light:
				item_light.light_color = Color(0.2, 0.9, 0.4)
				item_light.light_energy = 1.2
		"baterai":
			target_name = "BateraiVisual"
			if item_light:
				item_light.light_color = Color(1.0, 0.9, 0.2)
				item_light.light_energy = 0.8
		"kemenyan":
			target_name = "KemenyanVisual"
			if item_light:
				item_light.light_color = Color(1.0, 0.4, 0.1)
				item_light.light_energy = 1.5
		"bunga":
			target_name = "BungaVisual"
			if item_light:
				item_light.light_color = Color(0.9, 0.4, 0.8)
				item_light.light_energy = 1.4
		"tanah":
			target_name = "TanahVisual"
			if item_light:
				item_light.light_color = Color(0.6, 0.3, 0.8)
				item_light.light_energy = 1.5

	_build_ritual_model(item_id)
	if is_ritual_item and visual_node:
		visual_node.scale = Vector3(1.5, 1.5, 1.5)

	for child: Node in visual_node.get_children():
		if child is Node3D and child != item_light:
			child.visible = (child.name == target_name)

func _process(delta: float) -> void:
	if visual_node:
		visual_node.rotate_y(delta * 1.5)

func get_interaction_prompt(player: Node) -> String:
	if is_picked_up:
		return ""

	if is_ritual_item:
		var r_name: String = ritual_display_name if ritual_display_name != "" else item_name
		return "[E] Ambil Benda Ritual: " + r_name

	var inv: InventorySystem = player.get_node_or_null("InventorySystem")
	if inv:
		if not inv.can_add_item(item_id):
			var max_stack: int = inv.STACK_LIMITS.get(item_id, 1)
			var current_qty: int = inv.get_item_quantity(item_id)
			if current_qty >= max_stack:
				return item_name + " (Kapasitas Penuh: %d)" % max_stack
			else:
				return item_name + " (Tas Penuh!)"

	return "[E] Ambil " + item_name

func interact(player: Node) -> void:
	if is_picked_up:
		return

	if is_ritual_item:
		is_picked_up = true
		var r_name: String = ritual_display_name if ritual_display_name != "" else item_name
		GameManager.ritual_items[r_name] = true
		var current_count: int = GameManager.get_ritual_item_count()
		SignalBus.ritual_item_collected.emit(r_name, current_count, GameManager.TOTAL_RITUAL_ITEMS)
		AudioManager.play_sound("item_pickup")
		queue_free()
		return

	var inv: InventorySystem = player.get_node_or_null("InventorySystem")
	if not inv:
		return

	if not inv.can_add_item(item_id):
		AudioManager.play_sound("item_pickup", -10.0, 0.5)
		return

	is_picked_up = true
	var item_data: Dictionary = {
		"id": item_id,
		"name": item_name,
		"type": item_type,
		"quantity": 1
	}
	var success: bool = inv.add_item(item_data)
	if success:
		queue_free()
	else:
		is_picked_up = false

# ---------- Model benda ritual (dibangun lewat kode) ----------

func _mat(color: Color, rough: float = 0.8, metal: float = 0.0, glow: float = 0.0, alpha: float = 1.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.roughness = rough
	m.metallic = metal
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	return m

func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var c: CylinderMesh = CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	return c

func _sph(r: float) -> SphereMesh:
	var s: SphereMesh = SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s

func _box(x: float, y: float, z: float) -> BoxMesh:
	var b: BoxMesh = BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b

func _add_mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	parent.add_child(mi)
	return mi

func _replace_visual(node_name: String) -> Node3D:
	var old: Node = visual_node.get_node_or_null(node_name)
	if old:
		visual_node.remove_child(old)
		old.free()
	var fresh: Node3D = Node3D.new()
	fresh.name = node_name
	visual_node.add_child(fresh)
	return fresh

func _build_ritual_model(id: String) -> void:
	if not visual_node:
		return
	match id:
		'tanah':
			_build_tanah()
		'bunga':
			_build_bunga()
		'kemenyan':
			_build_kemenyan()
		'keris':
			_build_keris()

func _build_tanah() -> void:
	# Wadah tanah liat berlilit kain kafan, berisi gundukan tanah makam dan nisan kecil
	var root: Node3D = _replace_visual('TanahVisual')
	var clay: StandardMaterial3D = _mat(Color(0.55, 0.32, 0.18), 0.9)
	var soil: StandardMaterial3D = _mat(Color(0.16, 0.10, 0.06), 1.0)
	var stone: StandardMaterial3D = _mat(Color(0.55, 0.55, 0.58), 0.9)
	var cloth: StandardMaterial3D = _mat(Color(0.92, 0.90, 0.84), 0.95)
	_add_mesh(root, _cyl(0.2, 0.13, 0.1), clay, Vector3(0, -0.1, 0))
	_add_mesh(root, _cyl(0.205, 0.205, 0.025), cloth, Vector3(0, -0.07, 0))
	_add_mesh(root, _cyl(0.05, 0.19, 0.16), soil, Vector3(0, 0.03, 0))
	for i: int in range(6):
		var a: float = TAU * float(i) / 6.0
		_add_mesh(root, _sph(0.035), soil, Vector3(cos(a) * 0.13, -0.03, sin(a) * 0.13), Vector3.ZERO, Vector3(1.0, 0.7, 1.0))
	_add_mesh(root, _box(0.07, 0.2, 0.025), stone, Vector3(0, 0.2, 0), Vector3(0, 0, 6))

func _build_bunga() -> void:
	# Nampan anyaman berisi 7 bunga dengan 7 warna berbeda
	var root: Node3D = _replace_visual('BungaVisual')
	var rattan: StandardMaterial3D = _mat(Color(0.6, 0.45, 0.2), 0.9)
	var green: StandardMaterial3D = _mat(Color(0.2, 0.5, 0.2), 0.8)
	var colors: Array[Color] = [
		Color(0.9, 0.1, 0.2), Color(0.97, 0.97, 0.92), Color(0.95, 0.85, 0.1), Color(1.0, 0.45, 0.7),
		Color(0.6, 0.25, 0.85), Color(1.0, 0.55, 0.1), Color(0.25, 0.45, 0.95)
	]
	_add_mesh(root, _cyl(0.26, 0.2, 0.04), rattan, Vector3(0, -0.08, 0))
	for i: int in range(7):
		var pos: Vector3 = Vector3.ZERO
		if i < 6:
			var a: float = TAU * float(i) / 6.0
			pos = Vector3(cos(a) * 0.13, 0.0, sin(a) * 0.13)
		_add_mesh(root, _cyl(0.008, 0.008, 0.12), green, pos + Vector3(0, -0.01, 0))
		_add_mesh(root, _sph(0.05), _mat(colors[i], 0.6), pos + Vector3(0, 0.07, 0), Vector3.ZERO, Vector3(1.0, 0.55, 1.0))
		_add_mesh(root, _sph(0.016), _mat(Color(0.95, 0.8, 0.1), 0.6), pos + Vector3(0, 0.085, 0))

func _build_kemenyan() -> void:
	# Pedupaan berkaki tiga berisi bongkahan kemenyan, bara menyala, dupa, dan asap tipis
	var root: Node3D = _replace_visual('KemenyanVisual')
	var bowl: StandardMaterial3D = _mat(Color(0.3, 0.2, 0.15), 0.9)
	var resin: StandardMaterial3D = _mat(Color(0.9, 0.8, 0.55), 0.5)
	var coal: StandardMaterial3D = _mat(Color(1.0, 0.35, 0.08), 0.9, 0.0, 2.5)
	var stick: StandardMaterial3D = _mat(Color(0.4, 0.25, 0.12), 0.9)
	var smoke: StandardMaterial3D = _mat(Color(0.75, 0.75, 0.75), 1.0, 0.0, 0.0, 0.25)
	_add_mesh(root, _cyl(0.17, 0.1, 0.12), bowl, Vector3(0, -0.02, 0))
	for i: int in range(3):
		var a: float = TAU * float(i) / 3.0
		_add_mesh(root, _cyl(0.025, 0.015, 0.08), bowl, Vector3(cos(a) * 0.09, -0.11, sin(a) * 0.09))
	_add_mesh(root, _sph(0.07), coal, Vector3(0, 0.05, 0), Vector3.ZERO, Vector3(1.0, 0.5, 1.0))
	for i: int in range(4):
		var a2: float = TAU * float(i) / 4.0 + 0.4
		_add_mesh(root, _box(0.05, 0.04, 0.045), resin, Vector3(cos(a2) * 0.07, 0.06, sin(a2) * 0.07), Vector3(0, a2 * 40.0, 15))
	for i: int in range(3):
		var a3: float = TAU * float(i) / 3.0 + 0.8
		_add_mesh(root, _cyl(0.006, 0.006, 0.3), stick, Vector3(cos(a3) * 0.04, 0.2, sin(a3) * 0.04), Vector3(sin(a3) * 8.0, 0, cos(a3) * 8.0))
		_add_mesh(root, _sph(0.012), coal, Vector3(cos(a3) * 0.04, 0.35, sin(a3) * 0.04))
	for i: int in range(3):
		_add_mesh(root, _sph(0.05 + float(i) * 0.015), smoke, Vector3(0.02 * float(i), 0.42 + float(i) * 0.1, 0.0))

func _build_keris() -> void:
	# Keris: bilah berluk bergelombang, ganja emas, dan hulu kayu
	var root: Node3D = _replace_visual('KerisVisual')
	var steel: StandardMaterial3D = _mat(Color(0.65, 0.68, 0.74), 0.25, 0.9, 0.25)
	var gold: StandardMaterial3D = _mat(Color(0.9, 0.75, 0.25), 0.3, 0.85, 0.4)
	var wood: StandardMaterial3D = _mat(Color(0.25, 0.12, 0.05), 0.8)
	root.rotation_degrees = Vector3(0, 0, 20)
	for i: int in range(7):
		var w: float = lerp(0.07, 0.022, float(i) / 6.0)
		var off: float = 0.016 if i % 2 == 0 else -0.016
		_add_mesh(root, _box(w, 0.058, 0.012), steel, Vector3(off, float(i) * 0.05, 0.0))
	_add_mesh(root, _cyl(0.0, 0.016, 0.06), steel, Vector3(0.0, 0.36, 0.0))
	_add_mesh(root, _box(0.13, 0.03, 0.035), gold, Vector3(0, -0.04, 0))
	_add_mesh(root, _cyl(0.035, 0.04, 0.02), gold, Vector3(0, -0.07, 0))
	_add_mesh(root, _cyl(0.022, 0.03, 0.14), wood, Vector3(0.0, -0.15, 0.0), Vector3(0, 0, 8))
	_add_mesh(root, _sph(0.04), gold, Vector3(0.025, -0.23, 0.0))


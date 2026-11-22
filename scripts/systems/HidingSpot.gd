class_name HidingSpot
extends Area3D

# Lemari persembunyian. Badan lemari dibangun dari panel tipis (bukan satu kotak mesh),
# sehingga bagian dalamnya tetap terlihat saat kamera player ada di dalam.
# Pintu kiri tertutup, pintu kanan terbuka sedikit supaya player bisa mengintip.

const DOOR_OPEN_ANGLE_DEG: float = 35.0
const CLOSET_WIDTH: float = 1.1
const CLOSET_HEIGHT: float = 2.1
const CLOSET_DEPTH: float = 0.9
const PANEL: float = 0.04

# Posisi kamera di dalam lemari (koordinat lokal lemari, sisi depan = +Z)
const HIDE_LOCAL_POS: Vector3 = Vector3(0.0, 0.05, -0.1)

var is_occupied: bool = false
var occupying_player: PlayerController = null

@onready var exit_point: Marker3D = $ExitPoint

func _ready() -> void:
	collision_layer = 1
	collision_mask = 2
	_build_closet_model()

func get_hide_global_position() -> Vector3:
	return to_global(HIDE_LOCAL_POS)

const LocScript = preload("res://scripts/systems/Loc.gd")

func get_interaction_prompt(_player: Node) -> String:
	var k: String = SettingsManager.get_action_key_text("interact")
	return LocScript.pick("[%s] Masuk & Sembunyi di Lemari" % k, "[%s] Hide Inside Closet" % k) if not is_occupied else LocScript.pick("[%s] Keluar dari Lemari" % k, "[%s] Exit Closet" % k)

func interact(player: Node) -> void:
	var pc: PlayerController = player as PlayerController
	if not pc:
		return

	if not is_occupied:
		is_occupied = true
		occupying_player = pc
		pc.enter_hiding(self)
		AudioManager.play_sound("door_creak", -6.0, 1.2)
	else:
		is_occupied = false
		pc.exit_hiding()
		occupying_player = null
		AudioManager.play_sound("door_creak", -6.0, 1.0)

# ---------- Model lemari ----------

func _mat(color: Color, rough: float = 0.85, metal: float = 0.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m

func _panel(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func _knob(parent: Node3D, pos: Vector3, mat: Material) -> void:
	var sph: SphereMesh = SphereMesh.new()
	sph.radius = 0.035
	sph.height = 0.07
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = sph
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)

func _build_closet_model() -> void:
	# Buang kotak mesh lama (sisi dalamnya tidak digambar sehingga lemari tampak hilang)
	var old_mesh: Node = get_node_or_null("MeshInstance3D")
	if old_mesh:
		old_mesh.queue_free()

	var wood: StandardMaterial3D = _mat(Color(0.28, 0.18, 0.1))
	if ResourceLoader.exists("res://assets/textures/wood_albedo.png"):
		wood.albedo_texture = load("res://assets/textures/wood_albedo.png")
	var dark_wood: StandardMaterial3D = _mat(Color(0.16, 0.1, 0.06), 0.9)
	var inner: StandardMaterial3D = _mat(Color(0.12, 0.08, 0.05), 0.95)
	var brass: StandardMaterial3D = _mat(Color(0.8, 0.62, 0.2), 0.35, 0.8)

	var root: Node3D = Node3D.new()
	root.name = "ClosetModel"
	add_child(root)

	var h: float = CLOSET_HEIGHT
	var hw: float = CLOSET_WIDTH * 0.5
	var hd: float = CLOSET_DEPTH * 0.5

	# Badan: dinding belakang, kiri, kanan, atas, lantai
	_panel(root, Vector3(CLOSET_WIDTH, h, PANEL), Vector3(0, h * 0.5, -hd + PANEL * 0.5), inner)
	_panel(root, Vector3(PANEL, h, CLOSET_DEPTH), Vector3(-hw + PANEL * 0.5, h * 0.5, 0), wood)
	_panel(root, Vector3(PANEL, h, CLOSET_DEPTH), Vector3(hw - PANEL * 0.5, h * 0.5, 0), wood)
	_panel(root, Vector3(CLOSET_WIDTH + 0.06, PANEL * 1.5, CLOSET_DEPTH + 0.04), Vector3(0, h + 0.01, 0), dark_wood)
	_panel(root, Vector3(CLOSET_WIDTH, PANEL, CLOSET_DEPTH), Vector3(0, PANEL * 0.5, 0), dark_wood)

	# Rak gantung di dalam supaya bagian dalam tidak kosong
	_panel(root, Vector3(CLOSET_WIDTH - 0.1, 0.03, 0.35), Vector3(0, h - 0.35, -hd + 0.25), dark_wood)

	# Pintu kiri: TERTUTUP. Engsel di sisi kiri depan.
	var front_z: float = hd
	var left_pivot: Node3D = Node3D.new()
	left_pivot.name = "DoorLeftPivot"
	left_pivot.position = Vector3(-hw, h * 0.5, front_z)
	root.add_child(left_pivot)
	var left_w: float = 0.5
	_panel(left_pivot, Vector3(left_w, h - 0.1, 0.03), Vector3(left_w * 0.5, 0, 0), wood)
	_panel(left_pivot, Vector3(left_w - 0.12, h - 0.4, 0.015), Vector3(left_w * 0.5, 0, 0.02), dark_wood)
	_knob(left_pivot, Vector3(left_w - 0.06, 0, 0.04), brass)

	# Pintu kanan: TERBUKA sedikit. Engsel di sisi kanan depan, daun pintu mengayun ke luar.
	var right_pivot: Node3D = Node3D.new()
	right_pivot.name = "DoorRightPivot"
	right_pivot.position = Vector3(hw, h * 0.5, front_z)
	right_pivot.rotation_degrees = Vector3(0, DOOR_OPEN_ANGLE_DEG, 0)
	root.add_child(right_pivot)
	var right_w: float = 0.54
	_panel(right_pivot, Vector3(right_w, h - 0.1, 0.03), Vector3(-right_w * 0.5, 0, 0), wood)
	_panel(right_pivot, Vector3(right_w - 0.12, h - 0.4, 0.015), Vector3(-right_w * 0.5, 0, 0.02), dark_wood)
	_knob(right_pivot, Vector3(-right_w + 0.06, 0, 0.04), brass)

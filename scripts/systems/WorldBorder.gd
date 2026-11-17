extends Node3D

# Dinding tak terlihat di tepi peta + jaring pengaman supaya player tidak jatuh ke void.

const BORDER: float = 46.0
const WALL_HEIGHT: float = 30.0
const WALL_THICKNESS: float = 2.0
const VOID_Y: float = -6.0
const SAFE_RECORD_INTERVAL: float = 0.5

var _safe_position: Vector3 = Vector3(0, 1.0, 8.0)
var _record_timer: float = 0.0

func _ready() -> void:
	_build_walls()

func _build_walls() -> void:
	var span: float = BORDER * 2.0 + WALL_THICKNESS * 2.0
	# [posisi, ukuran] untuk utara, selatan, timur, barat
	var defs: Array[Array] = [
		[Vector3(0, WALL_HEIGHT * 0.5 - 2.0, -(BORDER + WALL_THICKNESS * 0.5)), Vector3(span, WALL_HEIGHT, WALL_THICKNESS)],
		[Vector3(0, WALL_HEIGHT * 0.5 - 2.0, BORDER + WALL_THICKNESS * 0.5), Vector3(span, WALL_HEIGHT, WALL_THICKNESS)],
		[Vector3(BORDER + WALL_THICKNESS * 0.5, WALL_HEIGHT * 0.5 - 2.0, 0), Vector3(WALL_THICKNESS, WALL_HEIGHT, span)],
		[Vector3(-(BORDER + WALL_THICKNESS * 0.5), WALL_HEIGHT * 0.5 - 2.0, 0), Vector3(WALL_THICKNESS, WALL_HEIGHT, span)]
	]
	for i: int in range(defs.size()):
		var body: StaticBody3D = StaticBody3D.new()
		body.name = 'BorderWall' + str(i)
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = defs[i][0]
		var shape: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = defs[i][1]
		shape.shape = box
		body.add_child(shape)
		add_child(body)

func _physics_process(delta: float) -> void:
	var player: Node3D = GameManager.player_character as Node3D
	if player == null or not is_instance_valid(player):
		return
	var pos: Vector3 = player.global_position

	# Jatuh ke void -> kembalikan ke posisi aman terakhir
	if pos.y < VOID_Y:
		player.global_position = _safe_position
		if 'velocity' in player:
			player.velocity = Vector3.ZERO
		return

	# Lolos dari dinding (misal lewat glitch) -> tarik kembali ke dalam batas
	if absf(pos.x) > BORDER + 0.5 or absf(pos.z) > BORDER + 0.5:
		player.global_position = Vector3(clampf(pos.x, -BORDER + 1.0, BORDER - 1.0), pos.y, clampf(pos.z, -BORDER + 1.0, BORDER - 1.0))
		return

	# Catat posisi aman secara berkala saat player berdiri di tanah
	_record_timer += delta
	if _record_timer >= SAFE_RECORD_INTERVAL:
		_record_timer = 0.0
		if pos.y > -0.5 and pos.y < 3.0 and absf(pos.x) < BORDER - 2.0 and absf(pos.z) < BORDER - 2.0:
			_safe_position = pos + Vector3(0, 0.3, 0)

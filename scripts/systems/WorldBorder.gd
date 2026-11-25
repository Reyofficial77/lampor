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
	_build_forest_perimeter()

func _build_forest_perimeter() -> void:
	# Alas tanah hutan gelap di luar batas desa supaya void tidak pernah terlihat dari sudut mana pun.
	var skirt := MeshInstance3D.new()
	skirt.name = "ForestGroundSkirt"
	skirt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var skirt_plane := PlaneMesh.new()
	skirt_plane.size = Vector2(210.0, 210.0)
	skirt.mesh = skirt_plane
	skirt.position = Vector3(0.0, -0.56, 0.0)
	var skirt_mat := StandardMaterial3D.new()
	skirt_mat.albedo_color = Color(0.038, 0.052, 0.036, 1.0)
	skirt_mat.roughness = 1.0
	skirt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	skirt.material_override = skirt_mat
	add_child(skirt)

	var is_mobile_low: bool = (OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or DisplayServer.is_touchscreen_available()) and SettingsManager.get_effective_graphics_quality() == "low"
	var tree_transforms_trunk: Array[Transform3D] = []
	var tree_transforms_low_canopy: Array[Transform3D] = []
	var tree_transforms_high_canopy: Array[Transform3D] = []
	var canopy_colors: Array[Color] = []

	var rng := RandomNumberGenerator.new()
	rng.seed = 133742

	var ring_defs: Array[Dictionary] = [
		{"min_d": 48.0, "max_d": 52.5, "step": 3.8, "h_min": 9.5, "h_max": 14.5, "offset": 0.0},
		{"min_d": 54.0, "max_d": 61.5, "step": 4.4, "h_min": 12.0, "h_max": 17.5, "offset": 2.1},
		{"min_d": 63.0, "max_d": 76.0, "step": 7.6 if is_mobile_low else 5.4, "h_min": 15.0, "h_max": 22.0, "offset": 1.3}
	]

	var seen_cells: Dictionary = {}
	for ring: Dictionary in ring_defs:
		var min_d: float = float(ring["min_d"])
		var max_d: float = float(ring["max_d"])
		var step: float = float(ring["step"])
		var h_min: float = float(ring["h_min"])
		var h_max: float = float(ring["h_max"])
		var phase: float = float(ring["offset"])
		var outer_span: float = max_d + 4.0

		var t: float = -outer_span + phase
		while t <= outer_span:
			var edge_candidates: Array[Vector2] = [
				Vector2(t + rng.randf_range(-0.9, 0.9), -rng.randf_range(min_d, max_d)),
				Vector2(t + rng.randf_range(-0.9, 0.9), rng.randf_range(min_d, max_d)),
				Vector2(-rng.randf_range(min_d, max_d), t + rng.randf_range(-0.9, 0.9)),
				Vector2(rng.randf_range(min_d, max_d), t + rng.randf_range(-0.9, 0.9))
			]
			for cand: Vector2 in edge_candidates:
				if absf(cand.x) < 47.2 and absf(cand.y) < 47.2:
					continue
				var cell_key: String = "%d:%d" % [int(round(cand.x / 2.6)), int(round(cand.y / 2.6))]
				if seen_cells.has(cell_key):
					continue
				seen_cells[cell_key] = true

				var trunk_h: float = rng.randf_range(h_min, h_max)
				var radius_s: float = rng.randf_range(0.85, 1.55)
				var yaw: float = rng.randf_range(0.0, TAU)
				var ground_y: float = -0.55

				var trunk_basis := Basis(Vector3.UP, yaw).scaled(Vector3(radius_s, trunk_h, radius_s))
				tree_transforms_trunk.append(Transform3D(trunk_basis, Vector3(cand.x, ground_y + trunk_h * 0.5, cand.y)))

				var low_scale: float = radius_s * rng.randf_range(1.05, 1.45)
				var low_h: float = trunk_h * rng.randf_range(0.55, 0.72)
				var low_y: float = ground_y + trunk_h * 0.42
				var low_basis := Basis(Vector3.UP, yaw + 0.4).scaled(Vector3(low_scale, low_h, low_scale))
				tree_transforms_low_canopy.append(Transform3D(low_basis, Vector3(cand.x, low_y, cand.y)))

				var high_scale: float = low_scale * rng.randf_range(0.70, 0.86)
				var high_h: float = trunk_h * rng.randf_range(0.45, 0.60)
				var high_y: float = ground_y + trunk_h * 0.80
				var high_basis := Basis(Vector3.UP, yaw + 1.1).scaled(Vector3(high_scale, high_h, high_scale))
				tree_transforms_high_canopy.append(Transform3D(high_basis, Vector3(cand.x, high_y, cand.y)))

				var shade: float = rng.randf_range(0.82, 1.18)
				canopy_colors.append(Color(0.045 * shade, 0.11 * shade, 0.055 * shade, 1.0))
			t += step

	var total_trees: int = tree_transforms_trunk.size()
	if total_trees <= 0:
		return

	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.24
	trunk_mesh.bottom_radius = 0.52
	trunk_mesh.height = 1.0
	trunk_mesh.radial_segments = 6
	trunk_mesh.rings = 1
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.11, 0.075, 0.052, 1.0)
	trunk_mat.roughness = 0.96
	trunk_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	trunk_mesh.material = trunk_mat

	var trunk_mm := MultiMesh.new()
	trunk_mm.transform_format = MultiMesh.TRANSFORM_3D
	trunk_mm.mesh = trunk_mesh
	trunk_mm.instance_count = total_trees
	for i: int in range(total_trees):
		trunk_mm.set_instance_transform(i, tree_transforms_trunk[i])

	var trunk_mmi := MultiMeshInstance3D.new()
	trunk_mmi.name = "ForestTrunks"
	trunk_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trunk_mmi.multimesh = trunk_mm
	add_child(trunk_mmi)

	var canopy_low_mesh := CylinderMesh.new()
	canopy_low_mesh.top_radius = 0.18
	canopy_low_mesh.bottom_radius = 2.65
	canopy_low_mesh.height = 1.0
	canopy_low_mesh.radial_segments = 7
	canopy_low_mesh.rings = 1
	var canopy_mat := StandardMaterial3D.new()
	canopy_mat.vertex_color_use_as_albedo = true
	canopy_mat.albedo_color = Color.WHITE
	canopy_mat.roughness = 0.94
	canopy_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	canopy_low_mesh.material = canopy_mat

	var canopy_low_mm := MultiMesh.new()
	canopy_low_mm.transform_format = MultiMesh.TRANSFORM_3D
	canopy_low_mm.use_colors = true
	canopy_low_mm.mesh = canopy_low_mesh
	canopy_low_mm.instance_count = total_trees
	for i: int in range(total_trees):
		canopy_low_mm.set_instance_transform(i, tree_transforms_low_canopy[i])
		canopy_low_mm.set_instance_color(i, canopy_colors[i])

	var canopy_low_mmi := MultiMeshInstance3D.new()
	canopy_low_mmi.name = "ForestCanopiesLower"
	canopy_low_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	canopy_low_mmi.multimesh = canopy_low_mm
	add_child(canopy_low_mmi)

	var canopy_high_mesh := CylinderMesh.new()
	canopy_high_mesh.top_radius = 0.08
	canopy_high_mesh.bottom_radius = 2.15
	canopy_high_mesh.height = 1.0
	canopy_high_mesh.radial_segments = 7
	canopy_high_mesh.rings = 1
	canopy_high_mesh.material = canopy_mat

	var canopy_high_mm := MultiMesh.new()
	canopy_high_mm.transform_format = MultiMesh.TRANSFORM_3D
	canopy_high_mm.use_colors = true
	canopy_high_mm.mesh = canopy_high_mesh
	canopy_high_mm.instance_count = total_trees
	for i: int in range(total_trees):
		canopy_high_mm.set_instance_transform(i, tree_transforms_high_canopy[i])
		var hc: Color = canopy_colors[i]
		canopy_high_mm.set_instance_color(i, Color(hc.r * 0.78, hc.g * 0.82, hc.b * 0.85, 1.0))

	var canopy_high_mmi := MultiMeshInstance3D.new()
	canopy_high_mmi.name = "ForestCanopiesUpper"
	canopy_high_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	canopy_high_mmi.multimesh = canopy_high_mm
	add_child(canopy_high_mmi)

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

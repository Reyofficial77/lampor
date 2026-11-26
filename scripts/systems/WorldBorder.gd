extends Node3D

# Dinding tak terlihat di tepi peta + jaring pengaman + hutan perimeter adaptif (2D/3D + sector culling).

const BORDER: float = 46.0
const WALL_HEIGHT: float = 30.0
const WALL_THICKNESS: float = 2.0
const VOID_Y: float = -6.0
const SAFE_RECORD_INTERVAL: float = 0.5
const SECTOR_COUNT: int = 8
const CULL_UPDATE_INTERVAL: float = 0.15

static var _tree_2d_tex: ImageTexture = null
static var _bamboo_2d_tex: ImageTexture = null

var _safe_position: Vector3 = Vector3(0, 1.0, 8.0)
var _record_timer: float = 0.0
var _cull_timer: float = 0.0

var _active_quality: String = ""
var _built_2d_quality: String = ""
var _built_3d: bool = false

var _forest_trunks_container: Node3D = null
var _forest_2d_container: Node3D = null

var _sector_nodes_2d: Array[Node3D] = []
var _sector_centers_2d: Array[Vector3] = []
var _sector_radii_2d: Array[float] = []

var _sector_nodes_3d: Array[Node3D] = []
var _sector_centers_3d: Array[Vector3] = []
var _sector_radii_3d: Array[float] = []

func _ready() -> void:
	_build_walls()
	_build_forest_containers()
	if not SettingsManager.graphics_quality_changed.is_connected(_on_graphics_quality_changed):
		SettingsManager.graphics_quality_changed.connect(_on_graphics_quality_changed)
	_apply_forest_quality(SettingsManager.get_effective_graphics_quality())

func get_active_tree_mode() -> String:
	return "3d" if _active_quality == "high" else "2d"

func get_total_sector_count() -> int:
	return SECTOR_COUNT

func get_visible_sector_count() -> int:
	var nodes: Array[Node3D] = _sector_nodes_3d if get_active_tree_mode() == "3d" else _sector_nodes_2d
	var count: int = 0
	for s_node: Node3D in nodes:
		if is_instance_valid(s_node) and s_node.visible:
			count += 1
	return count

func force_update_culling_for_camera(cam: Camera3D = null) -> void:
	_update_sector_culling(cam)

func _on_graphics_quality_changed(effective_quality: String) -> void:
	_apply_forest_quality(effective_quality)

func _normalize_quality(quality: String) -> String:
	var q: String = quality.to_lower()
	if q == "low" or q == "medium" or q == "high":
		return q
	return "medium"

func _build_forest_containers() -> void:
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

	_forest_trunks_container = Node3D.new()
	_forest_trunks_container.name = "ForestTrunks"
	_forest_trunks_container.visible = false
	add_child(_forest_trunks_container)

	_forest_2d_container = Node3D.new()
	_forest_2d_container.name = "Forest2DTrees"
	_forest_2d_container.visible = false
	add_child(_forest_2d_container)

func _apply_forest_quality(quality: String) -> void:
	var q: String = _normalize_quality(quality)
	_active_quality = q

	if q == "high":
		_ensure_3d_forest_built()
		if is_instance_valid(_forest_2d_container):
			_forest_2d_container.visible = false
		if is_instance_valid(_forest_trunks_container):
			_forest_trunks_container.visible = true
	else:
		if is_instance_valid(_forest_trunks_container):
			_forest_trunks_container.visible = false
		if _built_2d_quality != q:
			_rebuild_2d_forest(q)
		if is_instance_valid(_forest_2d_container):
			_forest_2d_container.visible = true

	_apply_bamboo_lod(q)
	_update_sector_culling()

func _compute_sector_index(x: float, z: float) -> int:
	var angle: float = wrapf(atan2(z, x), 0.0, TAU)
	return clampi(int(floor(angle / (TAU / float(SECTOR_COUNT)))), 0, SECTOR_COUNT - 1)

func _generate_perimeter_trees(ring_defs: Array[Dictionary], dedup_cell: float) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = 133742
	var seen_cells: Dictionary = {}
	var trees: Array[Dictionary] = []

	for ring: Dictionary in ring_defs:
		var min_d: float = float(ring["min_d"])
		var max_d: float = float(ring["max_d"])
		var step: float = float(ring["step"])
		var h_min: float = float(ring["h_min"])
		var h_max: float = float(ring["h_max"])
		var w_min: float = float(ring.get("w_min", 8.0))
		var w_max: float = float(ring.get("w_max", 12.0))
		var phase: float = float(ring["offset"])
		var outer_span: float = max_d + 3.0

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
				var cell_key: String = "%d:%d" % [int(round(cand.x / dedup_cell)), int(round(cand.y / dedup_cell))]
				if seen_cells.has(cell_key):
					continue
				seen_cells[cell_key] = true

				trees.append({
					"pos": cand,
					"sector": _compute_sector_index(cand.x, cand.y),
					"height": rng.randf_range(h_min, h_max),
					"width": rng.randf_range(w_min, w_max),
					"radius_s": rng.randf_range(0.85, 1.55),
					"yaw": rng.randf_range(0.0, TAU),
					"shade": rng.randf_range(0.82, 1.18),
					"low_scale_mul": rng.randf_range(1.05, 1.45),
					"low_h_mul": rng.randf_range(0.55, 0.72),
					"high_scale_mul": rng.randf_range(0.70, 0.86),
					"high_h_mul": rng.randf_range(0.45, 0.60)
				})
			t += step
	return trees

func _compute_sector_bounds(points: Array[Vector3], padding: float) -> Dictionary:
	if points.is_empty():
		return {"center": Vector3.ZERO, "radius": 0.0, "aabb": AABB(Vector3.ZERO, Vector3.ONE)}
	var min_p: Vector3 = points[0]
	var max_p: Vector3 = points[0]
	for p: Vector3 in points:
		min_p = min_p.min(p)
		max_p = max_p.max(p)
	var center: Vector3 = (min_p + max_p) * 0.5
	var max_r: float = 0.0
	for p: Vector3 in points:
		var dx: float = p.x - center.x
		var dz: float = p.z - center.z
		max_r = maxf(max_r, sqrt(dx * dx + dz * dz))
	var pad_vec := Vector3(padding, padding, padding)
	var aabb := AABB(min_p - pad_vec, (max_p - min_p) + pad_vec * 2.0)
	return {"center": Vector3(center.x, 0.0, center.z), "radius": max_r + padding, "aabb": aabb}

func _rebuild_2d_forest(quality: String) -> void:
	for child: Node in _forest_2d_container.get_children():
		_forest_2d_container.remove_child(child)
		child.queue_free()
	_sector_nodes_2d.clear()
	_sector_centers_2d.clear()
	_sector_radii_2d.clear()

	var is_low: bool = (quality == "low")
	# Low: ~64-80 billboard quads; Medium: ~96-112 billboard quads.
	var ring_defs: Array[Dictionary] = []
	if is_low:
		ring_defs = [
			{"min_d": 48.5, "max_d": 54.0, "step": 8.4, "h_min": 13.0, "h_max": 18.5, "w_min": 11.2, "w_max": 15.2, "offset": 0.0},
			{"min_d": 56.0, "max_d": 63.5, "step": 26.0, "h_min": 15.5, "h_max": 21.0, "w_min": 12.5, "w_max": 16.5, "offset": 3.5}
		]
	else:
		ring_defs = [
			{"min_d": 48.0, "max_d": 53.0, "step": 7.8, "h_min": 12.5, "h_max": 18.0, "w_min": 9.8, "w_max": 13.2, "offset": 0.0},
			{"min_d": 54.5, "max_d": 63.5, "step": 11.5, "h_min": 15.0, "h_max": 21.5, "w_min": 11.0, "w_max": 15.0, "offset": 2.3}
		]

	var trees: Array[Dictionary] = _generate_perimeter_trees(ring_defs, 3.2 if is_low else 2.8)
	var sector_buckets: Array[Array] = []
	for _s: int in range(SECTOR_COUNT):
		sector_buckets.append([])
	for entry: Dictionary in trees:
		sector_buckets[int(entry["sector"])].append(entry)

	var quad_mesh := QuadMesh.new()
	quad_mesh.size = Vector2(1.0, 1.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _get_or_create_tree_2d_texture()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.42
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.billboard_keep_scale = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad_mesh.material = mat

	var ground_y: float = -0.55
	for s: int in range(SECTOR_COUNT):
		var bucket: Array = sector_buckets[s]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = quad_mesh
		mm.instance_count = bucket.size()

		var pts: Array[Vector3] = []
		for i: int in range(bucket.size()):
			var item: Dictionary = bucket[i]
			var cand: Vector2 = item["pos"]
			var h: float = float(item["height"])
			var w: float = float(item["width"])
			var shade: float = float(item["shade"])
			var center_pos := Vector3(cand.x, ground_y + h * 0.5, cand.y)
			pts.append(center_pos)

			var xform := Transform3D(Basis.from_scale(Vector3(w, h, 1.0)), center_pos)
			mm.set_instance_transform(i, xform)
			mm.set_instance_color(i, Color(0.86 * shade, 0.94 * shade, 0.90 * shade, 1.0))

		var bounds: Dictionary = _compute_sector_bounds(pts, 10.0)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Sector" + str(s)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.multimesh = mm
		if not pts.is_empty():
			mmi.custom_aabb = bounds["aabb"]
		else:
			mmi.visible = false
		_forest_2d_container.add_child(mmi)

		_sector_nodes_2d.append(mmi)
		_sector_centers_2d.append(bounds["center"])
		_sector_radii_2d.append(float(bounds["radius"]))

	_built_2d_quality = quality

func _ensure_3d_forest_built() -> void:
	if _built_3d:
		return
	_built_3d = true

	var ring_defs: Array[Dictionary] = [
		{"min_d": 48.0, "max_d": 53.5, "step": 8.6, "h_min": 10.0, "h_max": 15.0, "offset": 0.0},
		{"min_d": 55.0, "max_d": 63.0, "step": 14.0, "h_min": 13.0, "h_max": 18.5, "offset": 2.1},
		{"min_d": 64.5, "max_d": 75.0, "step": 32.0, "h_min": 15.5, "h_max": 22.0, "offset": 1.3}
	]
	var trees: Array[Dictionary] = _generate_perimeter_trees(ring_defs, 2.7)
	var sector_buckets: Array[Array] = []
	for _s: int in range(SECTOR_COUNT):
		sector_buckets.append([])
	for entry: Dictionary in trees:
		sector_buckets[int(entry["sector"])].append(entry)

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

	var canopy_mat := StandardMaterial3D.new()
	canopy_mat.vertex_color_use_as_albedo = true
	canopy_mat.albedo_color = Color.WHITE
	canopy_mat.roughness = 0.94
	canopy_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX

	var canopy_low_mesh := CylinderMesh.new()
	canopy_low_mesh.top_radius = 0.22
	canopy_low_mesh.bottom_radius = 2.7
	canopy_low_mesh.height = 1.0
	canopy_low_mesh.radial_segments = 7
	canopy_low_mesh.rings = 1
	canopy_low_mesh.material = canopy_mat

	var canopy_high_mesh := CylinderMesh.new()
	canopy_high_mesh.top_radius = 0.08
	canopy_high_mesh.bottom_radius = 2.15
	canopy_high_mesh.height = 1.0
	canopy_high_mesh.radial_segments = 7
	canopy_high_mesh.rings = 1
	canopy_high_mesh.material = canopy_mat

	var ground_y: float = -0.55
	for s: int in range(SECTOR_COUNT):
		var bucket: Array = sector_buckets[s]
		var sector_node := Node3D.new()
		sector_node.name = "Sector" + str(s)
		_forest_trunks_container.add_child(sector_node)

		var n: int = bucket.size()
		var trunk_mm := MultiMesh.new()
		trunk_mm.transform_format = MultiMesh.TRANSFORM_3D
		trunk_mm.mesh = trunk_mesh
		trunk_mm.instance_count = n

		var low_mm := MultiMesh.new()
		low_mm.transform_format = MultiMesh.TRANSFORM_3D
		low_mm.use_colors = true
		low_mm.mesh = canopy_low_mesh
		low_mm.instance_count = n

		var high_mm := MultiMesh.new()
		high_mm.transform_format = MultiMesh.TRANSFORM_3D
		high_mm.use_colors = true
		high_mm.mesh = canopy_high_mesh
		high_mm.instance_count = n

		var pts: Array[Vector3] = []
		for i: int in range(n):
			var item: Dictionary = bucket[i]
			var cand: Vector2 = item["pos"]
			var trunk_h: float = float(item["height"])
			var radius_s: float = float(item["radius_s"])
			var yaw: float = float(item["yaw"])
			var shade: float = float(item["shade"])

			var trunk_pos := Vector3(cand.x, ground_y + trunk_h * 0.5, cand.y)
			pts.append(trunk_pos)
			var trunk_basis := Basis(Vector3.UP, yaw).scaled(Vector3(radius_s, trunk_h, radius_s))
			trunk_mm.set_instance_transform(i, Transform3D(trunk_basis, trunk_pos))

			var low_scale: float = radius_s * float(item["low_scale_mul"])
			var low_h: float = trunk_h * float(item["low_h_mul"])
			var low_basis := Basis(Vector3.UP, yaw + 0.4).scaled(Vector3(low_scale, low_h, low_scale))
			low_mm.set_instance_transform(i, Transform3D(low_basis, Vector3(cand.x, ground_y + trunk_h * 0.42, cand.y)))
			var cc := Color(0.045 * shade, 0.11 * shade, 0.055 * shade, 1.0)
			low_mm.set_instance_color(i, cc)

			var high_scale: float = low_scale * float(item["high_scale_mul"])
			var high_h: float = trunk_h * float(item["high_h_mul"])
			var high_basis := Basis(Vector3.UP, yaw + 1.1).scaled(Vector3(high_scale, high_h, high_scale))
			high_mm.set_instance_transform(i, Transform3D(high_basis, Vector3(cand.x, ground_y + trunk_h * 0.80, cand.y)))
			high_mm.set_instance_color(i, Color(cc.r * 0.78, cc.g * 0.82, cc.b * 0.85, 1.0))

		var bounds: Dictionary = _compute_sector_bounds(pts, 12.0)

		var trunk_mmi := MultiMeshInstance3D.new()
		trunk_mmi.name = "Trunks"
		trunk_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		trunk_mmi.multimesh = trunk_mm
		if not pts.is_empty():
			trunk_mmi.custom_aabb = bounds["aabb"]
		sector_node.add_child(trunk_mmi)

		var low_mmi := MultiMeshInstance3D.new()
		low_mmi.name = "CanopiesLower"
		low_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		low_mmi.multimesh = low_mm
		if not pts.is_empty():
			low_mmi.custom_aabb = bounds["aabb"]
		sector_node.add_child(low_mmi)

		var high_mmi := MultiMeshInstance3D.new()
		high_mmi.name = "CanopiesUpper"
		high_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		high_mmi.multimesh = high_mm
		if not pts.is_empty():
			high_mmi.custom_aabb = bounds["aabb"]
		sector_node.add_child(high_mmi)

		if pts.is_empty():
			sector_node.visible = false
		_sector_nodes_3d.append(sector_node)
		_sector_centers_3d.append(bounds["center"])
		_sector_radii_3d.append(float(bounds["radius"]))

func _update_sector_culling(cam_override: Camera3D = null) -> void:
	var is_3d: bool = (get_active_tree_mode() == "3d")
	var nodes: Array[Node3D] = _sector_nodes_3d if is_3d else _sector_nodes_2d
	var centers: Array[Vector3] = _sector_centers_3d if is_3d else _sector_centers_2d
	var radii: Array[float] = _sector_radii_3d if is_3d else _sector_radii_2d
	if nodes.size() < SECTOR_COUNT or centers.size() < SECTOR_COUNT or radii.size() < SECTOR_COUNT:
		return

	var cam: Camera3D = cam_override if (cam_override != null and is_instance_valid(cam_override)) else (get_viewport().get_camera_3d() if get_viewport() else null)
	var has_view: bool = false
	var cam_pos := Vector3.ZERO
	var cam_fwd := Vector3(0.0, 0.0, -1.0)

	if cam != null and is_instance_valid(cam):
		has_view = true
		cam_pos = cam.global_position
		var raw_fwd: Vector3 = -cam.global_transform.basis.z
		cam_fwd = Vector3(raw_fwd.x, 0.0, raw_fwd.z)
		if cam_fwd.length_squared() > 0.0001:
			cam_fwd = cam_fwd.normalized()
		else:
			cam_fwd = Vector3(0.0, 0.0, -1.0)
	else:
		var player: Node3D = GameManager.player_character as Node3D
		if player != null and is_instance_valid(player):
			has_view = true
			cam_pos = player.global_position
			var p_fwd: Vector3 = -player.global_transform.basis.z
			cam_fwd = Vector3(p_fwd.x, 0.0, p_fwd.z)
			if cam_fwd.length_squared() > 0.0001:
				cam_fwd = cam_fwd.normalized()
			else:
				cam_fwd = Vector3(0.0, 0.0, -1.0)

	if not has_view:
		for s: int in range(SECTOR_COUNT):
			if is_instance_valid(nodes[s]):
				nodes[s].visible = radii[s] > 0.0
		return

	var max_dist: float = 72.0 if _active_quality == "low" else (96.0 if _active_quality == "medium" else 130.0)
	for s: int in range(SECTOR_COUNT):
		var s_node: Node3D = nodes[s]
		if not is_instance_valid(s_node):
			continue
		var s_radius: float = radii[s]
		if s_radius <= 0.0:
			s_node.visible = false
			continue
		var delta_xz := Vector3(centers[s].x - cam_pos.x, 0.0, centers[s].z - cam_pos.z)
		var dist_xz: float = delta_xz.length()
		var edge_dist: float = maxf(0.0, dist_xz - s_radius)
		if edge_dist > max_dist:
			s_node.visible = false
			continue
		if dist_xz > s_radius + 6.0:
			var to_sector_dir: Vector3 = delta_xz / dist_xz
			if cam_fwd.dot(to_sector_dir) < -0.35:
				s_node.visible = false
				continue
		s_node.visible = true

func _apply_bamboo_lod(quality: String) -> void:
	var map_root: Node = get_parent()
	if map_root == null:
		return
	var use_3d: bool = (quality == "high")
	for cluster_name: String in ["BambooNorth", "BambooSouth"]:
		var cluster: Node3D = map_root.get_node_or_null(cluster_name) as Node3D
		if cluster == null:
			continue
		for stalk_name: String in ["B1", "B2", "B3"]:
			var stalk: Node3D = cluster.get_node_or_null(stalk_name) as Node3D
			if stalk != null:
				stalk.visible = use_3d
		var bamboo_2d: MeshInstance3D = cluster.get_node_or_null("Bamboo2D") as MeshInstance3D
		if use_3d:
			if bamboo_2d != null:
				bamboo_2d.visible = false
		else:
			if bamboo_2d == null:
				bamboo_2d = _create_bamboo_2d_node()
				cluster.add_child(bamboo_2d)
			bamboo_2d.visible = true

func _create_bamboo_2d_node() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Bamboo2D"
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0.0, 3.6, 0.0)
	var quad := QuadMesh.new()
	quad.size = Vector2(5.4, 7.2)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _get_or_create_bamboo_2d_texture()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.42
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.billboard_keep_scale = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = mat
	mi.mesh = quad
	return mi

static func _get_or_create_tree_2d_texture() -> Texture2D:
	if _tree_2d_tex != null:
		return _tree_2d_tex
	var w: int = 128
	var h: int = 192
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))

	var cx: float = float(w) * 0.5
	# Batang pohon meruncing dengan akar melebar di dasar.
	for y: int in range(96, h):
		var t: float = float(y - 96) / float(h - 96)
		var half_w: float = lerpf(4.0, 9.5, t)
		if t > 0.82:
			half_w += (t - 0.82) * 34.0
		var x_min: int = maxi(0, int(floor(cx - half_w)))
		var x_max: int = mini(w - 1, int(ceil(cx + half_w)))
		for x: int in range(x_min, x_max + 1):
			var dx: float = absf(float(x) - cx) / maxf(1.0, half_w)
			var bark_groove: float = sin(float(x) * 1.3 + float(y) * 0.25) * 0.03
			var root_gap: bool = (t > 0.88 and dx < 0.22 and sin(float(x) * 0.9) > 0.3)
			if dx <= 1.0 and not root_gap:
				var rim: float = (1.0 - dx) * 0.05
				img.set_pixel(x, y, Color(0.11 + rim + bark_groove, 0.08 + rim, 0.06 + rim * 0.5, 1.0))

	# Lapisan tajuk pohon rimbun khas hutan malam Indonesia (pinus/beringin gelap dengan highlight cahaya bulan).
	var clusters: Array[Array] = [
		[64.0, 24.0, 18.0, 16.0],
		[48.0, 40.0, 22.0, 17.0],
		[80.0, 42.0, 22.0, 17.0],
		[64.0, 48.0, 28.0, 20.0],
		[38.0, 68.0, 28.0, 21.0],
		[90.0, 68.0, 28.0, 21.0],
		[64.0, 74.0, 35.0, 24.0],
		[32.0, 98.0, 30.0, 22.0],
		[96.0, 98.0, 30.0, 22.0],
		[64.0, 102.0, 40.0, 24.0],
		[44.0, 118.0, 28.0, 16.0],
		[84.0, 118.0, 28.0, 16.0]
	]

	for y: int in range(0, 144):
		for x: int in range(0, w):
			var inside_val: float = 0.0
			var best_top_bias: float = 0.0
			for c: Array in clusters:
				var ccx: float = float(c[0])
				var ccy: float = float(c[1])
				var rx: float = float(c[2])
				var ry: float = float(c[3])
				var nx: float = (float(x) - ccx) / rx
				var ny: float = (float(y) - ccy) / ry
				var angle: float = atan2(ny, nx)
				var wobble: float = 0.11 * sin(angle * 7.0 + ccx * 0.2) + 0.06 * cos(angle * 13.0 + ccy * 0.3)
				var d: float = sqrt(nx * nx + ny * ny) + wobble
				if d < 1.0:
					inside_val = maxf(inside_val, 1.0 - d)
					best_top_bias = maxf(best_top_bias, clampf(-ny * 0.5 + 0.5, 0.0, 1.0))
			if inside_val > 0.02:
				var height_lit: float = clampf(1.0 - float(y) / 138.0, 0.0, 1.0)
				var leaf_tex: float = 0.5 + 0.5 * sin(float(x) * 0.45 + float(y) * 0.55)
				var moon_rim: float = pow(height_lit, 1.3) * 0.65 + best_top_bias * 0.35
				var r_col: float = lerpf(0.032, 0.095, moon_rim) + leaf_tex * 0.015
				var g_col: float = lerpf(0.065, 0.195, moon_rim) + leaf_tex * 0.028
				var b_col: float = lerpf(0.042, 0.145, moon_rim) + leaf_tex * 0.018
				var alpha: float = clampf(inside_val * 7.5, 0.0, 1.0)
				img.set_pixel(x, y, Color(r_col, g_col, b_col, alpha))

	img.generate_mipmaps()
	_tree_2d_tex = ImageTexture.create_from_image(img)
	return _tree_2d_tex

static func _get_or_create_bamboo_2d_texture() -> Texture2D:
	if _bamboo_2d_tex != null:
		return _bamboo_2d_tex
	var w: int = 96
	var h: int = 192
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))

	# Tiga batang bambu ramping beruas + daun bambu tipis di bagian atas.
	var stalks: Array[Array] = [
		[22.0, 18.0, 3.3],
		[48.0, 49.0, 3.8],
		[74.0, 79.0, 3.2]
	]
	for st: Array in stalks:
		var x_bot: float = float(st[0])
		var x_top: float = float(st[1])
		var half_r: float = float(st[2])
		for y: int in range(8, h):
			var t: float = float(y) / float(h)
			var sx: float = lerpf(x_top, x_bot, t)
			var is_node_ring: bool = (y % 28) <= 2
			var xmin: int = maxi(0, int(floor(sx - half_r)))
			var xmax: int = mini(w - 1, int(ceil(sx + half_r)))
			for x: int in range(xmin, xmax + 1):
				var dx: float = absf(float(x) - sx) / half_r
				if dx <= 1.0:
					var shade: float = 0.72 if is_node_ring else (1.0 - dx * 0.38)
					img.set_pixel(x, y, Color(0.18 * shade, 0.34 * shade, 0.13 * shade, 1.0))

	# Daun bambu meruncing di bagian atas.
	var leaf_anchors: Array[Vector2] = [
		Vector2(20, 26), Vector2(48, 22), Vector2(76, 30),
		Vector2(24, 58), Vector2(50, 50), Vector2(74, 62),
		Vector2(44, 82), Vector2(68, 86)
	]
	for anc: Vector2 in leaf_anchors:
		for k: int in range(-2, 3):
			var dir_x: float = float(k) * 0.55
			var dir_y: float = 0.45 + absf(float(k)) * 0.12
			for step_i: int in range(1, 18):
				var lx: int = int(round(anc.x + dir_x * float(step_i)))
				var ly: int = int(round(anc.y + dir_y * float(step_i)))
				if lx >= 0 and lx < w and ly >= 0 and ly < h:
					img.set_pixel(lx, ly, Color(0.14, 0.28, 0.11, 1.0))

	img.generate_mipmaps()
	_bamboo_2d_tex = ImageTexture.create_from_image(img)
	return _bamboo_2d_tex

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
		body.name = "BorderWall" + str(i)
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
	_cull_timer += delta
	if _cull_timer >= CULL_UPDATE_INTERVAL:
		_cull_timer = 0.0
		_update_sector_culling()

	var player: Node3D = GameManager.player_character as Node3D
	if player == null or not is_instance_valid(player):
		return
	var pos: Vector3 = player.global_position

	# Jatuh ke void -> kembalikan ke posisi aman terakhir
	if pos.y < VOID_Y:
		player.global_position = _safe_position
		if "velocity" in player:
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

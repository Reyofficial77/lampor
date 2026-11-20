class_name LamporStateMachine
extends CharacterBody3D

enum State { DORMANT_SKY, DESCENDING, PATROL, INVESTIGATE, STARE_PUNISHMENT, CHASE, BANISHED }
var current_state: State = State.DORMANT_SKY

@export var patrol_speed: float = 3.2
@export var chase_speed: float = 6.8
@export var stare_threshold: float = 0.82
@export var sight_range: float = 35.0
@export var hearing_range: float = 24.0

var waypoints: Array[Vector3] = []
var current_waypoint_idx: int = 0
var target_position: Vector3 = Vector3.ZERO

var player: PlayerController = null
var stare_timer: float = 0.0
var bell_timer: float = 0.0
var bell_interval: float = 12.0

var hover_offset: float = 2.0
var hover_time: float = 0.0
var sky_time: float = 0.0

var descend_target: Vector3 = Vector3.ZERO
var is_descending: bool = false

# Batas pengejaran supaya Lampor tidak mengikuti player selamanya
const MAX_CHASE_TIME: float = 18.0
const LOST_SIGHT_GIVE_UP: float = 5.0
const CHASE_COOLDOWN_TIME: float = 10.0
var chase_timer: float = 0.0
var lost_sight_timer: float = 0.0
var chase_cooldown: float = 0.0
var stare_punish_timer: float = 0.0
var is_catching: bool = false

@onready var visual_mesh: Node3D = $Visuals
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var audio_bell: AudioStreamPlayer3D = $AudioBell
@onready var audio_roar: AudioStreamPlayer3D = $AudioRoar
@onready var red_light: OmniLight3D = $Visuals/LanternLight

func _ready() -> void:
	_build_keranda_model()

	# Start dormant high in the sky
	current_state = State.DORMANT_SKY
	global_position = Vector3(0, 45.0, 0)
	if collision_shape:
		collision_shape.disabled = true
	if red_light:
		red_light.light_energy = 0.8
		red_light.light_color = Color(0.2, 0.8, 0.3)

	# Apply difficulty tuning from GameManager
	var speeds: Dictionary = GameManager.get_lampor_speeds_for_difficulty(GameManager.selected_difficulty)
	patrol_speed = speeds.get("patrol", 3.2)
	chase_speed = speeds.get("chase", 6.8)
	hearing_range = speeds.get("hearing", 24.0)

	# Connect signals
	SignalBus.player_noise_made.connect(_on_player_noise)
	SignalBus.act_started.connect(_on_act_started)
	SignalBus.lampor_state_changed.connect(func(new_state_str: String) -> void:
		if GameManager.is_resuming_saved_run:
			return
		if new_state_str == "CHASE":
			if current_state == State.DORMANT_SKY or current_state == State.DESCENDING:
				trigger_descent(true)
			else:
				_set_state(State.CHASE)
	)
	
	call_deferred("_setup_waypoints")

# ---------- Model keranda (dibangun lewat kode) ----------

func _kmat(color: Color, rough: float = 0.85, metal: float = 0.0, glow: float = 0.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	return m

func _kpart(mesh: Mesh, mat: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	visual_mesh.add_child(mi)
	return mi

func _kbox(x: float, y: float, z: float) -> BoxMesh:
	var b: BoxMesh = BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b

func _kcyl(radius: float, height: float) -> CylinderMesh:
	var c: CylinderMesh = CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	return c

func _ksph(radius: float, height: float = -1.0) -> SphereMesh:
	var s: SphereMesh = SphereMesh.new()
	s.radius = radius
	s.height = height if height > 0.0 else radius * 2.0
	return s

func _build_keranda_model() -> void:
	if not visual_mesh:
		return
	for old_name: String in ["CoffinBody", "ShroudCloth", "BambooPoleLeft", "BambooPoleRight", "ProceduralKeranda"]:
		var old: Node = visual_mesh.get_node_or_null(old_name)
		if old:
			old.queue_free()

	var tex_cloth: Texture2D = null
	if ResourceLoader.exists("res://assets/textures/cloth_green.png"):
		tex_cloth = load("res://assets/textures/cloth_green.png") as Texture2D

	var cloth_main: StandardMaterial3D = _kmat(Color(0.035, 0.34, 0.14), 0.92, 0.02, 0.04)
	var cloth_fold: StandardMaterial3D = _kmat(Color(0.018, 0.22, 0.085), 0.96, 0.0)
	var cloth_ridge: StandardMaterial3D = _kmat(Color(0.055, 0.42, 0.18), 0.88, 0.04, 0.06)
	if tex_cloth:
		cloth_main.albedo_texture = tex_cloth
		cloth_ridge.albedo_texture = tex_cloth

	var gold_bright: StandardMaterial3D = _kmat(Color(0.96, 0.78, 0.22), 0.28, 0.85, 0.45)
	var gold_fringe: StandardMaterial3D = _kmat(Color(0.88, 0.68, 0.16), 0.42, 0.72, 0.28)
	var steel_frame: StandardMaterial3D = _kmat(Color(0.62, 0.65, 0.68), 0.32, 0.88)
	var dark_iron: StandardMaterial3D = _kmat(Color(0.16, 0.17, 0.19), 0.65, 0.6)
	var wood_dark: StandardMaterial3D = _kmat(Color(0.24, 0.14, 0.07), 0.85)
	var rubber_foot: StandardMaterial3D = _kmat(Color(0.06, 0.06, 0.06), 0.95)
	var void_black: StandardMaterial3D = _kmat(Color(0.01, 0.01, 0.012), 1.0)
	var kafan_cloth: StandardMaterial3D = _kmat(Color(0.82, 0.80, 0.73), 0.92, 0.0, 0.05)

	# 1. RANGKA TANDU & BATANG PIKULAN KERANDA
	for sx: float in [-1.0, 1.0]:
		var px: float = sx * 0.54
		_kpart(_kcyl(0.034, 3.36), steel_frame, Vector3(px, -0.34, 0.0), Vector3(90, 0, 0))
		for sz: float in [-1.0, 1.0]:
			_kpart(_kcyl(0.040, 0.32), dark_iron, Vector3(px, -0.34, sz * 1.52), Vector3(90, 0, 0))
			_kpart(_ksph(0.042), gold_bright, Vector3(px, -0.34, sz * 1.69))
			_kpart(_kcyl(0.044, 0.05), dark_iron, Vector3(px, -0.34, sz * 1.20), Vector3(90, 0, 0))

	for cz: float in [-1.12, -0.38, 0.38, 1.12]:
		_kpart(_kbox(1.12, 0.048, 0.06), steel_frame, Vector3(0.0, -0.34, cz))
	_kpart(_kbox(1.04, 0.055, 2.34), wood_dark, Vector3(0.0, -0.305, 0.0))

	# 4 Kaki penopang keranda beserta sepatu karet & penyangga sudut
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var lx: float = sx * 0.50
			var lz: float = sz * 1.06
			_kpart(_kcyl(0.026, 0.24), steel_frame, Vector3(lx, -0.45, lz))
			_kpart(_kcyl(0.018, 0.18), steel_frame, Vector3(lx, -0.42, lz - sz * 0.08), Vector3(sz * 32.0, 0, 0))
			_kpart(_kcyl(0.042, 0.035), rubber_foot, Vector3(lx, -0.57, lz))

	# 2. BADAN KURUNG BATANG & KAIN BELUDRU HIJAU PENUTUP KERANDA
	_kpart(_kbox(1.06, 0.50, 2.40), cloth_main, Vector3(0.0, -0.03, 0.0))
	_kpart(_kcyl(0.53, 2.40), cloth_main, Vector3(0.0, 0.22, 0.0), Vector3(90, 0, 0), Vector3(1.0, 1.0, 0.66))

	for rz: float in [-1.14, -0.57, 0.0, 0.57, 1.14]:
		_kpart(_kbox(1.084, 0.48, 0.036), cloth_ridge, Vector3(0.0, -0.02, rz))
		_kpart(_kcyl(0.542, 0.038), cloth_ridge, Vector3(0.0, 0.22, rz), Vector3(90, 0, 0), Vector3(1.0, 1.0, 0.66))

	for side: float in [-1.0, 1.0]:
		for i: int in range(15):
			var fz: float = -1.05 + float(i) * 0.15
			var fold_mat: StandardMaterial3D = cloth_fold if (i % 2 == 0) else cloth_ridge
			_kpart(_kbox(0.012, 0.52, 0.045), fold_mat, Vector3(side * 0.534, -0.04, fz))

	# 3. PITA BORDIR EMAS, BINGKAI KALIGRAFI, & MEDALI KERANDA
	for side: float in [-1.0, 1.0]:
		_kpart(_kbox(0.022, 0.055, 2.44), gold_bright, Vector3(side * 0.542, -0.21, 0.0))
		_kpart(_kbox(0.022, 0.022, 2.44), gold_fringe, Vector3(side * 0.542, -0.265, 0.0))
	_kpart(_kbox(1.09, 0.055, 0.022), gold_bright, Vector3(0.0, -0.21, -1.21))
	_kpart(_kbox(1.09, 0.022, 0.022), gold_fringe, Vector3(0.0, -0.265, -1.21))
	_kpart(_kbox(0.075, 0.016, 2.42), gold_bright, Vector3(0.0, 0.572, 0.0))
	for sz: float in [-1.0, 1.0]:
		_kpart(_kcyl(0.545, 0.028), gold_bright, Vector3(0.0, 0.22, sz * 1.202), Vector3(90, 0, 0), Vector3(1.0, 1.0, 0.66))

	for side: float in [-1.0, 1.0]:
		var sx_pos: float = side * 0.544
		_kpart(_kbox(0.014, 0.024, 1.64), gold_bright, Vector3(sx_pos, 0.21, 0.0))
		_kpart(_kbox(0.014, 0.024, 1.64), gold_bright, Vector3(sx_pos, -0.11, 0.0))
		_kpart(_kbox(0.014, 0.34, 0.028), gold_bright, Vector3(sx_pos, 0.05, -0.82))
		_kpart(_kbox(0.014, 0.34, 0.028), gold_bright, Vector3(sx_pos, 0.05, 0.82))

		for rz_end: float in [-0.99, 0.99]:
			_kpart(_kcyl(0.085, 0.016), gold_bright, Vector3(sx_pos, 0.05, rz_end), Vector3(0, 0, 90))
			_kpart(_kcyl(0.055, 0.020), cloth_main, Vector3(side * 0.546, 0.05, rz_end), Vector3(0, 0, 90))
			_kpart(_ksph(0.026), gold_bright, Vector3(side * 0.548, 0.05, rz_end))

		for i: int in range(13):
			var cz: float = -0.68 + float(i) * 0.113
			var wave: float = sin(float(i) * 1.45)
			var stem_h: float = 0.08 + 0.09 * absf(cos(float(i) * 1.15))
			_kpart(_kbox(0.016, 0.024, 0.088), gold_bright, Vector3(sx_pos, 0.01 + wave * 0.018, cz))
			if i % 2 == 0:
				_kpart(_kbox(0.016, stem_h, 0.022), gold_bright, Vector3(sx_pos, 0.03 + stem_h * 0.5, cz - 0.02))
			if i % 3 == 1:
				_kpart(_kbox(0.016, 0.042, 0.052), gold_bright, Vector3(sx_pos, -0.025, cz + 0.015), Vector3(22.0, 0, 0))
			_kpart(_kbox(0.016, 0.018, 0.018), gold_bright, Vector3(sx_pos, 0.145 if (i % 2 == 0) else -0.06, cz + 0.01), Vector3(45, 0, 0))

	for sz: float in [-1.0, 1.0]:
		var mz: float = sz * 1.212
		_kpart(_kcyl(0.14, 0.016), gold_bright, Vector3(0.0, 0.30, mz), Vector3(90, 0, 0))
		_kpart(_kcyl(0.105, 0.018), cloth_fold, Vector3(0.0, 0.30, mz + sz * 0.002), Vector3(90, 0, 0))
		_kpart(_kbox(0.12, 0.02, 0.02), gold_bright, Vector3(0.0, 0.29, mz + sz * 0.005))
		_kpart(_kbox(0.02, 0.11, 0.02), gold_bright, Vector3(-0.03, 0.31, mz + sz * 0.005))
		_kpart(_kbox(0.02, 0.09, 0.02), gold_bright, Vector3(0.035, 0.30, mz + sz * 0.005))

	# 4. RUMBAI-RUMBAI BENANG EMAS MENGGANTUNG
	for side: float in [-1.0, 1.0]:
		for i: int in range(21):
			var tz: float = -1.10 + float(i) * 0.11
			_kpart(_ksph(0.014), gold_bright, Vector3(side * 0.542, -0.285, tz))
			_kpart(_kcyl(0.011, 0.085), gold_fringe, Vector3(side * 0.542, -0.33, tz))
	for sz: float in [-1.0, 1.0]:
		for i: int in range(11):
			var tx: float = -0.48 + float(i) * 0.096
			_kpart(_ksph(0.014), gold_bright, Vector3(tx, -0.285, sz * 1.212))
			_kpart(_kcyl(0.011, 0.085), gold_fringe, Vector3(tx, -0.33, sz * 1.212))

	# 5. TIRAI DEPAN TERSINGKAP HOROR, RONGGA GELAP, & SILUET JENAZAH BERKAFAN
	_kpart(_kbox(0.74, 0.42, 0.06), void_black, Vector3(0.0, -0.03, 1.185))
	_kpart(_kbox(0.22, 0.46, 0.04), cloth_fold, Vector3(-0.39, -0.03, 1.20), Vector3(0, 0, -10))
	_kpart(_kbox(0.22, 0.46, 0.04), cloth_fold, Vector3(0.39, -0.03, 1.20), Vector3(0, 0, 10))
	_kpart(_kbox(0.025, 0.46, 0.045), gold_bright, Vector3(-0.28, -0.03, 1.208), Vector3(0, 0, -10))
	_kpart(_kbox(0.025, 0.46, 0.045), gold_bright, Vector3(0.28, -0.03, 1.208), Vector3(0, 0, 10))
	_kpart(_ksph(0.135), kafan_cloth, Vector3(0.0, -0.08, 1.13), Vector3.ZERO, Vector3(0.95, 1.1, 0.85))
	_kpart(_kbox(0.24, 0.022, 0.08), wood_dark, Vector3(0.0, -0.20, 1.15))

	var eye_l: Node3D = visual_mesh.get_node_or_null("EyeLeft") as Node3D
	var eye_r: Node3D = visual_mesh.get_node_or_null("EyeRight") as Node3D
	if eye_l:
		eye_l.position = Vector3(-0.16, 0.05, 1.215)
	if eye_r:
		eye_r.position = Vector3(0.16, 0.05, 1.215)

func _setup_waypoints() -> void:
	var path_nodes: Array[Node] = get_tree().get_nodes_in_group("lampor_waypoint")
	if path_nodes.size() > 0:
		for n: Node in path_nodes:
			if n is Node3D:
				waypoints.append(n.global_position)
	else:
		waypoints = [
			Vector3(0, 2.0, -20),
			Vector3(25, 2.0, 15),
			Vector3(15, 2.0, -25),
			Vector3(-20, 2.0, -20),
			Vector3(-25, 2.0, 20)
		]
	if waypoints.size() > 0:
		target_position = waypoints[0]
		descend_target = waypoints[0]

func _on_act_started(act_number: int, _title: String) -> void:
	if GameManager.is_resuming_saved_run:
		return
	if act_number >= 2 and current_state == State.DORMANT_SKY:
		trigger_descent()

func trigger_descent(immediate_chase: bool = false) -> void:
	if current_state != State.DORMANT_SKY and current_state != State.DESCENDING:
		return
		
	current_state = State.DESCENDING
	is_descending = true
	
	if waypoints.size() > 0:
		descend_target = waypoints[0]
	else:
		descend_target = Vector3(0, 2.5, -20)
		
	if audio_roar:
		audio_roar.play()
	if audio_bell:
		audio_bell.play()
		
	if red_light:
		red_light.light_energy = 4.0
		red_light.light_color = Color(1.0, 0.2, 0.1)

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", descend_target, 4.0)
	tween.tween_callback(func() -> void:
		is_descending = false
		if collision_shape:
			collision_shape.disabled = false
		if immediate_chase:
			_set_state(State.CHASE)
		else:
			_set_state(State.PATROL)
	)

func safe_look_at(target_pos: Vector3) -> void:
	var flat_target: Vector3 = Vector3(target_pos.x, global_position.y, target_pos.z)
	if global_position.distance_squared_to(flat_target) > 0.05:
		look_at(flat_target, Vector3.UP, true)

func has_line_of_sight_to_player() -> bool:
	if not player or not is_instance_valid(player):
		return false

	# Player inside any house is ALWAYS protected from Lampor's line of sight
	if player.is_inside_house:
		return false

	# Physics direct space raycast check
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var origin: Vector3 = global_position + Vector3(0, 0.4, 0)
	var target: Vector3 = player.global_position + Vector3(0, 1.0, 0)
	
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, target)
	query.collision_mask = 1 # Walls, doors, environment
	query.exclude = [self.get_rid(), player.get_rid()]
	
	var result: Dictionary = space_state.intersect_ray(query)
	# If ray hit an environmental obstacle (e.g. wall/closed door), line of sight is blocked
	if not result.is_empty():
		return false
		
	return true

func _physics_process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	if not player:
		player = GameManager.player_character as PlayerController
		if not player:
			return

	hover_time += delta * 2.0
	if chase_cooldown > 0.0:
		chase_cooldown = max(0.0, chase_cooldown - delta)
	var hover_bob: float = sin(hover_time) * 0.35

	if current_state == State.DORMANT_SKY:
		sky_time += delta
		global_position.x = sin(sky_time * 0.15) * 30.0
		global_position.z = cos(sky_time * 0.15) * 30.0
		global_position.y = 45.0 + sin(sky_time * 0.4) * 2.0
		
		bell_timer += delta
		if bell_timer >= bell_interval:
			bell_timer = 0.0
			bell_interval = randf_range(16.0, 24.0)
			if audio_bell and not audio_bell.playing:
				audio_bell.play()
				
		SignalBus.lampor_nearby.emit(999.0)
		return

	if current_state == State.DESCENDING:
		safe_look_at(descend_target)
		return

	var dist_to_player: float = global_position.distance_to(player.global_position)
	
	# If player is inside any house, proximity sanity drain is muted
	if player.is_inside_house:
		SignalBus.lampor_nearby.emit(999.0)
	else:
		SignalBus.lampor_nearby.emit(dist_to_player)

	# Check player staring at Lampor
	_check_player_stare(dist_to_player, delta)

	# Regular eerie bell ringing on ground
	bell_timer += delta
	if bell_timer >= bell_interval:
		bell_timer = 0.0
		bell_interval = randf_range(6.0, 10.0)
		if audio_bell and not audio_bell.playing:
			audio_bell.play()

	match current_state:
		State.PATROL:
			_process_patrol(delta, dist_to_player, hover_bob)
		State.INVESTIGATE:
			_process_investigate(delta, dist_to_player, hover_bob)
		State.STARE_PUNISHMENT:
			_process_stare_punishment(delta, dist_to_player, hover_bob)
		State.CHASE:
			_process_chase(delta, dist_to_player, hover_bob)
		State.BANISHED:
			global_position.y += delta * 5.0

	move_and_slide()

func _check_player_stare(dist_to_player: float, delta: float) -> void:
	if player.is_hiding or dist_to_player > sight_range or current_state == State.DORMANT_SKY:
		SignalBus.lampor_stare_detected.emit(0.0)
		stare_timer = 0.0
		return

	# Cannot stare at Lampor if line of sight is blocked by walls or closed house
	if not has_line_of_sight_to_player():
		SignalBus.lampor_stare_detected.emit(0.0)
		stare_timer = 0.0
		return

	var cam: Camera3D = player.camera
	var cam_forward: Vector3 = -cam.global_transform.basis.z.normalized()
	var dir_to_lampor: Vector3 = (global_position - cam.global_position).normalized()
	
	var dot: float = cam_forward.dot(dir_to_lampor)
	if dot > stare_threshold:
		SignalBus.lampor_stare_detected.emit(dot)
		stare_timer += delta
		if stare_timer > 0.6 and current_state != State.CHASE and current_state != State.STARE_PUNISHMENT:
			_trigger_stare_punishment()
	else:
		SignalBus.lampor_stare_detected.emit(0.0)
		stare_timer = max(0.0, stare_timer - delta * 2.0)

func _trigger_stare_punishment() -> void:
	_set_state(State.STARE_PUNISHMENT)
	stare_punish_timer = 0.7
	SignalBus.lampor_screamer_triggered.emit()
	if audio_roar:
		audio_roar.play()
	red_light.light_energy = 5.0
	red_light.light_color = Color(1.0, 0.1, 0.1)

func _process_patrol(delta: float, dist_to_player: float, hover_bob: float) -> void:
	if not player.is_hiding:
		if chase_cooldown <= 0.0 and player.flashlight_on and dist_to_player < (sight_range * 0.75):
			if has_line_of_sight_to_player():
				target_position = player.global_position
				_set_state(State.INVESTIGATE)
				return

	if waypoints.is_empty():
		return

	var target: Vector3 = waypoints[current_waypoint_idx]
	target.y += hover_offset + hover_bob
	var dir: Vector3 = (target - global_position).normalized()
	velocity = dir * patrol_speed

	var horiz_sq: float = velocity.x * velocity.x + velocity.z * velocity.z
	if horiz_sq > 0.05:
		safe_look_at(global_position + Vector3(velocity.x, 0, velocity.z))

	if global_position.distance_to(target) < 2.5:
		current_waypoint_idx = (current_waypoint_idx + 1) % waypoints.size()

func _process_investigate(delta: float, dist_to_player: float, hover_bob: float) -> void:
	var target: Vector3 = target_position
	target.y += hover_offset + hover_bob
	var dir: Vector3 = (target - global_position).normalized()
	velocity = dir * (patrol_speed * 1.3)

	var horiz_sq: float = velocity.x * velocity.x + velocity.z * velocity.z
	if horiz_sq > 0.05:
		safe_look_at(global_position + Vector3(velocity.x, 0, velocity.z))

	if chase_cooldown <= 0.0 and not player.is_hiding and dist_to_player < 14.0:
		if has_line_of_sight_to_player():
			_set_state(State.CHASE)
			return

	if global_position.distance_to(target) < 3.0:
		_set_state(State.PATROL)

func _process_stare_punishment(delta: float, dist_to_player: float, hover_bob: float) -> void:
	safe_look_at(player.global_position)
	velocity = Vector3.ZERO

	stare_punish_timer -= delta
	if stare_punish_timer <= 0.0:
		_set_state(State.CHASE)

func _process_chase(delta: float, dist_to_player: float, hover_bob: float) -> void:
	# Sedang menangkap player: Lampor muncul tepat di depan kamera (jumpscare)
	if is_catching:
		velocity = Vector3.ZERO
		var cam_forward: Vector3 = -player.camera.global_transform.basis.z
		var front_pos: Vector3 = player.camera.global_position + cam_forward * 1.4
		global_position = global_position.lerp(front_pos, delta * 10.0)
		look_at(player.camera.global_position, Vector3.UP, true)
		return

	# Batas waktu pengejaran: menyerah jika terlalu lama atau player hilang dari pandangan
	chase_timer += delta
	if has_line_of_sight_to_player():
		lost_sight_timer = 0.0
	else:
		lost_sight_timer += delta
	if chase_timer > MAX_CHASE_TIME or lost_sight_timer > LOST_SIGHT_GIVE_UP:
		_give_up_chase()
		return

	if player.is_hiding:
		_set_state(State.INVESTIGATE)
		target_position = player.global_position
		return

	# If player fled into a house, Lampor cannot enter! Houses are always safe.
	if player.is_inside_house:
		# Lampor investigates outside the house entrance
		if player.current_house and is_instance_valid(player.current_house):
			target_position = player.current_house.global_position + Vector3(0, 0, 3.8)
		_set_state(State.INVESTIGATE)
		return

	var target: Vector3 = player.global_position
	target.y += hover_offset + hover_bob
	var dir: Vector3 = (target - global_position).normalized()
	velocity = dir * chase_speed

	safe_look_at(player.global_position)

	# Catch player ONLY if close AND has direct line of sight (not through walls)
	if dist_to_player < 1.9:
		if has_line_of_sight_to_player():
			_start_catch()

func _start_catch() -> void:
	if is_catching:
		return
	is_catching = true
	velocity = Vector3.ZERO
	if player and is_instance_valid(player):
		player.is_caught = true
		player.virtual_move_input = Vector2.ZERO
		player.virtual_sprint_pressed = false
		player.velocity = Vector3.ZERO
		player.set_physics_process(false)
		player.set_process_unhandled_input(false)
	red_light.light_energy = 6.0
	red_light.light_color = Color(1.0, 0.05, 0.05)
	SignalBus.lampor_screamer_triggered.emit()
	await get_tree().create_timer(1.0).timeout
	SignalBus.player_death_requested.emit("Kamu ditarik ke dalam keranda Lampor!")


func reset_after_player_revive() -> void:
	is_catching = false
	chase_timer = 0.0
	lost_sight_timer = 0.0
	stare_timer = 0.0
	chase_cooldown = CHASE_COOLDOWN_TIME
	velocity = Vector3.ZERO
	if current_state != State.DORMANT_SKY and current_state != State.DESCENDING and current_state != State.BANISHED:
		_set_state(State.PATROL)

func _give_up_chase() -> void:
	# Lampor kehilangan minat, mundur ke waypoint terjauh dari player, lalu cooldown
	chase_cooldown = CHASE_COOLDOWN_TIME
	var best_idx: int = current_waypoint_idx
	var best_dist: float = -1.0
	for i: int in range(waypoints.size()):
		var d: float = waypoints[i].distance_squared_to(player.global_position)
		if d > best_dist:
			best_dist = d
			best_idx = i
	current_waypoint_idx = best_idx
	_set_state(State.PATROL)

func _on_player_noise(level: float, noise_pos: Vector3) -> void:
	if current_state == State.DORMANT_SKY or current_state == State.DESCENDING:
		return
	if current_state == State.CHASE or current_state == State.STARE_PUNISHMENT:
		return
	if chase_cooldown > 0.0 or is_catching:
		return
		
	var effective_hearing: float = hearing_range
	if player and player.is_inside_house:
		effective_hearing *= 0.4 # Noise muffled by house walls
		
	var dist: float = global_position.distance_to(noise_pos)
	if dist < (effective_hearing * level):
		target_position = noise_pos
		_set_state(State.INVESTIGATE)

func _set_state(new_state: State) -> void:
	current_state = new_state
	if new_state == State.CHASE:
		chase_timer = 0.0
		lost_sight_timer = 0.0
	match new_state:
		State.PATROL:
			red_light.light_energy = 2.0
			red_light.light_color = Color(0.2, 0.9, 0.4) # Eerie green
		State.INVESTIGATE:
			red_light.light_energy = 2.8
			red_light.light_color = Color(0.9, 0.7, 0.1) # Alert yellow
		State.CHASE:
			red_light.light_energy = 4.5
			red_light.light_color = Color(1.0, 0.1, 0.1) # Menacing crimson
			if audio_roar and not audio_roar.playing:
				audio_roar.play()

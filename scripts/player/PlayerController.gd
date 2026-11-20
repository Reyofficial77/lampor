class_name PlayerController
extends CharacterBody3D

const PLAYER_MODEL_SCENE: PackedScene = preload("res://assets/models/player/character-suit.glb")

@export var walk_speed: float = 4.2
@export var sprint_speed: float = 7.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.0025
@export var camera_sensitivity: float = 0.0025

# Head & Camera
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interaction_ray: InteractionRay = $Head/Camera3D/InteractionRay
@onready var flashlight: SpotLight3D = $Head/Camera3D/Flashlight
@onready var sanity_system: SanitySystem = $SanitySystem
@onready var inventory_system: InventorySystem = $InventorySystem

# Stamina
var max_stamina: float = 100.0
var current_stamina: float = 100.0
var stamina_drain_rate: float = 22.0
var stamina_recovery_rate: float = 16.0
var is_sprinting: bool = false
var virtual_move_input: Vector2 = Vector2.ZERO
var virtual_sprint_pressed: bool = false
var is_caught: bool = false

# Head Bobbing
var bob_freq: float = 2.4
var bob_amp: float = 0.06
var bob_time: float = 0.0
var initial_camera_pos: Vector3

# Footstep tracking
var step_distance: float = 0.0
var step_interval: float = 2.2

# Flashlight state
var flashlight_on: bool = true
var flashlight_battery: float = 100.0
var flashlight_drain_rate: float = 0.25

# Hiding
var is_hiding: bool = false
var hiding_spot: Node = null
var is_inventory_open: bool = false
var hide_yaw_center: float = 0.0
const HIDE_LOOK_YAW: float = 55.0
const HIDE_LOOK_PITCH: float = 40.0

# House Interior
var is_inside_house: bool = false
var current_house: Node = null
var initial_spawn_position: Vector3 = Vector3.ZERO
var initial_spawn_rotation: float = 0.0

# Noise
var current_noise_level: float = 0.0

# Player 3D Model & Animations
var player_model: Node3D = null
var player_skeleton: Skeleton3D = null
var model_anim_player: AnimationPlayer = null
var model_head_mesh: GeometryInstance3D = null
var hand_item_holder: BoneAttachment3D = null
var hand_prop_pivot: Node3D = null
var hand_item_props: Dictionary = {}
var handheld_flashlight_lens: MeshInstance3D = null
var equipped_item_id: String = "flashlight"
var flashlight_preferred_on: bool = true
var in_cutscene: bool = false
var current_anim_name: String = ""
var action_anim_timer: float = 0.0
var idle_arm_time: float = 0.0
const PLAYER_MODEL_FPP_POS: Vector3 = Vector3(0.0, 0.0, 0.22)

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	if _is_touch_device():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	initial_camera_pos = camera.position
	initial_spawn_position = global_position
	initial_spawn_rotation = rotation.y
	GameManager.player_character = self
	GameManager.call_deferred("deliver_stored_items", inventory_system)
	SettingsManager.apply_player_settings(self)
	var sanity_cfg: Dictionary = GameManager.get_sanity_settings_for_difficulty(GameManager.selected_difficulty)
	flashlight_drain_rate = sanity_cfg.get("flash_drain", 0.25)
	_setup_player_model()
	if not SignalBus.item_equipped.is_connected(_on_item_equipped):
		SignalBus.item_equipped.connect(_on_item_equipped)
	if inventory_system and inventory_system.has_method("get_equipped_item"):
		_apply_equipped_item(inventory_system.get_equipped_item())
	else:
		_sync_flashlight_state(true)
	
	SignalBus.flashlight_battery_changed.emit(flashlight_battery, 100.0)
	SignalBus.player_stamina_changed.emit(current_stamina, max_stamina)

func _process(_delta: float) -> void:
	if is_caught:
		_play_player_anim("die", 0.08, 1.0)
		if model_head_mesh:
			model_head_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		if player_model:
			player_model.position = PLAYER_MODEL_FPP_POS
		_hide_all_hand_props()
		if flashlight:
			flashlight.visible = false
		camera.position = initial_camera_pos

func _unhandled_input(event: InputEvent) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	if is_inventory_open:
		return

	if is_hiding:
		if event.is_action_pressed("interact"):
			_request_exit_hiding()
		elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			# Mengintip dari dalam lemari: arah pandang dibatasi di sekitar pintu
			var new_yaw: float = rotation.y - event.relative.x * mouse_sensitivity
			var yaw_diff: float = clampf(angle_difference(hide_yaw_center, new_yaw), -deg_to_rad(HIDE_LOOK_YAW), deg_to_rad(HIDE_LOOK_YAW))
			rotation.y = hide_yaw_center + yaw_diff
			head.rotate_x(-event.relative.y * mouse_sensitivity)
			head.rotation.x = clamp(head.rotation.x, deg_to_rad(-HIDE_LOOK_PITCH), deg_to_rad(HIDE_LOOK_PITCH))
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-80), deg_to_rad(80))

	if event.is_action_pressed("flashlight"):
		toggle_flashlight()

	if event.is_action_pressed("interact"):
		trigger_action_animation("interact-right", 0.45)
		interaction_ray.trigger_interaction(self)
		
	if event.is_action_pressed("slot_1"):
		inventory_system.select_slot(0)
	elif event.is_action_pressed("slot_2"):
		inventory_system.select_slot(1)
	elif event.is_action_pressed("slot_3"):
		inventory_system.select_slot(2)
	elif event.is_action_pressed("slot_4"):
		inventory_system.select_slot(3)
	elif event.is_action_pressed("slot_5"):
		inventory_system.select_slot(4)
		
	if event.is_action_pressed("ui_accept"):
		_try_use_equipped_item()
		
	if event.is_action_pressed("drop_item"):
		var drop_pos: Vector3 = global_position + (-camera.global_transform.basis.z * 1.2) + Vector3(0, 0.4, 0)
		inventory_system.drop_equipped_item(drop_pos)

func _physics_process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	if in_cutscene:
		in_cutscene = false
		_sync_hand_prop_visibility()
		_sync_flashlight_state(true)
		
	if is_hiding or is_inventory_open:
		current_noise_level = 0.0
		velocity = Vector3.ZERO
		_update_fpp_camera_and_arm(delta, false)
		_update_player_animation(delta, false)
		return

	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Sprinting & Stamina
	var wants_sprint: bool = (Input.is_action_pressed("sprint") or virtual_sprint_pressed) and is_on_floor() and current_stamina > 5.0
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if virtual_move_input.length_squared() > 0.01:
		input_dir = virtual_move_input
	var is_moving: bool = input_dir.length_squared() > 0.01

	if wants_sprint and is_moving:
		is_sprinting = true
		current_stamina = max(0.0, current_stamina - stamina_drain_rate * delta)
	else:
		is_sprinting = false
		current_stamina = min(max_stamina, current_stamina + stamina_recovery_rate * delta)

	SignalBus.player_stamina_changed.emit(current_stamina, max_stamina)

	# Movement calculation
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var speed: float = sprint_speed if is_sprinting else walk_speed

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()

	# Noise generation
	if not is_moving:
		current_noise_level = 0.0
	elif is_sprinting:
		current_noise_level = 0.95
	else:
		current_noise_level = 0.35
		
	if current_noise_level > 0.1:
		SignalBus.player_noise_made.emit(current_noise_level, global_position)

	# Head Bobbing, Camera Perspective, Footsteps & Animations
	if is_on_floor() and is_moving:
		var current_speed: float = velocity.length()
		bob_time += delta * current_speed * (1.3 if is_sprinting else 1.0)
		step_distance += current_speed * delta
		var req_step: float = step_interval * (0.75 if is_sprinting else 1.0)
		if step_distance >= req_step:
			step_distance = 0.0
			_play_footstep()

	_update_fpp_camera_and_arm(delta, is_moving)
	_update_player_animation(delta, is_moving)

	# Flashlight battery drain (only when flashlight is actively held & turned on)
	if flashlight_on and equipped_item_id == "flashlight":
		flashlight_battery = max(0.0, flashlight_battery - flashlight_drain_rate * delta)
		SignalBus.flashlight_battery_changed.emit(flashlight_battery, 100.0)
		if flashlight_battery <= 0.0:
			toggle_flashlight(false)

func _is_touch_device() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web_android") or OS.has_feature("web_ios")

func set_virtual_move(direction: Vector2) -> void:
	virtual_move_input = Vector2.ZERO if is_caught else direction.limit_length(1.0)

func set_virtual_sprint(pressed: bool) -> void:
	virtual_sprint_pressed = pressed and not is_caught

func apply_touch_look(relative: Vector2) -> void:
	if is_caught or GameManager.current_state != GameManager.GameState.PLAYING or is_hiding:
		return
	rotate_y(-relative.x * camera_sensitivity)
	head.rotate_x(-relative.y * camera_sensitivity)
	head.rotation.x = clampf(head.rotation.x, deg_to_rad(-80.0), deg_to_rad(80.0))

func touch_interact() -> void:
	if is_caught or GameManager.current_state != GameManager.GameState.PLAYING:
		return
	if is_hiding:
		_request_exit_hiding()
	else:
		trigger_action_animation("interact-right", 0.45)
		interaction_ray.trigger_interaction(self)

func touch_use_item() -> void:
	if not is_caught and not get_tree().paused and GameManager.current_state == GameManager.GameState.PLAYING:
		_try_use_equipped_item()

func touch_select_slot(slot_index: int) -> void:
	if not is_caught and not get_tree().paused and GameManager.current_state == GameManager.GameState.PLAYING:
		inventory_system.select_slot(slot_index)

func _play_footstep() -> void:
	AudioManager.play_sound("footstep_dirt", -8.0, randf_range(0.9, 1.1))

func toggle_flashlight(state: Variant = null) -> void:
	if is_caught or get_tree().paused or GameManager.current_state != GameManager.GameState.PLAYING:
		return
	if equipped_item_id != "flashlight":
		if state != null and not bool(state):
			flashlight_preferred_on = false
			_sync_flashlight_state(true)
			return
		var torch_slot: int = _find_hotbar_slot_by_id("flashlight")
		if torch_slot >= 0 and inventory_system:
			flashlight_preferred_on = flashlight_battery > 0.0
			inventory_system.select_slot(torch_slot)
			AudioManager.play_sound("item_pickup", -12.0, 1.4)
			return
		flashlight_preferred_on = false
		_sync_flashlight_state(true)
		return

	if state != null:
		flashlight_preferred_on = bool(state)
	else:
		flashlight_preferred_on = !flashlight_preferred_on
	if flashlight_preferred_on and flashlight_battery <= 0.0:
		flashlight_preferred_on = false
	_sync_flashlight_state(true)
	AudioManager.play_sound("item_pickup", -12.0, 1.4)

func _find_hotbar_slot_by_id(item_id: String) -> int:
	if not inventory_system:
		return -1
	for i: int in range(inventory_system.slots.size()):
		if str(inventory_system.slots[i].get("id", "")) == item_id:
			return i
	return -1

func _on_item_equipped(_slot_index: int, item_data: Dictionary) -> void:
	_apply_equipped_item(item_data)

func _apply_equipped_item(item_data: Dictionary) -> void:
	equipped_item_id = str(item_data.get("id", ""))
	_sync_hand_prop_visibility()
	_sync_flashlight_state(true)

func _sync_hand_prop_visibility() -> void:
	var show_prop: bool = not in_cutscene and not is_caught and not is_hiding and equipped_item_id != ""
	for prop_id: String in hand_item_props.keys():
		var prop_node: Node3D = hand_item_props[prop_id] as Node3D
		if prop_node:
			prop_node.visible = show_prop and (prop_id == equipped_item_id)

func _hide_all_hand_props() -> void:
	for prop_id: String in hand_item_props.keys():
		var prop_node: Node3D = hand_item_props[prop_id] as Node3D
		if prop_node:
			prop_node.visible = false

func _sync_flashlight_state(emit_signal: bool = true) -> void:
	var beam_active: bool = (equipped_item_id == "flashlight") and flashlight_preferred_on and (flashlight_battery > 0.0) and not is_caught and not in_cutscene
	flashlight_on = beam_active
	if flashlight:
		flashlight.visible = beam_active
	if handheld_flashlight_lens and handheld_flashlight_lens.material_override is StandardMaterial3D:
		var lens_mat: StandardMaterial3D = handheld_flashlight_lens.material_override as StandardMaterial3D
		lens_mat.emission_enabled = beam_active
		lens_mat.emission_energy_multiplier = 1.6 if beam_active else 0.0
	if emit_signal:
		SignalBus.flashlight_toggled.emit(flashlight_on)

func enter_hiding(spot: Node) -> void:
	is_hiding = true
	hiding_spot = spot
	velocity = Vector3.ZERO
	$CollisionShape3D.disabled = true
	if spot.has_method("get_hide_global_position"):
		global_position = spot.get_hide_global_position()
	else:
		global_position = spot.global_position + Vector3(0, 0.2, 0)
	# Hadapkan pandangan ke arah pintu lemari (sisi depan lemari = +Z lokal lemari)
	hide_yaw_center = spot.global_rotation.y + PI
	rotation.y = hide_yaw_center
	head.rotation.x = 0.0
	SignalBus.player_entered_hiding.emit(true)

func _request_exit_hiding() -> void:
	# Keluar lewat HidingSpot supaya status is_occupied ikut ter-reset
	if hiding_spot and is_instance_valid(hiding_spot) and hiding_spot.has_method("interact"):
		hiding_spot.interact(self)
	else:
		exit_hiding()

func exit_hiding() -> void:
	if not is_hiding:
		return
	is_hiding = false
	$CollisionShape3D.set_deferred("disabled", false)
	velocity = Vector3.ZERO
	if hiding_spot and is_instance_valid(hiding_spot):
		if hiding_spot.has_node("ExitPoint"):
			global_position = hiding_spot.get_node("ExitPoint").global_position
		if "is_occupied" in hiding_spot:
			hiding_spot.is_occupied = false
		if "occupying_player" in hiding_spot:
			hiding_spot.occupying_player = null
	hiding_spot = null
	SignalBus.player_entered_hiding.emit(false)

func _try_use_equipped_item() -> void:
	var item: Dictionary = inventory_system.get_equipped_item()
	if item.is_empty():
		return
		
	if item.get("id") == "jamu":
		sanity_system.restore_sanity(45.0)
		current_stamina = max_stamina
		SignalBus.player_stamina_changed.emit(current_stamina, max_stamina)
		inventory_system.consume_equipped_item()
		trigger_action_animation("pick-up", 0.5)
		AudioManager.play_sound("item_pickup", -4.0, 0.8)
	elif item.get("id") == "baterai":
		if flashlight_battery >= 99.0:
			SignalBus.dialog_requested.emit("Baterai senter masih penuh.", 2.0)
			return
		flashlight_battery = minf(100.0, flashlight_battery + 50.0)
		SignalBus.flashlight_battery_changed.emit(flashlight_battery, 100.0)
		inventory_system.consume_equipped_item()
		trigger_action_animation("pick-up", 0.5)
		AudioManager.play_sound("item_pickup", -4.0, 0.8)

func _setup_player_model() -> void:
	if not PLAYER_MODEL_SCENE:
		return
	player_model = PLAYER_MODEL_SCENE.instantiate() as Node3D
	if not player_model:
		return
	player_model.name = "PlayerModel"
	player_model.scale = Vector3(0.93, 0.93, 0.93)
	player_model.rotation.y = PI
	player_model.position = PLAYER_MODEL_FPP_POS
	add_child(player_model)

	# Keep model hands, cuffs, and suit faintly legible even in dark unlit rooms
	_apply_dark_visibility_floor(player_model)

	var head_node: Node = player_model.find_child("Suit_Head", true, false)
	if not (head_node is GeometryInstance3D):
		head_node = player_model.find_child("head-mesh", true, false)
	if head_node is GeometryInstance3D:
		model_head_mesh = head_node as GeometryInstance3D
	else:
		for child: Node in player_model.find_children("*", "GeometryInstance3D", true, false):
			if child.name.to_lower().contains("head") and child is GeometryInstance3D:
				model_head_mesh = child as GeometryInstance3D
				break

	player_skeleton = player_model.find_child("Skeleton3D", true, false) as Skeleton3D
	model_anim_player = player_model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not model_anim_player and player_skeleton:
		_build_suit_animations(player_skeleton)
	if model_anim_player and not model_anim_player.mixer_applied.is_connected(_apply_fpp_hand_override):
		model_anim_player.mixer_applied.connect(_apply_fpp_hand_override)

	if player_skeleton:
		_build_hand_item_holder(player_skeleton)
	_play_player_anim("idle", 0.0, 1.0)
	_update_fpp_camera_and_arm(0.0, false)

func _apply_dark_visibility_floor(root_node: Node) -> void:
	for mi: MeshInstance3D in root_node.find_children("*", "MeshInstance3D", true, false):
		if not mi.mesh:
			continue
		for surf_idx: int in range(mi.mesh.get_surface_count()):
			var base_mat: Material = mi.get_active_material(surf_idx)
			if base_mat is StandardMaterial3D:
				var cloned: StandardMaterial3D = base_mat.duplicate() as StandardMaterial3D
				cloned.emission_enabled = true
				cloned.emission = cloned.albedo_color
				cloned.emission_energy_multiplier = 0.04
				mi.set_surface_override_material(surf_idx, cloned)

func _make_suit_mat(color: Color, rough: float = 0.72, metal: float = 0.04, ambient_floor: float = 0.045) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	mat.metallic = metal
	if ambient_floor > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = ambient_floor
	return mat

func _attach_suit_box(parent_node: Node3D, box_name: String, size_vec: Vector3, pos_vec: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = box_name
	var mesh := BoxMesh.new()
	mesh.size = size_vec
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos_vec
	mi.rotation_degrees = rot_deg
	parent_node.add_child(mi)
	return mi

func _bone_pose_quat(skel: Skeleton3D, bone_name: String, rot_x_deg: float, rot_z_deg: float, rot_y_deg: float = 0.0) -> Quaternion:
	var idx: int = skel.find_bone(bone_name)
	if idx < 0:
		return Quaternion.IDENTITY
	var rest_b: Basis = skel.get_bone_rest(idx).basis
	var g_rest_b: Basis = skel.get_bone_global_rest(idx).basis
	var inv_g: Basis = g_rest_b.inverse()
	var q: Quaternion = rest_b.get_rotation_quaternion()
	if not is_zero_approx(rot_y_deg):
		var axis_yaw: Vector3 = (inv_g * Vector3(0.0, 0.0, 1.0)).normalized()
		q = q * Quaternion(axis_yaw, deg_to_rad(rot_y_deg))
	if not is_zero_approx(rot_x_deg):
		var axis_swing: Vector3 = (inv_g * Vector3(1.0, 0.0, 0.0)).normalized()
		q = q * Quaternion(axis_swing, deg_to_rad(rot_x_deg))
	if not is_zero_approx(rot_z_deg):
		var axis_drop: Vector3 = (inv_g * Vector3(0.0, 1.0, 0.0)).normalized()
		q = q * Quaternion(axis_drop, deg_to_rad(rot_z_deg))
	return q.normalized()

func _add_suit_anim(lib: AnimationLibrary, skel_path: String, skel: Skeleton3D, anim_name: String, length: float, loop_mode: Animation.LoopMode, keyframes: Dictionary) -> void:
	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = loop_mode
	for bone_name: String in keyframes.keys():
		if skel.find_bone(bone_name) < 0:
			continue
		var track_idx: int = anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(track_idx, skel_path + ":" + bone_name)
		anim.track_set_interpolation_type(track_idx, Animation.INTERPOLATION_LINEAR)
		var keys: Array = keyframes[bone_name]
		for kf: Array in keys:
			var t: float = float(kf[0])
			var deg: Vector3 = kf[1] as Vector3
			var q: Quaternion = _bone_pose_quat(skel, bone_name, deg.x, deg.y, deg.z)
			anim.rotation_track_insert_key(track_idx, t, q)
	lib.add_animation(anim_name, anim)

func _build_suit_animations(skel: Skeleton3D) -> void:
	model_anim_player = AnimationPlayer.new()
	model_anim_player.name = "AnimationPlayer"
	player_model.add_child(model_anim_player)

	var lib := AnimationLibrary.new()
	model_anim_player.add_animation_library("", lib)
	var skel_path: String = String(player_model.get_path_to(skel))

	_add_suit_anim(lib, skel_path, skel, "idle", 1.6, Animation.LOOP_LINEAR, {
		"Hips": [[0.0, Vector3.ZERO], [0.8, Vector3.ZERO], [1.6, Vector3.ZERO]],
		"Torso": [[0.0, Vector3.ZERO], [0.8, Vector3(-1.5, 0.0, 0.0)], [1.6, Vector3.ZERO]],
		"Chest": [[0.0, Vector3(-1.0, 0.0, 0.0)], [0.8, Vector3(2.0, 0.0, 0.0)], [1.6, Vector3(-1.0, 0.0, 0.0)]],
		"Head": [[0.0, Vector3(0.0, 0.0, 0.0)], [0.8, Vector3(1.5, 0.0, 0.0)], [1.6, Vector3(0.0, 0.0, 0.0)]],
		"UpperArm.L": [[0.0, Vector3(4.0, 78.0, 0.0)], [0.8, Vector3(2.0, 76.0, 0.0)], [1.6, Vector3(4.0, 78.0, 0.0)]],
		"LowerArm.L": [[0.0, Vector3(-14.0, 0.0, 0.0)], [0.8, Vector3(-18.0, 0.0, 0.0)], [1.6, Vector3(-14.0, 0.0, 0.0)]],
		"UpperArm.R": [[0.0, Vector3(6.0, -78.0, 0.0)], [0.8, Vector3(4.0, -76.0, 0.0)], [1.6, Vector3(6.0, -78.0, 0.0)]],
		"LowerArm.R": [[0.0, Vector3(-14.0, 0.0, 0.0)], [0.8, Vector3(-18.0, 0.0, 0.0)], [1.6, Vector3(-14.0, 0.0, 0.0)]],
		"UpperLeg.L": [[0.0, Vector3.ZERO], [1.6, Vector3.ZERO]],
		"LowerLeg.L": [[0.0, Vector3.ZERO], [1.6, Vector3.ZERO]],
		"Foot.L": [[0.0, Vector3.ZERO], [1.6, Vector3.ZERO]],
		"UpperLeg.R": [[0.0, Vector3.ZERO], [1.6, Vector3.ZERO]],
		"LowerLeg.R": [[0.0, Vector3.ZERO], [1.6, Vector3.ZERO]],
		"Foot.R": [[0.0, Vector3.ZERO], [1.6, Vector3.ZERO]]
	})

	_add_suit_anim(lib, skel_path, skel, "walk", 0.8, Animation.LOOP_LINEAR, {
		"Hips": [[0.0, Vector3(-2.0, 0.0, 3.0)], [0.4, Vector3(-2.0, 0.0, -3.0)], [0.8, Vector3(-2.0, 0.0, 3.0)]],
		"Torso": [[0.0, Vector3(-4.0, 0.0, -4.0)], [0.4, Vector3(-4.0, 0.0, 4.0)], [0.8, Vector3(-4.0, 0.0, -4.0)]],
		"Chest": [[0.0, Vector3(-2.0, 0.0, 0.0)], [0.4, Vector3(-2.0, 0.0, 0.0)], [0.8, Vector3(-2.0, 0.0, 0.0)]],
		"UpperArm.L": [[0.0, Vector3(18.0, 76.0, 0.0)], [0.4, Vector3(-22.0, 76.0, 0.0)], [0.8, Vector3(18.0, 76.0, 0.0)]],
		"LowerArm.L": [[0.0, Vector3(-24.0, 0.0, 0.0)], [0.4, Vector3(-36.0, 0.0, 0.0)], [0.8, Vector3(-24.0, 0.0, 0.0)]],
		"UpperArm.R": [[0.0, Vector3(-16.0, -76.0, 0.0)], [0.4, Vector3(20.0, -76.0, 0.0)], [0.8, Vector3(-16.0, -76.0, 0.0)]],
		"LowerArm.R": [[0.0, Vector3(-34.0, 0.0, 0.0)], [0.4, Vector3(-22.0, 0.0, 0.0)], [0.8, Vector3(-34.0, 0.0, 0.0)]],
		"UpperLeg.L": [[0.0, Vector3(-28.0, 0.0, 0.0)], [0.2, Vector3(0.0, 0.0, 0.0)], [0.4, Vector3(24.0, 0.0, 0.0)], [0.6, Vector3(-8.0, 0.0, 0.0)], [0.8, Vector3(-28.0, 0.0, 0.0)]],
		"LowerLeg.L": [[0.0, Vector3(14.0, 0.0, 0.0)], [0.2, Vector3(8.0, 0.0, 0.0)], [0.4, Vector3(36.0, 0.0, 0.0)], [0.6, Vector3(46.0, 0.0, 0.0)], [0.8, Vector3(14.0, 0.0, 0.0)]],
		"Foot.L": [[0.0, Vector3(-8.0, 0.0, 0.0)], [0.4, Vector3(14.0, 0.0, 0.0)], [0.8, Vector3(-8.0, 0.0, 0.0)]],
		"UpperLeg.R": [[0.0, Vector3(24.0, 0.0, 0.0)], [0.2, Vector3(-8.0, 0.0, 0.0)], [0.4, Vector3(-28.0, 0.0, 0.0)], [0.6, Vector3(0.0, 0.0, 0.0)], [0.8, Vector3(24.0, 0.0, 0.0)]],
		"LowerLeg.R": [[0.0, Vector3(36.0, 0.0, 0.0)], [0.2, Vector3(46.0, 0.0, 0.0)], [0.4, Vector3(14.0, 0.0, 0.0)], [0.6, Vector3(8.0, 0.0, 0.0)], [0.8, Vector3(36.0, 0.0, 0.0)]],
		"Foot.R": [[0.0, Vector3(14.0, 0.0, 0.0)], [0.4, Vector3(-8.0, 0.0, 0.0)], [0.8, Vector3(14.0, 0.0, 0.0)]]
	})

	_add_suit_anim(lib, skel_path, skel, "sprint", 0.52, Animation.LOOP_LINEAR, {
		"Hips": [[0.0, Vector3(-6.0, 0.0, 5.0)], [0.26, Vector3(-6.0, 0.0, -5.0)], [0.52, Vector3(-6.0, 0.0, 5.0)]],
		"Torso": [[0.0, Vector3(-10.0, 0.0, -6.0)], [0.26, Vector3(-10.0, 0.0, 6.0)], [0.52, Vector3(-10.0, 0.0, -6.0)]],
		"Chest": [[0.0, Vector3(-6.0, 0.0, 0.0)], [0.26, Vector3(-6.0, 0.0, 0.0)], [0.52, Vector3(-6.0, 0.0, 0.0)]],
		"UpperArm.L": [[0.0, Vector3(34.0, 74.0, 0.0)], [0.26, Vector3(-38.0, 74.0, 0.0)], [0.52, Vector3(34.0, 74.0, 0.0)]],
		"LowerArm.L": [[0.0, Vector3(-56.0, 0.0, 0.0)], [0.26, Vector3(-68.0, 0.0, 0.0)], [0.52, Vector3(-56.0, 0.0, 0.0)]],
		"UpperArm.R": [[0.0, Vector3(-34.0, -74.0, 0.0)], [0.26, Vector3(34.0, -74.0, 0.0)], [0.52, Vector3(-34.0, -74.0, 0.0)]],
		"LowerArm.R": [[0.0, Vector3(-66.0, 0.0, 0.0)], [0.26, Vector3(-54.0, 0.0, 0.0)], [0.52, Vector3(-66.0, 0.0, 0.0)]],
		"UpperLeg.L": [[0.0, Vector3(-44.0, 0.0, 0.0)], [0.13, Vector3(0.0, 0.0, 0.0)], [0.26, Vector3(38.0, 0.0, 0.0)], [0.39, Vector3(-12.0, 0.0, 0.0)], [0.52, Vector3(-44.0, 0.0, 0.0)]],
		"LowerLeg.L": [[0.0, Vector3(18.0, 0.0, 0.0)], [0.13, Vector3(14.0, 0.0, 0.0)], [0.26, Vector3(58.0, 0.0, 0.0)], [0.39, Vector3(70.0, 0.0, 0.0)], [0.52, Vector3(18.0, 0.0, 0.0)]],
		"Foot.L": [[0.0, Vector3(-10.0, 0.0, 0.0)], [0.26, Vector3(18.0, 0.0, 0.0)], [0.52, Vector3(-10.0, 0.0, 0.0)]],
		"UpperLeg.R": [[0.0, Vector3(38.0, 0.0, 0.0)], [0.13, Vector3(-12.0, 0.0, 0.0)], [0.26, Vector3(-44.0, 0.0, 0.0)], [0.39, Vector3(0.0, 0.0, 0.0)], [0.52, Vector3(38.0, 0.0, 0.0)]],
		"LowerLeg.R": [[0.0, Vector3(58.0, 0.0, 0.0)], [0.13, Vector3(70.0, 0.0, 0.0)], [0.26, Vector3(18.0, 0.0, 0.0)], [0.39, Vector3(14.0, 0.0, 0.0)], [0.52, Vector3(58.0, 0.0, 0.0)]],
		"Foot.R": [[0.0, Vector3(18.0, 0.0, 0.0)], [0.26, Vector3(-10.0, 0.0, 0.0)], [0.52, Vector3(18.0, 0.0, 0.0)]]
	})

	_add_suit_anim(lib, skel_path, skel, "jump", 0.4, Animation.LOOP_NONE, {
		"Torso": [[0.0, Vector3(-6.0, 0.0, 0.0)], [0.4, Vector3(-8.0, 0.0, 0.0)]],
		"UpperArm.L": [[0.0, Vector3(-24.0, 62.0, 0.0)], [0.4, Vector3(-34.0, 56.0, 0.0)]],
		"UpperArm.R": [[0.0, Vector3(-24.0, -62.0, 0.0)], [0.4, Vector3(-34.0, -56.0, 0.0)]],
		"UpperLeg.L": [[0.0, Vector3(-22.0, 0.0, 0.0)], [0.4, Vector3(-28.0, 0.0, 0.0)]],
		"LowerLeg.L": [[0.0, Vector3(35.0, 0.0, 0.0)], [0.4, Vector3(45.0, 0.0, 0.0)]],
		"UpperLeg.R": [[0.0, Vector3(-10.0, 0.0, 0.0)], [0.4, Vector3(-16.0, 0.0, 0.0)]],
		"LowerLeg.R": [[0.0, Vector3(24.0, 0.0, 0.0)], [0.4, Vector3(32.0, 0.0, 0.0)]]
	})

	_add_suit_anim(lib, skel_path, skel, "fall", 0.6, Animation.LOOP_LINEAR, {
		"Torso": [[0.0, Vector3(-6.0, 0.0, 0.0)], [0.3, Vector3(-4.0, 0.0, 0.0)], [0.6, Vector3(-6.0, 0.0, 0.0)]],
		"UpperArm.L": [[0.0, Vector3(-18.0, 54.0, 0.0)], [0.3, Vector3(-24.0, 50.0, 0.0)], [0.6, Vector3(-18.0, 54.0, 0.0)]],
		"UpperArm.R": [[0.0, Vector3(-18.0, -54.0, 0.0)], [0.3, Vector3(-24.0, -50.0, 0.0)], [0.6, Vector3(-18.0, -54.0, 0.0)]],
		"UpperLeg.L": [[0.0, Vector3(-18.0, 0.0, 0.0)], [0.6, Vector3(-18.0, 0.0, 0.0)]],
		"LowerLeg.L": [[0.0, Vector3(28.0, 0.0, 0.0)], [0.6, Vector3(28.0, 0.0, 0.0)]],
		"UpperLeg.R": [[0.0, Vector3(-12.0, 0.0, 0.0)], [0.6, Vector3(-12.0, 0.0, 0.0)]],
		"LowerLeg.R": [[0.0, Vector3(22.0, 0.0, 0.0)], [0.6, Vector3(22.0, 0.0, 0.0)]]
	})

	_add_suit_anim(lib, skel_path, skel, "crouch", 1.0, Animation.LOOP_LINEAR, {
		"Hips": [[0.0, Vector3(-10.0, 0.0, 0.0)], [1.0, Vector3(-10.0, 0.0, 0.0)]],
		"Torso": [[0.0, Vector3(-18.0, 0.0, 0.0)], [0.5, Vector3(-20.0, 0.0, 0.0)], [1.0, Vector3(-18.0, 0.0, 0.0)]],
		"UpperArm.L": [[0.0, Vector3(-24.0, 74.0, 0.0)], [1.0, Vector3(-24.0, 74.0, 0.0)]],
		"LowerArm.L": [[0.0, Vector3(-42.0, 0.0, 0.0)], [1.0, Vector3(-42.0, 0.0, 0.0)]],
		"UpperArm.R": [[0.0, Vector3(-24.0, -74.0, 0.0)], [1.0, Vector3(-24.0, -74.0, 0.0)]],
		"LowerArm.R": [[0.0, Vector3(-42.0, 0.0, 0.0)], [1.0, Vector3(-42.0, 0.0, 0.0)]],
		"UpperLeg.L": [[0.0, Vector3(-48.0, 0.0, 0.0)], [1.0, Vector3(-48.0, 0.0, 0.0)]],
		"LowerLeg.L": [[0.0, Vector3(86.0, 0.0, 0.0)], [1.0, Vector3(86.0, 0.0, 0.0)]],
		"Foot.L": [[0.0, Vector3(-34.0, 0.0, 0.0)], [1.0, Vector3(-34.0, 0.0, 0.0)]],
		"UpperLeg.R": [[0.0, Vector3(-48.0, 0.0, 0.0)], [1.0, Vector3(-48.0, 0.0, 0.0)]],
		"LowerLeg.R": [[0.0, Vector3(86.0, 0.0, 0.0)], [1.0, Vector3(86.0, 0.0, 0.0)]],
		"Foot.R": [[0.0, Vector3(-34.0, 0.0, 0.0)], [1.0, Vector3(-34.0, 0.0, 0.0)]]
	})

	_add_suit_anim(lib, skel_path, skel, "interact-right", 0.45, Animation.LOOP_NONE, {
		"Torso": [[0.0, Vector3.ZERO], [0.18, Vector3(-6.0, 0.0, 6.0)], [0.45, Vector3.ZERO]],
		"UpperArm.R": [[0.0, Vector3(6.0, -78.0, 0.0)], [0.18, Vector3(-58.0, -68.0, 0.0)], [0.45, Vector3(6.0, -78.0, 0.0)]],
		"LowerArm.R": [[0.0, Vector3(-14.0, 0.0, 0.0)], [0.18, Vector3(-34.0, 0.0, 0.0)], [0.45, Vector3(-14.0, 0.0, 0.0)]]
	})

	_add_suit_anim(lib, skel_path, skel, "pick-up", 0.5, Animation.LOOP_NONE, {
		"Torso": [[0.0, Vector3.ZERO], [0.22, Vector3(-24.0, 0.0, 4.0)], [0.5, Vector3.ZERO]],
		"Chest": [[0.0, Vector3.ZERO], [0.22, Vector3(-12.0, 0.0, 0.0)], [0.5, Vector3.ZERO]],
		"UpperArm.R": [[0.0, Vector3(6.0, -78.0, 0.0)], [0.22, Vector3(-68.0, -65.0, 0.0)], [0.5, Vector3(6.0, -78.0, 0.0)]],
		"LowerArm.R": [[0.0, Vector3(-14.0, 0.0, 0.0)], [0.22, Vector3(-28.0, 0.0, 0.0)], [0.5, Vector3(-14.0, 0.0, 0.0)]]
	})

	_add_suit_anim(lib, skel_path, skel, "die", 0.7, Animation.LOOP_NONE, {
		"Hips": [[0.0, Vector3.ZERO], [0.5, Vector3(82.0, 0.0, 0.0)], [0.7, Vector3(82.0, 0.0, 0.0)]],
		"Head": [[0.0, Vector3.ZERO], [0.5, Vector3(18.0, 0.0, 0.0)], [0.7, Vector3(18.0, 0.0, 0.0)]],
		"UpperArm.L": [[0.0, Vector3(4.0, 78.0, 0.0)], [0.7, Vector3(18.0, 62.0, 0.0)]],
		"UpperArm.R": [[0.0, Vector3(6.0, -78.0, 0.0)], [0.7, Vector3(18.0, -62.0, 0.0)]]
	})

func _build_hand_item_holder(skel: Skeleton3D) -> void:
	if not skel:
		return
	if hand_item_holder and is_instance_valid(hand_item_holder):
		hand_item_holder.queue_free()
	hand_item_props.clear()

	hand_item_holder = BoneAttachment3D.new()
	hand_item_holder.name = "HandItemHolder"
	hand_item_holder.bone_name = "Hand.R"
	skel.add_child(hand_item_holder)

	# Compensate CharacterArmature (100x) import scale so props are built in real meters
	var parent_scale: Vector3 = skel.get_parent().scale if skel.get_parent() is Node3D else Vector3.ONE
	hand_prop_pivot = Node3D.new()
	hand_prop_pivot.name = "HandPropPivot"
	hand_prop_pivot.scale = Vector3(
		1.0 / maxf(0.001, absf(parent_scale.x)),
		1.0 / maxf(0.001, absf(parent_scale.y)),
		1.0 / maxf(0.001, absf(parent_scale.z))
	)
	hand_item_holder.add_child(hand_prop_pivot)

	# 1. Flashlight (cylinder aligned with Hand.R +Y finger axis)
	var torch_root := Node3D.new()
	torch_root.name = "Prop_flashlight"
	hand_prop_pivot.add_child(torch_root)
	hand_item_props["flashlight"] = torch_root

	var body_metal_mat: StandardMaterial3D = _make_suit_mat(Color(0.14, 0.15, 0.17), 0.35, 0.7)
	var lens_mat := StandardMaterial3D.new()
	lens_mat.albedo_color = Color(1.0, 0.95, 0.78)
	lens_mat.emission_enabled = flashlight_on
	lens_mat.emission = Color(1.0, 0.94, 0.75)
	lens_mat.emission_energy_multiplier = 1.6 if flashlight_on else 0.0

	var torch_body := MeshInstance3D.new()
	torch_body.name = "HandheldFlashlightBody"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.018
	cyl.bottom_radius = 0.014
	cyl.height = 0.135
	torch_body.mesh = cyl
	torch_body.material_override = body_metal_mat
	torch_body.position = Vector3(0.0, 0.055, -0.018)
	torch_root.add_child(torch_body)

	handheld_flashlight_lens = MeshInstance3D.new()
	handheld_flashlight_lens.name = "HandheldFlashlightLens"
	var lens_cyl := CylinderMesh.new()
	lens_cyl.top_radius = 0.019
	lens_cyl.bottom_radius = 0.019
	lens_cyl.height = 0.010
	handheld_flashlight_lens.mesh = lens_cyl
	handheld_flashlight_lens.material_override = lens_mat
	handheld_flashlight_lens.position = Vector3(0.0, 0.125, -0.018)
	torch_root.add_child(handheld_flashlight_lens)

	# 2. Jamu Tolak Bala (green glass bottle + wooden cork)
	var jamu_root := Node3D.new()
	jamu_root.name = "Prop_jamu"
	jamu_root.rotation_degrees = Vector3(-42.0, 0.0, -18.0)
	jamu_root.position = Vector3(0.004, 0.042, -0.018)
	hand_prop_pivot.add_child(jamu_root)
	hand_item_props["jamu"] = jamu_root

	var jamu_glass := MeshInstance3D.new()
	var jamu_cyl := CylinderMesh.new()
	jamu_cyl.top_radius = 0.016
	jamu_cyl.bottom_radius = 0.022
	jamu_cyl.height = 0.105
	jamu_glass.mesh = jamu_cyl
	jamu_glass.material_override = _make_suit_mat(Color(0.2, 0.65, 0.28), 0.25, 0.1, 0.06)
	jamu_root.add_child(jamu_glass)

	var jamu_cork := MeshInstance3D.new()
	var cork_cyl := CylinderMesh.new()
	cork_cyl.top_radius = 0.011
	cork_cyl.bottom_radius = 0.011
	cork_cyl.height = 0.022
	jamu_cork.mesh = cork_cyl
	jamu_cork.position = Vector3(0.0, 0.060, 0.0)
	jamu_cork.material_override = _make_suit_mat(Color(0.55, 0.36, 0.18), 0.85, 0.0)
	jamu_root.add_child(jamu_cork)

	# 3. Minyak Tanah & Korek (canister + red matchbox)
	var minyak_root := Node3D.new()
	minyak_root.name = "Prop_minyak_tanah"
	minyak_root.rotation_degrees = Vector3(-38.0, 0.0, -15.0)
	minyak_root.position = Vector3(0.005, 0.046, -0.020)
	hand_prop_pivot.add_child(minyak_root)
	hand_item_props["minyak_tanah"] = minyak_root

	_attach_suit_box(minyak_root, "CanBody", Vector3(0.056, 0.088, 0.042), Vector3.ZERO, _make_suit_mat(Color(0.28, 0.24, 0.20), 0.5, 0.55))
	_attach_suit_box(minyak_root, "CanCap", Vector3(0.022, 0.016, 0.022), Vector3(0.012, 0.050, 0.0), _make_suit_mat(Color(0.85, 0.72, 0.2), 0.35, 0.6))
	_attach_suit_box(minyak_root, "Matchbox", Vector3(0.032, 0.022, 0.014), Vector3(-0.010, 0.046, 0.018), _make_suit_mat(Color(0.82, 0.22, 0.14), 0.8, 0.0, 0.06))

	# 4. Papan & Paku (wooden plank + metal nails)
	var papan_root := Node3D.new()
	papan_root.name = "Prop_papan_paku"
	papan_root.position = Vector3(0.0, 0.060, -0.018)
	hand_prop_pivot.add_child(papan_root)
	hand_item_props["papan_paku"] = papan_root

	var wood_mat: StandardMaterial3D = _make_suit_mat(Color(0.45, 0.28, 0.14), 0.88, 0.0, 0.05)
	var nail_mat: StandardMaterial3D = _make_suit_mat(Color(0.75, 0.77, 0.82), 0.3, 0.85)
	_attach_suit_box(papan_root, "Plank", Vector3(0.052, 0.185, 0.016), Vector3.ZERO, wood_mat)
	_attach_suit_box(papan_root, "Nail1", Vector3(0.008, 0.008, 0.032), Vector3(0.012, 0.055, 0.006), nail_mat)
	_attach_suit_box(papan_root, "Nail2", Vector3(0.008, 0.008, 0.032), Vector3(-0.012, -0.045, 0.006), nail_mat)

	# 5. Baterai (battery cylinder + brass cathode)
	var bat_root := Node3D.new()
	bat_root.name = "Prop_baterai"
	bat_root.rotation_degrees = Vector3(-40.0, 0.0, -15.0)
	bat_root.position = Vector3(0.0, 0.045, -0.016)
	hand_prop_pivot.add_child(bat_root)
	hand_item_props["baterai"] = bat_root

	var bat_body := MeshInstance3D.new()
	var bat_cyl := CylinderMesh.new()
	bat_cyl.top_radius = 0.016
	bat_cyl.bottom_radius = 0.016
	bat_cyl.height = 0.068
	bat_body.mesh = bat_cyl
	bat_body.material_override = _make_suit_mat(Color(0.14, 0.14, 0.16), 0.4, 0.65)
	bat_root.add_child(bat_body)

	var bat_top := MeshInstance3D.new()
	var top_cyl := CylinderMesh.new()
	top_cyl.top_radius = 0.016
	top_cyl.bottom_radius = 0.016
	top_cyl.height = 0.018
	bat_top.mesh = top_cyl
	bat_top.position = Vector3(0.0, 0.032, 0.0)
	bat_top.material_override = _make_suit_mat(Color(0.88, 0.68, 0.16), 0.3, 0.75, 0.06)
	bat_root.add_child(bat_top)

	_sync_hand_prop_visibility()

func _apply_fpp_hand_override() -> void:
	if not player_skeleton or in_cutscene or is_caught or is_hiding or action_anim_timer > 0.0:
		return
	if equipped_item_id == "":
		return

	var pitch_deg: float = clampf(rad_to_deg(head.rotation.x) * 0.55, -26.0, 26.0) if head else 0.0
	var sway_x: float = 0.0
	var sway_y: float = 0.0
	if velocity.length() > 0.4 and is_on_floor():
		var sway_mult: float = 1.4 if is_sprinting else 1.0
		sway_x = sin(bob_time * bob_freq) * 2.5 * sway_mult
		sway_y = cos(bob_time * bob_freq * 0.5) * 2.0 * sway_mult
	else:
		sway_x = sin(idle_arm_time * 1.8) * 1.1

	_set_skeleton_bone_rot("Shoulder.R", -18.0, -10.0, 5.0)
	_set_skeleton_bone_rot("UpperArm.R", -95.0 - pitch_deg + sway_x, -50.0, 35.0 + sway_y)
	_set_skeleton_bone_rot("LowerArm.R", -25.0 + sway_x * 0.4, -15.0, 0.0)
	_set_skeleton_bone_rot("Hand.R", -8.0, 0.0, 0.0)

func _set_skeleton_bone_rot(bone_name: String, rot_x_deg: float, rot_z_deg: float, rot_y_deg: float) -> void:
	var idx: int = player_skeleton.find_bone(bone_name)
	if idx >= 0:
		player_skeleton.set_bone_pose_rotation(idx, _bone_pose_quat(player_skeleton, bone_name, rot_x_deg, rot_z_deg, rot_y_deg))

func prepare_for_cutscene() -> void:
	in_cutscene = true
	action_anim_timer = 0.0
	if model_head_mesh:
		model_head_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if player_model:
		player_model.position = Vector3.ZERO
	_hide_all_hand_props()
	if flashlight:
		flashlight.visible = false
	_play_player_anim("idle", 0.1, 1.0)

func trigger_action_animation(anim_name: String, duration: float = 0.45) -> void:
	if not model_anim_player or not model_anim_player.has_animation(anim_name):
		return
	action_anim_timer = maxf(0.1, duration)
	current_anim_name = anim_name
	model_anim_player.play(anim_name, 0.08, 1.25)

func _play_player_anim(anim_name: String, custom_blend: float = 0.15, custom_speed: float = 1.0) -> void:
	if not model_anim_player or not model_anim_player.has_animation(anim_name):
		return
	if current_anim_name == anim_name and model_anim_player.is_playing():
		return
	current_anim_name = anim_name
	model_anim_player.play(anim_name, custom_blend, custom_speed)

func _update_player_animation(delta: float, is_moving: bool) -> void:
	if not model_anim_player:
		return
	if is_caught:
		_play_player_anim("die", 0.08, 1.0)
		return
	if is_hiding:
		_play_player_anim("crouch", 0.15, 1.0)
		return
	if action_anim_timer > 0.0:
		action_anim_timer = maxf(0.0, action_anim_timer - delta)
		if model_anim_player.is_playing():
			return
		action_anim_timer = 0.0
	if not is_on_floor():
		if velocity.y > 0.1:
			_play_player_anim("jump", 0.1, 1.0)
		else:
			_play_player_anim("fall", 0.15, 1.0)
		return
	if is_moving and is_sprinting:
		_play_player_anim("sprint", 0.12, 1.15)
	elif is_moving:
		_play_player_anim("walk", 0.12, 1.0)
	else:
		_play_player_anim("idle", 0.18, 1.0)

func _update_fpp_camera_and_arm(delta: float, is_moving: bool) -> void:
	if not camera or not head:
		return
	if model_head_mesh:
		model_head_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	if player_model:
		player_model.position = PLAYER_MODEL_FPP_POS

	idle_arm_time += maxf(0.0, delta)
	if is_on_floor() and is_moving and not is_hiding and not is_caught:
		camera.position = Vector3(
			initial_camera_pos.x + cos(bob_time * bob_freq * 0.5) * bob_amp * 0.6,
			initial_camera_pos.y + sin(bob_time * bob_freq) * bob_amp,
			initial_camera_pos.z
		)
	elif delta > 0.0:
		camera.position = camera.position.lerp(initial_camera_pos, minf(1.0, delta * 8.0))
	else:
		camera.position = initial_camera_pos

	if interaction_ray:
		interaction_ray.position = Vector3.ZERO
	if flashlight:
		flashlight.position = Vector3(0.2, -0.2, -0.1)
	_sync_hand_prop_visibility()

func revive_from_extra_life() -> void:
	is_caught = false
	is_hiding = false
	in_cutscene = false
	hiding_spot = null
	is_inside_house = false
	current_house = null
	virtual_move_input = Vector2.ZERO
	virtual_sprint_pressed = false
	velocity = Vector3.ZERO
	global_position = initial_spawn_position + Vector3(0.0, 0.08, 0.0)
	rotation.y = initial_spawn_rotation
	head.rotation = Vector3.ZERO
	$CollisionShape3D.set_deferred("disabled", false)
	set_physics_process(true)
	set_process_unhandled_input(true)
	current_stamina = max_stamina
	flashlight_battery = 100.0
	flashlight_preferred_on = true
	_sync_hand_prop_visibility()
	_sync_flashlight_state(true)
	_play_player_anim("idle", 0.05, 1.0)
	_update_fpp_camera_and_arm(0.0, false)
	sanity_system.current_sanity = sanity_system.max_sanity
	sanity_system.safe_sources.clear()
	sanity_system.lampor_distance = 999.0
	sanity_system.is_staring_at_lampor = false
	SignalBus.player_sanity_changed.emit(sanity_system.current_sanity, sanity_system.max_sanity)
	SignalBus.player_stamina_changed.emit(current_stamina, max_stamina)
	SignalBus.flashlight_battery_changed.emit(flashlight_battery, 100.0)

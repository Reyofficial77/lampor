class_name PlayerController
extends CharacterBody3D

const PLAYER_MODEL_SCENE: PackedScene = preload("res://assets/models/player/ordinaryMan.fbx")
const PLAYER_TEXTURE_1024: Texture2D = preload("res://assets/models/player/OrdinaryManTexture_1024x1024.png")

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
const ENERGY_DRINK_DURATION: float = 3.0
const ENERGY_DRINK_COOLDOWN: float = 6.0
var energy_drink_timer: float = 0.0
var energy_drink_cooldown: float = 0.0

# Head Bobbing & Natural Motion
var bob_freq: float = 2.4
var bob_amp: float = 0.034
var bob_time: float = 0.0
var initial_camera_pos: Vector3
var was_on_floor: bool = true
var landing_dip: float = 0.0
var look_sway: Vector2 = Vector2.ZERO
var look_sway_target: Vector2 = Vector2.ZERO
var equip_raise_blend: float = 1.0

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
var left_hand_item_holder: BoneAttachment3D = null
var left_hand_prop_pivot: Node3D = null
var left_hand_item_props: Dictionary = {}
var handheld_flashlight_lens: MeshInstance3D = null
var equipped_item_id: String = "flashlight"
var flashlight_preferred_on: bool = true
var in_cutscene: bool = false
var current_anim_name: String = ""
var action_anim_timer: float = 0.0
var action_anim_duration: float = 0.45
var idle_arm_time: float = 0.0
var move_blend: float = 0.0
var sprint_blend: float = 0.0
const PLAYER_MODEL_FPP_POS: Vector3 = Vector3(0.0, 0.0, 0.19)

const BONE_ALIASES: Dictionary = {
	"Hips": ["hip", "Hips"],
	"Torso": ["spine", "Torso", "Abdomen"],
	"Chest": ["chest", "Chest"],
	"Neck": ["neck", "Neck"],
	"Head": ["head", "Head"],
	"Shoulder.L": ["Shoulder.L"],
	"UpperArm.L": ["upperArm.l", "UpperArm.L"],
	"LowerArm.L": ["lowerArm.l", "LowerArm.L"],
	"Hand.L": ["hand.l", "Hand.L"],
	"Shoulder.R": ["Shoulder.R"],
	"UpperArm.R": ["upperArm.r", "UpperArm.R"],
	"LowerArm.R": ["lowerArm.r", "LowerArm.R"],
	"Hand.R": ["hand.r", "Hand.R"],
	"UpperLeg.L": ["upperLeg.l", "UpperLeg.L"],
	"LowerLeg.L": ["lowerLeg.l", "LowerLeg.L"],
	"Foot.L": ["foot.l", "Foot.L"],
	"UpperLeg.R": ["upperLeg.r", "UpperLeg.R"],
	"LowerLeg.R": ["lowerLeg.r", "LowerLeg.R"],
	"Foot.R": ["foot.r", "Foot.R"]
}

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

func _resolve_bone_name(skel: Skeleton3D, canonical_name: String) -> String:
	if not skel:
		return ""
	if skel.find_bone(canonical_name) >= 0:
		return canonical_name
	if BONE_ALIASES.has(canonical_name):
		for candidate: String in BONE_ALIASES[canonical_name]:
			if skel.find_bone(candidate) >= 0:
				return candidate
	return ""

func _find_bone_idx(skel: Skeleton3D, canonical_name: String) -> int:
	var actual: String = _resolve_bone_name(skel, canonical_name)
	return skel.find_bone(actual) if not actual.is_empty() else -1

func _process(_delta: float) -> void:
	if in_cutscene:
		return
	if is_caught:
		_play_player_anim("die", 0.08, 1.0)
		if player_skeleton:
			var hand_idx: int = _find_bone_idx(player_skeleton, "Hand.R")
			if hand_idx >= 0:
				player_skeleton.set_bone_pose_scale(hand_idx, Vector3.ONE)
			var hand_l_idx: int = _find_bone_idx(player_skeleton, "Hand.L")
			if hand_l_idx >= 0:
				player_skeleton.set_bone_pose_scale(hand_l_idx, Vector3.ONE)
			var head_idx: int = _find_bone_idx(player_skeleton, "Head")
			if head_idx >= 0:
				player_skeleton.set_bone_pose_scale(head_idx, Vector3.ONE)
		if model_head_mesh:
			model_head_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		if player_model:
			player_model.position = PLAYER_MODEL_FPP_POS
		_hide_all_hand_props()
		if flashlight:
			flashlight.visible = false
		camera.position = initial_camera_pos
		camera.rotation.z = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	if is_inventory_open or (get_viewport().gui_get_focus_owner() is LineEdit):
		return

	if is_hiding:
		if event.is_action_pressed("interact"):
			_request_exit_hiding()
		elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
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
		look_sway_target.x = clampf(look_sway_target.x - event.relative.x * 0.14, -10.0, 10.0)
		look_sway_target.y = clampf(look_sway_target.y - event.relative.y * 0.12, -8.0, 8.0)

	if event.is_action_pressed("flashlight"):
		toggle_flashlight()

	if event.is_action_pressed("interact"):
		_perform_interact_or_use()

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

	if event.is_action_pressed("drop_item"):
		var drop_pos: Vector3 = global_position + (-camera.global_transform.basis.z * 1.2) + Vector3(0, 0.4, 0)
		inventory_system.drop_equipped_item(drop_pos)

func _perform_interact_or_use() -> void:
	if is_caught or GameManager.current_state != GameManager.GameState.PLAYING:
		return
	if is_hiding:
		_request_exit_hiding()
		return
	var interacted: bool = false
	if interaction_ray:
		interacted = interaction_ray.trigger_interaction(self)
	if interacted:
		trigger_action_animation("interact-right", 0.45)
	else:
		if not _try_use_equipped_item():
			trigger_action_animation("interact-right", 0.42)

func _physics_process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	if in_cutscene:
		in_cutscene = false
		_sync_hand_prop_visibility()
		_sync_flashlight_state(true)

	if is_hiding or is_inventory_open or (get_viewport().gui_get_focus_owner() is LineEdit):
		current_noise_level = 0.0
		velocity = Vector3.ZERO
		_update_fpp_camera_and_arm(delta, false)
		_update_player_animation(delta, false)
		return

	var pre_fall_vy: float = velocity.y
	if not is_on_floor():
		velocity.y -= gravity * delta

	var god_mode: bool = ("admin_god_mode" in GameManager) and bool(GameManager.get("admin_god_mode"))

	if energy_drink_cooldown > 0.0:
		energy_drink_cooldown = maxf(0.0, energy_drink_cooldown - delta)
	if energy_drink_timer > 0.0:
		energy_drink_timer = maxf(0.0, energy_drink_timer - delta)
		current_stamina = max_stamina

	var unlimited_stamina: bool = god_mode or (energy_drink_timer > 0.0)

	# Sprinting & Stamina
	var wants_sprint: bool = (Input.is_action_pressed("sprint") or virtual_sprint_pressed) and is_on_floor() and (current_stamina > 5.0 or unlimited_stamina)
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if virtual_move_input.length_squared() > 0.01:
		input_dir = virtual_move_input
	var is_moving: bool = input_dir.length_squared() > 0.01

	if wants_sprint and is_moving:
		is_sprinting = true
		if not unlimited_stamina:
			current_stamina = max(0.0, current_stamina - stamina_drain_rate * delta)
		else:
			current_stamina = max_stamina
	else:
		is_sprinting = false
		if energy_drink_timer > 0.0:
			current_stamina = max_stamina
		else:
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

	if is_on_floor() and not was_on_floor and pre_fall_vy < -1.5:
		landing_dip = clampf(-pre_fall_vy * 0.014, 0.0, 0.065)
	was_on_floor = is_on_floor()

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
		bob_time += delta * current_speed * (1.32 if is_sprinting else 1.0)
		step_distance += current_speed * delta
		var req_step: float = step_interval * (0.75 if is_sprinting else 1.0)
		if step_distance >= req_step:
			step_distance = 0.0
			_play_footstep()

	_update_fpp_camera_and_arm(delta, is_moving)
	_update_player_animation(delta, is_moving)

	# Flashlight battery drain
	if flashlight_on and equipped_item_id == "flashlight":
		if not god_mode:
			flashlight_battery = max(0.0, flashlight_battery - flashlight_drain_rate * delta)
		else:
			flashlight_battery = 100.0
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
	look_sway_target.x = clampf(look_sway_target.x - relative.x * 0.14, -10.0, 10.0)
	look_sway_target.y = clampf(look_sway_target.y - relative.y * 0.12, -8.0, 8.0)

func touch_interact() -> void:
	_perform_interact_or_use()

func touch_use_item() -> void:
	_perform_interact_or_use()

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
	var next_id: String = str(item_data.get("id", ""))
	if next_id != equipped_item_id:
		equip_raise_blend = 0.0
	equipped_item_id = next_id
	_sync_hand_prop_visibility()
	_sync_flashlight_state(true)
	if interaction_ray:
		interaction_ray._update_prompt()

func _sync_hand_prop_visibility() -> void:
	var show_prop: bool = not in_cutscene and not is_caught and not is_hiding and equipped_item_id != ""
	for prop_id: String in hand_item_props.keys():
		var prop_node: Node3D = hand_item_props[prop_id] as Node3D
		if prop_node:
			prop_node.visible = show_prop and (prop_id == equipped_item_id)
	for prop_id: String in left_hand_item_props.keys():
		var prop_node: Node3D = left_hand_item_props[prop_id] as Node3D
		if prop_node:
			prop_node.visible = show_prop and (prop_id == equipped_item_id)

func _hide_all_hand_props() -> void:
	for prop_id: String in hand_item_props.keys():
		var prop_node: Node3D = hand_item_props[prop_id] as Node3D
		if prop_node:
			prop_node.visible = false
	for prop_id: String in left_hand_item_props.keys():
		var prop_node: Node3D = left_hand_item_props[prop_id] as Node3D
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
	hide_yaw_center = spot.global_rotation.y + PI
	rotation.y = hide_yaw_center
	head.rotation.x = 0.0
	SignalBus.player_entered_hiding.emit(true)

func _request_exit_hiding() -> void:
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

func _try_use_equipped_item() -> bool:
	var item: Dictionary = inventory_system.get_equipped_item()
	if item.is_empty():
		return false

	if item.get("id") == "jamu":
		sanity_system.restore_sanity(45.0)
		current_stamina = max_stamina
		SignalBus.player_stamina_changed.emit(current_stamina, max_stamina)
		inventory_system.consume_equipped_item()
		trigger_action_animation("pick-up", 0.5)
		AudioManager.play_sound("item_pickup", -4.0, 0.8)
		SignalBus.item_used.emit(item)
		if interaction_ray:
			interaction_ray._update_prompt()
		return true
	elif item.get("id") == "baterai":
		if flashlight_battery >= 99.0:
			SignalBus.dialog_requested.emit("Baterai senter masih penuh.", 2.0)
			return true
		flashlight_battery = minf(100.0, flashlight_battery + 50.0)
		SignalBus.flashlight_battery_changed.emit(flashlight_battery, 100.0)
		inventory_system.consume_equipped_item()
		trigger_action_animation("pick-up", 0.5)
		AudioManager.play_sound("item_pickup", -4.0, 0.8)
		SignalBus.item_used.emit(item)
		if interaction_ray:
			interaction_ray._update_prompt()
		return true
	elif item.get("id") == "energy_drink":
		if energy_drink_timer > 0.0:
			SignalBus.dialog_requested.emit("Efek Energy Drink masih aktif (%.1f detik)! Tidak dapat di-spam." % energy_drink_timer, 1.8)
			return true
		if energy_drink_cooldown > 0.0:
			SignalBus.dialog_requested.emit("Tunggu %.1f detik sebelum minum Energy Drink lagi." % energy_drink_cooldown, 1.8)
			return true
		energy_drink_timer = ENERGY_DRINK_DURATION
		energy_drink_cooldown = ENERGY_DRINK_COOLDOWN
		current_stamina = max_stamina
		SignalBus.player_stamina_changed.emit(current_stamina, max_stamina)
		inventory_system.consume_equipped_item()
		trigger_action_animation("drink", 0.65)
		AudioManager.play_sound("energy_drink", 1.0)
		SignalBus.dialog_requested.emit("Energy Drink diminum! Stamina penuh 100% selama 3 detik!", 3.0)
		SignalBus.item_used.emit(item)
		if interaction_ray:
			interaction_ray._update_prompt()
		return true
	elif item.get("id") == "kentongan":
		var repelled_any: bool = false
		for lampor_node: Node in get_tree().get_nodes_in_group("lampor"):
			if lampor_node.has_method("repel_from_kentongan"):
				if bool(lampor_node.call("repel_from_kentongan", 5.0)):
					repelled_any = true
		if not repelled_any:
			SignalBus.dialog_requested.emit("Lampor belum turun ke desa. Simpan kentongan untuk nanti!", 2.5)
			return true
		inventory_system.consume_equipped_item()
		trigger_action_animation("kentongan_hit", 0.55)
		AudioManager.play_sound("kentongan", 2.0)
		SignalBus.dialog_requested.emit("Kentongan dibunyikan! Lampor terusir selama 5 detik!", 3.0)
		SignalBus.item_used.emit(item)
		if interaction_ray:
			interaction_ray._update_prompt()
		return true
	return false

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

	# Hapus node referensi Blender (Side/Front) bila ada pada FBX
	for helper_name: String in ["Side", "Front"]:
		var helper_node: Node = player_model.get_node_or_null(helper_name)
		if helper_node:
			helper_node.queue_free()

	_apply_dark_visibility_floor(player_model)
	for mi_node: Node in player_model.find_children("*", "MeshInstance3D", true, false):
		if mi_node is GeometryInstance3D:
			(mi_node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var head_node: Node = player_model.find_child("Suit_Head", true, false)
	if not (head_node is GeometryInstance3D):
		head_node = player_model.find_child("head-mesh", true, false)
	if head_node is GeometryInstance3D:
		model_head_mesh = head_node as GeometryInstance3D

	player_skeleton = player_model.find_child("Skeleton3D", true, false) as Skeleton3D
	model_anim_player = player_model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not model_anim_player and player_skeleton:
		_build_suit_animations(player_skeleton)
	if model_anim_player and not model_anim_player.mixer_applied.is_connected(_apply_fpp_hand_override):
		model_anim_player.mixer_applied.connect(_apply_fpp_hand_override)

	if player_skeleton:
		_build_hand_item_holder(player_skeleton)
	_play_player_anim("idle", 0.0, 1.0)
	if model_anim_player:
		model_anim_player.advance(0.0)
	_update_fpp_camera_and_arm(0.0, false)
	_apply_fpp_hand_override()

func _apply_dark_visibility_floor(root_node: Node) -> void:
	for mi: MeshInstance3D in root_node.find_children("*", "MeshInstance3D", true, false):
		if not mi.mesh:
			continue
		for surf_idx: int in range(mi.mesh.get_surface_count()):
			var base_mat: Material = mi.get_active_material(surf_idx)
			var cloned: StandardMaterial3D = null
			if base_mat is StandardMaterial3D:
				cloned = base_mat.duplicate() as StandardMaterial3D
			else:
				cloned = StandardMaterial3D.new()
			if PLAYER_TEXTURE_1024 and (cloned.albedo_texture != null or mi.name == "Cube"):
				cloned.albedo_texture = PLAYER_TEXTURE_1024
			cloned.roughness = 0.78
			cloned.emission_enabled = true
			if cloned.albedo_texture:
				cloned.emission_texture = cloned.albedo_texture
				cloned.emission = Color.WHITE
			else:
				cloned.emission = cloned.albedo_color
			cloned.emission_energy_multiplier = 0.045
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
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos_vec
	mi.rotation_degrees = rot_deg
	parent_node.add_child(mi)
	return mi

func _attach_suit_cyl(parent_node: Node3D, cyl_name: String, top_r: float, bottom_r: float, h: float, pos_vec: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = cyl_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_r
	mesh.bottom_radius = bottom_r
	mesh.height = h
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos_vec
	mi.rotation_degrees = rot_deg
	parent_node.add_child(mi)
	return mi

func _attach_suit_sph(parent_node: Node3D, sph_name: String, r: float, pos_vec: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = sph_name
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos_vec
	parent_node.add_child(mi)
	return mi

func _bone_pose_quat(skel: Skeleton3D, canonical_bone_name: String, rot_x_deg: float, rot_z_deg: float, rot_y_deg: float = 0.0) -> Quaternion:
	var actual_name: String = _resolve_bone_name(skel, canonical_bone_name)
	var idx: int = skel.find_bone(actual_name) if not actual_name.is_empty() else -1
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
	for canonical_name: String in keyframes.keys():
		var actual_name: String = _resolve_bone_name(skel, canonical_name)
		if actual_name.is_empty() or skel.find_bone(actual_name) < 0:
			continue
		var track_idx: int = anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(track_idx, skel_path + ":" + actual_name)
		anim.track_set_interpolation_type(track_idx, Animation.INTERPOLATION_CUBIC)
		var keys: Array = keyframes[canonical_name]
		for kf: Array in keys:
			var t: float = float(kf[0])
			var deg: Vector3 = kf[1] as Vector3
			var q: Quaternion = _bone_pose_quat(skel, canonical_name, deg.x, deg.y, deg.z)
			anim.rotation_track_insert_key(track_idx, t, q)
	lib.add_animation(anim_name, anim)

func _build_suit_animations(skel: Skeleton3D) -> void:
	model_anim_player = AnimationPlayer.new()
	model_anim_player.name = "AnimationPlayer"
	player_model.add_child(model_anim_player)

	var lib := AnimationLibrary.new()
	model_anim_player.add_animation_library("", lib)
	var skel_path: String = String(player_model.get_path_to(skel))

	# Idle: napas alami bertingkat, sedikit perpindahan tumpuan pinggul, siku rileks
	_add_suit_anim(lib, skel_path, skel, "idle", 2.4, Animation.LOOP_LINEAR, {
		"Hips": [
			[0.0, Vector3(0.5, 0.8, 0.4)],
			[0.6, Vector3(0.0, -0.4, -0.3)],
			[1.2, Vector3(0.8, -0.8, -0.5)],
			[1.8, Vector3(0.2, 0.3, 0.2)],
			[2.4, Vector3(0.5, 0.8, 0.4)]
		],
		"Torso": [
			[0.0, Vector3(-1.0, -0.5, -0.4)],
			[0.6, Vector3(0.5, 0.3, 0.3)],
			[1.2, Vector3(-2.2, 0.6, 0.5)],
			[1.8, Vector3(-0.4, -0.2, -0.2)],
			[2.4, Vector3(-1.0, -0.5, -0.4)]
		],
		"Chest": [
			[0.0, Vector3(-1.2, 0.0, 0.0)],
			[0.6, Vector3(1.4, 0.0, 0.4)],
			[1.2, Vector3(2.6, 0.0, -0.4)],
			[1.8, Vector3(0.4, 0.0, 0.2)],
			[2.4, Vector3(-1.2, 0.0, 0.0)]
		],
		"Head": [
			[0.0, Vector3(0.4, 0.0, -0.6)],
			[0.8, Vector3(1.8, 0.0, 0.8)],
			[1.6, Vector3(-0.6, 0.0, -0.4)],
			[2.4, Vector3(0.4, 0.0, -0.6)]
		],
		"UpperArm.L": [
			[0.0, Vector3(5.0, 76.0, -2.0)],
			[0.6, Vector3(3.0, 74.5, 0.0)],
			[1.2, Vector3(1.5, 73.5, 1.5)],
			[1.8, Vector3(3.5, 75.0, -0.5)],
			[2.4, Vector3(5.0, 76.0, -2.0)]
		],
		"LowerArm.L": [
			[0.0, Vector3(-18.0, 0.0, 4.0)],
			[1.2, Vector3(-23.0, 0.0, 6.0)],
			[2.4, Vector3(-18.0, 0.0, 4.0)]
		],
		"UpperArm.R": [
			[0.0, Vector3(6.0, -76.0, 2.0)],
			[0.6, Vector3(4.0, -74.5, 0.0)],
			[1.2, Vector3(2.0, -73.5, -1.5)],
			[1.8, Vector3(4.5, -75.0, 0.5)],
			[2.4, Vector3(6.0, -76.0, 2.0)]
		],
		"LowerArm.R": [
			[0.0, Vector3(-18.0, 0.0, -4.0)],
			[1.2, Vector3(-23.0, 0.0, -6.0)],
			[2.4, Vector3(-18.0, 0.0, -4.0)]
		],
		"UpperLeg.L": [[0.0, Vector3(-2.0, 0.0, 0.0)], [1.2, Vector3(-3.5, 0.0, 0.0)], [2.4, Vector3(-2.0, 0.0, 0.0)]],
		"LowerLeg.L": [[0.0, Vector3(4.0, 0.0, 0.0)], [1.2, Vector3(6.5, 0.0, 0.0)], [2.4, Vector3(4.0, 0.0, 0.0)]],
		"Foot.L": [[0.0, Vector3(-2.0, 0.0, 0.0)], [2.4, Vector3(-2.0, 0.0, 0.0)]],
		"UpperLeg.R": [[0.0, Vector3(-3.0, 0.0, 0.0)], [1.2, Vector3(-1.5, 0.0, 0.0)], [2.4, Vector3(-3.0, 0.0, 0.0)]],
		"LowerLeg.R": [[0.0, Vector3(5.5, 0.0, 0.0)], [1.2, Vector3(3.5, 0.0, 0.0)], [2.4, Vector3(5.5, 0.0, 0.0)]],
		"Foot.R": [[0.0, Vector3(-2.0, 0.0, 0.0)], [2.4, Vector3(-2.0, 0.0, 0.0)]]
	})

	# Walk: siklus langkah 5-fase organik dengan ayunan lengan & tindak lanjut lengan bawah
	_add_suit_anim(lib, skel_path, skel, "walk", 0.88, Animation.LOOP_LINEAR, {
		"Hips": [
			[0.0, Vector3(2.5, -2.2, 3.8)],
			[0.22, Vector3(1.5, 0.0, 1.2)],
			[0.44, Vector3(2.5, 2.2, -3.8)],
			[0.66, Vector3(1.5, 0.0, -1.2)],
			[0.88, Vector3(2.5, -2.2, 3.8)]
		],
		"Torso": [
			[0.0, Vector3(3.5, 1.8, -4.5)],
			[0.22, Vector3(4.5, 0.0, -1.5)],
			[0.44, Vector3(3.5, -1.8, 4.5)],
			[0.66, Vector3(4.5, 0.0, 1.5)],
			[0.88, Vector3(3.5, 1.8, -4.5)]
		],
		"Chest": [
			[0.0, Vector3(2.5, 0.8, -2.0)],
			[0.22, Vector3(3.5, 0.0, 0.0)],
			[0.44, Vector3(2.5, -0.8, 2.0)],
			[0.66, Vector3(3.5, 0.0, 0.0)],
			[0.88, Vector3(2.5, 0.8, -2.0)]
		],
		"UpperArm.L": [
			[0.0, Vector3(22.0, 74.0, -4.0)],
			[0.22, Vector3(4.0, 75.5, 0.0)],
			[0.44, Vector3(-24.0, 74.0, 5.0)],
			[0.66, Vector3(-2.0, 75.5, 0.0)],
			[0.88, Vector3(22.0, 74.0, -4.0)]
		],
		"LowerArm.L": [
			[0.0, Vector3(-20.0, 0.0, 4.0)],
			[0.22, Vector3(-28.0, 0.0, 5.0)],
			[0.44, Vector3(-42.0, 0.0, 7.0)],
			[0.66, Vector3(-30.0, 0.0, 5.0)],
			[0.88, Vector3(-20.0, 0.0, 4.0)]
		],
		"UpperArm.R": [
			[0.0, Vector3(-24.0, -74.0, -5.0)],
			[0.22, Vector3(-2.0, -75.5, 0.0)],
			[0.44, Vector3(22.0, -74.0, 4.0)],
			[0.66, Vector3(4.0, -75.5, 0.0)],
			[0.88, Vector3(-24.0, -74.0, -5.0)]
		],
		"LowerArm.R": [
			[0.0, Vector3(-42.0, 0.0, -7.0)],
			[0.22, Vector3(-30.0, 0.0, -5.0)],
			[0.44, Vector3(-20.0, 0.0, -4.0)],
			[0.66, Vector3(-28.0, 0.0, -5.0)],
			[0.88, Vector3(-42.0, 0.0, -7.0)]
		],
		"UpperLeg.L": [
			[0.0, Vector3(-30.0, 0.0, 0.0)],
			[0.22, Vector3(-4.0, 0.0, 0.0)],
			[0.44, Vector3(24.0, 0.0, 0.0)],
			[0.66, Vector3(-12.0, 0.0, 0.0)],
			[0.88, Vector3(-30.0, 0.0, 0.0)]
		],
		"LowerLeg.L": [
			[0.0, Vector3(12.0, 0.0, 0.0)],
			[0.22, Vector3(18.0, 0.0, 0.0)],
			[0.44, Vector3(34.0, 0.0, 0.0)],
			[0.66, Vector3(52.0, 0.0, 0.0)],
			[0.88, Vector3(12.0, 0.0, 0.0)]
		],
		"Foot.L": [
			[0.0, Vector3(-10.0, 0.0, 0.0)],
			[0.22, Vector3(2.0, 0.0, 0.0)],
			[0.44, Vector3(16.0, 0.0, 0.0)],
			[0.66, Vector3(6.0, 0.0, 0.0)],
			[0.88, Vector3(-10.0, 0.0, 0.0)]
		],
		"UpperLeg.R": [
			[0.0, Vector3(24.0, 0.0, 0.0)],
			[0.22, Vector3(-12.0, 0.0, 0.0)],
			[0.44, Vector3(-30.0, 0.0, 0.0)],
			[0.66, Vector3(-4.0, 0.0, 0.0)],
			[0.88, Vector3(24.0, 0.0, 0.0)]
		],
		"LowerLeg.R": [
			[0.0, Vector3(34.0, 0.0, 0.0)],
			[0.22, Vector3(52.0, 0.0, 0.0)],
			[0.44, Vector3(12.0, 0.0, 0.0)],
			[0.66, Vector3(18.0, 0.0, 0.0)],
			[0.88, Vector3(34.0, 0.0, 0.0)]
		],
		"Foot.R": [
			[0.0, Vector3(16.0, 0.0, 0.0)],
			[0.22, Vector3(6.0, 0.0, 0.0)],
			[0.44, Vector3(-10.0, 0.0, 0.0)],
			[0.66, Vector3(2.0, 0.0, 0.0)],
			[0.88, Vector3(16.0, 0.0, 0.0)]
		]
	})

	# Sprint / Run: lari panik realistis dengan condong tubuh & dorongan siku aktif
	_add_suit_anim(lib, skel_path, skel, "sprint", 0.56, Animation.LOOP_LINEAR, {
		"Hips": [
			[0.0, Vector3(6.0, -3.5, 6.0)],
			[0.14, Vector3(4.0, 0.0, 2.0)],
			[0.28, Vector3(6.0, 3.5, -6.0)],
			[0.42, Vector3(4.0, 0.0, -2.0)],
			[0.56, Vector3(6.0, -3.5, 6.0)]
		],
		"Torso": [
			[0.0, Vector3(9.0, 2.5, -7.5)],
			[0.14, Vector3(11.0, 0.0, -2.0)],
			[0.28, Vector3(9.0, -2.5, 7.5)],
			[0.42, Vector3(11.0, 0.0, 2.0)],
			[0.56, Vector3(9.0, 2.5, -7.5)]
		],
		"Chest": [
			[0.0, Vector3(6.0, 1.5, -4.0)],
			[0.14, Vector3(8.0, 0.0, 0.0)],
			[0.28, Vector3(6.0, -1.5, 4.0)],
			[0.42, Vector3(8.0, 0.0, 0.0)],
			[0.56, Vector3(6.0, 1.5, -4.0)]
		],
		"UpperArm.L": [
			[0.0, Vector3(38.0, 70.0, -8.0)],
			[0.14, Vector3(4.0, 72.0, 0.0)],
			[0.28, Vector3(-44.0, 68.0, 10.0)],
			[0.42, Vector3(-6.0, 72.0, 0.0)],
			[0.56, Vector3(38.0, 70.0, -8.0)]
		],
		"LowerArm.L": [
			[0.0, Vector3(-54.0, 0.0, 8.0)],
			[0.14, Vector3(-66.0, 0.0, 10.0)],
			[0.28, Vector3(-82.0, 0.0, 14.0)],
			[0.42, Vector3(-68.0, 0.0, 10.0)],
			[0.56, Vector3(-54.0, 0.0, 8.0)]
		],
		"UpperArm.R": [
			[0.0, Vector3(-44.0, -68.0, -10.0)],
			[0.14, Vector3(-6.0, -72.0, 0.0)],
			[0.28, Vector3(38.0, -70.0, 8.0)],
			[0.42, Vector3(4.0, -72.0, 0.0)],
			[0.56, Vector3(-44.0, -68.0, -10.0)]
		],
		"LowerArm.R": [
			[0.0, Vector3(-82.0, 0.0, -14.0)],
			[0.14, Vector3(-68.0, 0.0, -10.0)],
			[0.28, Vector3(-54.0, 0.0, -8.0)],
			[0.42, Vector3(-66.0, 0.0, -10.0)],
			[0.56, Vector3(-82.0, 0.0, -14.0)]
		],
		"UpperLeg.L": [
			[0.0, Vector3(-48.0, 0.0, 0.0)],
			[0.14, Vector3(-6.0, 0.0, 0.0)],
			[0.28, Vector3(40.0, 0.0, 0.0)],
			[0.42, Vector3(-18.0, 0.0, 0.0)],
			[0.56, Vector3(-48.0, 0.0, 0.0)]
		],
		"LowerLeg.L": [
			[0.0, Vector3(20.0, 0.0, 0.0)],
			[0.14, Vector3(24.0, 0.0, 0.0)],
			[0.28, Vector3(56.0, 0.0, 0.0)],
			[0.42, Vector3(78.0, 0.0, 0.0)],
			[0.56, Vector3(20.0, 0.0, 0.0)]
		],
		"Foot.L": [
			[0.0, Vector3(-14.0, 0.0, 0.0)],
			[0.28, Vector3(22.0, 0.0, 0.0)],
			[0.56, Vector3(-14.0, 0.0, 0.0)]
		],
		"UpperLeg.R": [
			[0.0, Vector3(40.0, 0.0, 0.0)],
			[0.14, Vector3(-18.0, 0.0, 0.0)],
			[0.28, Vector3(-48.0, 0.0, 0.0)],
			[0.42, Vector3(-6.0, 0.0, 0.0)],
			[0.56, Vector3(40.0, 0.0, 0.0)]
		],
		"LowerLeg.R": [
			[0.0, Vector3(56.0, 0.0, 0.0)],
			[0.14, Vector3(78.0, 0.0, 0.0)],
			[0.28, Vector3(20.0, 0.0, 0.0)],
			[0.42, Vector3(24.0, 0.0, 0.0)],
			[0.56, Vector3(56.0, 0.0, 0.0)]
		],
		"Foot.R": [
			[0.0, Vector3(22.0, 0.0, 0.0)],
			[0.28, Vector3(-14.0, 0.0, 0.0)],
			[0.56, Vector3(22.0, 0.0, 0.0)]
		]
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
		"UpperArm.R": [[0.0, Vector3(6.0, -76.0, 0.0)], [0.18, Vector3(-58.0, -64.0, 8.0)], [0.45, Vector3(6.0, -76.0, 0.0)]],
		"LowerArm.R": [[0.0, Vector3(-18.0, 0.0, 0.0)], [0.18, Vector3(-36.0, 0.0, 0.0)], [0.45, Vector3(-18.0, 0.0, 0.0)]]
	})

	_add_suit_anim(lib, skel_path, skel, "pick-up", 0.5, Animation.LOOP_NONE, {
		"Torso": [[0.0, Vector3.ZERO], [0.22, Vector3(-22.0, 0.0, 4.0)], [0.5, Vector3.ZERO]],
		"Chest": [[0.0, Vector3.ZERO], [0.22, Vector3(-10.0, 0.0, 0.0)], [0.5, Vector3.ZERO]],
		"UpperArm.R": [[0.0, Vector3(6.0, -76.0, 0.0)], [0.22, Vector3(-68.0, -62.0, 10.0)], [0.5, Vector3(6.0, -76.0, 0.0)]],
		"LowerArm.R": [[0.0, Vector3(-18.0, 0.0, 0.0)], [0.22, Vector3(-32.0, 0.0, 0.0)], [0.5, Vector3(-18.0, 0.0, 0.0)]]
	})

	_add_suit_anim(lib, skel_path, skel, "kentongan_hit", 0.55, Animation.LOOP_NONE, {
		"Torso": [[0.0, Vector3.ZERO], [0.18, Vector3(-4.0, 0.0, 3.0)], [0.55, Vector3.ZERO]],
		"UpperArm.R": [[0.0, Vector3(-76.0, -48.0, 18.0)], [0.14, Vector3(-88.0, -44.0, 42.0)], [0.28, Vector3(-78.0, -48.0, 22.0)], [0.42, Vector3(-88.0, -44.0, 42.0)], [0.55, Vector3(-76.0, -48.0, 18.0)]],
		"LowerArm.R": [[0.0, Vector3(-28.0, -10.0, 0.0)], [0.14, Vector3(-38.0, -10.0, 18.0)], [0.42, Vector3(-38.0, -10.0, 18.0)], [0.55, Vector3(-28.0, -10.0, 0.0)]],
		"UpperArm.L": [[0.0, Vector3(-78.0, 48.0, -18.0)], [0.55, Vector3(-78.0, 48.0, -18.0)]],
		"LowerArm.L": [[0.0, Vector3(-28.0, 10.0, 0.0)], [0.55, Vector3(-28.0, 10.0, 0.0)]]
	})

	_add_suit_anim(lib, skel_path, skel, "drink", 0.65, Animation.LOOP_NONE, {
		"Torso": [[0.0, Vector3.ZERO], [0.28, Vector3(4.0, 0.0, -2.0)], [0.65, Vector3.ZERO]],
		"UpperArm.R": [[0.0, Vector3(-78.0, -48.0, 18.0)], [0.28, Vector3(-104.0, -44.0, 36.0)], [0.48, Vector3(-104.0, -44.0, 36.0)], [0.65, Vector3(-78.0, -48.0, 18.0)]],
		"LowerArm.R": [[0.0, Vector3(-24.0, -10.0, 0.0)], [0.28, Vector3(-52.0, -8.0, 22.0)], [0.48, Vector3(-52.0, -8.0, 22.0)], [0.65, Vector3(-24.0, -10.0, 0.0)]]
	})

	_add_suit_anim(lib, skel_path, skel, "die", 0.7, Animation.LOOP_NONE, {
		"Hips": [[0.0, Vector3.ZERO], [0.5, Vector3(82.0, 0.0, 0.0)], [0.7, Vector3(82.0, 0.0, 0.0)]],
		"Head": [[0.0, Vector3.ZERO], [0.5, Vector3(18.0, 0.0, 0.0)], [0.7, Vector3(18.0, 0.0, 0.0)]],
		"UpperArm.L": [[0.0, Vector3(4.0, 76.0, 0.0)], [0.7, Vector3(18.0, 62.0, 0.0)]],
		"UpperArm.R": [[0.0, Vector3(6.0, -76.0, 0.0)], [0.7, Vector3(18.0, -62.0, 0.0)]]
	})

func _build_hand_item_holder(skel: Skeleton3D) -> void:
	if not skel:
		return
	if hand_item_holder and is_instance_valid(hand_item_holder):
		hand_item_holder.queue_free()
	if left_hand_item_holder and is_instance_valid(left_hand_item_holder):
		left_hand_item_holder.queue_free()
	hand_item_props.clear()
	left_hand_item_props.clear()

	var right_hand_bone: String = _resolve_bone_name(skel, "Hand.R")
	if right_hand_bone.is_empty():
		return

	hand_item_holder = BoneAttachment3D.new()
	hand_item_holder.name = "HandItemHolder"
	hand_item_holder.bone_name = right_hand_bone
	skel.add_child(hand_item_holder)

	var parent_scale: Vector3 = skel.get_parent().scale if skel.get_parent() is Node3D else Vector3.ONE
	var inv_scale := Vector3(
		1.0 / maxf(0.001, absf(parent_scale.x)),
		1.0 / maxf(0.001, absf(parent_scale.y)),
		1.0 / maxf(0.001, absf(parent_scale.z))
	)
	hand_prop_pivot = Node3D.new()
	hand_prop_pivot.name = "HandPropPivot"
	hand_prop_pivot.scale = inv_scale
	# Pada ordinaryMan.fbx, sumbu lokal X/Z hand.r berputar 90 derajat di sekitar sumbu jari (+Y)
	if right_hand_bone == "hand.r":
		hand_prop_pivot.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	hand_item_holder.add_child(hand_prop_pivot)

	var left_hand_bone: String = _resolve_bone_name(skel, "Hand.L")
	if not left_hand_bone.is_empty():
		left_hand_item_holder = BoneAttachment3D.new()
		left_hand_item_holder.name = "LeftHandItemHolder"
		left_hand_item_holder.bone_name = left_hand_bone
		skel.add_child(left_hand_item_holder)

		left_hand_prop_pivot = Node3D.new()
		left_hand_prop_pivot.name = "LeftHandPropPivot"
		left_hand_prop_pivot.scale = inv_scale
		if left_hand_bone == "hand.l":
			left_hand_prop_pivot.rotation_degrees = Vector3(0.0, -90.0, 0.0)
		left_hand_item_holder.add_child(left_hand_prop_pivot)

	# 1. Flashlight
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
	cyl.top_radius = 0.019
	cyl.bottom_radius = 0.015
	cyl.height = 0.150
	torch_body.mesh = cyl
	torch_body.material_override = body_metal_mat
	torch_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	torch_body.position = Vector3(0.0, 0.125, -0.028)
	torch_root.add_child(torch_body)

	handheld_flashlight_lens = MeshInstance3D.new()
	handheld_flashlight_lens.name = "HandheldFlashlightLens"
	var lens_cyl := CylinderMesh.new()
	lens_cyl.top_radius = 0.021
	lens_cyl.bottom_radius = 0.020
	lens_cyl.height = 0.012
	handheld_flashlight_lens.mesh = lens_cyl
	handheld_flashlight_lens.material_override = lens_mat
	handheld_flashlight_lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	handheld_flashlight_lens.position = Vector3(0.0, 0.204, -0.028)
	torch_root.add_child(handheld_flashlight_lens)

	# 2. Jamu Tolak Bala
	var jamu_root := Node3D.new()
	jamu_root.name = "Prop_jamu"
	jamu_root.rotation_degrees = Vector3(-28.0, 0.0, -14.0)
	jamu_root.position = Vector3(0.004, 0.115, -0.030)
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

	# 3. Minyak Tanah & Korek
	var minyak_root := Node3D.new()
	minyak_root.name = "Prop_minyak_tanah"
	minyak_root.rotation_degrees = Vector3(-26.0, 0.0, -12.0)
	minyak_root.position = Vector3(0.005, 0.118, -0.032)
	hand_prop_pivot.add_child(minyak_root)
	hand_item_props["minyak_tanah"] = minyak_root

	_attach_suit_box(minyak_root, "CanBody", Vector3(0.056, 0.088, 0.042), Vector3.ZERO, _make_suit_mat(Color(0.28, 0.24, 0.20), 0.5, 0.55))
	_attach_suit_box(minyak_root, "CanCap", Vector3(0.022, 0.016, 0.022), Vector3(0.012, 0.050, 0.0), _make_suit_mat(Color(0.85, 0.72, 0.2), 0.35, 0.6))
	_attach_suit_box(minyak_root, "Matchbox", Vector3(0.032, 0.022, 0.014), Vector3(-0.010, 0.046, 0.018), _make_suit_mat(Color(0.82, 0.22, 0.14), 0.8, 0.0, 0.06))

	# 4. Papan & Paku
	var papan_root := Node3D.new()
	papan_root.name = "Prop_papan_paku"
	papan_root.position = Vector3(0.0, 0.125, -0.028)
	hand_prop_pivot.add_child(papan_root)
	hand_item_props["papan_paku"] = papan_root

	var wood_mat: StandardMaterial3D = _make_suit_mat(Color(0.45, 0.28, 0.14), 0.88, 0.0, 0.05)
	var nail_mat: StandardMaterial3D = _make_suit_mat(Color(0.75, 0.77, 0.82), 0.3, 0.85)
	_attach_suit_box(papan_root, "Plank", Vector3(0.052, 0.185, 0.016), Vector3.ZERO, wood_mat)
	_attach_suit_box(papan_root, "Nail1", Vector3(0.008, 0.008, 0.032), Vector3(0.012, 0.055, 0.006), nail_mat)
	_attach_suit_box(papan_root, "Nail2", Vector3(0.008, 0.008, 0.032), Vector3(-0.012, -0.045, 0.006), nail_mat)

	# 5. Baterai
	var bat_root := Node3D.new()
	bat_root.name = "Prop_baterai"
	bat_root.rotation_degrees = Vector3(-28.0, 0.0, -12.0)
	bat_root.position = Vector3(0.0, 0.115, -0.028)
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

	# 6. Energy Drink (Kaleng minuman energi aluminium di tangan kanan)
	var drink_root := Node3D.new()
	drink_root.name = "Prop_energy_drink"
	drink_root.rotation_degrees = Vector3(-26.0, 0.0, -10.0)
	drink_root.position = Vector3(0.0, 0.118, -0.026)
	hand_prop_pivot.add_child(drink_root)
	hand_item_props["energy_drink"] = drink_root

	var drink_blue: StandardMaterial3D = _make_suit_mat(Color(0.08, 0.44, 0.92), 0.24, 0.85, 0.08)
	var drink_neon: StandardMaterial3D = _make_suit_mat(Color(0.15, 0.95, 0.88), 0.22, 0.35, 0.35)
	var drink_silver: StandardMaterial3D = _make_suit_mat(Color(0.84, 0.87, 0.90), 0.22, 0.90, 0.04)
	var drink_hole: StandardMaterial3D = _make_suit_mat(Color(0.05, 0.05, 0.07), 0.8, 0.3, 0.0)
	_attach_suit_cyl(drink_root, "CanBody", 0.026, 0.026, 0.084, Vector3.ZERO, drink_blue)
	_attach_suit_cyl(drink_root, "NeonBandTop", 0.0268, 0.0268, 0.018, Vector3(0.0, 0.012, 0.0), drink_neon)
	_attach_suit_cyl(drink_root, "NeonBandLow", 0.0268, 0.0268, 0.008, Vector3(0.0, -0.020, 0.0), drink_neon)
	_attach_suit_cyl(drink_root, "CanNeck", 0.021, 0.026, 0.013, Vector3(0.0, 0.048, 0.0), drink_silver)
	_attach_suit_cyl(drink_root, "CanBase", 0.026, 0.022, 0.009, Vector3(0.0, -0.046, 0.0), drink_silver)
	_attach_suit_cyl(drink_root, "CanRim", 0.022, 0.022, 0.005, Vector3(0.0, 0.056, 0.0), drink_silver)
	_attach_suit_box(drink_root, "Opening", Vector3(0.010, 0.004, 0.007), Vector3(0.0, 0.058, 0.009), drink_hole)
	_attach_suit_box(drink_root, "PullTab", Vector3(0.008, 0.003, 0.015), Vector3(0.0, 0.060, -0.002), drink_silver, Vector3(12.0, 0.0, 0.0))

	# 7. Kentongan (2 Tangan: kanan = pemukul kayu, kiri = tabung kentongan)
	var pemukul_root := Node3D.new()
	pemukul_root.name = "Prop_kentongan_pemukul"
	pemukul_root.position = Vector3(0.0, 0.125, -0.025)
	pemukul_root.rotation_degrees = Vector3(-48.0, 0.0, 28.0)
	hand_prop_pivot.add_child(pemukul_root)
	hand_item_props["kentongan"] = pemukul_root

	var beater_wood: StandardMaterial3D = _make_suit_mat(Color(0.45, 0.25, 0.11), 0.76, 0.04, 0.05)
	var beater_tip: StandardMaterial3D = _make_suit_mat(Color(0.30, 0.16, 0.07), 0.82, 0.02, 0.04)
	_attach_suit_cyl(pemukul_root, "BeaterShaft", 0.011, 0.010, 0.22, Vector3(0.0, 0.06, 0.0), beater_wood)
	_attach_suit_sph(pemukul_root, "BeaterHead", 0.022, Vector3(0.0, 0.175, 0.0), beater_tip)

	if left_hand_prop_pivot:
		var kentongan_root := Node3D.new()
		kentongan_root.name = "Prop_kentongan_body"
		kentongan_root.position = Vector3(0.0, 0.120, -0.028)
		kentongan_root.rotation_degrees = Vector3(-68.0, 12.0, -8.0)
		left_hand_prop_pivot.add_child(kentongan_root)
		left_hand_item_props["kentongan"] = kentongan_root

		var bamboo_mat: StandardMaterial3D = _make_suit_mat(Color(0.60, 0.41, 0.17), 0.75, 0.02, 0.06)
		var ring_mat: StandardMaterial3D = _make_suit_mat(Color(0.32, 0.19, 0.08), 0.84, 0.02, 0.04)
		var slit_mat: StandardMaterial3D = _make_suit_mat(Color(0.04, 0.02, 0.015), 0.98, 0.0, 0.0)
		_attach_suit_cyl(kentongan_root, "Body", 0.044, 0.048, 0.24, Vector3(0.0, 0.04, 0.0), bamboo_mat)
		for ry: float in [-0.065, 0.04, 0.145]:
			_attach_suit_cyl(kentongan_root, "Ring", 0.050, 0.050, 0.015, Vector3(0.0, ry, 0.0), ring_mat)
		_attach_suit_cyl(kentongan_root, "Peg", 0.012, 0.012, 0.045, Vector3(0.0, 0.175, 0.0), ring_mat)
		_attach_suit_box(kentongan_root, "Slit", Vector3(0.024, 0.15, 0.032), Vector3(-0.032, 0.04, 0.022), slit_mat)

	_sync_hand_prop_visibility()

func _apply_fpp_hand_override() -> void:
	if not player_skeleton or in_cutscene or is_caught or is_hiding:
		return

	# Stabilkan tulang punggung di FPP dan sembunyikan vertex kepala agar tidak menghalangi kamera
	for spine_bone: String in ["Hips", "Torso", "Chest", "Neck", "Head"]:
		var spine_idx: int = _find_bone_idx(player_skeleton, spine_bone)
		if spine_idx >= 0:
			player_skeleton.set_bone_pose_rotation(spine_idx, player_skeleton.get_bone_rest(spine_idx).basis.get_rotation_quaternion())
	var head_idx: int = _find_bone_idx(player_skeleton, "Head")
	if head_idx >= 0:
		player_skeleton.set_bone_pose_scale(head_idx, Vector3(0.001, 0.001, 0.001))

	var pitch_deg: float = clampf(rad_to_deg(head.rotation.x) * 0.96, -78.0, 22.0) if head else 0.0
	var walk_phase: float = bob_time * bob_freq * 0.5
	var breath_primary: float = sin(idle_arm_time * 1.85)
	var breath_secondary: float = cos(idle_arm_time * 0.95) * 0.5
	var idle_breath: float = (breath_primary + breath_secondary) * lerpf(1.35, 2.8, sprint_blend)
	var fear_tremor: float = 0.0
	if sanity_system:
		var s_ratio: float = clampf(sanity_system.current_sanity / maxf(1.0, sanity_system.max_sanity), 0.0, 1.0)
		if s_ratio < 0.5:
			fear_tremor = (0.5 - s_ratio) * 2.4 * sin(idle_arm_time * 19.0)

	var action_nudge: float = 0.0
	if action_anim_timer > 0.0:
		var progress: float = clampf(1.0 - (action_anim_timer / maxf(0.01, action_anim_duration)), 0.0, 1.0)
		action_nudge = sin(progress * PI) * 16.0

	var hand_idx: int = _find_bone_idx(player_skeleton, "Hand.R")
	var hand_l_idx: int = _find_bone_idx(player_skeleton, "Hand.L")

	# 1. Mode TIDAK PEGANG BARANG (Empty-Handed): kedua lengan berayun & bernapas realistis
	if equipped_item_id == "":
		if hand_idx >= 0:
			player_skeleton.set_bone_pose_scale(hand_idx, Vector3(0.86, 0.86, 0.86))
		if hand_l_idx >= 0:
			player_skeleton.set_bone_pose_scale(hand_l_idx, Vector3(0.86, 0.86, 0.86))

		var stride_r: float = sin(walk_phase) * lerpf(18.0, 42.0, sprint_blend) * move_blend
		var stride_l: float = -sin(walk_phase) * lerpf(18.0, 42.0, sprint_blend) * move_blend
		var elbow_pump_r: float = maxf(0.0, -sin(walk_phase - 0.35)) * lerpf(14.0, 34.0, sprint_blend) * move_blend
		var elbow_pump_l: float = maxf(0.0, sin(walk_phase - 0.35)) * lerpf(14.0, 34.0, sprint_blend) * move_blend
		var guard_lift: float = lerpf(0.0, 26.0, sprint_blend) * move_blend

		# Lengan kanan (tidak pegang barang: ayunan langkah + guard saat lari + gerakan meraih saat interaksi)
		_set_skeleton_bone_rot("Shoulder.R", 0.0, 0.0, 0.0)
		_set_skeleton_bone_rot(
			"UpperArm.R",
			-22.0 - guard_lift - stride_r - idle_breath * 0.9 - action_nudge * 2.2 + look_sway.y * 0.6,
			-66.0 + sprint_blend * 8.0,
			14.0 + look_sway.x * 0.8 + sin(walk_phase) * 4.0 * move_blend
		)
		_set_skeleton_bone_rot(
			"LowerArm.R",
			-24.0 - guard_lift * 0.7 - elbow_pump_r - action_nudge * 1.1 - absf(breath_primary) * 2.0,
			-8.0,
			-6.0 + look_sway.x * 0.6
		)
		_set_skeleton_bone_rot("Hand.R", -4.0 - action_nudge * 0.8, 0.0, -6.0 + cos(walk_phase) * 5.0 * move_blend)

		# Lengan kiri (penyeimbang alami saat jalan/lari & napas)
		_set_skeleton_bone_rot("Shoulder.L", 0.0, 0.0, 0.0)
		_set_skeleton_bone_rot(
			"UpperArm.L",
			-20.0 - guard_lift - stride_l - idle_breath * 0.8 + look_sway.y * 0.5,
			66.0 - sprint_blend * 8.0,
			-14.0 + look_sway.x * 0.7 - sin(walk_phase) * 4.0 * move_blend
		)
		_set_skeleton_bone_rot(
			"LowerArm.L",
			-24.0 - guard_lift * 0.7 - elbow_pump_l - absf(breath_primary) * 2.0,
			8.0,
			6.0 + look_sway.x * 0.5
		)
		_set_skeleton_bone_rot("Hand.L", -4.0, 0.0, 6.0 - cos(walk_phase) * 5.0 * move_blend)
		return

	# 2. Mode PEGANG BARANG (Holding Item): postur spesifik barang + inersia kamera + transisi angkat tangan
	var sway_yaw: float = sin(walk_phase) * lerpf(2.8, 5.2, sprint_blend) * move_blend
	var sway_lift: float = absf(cos(walk_phase)) * lerpf(1.8, 3.8, sprint_blend) * move_blend
	var wrist_lag: float = cos(walk_phase - 0.35) * lerpf(2.2, 4.4, sprint_blend) * move_blend
	var raise_drop: float = (1.0 - ease(equip_raise_blend, 0.35)) * 32.0

	var item_pitch_offset: float = 0.0
	var item_drop_offset: float = 0.0
	var item_yaw_offset: float = 0.0
	var is_two_handed_kentongan: bool = (equipped_item_id == "kentongan")
	match equipped_item_id:
		"jamu", "baterai", "energy_drink":
			item_pitch_offset = 6.0
			item_drop_offset = 4.0
			item_yaw_offset = 5.0
		"papan_paku", "minyak_tanah":
			item_pitch_offset = 4.0
			item_drop_offset = -3.0
			item_yaw_offset = -2.0
		"kentongan":
			item_pitch_offset = -2.0
			item_drop_offset = 2.0
			item_yaw_offset = 4.0

	var strike_swing: float = 0.0
	var drink_lift: float = 0.0
	if is_two_handed_kentongan and action_anim_timer > 0.0:
		var hit_p: float = clampf(1.0 - (action_anim_timer / maxf(0.01, action_anim_duration)), 0.0, 1.0)
		strike_swing = absf(sin(hit_p * PI * 2.0)) * 28.0
	elif equipped_item_id == "energy_drink" and action_anim_timer > 0.0:
		var drink_p: float = clampf(1.0 - (action_anim_timer / maxf(0.01, action_anim_duration)), 0.0, 1.0)
		drink_lift = sin(drink_p * PI) * 26.0

	_set_skeleton_bone_rot("Shoulder.R", -18.0, -8.0, 6.0)
	_set_skeleton_bone_rot(
		"UpperArm.R",
		-95.0 - pitch_deg + item_pitch_offset + raise_drop - idle_breath - sway_lift * 0.65 - drink_lift + (0.0 if (is_two_handed_kentongan or drink_lift > 0.0) else action_nudge * 0.55) + look_sway.y * 0.85 + fear_tremor * 0.4,
		-54.0 + item_drop_offset - sprint_blend * 4.5,
		28.0 + item_yaw_offset + strike_swing + drink_lift * 0.6 + sway_yaw + sprint_blend * 6.5 + look_sway.x * 1.15
	)
	_set_skeleton_bone_rot(
		"LowerArm.R",
		-20.0 - sway_lift * 0.65 - sprint_blend * 9.0 - drink_lift * 1.2 + (action_nudge * 0.65 if (not is_two_handed_kentongan and drink_lift <= 0.0) else (-10.0 if is_two_handed_kentongan else 0.0)) + look_sway.y * 0.45,
		-10.0,
		wrist_lag + strike_swing * 0.5 + idle_breath * 0.55 + look_sway.x * 0.75 + fear_tremor * 0.6
	)
	_set_skeleton_bone_rot(
		"Hand.R",
		-4.0 - action_nudge * 0.85 - drink_lift * 1.1 + look_sway.y * 0.35,
		0.0,
		-10.0 + strike_swing * 0.35 + wrist_lag * 0.8 + look_sway.x * 0.5 + fear_tremor
	)

	if is_two_handed_kentongan:
		# Tangan kiri mengangkat tabung kentongan di sisi kiri pandangan agar siap dipukul tangan kanan
		_set_skeleton_bone_rot("Shoulder.L", -18.0, 8.0, -6.0)
		_set_skeleton_bone_rot(
			"UpperArm.L",
			-95.0 - pitch_deg + raise_drop - idle_breath * 0.9 - sway_lift * 0.5 + look_sway.y * 0.8 + fear_tremor * 0.3,
			52.0 + sprint_blend * 4.5,
			-28.0 - sway_yaw * 0.6 - sprint_blend * 5.0 + look_sway.x * 1.0
		)
		_set_skeleton_bone_rot(
			"LowerArm.L",
			-20.0 - sway_lift * 0.5 - sprint_blend * 8.0 + look_sway.y * 0.4,
			10.0,
			-wrist_lag * 0.6 + idle_breath * 0.45 + look_sway.x * 0.65
		)
		_set_skeleton_bone_rot(
			"Hand.L",
			-4.0 + look_sway.y * 0.3,
			0.0,
			10.0 + look_sway.x * 0.45
		)
		if hand_l_idx >= 0:
			player_skeleton.set_bone_pose_scale(hand_l_idx, Vector3(0.78, 0.78, 0.78))
	else:
		# Lengan kiri tetap mengayun sebagai penyeimbang tubuh saat memegang barang di tangan kanan
		_set_skeleton_bone_rot("Shoulder.L", 0.0, 0.0, 0.0)
		if hand_l_idx >= 0:
			player_skeleton.set_bone_pose_scale(hand_l_idx, Vector3(0.86, 0.86, 0.86))
		var left_stride: float = -sin(walk_phase) * lerpf(16.0, 36.0, sprint_blend) * move_blend
		var left_pump: float = maxf(0.0, sin(walk_phase - 0.35)) * lerpf(12.0, 28.0, sprint_blend) * move_blend
		_set_skeleton_bone_rot(
			"UpperArm.L",
			-18.0 - lerpf(0.0, 20.0, sprint_blend) * move_blend - left_stride - idle_breath * 0.7,
			68.0 - sprint_blend * 6.0,
			-12.0 + look_sway.x * 0.5
		)
		_set_skeleton_bone_rot("LowerArm.L", -22.0 - left_pump, 6.0, 5.0)
		_set_skeleton_bone_rot("Hand.L", -4.0, 0.0, 6.0)

	if hand_idx >= 0:
		player_skeleton.set_bone_pose_scale(hand_idx, Vector3(0.78, 0.78, 0.78))

	for finger_name: String in ["Index", "Middle", "Ring", "Pinky"]:
		_set_skeleton_bone_rot(finger_name + "2.R", 0.0, -42.0, 0.0)
		_set_skeleton_bone_rot(finger_name + "3.R", 0.0, -52.0, 0.0)
		_set_skeleton_bone_rot(finger_name + "4.R", 0.0, -30.0, 0.0)
	_set_skeleton_bone_rot("Thumb2.R", 14.0, -34.0, -18.0)
	_set_skeleton_bone_rot("Thumb3.R", 8.0, -24.0, 0.0)

func _set_skeleton_bone_rot(canonical_bone_name: String, rot_x_deg: float, rot_z_deg: float, rot_y_deg: float) -> void:
	var idx: int = _find_bone_idx(player_skeleton, canonical_bone_name)
	if idx >= 0:
		player_skeleton.set_bone_pose_rotation(idx, _bone_pose_quat(player_skeleton, canonical_bone_name, rot_x_deg, rot_z_deg, rot_y_deg))

func prepare_for_cutscene() -> void:
	in_cutscene = true
	action_anim_timer = 0.0
	if player_skeleton:
		var hand_idx: int = _find_bone_idx(player_skeleton, "Hand.R")
		if hand_idx >= 0:
			player_skeleton.set_bone_pose_scale(hand_idx, Vector3.ONE)
		var hand_l_idx: int = _find_bone_idx(player_skeleton, "Hand.L")
		if hand_l_idx >= 0:
			player_skeleton.set_bone_pose_scale(hand_l_idx, Vector3.ONE)
		var head_idx: int = _find_bone_idx(player_skeleton, "Head")
		if head_idx >= 0:
			player_skeleton.set_bone_pose_scale(head_idx, Vector3.ONE)
	if model_head_mesh:
		model_head_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if player_model:
		player_model.position = Vector3.ZERO
	if camera:
		camera.rotation.z = 0.0
	_hide_all_hand_props()
	if flashlight:
		flashlight.visible = false
	_play_player_anim("idle", 0.1, 1.0)

func pose_abducted_dangle(phase: float) -> void:
	if not player_skeleton:
		return
	for i: int in range(player_skeleton.get_bone_count()):
		player_skeleton.reset_bone_pose(i)
	var head_idx: int = _find_bone_idx(player_skeleton, "Head")
	if head_idx >= 0:
		player_skeleton.set_bone_pose_scale(head_idx, Vector3.ONE)
	var hand_r_idx: int = _find_bone_idx(player_skeleton, "Hand.R")
	if hand_r_idx >= 0:
		player_skeleton.set_bone_pose_scale(hand_r_idx, Vector3.ONE)
	var hand_l_idx: int = _find_bone_idx(player_skeleton, "Hand.L")
	if hand_l_idx >= 0:
		player_skeleton.set_bone_pose_scale(hand_l_idx, Vector3.ONE)
	var sway_a: float = sin(phase * 7.0) * 14.0
	var sway_b: float = cos(phase * 5.8) * 12.0
	_set_skeleton_bone_rot("Torso", 8.0 + sin(phase * 4.0) * 4.0, 0.0, 0.0)
	_set_skeleton_bone_rot("UpperArm.R", -120.0 + sway_a, -36.0, 12.0)
	_set_skeleton_bone_rot("LowerArm.R", -28.0 + sway_b, 0.0, 0.0)
	_set_skeleton_bone_rot("UpperArm.L", -115.0 - sway_a, 36.0, -12.0)
	_set_skeleton_bone_rot("LowerArm.L", -26.0 - sway_b, 0.0, 0.0)
	_set_skeleton_bone_rot("UpperLeg.R", 14.0 + sway_b * 0.8, 0.0, -4.0)
	_set_skeleton_bone_rot("LowerLeg.R", 18.0 + absf(sway_a) * 0.5, 0.0, 0.0)
	_set_skeleton_bone_rot("UpperLeg.L", 14.0 - sway_b * 0.8, 0.0, 4.0)
	_set_skeleton_bone_rot("LowerLeg.L", 18.0 + absf(sway_b) * 0.5, 0.0, 0.0)

func trigger_action_animation(anim_name: String, duration: float = 0.45) -> void:
	if not model_anim_player or not model_anim_player.has_animation(anim_name):
		return
	action_anim_duration = maxf(0.1, duration)
	action_anim_timer = action_anim_duration
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
		_play_player_anim("sprint", 0.14, 1.12)
	elif is_moving:
		_play_player_anim("walk", 0.14, 1.0)
	else:
		_play_player_anim("idle", 0.22, 1.0)

func _update_fpp_camera_and_arm(delta: float, is_moving: bool) -> void:
	if not camera or not head:
		return
	if model_head_mesh:
		model_head_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY

	idle_arm_time += maxf(0.0, delta)
	var target_move: float = 1.0 if (is_on_floor() and is_moving and not is_hiding and not is_caught) else 0.0
	var target_sprint: float = 1.0 if (target_move > 0.5 and is_sprinting) else 0.0
	if delta > 0.0:
		move_blend = lerpf(move_blend, target_move, minf(1.0, delta * 8.5))
		sprint_blend = lerpf(sprint_blend, target_sprint, minf(1.0, delta * 7.5))
		equip_raise_blend = minf(1.0, equip_raise_blend + delta * 4.5)
		landing_dip = move_toward(landing_dip, 0.0, delta * 0.24)
		look_sway_target = look_sway_target.lerp(Vector2.ZERO, minf(1.0, delta * 10.0))
		look_sway = look_sway.lerp(look_sway_target, minf(1.0, delta * 14.0))
	else:
		move_blend = target_move
		sprint_blend = target_sprint
		equip_raise_blend = 1.0

	var breath_cam_y: float = sin(idle_arm_time * 1.85) * 0.004 * (1.0 - move_blend * 0.6)
	var walk_bob_x: float = cos(bob_time * bob_freq * 0.5) * bob_amp * 0.65 * lerpf(1.0, 1.35, sprint_blend) * move_blend
	var walk_bob_y: float = sin(bob_time * bob_freq) * bob_amp * lerpf(1.0, 1.4, sprint_blend) * move_blend
	var target_cam_pos := Vector3(
		initial_camera_pos.x + walk_bob_x,
		initial_camera_pos.y + walk_bob_y + breath_cam_y - landing_dip,
		initial_camera_pos.z
	)
	if delta > 0.0:
		camera.position = camera.position.lerp(target_cam_pos, minf(1.0, delta * 14.0))
	else:
		camera.position = target_cam_pos

	# Low-sanity camera dizzy tilt + subtle step roll
	var dizzy_factor: float = 0.0
	if sanity_system and not is_caught and not in_cutscene:
		var sanity_ratio: float = clampf(sanity_system.current_sanity / maxf(1.0, sanity_system.max_sanity), 0.0, 1.0)
		dizzy_factor = clampf((0.55 - sanity_ratio) / 0.55, 0.0, 1.0)
	var step_roll: float = sin(bob_time * bob_freq * 0.5) * deg_to_rad(lerpf(0.45, 1.15, sprint_blend)) * move_blend
	camera.rotation.z = sin(idle_arm_time * 1.9) * deg_to_rad(3.2) * dizzy_factor + step_roll
	camera.rotation.x = cos(idle_arm_time * 2.4) * deg_to_rad(1.1) * dizzy_factor

	if player_model:
		var cam_bob_offset: Vector3 = head.transform.basis * (camera.position - initial_camera_pos)
		player_model.position = PLAYER_MODEL_FPP_POS + cam_bob_offset
	if model_anim_player and not model_anim_player.is_playing():
		_apply_fpp_hand_override()

	if interaction_ray:
		interaction_ray.position = Vector3.ZERO
	if flashlight:
		flashlight.position = Vector3(0.14 + look_sway.x * 0.002, -0.09 + look_sway.y * 0.002, -0.38)
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
	energy_drink_timer = 0.0
	energy_drink_cooldown = 0.0
	move_blend = 0.0
	sprint_blend = 0.0
	velocity = Vector3.ZERO
	global_position = initial_spawn_position + Vector3(0.0, 0.08, 0.0)
	rotation.y = initial_spawn_rotation
	head.rotation = Vector3.ZERO
	if camera:
		camera.rotation = Vector3.ZERO
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

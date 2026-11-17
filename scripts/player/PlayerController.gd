class_name PlayerController
extends CharacterBody3D

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
var flashlight_drain_rate: float = 0.7

# Hiding
var is_hiding: bool = false
var hiding_spot: Node = null
var hide_yaw_center: float = 0.0
const HIDE_LOOK_YAW: float = 55.0
const HIDE_LOOK_PITCH: float = 40.0

# House Interior
var is_inside_house: bool = false
var current_house: Node = null

# Noise
var current_noise_level: float = 0.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	if _is_touch_device():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	initial_camera_pos = camera.position
	GameManager.player_character = self
	SettingsManager.apply_player_settings(self)
	var sanity_cfg: Dictionary = GameManager.get_sanity_settings_for_difficulty(GameManager.selected_difficulty)
	flashlight_drain_rate = sanity_cfg.get("flash_drain", 0.7)
	
	SignalBus.flashlight_toggled.emit(flashlight_on)
	SignalBus.flashlight_battery_changed.emit(flashlight_battery, 100.0)
	SignalBus.player_stamina_changed.emit(current_stamina, max_stamina)

func _unhandled_input(event: InputEvent) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
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
		interaction_ray.trigger_interaction(self)
		
	if event.is_action_pressed("slot_1"):
		inventory_system.select_slot(0)
	elif event.is_action_pressed("slot_2"):
		inventory_system.select_slot(1)
	elif event.is_action_pressed("slot_3"):
		inventory_system.select_slot(2)
	elif event.is_action_pressed("slot_4"):
		inventory_system.select_slot(3)
		
	if event.is_action_pressed("ui_accept"):
		_try_use_equipped_item()
		
	if event.is_action_pressed("drop_item"):
		var drop_pos: Vector3 = global_position + (-camera.global_transform.basis.z * 1.2) + Vector3(0, 0.4, 0)
		inventory_system.drop_equipped_item(drop_pos)

func _physics_process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
		
	if is_hiding:
		current_noise_level = 0.0
		velocity = Vector3.ZERO
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

	# Head Bobbing & Footsteps
	if is_on_floor() and is_moving:
		var current_speed: float = velocity.length()
		bob_time += delta * current_speed * (1.3 if is_sprinting else 1.0)
		camera.position.y = initial_camera_pos.y + sin(bob_time * bob_freq) * bob_amp
		camera.position.x = initial_camera_pos.x + cos(bob_time * bob_freq * 0.5) * bob_amp * 0.6
		
		step_distance += current_speed * delta
		var req_step: float = step_interval * (0.75 if is_sprinting else 1.0)
		if step_distance >= req_step:
			step_distance = 0.0
			_play_footstep()
	else:
		camera.position = camera.position.lerp(initial_camera_pos, delta * 8.0)

	# Flashlight battery drain
	if flashlight_on:
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
	if state != null:
		flashlight_on = bool(state)
	else:
		flashlight_on = !flashlight_on
		
	if flashlight_on and flashlight_battery <= 0.0:
		flashlight_on = false
		
	flashlight.visible = flashlight_on
	SignalBus.flashlight_toggled.emit(flashlight_on)
	AudioManager.play_sound("item_pickup", -12.0, 1.4)

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
		inventory_system.consume_equipped_item()
		AudioManager.play_sound("item_pickup", -4.0, 0.8)

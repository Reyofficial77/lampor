class_name RemotePlayer
extends Node3D

const ProfanityFilterScript = preload("res://scripts/systems/ProfanityFilter.gd")
const VerifiedBadgeScript = preload("res://scripts/ui/VerifiedBadge.gd")
const PLAYER_MODEL_PATH: String = "res://assets/models/player/ordinaryMan.fbx"
const PLAYER_TEXTURE_PATH: String = "res://assets/models/player/OrdinaryManTexture_1024x1024.png"

static var _model_cache: Dictionary = {}
static var _tex_cache: Texture2D = null

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

var user_id: String = ""
var username: String = "Player"
var is_host: bool = false
var is_verified: bool = false
var target_position: Vector3 = Vector3.ZERO
var target_rot_y: float = 0.0
var target_pitch: float = 0.0
var current_anim: String = "idle"
var flashlight_on: bool = false
var equipped_item: String = ""
var sanity: float = 100.0
var is_hiding: bool = false
var is_alive: bool = true
var mic_on: bool = false
var is_speaking: bool = false
var character_model: String = "male"

var visual_root: Node3D = null
var head_pivot: Node3D = null
var flashlight: SpotLight3D = null
var name_label: Label3D = null
var verified_sprite: Sprite3D = null
var voice_player_3d: AudioStreamPlayer3D = null
var voice_generator: AudioStreamGenerator = null
var _skeleton: Skeleton3D = null
var _anim_player: AnimationPlayer = null
var _initialized: bool = false
var _has_network_pose: bool = false
var _last_played_anim: String = ""
var _loaded_character_model: String = ""
var _using_legacy_fbx: bool = false
var _lod_check_elapsed: float = 0.0
const LOOPING_ANIMATIONS: Array[String] = ["idle", "walk", "sprint", "fall", "crouch", "abducted"]

var hand_item_holder: BoneAttachment3D = null
var hand_prop_pivot: Node3D = null
var hand_item_props: Dictionary = {}
var left_hand_item_holder: BoneAttachment3D = null
var left_hand_prop_pivot: Node3D = null
var left_hand_item_props: Dictionary = {}
var handheld_flashlight_lens: MeshInstance3D = null
var _base_hand_prop_scale: Vector3 = Vector3.ONE

var _visual_equipped_item: String = ""
var _remote_equip_prev_item: String = ""
var _remote_equip_progress: float = 1.0
var _remote_equip_duration: float = 0.64
var _remote_equip_swap_point: float = 0.42
var _remote_equip_grab_end: float = 0.56
var _remote_hold_blend: float = 0.0
var _remote_left_hold_blend: float = 0.0
var _remote_grip_blend: float = 0.0
var _remote_left_grip_blend: float = 0.0
var remote_equip_phase: String = "empty"

func _ready() -> void:
	add_to_group("remote_player")
	_ensure_initialized()
	visible = _has_network_pose
	if _has_network_pose:
		global_position = target_position

func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true

	head_pivot = Node3D.new()
	head_pivot.name = "HeadPivot"
	head_pivot.position = Vector3(0.0, 1.55, 0.0)
	add_child(head_pivot)

	flashlight = SpotLight3D.new()
	flashlight.name = "RemoteFlashlight"
	flashlight.position = Vector3(0.14, -0.08, -0.40)
	flashlight.light_color = Color(1.0, 0.96, 0.82)
	flashlight.light_energy = 4.0
	flashlight.spot_range = 30.0
	flashlight.spot_attenuation = 0.85
	flashlight.spot_angle = 44.0
	flashlight.shadow_enabled = false
	flashlight.set_meta("_base_shadow", false)
	flashlight.visible = false
	head_pivot.add_child(flashlight)

	name_label = Label3D.new()
	name_label.name = "NameLabel"
	name_label.position = Vector3(0.0, 2.15, 0.0)
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.no_depth_test = true
	name_label.pixel_size = 0.0045
	name_label.font_size = 32
	name_label.outline_size = 6
	name_label.outline_modulate = Color(0.04, 0.02, 0.02, 0.92)
	name_label.modulate = Color(0.97, 0.87, 0.85, 1.0)
	name_label.text = username
	add_child(name_label)

	verified_sprite = Sprite3D.new()
	verified_sprite.name = "VerifiedSprite"
	verified_sprite.position = Vector3(0.0, 2.34, 0.0)
	verified_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	verified_sprite.no_depth_test = true
	verified_sprite.pixel_size = 0.0042
	verified_sprite.texture = VerifiedBadgeScript.get_texture(48)
	verified_sprite.visible = is_verified
	add_child(verified_sprite)

	voice_player_3d = AudioStreamPlayer3D.new()
	voice_player_3d.name = "VoicePlayer3D"
	voice_player_3d.position = Vector3(0.0, 1.65, 0.0)
	voice_player_3d.unit_size = 14.0
	voice_player_3d.max_distance = 120.0
	voice_player_3d.bus = &"Master"
	add_child(voice_player_3d)
	if DisplayServer.get_name() != "headless":
		voice_generator = AudioStreamGenerator.new()
		voice_generator.mix_rate = 8000.0
		voice_generator.buffer_length = 1.5
		voice_player_3d.stream = voice_generator
		voice_player_3d.play()

	_setup_character_visuals()

func _ensure_looping_animations(anim_player: AnimationPlayer) -> void:
	if anim_player == null:
		return
	for anim_name: String in LOOPING_ANIMATIONS:
		if anim_player.has_animation(anim_name):
			var anim: Animation = anim_player.get_animation(anim_name)
			if anim != null:
				anim.loop_mode = Animation.LOOP_LINEAR

func _setup_character_visuals() -> void:
	character_model = SettingsManager.normalize_character_model(character_model)
	var model_path: String = SettingsManager.get_character_model_path(character_model)
	var loaded_model: Node3D = null
	_using_legacy_fbx = false
	if not model_path.is_empty() and ResourceLoader.exists(model_path):
		var packed: PackedScene = _model_cache.get(model_path, null) as PackedScene
		if packed == null:
			packed = ResourceLoader.load(model_path) as PackedScene
			if packed != null:
				_model_cache[model_path] = packed
		if packed != null:
			loaded_model = packed.instantiate() as Node3D
	if loaded_model == null and ResourceLoader.exists(PLAYER_MODEL_PATH):
		var fallback_packed: PackedScene = _model_cache.get(PLAYER_MODEL_PATH, null) as PackedScene
		if fallback_packed == null:
			fallback_packed = ResourceLoader.load(PLAYER_MODEL_PATH) as PackedScene
			if fallback_packed != null:
				_model_cache[PLAYER_MODEL_PATH] = fallback_packed
		if fallback_packed != null:
			loaded_model = fallback_packed.instantiate() as Node3D
			_using_legacy_fbx = true
	_loaded_character_model = character_model

	if loaded_model != null:
		visual_root = loaded_model
		visual_root.name = "CharacterModel"
		visual_root.scale = Vector3(0.93, 0.93, 0.93)
		visual_root.rotation.y = PI
		add_child(visual_root)

		for helper_name: String in ["Side", "Front"]:
			var helper: Node = visual_root.get_node_or_null(helper_name)
			if helper:
				helper.queue_free()

		_apply_player_materials(visual_root)
		_skeleton = visual_root.find_child("Skeleton3D", true, false) as Skeleton3D
		_anim_player = visual_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if (_anim_player == null or not _anim_player.has_animation("idle")) and _skeleton != null:
			if _anim_player != null:
				_anim_player.queue_free()
				_anim_player = null
			_build_remote_animations(_skeleton)
		_ensure_looping_animations(_anim_player)
		if _anim_player and not _anim_player.mixer_applied.is_connected(_apply_remote_hand_override):
			_anim_player.mixer_applied.connect(_apply_remote_hand_override)
		if _skeleton != null:
			_build_hand_item_holder(_skeleton)
		_last_played_anim = ""
		_play_anim("idle")
		if _anim_player:
			_anim_player.advance(0.0)
		_apply_remote_hand_override()
		return

	# Safe geometric fallback if both GLB and FBX fail to load
	visual_root = Node3D.new()
	visual_root.name = "FallbackVisual"
	add_child(visual_root)

	var body_mesh := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.35
	cap.height = 1.65
	body_mesh.mesh = cap
	body_mesh.position = Vector3(0.0, 0.85, 0.0)
	body_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fallback_mat := StandardMaterial3D.new()
	fallback_mat.albedo_color = Color(0.24, 0.22, 0.25)
	fallback_mat.roughness = 0.82
	fallback_mat.emission_enabled = true
	fallback_mat.emission = Color(0.18, 0.16, 0.18)
	fallback_mat.emission_energy_multiplier = 0.06
	body_mesh.material_override = fallback_mat
	visual_root.add_child(body_mesh)

func _apply_player_materials(root_node: Node) -> void:
	var tex: Texture2D = null
	if _using_legacy_fbx and ResourceLoader.exists(PLAYER_TEXTURE_PATH):
		tex = ResourceLoader.load(PLAYER_TEXTURE_PATH) as Texture2D

	for node: Node in root_node.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi == null:
			continue
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if not mi.mesh:
			continue
		for surf_idx: int in range(mi.mesh.get_surface_count()):
			var base_mat: Material = mi.get_active_material(surf_idx)
			var cloned: BaseMaterial3D = (base_mat.duplicate() as BaseMaterial3D) if base_mat is BaseMaterial3D else StandardMaterial3D.new()
			if _using_legacy_fbx and tex != null and (cloned.albedo_texture != null or mi.name == "Cube"):
				cloned.albedo_texture = tex
			cloned.roughness = 0.78
			cloned.emission_enabled = true
			if cloned.albedo_texture:
				cloned.emission_texture = cloned.albedo_texture
				cloned.emission = Color.WHITE
			else:
				cloned.emission = cloned.albedo_color
			cloned.emission_energy_multiplier = 0.045
			mi.set_surface_override_material(surf_idx, cloned)

func _find_bone_idx(skel: Skeleton3D, canonical_name: String) -> int:
	var actual: String = _resolve_bone_name(skel, canonical_name)
	return skel.find_bone(actual) if not actual.is_empty() else -1

func _set_skeleton_bone_rot(canonical_bone_name: String, rot_x_deg: float, rot_z_deg: float, rot_y_deg: float) -> void:
	if _skeleton == null:
		return
	var idx: int = _find_bone_idx(_skeleton, canonical_bone_name)
	if idx >= 0:
		_skeleton.set_bone_pose_rotation(idx, _bone_pose_quat(_skeleton, canonical_bone_name, rot_x_deg, rot_z_deg, rot_y_deg))

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

func _orient_hand_prop_pivot(pivot: Node3D, skel: Skeleton3D, bone_name: String, skel_to_model_basis: Basis, is_right: bool) -> void:
	if _using_legacy_fbx or bone_name == "hand.r" or bone_name == "hand.l":
		if bone_name == "hand.r":
			pivot.rotation_degrees = Vector3(0.0, 90.0, 0.0)
		elif bone_name == "hand.l":
			pivot.rotation_degrees = Vector3(0.0, -90.0, 0.0)
		return
	var bone_idx: int = skel.find_bone(bone_name)
	if bone_idx < 0:
		return
	var hand_model_basis: Basis = (skel_to_model_basis * skel.get_bone_global_rest(bone_idx).basis).orthonormalized()
	var desired_basis := Basis(Vector3(0.0, 0.0, -1.0), Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0)) if is_right else Basis(Vector3(0.0, 0.0, 1.0), Vector3(1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0))
	pivot.quaternion = (hand_model_basis.inverse() * desired_basis).orthonormalized().get_rotation_quaternion()

func _build_hand_item_holder(skel: Skeleton3D) -> void:
	if skel == null:
		return
	if hand_item_holder and is_instance_valid(hand_item_holder):
		hand_item_holder.queue_free()
	if left_hand_item_holder and is_instance_valid(left_hand_item_holder):
		left_hand_item_holder.queue_free()
	hand_item_props.clear()
	left_hand_item_props.clear()
	handheld_flashlight_lens = null

	var right_hand_bone: String = _resolve_bone_name(skel, "Hand.R")
	if right_hand_bone.is_empty():
		return

	hand_item_holder = BoneAttachment3D.new()
	hand_item_holder.name = "RemoteHandItemHolder"
	hand_item_holder.bone_name = right_hand_bone
	skel.add_child(hand_item_holder)

	var accum_scale: Vector3 = Vector3.ONE
	var skel_to_model_basis: Basis = Basis.IDENTITY
	var cursor: Node = skel
	while cursor != null and cursor != visual_root:
		if cursor is Node3D:
			var n3d: Node3D = cursor as Node3D
			var s: Vector3 = n3d.scale
			accum_scale = Vector3(accum_scale.x * s.x, accum_scale.y * s.y, accum_scale.z * s.z)
			skel_to_model_basis = n3d.transform.basis.orthonormalized() * skel_to_model_basis
		cursor = cursor.get_parent()
	var inv_scale := Vector3(
		1.0 / maxf(0.001, absf(accum_scale.x)),
		1.0 / maxf(0.001, absf(accum_scale.y)),
		1.0 / maxf(0.001, absf(accum_scale.z))
	)
	hand_prop_pivot = Node3D.new()
	hand_prop_pivot.name = "RemoteHandPropPivot"
	_base_hand_prop_scale = inv_scale
	hand_prop_pivot.scale = _base_hand_prop_scale
	_orient_hand_prop_pivot(hand_prop_pivot, skel, right_hand_bone, skel_to_model_basis, true)
	hand_item_holder.add_child(hand_prop_pivot)

	var left_hand_bone: String = _resolve_bone_name(skel, "Hand.L")
	if not left_hand_bone.is_empty():
		left_hand_item_holder = BoneAttachment3D.new()
		left_hand_item_holder.name = "RemoteLeftHandItemHolder"
		left_hand_item_holder.bone_name = left_hand_bone
		skel.add_child(left_hand_item_holder)

		left_hand_prop_pivot = Node3D.new()
		left_hand_prop_pivot.name = "RemoteLeftHandPropPivot"
		left_hand_prop_pivot.scale = inv_scale
		_orient_hand_prop_pivot(left_hand_prop_pivot, skel, left_hand_bone, skel_to_model_basis, false)
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
	_attach_suit_cyl(torch_root, "HandheldFlashlightBody", 0.019, 0.015, 0.150, Vector3(0.0, 0.125, -0.028), body_metal_mat)
	handheld_flashlight_lens = _attach_suit_cyl(torch_root, "HandheldFlashlightLens", 0.021, 0.020, 0.012, Vector3(0.0, 0.204, -0.028), lens_mat)

	# 2. Jamu
	var jamu_root := Node3D.new()
	jamu_root.name = "Prop_jamu"
	jamu_root.rotation_degrees = Vector3(-28.0, 0.0, -14.0)
	jamu_root.position = Vector3(0.004, 0.115, -0.030)
	hand_prop_pivot.add_child(jamu_root)
	hand_item_props["jamu"] = jamu_root
	_attach_suit_cyl(jamu_root, "JamuGlass", 0.016, 0.022, 0.105, Vector3.ZERO, _make_suit_mat(Color(0.2, 0.65, 0.28), 0.25, 0.1, 0.06))
	_attach_suit_cyl(jamu_root, "JamuCork", 0.011, 0.011, 0.022, Vector3(0.0, 0.060, 0.0), _make_suit_mat(Color(0.55, 0.36, 0.18), 0.85, 0.0))

	# 3. Minyak Tanah
	var minyak_root := Node3D.new()
	minyak_root.name = "Prop_minyak_tanah"
	minyak_root.rotation_degrees = Vector3(-26.0, 0.0, -12.0)
	minyak_root.position = Vector3(0.005, 0.118, -0.032)
	hand_prop_pivot.add_child(minyak_root)
	hand_item_props["minyak_tanah"] = minyak_root
	_attach_suit_box(minyak_root, "CanBody", Vector3(0.056, 0.088, 0.042), Vector3.ZERO, _make_suit_mat(Color(0.28, 0.24, 0.20), 0.5, 0.55))
	_attach_suit_box(minyak_root, "CanCap", Vector3(0.022, 0.016, 0.022), Vector3(0.012, 0.050, 0.0), _make_suit_mat(Color(0.85, 0.72, 0.2), 0.35, 0.6))
	_attach_suit_box(minyak_root, "Matchbox", Vector3(0.032, 0.022, 0.014), Vector3(-0.010, 0.046, 0.018), _make_suit_mat(Color(0.82, 0.22, 0.14), 0.8, 0.0, 0.06))

	# 4. Papan Paku
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
	_attach_suit_cyl(bat_root, "BatBody", 0.016, 0.016, 0.068, Vector3.ZERO, _make_suit_mat(Color(0.14, 0.14, 0.16), 0.4, 0.65))
	_attach_suit_cyl(bat_root, "BatTop", 0.016, 0.016, 0.018, Vector3(0.0, 0.032, 0.0), _make_suit_mat(Color(0.88, 0.68, 0.16), 0.3, 0.75, 0.06))

	# 6. Energy Drink
	var drink_root := Node3D.new()
	drink_root.name = "Prop_energy_drink"
	drink_root.rotation_degrees = Vector3(-26.0, 0.0, -10.0)
	drink_root.position = Vector3(0.0, 0.118, -0.026)
	hand_prop_pivot.add_child(drink_root)
	hand_item_props["energy_drink"] = drink_root
	var drink_blue: StandardMaterial3D = _make_suit_mat(Color(0.08, 0.44, 0.92), 0.24, 0.85, 0.08)
	var drink_neon: StandardMaterial3D = _make_suit_mat(Color(0.15, 0.95, 0.88), 0.22, 0.35, 0.35)
	var drink_silver: StandardMaterial3D = _make_suit_mat(Color(0.84, 0.87, 0.90), 0.22, 0.90, 0.04)
	_attach_suit_cyl(drink_root, "CanBody", 0.026, 0.026, 0.084, Vector3.ZERO, drink_blue)
	_attach_suit_cyl(drink_root, "NeonBandTop", 0.0268, 0.0268, 0.018, Vector3(0.0, 0.012, 0.0), drink_neon)
	_attach_suit_cyl(drink_root, "CanNeck", 0.021, 0.026, 0.013, Vector3(0.0, 0.048, 0.0), drink_silver)

	# 7. Kentongan
	var pemukul_root := Node3D.new()
	pemukul_root.name = "Prop_kentongan_pemukul"
	pemukul_root.position = Vector3(0.0, 0.125, -0.025)
	pemukul_root.rotation_degrees = Vector3(-48.0, 0.0, 28.0)
	hand_prop_pivot.add_child(pemukul_root)
	hand_item_props["kentongan"] = pemukul_root
	_attach_suit_cyl(pemukul_root, "BeaterShaft", 0.011, 0.010, 0.22, Vector3(0.0, 0.06, 0.0), _make_suit_mat(Color(0.45, 0.25, 0.11), 0.76, 0.04, 0.05))
	_attach_suit_sph(pemukul_root, "BeaterHead", 0.022, Vector3(0.0, 0.175, 0.0), _make_suit_mat(Color(0.30, 0.16, 0.07), 0.82, 0.02, 0.04))

	if left_hand_prop_pivot:
		var kentongan_root := Node3D.new()
		kentongan_root.name = "Prop_kentongan_body"
		kentongan_root.position = Vector3(0.0, 0.120, -0.028)
		kentongan_root.rotation_degrees = Vector3(-68.0, 12.0, -8.0)
		left_hand_prop_pivot.add_child(kentongan_root)
		left_hand_item_props["kentongan"] = kentongan_root
		_attach_suit_cyl(kentongan_root, "Body", 0.044, 0.048, 0.24, Vector3(0.0, 0.04, 0.0), _make_suit_mat(Color(0.60, 0.41, 0.17), 0.75, 0.02, 0.06))
		_attach_suit_box(kentongan_root, "Slit", Vector3(0.024, 0.15, 0.032), Vector3(-0.032, 0.04, 0.022), _make_suit_mat(Color(0.04, 0.02, 0.015), 0.98, 0.0, 0.0))

	_sync_remote_hand_prop_visibility()

func _snap_remote_equip_state(item_id: String) -> void:
	_visual_equipped_item = item_id
	_remote_equip_prev_item = item_id
	_remote_equip_progress = 1.0
	_remote_hold_blend = 1.0 if not item_id.is_empty() else 0.0
	_remote_left_hold_blend = 1.0 if item_id == "kentongan" else 0.0
	_remote_grip_blend = 1.0 if not item_id.is_empty() else 0.0
	_remote_left_grip_blend = 1.0 if item_id == "kentongan" else 0.0
	remote_equip_phase = "holding" if not item_id.is_empty() else "empty"
	_sync_remote_hand_prop_visibility()

func _start_remote_equip_transition(next_id: String) -> void:
	_remote_equip_prev_item = _visual_equipped_item
	equipped_item = next_id
	_remote_equip_progress = 0.0
	remote_equip_phase = "reaching_pocket"
	if _remote_equip_prev_item.is_empty() and not next_id.is_empty():
		_remote_equip_duration = 0.64
		_remote_equip_swap_point = 0.40
		_remote_equip_grab_end = 0.54
	elif not _remote_equip_prev_item.is_empty() and next_id.is_empty():
		_remote_equip_duration = 0.52
		_remote_equip_swap_point = 0.56
		_remote_equip_grab_end = 0.66
	else:
		_remote_equip_duration = 0.78
		_remote_equip_swap_point = 0.44
		_remote_equip_grab_end = 0.56
	_sync_remote_hand_prop_visibility()

func _sync_remote_hand_prop_visibility() -> void:
	var shown_id: String = _visual_equipped_item
	var show_prop: bool = is_alive and not is_hiding and not shown_id.is_empty()
	for prop_id: String in hand_item_props.keys():
		var prop_node: Node3D = hand_item_props[prop_id] as Node3D
		if prop_node:
			prop_node.visible = show_prop and (prop_id == shown_id)
	for prop_id: String in left_hand_item_props.keys():
		var prop_node: Node3D = left_hand_item_props[prop_id] as Node3D
		if prop_node:
			prop_node.visible = show_prop and (prop_id == shown_id)
	var scale_mult: float = 1.0
	if shown_id.is_empty():
		scale_mult = 0.001
	elif _remote_equip_progress < _remote_equip_swap_point:
		var t_stow: float = clampf(_remote_equip_progress / maxf(0.01, _remote_equip_swap_point), 0.0, 1.0)
		if t_stow >= 0.78:
			scale_mult = lerpf(1.0, 0.001, (t_stow - 0.78) / 0.22)
	elif _remote_equip_progress < _remote_equip_grab_end:
		var t_grab: float = clampf((_remote_equip_progress - _remote_equip_swap_point) / maxf(0.01, _remote_equip_grab_end - _remote_equip_swap_point), 0.0, 1.0)
		scale_mult = lerpf(0.25, 1.0, t_grab)
	var prop_scale: Vector3 = _base_hand_prop_scale * scale_mult
	if hand_prop_pivot and is_instance_valid(hand_prop_pivot):
		hand_prop_pivot.scale = prop_scale
	if left_hand_prop_pivot and is_instance_valid(left_hand_prop_pivot):
		left_hand_prop_pivot.scale = prop_scale
	if handheld_flashlight_lens and handheld_flashlight_lens.material_override is StandardMaterial3D:
		var lmat: StandardMaterial3D = handheld_flashlight_lens.material_override as StandardMaterial3D
		var lit: bool = show_prop and shown_id == "flashlight" and flashlight_on
		lmat.emission_enabled = lit
		lmat.emission_energy_multiplier = 1.6 if lit else 0.0

func _update_remote_equip_anim(delta: float) -> void:
	if _remote_equip_progress < 1.0:
		_remote_equip_progress = minf(1.0, _remote_equip_progress + (maxf(0.0, delta) / maxf(0.05, _remote_equip_duration)))
		if _remote_equip_progress >= _remote_equip_swap_point and _visual_equipped_item != equipped_item:
			_visual_equipped_item = equipped_item
			_sync_remote_hand_prop_visibility()
	if _remote_equip_progress < _remote_equip_swap_point:
		remote_equip_phase = "reaching_pocket"
	elif _remote_equip_progress < _remote_equip_grab_end:
		remote_equip_phase = "grabbing_pocket"
	elif _remote_equip_progress < 1.0:
		remote_equip_phase = "pulling_out"
	else:
		remote_equip_phase = "holding" if not _visual_equipped_item.is_empty() else "empty"

	_remote_hold_blend = move_toward(_remote_hold_blend, 1.0 if not _visual_equipped_item.is_empty() else 0.0, delta * 7.5)
	_remote_left_hold_blend = move_toward(_remote_left_hold_blend, 1.0 if _visual_equipped_item == "kentongan" else 0.0, delta * 6.5)

	var target_grip_r: float = 0.0
	var target_grip_l: float = 0.0
	match remote_equip_phase:
		"reaching_pocket":
			target_grip_r = 0.85 if not _remote_equip_prev_item.is_empty() else 0.10
			target_grip_l = 0.85 if _remote_equip_prev_item == "kentongan" else 0.0
		"grabbing_pocket":
			var grab_t: float = clampf((_remote_equip_progress - _remote_equip_swap_point) / maxf(0.01, _remote_equip_grab_end - _remote_equip_swap_point), 0.0, 1.0)
			target_grip_r = lerpf(0.25, 1.0, grab_t) if not _visual_equipped_item.is_empty() else 0.0
			target_grip_l = lerpf(0.25, 1.0, grab_t) if _visual_equipped_item == "kentongan" else 0.0
		"pulling_out", "holding":
			target_grip_r = 1.0 if not _visual_equipped_item.is_empty() else 0.0
			target_grip_l = 1.0 if _visual_equipped_item == "kentongan" else 0.0
	_remote_grip_blend = move_toward(_remote_grip_blend, target_grip_r, delta * 12.0)
	_remote_left_grip_blend = move_toward(_remote_left_grip_blend, target_grip_l, delta * 12.0)
	_sync_remote_hand_prop_visibility()

func _apply_remote_hand_override() -> void:
	if _skeleton == null or not is_alive or is_hiding:
		return
	var hb: float = clampf(_remote_hold_blend, 0.0, 1.0)
	var lb: float = clampf(_remote_left_hold_blend, 0.0, 1.0)
	var pocket_reach: float = 0.0
	var pocket_settle: float = 0.0
	var pocket_grab_tug: float = 0.0
	if _remote_equip_progress < 1.0:
		if _remote_equip_progress < _remote_equip_swap_point:
			var t_down: float = clampf(_remote_equip_progress / maxf(0.01, _remote_equip_swap_point), 0.0, 1.0)
			pocket_reach = t_down * t_down * (3.0 - 2.0 * t_down)
		elif _remote_equip_progress < _remote_equip_grab_end:
			pocket_reach = 1.0
			var t_grab: float = clampf((_remote_equip_progress - _remote_equip_swap_point) / maxf(0.01, _remote_equip_grab_end - _remote_equip_swap_point), 0.0, 1.0)
			pocket_grab_tug = sin(t_grab * PI) * 5.0
		else:
			var t_up: float = clampf((_remote_equip_progress - _remote_equip_grab_end) / maxf(0.01, 1.0 - _remote_equip_grab_end), 0.0, 1.0)
			var smooth_up: float = t_up * t_up * (3.0 - 2.0 * t_up)
			pocket_reach = 1.0 - smooth_up
			pocket_settle = sin(t_up * PI) * 8.5

	if hb > 0.001 or pocket_reach > 0.001 or absf(pocket_settle) > 0.01:
		var pitch_deg: float = clampf(rad_to_deg(target_pitch) * 0.85, -55.0, 35.0)
		var base_sh_r := Vector3(0.0, 0.0, 0.0)
		var base_up_r := Vector3(4.0, -74.0, 0.0)
		var base_lo_r := Vector3(-18.0, 0.0, -4.0)
		var base_ha_r := Vector3(0.0, 0.0, 0.0)

		var hold_sh_r := Vector3(-14.0, -6.0, 4.0)
		var hold_up_r := Vector3(-86.0 - pitch_deg, -56.0, 22.0)
		var hold_lo_r := Vector3(-22.0, -8.0, 0.0)
		var hold_ha_r := Vector3(-4.0, 0.0, -8.0)

		var target_sh_r: Vector3 = base_sh_r.lerp(hold_sh_r, hb)
		var target_up_r: Vector3 = base_up_r.lerp(hold_up_r, hb)
		var target_lo_r: Vector3 = base_lo_r.lerp(hold_lo_r, hb)
		var target_ha_r: Vector3 = base_ha_r.lerp(hold_ha_r, hb)

		if pocket_reach > 0.001 or absf(pocket_settle) > 0.01:
			var pocket_sh_r := Vector3(10.0, -6.0, -8.0)
			var pocket_up_r := Vector3(16.0 + pocket_grab_tug * 0.6, -70.0, -18.0)
			var pocket_lo_r := Vector3(-52.0 - pocket_grab_tug, -12.0, -24.0)
			var pocket_ha_r := Vector3(-16.0, -14.0, 20.0)
			target_sh_r = target_sh_r.lerp(pocket_sh_r, pocket_reach)
			target_up_r = target_up_r.lerp(pocket_up_r, pocket_reach) + Vector3(-pocket_settle, 0.0, pocket_settle * 0.45)
			target_lo_r = target_lo_r.lerp(pocket_lo_r, pocket_reach) + Vector3(-pocket_settle * 0.7, 0.0, 0.0)
			target_ha_r = target_ha_r.lerp(pocket_ha_r, pocket_reach) + Vector3(pocket_settle * 0.4, 0.0, 0.0)

		_set_skeleton_bone_rot("Shoulder.R", target_sh_r.x, target_sh_r.y, target_sh_r.z)
		_set_skeleton_bone_rot("UpperArm.R", target_up_r.x, target_up_r.y, target_up_r.z)
		_set_skeleton_bone_rot("LowerArm.R", target_lo_r.x, target_lo_r.y, target_lo_r.z)
		_set_skeleton_bone_rot("Hand.R", target_ha_r.x, target_ha_r.y, target_ha_r.z)

	var left_pocket: bool = (equipped_item == "kentongan") or (_remote_equip_prev_item == "kentongan")
	if lb > 0.001 or (left_pocket and (pocket_reach > 0.001 or absf(pocket_settle) > 0.01)):
		var pitch_deg_l: float = clampf(rad_to_deg(target_pitch) * 0.85, -55.0, 35.0)
		var base_sh_l := Vector3.ZERO
		var base_up_l := Vector3(4.0, 74.0, 0.0)
		var base_lo_l := Vector3(-18.0, 0.0, 4.0)
		var base_ha_l := Vector3.ZERO

		var kent_sh_l := Vector3(-14.0, 6.0, -4.0)
		var kent_up_l := Vector3(-86.0 - pitch_deg_l, 54.0, -22.0)
		var kent_lo_l := Vector3(-22.0, 8.0, 0.0)
		var kent_ha_l := Vector3(-4.0, 0.0, 8.0)

		var target_sh_l: Vector3 = base_sh_l.lerp(kent_sh_l, lb)
		var target_up_l: Vector3 = base_up_l.lerp(kent_up_l, lb)
		var target_lo_l: Vector3 = base_lo_l.lerp(kent_lo_l, lb)
		var target_ha_l: Vector3 = base_ha_l.lerp(kent_ha_l, lb)
		if left_pocket and (pocket_reach > 0.001 or absf(pocket_settle) > 0.01):
			var pocket_sh_l := Vector3(10.0, 6.0, 8.0)
			var pocket_up_l := Vector3(16.0 + pocket_grab_tug * 0.6, 70.0, 18.0)
			var pocket_lo_l := Vector3(-52.0 - pocket_grab_tug, 12.0, 24.0)
			var pocket_ha_l := Vector3(-16.0, 14.0, -20.0)
			target_sh_l = target_sh_l.lerp(pocket_sh_l, pocket_reach)
			target_up_l = target_up_l.lerp(pocket_up_l, pocket_reach) + Vector3(-pocket_settle, 0.0, -pocket_settle * 0.45)
			target_lo_l = target_lo_l.lerp(pocket_lo_l, pocket_reach) + Vector3(-pocket_settle * 0.7, 0.0, 0.0)
			target_ha_l = target_ha_l.lerp(pocket_ha_l, pocket_reach) + Vector3(pocket_settle * 0.4, 0.0, 0.0)
		_set_skeleton_bone_rot("Shoulder.L", target_sh_l.x, target_sh_l.y, target_sh_l.z)
		_set_skeleton_bone_rot("UpperArm.L", target_up_l.x, target_up_l.y, target_up_l.z)
		_set_skeleton_bone_rot("LowerArm.L", target_lo_l.x, target_lo_l.y, target_lo_l.z)
		_set_skeleton_bone_rot("Hand.L", target_ha_l.x, target_ha_l.y, target_ha_l.z)

	var grip_r: float = clampf(_remote_grip_blend, 0.0, 1.0)
	var grip_l: float = clampf(_remote_left_grip_blend, 0.0, 1.0)
	var curl_r: float = lerpf(14.0, 56.0, grip_r)
	var curl_l: float = lerpf(14.0, 56.0, grip_l)
	var finger_names: Array[String] = ["Index", "Middle", "Ring", "Pinky"]
	var finger_stagger: Array[float] = [0.92, 1.00, 1.06, 1.12]
	for fi: int in range(finger_names.size()):
		var fn: String = finger_names[fi]
		var stg: float = finger_stagger[fi]
		_set_skeleton_bone_rot(fn + "2.R", 0.0, -curl_r * 0.95 * stg, 0.0)
		_set_skeleton_bone_rot(fn + "3.R", 0.0, -curl_r * 1.18 * stg, 0.0)
		_set_skeleton_bone_rot(fn + "4.R", 0.0, -curl_r * 0.68 * stg, 0.0)
		_set_skeleton_bone_rot(fn + "2.L", 0.0, curl_l * 0.95 * stg, 0.0)
		_set_skeleton_bone_rot(fn + "3.L", 0.0, curl_l * 1.18 * stg, 0.0)
		_set_skeleton_bone_rot(fn + "4.L", 0.0, curl_l * 0.68 * stg, 0.0)
	_set_skeleton_bone_rot("Thumb2.R", lerpf(6.0, 18.0, grip_r), lerpf(-14.0, -40.0, grip_r), lerpf(-8.0, -22.0, grip_r))
	_set_skeleton_bone_rot("Thumb3.R", lerpf(4.0, 12.0, grip_r), lerpf(-10.0, -28.0, grip_r), 0.0)
	_set_skeleton_bone_rot("Thumb2.L", lerpf(6.0, 18.0, grip_l), lerpf(14.0, 40.0, grip_l), lerpf(8.0, 22.0, grip_l))
	_set_skeleton_bone_rot("Thumb3.L", lerpf(4.0, 12.0, grip_l), lerpf(10.0, 28.0, grip_l), 0.0)

func get_pocket_anim_state() -> Dictionary:
	return {
		"phase": remote_equip_phase,
		"progress": _remote_equip_progress,
		"equipped_item": equipped_item,
		"visual_equipped_item": _visual_equipped_item,
		"grip_blend": _remote_grip_blend,
		"left_grip_blend": _remote_left_grip_blend
	}

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

func _bone_pose_quat(skel: Skeleton3D, canonical_bone_name: String, rot_x_deg: float, rot_z_deg: float, rot_y_deg: float = 0.0) -> Quaternion:
	var actual_name: String = _resolve_bone_name(skel, canonical_bone_name)
	var idx: int = skel.find_bone(actual_name) if not actual_name.is_empty() else -1
	if idx < 0:
		return Quaternion.IDENTITY
	var rest_b: Basis = skel.get_bone_rest(idx).basis
	var g_rest_b: Basis = skel.get_bone_global_rest(idx).basis
	var inv_g: Basis = g_rest_b.inverse()
	var q: Quaternion = rest_b.get_rotation_quaternion()
	var use_gltf_yup_axes: bool = (not _using_legacy_fbx) and skel.find_bone("Hips") >= 0
	if not is_zero_approx(rot_y_deg):
		var raw_yaw: Vector3 = Vector3(0.0, 1.0, 0.0) if use_gltf_yup_axes else Vector3(0.0, 0.0, 1.0)
		var axis_yaw: Vector3 = (inv_g * raw_yaw).normalized()
		q = q * Quaternion(axis_yaw, deg_to_rad(rot_y_deg))
	if not is_zero_approx(rot_x_deg):
		var axis_swing: Vector3 = (inv_g * Vector3(1.0, 0.0, 0.0)).normalized()
		q = q * Quaternion(axis_swing, deg_to_rad(rot_x_deg))
	if not is_zero_approx(rot_z_deg):
		var raw_drop: Vector3 = Vector3(0.0, 0.0, -1.0) if use_gltf_yup_axes else Vector3(0.0, 1.0, 0.0)
		var axis_drop: Vector3 = (inv_g * raw_drop).normalized()
		q = q * Quaternion(axis_drop, deg_to_rad(rot_z_deg))
	return q.normalized()

func _add_anim(lib: AnimationLibrary, skel_path: String, skel: Skeleton3D, anim_name: String, length: float, loop_mode: Animation.LoopMode, keyframes: Dictionary) -> void:
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
			anim.rotation_track_insert_key(track_idx, t, _bone_pose_quat(skel, canonical_name, deg.x, deg.y, deg.z))
	lib.add_animation(anim_name, anim)

func _build_remote_animations(skel: Skeleton3D) -> void:
	_anim_player = AnimationPlayer.new()
	_anim_player.name = "AnimationPlayer"
	visual_root.add_child(_anim_player)

	var lib := AnimationLibrary.new()
	_anim_player.add_animation_library("", lib)
	var skel_path: String = String(visual_root.get_path_to(skel))

	_add_anim(lib, skel_path, skel, "idle", 2.0, Animation.LOOP_LINEAR, {
		"Torso": [[0.0, Vector3(-1.0, 0.0, 0.0)], [1.0, Vector3(-2.2, 0.0, 0.0)], [2.0, Vector3(-1.0, 0.0, 0.0)]],
		"UpperArm.L": [[0.0, Vector3(4.0, 75.0, 0.0)], [1.0, Vector3(2.0, 73.5, 0.0)], [2.0, Vector3(4.0, 75.0, 0.0)]],
		"LowerArm.L": [[0.0, Vector3(-18.0, 0.0, 4.0)], [1.0, Vector3(-22.0, 0.0, 5.0)], [2.0, Vector3(-18.0, 0.0, 4.0)]],
		"UpperArm.R": [[0.0, Vector3(4.0, -75.0, 0.0)], [1.0, Vector3(2.0, -73.5, 0.0)], [2.0, Vector3(4.0, -75.0, 0.0)]],
		"LowerArm.R": [[0.0, Vector3(-18.0, 0.0, -4.0)], [1.0, Vector3(-22.0, 0.0, -5.0)], [2.0, Vector3(-18.0, 0.0, -4.0)]]
	})

	_add_anim(lib, skel_path, skel, "walk", 0.88, Animation.LOOP_LINEAR, {
		"Torso": [[0.0, Vector3(3.5, 1.5, -3.5)], [0.44, Vector3(3.5, -1.5, 3.5)], [0.88, Vector3(3.5, 1.5, -3.5)]],
		"UpperArm.L": [[0.0, Vector3(20.0, 74.0, 0.0)], [0.44, Vector3(-22.0, 74.0, 0.0)], [0.88, Vector3(20.0, 74.0, 0.0)]],
		"UpperArm.R": [[0.0, Vector3(-22.0, -74.0, 0.0)], [0.44, Vector3(20.0, -74.0, 0.0)], [0.88, Vector3(-22.0, -74.0, 0.0)]],
		"UpperLeg.L": [[0.0, Vector3(-28.0, 0.0, 0.0)], [0.44, Vector3(22.0, 0.0, 0.0)], [0.88, Vector3(-28.0, 0.0, 0.0)]],
		"LowerLeg.L": [[0.0, Vector3(12.0, 0.0, 0.0)], [0.44, Vector3(36.0, 0.0, 0.0)], [0.88, Vector3(12.0, 0.0, 0.0)]],
		"UpperLeg.R": [[0.0, Vector3(22.0, 0.0, 0.0)], [0.44, Vector3(-28.0, 0.0, 0.0)], [0.88, Vector3(22.0, 0.0, 0.0)]],
		"LowerLeg.R": [[0.0, Vector3(36.0, 0.0, 0.0)], [0.44, Vector3(12.0, 0.0, 0.0)], [0.88, Vector3(36.0, 0.0, 0.0)]]
	})

	_add_anim(lib, skel_path, skel, "sprint", 0.56, Animation.LOOP_LINEAR, {
		"Torso": [[0.0, Vector3(9.0, 2.5, -6.0)], [0.28, Vector3(9.0, -2.5, 6.0)], [0.56, Vector3(9.0, 2.5, -6.0)]],
		"UpperArm.L": [[0.0, Vector3(36.0, 70.0, 0.0)], [0.28, Vector3(-40.0, 68.0, 0.0)], [0.56, Vector3(36.0, 70.0, 0.0)]],
		"LowerArm.L": [[0.0, Vector3(-56.0, 0.0, 8.0)], [0.28, Vector3(-76.0, 0.0, 12.0)], [0.56, Vector3(-56.0, 0.0, 8.0)]],
		"UpperArm.R": [[0.0, Vector3(-40.0, -68.0, 0.0)], [0.28, Vector3(36.0, -70.0, 0.0)], [0.56, Vector3(-40.0, -68.0, 0.0)]],
		"LowerArm.R": [[0.0, Vector3(-76.0, 0.0, -12.0)], [0.28, Vector3(-56.0, 0.0, -8.0)], [0.56, Vector3(-76.0, 0.0, -12.0)]],
		"UpperLeg.L": [[0.0, Vector3(-46.0, 0.0, 0.0)], [0.28, Vector3(38.0, 0.0, 0.0)], [0.56, Vector3(-46.0, 0.0, 0.0)]],
		"LowerLeg.L": [[0.0, Vector3(22.0, 0.0, 0.0)], [0.28, Vector3(58.0, 0.0, 0.0)], [0.56, Vector3(22.0, 0.0, 0.0)]],
		"UpperLeg.R": [[0.0, Vector3(38.0, 0.0, 0.0)], [0.28, Vector3(-46.0, 0.0, 0.0)], [0.56, Vector3(38.0, 0.0, 0.0)]],
		"LowerLeg.R": [[0.0, Vector3(58.0, 0.0, 0.0)], [0.28, Vector3(22.0, 0.0, 0.0)], [0.56, Vector3(58.0, 0.0, 0.0)]]
	})

	_add_anim(lib, skel_path, skel, "jump", 0.4, Animation.LOOP_NONE, {
		"Torso": [[0.0, Vector3(-6.0, 0.0, 0.0)], [0.4, Vector3(-8.0, 0.0, 0.0)]],
		"UpperLeg.L": [[0.0, Vector3(-24.0, 0.0, 0.0)], [0.4, Vector3(-28.0, 0.0, 0.0)]],
		"LowerLeg.L": [[0.0, Vector3(36.0, 0.0, 0.0)], [0.4, Vector3(44.0, 0.0, 0.0)]]
	})

	_add_anim(lib, skel_path, skel, "fall", 0.6, Animation.LOOP_LINEAR, {
		"Torso": [[0.0, Vector3(-5.0, 0.0, 0.0)], [0.6, Vector3(-5.0, 0.0, 0.0)]],
		"UpperArm.L": [[0.0, Vector3(-18.0, 52.0, 0.0)], [0.6, Vector3(-18.0, 52.0, 0.0)]],
		"UpperArm.R": [[0.0, Vector3(-18.0, -52.0, 0.0)], [0.6, Vector3(-18.0, -52.0, 0.0)]]
	})

	_add_anim(lib, skel_path, skel, "crouch", 1.0, Animation.LOOP_LINEAR, {
		"Hips": [[0.0, Vector3(-10.0, 0.0, 0.0)], [1.0, Vector3(-10.0, 0.0, 0.0)]],
		"Torso": [[0.0, Vector3(-18.0, 0.0, 0.0)], [1.0, Vector3(-18.0, 0.0, 0.0)]],
		"UpperLeg.L": [[0.0, Vector3(-48.0, 0.0, 0.0)], [1.0, Vector3(-48.0, 0.0, 0.0)]],
		"LowerLeg.L": [[0.0, Vector3(84.0, 0.0, 0.0)], [1.0, Vector3(84.0, 0.0, 0.0)]],
		"UpperLeg.R": [[0.0, Vector3(-48.0, 0.0, 0.0)], [1.0, Vector3(-48.0, 0.0, 0.0)]],
		"LowerLeg.R": [[0.0, Vector3(84.0, 0.0, 0.0)], [1.0, Vector3(84.0, 0.0, 0.0)]]
	})

	_add_anim(lib, skel_path, skel, "die", 0.7, Animation.LOOP_NONE, {
		"Hips": [[0.0, Vector3.ZERO], [0.7, Vector3(82.0, 0.0, 0.0)]],
		"Head": [[0.0, Vector3.ZERO], [0.7, Vector3(18.0, 0.0, 0.0)]]
	})

func _play_anim(anim_name: String) -> void:
	if _anim_player == null:
		return
	var target_anim: String = anim_name
	if not _anim_player.has_animation(target_anim):
		target_anim = "idle"
	if not _anim_player.has_animation(target_anim):
		return
	if _last_played_anim == target_anim and _anim_player.is_playing():
		return
	_last_played_anim = target_anim
	_anim_player.play(target_anim, 0.14)

func push_voice_frames(samples: PackedFloat32Array) -> void:
	if DisplayServer.get_name() == "headless" or samples.is_empty():
		return
	_ensure_initialized()
	if not is_instance_valid(voice_player_3d):
		return
	if not voice_player_3d.playing and voice_generator != null:
		voice_player_3d.play()
	var playback: AudioStreamGeneratorPlayback = voice_player_3d.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var max_push: int = mini(playback.get_frames_available(), samples.size())
	for i: int in range(max_push):
		var s: float = samples[i]
		playback.push_frame(Vector2(s, s))

func apply_network_state(data: Dictionary) -> void:
	_ensure_initialized()
	var raw_char: Variant = data.get("character", character_model)
	var incoming_char: String = SettingsManager.normalize_character_model(str(raw_char) if raw_char != null else character_model)
	if incoming_char != _loaded_character_model:
		character_model = incoming_char
		if hand_item_holder and is_instance_valid(hand_item_holder):
			hand_item_holder.queue_free()
		if left_hand_item_holder and is_instance_valid(left_hand_item_holder):
			left_hand_item_holder.queue_free()
		hand_item_holder = null
		hand_prop_pivot = null
		left_hand_item_holder = null
		left_hand_prop_pivot = null
		hand_item_props.clear()
		left_hand_item_props.clear()
		handheld_flashlight_lens = null
		if visual_root and is_instance_valid(visual_root):
			if visual_root.get_parent() == self:
				remove_child(visual_root)
			visual_root.queue_free()
		visual_root = null
		_skeleton = null
		_anim_player = null
		_last_played_anim = ""
		_setup_character_visuals()
	if data.has("userId"):
		user_id = str(data.get("userId", user_id))
	if data.has("username"):
		var uname: String = ProfanityFilterScript.censor(str(data.get("username", "")).strip_edges())
		if not uname.is_empty():
			username = uname
	if data.has("isHost"):
		is_host = bool(data.get("isHost", false))
	if data.has("isVerified"):
		is_verified = bool(data.get("isVerified", false))

	var has_pos_in_packet: bool = false
	var pos_raw: Variant = data.get("pos", null)
	if pos_raw is Array and (pos_raw as Array).size() >= 3:
		var arr: Array = pos_raw as Array
		target_position = Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
		has_pos_in_packet = true
	if data.has("rotY"):
		target_rot_y = float(data.get("rotY", target_rot_y))
	if data.has("pitch"):
		target_pitch = float(data.get("pitch", target_pitch))
	if data.has("anim"):
		current_anim = str(data.get("anim", "idle"))
	if data.has("flashlightOn"):
		flashlight_on = bool(data.get("flashlightOn", false))
	if data.has("equippedItem"):
		var next_eq: String = str(data.get("equippedItem", ""))
		if next_eq != equipped_item:
			if _has_network_pose:
				_start_remote_equip_transition(next_eq)
			else:
				equipped_item = next_eq
				_snap_remote_equip_state(next_eq)
	if data.has("sanity"):
		sanity = clampf(float(data.get("sanity", 100.0)), 0.0, 100.0)
	if data.has("isHiding"):
		is_hiding = bool(data.get("isHiding", false))
	if data.has("isAlive"):
		is_alive = bool(data.get("isAlive", true))
	if data.has("micOn"):
		mic_on = bool(data.get("micOn", false))
	if data.has("speaking"):
		is_speaking = bool(data.get("speaking", false))

	if has_pos_in_packet and not _has_network_pose:
		if is_inside_tree():
			global_position = target_position
		else:
			position = target_position
		rotation.y = target_rot_y
		if head_pivot:
			head_pivot.rotation.x = clampf(target_pitch, deg_to_rad(-80.0), deg_to_rad(80.0))
		_has_network_pose = true
		visible = true
		_snap_remote_equip_state(equipped_item)
	else:
		_sync_remote_hand_prop_visibility()

	if name_label:
		name_label.text = username + (" [HOST]" if is_host else "") + (" [MIC]" if is_speaking else "")
		if not is_alive:
			name_label.modulate = Color(0.83, 0.26, 0.24, 0.85)
		elif is_host:
			name_label.modulate = Color(0.92, 0.76, 0.45, 1.0)
		else:
			name_label.modulate = Color(0.97, 0.87, 0.85, 1.0)
	if verified_sprite:
		verified_sprite.visible = is_verified and (name_label == null or name_label.visible)

	if flashlight:
		var disable_fl: bool = _is_low_graphics()
		flashlight.visible = (not disable_fl) and flashlight_on and is_alive and not is_hiding
		flashlight.spot_range = 14.0 if SettingsManager.get_effective_graphics_quality() == "low" else 30.0

	var resolved_anim: String = current_anim
	if not is_alive:
		resolved_anim = "die"
	elif is_hiding:
		resolved_anim = "crouch"
	_play_anim(resolved_anim)

func _is_low_graphics() -> bool:
	return SettingsManager.get_effective_graphics_quality() == "low"

func _process(delta: float) -> void:
	if not _has_network_pose or not is_inside_tree():
		return
	_update_remote_equip_anim(delta)
	if _anim_player == null or not _anim_player.is_playing():
		_apply_remote_hand_override()
	if global_position.distance_squared_to(target_position) > 225.0:
		global_position = target_position
	else:
		global_position = global_position.lerp(target_position, minf(1.0, delta * 12.0))
	rotation.y = lerp_angle(rotation.y, target_rot_y, minf(1.0, delta * 14.0))
	if head_pivot:
		var clamped_pitch: float = clampf(target_pitch, deg_to_rad(-80.0), deg_to_rad(80.0))
		head_pivot.rotation.x = lerpf(head_pivot.rotation.x, clamped_pitch, minf(1.0, delta * 14.0))
	_lod_check_elapsed += delta
	if _lod_check_elapsed >= 0.45:
		_lod_check_elapsed = 0.0
		var show_tag: bool = true
		if name_label and is_instance_valid(GameManager.player_character) and GameManager.player_character is Node3D:
			var d_sq: float = global_position.distance_squared_to((GameManager.player_character as Node3D).global_position)
			show_tag = d_sq <= 784.0
			name_label.visible = show_tag
		if verified_sprite:
			verified_sprite.visible = is_verified and show_tag
		if flashlight:
			var disable_fl: bool = _is_low_graphics()
			if disable_fl and flashlight.visible:
				flashlight.visible = false
			elif not disable_fl:
				flashlight.visible = flashlight_on and is_alive and not is_hiding

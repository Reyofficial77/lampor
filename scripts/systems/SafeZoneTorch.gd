class_name SafeZoneTorch
extends StaticBody3D

@export var torch_id: int = 1
@export var is_lit: bool = false

@onready var light: OmniLight3D = $TorchLight
@onready var flame_mesh: MeshInstance3D = $TorchFlame
@onready var safe_area: Area3D = $SafeZoneArea

func _ready() -> void:
	collision_layer = 1
	collision_mask = 2
	safe_area.body_entered.connect(_on_safe_area_entered)
	safe_area.body_exited.connect(_on_safe_area_exited)
	_update_visuals()

func _update_visuals() -> void:
	light.visible = is_lit
	flame_mesh.visible = is_lit

const LocScript = preload("res://scripts/systems/Loc.gd")

func get_interaction_prompt(player: Node) -> String:
	var k: String = SettingsManager.get_action_key_text("interact")
	if is_lit:
		return LocScript.pick("Obor Penolak Bala (Menyala & Melindungi)", "Repellent Torch (Lit & Protecting)")
		
	var inv: InventorySystem = player.get_node_or_null("InventorySystem")
	if inv and inv.has_item_id("minyak_tanah"):
		return LocScript.pick("[%s] Nyalakan Obor Penolak Bala (Gunakan Minyak Tanah)" % k, "[%s] Light Repellent Torch (Use Kerosene)" % k)
	else:
		return LocScript.pick("Obor Padam (Butuh Minyak Tanah & Korek Api)", "Unlit Torch (Requires Kerosene & Matches)")

func _get_scene_node_path() -> String:
	var root: Node = get_tree().current_scene
	if root and root.is_ancestor_of(self):
		return str(root.get_path_to(self))
	return name

func interact(player: Node) -> void:
	if is_lit:
		return
		
	var inv: InventorySystem = player.get_node_or_null("InventorySystem")
	if inv and inv.has_item_id("minyak_tanah"):
		inv.consume_item_by_id("minyak_tanah")
		is_lit = true
		GameManager.torches_lit += 1
		_update_visuals()
		AudioManager.play_sound("lighter_ignite", 2.0)
		SignalBus.torch_lit.emit(torch_id, GameManager.torches_lit, GameManager.REQUIRED_TORCHES)
		if MultiplayerManager.is_online_session:
			MultiplayerManager.push_event("torch_lit", {
				"torch_id": torch_id,
				"node_path": _get_scene_node_path(),
				"is_lit": true
			})
		
		# Pemain berdiri dekat obor (jangkauan interaksi < radius area), jadi langsung aman
		var pc: PlayerController = player as PlayerController
		if pc and pc.sanity_system:
			pc.sanity_system.set_safe_source(self, true)

func apply_network_lit(lit: bool) -> void:
	if is_lit == lit:
		return
	is_lit = lit
	_update_visuals()
	if is_lit:
		AudioManager.play_sound("lighter_ignite", 0.0)
	if safe_area:
		for body: Node3D in safe_area.get_overlapping_bodies():
			if body is PlayerController:
				var pc: PlayerController = body as PlayerController
				if pc.sanity_system:
					pc.sanity_system.set_safe_source(self, is_lit)

func _on_safe_area_entered(body: Node3D) -> void:
	if is_lit and body is PlayerController:
		var pc: PlayerController = body as PlayerController
		if pc.sanity_system:
			pc.sanity_system.set_safe_source(self, true)

func _on_safe_area_exited(body: Node3D) -> void:
	if body is PlayerController:
		var pc: PlayerController = body as PlayerController
		if pc.sanity_system:
			pc.sanity_system.set_safe_source(self, false)

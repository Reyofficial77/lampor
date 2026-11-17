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

func get_interaction_prompt(player: Node) -> String:
	if is_lit:
		return "Obor Penolak Bala (Menyala & Melindungi)"
		
	var inv: InventorySystem = player.get_node_or_null("InventorySystem")
	if inv and inv.has_item_id("minyak_tanah"):
		return "[E] Nyalakan Obor Penolak Bala (Gunakan Minyak Tanah)"
	else:
		return "Obor Padam (Butuh Minyak Tanah & Korek Api)"

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
		
		# Pemain berdiri dekat obor (jangkauan interaksi < radius area), jadi langsung aman
		var pc: PlayerController = player as PlayerController
		if pc and pc.sanity_system:
			pc.sanity_system.set_safe_source(self, true)

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

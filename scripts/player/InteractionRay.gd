class_name InteractionRay
extends RayCast3D

var current_target: Node = null
var prompt_text: String = ""

signal interaction_prompt_changed(text: String)

func _physics_process(_delta: float) -> void:
	if not is_colliding():
		current_target = null
		_update_prompt()
		return

	var collider: Node = get_collider()
	if collider != current_target:
		current_target = collider

	_update_prompt()

func _get_held_item_prompt(player: Node) -> String:
	if not player:
		return ""
	var inv: InventorySystem = player.get_node_or_null("InventorySystem") as InventorySystem
	if not inv:
		return ""
	var eq: Dictionary = inv.get_equipped_item()
	var item_id: String = str(eq.get("id", ""))
	if item_id == "jamu":
		return "[E] Minum Jamu Tolak Bala"
	elif item_id == "baterai":
		return "[E] Isi Ulang Baterai Senter"
	return ""

func _is_target_actionable(target: Node, player: Node) -> bool:
	if not target or not is_instance_valid(target) or not target.has_method("interact"):
		return false
	if target is SafeZoneTorch:
		var torch := target as SafeZoneTorch
		if torch.is_lit:
			return false
		var inv: InventorySystem = player.get_node_or_null("InventorySystem") as InventorySystem if player else null
		return inv != null and inv.has_item_id("minyak_tanah")
	if target is RitualAltar:
		if GameManager.furnace_burning or GameManager.current_act == GameManager.Act.BABAK_1:
			return false
		return GameManager.get_ritual_item_count() >= GameManager.TOTAL_RITUAL_ITEMS
	if target is Door:
		var door := target as Door
		if door.is_barricaded and not door.is_player_inside(player):
			return false
		return true
	return true

func _update_prompt() -> void:
	var player: Node = owner
	var new_prompt: String = ""
	if current_target and is_instance_valid(current_target) and current_target.has_method("get_interaction_prompt"):
		new_prompt = current_target.get_interaction_prompt(player)
		if not _is_target_actionable(current_target, player):
			var held_prompt: String = _get_held_item_prompt(player)
			if not held_prompt.is_empty():
				new_prompt = held_prompt + "  ·  " + new_prompt
	else:
		new_prompt = _get_held_item_prompt(player)

	if new_prompt != prompt_text:
		prompt_text = new_prompt
		interaction_prompt_changed.emit(prompt_text)

func trigger_interaction(player: Node) -> bool:
	if current_target and is_instance_valid(current_target) and current_target.has_method("interact"):
		if _is_target_actionable(current_target, player):
			current_target.interact(player)
			_update_prompt()
			return true
		# Tetap panggil interact untuk feedback suara (mis. altar belum lengkap) bila tidak memegang item pakai
		var held_prompt: String = _get_held_item_prompt(player)
		if held_prompt.is_empty():
			current_target.interact(player)
			_update_prompt()
			return true
	return false

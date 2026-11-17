class_name InteractionRay
extends RayCast3D

var current_target: Node = null
var prompt_text: String = ""

signal interaction_prompt_changed(text: String)

func _physics_process(_delta: float) -> void:
	if not is_colliding():
		if current_target != null or prompt_text != "":
			current_target = null
			prompt_text = ""
			interaction_prompt_changed.emit("")
		return
		
	var collider: Node = get_collider()
	if collider != current_target:
		current_target = collider
	
	_update_prompt()

func _update_prompt() -> void:
	if current_target and is_instance_valid(current_target) and current_target.has_method("get_interaction_prompt"):
		var player: Node = owner
		var new_prompt: String = current_target.get_interaction_prompt(player)
		if new_prompt != prompt_text:
			prompt_text = new_prompt
			interaction_prompt_changed.emit(prompt_text)
	else:
		if prompt_text != "":
			prompt_text = ""
			interaction_prompt_changed.emit("")

func trigger_interaction(player: Node) -> void:
	if current_target and is_instance_valid(current_target) and current_target.has_method("interact"):
		current_target.interact(player)
		_update_prompt()

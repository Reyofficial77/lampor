class_name VillageHouse
extends Node3D

@onready var door: Door = $Door
@onready var interior_area: Area3D = $InteriorArea

func _ready() -> void:
	if interior_area:
		interior_area.body_entered.connect(_on_interior_entered)
		interior_area.body_exited.connect(_on_interior_exited)

func is_door_secure() -> bool:
	if not door:
		return true
	return door.is_barricaded or not door.is_open

func _on_interior_entered(body: Node3D) -> void:
	if body is PlayerController:
		var pc: PlayerController = body as PlayerController
		pc.is_inside_house = true
		pc.current_house = self

func _on_interior_exited(body: Node3D) -> void:
	if body is PlayerController:
		var pc: PlayerController = body as PlayerController
		if pc.current_house == self:
			pc.is_inside_house = false
			pc.current_house = null

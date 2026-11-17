class_name GameOverScreen
extends Control

@onready var retry_btn: Button = $VBoxContainer/RetryButton
@onready var menu_btn: Button = $VBoxContainer/MenuButton
@onready var reason_label: Label = $TitleBox/ReasonLabel

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	retry_btn.pressed.connect(func() -> void: GameManager.start_new_game(GameManager.selected_difficulty))
	menu_btn.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn"))

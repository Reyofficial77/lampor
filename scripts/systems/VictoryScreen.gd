class_name VictoryScreen
extends Control

@onready var replay_btn: Button = $VBoxContainer/ReplayButton
@onready var menu_btn: Button = $VBoxContainer/MenuButton

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	replay_btn.pressed.connect(func() -> void:
		AudioManager.stop_ending_audio()
		GameManager.start_new_game(GameManager.selected_difficulty)
	)
	menu_btn.pressed.connect(func() -> void:
		AudioManager.stop_ending_audio()
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
	)

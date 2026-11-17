class_name MainMenu
extends Control

@onready var start_btn: Button = $VBoxContainer/StartButton
@onready var guide_btn: Button = $VBoxContainer/GuideButton
@onready var exit_btn: Button = $VBoxContainer/ExitButton
@onready var guide_panel: PanelContainer = $GuidePanel
@onready var close_guide_btn: Button = $GuidePanel/MarginContainer/VBoxContainer/CloseGuideButton

# Difficulty Panel
@onready var difficulty_panel: PanelContainer = $DifficultyPanel
@onready var easy_btn: Button = $DifficultyPanel/Margin/VBox/EasyButton
@onready var normal_btn: Button = $DifficultyPanel/Margin/VBox/NormalButton
@onready var hard_btn: Button = $DifficultyPanel/Margin/VBox/HardButton
@onready var nightmare_btn: Button = $DifficultyPanel/Margin/VBox/NightmareButton
@onready var nightmare_lock_label: Label = $DifficultyPanel/Margin/VBox/NightmareLockLabel
@onready var cancel_diff_btn: Button = $DifficultyPanel/Margin/VBox/CancelDiffButton
@onready var wins_label: Label = $TitleBox/WinsLabel

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameManager.current_state = GameManager.GameState.MENU
	
	start_btn.pressed.connect(_on_start_pressed)
	guide_btn.pressed.connect(func() -> void: guide_panel.visible = true)
	close_guide_btn.pressed.connect(func() -> void: guide_panel.visible = false)
	exit_btn.pressed.connect(func() -> void: get_tree().quit())
	
	# Difficulty buttons
	easy_btn.pressed.connect(func() -> void: _start_with_difficulty(GameManager.Difficulty.EASY))
	normal_btn.pressed.connect(func() -> void: _start_with_difficulty(GameManager.Difficulty.NORMAL))
	hard_btn.pressed.connect(func() -> void: _start_with_difficulty(GameManager.Difficulty.HARD))
	nightmare_btn.pressed.connect(func() -> void: _start_with_difficulty(GameManager.Difficulty.NIGHTMARE))
	cancel_diff_btn.pressed.connect(func() -> void: difficulty_panel.visible = false)
	
	guide_panel.visible = false
	difficulty_panel.visible = false
	
	_update_wins_display()

func _on_start_pressed() -> void:
	difficulty_panel.visible = true
	_update_nightmare_status()

func _update_nightmare_status() -> void:
	var unlocked: bool = GameManager.is_nightmare_unlocked()
	nightmare_btn.disabled = not unlocked
	if unlocked:
		nightmare_lock_label.text = "💀 Nightmare TERBUKA! Selamat mencoba... jika berani."
		nightmare_lock_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 0.9))
	else:
		var remaining: int = 5 - GameManager.total_wins
		nightmare_lock_label.text = "🔒 Nightmare terbuka setelah %d kemenangan lagi (%d/5)" % [remaining, GameManager.total_wins]
		nightmare_lock_label.add_theme_color_override("font_color", Color(0.6, 0.3, 0.3, 0.8))

func _update_wins_display() -> void:
	if GameManager.total_wins > 0:
		wins_label.text = "🏆 Total Kemenangan: %d" % GameManager.total_wins
	else:
		wins_label.text = ""

func _start_with_difficulty(diff: GameManager.Difficulty) -> void:
	difficulty_panel.visible = false
	GameManager.start_new_game(diff)

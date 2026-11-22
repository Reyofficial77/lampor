class_name GameOverScreen
extends Control

const LocScript = preload("res://scripts/systems/Loc.gd")

@onready var background: ColorRect = $Background
@onready var retry_btn: Button = $VBoxContainer/RetryButton
@onready var menu_btn: Button = $VBoxContainer/MenuButton
@onready var reason_label: Label = $TitleBox/ReasonLabel
@onready var title_label: Label = $TitleBox/Title
@onready var title_box: VBoxContainer = $TitleBox
@onready var buttons_box: VBoxContainer = $VBoxContainer

var backdrop: Control
var anim_time: float = 0.0
var content_vbox: VBoxContainer
var rule_line: ColorRect
var reward_label: Label

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_horror_layout()

	reason_label.text = GameManager.last_death_reason if GameManager.last_death_reason != "" else LocScript.pick("Malam ini belum menjadi milikmu.", "The night claimed you before dawn.")
	var lower_reason: String = reason_label.text.to_lower()
	if lower_reason.contains("keranda") or lower_reason.contains("ditarik") or lower_reason.contains("coffin") or lower_reason.contains("dragged"):
		title_label.text = LocScript.pick("DITELAN KERANDA LAMPOR", "SWALLOWED BY LAMPOR'S COFFIN")
	elif lower_reason.contains("fajar") or lower_reason.contains("05.00") or lower_reason.contains("05:00") or lower_reason.contains("dawn"):
		title_label.text = LocScript.pick("FAJAR TAK MENYELAMATKANMU", "DAWN DID NOT SAVE YOU")
	else:
		title_label.text = LocScript.pick("JIWAMU TELAH HANCUR", "YOUR SANITY SHATTERED")

	reward_label.text = LocScript.pick("+%d Koin Emas  ·  Total: %d" % [GameManager.last_run_coin_reward, GameManager.coins], "+%d Gold Coins  ·  Total: %d" % [GameManager.last_run_coin_reward, GameManager.coins])

	retry_btn.pressed.connect(func() -> void: GameManager.start_new_game(GameManager.selected_difficulty))
	menu_btn.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn"))

	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()
	HorrorTheme.animate_surface_enter(content_vbox)
	retry_btn.call_deferred("grab_focus")

func _process(delta: float) -> void:
	anim_time += delta
	if backdrop:
		backdrop.queue_redraw()

func _build_horror_layout() -> void:
	if background:
		background.color = Color("100606")

	backdrop = Control.new()
	backdrop.name = "DeathBackdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.draw.connect(_draw_death_backdrop)
	add_child(backdrop)
	move_child(backdrop, 1)

	var center := CenterContainer.new()
	center.name = "DeathCenter"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(center)

	content_vbox = VBoxContainer.new()
	content_vbox.name = "DeathContent"
	content_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_vbox.add_theme_constant_override("separation", 16)
	center.add_child(content_vbox)

	title_box.reparent(content_vbox)
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	title_box.add_theme_constant_override("separation", 12)
	HorrorTheme.style_label(title_label, "display", HorrorTheme.ACCENT, 34)
	title_label.add_theme_constant_override("outline_size", 6)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	rule_line = ColorRect.new()
	rule_line.color = Color(HorrorTheme.ACCENT.r, HorrorTheme.ACCENT.g, HorrorTheme.ACCENT.b, 0.50)
	rule_line.custom_minimum_size = Vector2(110.0, 1.0)
	rule_line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rule_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_box.add_child(rule_line)
	title_box.move_child(rule_line, 1)

	HorrorTheme.style_label(reason_label, "body-lg", HorrorTheme.ON_SURFACE, 16)
	reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	reward_label = Label.new()
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	HorrorTheme.style_label(reward_label, "mono-sm", HorrorTheme.RELIC_BRASS, 13)
	content_vbox.add_child(reward_label)

	buttons_box.reparent(content_vbox)
	buttons_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buttons_box.add_theme_constant_override("separation", 10)
	retry_btn.text = LocScript.pick("COBA LAGI", "TRY AGAIN")
	retry_btn.custom_minimum_size = Vector2(240.0, 44.0)
	HorrorTheme.style_button(retry_btn, "primary", 14, true)
	menu_btn.text = LocScript.pick("KEMBALI KE MENU", "BACK TO MENU")
	menu_btn.custom_minimum_size = Vector2(240.0, 44.0)
	HorrorTheme.style_button(menu_btn, "ghost", 13, true)

func _draw_death_backdrop() -> void:
	if not backdrop:
		return
	var s: Vector2 = backdrop.size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	var c: Vector2 = s * 0.5
	var pulse: float = 0.5 + 0.5 * sin(anim_time * 1.4)

	# Kabut gelap bernuansa darah redup di balik teks
	backdrop.draw_circle(c, minf(s.x, s.y) * 0.52, Color(HorrorTheme.SECONDARY_CONTAINER.r, HorrorTheme.SECONDARY_CONTAINER.g, HorrorTheme.SECONDARY_CONTAINER.b, 0.14 + pulse * 0.04))
	backdrop.draw_circle(c, minf(s.x, s.y) * 0.30, Color(HorrorTheme.PRIMARY_CONTAINER.r, HorrorTheme.PRIMARY_CONTAINER.g, HorrorTheme.PRIMARY_CONTAINER.b, 0.09 + pulse * 0.03))

	# Siluet keranda samar di kegelapan atas
	var ky: float = s.y * 0.14 + sin(anim_time * 1.1) * 4.0
	var kw: float = minf(s.x, s.y) * 0.13
	var kh: float = kw * 0.42
	var keranda := PackedVector2Array([
		Vector2(c.x - kw * 0.5, ky + kh * 0.35),
		Vector2(c.x - kw * 0.5, ky - kh * 0.10),
		Vector2(c.x - kw * 0.36, ky - kh * 0.45),
		Vector2(c.x + kw * 0.36, ky - kh * 0.45),
		Vector2(c.x + kw * 0.5, ky - kh * 0.10),
		Vector2(c.x + kw * 0.5, ky + kh * 0.35)
	])
	backdrop.draw_colored_polygon(keranda, Color(HorrorTheme.KERANDA_GLOW.r, HorrorTheme.KERANDA_GLOW.g, HorrorTheme.KERANDA_GLOW.b, 0.16))
	var eye_a: float = 0.35 + 0.35 * sin(anim_time * 2.8)
	backdrop.draw_circle(Vector2(c.x - kw * 0.10, ky - kh * 0.02), 2.4, Color(HorrorTheme.ACCENT.r, HorrorTheme.ACCENT.g, HorrorTheme.ACCENT.b, eye_a))
	backdrop.draw_circle(Vector2(c.x + kw * 0.10, ky - kh * 0.02), 2.4, Color(HorrorTheme.ACCENT.r, HorrorTheme.ACCENT.g, HorrorTheme.ACCENT.b, eye_a))

func _apply_layout() -> void:
	var view_size: Vector2 = get_viewport_rect().size
	var compact: bool = view_size.x < 700.0
	var short_screen: bool = view_size.y < 520.0
	var max_text_w: float = clampf(view_size.x - 48.0, 260.0, 520.0)

	if content_vbox:
		content_vbox.add_theme_constant_override("separation", 10 if short_screen else 16)
	title_label.custom_minimum_size.x = max_text_w
	reason_label.custom_minimum_size.x = max_text_w
	title_label.add_theme_font_size_override("font_size", 22 if short_screen else (26 if compact else 36))
	reason_label.add_theme_font_size_override("font_size", 14 if compact or short_screen else 16)

	var btn_w: float = minf(260.0, max_text_w)
	retry_btn.custom_minimum_size = Vector2(btn_w, 44.0)
	menu_btn.custom_minimum_size = Vector2(btn_w, 44.0)

	if backdrop:
		backdrop.queue_redraw()

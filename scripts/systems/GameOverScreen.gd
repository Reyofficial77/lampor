class_name GameOverScreen
extends Control

@onready var background: ColorRect = $Background
@onready var retry_btn: Button = $VBoxContainer/RetryButton
@onready var menu_btn: Button = $VBoxContainer/MenuButton
@onready var reason_label: Label = $TitleBox/ReasonLabel
@onready var title_label: Label = $TitleBox/Title
@onready var title_box: VBoxContainer = $TitleBox
@onready var buttons_box: VBoxContainer = $VBoxContainer

var backdrop: Control
var anim_time: float = 0.0
var card_panel: PanelContainer
var card_margin: MarginContainer
var card_vbox: VBoxContainer
var eyebrow_label: Label
var reward_label: Label

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_horror_layout()

	reason_label.text = GameManager.last_death_reason if GameManager.last_death_reason != "" else "Malam ini belum menjadi milikmu."
	var lower_reason: String = reason_label.text.to_lower()
	if lower_reason.contains("keranda") or lower_reason.contains("ditarik"):
		title_label.text = "DITELAN KERANDA LAMPOR"
	elif lower_reason.contains("fajar"):
		title_label.text = "FAJAR TAK MENYELAMATKANMU"
	else:
		title_label.text = "JIWAMU TELAH HANCUR"

	reward_label.text = "+%d Koin Emas  ·  Total: %d" % [GameManager.last_run_coin_reward, GameManager.coins]

	retry_btn.pressed.connect(func() -> void: GameManager.start_new_game(GameManager.selected_difficulty))
	menu_btn.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn"))

	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()
	HorrorTheme.animate_surface_enter(card_panel)

func _process(delta: float) -> void:
	anim_time += delta
	if backdrop:
		backdrop.queue_redraw()
	if title_label:
		var pulse: float = 0.5 + 0.5 * sin(anim_time * 2.4)
		title_label.modulate = Color(1.0, lerpf(0.84, 1.0, pulse), lerpf(0.84, 1.0, pulse), 1.0)

func _build_horror_layout() -> void:
	if background:
		background.color = HorrorTheme.BACKGROUND

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

	card_panel = PanelContainer.new()
	card_panel.name = "DeathRelicCard"
	var p_style := HorrorTheme.make_panel_style(
		Color(HorrorTheme.SURFACE.r, HorrorTheme.SURFACE.g, HorrorTheme.SURFACE.b, 0.94),
		HorrorTheme.OUTLINE_VARIANT,
		4,
		2
	)
	card_panel.add_theme_stylebox_override("panel", p_style)
	HorrorTheme.attach_corner_ornaments(card_panel, HorrorTheme.ACCENT, 14.0, 2.0, 5.0, true)
	center.add_child(card_panel)

	card_margin = MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", 32)
	card_margin.add_theme_constant_override("margin_right", 32)
	card_margin.add_theme_constant_override("margin_top", 28)
	card_margin.add_theme_constant_override("margin_bottom", 28)
	card_panel.add_child(card_margin)

	card_vbox = VBoxContainer.new()
	card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card_vbox.add_theme_constant_override("separation", 14)
	card_margin.add_child(card_vbox)

	eyebrow_label = Label.new()
	eyebrow_label.text = "TAKDIR MALAM JAHANAM"
	eyebrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	HorrorTheme.style_label(eyebrow_label, "label-lg", HorrorTheme.ACCENT, 12)
	card_vbox.add_child(eyebrow_label)

	title_box.reparent(card_vbox)
	title_box.add_theme_constant_override("separation", 12)
	HorrorTheme.style_label(title_label, "display", HorrorTheme.PRIMARY, 34)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	HorrorTheme.style_label(reason_label, "body-lg", HorrorTheme.ON_SURFACE, 16)
	reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	card_vbox.add_child(HorrorTheme.create_ritual_divider("◆", HorrorTheme.ACCENT))

	var reward_chip := PanelContainer.new()
	reward_chip.add_theme_stylebox_override(
		"panel",
		HorrorTheme.make_chip_style(HorrorTheme.SURFACE_LOW, HorrorTheme.OUTLINE_VARIANT, 3, 14, 8)
	)
	card_vbox.add_child(reward_chip)

	reward_label = Label.new()
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	HorrorTheme.style_label(reward_label, "mono-sm", HorrorTheme.RELIC_BRASS, 13)
	reward_chip.add_child(reward_label)

	buttons_box.reparent(card_vbox)
	buttons_box.add_theme_constant_override("separation", 10)
	retry_btn.text = "COBA LAGI"
	retry_btn.custom_minimum_size = Vector2(0, 46)
	HorrorTheme.style_button(retry_btn, "primary", 14, true)
	menu_btn.text = "KEMBALI KE MENU"
	menu_btn.custom_minimum_size = Vector2(0, 44)
	HorrorTheme.style_button(menu_btn, "secondary", 14, true)

func _draw_death_backdrop() -> void:
	if not backdrop:
		return
	var s: Vector2 = backdrop.size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	var c: Vector2 = s * 0.5
	var pulse: float = 0.5 + 0.5 * sin(anim_time * 1.8)

	# Kabut & aura merah darah di belakang panel
	backdrop.draw_circle(c, minf(s.x, s.y) * 0.55, Color(HorrorTheme.SECONDARY_CONTAINER.r, HorrorTheme.SECONDARY_CONTAINER.g, HorrorTheme.SECONDARY_CONTAINER.b, 0.22 + pulse * 0.08))
	backdrop.draw_circle(c, minf(s.x, s.y) * 0.34, Color(HorrorTheme.PRIMARY_CONTAINER.r, HorrorTheme.PRIMARY_CONTAINER.g, HorrorTheme.PRIMARY_CONTAINER.b, 0.14 + pulse * 0.06))

	# Siluet keranda samar di atas
	var ky: float = s.y * 0.13 + sin(anim_time * 1.2) * 5.0
	var kw: float = minf(s.x, s.y) * 0.14
	var kh: float = kw * 0.42
	var keranda := PackedVector2Array([
		Vector2(c.x - kw * 0.5, ky + kh * 0.35),
		Vector2(c.x - kw * 0.5, ky - kh * 0.10),
		Vector2(c.x - kw * 0.36, ky - kh * 0.45),
		Vector2(c.x + kw * 0.36, ky - kh * 0.45),
		Vector2(c.x + kw * 0.5, ky - kh * 0.10),
		Vector2(c.x + kw * 0.5, ky + kh * 0.35)
	])
	backdrop.draw_colored_polygon(keranda, Color(HorrorTheme.KERANDA_GLOW.r, HorrorTheme.KERANDA_GLOW.g, HorrorTheme.KERANDA_GLOW.b, 0.22))
	var eye_a: float = 0.45 + 0.45 * sin(anim_time * 3.2)
	backdrop.draw_circle(Vector2(c.x - kw * 0.10, ky - kh * 0.02), 2.8, Color(HorrorTheme.ACCENT.r, HorrorTheme.ACCENT.g, HorrorTheme.ACCENT.b, eye_a))
	backdrop.draw_circle(Vector2(c.x + kw * 0.10, ky - kh * 0.02), 2.8, Color(HorrorTheme.ACCENT.r, HorrorTheme.ACCENT.g, HorrorTheme.ACCENT.b, eye_a))

	# Abu & percikan darah melayang
	for i: int in range(18):
		var seed_f: float = float(i) * 41.3
		var px: float = fmod(seed_f * 23.0 + sin(anim_time * 0.7 + seed_f) * 24.0, s.x)
		var py: float = fmod(anim_time * (14.0 + float(i % 4) * 5.0) + seed_f * 17.0, s.y)
		backdrop.draw_circle(Vector2(px, py), 1.6 + float(i % 2), Color(HorrorTheme.ACCENT.r, HorrorTheme.ACCENT.g, HorrorTheme.ACCENT.b, 0.24))

	# Vignette scrim di tepi layar
	var scrim := Color(HorrorTheme.SCRIM.r, HorrorTheme.SCRIM.g, HorrorTheme.SCRIM.b, 0.72)
	backdrop.draw_rect(Rect2(0.0, 0.0, s.x, 36.0), scrim)
	backdrop.draw_rect(Rect2(0.0, s.y - 36.0, s.x, 36.0), scrim)
	backdrop.draw_rect(Rect2(0.0, 0.0, 32.0, s.y), scrim)
	backdrop.draw_rect(Rect2(s.x - 32.0, 0.0, 32.0, s.y), scrim)
	backdrop.draw_rect(Rect2(14.0, 14.0, s.x - 28.0, s.y - 28.0), Color(HorrorTheme.OUTLINE_VARIANT.r, HorrorTheme.OUTLINE_VARIANT.g, HorrorTheme.OUTLINE_VARIANT.b, 0.35), false, 1.0)

func _apply_layout() -> void:
	var view_size: Vector2 = get_viewport_rect().size
	var compact: bool = view_size.x < 700.0
	var short_screen: bool = view_size.y < 520.0
	var card_w: float = clampf(view_size.x - 32.0, 280.0, 480.0)
	var h_pad: int = 18 if compact else 24
	var v_pad: int = 14 if short_screen else 20
	if card_margin:
		card_margin.add_theme_constant_override("margin_left", h_pad)
		card_margin.add_theme_constant_override("margin_right", h_pad)
		card_margin.add_theme_constant_override("margin_top", v_pad)
		card_margin.add_theme_constant_override("margin_bottom", v_pad)
	var inner_w: float = maxf(220.0, card_w - float(h_pad * 2))
	title_label.custom_minimum_size.x = inner_w
	reason_label.custom_minimum_size.x = inner_w
	title_label.add_theme_font_size_override("font_size", 20 if compact else 28)
	reason_label.add_theme_font_size_override("font_size", 13 if compact else 15)
	if card_panel:
		card_panel.custom_minimum_size = Vector2(card_w, 0.0)
		card_panel.reset_size()
	if backdrop:
		backdrop.queue_redraw()

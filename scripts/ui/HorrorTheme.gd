class_name HorrorTheme
extends RefCounted

# Sistem desain horor folklor Indonesia untuk LAMPOR: Malam Jahanam (berbasis DESIGN.md)

const DISPLAY_FONT: Font = preload("res://assets/fonts/HorrorTitle.ttf")

# Palet warna resmi DESIGN.md
const PRIMARY: Color = Color("ffb4ac")
const ON_PRIMARY: Color = Color("690006")
const PRIMARY_CONTAINER: Color = Color("9e1b1b")
const ON_PRIMARY_CONTAINER: Color = Color("ffedea")

const SECONDARY: Color = Color("e1bebb")
const ON_SECONDARY: Color = Color("3c2d2b")
const SECONDARY_CONTAINER: Color = Color("5a1a17")
const ON_SECONDARY_CONTAINER: Color = Color("ffdad6")

const ACCENT: Color = Color("d4433c")
const ON_ACCENT: Color = Color("060606")

const BACKGROUND: Color = Color("170b0a")
const ON_BACKGROUND: Color = Color("f7ddda")

const SURFACE: Color = Color("1d100f")
const SURFACE_DIM: Color = Color("120908")
const SURFACE_BRIGHT: Color = Color("352625")
const SURFACE_LOWEST: Color = Color("140a09")
const SURFACE_LOW: Color = Color("261817")
const SURFACE_CONTAINER: Color = Color("2a1c1b")
const SURFACE_HIGH: Color = Color("352625")
const SURFACE_HIGHEST: Color = Color("41312f")

const ON_SURFACE: Color = Color("f7ddda")
const ON_SURFACE_VARIANT: Color = Color("d5bdbb")
const OUTLINE: Color = Color("8d706d")
const OUTLINE_VARIANT: Color = Color("59413e")

const ERROR: Color = Color("ffb4ab")
const ON_ERROR: Color = Color("690005")
const SCRIM: Color = Color("0a0505")

# Aksen sekunder terkendali untuk relik/koin/obor/status positif
const RELIC_BRASS: Color = Color("c99a5b")
const SUCCESS_SAGE: Color = Color("86ba8c")
const KERANDA_GLOW: Color = Color("1f5e3b")

static var _serif_base: SystemFont = null
static var _serif_variants: Dictionary = {}
static var _body_font: SystemFont = null
static var _mono_font: SystemFont = null
static var _slider_grabber_tex: Texture2D = null
static var _slider_grabber_hi_tex: Texture2D = null

static func get_serif_font(letter_spacing: int = 2, bold: bool = true) -> Font:
	if _serif_base == null:
		_serif_base = SystemFont.new()
		_serif_base.font_names = PackedStringArray([
			"Cinzel",
			"Palatino Linotype",
			"Book Antiqua",
			"Georgia",
			"Times New Roman",
			"serif"
		])
		_serif_base.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	var key: String = "%d_%s" % [letter_spacing, "1" if bold else "0"]
	if _serif_variants.has(key):
		return _serif_variants[key] as Font
	var fv := FontVariation.new()
	fv.base_font = _serif_base
	fv.spacing_glyph = letter_spacing
	if bold:
		fv.variation_embolden = 0.22
	_serif_variants[key] = fv
	return fv

static func get_body_font() -> Font:
	if _body_font == null:
		_body_font = SystemFont.new()
		_body_font.font_names = PackedStringArray([
			"Proza Libre",
			"Segoe UI",
			"Roboto",
			"Noto Sans",
			"sans-serif"
		])
		_body_font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return _body_font

static func get_mono_font() -> Font:
	if _mono_font == null:
		_mono_font = SystemFont.new()
		_mono_font.font_names = PackedStringArray([
			"Source Code Pro",
			"JetBrains Mono",
			"Consolas",
			"Courier New",
			"monospace"
		])
		_mono_font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return _mono_font

static func make_panel_style(
	bg_color: Color = SURFACE,
	border_color: Color = OUTLINE_VARIANT,
	radius: int = 4,
	border_width: int = 1,
	pad_h: int = 0,
	pad_v: int = 0
) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg_color
	s.border_color = border_color
	s.set_border_width_all(border_width)
	s.border_width_bottom = border_width + 1
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(SCRIM.r, SCRIM.g, SCRIM.b, 0.72)
	s.shadow_size = 10
	if pad_h > 0 or pad_v > 0:
		s.content_margin_left = float(pad_h)
		s.content_margin_right = float(pad_h)
		s.content_margin_top = float(pad_v)
		s.content_margin_bottom = float(pad_v)
	return s

static func make_chip_style(
	bg_color: Color = SURFACE_LOWEST,
	border_color: Color = OUTLINE_VARIANT,
	radius: int = 2,
	pad_h: int = 10,
	pad_v: int = 5
) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg_color
	s.border_color = border_color
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = float(pad_h)
	s.content_margin_right = float(pad_h)
	s.content_margin_top = float(pad_v)
	s.content_margin_bottom = float(pad_v)
	return s

static func make_divider(color: Color = OUTLINE_VARIANT, thickness: int = 1) -> HSeparator:
	var sep := HSeparator.new()
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.content_margin_top = float(thickness)
	s.content_margin_bottom = 0.0
	sep.add_theme_stylebox_override("separator", s)
	return sep

static func style_label(
	lbl: Label,
	role: String = "body-md",
	color: Color = ON_SURFACE,
	font_size_override: int = -1
) -> void:
	if not lbl:
		return
	var fsize: int = 14
	match role:
		"display":
			lbl.add_theme_font_override("font", DISPLAY_FONT)
			fsize = 44
			lbl.add_theme_color_override("font_outline_color", SCRIM)
			lbl.add_theme_constant_override("outline_size", 10)
		"headline-lg":
			lbl.add_theme_font_override("font", get_serif_font(2, true))
			fsize = 26
			lbl.add_theme_color_override("font_outline_color", SCRIM)
			lbl.add_theme_constant_override("outline_size", 4)
		"headline-md":
			lbl.add_theme_font_override("font", get_serif_font(2, true))
			fsize = 20
			lbl.add_theme_color_override("font_outline_color", SCRIM)
			lbl.add_theme_constant_override("outline_size", 3)
		"title-lg":
			lbl.add_theme_font_override("font", get_serif_font(1, true))
			fsize = 17
			lbl.add_theme_color_override("font_outline_color", SCRIM)
			lbl.add_theme_constant_override("outline_size", 2)
		"label-lg":
			lbl.add_theme_font_override("font", get_serif_font(2, true))
			fsize = 13
		"label-sm":
			lbl.add_theme_font_override("font", get_body_font())
			fsize = 12
		"mono-sm":
			lbl.add_theme_font_override("font", get_mono_font())
			fsize = 12
		"body-lg":
			lbl.add_theme_font_override("font", get_body_font())
			fsize = 16
		_:
			lbl.add_theme_font_override("font", get_body_font())
			fsize = 14
	lbl.add_theme_font_size_override("font_size", font_size_override if font_size_override > 0 else fsize)
	lbl.add_theme_color_override("font_color", color)

static func style_button(btn: Button, variant: String = "secondary", font_size: int = 14, use_serif: bool = true) -> void:
	if not btn:
		return
	var normal := StyleBoxFlat.new()
	normal.set_corner_radius_all(3)
	normal.border_width_left = 3
	normal.border_width_right = 1
	normal.border_width_top = 1
	normal.border_width_bottom = 2
	normal.content_margin_left = 14.0
	normal.content_margin_right = 14.0
	normal.content_margin_top = 8.0
	normal.content_margin_bottom = 8.0
	normal.shadow_color = Color(SCRIM.r, SCRIM.g, SCRIM.b, 0.55)
	normal.shadow_size = 4

	var hover := normal.duplicate() as StyleBoxFlat
	var pressed := normal.duplicate() as StyleBoxFlat
	var disabled := normal.duplicate() as StyleBoxFlat

	var txt_normal: Color = ON_SURFACE
	var txt_hover: Color = ON_PRIMARY_CONTAINER
	var txt_pressed: Color = ON_PRIMARY_CONTAINER

	match variant:
		"primary":
			normal.bg_color = Color(PRIMARY_CONTAINER.r, PRIMARY_CONTAINER.g, PRIMARY_CONTAINER.b, 0.96)
			normal.border_color = ACCENT
			hover.bg_color = Color("b62525")
			hover.border_color = PRIMARY
			pressed.bg_color = Color("7b1212")
			pressed.border_color = PRIMARY
			txt_normal = ON_PRIMARY_CONTAINER
			txt_hover = Color.WHITE
		"danger":
			normal.bg_color = Color(SECONDARY_CONTAINER.r, SECONDARY_CONTAINER.g, SECONDARY_CONTAINER.b, 0.94)
			normal.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.85)
			hover.bg_color = PRIMARY_CONTAINER
			hover.border_color = PRIMARY
			pressed.bg_color = Color("731414")
			pressed.border_color = PRIMARY
			txt_normal = ON_SECONDARY_CONTAINER
			txt_hover = ON_PRIMARY_CONTAINER
		"ghost":
			normal.bg_color = Color(SURFACE_LOW.r, SURFACE_LOW.g, SURFACE_LOW.b, 0.85)
			normal.border_color = OUTLINE_VARIANT
			normal.border_width_left = 1
			hover.bg_color = SURFACE_HIGH
			hover.border_color = OUTLINE
			pressed.bg_color = SURFACE_CONTAINER
			pressed.border_color = ACCENT
			txt_normal = ON_SURFACE_VARIANT
			txt_hover = ON_SURFACE
		_: # secondary
			normal.bg_color = Color(SURFACE_CONTAINER.r, SURFACE_CONTAINER.g, SURFACE_CONTAINER.b, 0.96)
			normal.border_color = OUTLINE_VARIANT
			hover.bg_color = SURFACE_HIGH
			hover.border_color = ACCENT
			pressed.bg_color = SECONDARY_CONTAINER
			pressed.border_color = PRIMARY
			txt_normal = ON_SURFACE
			txt_hover = ON_PRIMARY_CONTAINER

	disabled.bg_color = Color(SURFACE_DIM.r, SURFACE_DIM.g, SURFACE_DIM.b, 0.82)
	disabled.border_color = Color(OUTLINE_VARIANT.r, OUTLINE_VARIANT.g, OUTLINE_VARIANT.b, 0.45)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_stylebox_override("disabled", disabled)

	btn.add_theme_color_override("font_color", txt_normal)
	btn.add_theme_color_override("font_hover_color", txt_hover)
	btn.add_theme_color_override("font_pressed_color", txt_pressed)
	btn.add_theme_color_override("font_focus_color", txt_hover)
	btn.add_theme_color_override("font_disabled_color", Color(OUTLINE.r, OUTLINE.g, OUTLINE.b, 0.55))
	btn.add_theme_font_size_override("font_size", font_size)
	if use_serif:
		btn.add_theme_font_override("font", get_serif_font(2, true))
	else:
		btn.add_theme_font_override("font", get_body_font())

static func style_line_edit(le: LineEdit) -> void:
	if not le:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = SURFACE_LOWEST
	normal.border_color = OUTLINE_VARIANT
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	normal.content_margin_left = 10.0
	normal.content_margin_right = 10.0
	normal.content_margin_top = 8.0
	normal.content_margin_bottom = 8.0

	var focus := normal.duplicate() as StyleBoxFlat
	focus.bg_color = SURFACE_LOW
	focus.border_color = ACCENT
	focus.set_border_width_all(2)

	le.add_theme_stylebox_override("normal", normal)
	le.add_theme_stylebox_override("focus", focus)
	le.add_theme_color_override("font_color", ON_SURFACE)
	le.add_theme_color_override("font_placeholder_color", OUTLINE)
	le.add_theme_color_override("caret_color", PRIMARY)
	le.add_theme_color_override("selection_color", Color(PRIMARY_CONTAINER.r, PRIMARY_CONTAINER.g, PRIMARY_CONTAINER.b, 0.65))
	le.add_theme_font_override("font", get_mono_font())
	le.add_theme_font_size_override("font_size", 13)

static func style_option_button(opt: OptionButton) -> void:
	if not opt:
		return
	style_button(opt, "secondary", 13, false)
	var popup: PopupMenu = opt.get_popup()
	if popup:
		var panel := make_panel_style(SURFACE, OUTLINE_VARIANT, 3, 1, 6, 6)
		var hover := StyleBoxFlat.new()
		hover.bg_color = PRIMARY_CONTAINER
		hover.set_corner_radius_all(2)
		popup.add_theme_stylebox_override("panel", panel)
		popup.add_theme_stylebox_override("hover", hover)
		popup.add_theme_color_override("font_color", ON_SURFACE)
		popup.add_theme_color_override("font_hover_color", ON_PRIMARY_CONTAINER)
		popup.add_theme_font_override("font", get_body_font())
		popup.add_theme_font_size_override("font_size", 13)

static func style_check_button(chk: CheckButton) -> void:
	if not chk:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = SURFACE_LOW
	normal.border_color = OUTLINE_VARIANT
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	normal.content_margin_left = 10.0
	normal.content_margin_right = 10.0
	normal.content_margin_top = 6.0
	normal.content_margin_bottom = 6.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = SURFACE_HIGH
	hover.border_color = ACCENT
	chk.add_theme_stylebox_override("normal", normal)
	chk.add_theme_stylebox_override("hover", hover)
	chk.add_theme_stylebox_override("pressed", hover)
	chk.add_theme_stylebox_override("focus", hover)
	chk.add_theme_stylebox_override("hover_pressed", hover)
	chk.add_theme_color_override("font_color", ON_SURFACE)
	chk.add_theme_color_override("font_hover_color", ON_PRIMARY_CONTAINER)
	chk.add_theme_color_override("font_pressed_color", PRIMARY)
	chk.add_theme_color_override("font_hover_pressed_color", PRIMARY)
	chk.add_theme_font_override("font", get_body_font())
	chk.add_theme_font_size_override("font_size", 13)

static func _ensure_slider_textures() -> void:
	if _slider_grabber_tex != null:
		return
	_slider_grabber_tex = _build_grabber_texture(SURFACE_CONTAINER, ACCENT)
	_slider_grabber_hi_tex = _build_grabber_texture(PRIMARY_CONTAINER, PRIMARY)

static func _build_grabber_texture(fill_col: Color, rim_col: Color) -> Texture2D:
	var w: int = 14
	var h: int = 18
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			var is_border: bool = (x == 0 or x == w - 1 or y == 0 or y == h - 1)
			var is_notch: bool = ((x == 0 or x == w - 1) and (y == 0 or y == h - 1))
			if is_notch:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif is_border:
				img.set_pixel(x, y, rim_col)
			elif x == w / 2 or x == w / 2 - 1:
				if y >= 4 and y <= h - 5:
					img.set_pixel(x, y, rim_col)
				else:
					img.set_pixel(x, y, fill_col)
			else:
				img.set_pixel(x, y, fill_col)
	return ImageTexture.create_from_image(img)

static func style_slider(slider: HSlider) -> void:
	if not slider:
		return
	_ensure_slider_textures()
	var rail := StyleBoxFlat.new()
	rail.bg_color = SURFACE_LOWEST
	rail.border_color = OUTLINE_VARIANT
	rail.set_border_width_all(1)
	rail.set_corner_radius_all(2)
	rail.content_margin_top = 4.0
	rail.content_margin_bottom = 4.0

	var area := StyleBoxFlat.new()
	area.bg_color = PRIMARY_CONTAINER
	area.set_corner_radius_all(2)
	area.content_margin_top = 4.0
	area.content_margin_bottom = 4.0

	var area_hi := area.duplicate() as StyleBoxFlat
	area_hi.bg_color = ACCENT

	slider.add_theme_stylebox_override("slider", rail)
	slider.add_theme_stylebox_override("grabber_area", area)
	slider.add_theme_stylebox_override("grabber_area_highlight", area_hi)
	slider.add_theme_icon_override("grabber", _slider_grabber_tex)
	slider.add_theme_icon_override("grabber_highlight", _slider_grabber_hi_tex)

static func style_scroll_container(sc: ScrollContainer) -> void:
	if not sc:
		return
	var vbar: VScrollBar = sc.get_v_scroll_bar()
	if not vbar:
		return
	var track := StyleBoxFlat.new()
	track.bg_color = SURFACE_LOWEST
	track.border_color = Color(OUTLINE_VARIANT.r, OUTLINE_VARIANT.g, OUTLINE_VARIANT.b, 0.45)
	track.set_border_width_all(1)
	track.set_corner_radius_all(2)
	track.content_margin_left = 4.0
	track.content_margin_right = 4.0

	var grab := StyleBoxFlat.new()
	grab.bg_color = OUTLINE_VARIANT
	grab.set_corner_radius_all(2)

	var grab_hi := StyleBoxFlat.new()
	grab_hi.bg_color = ACCENT
	grab_hi.set_corner_radius_all(2)

	var grab_press := StyleBoxFlat.new()
	grab_press.bg_color = PRIMARY
	grab_press.set_corner_radius_all(2)

	vbar.add_theme_stylebox_override("scroll", track)
	vbar.add_theme_stylebox_override("grabber", grab)
	vbar.add_theme_stylebox_override("grabber_highlight", grab_hi)
	vbar.add_theme_stylebox_override("grabber_pressed", grab_press)

static func attach_corner_ornaments(
	target: Control,
	color: Color = ACCENT,
	arm_len: float = 10.0,
	thickness: float = 1.5,
	inset: float = 4.0,
	draw_top_diamond: bool = false
) -> void:
	if not target:
		return
	target.set_meta("ornament_color", color)
	target.set_meta("ornament_arm", arm_len)
	target.set_meta("ornament_thick", thickness)
	target.set_meta("ornament_inset", inset)
	target.set_meta("ornament_diamond", draw_top_diamond)
	if not target.has_meta("ornament_connected"):
		target.set_meta("ornament_connected", true)
		target.draw.connect(_on_draw_ornaments.bind(target))
	target.queue_redraw()

static func _on_draw_ornaments(target: Control) -> void:
	if not is_instance_valid(target):
		return
	var s: Vector2 = target.size
	if s.x < 16.0 or s.y < 16.0:
		return
	var col: Color = target.get_meta("ornament_color", ACCENT)
	var arm: float = minf(float(target.get_meta("ornament_arm", 10.0)), minf(s.x, s.y) * 0.28)
	var thick: float = float(target.get_meta("ornament_thick", 1.5))
	var ins: float = float(target.get_meta("ornament_inset", 4.0))
	var draw_diamond: bool = bool(target.get_meta("ornament_diamond", false))

	var tl := Vector2(ins, ins)
	var tr := Vector2(s.x - ins, ins)
	var bl := Vector2(ins, s.y - ins)
	var br := Vector2(s.x - ins, s.y - ins)

	target.draw_line(tl, tl + Vector2(arm, 0.0), col, thick)
	target.draw_line(tl, tl + Vector2(0.0, arm), col, thick)
	target.draw_line(tr, tr + Vector2(-arm, 0.0), col, thick)
	target.draw_line(tr, tr + Vector2(0.0, arm), col, thick)
	target.draw_line(bl, bl + Vector2(arm, 0.0), col, thick)
	target.draw_line(bl, bl + Vector2(0.0, -arm), col, thick)
	target.draw_line(br, br + Vector2(-arm, 0.0), col, thick)
	target.draw_line(br, br + Vector2(0.0, -arm), col, thick)

	if draw_diamond:
		var cx: float = s.x * 0.5
		var cy: float = ins
		var d: float = 4.0
		var pts := PackedVector2Array([
			Vector2(cx, cy - d * 0.5),
			Vector2(cx + d, cy + d * 0.5),
			Vector2(cx, cy + d * 1.5),
			Vector2(cx - d, cy + d * 0.5)
		])
		target.draw_colored_polygon(pts, col)

static func create_ritual_divider(label_text: String = "◆", color: Color = ACCENT) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var left_line := make_divider(Color(color.r, color.g, color.b, 0.55), 1)
	left_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(left_line)

	var crest := Label.new()
	crest.text = label_text
	crest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	style_label(crest, "label-lg", color, 11)
	row.add_child(crest)

	var right_line := make_divider(Color(color.r, color.g, color.b, 0.55), 1)
	right_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(right_line)
	return row

static func animate_surface_enter(control: Control) -> void:
	if not is_instance_valid(control):
		return
	control.modulate.a = 0.0
	var tw := control.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(control, "modulate:a", 1.0, 0.30)

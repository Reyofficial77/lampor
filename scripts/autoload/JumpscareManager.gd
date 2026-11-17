extends CanvasLayer

# Jumpscare layar penuh: wajah keranda muncul mendadak + suara + getar (mobile).
# Dipicu oleh SignalBus.lampor_jumpscare dan tampil di atas semua scene.

const DURATION: float = 1.8
const FADE_TIME: float = 0.25

var root: Control
var bg: ColorRect
var face: Control
var flash: ColorRect
var is_playing: bool = false
var play_time: float = 0.0
var eye_glow: float = 1.0

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()
	root.visible = false
	SignalBus.lampor_jumpscare.connect(play_jumpscare)

func _build_overlay() -> void:
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	bg = ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	face = Control.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.draw.connect(_draw_face)
	root.add_child(face)
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	flash = ColorRect.new()
	flash.color = Color(1.0, 1.0, 1.0, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func play_jumpscare() -> void:
	if is_playing:
		return
	is_playing = true
	play_time = 0.0
	root.modulate.a = 1.0
	root.visible = true
	AudioManager.play_sound('jumpscare', 8.0)
	# Getar di HP (tidak berpengaruh di desktop)
	Input.vibrate_handheld(700)

func _finish() -> void:
	is_playing = false
	root.visible = false
	root.modulate.a = 1.0

func _process(delta: float) -> void:
	if not is_playing:
		return
	play_time += delta

	# Wajah membesar mendadak lalu pelan-pelan mendekat
	var zoom: float = 1.5 + (play_time - 0.12) * 0.25
	if play_time < 0.12:
		zoom = lerpf(0.4, 1.5, play_time / 0.12)
	var shake: float = 6.0 + 24.0 * (1.0 - play_time / DURATION)
	face.pivot_offset = face.size * 0.5
	face.scale = Vector2(zoom, zoom)
	face.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake
	eye_glow = 0.7 + 0.3 * sin(play_time * 60.0)
	face.queue_redraw()

	# Kilatan putih di awal, lalu merah yang memudar
	if play_time < 0.06:
		flash.color = Color(1.0, 1.0, 1.0, 0.9)
	else:
		flash.color = Color(0.8, 0.0, 0.0, maxf(0.0, 0.6 - play_time * 1.2))

	# Memudar ke hitam di akhir
	var fade_start: float = DURATION - FADE_TIME
	if play_time > fade_start:
		root.modulate.a = clampf((DURATION - play_time) / FADE_TIME, 0.0, 1.0)
	if play_time >= DURATION:
		_finish()

func _ellipse(center: Vector2, rx: float, ry: float, steps: int) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(steps):
		var a: float = TAU * float(i) / float(steps)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

func _draw_face() -> void:
	var s: Vector2 = face.size
	var c: Vector2 = s * 0.5
	var u: float = minf(s.x, s.y)
	var cloth: Color = Color(0.05, 0.38, 0.16)
	var gold: Color = Color(0.95, 0.75, 0.2)

	# Kain keranda hijau + list emas
	var shape: PackedVector2Array = PackedVector2Array([
		c + Vector2(-0.28, -0.5) * u, c + Vector2(0.28, -0.5) * u,
		c + Vector2(0.44, -0.15) * u, c + Vector2(0.34, 0.5) * u,
		c + Vector2(-0.34, 0.5) * u, c + Vector2(-0.44, -0.15) * u])
	face.draw_colored_polygon(shape, cloth)
	var outline: PackedVector2Array = PackedVector2Array(shape)
	outline.append(shape[0])
	face.draw_polyline(outline, gold, maxf(2.0, u * 0.012))

	# Lipatan kain
	for i: int in range(-3, 4):
		var x: float = float(i) * 0.09
		face.draw_line(c + Vector2(x * 0.8, -0.48) * u, c + Vector2(x * 1.1, 0.5) * u, Color(0.02, 0.2, 0.08, 0.6), maxf(1.0, u * 0.006))

	# Pita emas di bagian bawah
	face.draw_rect(Rect2(c + Vector2(-0.33, 0.4) * u, Vector2(0.66, 0.04) * u), gold)

	# Rongga gelap di tengah
	face.draw_colored_polygon(_ellipse(c + Vector2(0.0, -0.02) * u, 0.25 * u, 0.34 * u, 32), Color(0.01, 0.0, 0.0))

	# Mata merah menyala + aliran darah
	for sx: float in [-1.0, 1.0]:
		var ep: Vector2 = c + Vector2(sx * 0.1, -0.14) * u
		face.draw_circle(ep, 0.085 * u, Color(1.0, 0.0, 0.0, 0.2 * eye_glow))
		face.draw_circle(ep, 0.055 * u, Color(1.0, 0.05, 0.05, 0.95))
		face.draw_circle(ep, 0.022 * u, Color(1.0, 0.9, 0.7, 1.0))
		face.draw_line(ep + Vector2(0.0, 0.05) * u, ep + Vector2(sx * 0.01, 0.2) * u, Color(0.6, 0.0, 0.0, 0.8), maxf(2.0, u * 0.008))

	# Mulut menganga bergigi runcing
	var mouth: PackedVector2Array = PackedVector2Array([
		c + Vector2(-0.15, 0.06) * u, c + Vector2(0.15, 0.06) * u,
		c + Vector2(0.11, 0.24) * u, c + Vector2(-0.11, 0.24) * u])
	face.draw_colored_polygon(mouth, Color(0.25, 0.0, 0.0))
	var tooth: Color = Color(0.9, 0.88, 0.8)
	for i: int in range(6):
		var x0: float = -0.15 + float(i) * 0.05
		face.draw_colored_polygon(PackedVector2Array([
			c + Vector2(x0, 0.06) * u, c + Vector2(x0 + 0.05, 0.06) * u,
			c + Vector2(x0 + 0.025, 0.13) * u]), tooth)
	for i: int in range(5):
		var x1: float = -0.11 + float(i) * 0.044
		face.draw_colored_polygon(PackedVector2Array([
			c + Vector2(x1, 0.24) * u, c + Vector2(x1 + 0.044, 0.24) * u,
			c + Vector2(x1 + 0.022, 0.17) * u]), tooth)

class_name WorldBackground
extends Node2D
## Layered, themed backdrop for menus and levels.
## Static layers are drawn once; only clouds, motes and vines animate.
## Draws well beyond the 720x1280 design area so tall phones never letterbox.

const SUNBEAMS_SHADER := preload("res://assets/shaders/sunbeams.gdshader")
const VIGNETTE_SHADER := preload("res://assets/shaders/vignette.gdshader")
const PAPER_GRAIN_PATH := "res://assets/textures/paper_grain.png"

const TOP := -460.0
const BOTTOM := 1740.0
const W := 720.0

var theme_name: String = "greenhouse"
var show_vignette: bool = true

var _sky: Layer
var _back: Layer
var _front: Layer
var _fx: Layer
var _sunbeam_rect: ColorRect
var _paper_rect: TextureRect
var _vignette_layer: CanvasLayer
var _time: float = 0.0
var _motes: Array[Dictionary] = []
var _clouds: Array[Dictionary] = []
var _vines: Array[Dictionary] = []


class Layer extends Node2D:
	var painter: Callable

	func _draw() -> void:
		if painter.is_valid():
			painter.call(self)


static func curtain_color(theme: String) -> Color:
	match theme:
		"kitchen":
			return Color(0.86, 0.50, 0.30)
		_:
			return Color(0.15, 0.55, 0.70)


static func accent_color(theme: String) -> Color:
	match theme:
		"kitchen":
			return Color(0.90, 0.52, 0.26)
		_:
			return Color(0.30, 0.70, 0.44)


func set_theme(p_theme: String) -> void:
	var t := p_theme.to_lower()
	if t != "kitchen":
		t = "greenhouse"
	theme_name = t
	_update_shader_colors()
	if is_inside_tree():
		_sky.queue_redraw()
		_front.queue_redraw()


func _ready() -> void:
	z_index = -20
	var rng := RandomNumberGenerator.new()
	rng.seed = 7331
	for i in range(26):
		_motes.append({
			"pos": Vector2(rng.randf_range(30, 690), rng.randf_range(TOP + 200, BOTTOM - 200)),
			"speed": rng.randf_range(6.0, 16.0),
			"phase": rng.randf_range(0.0, TAU),
			"r": rng.randf_range(1.8, 4.2),
		})
	for i in range(5):
		_clouds.append({
			"x": rng.randf_range(-60.0, 760.0),
			"y": rng.randf_range(-120.0, 420.0),
			"speed": rng.randf_range(5.0, 11.0),
			"scale": rng.randf_range(0.7, 1.3),
		})
	for x in [48.0, 150.0, 572.0, 676.0]:
		_vines.append({"x": x, "len": rng.randf_range(110.0, 190.0), "phase": rng.randf_range(0.0, TAU)})

	_sky = _make_layer(_paint_sky)
	_back = _make_layer(_paint_back)
	_front = _make_layer(_paint_front)

	_sunbeam_rect = ColorRect.new()
	_sunbeam_rect.position = Vector2(0, TOP)
	_sunbeam_rect.size = Vector2(W, 1500.0)
	_sunbeam_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = SUNBEAMS_SHADER
	_sunbeam_rect.material = mat
	add_child(_sunbeam_rect)

	_fx = _make_layer(_paint_fx)

	if ResourceLoader.exists(PAPER_GRAIN_PATH):
		_paper_rect = TextureRect.new()
		_paper_rect.texture = load(PAPER_GRAIN_PATH)
		_paper_rect.stretch_mode = TextureRect.STRETCH_TILE
		_paper_rect.position = Vector2(0, TOP)
		_paper_rect.size = Vector2(W, BOTTOM - TOP)
		_paper_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_paper_rect.modulate = Color(1, 1, 1, 0.35)
		add_child(_paper_rect)

	if show_vignette:
		_vignette_layer = CanvasLayer.new()
		_vignette_layer.layer = 5
		var vr := ColorRect.new()
		vr.set_anchors_preset(Control.PRESET_FULL_RECT)
		vr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var vmat := ShaderMaterial.new()
		vmat.shader = VIGNETTE_SHADER
		vr.material = vmat
		_vignette_layer.add_child(vr)
		add_child(_vignette_layer)

	_update_shader_colors()


func _make_layer(painter: Callable) -> Layer:
	var l := Layer.new()
	l.painter = painter
	add_child(l)
	return l


func _update_shader_colors() -> void:
	if _sunbeam_rect == null:
		return
	var mat := _sunbeam_rect.material as ShaderMaterial
	if theme_name == "kitchen":
		mat.set_shader_parameter("ray_color", Color(1.0, 0.92, 0.72, 0.20))
	else:
		mat.set_shader_parameter("ray_color", Color(1.0, 0.98, 0.84, 0.20))


func _process(delta: float) -> void:
	_time += delta
	for m in _motes:
		var p: Vector2 = m["pos"]
		p.y -= float(m["speed"]) * delta
		p.x += sin(_time * 0.8 + float(m["phase"])) * 7.0 * delta
		if p.y < TOP + 150.0:
			p.y = BOTTOM - 150.0
		m["pos"] = p
	for c in _clouds:
		c["x"] = float(c["x"]) + float(c["speed"]) * delta
		if float(c["x"]) > 820.0:
			c["x"] = -100.0
	_back.queue_redraw()
	_fx.queue_redraw()


# ================================================================ painters
func _vgrad_band(ci: CanvasItem, y0: float, y1: float, c0: Color, c1: Color, x0: float = 0.0, x1: float = W) -> void:
	ci.draw_polygon(
		PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]),
		PackedColorArray([c0, c0, c1, c1])
	)


func _gradient_stack(ci: CanvasItem, stops: Array) -> void:
	for i in range(stops.size() - 1):
		var a: Array = stops[i]
		var b: Array = stops[i + 1]
		_vgrad_band(ci, float(a[0]), float(b[0]), a[1], b[1])


func _paint_sky(ci: CanvasItem) -> void:
	if theme_name == "kitchen":
		_gradient_stack(ci, [
			[TOP, Color(0.62, 0.84, 0.95)],
			[300.0, Color(0.80, 0.92, 0.96)],
			[600.0, Color(0.94, 0.96, 0.92)],
			[BOTTOM, Color(0.94, 0.96, 0.92)],
		])
	else:
		_gradient_stack(ci, [
			[TOP, Color(0.66, 0.86, 0.95)],
			[250.0, Color(0.82, 0.94, 0.97)],
			[700.0, Color(0.96, 0.97, 0.90)],
			[1150.0, Color(0.86, 0.93, 0.80)],
			[BOTTOM, Color(0.72, 0.84, 0.66)],
		])
		# Distant garden beyond the glass
		var far := Color(0.62, 0.80, 0.62, 0.35)
		var near := Color(0.52, 0.74, 0.54, 0.38)
		for b in [[40, 990, 120], [190, 1030, 100], [330, 1000, 130], [480, 1035, 105], [640, 995, 125]]:
			Art.draw_ellipse(ci, Vector2(b[0], b[1]), float(b[2]), float(b[2]) * 0.8, far)
		_vgrad_band(ci, 1040.0, BOTTOM, Color(far.r, far.g, far.b, 0.35), Color(far.r, far.g, far.b, 0.5))
		for b in [[90, 1090, 90], [260, 1110, 80], [450, 1100, 95], [620, 1085, 88]]:
			Art.draw_ellipse(ci, Vector2(b[0], b[1]), float(b[2]), float(b[2]) * 0.7, near)


func _paint_back(ci: CanvasItem) -> void:
	# Clouds drifting behind the glass / through the window
	var col := Color(1.0, 1.0, 1.0, 0.72)
	for c in _clouds:
		var cp := Vector2(float(c["x"]), float(c["y"]))
		var sc: float = c["scale"]
		Art.draw_ellipse(ci, cp + Vector2(0, 10) * sc, 58.0 * sc, 16.0 * sc, Color(1, 1, 1, 0.5))
		ci.draw_circle(cp, 24.0 * sc, col)
		ci.draw_circle(cp + Vector2(-26.0, 8.0) * sc, 18.0 * sc, col)
		ci.draw_circle(cp + Vector2(27.0, 7.0) * sc, 19.0 * sc, col)
		ci.draw_circle(cp + Vector2(5.0, -12.0) * sc, 20.0 * sc, col)


func _paint_front(ci: CanvasItem) -> void:
	if theme_name == "kitchen":
		_paint_kitchen_front(ci)
	else:
		_paint_greenhouse_front(ci)


func _paint_greenhouse_front(ci: CanvasItem) -> void:
	# Faint glass tint so it reads as "indoors"
	ci.draw_rect(Rect2(0, TOP, W, BOTTOM - TOP), Color(1, 1, 1, 0.10))

	# Slender white-painted iron mullions with soft shadows
	var hi := Color(1.0, 1.0, 1.0, 0.55)
	var sh := Color(0.42, 0.58, 0.50, 0.20)
	for x in [120.0, 240.0, 360.0, 480.0, 600.0]:
		ci.draw_line(Vector2(x + 3.0, TOP), Vector2(x + 3.0, BOTTOM), sh, 3.0)
		ci.draw_line(Vector2(x, TOP), Vector2(x, BOTTOM), hi, 3.0)
	for y in [-150.0, 200.0, 560.0, 920.0]:
		ci.draw_line(Vector2(0, y + 3.0), Vector2(W, y + 3.0), sh, 2.5)
		ci.draw_line(Vector2(0, y), Vector2(W, y), hi, 2.5)
	# Gothic arch tracery in each bay
	for cx in [60.0, 180.0, 300.0, 420.0, 540.0, 660.0]:
		ci.draw_arc(Vector2(cx, 200.0), 60.0, PI, TAU, 22, Color(1, 1, 1, 0.42), 2.5, true)
		ci.draw_arc(Vector2(cx, 560.0), 60.0, PI, TAU, 22, Color(1, 1, 1, 0.30), 2.0, true)

	# Back potting bench + soft silhouettes of potted plants (low contrast)
	var bench_y := 1210.0
	var wood := Color(0.62, 0.48, 0.34, 0.55)
	ci.draw_rect(Rect2(0, bench_y, W, 22.0), wood)
	ci.draw_rect(Rect2(0, bench_y, W, 6.0), Color(0.82, 0.68, 0.50, 0.5))
	for lx in [60.0, 360.0, 660.0]:
		ci.draw_rect(Rect2(lx - 9.0, bench_y + 22.0, 18.0, BOTTOM - bench_y), Color(0.52, 0.38, 0.26, 0.45))
	var pot := Color(0.80, 0.52, 0.38, 0.45)
	var leaf := Color(0.40, 0.66, 0.42, 0.42)
	for p in [[110.0, 1.0], [250.0, 0.8], [470.0, 1.1], [610.0, 0.85]]:
		var px: float = p[0]
		var s: float = p[1]
		for k in range(5):
			var a := -PI * 0.5 + (float(k) - 2.0) * 0.42
			var tip := Vector2(px, bench_y - 40.0 * s) + Vector2(cos(a), sin(a)) * 34.0 * s
			Art.draw_ellipse(ci, Vector2(px, bench_y - 40.0 * s).lerp(tip, 0.55), 9.0 * s, 20.0 * s, leaf)
		var top_w := 30.0 * s
		var bot_w := 22.0 * s
		var h := 40.0 * s
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(px - top_w, bench_y - h), Vector2(px + top_w, bench_y - h),
			Vector2(px + bot_w, bench_y), Vector2(px - bot_w, bench_y),
		]), pot)
		ci.draw_rect(Rect2(px - top_w - 3.0, bench_y - h - 6.0, top_w * 2.0 + 6.0, 9.0), pot.darkened(0.08))

	# Cedar side posts
	_side_posts(ci, Color(0.50, 0.36, 0.24), Color(0.70, 0.54, 0.38, 0.7))


func _paint_kitchen_front(ci: CanvasItem) -> void:
	var wall_top := Color(0.99, 0.95, 0.87)
	var wall_bot := Color(0.95, 0.88, 0.78)
	# Wall with an arched window "hole" so the sky + clouds show through.
	var win := Rect2(185.0, 120.0, 350.0, 360.0)
	var arch_r := win.size.x * 0.5
	var arch_c := Vector2(win.position.x + arch_r, win.position.y + arch_r)
	_vgrad_band(ci, TOP, win.position.y, wall_top, wall_top)
	_vgrad_band(ci, win.position.y, win.end.y, wall_top, wall_top.lerp(wall_bot, 0.25), 0.0, win.position.x)
	_vgrad_band(ci, win.position.y, win.end.y, wall_top, wall_top.lerp(wall_bot, 0.25), win.end.x, W)
	_vgrad_band(ci, win.end.y, BOTTOM, wall_top.lerp(wall_bot, 0.25), wall_bot)
	for side: float in [-1.0, 1.0]:
		var corner := Vector2(arch_c.x + side * arch_r, win.position.y)
		var pts := PackedVector2Array([corner])
		for i in range(17):
			var a := lerpf(0.0, PI * 0.5, float(i) / 16.0)
			pts.append(arch_c + Vector2(side * cos(a), -sin(a)) * arch_r)
		pts.append(Vector2(arch_c.x, win.position.y))
		ci.draw_colored_polygon(pts, wall_top)
	# Distant hills inside the window
	var hills := PackedVector2Array()
	for i in range(21):
		var x := lerpf(win.position.x, win.end.x, float(i) / 20.0)
		hills.append(Vector2(x, win.end.y - 70.0 - sin(float(i) * 0.6) * 18.0 - sin(float(i) * 0.23) * 22.0))
	hills.append(Vector2(win.end.x, win.end.y))
	hills.append(Vector2(win.position.x, win.end.y))
	ci.draw_colored_polygon(hills, Color(0.58, 0.80, 0.58, 0.85))

	# Window frame, mullions and sill
	var frame := Color(0.72, 0.52, 0.34)
	ci.draw_arc(arch_c, arch_r, PI, TAU, 40, frame, 10.0, true)
	ci.draw_line(Vector2(win.position.x, arch_c.y), Vector2(win.position.x, win.end.y), frame, 10.0)
	ci.draw_line(Vector2(win.end.x, arch_c.y), Vector2(win.end.x, win.end.y), frame, 10.0)
	ci.draw_line(Vector2(arch_c.x, win.position.y), Vector2(arch_c.x, win.end.y), Color(1, 0.98, 0.94, 0.95), 6.0)
	ci.draw_line(Vector2(win.position.x, arch_c.y + 40.0), Vector2(win.end.x, arch_c.y + 40.0), Color(1, 0.98, 0.94, 0.95), 6.0)
	Art.draw_rrect(ci, Rect2(win.position.x - 24.0, win.end.y - 2.0, win.size.x + 48.0, 18.0), 6.0, Color(0.80, 0.60, 0.42))
	ci.draw_rect(Rect2(win.position.x - 24.0, win.end.y - 2.0, win.size.x + 48.0, 5.0), Color(0.92, 0.76, 0.58))
	# Little herb pots on the sill
	for hx in [win.position.x + 30.0, win.end.x - 30.0]:
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(hx - 16, win.end.y - 26), Vector2(hx + 16, win.end.y - 26),
			Vector2(hx + 12, win.end.y - 2), Vector2(hx - 12, win.end.y - 2)]), Color(0.86, 0.50, 0.34))
		for k in range(3):
			Art.draw_ellipse(ci, Vector2(hx - 8.0 + float(k) * 8.0, win.end.y - 36.0), 6.0, 11.0, Art.LEAF)

	# Subway tile backsplash
	var tile_top := 600.0
	var tile_h := 40.0
	var tile_w := 80.0
	var grout := Color(0.86, 0.80, 0.70, 0.55)
	ci.draw_rect(Rect2(0, tile_top, W, BOTTOM - tile_top), Color(0.97, 0.97, 0.93, 0.55))
	var row := 0
	var ty := tile_top
	while ty < 1200.0:
		ci.draw_line(Vector2(0, ty), Vector2(W, ty), grout, 2.0)
		var off := (tile_w * 0.5) if (row % 2 == 1) else 0.0
		var tx := off
		while tx < W:
			ci.draw_line(Vector2(tx, ty), Vector2(tx, ty + tile_h), grout, 2.0)
			tx += tile_w
		ty += tile_h
		row += 1
	# Copper rail with hanging utensils (soft silhouettes)
	ci.draw_line(Vector2(30.0, tile_top - 8.0), Vector2(690.0, tile_top - 8.0), Color(0.78, 0.50, 0.32, 0.55), 5.0)
	for hx in [70.0, 640.0]:
		ci.draw_line(Vector2(hx, tile_top - 8.0), Vector2(hx, tile_top + 26.0), Color(0.70, 0.46, 0.30, 0.45), 3.0)
		Art.draw_ellipse(ci, Vector2(hx, tile_top + 50.0), 26.0, 22.0, Color(0.82, 0.52, 0.34, 0.35))
		Art.draw_ellipse(ci, Vector2(hx - 4.0, tile_top + 44.0), 12.0, 8.0, Color(1.0, 0.84, 0.66, 0.35))

	# Countertop and cabinets (fills the extra height on tall screens)
	var counter_y := 1200.0
	Art.draw_rrect(ci, Rect2(-10.0, counter_y, W + 20.0, 26.0), 6.0, Color(0.86, 0.80, 0.70))
	ci.draw_rect(Rect2(0, counter_y, W, 6.0), Color(0.96, 0.93, 0.86))
	ci.draw_rect(Rect2(0, counter_y + 26.0, W, BOTTOM), Color(0.62, 0.74, 0.62))
	for cx in [20.0, 250.0, 480.0]:
		Art.draw_rrect_outline(ci, Rect2(cx, counter_y + 50.0, 220.0, 380.0), 10.0, Color(0.50, 0.62, 0.50), 3.0)
		ci.draw_circle(Vector2(cx + 110.0, counter_y + 80.0), 6.0, Color(0.92, 0.74, 0.44))

	_side_posts(ci, Color(0.58, 0.40, 0.26), Color(0.82, 0.66, 0.46, 0.65))


func _side_posts(ci: CanvasItem, base: Color, hi: Color) -> void:
	ci.draw_rect(Rect2(0, TOP, 12.0, BOTTOM - TOP), base)
	ci.draw_rect(Rect2(8.0, TOP, 4.0, BOTTOM - TOP), hi)
	ci.draw_rect(Rect2(W - 12.0, TOP, 12.0, BOTTOM - TOP), base)
	ci.draw_rect(Rect2(W - 12.0, TOP, 4.0, BOTTOM - TOP), hi)


func _paint_fx(ci: CanvasItem) -> void:
	# Hanging ivy (greenhouse) or drying herbs (kitchen) from the top edge
	var vine_col := Color(0.30, 0.56, 0.34, 0.55) if theme_name == "greenhouse" else Color(0.46, 0.60, 0.36, 0.5)
	var leaf_col := Color(0.42, 0.72, 0.44, 0.55) if theme_name == "greenhouse" else Color(0.56, 0.72, 0.42, 0.5)
	var top_y := TOP + 240.0
	for v in _vines:
		var bx: float = v["x"]
		var vlen: float = v["len"]
		var ph: float = v["phase"]
		var sway := sin(_time * 1.2 + ph) * 8.0
		var pts := PackedVector2Array()
		var segs := 7
		for s in range(segs + 1):
			var frac := float(s) / float(segs)
			var p := Vector2(bx + sway * frac * frac + sin(frac * 5.0 + ph) * 4.0, top_y + frac * (vlen + 120.0))
			pts.append(p)
			if s > 0:
				var side := -1.0 if s % 2 == 0 else 1.0
				var lp := p + Vector2(side * 8.0, 0.0)
				Art.draw_ellipse(ci, lp, 7.0 - frac * 2.0, 4.6 - frac * 1.2, leaf_col, 12)
		ci.draw_polyline(pts, vine_col, 2.2, true)

	# Floating sunlit dust motes
	for m in _motes:
		var glow := 0.28 + 0.26 * sin(_time * 2.2 + float(m["phase"]))
		var r: float = m["r"]
		Art.draw_glow(ci, m["pos"], r * 4.0, Color(1.0, 0.95, 0.70, glow * 0.6))
		ci.draw_circle(m["pos"], r * 0.7, Color(1.0, 0.99, 0.88, glow))

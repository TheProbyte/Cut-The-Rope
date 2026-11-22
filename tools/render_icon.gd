extends SceneTree
## Renders DRIP launcher icons from the in-game droplet art.
## Usage: godot --rendering-driver opengl3 -s res://tools/render_icon.gd
## (needs a display; e.g. wrap with xvfb-run). Writes assets/icons/*.png

var _canvas: Node2D
var _vp: SubViewport
var _mode := 0
var _frames := 0
var _art := DropletArt.new()


func _init() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(432, 432)
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	_canvas = Node2D.new()
	_canvas.draw.connect(_paint)
	_vp.add_child(_canvas)


func _process(_d: float) -> bool:
	_frames += 1
	if _frames % 4 != 0:
		return false
	var img := _vp.get_texture().get_image()
	match _mode:
		0:
			var big := img.duplicate() as Image
			img.resize(192, 192, Image.INTERPOLATE_LANCZOS)
			img.save_png("res://assets/icons/icon_192.png")
			big.save_png("res://assets/icons/icon_full_432.png")
		1:
			img.save_png("res://assets/icons/icon_432.png")
		2:
			img.save_png("res://assets/icons/icon_bg_432.png")
			return true
	_mode += 1
	_canvas.queue_redraw()
	return false


func _bg(ci: CanvasItem, rounded: bool) -> void:
	var rect := Rect2(0, 0, 432, 432)
	var pts := Art.rrect_points(rect, 96.0 if rounded else 0.0, 10)
	ci.draw_polygon(pts, Art.vgrad_colors(pts, Color(0.74, 0.93, 0.98), Color(0.42, 0.78, 0.62)))
	Art.draw_glow(ci, Vector2(170, 150), 200.0, Color(1.0, 0.98, 0.85, 0.8))
	for b in [[Vector2(70, 330), 16.0], [Vector2(360, 110), 12.0], [Vector2(372, 300), 9.0], [Vector2(88, 120), 8.0]]:
		ci.draw_circle(b[0], b[1], Color(1, 1, 1, 0.28))
		ci.draw_circle((b[0] as Vector2) + Vector2(-0.3, -0.3) * float(b[1]), float(b[1]) * 0.3, Color(1, 1, 1, 0.6))


func _droplet(ci: CanvasItem, center: Vector2, s: float) -> void:
	# little sprout on the droplet's head
	var tip := center + Vector2(0, -33.0 * s)
	ci.draw_line(tip, tip + Vector2(2, -12) * s, Art.LEAF_DEEP, 3.0 * s, true)
	for side: float in [-1.0, 1.0]:
		var leaf := PackedVector2Array()
		var base := tip + Vector2(1, -11) * s
		for i in range(9):
			var t := float(i) / 8.0
			leaf.append(base + Vector2(side * 16.0 * t, -6.0 * t - sin(t * PI) * 6.0) * s)
		for i in range(7, 0, -1):
			var t := float(i) / 8.0
			leaf.append(base + Vector2(side * 16.0 * t, -6.0 * t + sin(t * PI) * 4.0) * s)
		ci.draw_colored_polygon(leaf, Art.LEAF)
		ci.draw_polyline(Art.closed(leaf), Art.LEAF_DEEP, 1.2 * s, true)
	Art.draw_ellipse(ci, center + Vector2(0, 30 * s), 22.0 * s, 4.5 * s, Color(0.05, 0.25, 0.2, 0.25))
	_art.size = s
	_art.mood = "happy"
	_art.draw(ci, center)
	Art.draw_sparkle(ci, center + Vector2(30, -26) * s, 7.0 * s, Color(1, 1, 1, 0.95))
	Art.draw_sparkle(ci, center + Vector2(-32, 14) * s, 4.5 * s, Color(1, 1, 1, 0.85))


func _paint() -> void:
	match _mode:
		0:
			_bg(_canvas, true)
			_droplet(_canvas, Vector2(216, 272), 4.0)
		1:
			_droplet(_canvas, Vector2(216, 246), 3.0)
		2:
			_bg(_canvas, false)

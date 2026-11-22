class_name GreenhouseBackground
extends Node2D

var _time: float = 0.0
var _motes: Array[Dictionary] = []


func _ready() -> void:
	z_index = -20
	for i in range(18):
		_motes.append({
			"pos": Vector2(randf_range(30, 690), randf_range(120, 1180)),
			"speed": randf_range(6.0, 16.0),
			"phase": randf_range(0.0, TAU),
			"r": randf_range(2.0, 4.2),
		})


func _process(delta: float) -> void:
	_time += delta
	for m in _motes:
		var p: Vector2 = m["pos"]
		p.y -= float(m["speed"]) * delta
		p.x += sin(_time * 0.9 + float(m["phase"])) * 7.0 * delta
		if p.y < 100.0:
			p.y = 1200.0
			p.x = randf_range(30.0, 690.0)
		m["pos"] = p
	queue_redraw()


func _draw() -> void:
	# Soft vertical sunlit greenhouse cream-to-mint gradient (4 bands)
	var stops := [
		Color(0.95, 0.98, 0.92),
		Color(0.89, 0.95, 0.87),
		Color(0.83, 0.92, 0.82),
		Color(0.77, 0.88, 0.77),
	]
	var band_h := 1280.0 / float(stops.size())
	for i in range(stops.size()):
		draw_rect(Rect2(0.0, float(i) * band_h, 720.0, band_h + 2.0), stops[i])

	# Subtle glasshouse window panes in background
	var mullion := Color(1.0, 1.0, 1.0, 0.45)
	var frame := Color(0.64, 0.77, 0.65, 0.45)
	for x in [120.0, 240.0, 360.0, 480.0, 600.0]:
		draw_line(Vector2(x, 86.0), Vector2(x, 1190.0), mullion, 4.0)
		draw_line(Vector2(x + 2.0, 86.0), Vector2(x + 2.0, 1190.0), frame, 1.5)
	for y in [280.0, 520.0, 760.0, 1000.0]:
		draw_line(Vector2(0.0, y), Vector2(720.0, y), mullion, 3.0)

	# Warm diagonal morning sunbeams
	var beam1 := PackedVector2Array([
		Vector2(60.0, 80.0), Vector2(260.0, 80.0),
		Vector2(560.0, 1200.0), Vector2(310.0, 1200.0),
	])
	var beam2 := PackedVector2Array([
		Vector2(380.0, 80.0), Vector2(540.0, 80.0),
		Vector2(720.0, 820.0), Vector2(610.0, 980.0),
	])
	draw_colored_polygon(beam1, Color(1.0, 0.98, 0.82, 0.16))
	draw_colored_polygon(beam2, Color(1.0, 0.98, 0.82, 0.12))

	# Soft distant botanical leaf silhouettes along bottom edge
	var leaf_col := Color(0.56, 0.76, 0.58, 0.34)
	draw_circle(Vector2(60.0, 1185.0), 78.0, leaf_col)
	draw_circle(Vector2(140.0, 1205.0), 62.0, leaf_col)
	draw_circle(Vector2(655.0, 1185.0), 82.0, leaf_col)
	draw_circle(Vector2(575.0, 1210.0), 58.0, leaf_col)

	# Wooden greenhouse frame along left/right edges & bottom shelf sill
	draw_rect(Rect2(0.0, 0.0, 14.0, 1280.0), Color(0.52, 0.38, 0.25, 0.85))
	draw_rect(Rect2(706.0, 0.0, 14.0, 1280.0), Color(0.52, 0.38, 0.25, 0.85))
	draw_rect(Rect2(0.0, 84.0, 720.0, 6.0), Color(0.62, 0.78, 0.66, 0.55))

	# Floating golden sunlit dust motes
	for m in _motes:
		var glow := 0.30 + 0.25 * sin(_time * 2.5 + float(m["phase"]))
		draw_circle(m["pos"], float(m["r"]), Color(1.0, 0.97, 0.78, glow))

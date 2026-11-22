class_name SpawnSpout
extends Node2D

var theme_name: String = "greenhouse"
var _time: float = 0.0


func _process(delta: float) -> void:
	_time += delta
	if _time < 1.2:
		queue_redraw()


func _draw() -> void:
	var is_k := (theme_name == "kitchen")
	var pipe_col := Color(0.76, 0.48, 0.32) if is_k else Color(0.56, 0.64, 0.54)
	var hi_col := Color(0.94, 0.72, 0.54, 0.65) if is_k else Color(0.80, 0.88, 0.78, 0.65)
	var rim_col := Color(0.42, 0.24, 0.16) if is_k else Color(0.30, 0.40, 0.32)

	# Cozy overhead nozzle positioned just above droplet spawn
	var nozzle_y := -34.0
	draw_rect(Rect2(-9.0, nozzle_y - 26.0, 18.0, 22.0), pipe_col)
	draw_rect(Rect2(-6.0, nozzle_y - 26.0, 5.0, 22.0), hi_col)
	draw_rect(Rect2(-9.0, nozzle_y - 26.0, 18.0, 22.0), rim_col, false, 2.0)

	# Flared spout collar
	var flare := PackedVector2Array([
		Vector2(-14.0, nozzle_y - 6.0),
		Vector2(14.0, nozzle_y - 6.0),
		Vector2(18.0, nozzle_y + 4.0),
		Vector2(-18.0, nozzle_y + 4.0),
	])
	draw_colored_polygon(flare, pipe_col.lightened(0.08))
	draw_polyline(flare, rim_col, 2.0, true)
	draw_circle(Vector2(0.0, nozzle_y + 5.0), 4.0, Color(0.28, 0.78, 0.98, clampf(1.0 - _time, 0.0, 0.85)))

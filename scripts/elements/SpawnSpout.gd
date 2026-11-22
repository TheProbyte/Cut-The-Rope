class_name SpawnSpout
extends Node2D

var theme_name: String = "greenhouse"
var _time: float = 0.0
var _drip_t: float = -1.0


func _process(delta: float) -> void:
	_time += delta
	if _drip_t >= 0.0 and _drip_t < 1.0:
		_drip_t += delta / 0.35
		queue_redraw()
	elif _time < 0.2:
		queue_redraw()


func drip() -> void:
	_drip_t = 0.0


func _draw() -> void:
	var is_k := (theme_name == "kitchen")
	var base := Color(0.86, 0.56, 0.36) if is_k else Color(0.56, 0.70, 0.60)
	var deep := base.darkened(0.35)
	var ny := -36.0
	# pipe stub coming down from above
	var pipe := Rect2(-8.0, ny - 46.0, 16.0, 36.0)
	Art.draw_rrect_grad(self, pipe, 3.0, base.lightened(0.15), base)
	draw_rect(Rect2(-5.0, ny - 46.0, 4.0, 36.0), Color(1, 1, 1, 0.35))
	Art.draw_rrect_outline(self, pipe, 3.0, deep, 2.0)
	# valve wheel
	draw_circle(Vector2(0, ny - 30.0), 9.0, Color(0.86, 0.36, 0.30) if not is_k else Color(0.40, 0.62, 0.80))
	draw_circle(Vector2(0, ny - 30.0), 3.0, Color(1, 1, 1, 0.8))
	# flared nozzle
	var flare := PackedVector2Array([Vector2(-12.0, ny - 12.0), Vector2(12.0, ny - 12.0), Vector2(17.0, ny + 4.0), Vector2(-17.0, ny + 4.0)])
	draw_polygon(flare, Art.vgrad_colors(flare, base.lightened(0.2), base.darkened(0.1)))
	draw_polyline(Art.closed(flare), deep, 2.0, true)
	Art.draw_ellipse(self, Vector2(0, ny + 4.0), 15.0, 3.6, deep)
	# forming / falling drip during the intro
	if _drip_t >= 0.0 and _drip_t < 1.0:
		var t := _drip_t
		var r := 4.0 + t * 4.0
		Art.draw_ellipse(self, Vector2(0, ny + 6.0 + t * t * 30.0), r * 0.85, r * 1.1, Color(0.30, 0.78, 0.98, 1.0 - t * 0.6), 14)

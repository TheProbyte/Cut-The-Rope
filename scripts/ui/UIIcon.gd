class_name UIIcon
extends Control
## Crisp vector icons drawn in code (no font glyph or emoji dependencies).

var kind: String = "play"
var color: Color = Color.WHITE
var shadow: bool = true


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	if shadow:
		_draw_kind(c + Vector2(0, 2.0), s, Color(0, 0, 0, 0.16))
	_draw_kind(c, s, color)


func _draw_kind(c: Vector2, s: float, col: Color) -> void:
	var u := s / 64.0
	var w := maxf(2.0, 5.5 * u)
	match kind:
		"pause":
			Art.draw_rrect(self, Rect2(c + Vector2(-11, -13) * u, Vector2(8, 26) * u), 3.0 * u, col)
			Art.draw_rrect(self, Rect2(c + Vector2(3, -13) * u, Vector2(8, 26) * u), 3.0 * u, col)
		"play":
			var pts := PackedVector2Array([c + Vector2(-8, -14) * u, c + Vector2(14, 0) * u, c + Vector2(-8, 14) * u])
			draw_colored_polygon(pts, col)
			draw_polyline(Art.closed(pts), col, 4.0 * u, true)
		"next":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-14, -12) * u, c + Vector2(2, 0) * u, c + Vector2(-14, 12) * u]), col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -12) * u, c + Vector2(16, 0) * u, c + Vector2(0, 12) * u]), col)
		"restart":
			draw_arc(c, 13.0 * u, -PI * 0.35, PI * 1.45, 28, col, w, true)
			var tip := c + Vector2.from_angle(-PI * 0.35) * 13.0 * u
			draw_colored_polygon(PackedVector2Array([
				tip + Vector2(-9, -6) * u, tip + Vector2(5, -9) * u, tip + Vector2(2, 6) * u,
			]), col)
		"back":
			draw_polyline(PackedVector2Array([c + Vector2(5, -13) * u, c + Vector2(-8, 0) * u, c + Vector2(5, 13) * u]), col, w * 1.1, true)
		"close":
			draw_line(c + Vector2(-11, -11) * u, c + Vector2(11, 11) * u, col, w, true)
			draw_line(c + Vector2(11, -11) * u, c + Vector2(-11, 11) * u, col, w, true)
		"home":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -16) * u, c + Vector2(16, -1) * u, c + Vector2(-16, -1) * u]), col)
			Art.draw_rrect(self, Rect2(c + Vector2(-11, -3) * u, Vector2(22, 17) * u), 2.0 * u, col)
		"levels":
			for i in range(2):
				for j in range(2):
					Art.draw_rrect(self, Rect2(c + Vector2(-13 + i * 15, -13 + j * 15) * u, Vector2(11, 11) * u), 3.0 * u, col)
		"music", "music_off":
			draw_line(c + Vector2(-5, 9) * u, c + Vector2(-5, -12) * u, col, w * 0.8, true)
			draw_line(c + Vector2(9, 5) * u, c + Vector2(9, -16) * u, col, w * 0.8, true)
			draw_line(c + Vector2(-5, -12) * u, c + Vector2(9, -16) * u, col, w * 1.1, true)
			Art.draw_ellipse(self, c + Vector2(-9, 10) * u, 6.0 * u, 4.6 * u, col)
			Art.draw_ellipse(self, c + Vector2(5, 6) * u, 6.0 * u, 4.6 * u, col)
			if kind == "music_off":
				_slash(c, u, col)
		"sfx", "sfx_off":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-15, -6) * u, c + Vector2(-8, -6) * u, c + Vector2(1, -14) * u,
				c + Vector2(1, 14) * u, c + Vector2(-8, 6) * u, c + Vector2(-15, 6) * u,
			]), col)
			if kind == "sfx":
				draw_arc(c + Vector2(3, 0) * u, 7.0 * u, -0.9, 0.9, 10, col, w * 0.7, true)
				draw_arc(c + Vector2(3, 0) * u, 13.0 * u, -0.9, 0.9, 12, col, w * 0.7, true)
			else:
				draw_line(c + Vector2(6, -6) * u, c + Vector2(16, 6) * u, col, w * 0.8, true)
				draw_line(c + Vector2(16, -6) * u, c + Vector2(6, 6) * u, col, w * 0.8, true)
		"haptics", "haptics_off":
			Art.draw_rrect_outline(self, Rect2(c + Vector2(-7, -13) * u, Vector2(14, 26) * u), 3.5 * u, col, w * 0.7)
			for sgn: float in [-1.0, 1.0]:
				draw_line(c + Vector2(sgn * 12, -6) * u, c + Vector2(sgn * 15, -2) * u, col, w * 0.6, true)
				draw_line(c + Vector2(sgn * 15, -2) * u, c + Vector2(sgn * 12, 2) * u, col, w * 0.6, true)
				draw_line(c + Vector2(sgn * 12, 2) * u, c + Vector2(sgn * 15, 6) * u, col, w * 0.6, true)
			if kind == "haptics_off":
				_slash(c, u, col)
		"lock":
			draw_arc(c + Vector2(0, -4) * u, 8.0 * u, PI, TAU, 14, col, w * 0.8, true)
			draw_line(c + Vector2(-8, -4) * u, c + Vector2(-8, 1) * u, col, w * 0.8, true)
			draw_line(c + Vector2(8, -4) * u, c + Vector2(8, 1) * u, col, w * 0.8, true)
			Art.draw_rrect(self, Rect2(c + Vector2(-12, -1) * u, Vector2(24, 18) * u), 4.0 * u, col)
		"hint":
			draw_circle(c + Vector2(0, -4) * u, 11.0 * u, col)
			Art.draw_rrect(self, Rect2(c + Vector2(-6, 5) * u, Vector2(12, 8) * u), 2.0 * u, col)
			draw_line(c + Vector2(-5, 16) * u, c + Vector2(5, 16) * u, col, w * 0.7, true)
		"check":
			draw_polyline(PackedVector2Array([c + Vector2(-12, 0) * u, c + Vector2(-3, 9) * u, c + Vector2(13, -9) * u]), col, w * 1.2, true)
		"drop":
			var pts := PackedVector2Array()
			for i in range(24):
				var a := TAU * float(i) / 24.0
				var r := 12.0
				var lift := maxf(0.0, -sin(a)) * 9.0
				var taper := 1.0 - maxf(0.0, -sin(a)) * 0.4
				pts.append(c + Vector2(cos(a) * r * taper, sin(a) * r - lift + 4.0) * u)
			draw_colored_polygon(pts, col)
		"star":
			Art.draw_sun(self, c, 16.0 * u, 0.0, true, col.a)
		_:
			draw_circle(c, 8.0 * u, col)


func _slash(c: Vector2, u: float, col: Color) -> void:
	draw_line(c + Vector2(-17, -17) * u, c + Vector2(17, 17) * u, Color(0.86, 0.34, 0.30, col.a), 5.0 * u, true)

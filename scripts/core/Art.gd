class_name Art
extends RefCounted
## Shared drawing toolkit + palette so every element, screen and icon in DRIP
## speaks the same visual language: rounded shapes, soft offset shadows,
## gentle vertical gradients, warm dark outlines and texture-based glows.

# ---------------------------------------------------------------- palette
const INK := Color(0.17, 0.24, 0.20)
const INK_SOFT := Color(0.17, 0.24, 0.20, 0.55)
const CREAM := Color(1.0, 0.985, 0.95)
const CREAM_DARK := Color(0.93, 0.91, 0.84)
const WATER := Color(0.18, 0.66, 0.94)
const WATER_DEEP := Color(0.07, 0.42, 0.74)
const WATER_LIGHT := Color(0.62, 0.90, 1.0)
const ICE := Color(0.74, 0.93, 1.0)
const ICE_DEEP := Color(0.36, 0.66, 0.88)
const STEAM := Color(0.97, 0.98, 1.0)
const STEAM_SHADE := Color(0.72, 0.80, 0.88)
const SUN := Color(1.0, 0.79, 0.20)
const SUN_LIGHT := Color(1.0, 0.94, 0.62)
const SUN_DEEP := Color(0.90, 0.52, 0.06)
const LEAF := Color(0.36, 0.75, 0.38)
const LEAF_DEEP := Color(0.19, 0.50, 0.24)
const LEAF_LIGHT := Color(0.62, 0.90, 0.52)
const TERRACOTTA := Color(0.86, 0.47, 0.30)
const TERRACOTTA_DEEP := Color(0.58, 0.27, 0.16)
const HOT := Color(1.0, 0.42, 0.16)
const BLUSH := Color(1.0, 0.52, 0.58, 0.55)
const SHADOW := Color(0.10, 0.16, 0.12, 0.20)

const GLOW_TEX_PATH := "res://assets/textures/soft_glow.png"

static var _glow_tex: Texture2D = null
static var _radial_tex: Texture2D = null


static func state_color(state: int) -> Color:
	match state:
		0:
			return WATER
		1:
			return ICE_DEEP
		_:
			return STEAM_SHADE


# ---------------------------------------------------------------- textures
## Soft round radial glow (white, alpha falloff). Modulate to tint.
static func glow_texture() -> Texture2D:
	if _radial_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.55))
		g.add_point(0.7, Color(1, 1, 1, 0.12))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = 128
		t.height = 128
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		_radial_tex = t
	return _radial_tex


static func draw_glow(ci: CanvasItem, center: Vector2, radius: float, col: Color) -> void:
	if radius <= 0.5 or col.a <= 0.003:
		return
	ci.draw_texture_rect(glow_texture(), Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, col)


# ---------------------------------------------------------------- geometry
static func _push(pts: PackedVector2Array, p: Vector2) -> void:
	if pts.is_empty() or pts[pts.size() - 1].distance_squared_to(p) > 0.0004:
		pts.append(p)


static func rrect_points(rect: Rect2, radius: float, seg: int = 5) -> PackedVector2Array:
	var r := clampf(radius, 0.0, minf(rect.size.x, rect.size.y) * 0.5)
	var pts := PackedVector2Array()
	if r <= 0.5:
		pts.append(rect.position)
		pts.append(Vector2(rect.end.x, rect.position.y))
		pts.append(rect.end)
		pts.append(Vector2(rect.position.x, rect.end.y))
		return pts
	var centers := [
		Vector2(rect.end.x - r, rect.position.y + r),
		Vector2(rect.end.x - r, rect.end.y - r),
		Vector2(rect.position.x + r, rect.end.y - r),
		Vector2(rect.position.x + r, rect.position.y + r),
	]
	for c in range(4):
		var start := -PI * 0.5 + float(c) * PI * 0.5
		for i in range(seg + 1):
			var a := start + (PI * 0.5) * float(i) / float(seg)
			_push(pts, (centers[c] as Vector2) + Vector2(cos(a), sin(a)) * r)
	if pts.size() > 2 and pts[0].distance_squared_to(pts[pts.size() - 1]) <= 0.0004:
		pts.remove_at(pts.size() - 1)
	return pts


static func ellipse_points(center: Vector2, rx: float, ry: float, seg: int = 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(seg):
		var a := TAU * float(i) / float(seg)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	if out.size() > 0:
		out.append(out[0])
	return out


static func offset_points(pts: PackedVector2Array, off: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in range(pts.size()):
		out[i] = pts[i] + off
	return out


static func vgrad_colors(pts: PackedVector2Array, top: Color, bottom: Color) -> PackedColorArray:
	var y0 := INF
	var y1 := -INF
	for p in pts:
		y0 = minf(y0, p.y)
		y1 = maxf(y1, p.y)
	var span := maxf(y1 - y0, 0.001)
	var cols := PackedColorArray()
	cols.resize(pts.size())
	for i in range(pts.size()):
		cols[i] = top.lerp(bottom, (pts[i].y - y0) / span)
	return cols


# ---------------------------------------------------------------- drawing
static func draw_rrect(ci: CanvasItem, rect: Rect2, radius: float, col: Color) -> void:
	if rect.size.x < 1.0 or rect.size.y < 1.0:
		return
	ci.draw_colored_polygon(rrect_points(rect, radius), col)


static func draw_rrect_grad(ci: CanvasItem, rect: Rect2, radius: float, top: Color, bottom: Color) -> void:
	if rect.size.x < 1.0 or rect.size.y < 1.0:
		return
	var pts := rrect_points(rect, radius)
	ci.draw_polygon(pts, vgrad_colors(pts, top, bottom))


static func draw_rrect_outline(ci: CanvasItem, rect: Rect2, radius: float, col: Color, width: float = 2.0) -> void:
	if rect.size.x < 1.0 or rect.size.y < 1.0:
		return
	ci.draw_polyline(closed(rrect_points(rect, radius)), col, width, true)


## Soft offset drop shadow made of a few expanding translucent layers.
static func draw_soft_shadow(ci: CanvasItem, rect: Rect2, radius: float, offset: Vector2 = Vector2(0, 6), alpha: float = 0.18) -> void:
	for i in range(3):
		var grow := float(i) * 2.5
		var r := rect.grow(grow)
		r.position += offset
		draw_rrect(ci, r, radius + grow, Color(SHADOW.r, SHADOW.g, SHADOW.b, alpha * (0.55 - float(i) * 0.15)))


static func draw_ellipse(ci: CanvasItem, center: Vector2, rx: float, ry: float, col: Color, seg: int = 28) -> void:
	if rx < 0.5 or ry < 0.5:
		return
	ci.draw_colored_polygon(ellipse_points(center, rx, ry, seg), col)


static func draw_ground_shadow(ci: CanvasItem, center: Vector2, rx: float, ry: float, alpha: float = 0.18) -> void:
	draw_ellipse(ci, center, rx, ry, Color(SHADOW.r, SHADOW.g, SHADOW.b, alpha))
	draw_ellipse(ci, center, rx * 0.7, ry * 0.7, Color(SHADOW.r, SHADOW.g, SHADOW.b, alpha * 0.6))


static func star_points(center: Vector2, outer: float, inner: float, count: int = 5, rot: float = -PI * 0.5) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(count * 2):
		var a := rot + PI * float(i) / float(count)
		var r := outer if i % 2 == 0 else inner
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts


## Four-point twinkle sparkle.
static func draw_sparkle(ci: CanvasItem, center: Vector2, size: float, col: Color) -> void:
	if size < 0.5 or col.a <= 0.01:
		return
	ci.draw_colored_polygon(star_points(center, size, size * 0.28, 4, 0.0), col)


## The DRIP "sun" collectible / star icon. lit=false draws an empty slot.
static func draw_sun(ci: CanvasItem, center: Vector2, radius: float, rot: float = 0.0, lit: bool = true, alpha: float = 1.0) -> void:
	if not lit:
		draw_ellipse(ci, center + Vector2(0, radius * 0.08), radius * 0.62, radius * 0.62, Color(0.40, 0.50, 0.42, 0.16 * alpha))
		ci.draw_arc(center, radius * 0.58, 0.0, TAU, 28, Color(0.42, 0.52, 0.44, 0.45 * alpha), maxf(1.5, radius * 0.09), true)
		return
	draw_glow(ci, center, radius * 2.0, Color(1.0, 0.82, 0.3, 0.42 * alpha))
	var rays := PackedVector2Array()
	for i in range(16):
		var a := rot + TAU * float(i) / 16.0
		var r := radius if i % 2 == 0 else radius * 0.66
		rays.append(center + Vector2(cos(a), sin(a)) * r)
	ci.draw_colored_polygon(rays, Color(SUN_DEEP.r, SUN_DEEP.g, SUN_DEEP.b, alpha))
	var rays_in := PackedVector2Array()
	for i in range(16):
		var a := rot + TAU * float(i) / 16.0
		var r := radius * 0.86 if i % 2 == 0 else radius * 0.6
		rays_in.append(center + Vector2(cos(a), sin(a)) * r)
	ci.draw_colored_polygon(rays_in, Color(SUN.r, SUN.g, SUN.b, alpha))
	var core := ellipse_points(center, radius * 0.56, radius * 0.56, 24)
	ci.draw_polygon(core, vgrad_colors(core, Color(1.0, 0.95, 0.62, alpha), Color(1.0, 0.74, 0.18, alpha)))
	ci.draw_polyline(closed(core), Color(SUN_DEEP.r, SUN_DEEP.g, SUN_DEEP.b, 0.85 * alpha), maxf(1.2, radius * 0.07), true)
	draw_ellipse(ci, center + Vector2(-radius * 0.2, -radius * 0.22), radius * 0.2, radius * 0.13, Color(1, 1, 1, 0.75 * alpha))


## Simple cute face used by droplets and seedlings.
## mood: "happy", "neutral", "worried", "scared", "joy", "sleepy", "determined", "wince"
static func draw_face(ci: CanvasItem, center: Vector2, scale: float, ink: Color, mood: String, look: Vector2 = Vector2.ZERO, blink: bool = false) -> void:
	var eye_dx := 6.6 * scale
	var eye_y := -1.5 * scale
	var le := center + Vector2(-eye_dx, eye_y) + look * scale
	var re := center + Vector2(eye_dx, eye_y) + look * scale
	var lw := maxf(1.4, 2.0 * scale)
	# blush
	draw_ellipse(ci, center + Vector2(-11.0 * scale, 4.2 * scale), 3.6 * scale, 2.4 * scale, BLUSH, 16)
	draw_ellipse(ci, center + Vector2(11.0 * scale, 4.2 * scale), 3.6 * scale, 2.4 * scale, BLUSH, 16)

	match mood:
		"joy", "sleepy":
			ci.draw_arc(le + Vector2(0, 1.6 * scale), 3.4 * scale, PI + 0.4, TAU - 0.4, 10, ink, lw, true)
			ci.draw_arc(re + Vector2(0, 1.6 * scale), 3.4 * scale, PI + 0.4, TAU - 0.4, 10, ink, lw, true)
		"wince":
			for s: float in [-1.0, 1.0]:
				var e := le if s < 0 else re
				ci.draw_line(e + Vector2(-3.0 * s, -2.6) * scale, e + Vector2(1.6 * s, 0) * scale, ink, lw, true)
				ci.draw_line(e + Vector2(-3.0 * s, 2.6) * scale, e + Vector2(1.6 * s, 0) * scale, ink, lw, true)
		_:
			if blink:
				ci.draw_line(le + Vector2(-3.0, 0) * scale, le + Vector2(3.0, 0) * scale, ink, lw, true)
				ci.draw_line(re + Vector2(-3.0, 0) * scale, re + Vector2(3.0, 0) * scale, ink, lw, true)
			else:
				var er := (3.6 if mood == "scared" else 3.1) * scale
				draw_ellipse(ci, le, er * 0.92, er * 1.08, ink, 16)
				draw_ellipse(ci, re, er * 0.92, er * 1.08, ink, 16)
				ci.draw_circle(le + Vector2(-1.0, -1.2) * scale, 1.2 * scale, Color.WHITE)
				ci.draw_circle(re + Vector2(-1.0, -1.2) * scale, 1.2 * scale, Color.WHITE)
	match mood:
		"determined":
			ci.draw_line(le + Vector2(-3.8, -5.0) * scale, le + Vector2(3.0, -3.0) * scale, ink, lw, true)
			ci.draw_line(re + Vector2(3.8, -5.0) * scale, re + Vector2(-3.0, -3.0) * scale, ink, lw, true)
			ci.draw_line(center + Vector2(-3.0, 5.6) * scale, center + Vector2(3.0, 5.6) * scale, ink, lw, true)
		"worried":
			ci.draw_line(le + Vector2(-3.4, -4.0) * scale, le + Vector2(2.6, -5.4) * scale, ink, lw * 0.85, true)
			ci.draw_line(re + Vector2(3.4, -4.0) * scale, re + Vector2(-2.6, -5.4) * scale, ink, lw * 0.85, true)
			ci.draw_arc(center + Vector2(0, 8.6) * scale, 3.4 * scale, PI + 0.5, TAU - 0.5, 10, ink, lw, true)
		"scared", "wince":
			draw_ellipse(ci, center + Vector2(0, 6.2) * scale, 2.6 * scale, 3.2 * scale, ink, 14)
		"joy":
			var mouth := PackedVector2Array()
			for i in range(9):
				var a := lerpf(0.15, PI - 0.15, float(i) / 8.0)
				mouth.append(center + Vector2(cos(a) * 5.0, 2.4 + sin(a) * 4.6) * scale)
			ci.draw_colored_polygon(mouth, ink)
			draw_ellipse(ci, center + Vector2(0, 5.6) * scale, 2.4 * scale, 1.4 * scale, Color(1.0, 0.45, 0.5), 12)
		"neutral", "sleepy":
			ci.draw_arc(center + Vector2(0, 3.6) * scale, 3.0 * scale, 0.3, PI - 0.3, 10, ink, lw, true)
		_:
			ci.draw_arc(center + Vector2(0, 3.0) * scale, 4.2 * scale, 0.22, PI - 0.22, 12, ink, lw, true)

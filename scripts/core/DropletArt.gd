class_name DropletArt
extends RefCounted
## Renders the droplet character in any of its three states, including the
## morph between states. Used by the in-level Droplet and by menu heroes.

const MORPH_TIME := 0.26

var state: int = 0
var prev_state: int = 0
var morph: float = 1.0        # 0 -> 1 while morphing from prev_state to state
var time: float = 0.0
var squish: float = 0.0       # spring value from impacts (+ = squashed)
var pop: float = 1.0          # overall scale
var velocity: Vector2 = Vector2.ZERO  # in the droplet's local frame
var blink: bool = false
var mood: String = ""         # "" = default mood for the state
var alpha: float = 1.0
var size: float = 1.0         # extra uniform scale (menus)


func start_morph(from_state: int, to_state: int) -> void:
	prev_state = from_state
	state = to_state
	morph = 0.0 if from_state != to_state else 1.0


func advance(delta: float) -> void:
	time += delta
	if morph < 1.0:
		morph = minf(1.0, morph + delta / MORPH_TIME)


func draw(ci: CanvasItem, origin: Vector2 = Vector2.ZERO) -> void:
	if alpha <= 0.01 or pop <= 0.01:
		return
	if morph < 1.0:
		var out_t := morph
		var in_t := _ease_out_back(morph)
		_draw_state(ci, prev_state, origin, (1.0 - out_t * 0.55), alpha * (1.0 - out_t))
		_draw_state(ci, state, origin, lerpf(0.35, 1.0, in_t), alpha * minf(1.0, morph * 2.2))
	else:
		_draw_state(ci, state, origin, 1.0, alpha)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


static func _ease_out_back(t: float) -> float:
	var c1 := 1.9
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0)


func _stretch_xform(origin: Vector2, k: float) -> Transform2D:
	# Squash/stretch along the direction of travel + impact squish.
	var sc := pop * size * k
	var speed := velocity.length()
	var xf := Transform2D.IDENTITY
	if speed > 30.0:
		var ang := velocity.angle()
		var st := clampf(speed / 900.0, 0.0, 0.22)
		xf = Transform2D.IDENTITY.rotated(-ang).scaled(Vector2(1.0 + st, 1.0 - st * 0.55)).rotated(ang)
	var sq := clampf(squish, -0.4, 0.4)
	xf = Transform2D.IDENTITY.scaled(Vector2(1.0 + sq * 0.6, 1.0 - sq * 0.6)) * xf
	xf = Transform2D.IDENTITY.scaled(Vector2(sc, sc)) * xf
	xf.origin = origin
	return xf


func _look() -> Vector2:
	return velocity.limit_length(260.0) / 260.0 * 2.6


func _draw_state(ci: CanvasItem, st: int, origin: Vector2, k: float, a: float) -> void:
	if a <= 0.01 or k <= 0.01:
		return
	match st:
		0:
			_draw_water(ci, origin, k, a)
		1:
			_draw_ice(ci, origin, k, a)
		_:
			_draw_steam(ci, origin, k, a)


func _mood_for(st: int) -> String:
	if mood != "":
		return mood
	if velocity.y > 560.0:
		return "scared"
	match st:
		1:
			return "determined"
		2:
			return "sleepy"
	return "happy"


# ---------------------------------------------------------------- water
func _water_points(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var wob := sin(time * 6.5) * 0.045
	for i in range(36):
		var ang := TAU * float(i) / 36.0
		var ca := cos(ang)
		var sa := sin(ang)
		var up := maxf(0.0, -sa)
		var taper := 1.0 - pow(up, 1.6) * 0.62
		var lift := pow(up, 2.2) * 15.0
		var rr := r * (1.0 + wob * (1.0 if i % 2 == 0 else -1.0) * 0.4)
		pts.append(Vector2(ca * rr * taper * (1.0 + wob), sa * rr * (1.0 - wob) - lift + 3.0))
	return pts


func _draw_water(ci: CanvasItem, origin: Vector2, k: float, a: float) -> void:
	var gs := pop * size * k
	Art.draw_glow(ci, origin, 40.0 * gs, Color(0.36, 0.82, 1.0, 0.30 * a))
	ci.draw_set_transform_matrix(_stretch_xform(origin, k))
	var body := _water_points(21.5)
	ci.draw_colored_polygon(Art.offset_points(body, Vector2(2.5, 5.0)), Color(0.05, 0.20, 0.30, 0.16 * a))
	ci.draw_polygon(body, Art.vgrad_colors(body, Color(0.42, 0.85, 1.0, 0.96 * a), Color(0.09, 0.50, 0.86, 0.97 * a)))
	# inner refraction pool
	var shift := sin(time * 3.6) * 2.0
	Art.draw_ellipse(ci, Vector2(shift, 13.0), 11.0, 6.5, Color(0.78, 0.97, 1.0, 0.45 * a), 18)
	# glossy highlights
	Art.draw_ellipse(ci, Vector2(-8.0, -6.0), 5.4, 7.6, Color(1, 1, 1, 0.82 * a), 16)
	ci.draw_circle(Vector2(-4.5, -14.5), 2.2, Color(1, 1, 1, 0.75 * a))
	ci.draw_circle(Vector2(10.0, 12.0), 1.9, Color(1, 1, 1, 0.5 * a))
	ci.draw_polyline(Art.closed(body), Color(0.05, 0.36, 0.62, 0.95 * a), 2.4, true)
	Art.draw_face(ci, Vector2(0, 5.0), 1.0, Color(0.04, 0.17, 0.30, a), _mood_for(0), _look(), blink)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


# ---------------------------------------------------------------- ice
func _draw_ice(ci: CanvasItem, origin: Vector2, k: float, a: float) -> void:
	var gs := pop * size * k
	Art.draw_glow(ci, origin, 40.0 * gs, Color(0.75, 0.95, 1.0, 0.36 * a))
	var xf := Transform2D.IDENTITY.scaled(Vector2(gs * (1.0 + squish * 0.3), gs * (1.0 - squish * 0.3)))
	xf.origin = origin
	ci.draw_set_transform_matrix(xf)
	var s := 21.5
	var c := 7.0
	var cube := PackedVector2Array([
		Vector2(-s + c, -s), Vector2(s - c, -s), Vector2(s, -s + c), Vector2(s, s - c),
		Vector2(s - c, s), Vector2(-s + c, s), Vector2(-s, s - c), Vector2(-s, -s + c),
	])
	ci.draw_colored_polygon(Art.offset_points(cube, Vector2(2.5, 5.0)), Color(0.06, 0.20, 0.34, 0.18 * a))
	ci.draw_polygon(cube, Art.vgrad_colors(cube, Color(0.90, 0.99, 1.0, 0.96 * a), Color(0.55, 0.84, 0.98, 0.96 * a)))
	# bevel facets
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(-s + c, -s), Vector2(s - c, -s), Vector2(s - c - 4, -s + 6), Vector2(-s + c + 4, -s + 6),
	]), Color(1, 1, 1, 0.65 * a))
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(-s, -s + c), Vector2(-s + 6, -s + c + 4), Vector2(-s + 6, s - c - 4), Vector2(-s, s - c),
	]), Color(1, 1, 1, 0.35 * a))
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(s, -s + c), Vector2(s, s - c), Vector2(s - c, s), Vector2(-s + c, s),
		Vector2(-s + c + 4, s - 6), Vector2(s - c - 4, s - 6), Vector2(s - 6, s - c - 4), Vector2(s - 6, -s + c + 4),
	]), Color(0.30, 0.64, 0.88, 0.40 * a))
	# travelling sheen
	var sweep := fmod(time * 0.9, 2.6) - 0.8
	if sweep > -0.7 and sweep < 0.7:
		var sx := sweep * s * 1.5
		ci.draw_line(Vector2(clampf(sx - 8.0, -s + 4, s - 4), -s + 5), Vector2(clampf(sx + 8.0, -s + 4, s - 4), s - 5), Color(1, 1, 1, 0.45 * a), 5.0, true)
	# frost specks
	ci.draw_circle(Vector2(12, -12), 1.6, Color(1, 1, 1, 0.9 * a))
	ci.draw_circle(Vector2(-13, 11), 1.3, Color(1, 1, 1, 0.7 * a))
	ci.draw_polyline(Art.closed(cube), Color(0.22, 0.54, 0.80, 0.98 * a), 2.6, true)
	Art.draw_face(ci, Vector2(0, 2.0), 1.0, Color(0.06, 0.22, 0.38, a), _mood_for(1), _look() * 0.6, blink)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


# ---------------------------------------------------------------- steam
const PUFFS := [
	[Vector2(-15, 4), 13.5], [Vector2(15, 4), 13.5], [Vector2(-8, -9), 15.0],
	[Vector2(9, -8), 14.0], [Vector2(0, 6), 15.5],
]


func _draw_steam(ci: CanvasItem, origin: Vector2, k: float, a: float) -> void:
	var gs := pop * size * k
	Art.draw_glow(ci, origin, 44.0 * gs, Color(1.0, 1.0, 1.0, 0.42 * a))
	var xf := Transform2D.IDENTITY.scaled(Vector2(gs, gs))
	xf.origin = origin
	ci.draw_set_transform_matrix(xf)
	var breathe := []
	for i in range(PUFFS.size()):
		breathe.append(1.0 + sin(time * 3.4 + float(i) * 1.3) * 0.06)
	for i in range(PUFFS.size()):
		var pf: Array = PUFFS[i]
		ci.draw_circle((pf[0] as Vector2) + Vector2(2.0, 5.0), float(pf[1]) * float(breathe[i]), Color(0.30, 0.42, 0.50, 0.12 * a))
	for i in range(PUFFS.size()):
		var pf: Array = PUFFS[i]
		ci.draw_circle(pf[0], float(pf[1]) * float(breathe[i]) + 2.2, Color(0.62, 0.72, 0.82, 0.9 * a))
	for i in range(PUFFS.size()):
		var pf: Array = PUFFS[i]
		ci.draw_circle(pf[0], float(pf[1]) * float(breathe[i]), Color(0.90, 0.94, 0.98, 0.98 * a))
	for hp in [[Vector2(-9, -12), 9.5], [Vector2(8, -11), 8.5], [Vector2(-1, -3), 12.0]]:
		ci.draw_circle(hp[0], float(hp[1]), Color(1, 1, 1, 0.95 * a))
	Art.draw_face(ci, Vector2(0, 2.0), 1.0, Color(0.24, 0.36, 0.46, a), _mood_for(2), _look() * 0.5, blink)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)

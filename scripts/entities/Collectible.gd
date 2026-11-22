class_name Collectible
extends Area2D

signal collected(item: Collectible)

var is_collected: bool = false

var _time: float = 0.0
var _burst: Array[Dictionary] = []
var _fade: float = 1.0
var _collect_t: float = 0.0


func _ready() -> void:
	collision_layer = 16
	collision_mask = 8
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 25.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	_time = randf_range(0.0, TAU)


func _on_body_entered(body: Node) -> void:
	if is_collected:
		return
	if body is Droplet and (body as Droplet).active:
		is_collected = true
		set_deferred("monitoring", false)
		for i in range(10):
			var a := TAU * float(i) / 10.0 + randf_range(-0.2, 0.2)
			_burst.append({
				"pos": Vector2.ZERO,
				"vel": Vector2.from_angle(a) * randf_range(65.0, 145.0),
				"life": 0.42,
				"max_life": 0.42,
				"r": randf_range(3.5, 6.5),
				"spark": i % 2 == 0,
			})
		collected.emit(self)


func _process(delta: float) -> void:
	_time += delta
	if is_collected:
		_collect_t += delta
		_fade = maxf(0.0, 1.0 - _collect_t / 0.22)
	for i in range(_burst.size() - 1, -1, -1):
		var b: Dictionary = _burst[i]
		b["life"] = float(b["life"]) - delta
		if float(b["life"]) <= 0.0:
			_burst.remove_at(i)
		else:
			b["vel"] = (b["vel"] as Vector2) * (1.0 - delta * 3.0)
			b["pos"] = (b["pos"] as Vector2) + (b["vel"] as Vector2) * delta
	if is_collected and _burst.is_empty() and _collect_t > 0.6:
		set_process(false)
	queue_redraw()


func _draw() -> void:
	if is_collected:
		var ring_t := clampf(_collect_t / 0.35, 0.0, 1.0)
		if ring_t < 1.0:
			draw_arc(Vector2.ZERO, lerpf(14.0, 52.0, ring_t), 0.0, TAU, 32, Color(1.0, 0.88, 0.36, 1.0 - ring_t), 4.0 * (1.0 - ring_t) + 0.5, true)
	for b in _burst:
		var a: float = clampf(float(b["life"]) / float(b["max_life"]), 0.0, 1.0)
		if bool(b.get("spark", false)):
			Art.draw_sparkle(self, b["pos"], float(b["r"]) * 1.6 * a, Color(1.0, 0.97, 0.75, a))
		else:
			draw_circle(b["pos"], float(b["r"]) * a, Color(1.0, 0.82, 0.24, a))

	if _fade <= 0.01:
		return

	var bob := Vector2(0.0, sin(_time * 3.0) * 4.0)
	var pulse := 1.0 + sin(_time * 4.2) * 0.05
	var grow := 1.0 + (1.0 - _fade) * 0.6
	Art.draw_sun(self, bob, 21.0 * pulse * grow, _time * 0.7, true, _fade)
	# Orbiting twinkles
	for i in range(3):
		var a := _time * 1.6 + TAU * float(i) / 3.0
		var tw := 0.5 + 0.5 * sin(_time * 5.0 + float(i) * 2.0)
		Art.draw_sparkle(self, bob + Vector2.from_angle(a) * 28.0, 3.5 + 2.5 * tw, Color(1.0, 0.98, 0.8, 0.85 * tw * _fade))

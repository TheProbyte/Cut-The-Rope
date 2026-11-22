class_name Collectible
extends Area2D

signal collected(item: Collectible)

var is_collected: bool = false

var _time: float = 0.0
var _burst: Array[Dictionary] = []
var _fade: float = 1.0


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
			})
		collected.emit(self)


func _process(delta: float) -> void:
	_time += delta
	if is_collected:
		_fade = maxf(0.0, _fade - delta * 5.0)
	for i in range(_burst.size() - 1, -1, -1):
		var b: Dictionary = _burst[i]
		b["life"] = float(b["life"]) - delta
		if float(b["life"]) <= 0.0:
			_burst.remove_at(i)
		else:
			b["pos"] = (b["pos"] as Vector2) + (b["vel"] as Vector2) * delta
	queue_redraw()


func _draw() -> void:
	for b in _burst:
		var a: float = clampf(float(b["life"]) / float(b["max_life"]), 0.0, 1.0)
		draw_circle(b["pos"], float(b["r"]) * a, Color(1.0, 0.85, 0.24, a))

	if _fade <= 0.01:
		return

	var bob := Vector2(0.0, sin(_time * 3.2) * 4.0)
	var pulse := 1.0 + sin(_time * 4.5) * 0.06
	var rot := _time * 0.85

	# Warm golden halo
	draw_circle(bob, 25.0 * pulse, Color(1.0, 0.86, 0.30, 0.22 * _fade))

	# 8 sun rays
	for i in range(8):
		var a := rot + TAU * float(i) / 8.0
		var tip := bob + Vector2.from_angle(a) * (20.5 * pulse)
		var l := bob + Vector2.from_angle(a - 0.24) * 12.0
		var r := bob + Vector2.from_angle(a + 0.24) * 12.0
		draw_colored_polygon(PackedVector2Array([l, tip, r]), Color(1.0, 0.76, 0.16, _fade))

	# Sun core
	draw_circle(bob, 12.5 * pulse, Color(1.0, 0.86, 0.26, _fade))
	draw_circle(bob + Vector2(-3.0, -3.5), 4.2 * pulse, Color(1.0, 0.97, 0.76, 0.85 * _fade))
	draw_arc(bob, 12.5 * pulse, 0.0, TAU, 20, Color(0.86, 0.56, 0.08, 0.8 * _fade), 1.8, true)

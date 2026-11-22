extends Node2D

var _queue: Array[Dictionary] = []
var _q_idx: int = 0
var _world: Node2D
var _droplet: Droplet
var _seedling: Seedling
var _fans: Array = []
var _sponges: Array = []
var _moving_platforms: Array = []
var _stars: int = 0
var _won: bool = false
var _failed: bool = false
var _fail_reason: String = ""
var _elapsed: float = 0.0
var _phase: int = 0
var _results: Array[String] = []
var _all_passed: bool = true


func _ready() -> void:
	_world = Node2D.new()
	add_child(_world)
	for wid in ["greenhouse", "kitchen"]:
		for i in range(LevelRegistry.get_level_count(wid)):
			_queue.append({"world": wid, "index": i})
	_start_next(0)


func _start_next(q_idx: int) -> void:
	_q_idx = q_idx
	_stars = 0
	_won = false
	_failed = false
	_fail_reason = ""
	_elapsed = 0.0
	_phase = 0
	_fans.clear()
	_sponges.clear()
	_moving_platforms.clear()

	if _droplet != null and is_instance_valid(_droplet):
		_droplet.freeze_for_end()
	for c in _world.get_children():
		_world.remove_child(c)
		c.queue_free()

	if q_idx >= _queue.size():
		_finish_all()
		return

	var item: Dictionary = _queue[q_idx]
	var data := LevelRegistry.get_level_meta(String(item["world"]), int(item["index"]))
	var built := LevelLoader.build_level(_world, data)
	_droplet = built["droplet"]
	_seedling = built["seedling"]
	_fans = built["fans"]
	_sponges = built["sponges"]
	_moving_platforms = built["moving_platforms"]

	_droplet.lost.connect(func(r: String):
		_failed = true
		_fail_reason = r
	)
	_seedling.watered.connect(func():
		_won = true
	)
	for col in built["collectibles"]:
		(col as Collectible).collected.connect(func(_c):
			_stars += 1
		)
	for dr in built["drains"]:
		(dr as Drain).droplet_drained.connect(func(_d):
			_failed = true
			_fail_reason = "drain"
		)
	for hp in built["hot_plates"]:
		(hp as HotPlate).droplet_sizzled.connect(func(_d):
			_failed = true
			_fail_reason = "hotplate"
		)


func _physics_process(delta: float) -> void:
	if _droplet == null or not is_instance_valid(_droplet):
		return
	_elapsed += delta
	_drive_level_ai()

	var lvl_num := _q_idx + 1
	if _won:
		var line := "PASS L%02d: bloomed in %.2fs with %d/3 stars" % [lvl_num, _elapsed, _stars]
		print(line)
		_results.append(line)
		if _stars < 3:
			_all_passed = false
			for child in _world.get_children():
				if child is Collectible and not (child as Collectible).is_collected:
					print("  MISSED STAR at %s" % str((child as Collectible).global_position))
		_start_next(_q_idx + 1)
	elif _failed or _elapsed > 20.0:
		var reason := "%s at pos %s vel %s state %d phase %d" % [
			_fail_reason if _failed else "timeout",
			str(_droplet.global_position),
			str(_droplet.linear_velocity),
			int(_droplet.state),
			_phase,
		]
		var line := "FAIL L%02d: %s (stars=%d)" % [lvl_num, reason, _stars]
		print(line)
		_results.append(line)
		_all_passed = false
		_start_next(_q_idx + 1)


func _cycle_to(target: Droplet.State) -> void:
	var guard := 0
	while _droplet.state != target and guard < 4:
		if not _droplet.cycle_state():
			break
		guard += 1


func _drive_level_ai() -> void:
	var p := _droplet.global_position
	match _q_idx:
		0: # L01: Morning Dew
			if _phase == 0 and p.y > 730.0 and p.x > 250.0 and p.x < 430.0:
				_cycle_to(Droplet.State.ICE)
				_phase = 1
			elif _phase == 1 and p.y > 955.0:
				_cycle_to(Droplet.State.WATER)
				_phase = 2
		1: # L02: Rising Mist
			if _phase == 0 and _elapsed > 0.25:
				_cycle_to(Droplet.State.STEAM)
				_phase = 1
			elif _phase == 1 and p.x > 505.0:
				_cycle_to(Droplet.State.WATER)
				_phase = 2
		2: # L03: Through the Grate
			if _phase == 0 and p.x > 195.0:
				_cycle_to(Droplet.State.ICE)
				_phase = 1
			elif _phase == 1 and p.x > 460.0:
				_cycle_to(Droplet.State.WATER)
				_phase = 2
			elif _phase == 2 and p.y > 760.0 and p.x < 445.0:
				_cycle_to(Droplet.State.STEAM)
				_phase = 3
			elif _phase == 3 and p.x < 210.0 and _stars >= 3:
				_cycle_to(Droplet.State.WATER)
				_phase = 4
		3: # L04: Warm Glow
			if _phase == 0 and p.x > 515.0 and p.y < 320.0:
				_cycle_to(Droplet.State.WATER)
				_phase = 1
		4: # L05: Frost Pocket
			if _phase == 0 and _elapsed > 0.2:
				_cycle_to(Droplet.State.STEAM)
				_phase = 1
			elif _phase == 1 and p.y > 910.0 and p.x > 560.0:
				_cycle_to(Droplet.State.WATER)
				_phase = 2
		5: # L06: Gentle Breeze
			if _phase == 0 and _elapsed > 0.2:
				_cycle_to(Droplet.State.STEAM)
				_phase = 1
			elif _phase == 1 and p.y < 380.0:
				(_fans[0] as Fan).toggle()
				_phase = 2
			elif _phase == 2 and p.x > 545.0:
				(_fans[0] as Fan).toggle()
				_cycle_to(Droplet.State.WATER)
				_phase = 3
		6: # L07: Cold Pipe
			if _phase == 0 and _elapsed > 0.2:
				_cycle_to(Droplet.State.STEAM)
				_phase = 1
		7: # L08: Crosswinds
			if _phase == 0 and _elapsed > 0.2:
				_cycle_to(Droplet.State.STEAM)
				(_fans[0] as Fan).toggle()
				_phase = 1
			elif _phase == 1 and p.x > 520.0:
				(_fans[0] as Fan).toggle()
				_phase = 2
			elif _phase == 2 and p.y < 365.0:
				(_fans[1] as Fan).toggle()
				_phase = 3
			elif _phase == 3 and p.x < 200.0:
				(_fans[1] as Fan).toggle()
				_cycle_to(Droplet.State.WATER)
				_phase = 4
		8: # L09: Thermal Cycle
			if _phase == 0 and p.y > 955.0:
				_cycle_to(Droplet.State.WATER)
				_phase = 1
		9: # L10: Glasshouse Finale
			if _phase == 0 and p.x > 185.0:
				_cycle_to(Droplet.State.ICE)
				_phase = 1
			elif _phase == 1 and p.y > 620.0 and _droplet.is_steam():
				(_fans[0] as Fan).toggle()
				_phase = 2
			elif _phase == 2 and p.x < 245.0 and _droplet.is_water():
				(_fans[0] as Fan).toggle()
				_phase = 3
		10: # L11: Soak It Up
			if _phase == 0 and (_sponges[0] as Sponge).has_water():
				(_sponges[0] as Sponge).squeeze()
				_phase = 1
		11: # L12: Sizzle Stop
			if _phase == 0 and _elapsed > 0.2:
				_cycle_to(Droplet.State.STEAM)
				_phase = 1
			elif _phase == 1 and p.x > 538.0:
				_cycle_to(Droplet.State.WATER)
				_phase = 2
		12: # L13: Sponge & Ice
			if _phase == 0 and p.x > 195.0:
				_cycle_to(Droplet.State.ICE)
				_phase = 1
			elif _phase == 1 and p.x > 365.0:
				_cycle_to(Droplet.State.WATER)
				_phase = 2
			elif _phase == 2 and (_sponges[1] as Sponge).has_water():
				(_sponges[1] as Sponge).squeeze()
				_phase = 3
		13: # L14: Steam Kettle
			if _phase == 0 and (_sponges[0] as Sponge).has_water():
				(_sponges[0] as Sponge).squeeze()
				_phase = 1
		14: # L15: Sliding Tray
			if _phase == 0 and (_sponges[0] as Sponge).has_water():
				(_sponges[0] as Sponge).squeeze()
				_phase = 1
		15: # L16: Pantry Timing
			var mp := _moving_platforms[0] as MovingPlatform
			var mp_pos := mp.get_platform_position()
			var mp_vel := mp.get_platform_velocity()
			if _phase == 0 and (_sponges[0] as Sponge).has_water() and mp_vel.x > 10.0 and mp_pos.x > 190.0 and mp_pos.x < 225.0:
				(_sponges[0] as Sponge).squeeze()
				_phase = 1
			elif _phase == 1 and (_sponges[1] as Sponge).has_water():
				(_sponges[1] as Sponge).squeeze()
				_phase = 2
		16: # L17: Drafty Stove
			if _phase == 0 and _elapsed > 0.2:
				_cycle_to(Droplet.State.STEAM)
				_phase = 1
			elif _phase == 1 and p.y < 365.0:
				(_fans[0] as Fan).toggle()
				_phase = 2
			elif _phase == 2 and p.y > 900.0:
				_cycle_to(Droplet.State.WATER)
				_phase = 3
		17: # L18: Double Sponge
			var mp := _moving_platforms[0] as MovingPlatform
			var mp_pos := mp.get_platform_position()
			var mp_vel := mp.get_platform_velocity()
			if _phase == 0 and (_sponges[0] as Sponge).has_water() and mp_vel.x < -10.0 and mp_pos.x < 325.0:
				(_sponges[0] as Sponge).squeeze()
				_phase = 1
			elif _phase == 1 and (_sponges[1] as Sponge).has_water():
				(_sponges[1] as Sponge).squeeze()
				_phase = 2
		18: # L19: Chef's Contraption
			var mp := _moving_platforms[0] as MovingPlatform
			var mp_pos := mp.get_platform_position()
			var mp_vel := mp.get_platform_velocity()
			if _phase == 0 and (_sponges[0] as Sponge).has_water() and mp_vel.x > 10.0 and mp_pos.x > 495.0:
				(_sponges[0] as Sponge).squeeze()
				_phase = 1
			elif _phase == 1 and (_sponges[1] as Sponge).has_water():
				(_sponges[1] as Sponge).squeeze()
				_phase = 2
			elif _phase == 2 and p.y > 940.0:
				_cycle_to(Droplet.State.WATER)
				_phase = 3
		19: # L20: Grand Kitchen Finale
			var mp := _moving_platforms[0] as MovingPlatform
			var mp_pos := mp.get_platform_position()
			var mp_vel := mp.get_platform_velocity()
			if _phase == 0 and p.x > 185.0:
				_cycle_to(Droplet.State.ICE)
				_phase = 1
			elif _phase == 1 and p.y > 620.0 and _droplet.is_steam():
				(_fans[0] as Fan).toggle()
				_phase = 2
			elif _phase == 2 and p.x < 245.0 and _droplet.is_water():
				(_fans[0] as Fan).toggle()
				_phase = 3
			elif _phase == 3 and (_sponges[1] as Sponge).has_water() and mp_vel.x < -10.0 and mp_pos.x < 235.0:
				(_sponges[1] as Sponge).squeeze()
				_phase = 4


func _finish_all() -> void:
	print("=== 20-LEVEL VERIFICATION SUMMARY ===")
	for r in _results:
		print(r)
	get_tree().quit(0 if _all_passed else 1)

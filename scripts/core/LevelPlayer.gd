class_name LevelPlayer
extends Node2D

signal back_to_level_select(world_id: String)

const HUD_SCENE := preload("res://scenes/ui/HUD.tscn")
const PAUSE_SCENE := preload("res://scenes/ui/PauseModal.tscn")
const RESULT_SCENE := preload("res://scenes/ui/ResultModal.tscn")

var world_id: String = "greenhouse"
var level_index: int = 0

var _bg: GreenhouseBackground
var _camera: Camera2D
var _level_data: Dictionary = {}
var _playfield: Node2D
var _droplet: Droplet
var _seedling: Seedling
var _fans: Array = []
var _sponges: Array = []
var _stars_collected: int = 0
var _finished: bool = false
var _hud: HUD
var _pause_modal: PauseModal
var _result_modal: ResultModal
var _tap_ripples: Array[Dictionary] = []
var _shake_amp: float = 0.0
var _hitstop_timer: float = 0.0


func _ready() -> void:
	_camera = Camera2D.new()
	_camera.position = Vector2(360.0, 640.0)
	add_child(_camera)

	_bg = GreenhouseBackground.new()
	add_child(_bg)

	_playfield = Node2D.new()
	add_child(_playfield)

	_hud = HUD_SCENE.instantiate()
	add_child(_hud)
	_hud.pause_pressed.connect(_on_pause_pressed)
	_hud.restart_pressed.connect(restart_level)

	_pause_modal = PAUSE_SCENE.instantiate()
	add_child(_pause_modal)
	_pause_modal.resumed.connect(_on_resumed)
	_pause_modal.restarted.connect(restart_level)
	_pause_modal.level_select_requested.connect(_exit_to_level_select)

	_result_modal = RESULT_SCENE.instantiate()
	add_child(_result_modal)
	_result_modal.next_requested.connect(_next_level)
	_result_modal.replay_requested.connect(restart_level)
	_result_modal.level_select_requested.connect(_exit_to_level_select)

	load_level(world_id, level_index)


func load_level(p_world_id: String, p_level_index: int) -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	world_id = p_world_id
	level_index = p_level_index
	_finished = false
	_stars_collected = 0
	_fans.clear()
	_sponges.clear()
	_tap_ripples.clear()
	_shake_amp = 0.0
	_hitstop_timer = 0.0

	if _pause_modal != null:
		_pause_modal.visible = false
	if _result_modal != null:
		_result_modal.visible = false

	if _droplet != null and is_instance_valid(_droplet):
		_droplet.freeze_for_end()
	for child in _playfield.get_children():
		_playfield.remove_child(child)
		child.queue_free()

	_level_data = LevelRegistry.get_level_meta(world_id, level_index)
	if _level_data.is_empty():
		push_error("Could not load level %s #%d" % [world_id, level_index])
		return

	var built := LevelLoader.build_level(_playfield, _level_data)
	_bg.set_theme(String(built.get("theme", world_id)))
	_droplet = built["droplet"]
	_seedling = built["seedling"]
	_fans = built["fans"]
	_sponges = built["sponges"]

	_droplet.state_changed.connect(_on_droplet_state_changed)
	_droplet.lost.connect(_on_droplet_lost)
	_seedling.watered.connect(_on_seedling_watered)

	for col in built["collectibles"]:
		(col as Collectible).collected.connect(_on_collectible_collected)

	for dr in built["drains"]:
		(dr as Drain).droplet_drained.connect(_on_droplet_drained)

	for hp in built["hot_plates"]:
		(hp as HotPlate).droplet_sizzled.connect(_on_droplet_sizzled)

	for gp in built["glass_panes"]:
		(gp as GlassPane).shattered_impact.connect(_on_glass_shattered)

	var display_num := level_index + 1 + (10 if world_id == "kitchen" else 0)
	_hud.configure_level(
		display_num,
		String(_level_data.get("title", "Level")),
		String(_level_data.get("hint", ""))
	)
	_hud.set_active_state(int(_droplet.state))


func restart_level() -> void:
	get_tree().paused = false
	load_level(world_id, level_index)


func _next_level() -> void:
	var count := LevelRegistry.get_level_count(world_id)
	if level_index + 1 < count:
		load_level(world_id, level_index + 1)
	elif world_id == "greenhouse" and LevelRegistry.get_level_count("kitchen") > 0:
		load_level("kitchen", 0)
	else:
		_exit_to_level_select()


func _exit_to_level_select() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	back_to_level_select.emit(world_id)


func _on_pause_pressed() -> void:
	if _finished:
		return
	get_tree().paused = true
	_pause_modal.open_modal()


func _on_resumed() -> void:
	_pause_modal.visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if _finished or get_tree().paused:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_handle_playfield_tap(get_global_mouse_position())
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			if key.keycode == KEY_SPACE:
				if _droplet != null:
					_droplet.cycle_state()
			elif key.keycode == KEY_R:
				restart_level()


func _handle_playfield_tap(pos: Vector2) -> void:
	if pos.y < 92.0:
		return
	# First check tappable Sponges so squeezing never switches state
	for s in _sponges:
		var sponge := s as Sponge
		if is_instance_valid(sponge) and sponge.contains_point(pos):
			sponge.squeeze()
			_tap_ripples.append({"pos": sponge.global_position, "r": 16.0, "life": 0.30, "max_life": 0.30, "col": Color(0.24, 0.78, 0.98)})
			return

	# Next check tappable Fans
	for f in _fans:
		var fan := f as Fan
		if is_instance_valid(fan) and fan.contains_point(pos):
			fan.toggle()
			_tap_ripples.append({"pos": fan.global_position, "r": 16.0, "life": 0.28, "max_life": 0.28, "col": Color(0.32, 0.80, 0.68)})
			return

	# Otherwise cycle droplet state: WATER -> ICE -> STEAM -> WATER
	if _droplet != null and is_instance_valid(_droplet):
		if _droplet.cycle_state():
			_tap_ripples.append({"pos": pos, "r": 10.0, "life": 0.30, "max_life": 0.30, "col": _state_color(_droplet.state)})


func _state_color(st: Droplet.State) -> Color:
	match st:
		Droplet.State.WATER:
			return Color(0.24, 0.74, 0.96)
		Droplet.State.ICE:
			return Color(0.68, 0.92, 1.0)
		_:
			return Color(0.95, 0.98, 1.0)


func _on_glass_shattered(pos: Vector2) -> void:
	_shake_amp = 6.5
	_hitstop_timer = 0.035
	Engine.time_scale = 0.12
	_tap_ripples.append({"pos": pos, "r": 18.0, "life": 0.28, "max_life": 0.28, "col": Color(0.76, 0.96, 1.0)})


func _on_droplet_state_changed(new_state: int, _forced: bool) -> void:
	_hud.set_active_state(new_state)


func _on_collectible_collected(item: Collectible) -> void:
	var slot_idx := _stars_collected
	_stars_collected = mini(3, _stars_collected + 1)
	_hud.animate_star_collect(item.global_position, slot_idx)
	AudioManager.play_sfx("collect_star", 1.0 + float(_stars_collected - 1) * 0.12)


func _on_seedling_watered() -> void:
	if _finished:
		return
	_finished = true
	var level_id := String(_level_data.get("id", "%s_%02d" % [world_id, level_index + 1]))
	SaveManager.record_completion(level_id, _stars_collected)
	var has_next := (level_index + 1) < LevelRegistry.get_level_count(world_id)
	if not has_next and world_id == "greenhouse" and LevelRegistry.get_level_count("kitchen") > 0:
		has_next = true
	var timer := get_tree().create_timer(1.0)
	timer.timeout.connect(func():
		if is_instance_valid(self) and _finished:
			_result_modal.show_win(_stars_collected, has_next)
	)


func _on_droplet_drained(droplet: Droplet) -> void:
	if _finished:
		return
	droplet.freeze_for_end()
	_trigger_fail("drain")


func _on_droplet_sizzled(droplet: Droplet) -> void:
	if _finished:
		return
	droplet.freeze_for_end()
	droplet.visible = false
	_shake_amp = 5.0
	_trigger_fail("hotplate")


func _on_droplet_lost(reason: String) -> void:
	if _finished:
		return
	if _droplet != null and is_instance_valid(_droplet):
		_droplet.freeze_for_end()
	_trigger_fail(reason)


func _trigger_fail(reason: String) -> void:
	if _finished:
		return
	_finished = true
	if reason == "hotplate":
		AudioManager.play_sfx("hotplate_sizzle")
	else:
		AudioManager.play_sfx("fail_drain")
	var timer := get_tree().create_timer(0.45)
	timer.timeout.connect(func():
		if is_instance_valid(self) and _finished:
			_result_modal.show_fail(reason)
	)


func _process(delta: float) -> void:
	if _hitstop_timer > 0.0:
		_hitstop_timer -= delta / maxf(Engine.time_scale, 0.05)
		if _hitstop_timer <= 0.0:
			Engine.time_scale = 1.0

	if _shake_amp > 0.05:
		_shake_amp = lerpf(_shake_amp, 0.0, clampf(delta * 14.0, 0.0, 1.0))
		_camera.offset = Vector2(randf_range(-_shake_amp, _shake_amp), randf_range(-_shake_amp, _shake_amp))
	elif _camera.offset != Vector2.ZERO:
		_camera.offset = Vector2.ZERO

	if not _tap_ripples.is_empty():
		for i in range(_tap_ripples.size() - 1, -1, -1):
			var rp: Dictionary = _tap_ripples[i]
			rp["life"] = float(rp["life"]) - delta
			rp["r"] = float(rp["r"]) + delta * 155.0
			if float(rp["life"]) <= 0.0:
				_tap_ripples.remove_at(i)
		queue_redraw()


func _draw() -> void:
	for rp in _tap_ripples:
		var a: float = clampf(float(rp["life"]) / float(rp["max_life"]), 0.0, 1.0)
		var col: Color = rp["col"]
		col.a = a * 0.55
		draw_arc(rp["pos"], float(rp["r"]), 0.0, TAU, 28, col, 3.0, true)

class_name LevelPlayer
extends Node2D
## Runs a single level: builds it, stages the intro, routes input, and
## choreographs win / fail sequences, restarts and level-to-level transitions.

signal back_to_level_select(world_id: String)

const HUD_SCENE := preload("res://scenes/ui/HUD.tscn")
const PAUSE_SCENE := preload("res://scenes/ui/PauseModal.tscn")
const RESULT_SCENE := preload("res://scenes/ui/ResultModal.tscn")

const CENTER := Vector2(360.0, 640.0)

var world_id: String = "greenhouse"
var level_index: int = 0

var _bg: WorldBackground
var _camera: Camera2D
var _level_data: Dictionary = {}
var _playfield: Node2D
var _droplet: Droplet
var _seedling: Seedling
var _spout: SpawnSpout
var _fans: Array = []
var _sponges: Array = []
var _stars_collected: int = 0
var _finished: bool = false
var _intro_running: bool = false
var _hud: HUD
var _pause_modal: PauseModal
var _result_modal: ResultModal
var _tap_ripples: Array[Dictionary] = []
var _shake_amp: float = 0.0
var _hitstop_timer: float = 0.0
var _slowmo_timer: float = 0.0
var _cam_target_zoom: float = 1.0
var _cam_target_pos: Vector2 = CENTER
var _load_serial: int = 0
var _has_tapped: bool = false
var _level_time: float = 0.0
var _fx_layer: Node2D


func _ready() -> void:
	_camera = Camera2D.new()
	_camera.position = CENTER
	add_child(_camera)
	_camera.make_current()

	_bg = WorldBackground.new()
	add_child(_bg)

	_playfield = Node2D.new()
	add_child(_playfield)

	_fx_layer = Node2D.new()
	_fx_layer.z_index = 50
	add_child(_fx_layer)
	_fx_layer.draw.connect(_draw_fx)

	_hud = HUD_SCENE.instantiate()
	add_child(_hud)
	_hud.pause_pressed.connect(_on_pause_pressed)
	_hud.restart_pressed.connect(restart_level)

	_pause_modal = PAUSE_SCENE.instantiate()
	add_child(_pause_modal)
	_pause_modal.resumed.connect(_on_resumed)
	_pause_modal.restarted.connect(func():
		_pause_modal.close_modal()
		restart_level()
	)
	_pause_modal.level_select_requested.connect(_exit_to_level_select)

	_result_modal = RESULT_SCENE.instantiate()
	add_child(_result_modal)
	_result_modal.next_requested.connect(_next_level)
	_result_modal.replay_requested.connect(restart_level)
	_result_modal.level_select_requested.connect(_exit_to_level_select)

	load_level(world_id, level_index, false)


# ================================================================ loading
func load_level(p_world_id: String, p_level_index: int, quick: bool = false) -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	var world_changed := p_world_id != world_id or _level_data.is_empty()
	world_id = p_world_id
	level_index = p_level_index
	_finished = false
	_stars_collected = 0
	_fans.clear()
	_sponges.clear()
	_tap_ripples.clear()
	_shake_amp = 0.0
	_hitstop_timer = 0.0
	_slowmo_timer = 0.0
	_level_time = 0.0
	_load_serial += 1
	_cam_target_zoom = 1.0
	_cam_target_pos = CENTER
	_camera.zoom = Vector2.ONE
	_camera.position = CENTER
	_camera.offset = Vector2.ZERO

	_pause_modal.visible = false
	_result_modal.hide_now()

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
	if AudioManager.has_method("play_music"):
		AudioManager.play_music(String(built.get("theme", world_id)))
	_droplet = built["droplet"]
	_seedling = built["seedling"]
	_fans = built["fans"]
	_sponges = built["sponges"]
	_spout = built.get("spout", null)

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

	var display_num := LevelRegistry.get_display_number(world_id, level_index)
	var title := String(_level_data.get("title", "Level"))
	_hud.configure_level(display_num, title, String(_level_data.get("hint", "")), not quick)
	_hud.set_active_state(int(_droplet.state))
	_hud.set_stars(0)
	if not quick:
		var w := LevelRegistry.get_world(world_id)
		_hud.show_level_banner(display_num, title, String(w.get("name", "")) if world_changed else "")
	_has_tapped = false
	if level_index == 0 and world_id == String(LevelRegistry.get_worlds()[0].get("id", "")):
		_hud.show_tap_tutorial(true)
	else:
		_hud.show_tap_tutorial(false)

	_play_intro(quick)


func _play_intro(quick: bool) -> void:
	_intro_running = true
	_droplet.hold_for_intro()
	var serial := _load_serial
	var spread := 0.16 if quick else 0.30
	var dur := 0.26 if quick else 0.42
	var drop := 22.0 if quick else 38.0
	for child in _playfield.get_children():
		if child == _droplet or not (child is Node2D):
			continue
		var n := child as Node2D
		var target := n.position
		var delay := clampf((target.y - 120.0) / 1000.0, 0.0, 1.0) * spread
		if child is Seedling:
			delay = spread
		n.position = target + Vector2(0, -drop)
		n.modulate.a = 0.0
		var tw := n.create_tween()
		tw.tween_interval(delay)
		tw.set_parallel(true)
		tw.tween_property(n, "position", target, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(n, "modulate:a", 1.0, dur * 0.6)

	var release_at := spread + dur * 0.6
	get_tree().create_timer(maxf(0.0, release_at - 0.3)).timeout.connect(func():
		if serial == _load_serial and _spout != null and is_instance_valid(_spout):
			_spout.drip()
	)
	get_tree().create_timer(release_at).timeout.connect(func():
		if serial != _load_serial or not is_instance_valid(_droplet):
			return
		_droplet.release_from_intro()
		_intro_running = false
		AudioManager.play_sfx("level_start", 1.0, -6.0)
	)


func restart_level() -> void:
	if _intro_running and _level_time < 0.15:
		return
	AudioManager.play_sfx("ui_whoosh", 1.2, -8.0)
	var center := _hud.get_restart_center()
	TransitionLayer.run(func(): load_level(world_id, level_index, true), WorldBackground.curtain_color(world_id), center, true)


func _next_level() -> void:
	var nxt := LevelRegistry.get_next_level(world_id, level_index)
	if nxt.is_empty():
		_exit_to_level_select()
		return
	var wid := String(nxt["world"])
	var idx := int(nxt["index"])
	if not SaveManager.is_level_unlocked(wid, idx):
		_exit_to_level_select()
		return
	AudioManager.play_sfx("ui_whoosh", 1.0, -6.0)
	TransitionLayer.run(func(): load_level(wid, idx, false), WorldBackground.curtain_color(wid), _result_modal.get_next_center())


func _exit_to_level_select() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	back_to_level_select.emit(world_id)


# ================================================================ pause / system
func _on_pause_pressed() -> void:
	if _finished or get_tree().paused:
		return
	get_tree().paused = true
	_pause_modal.open_modal(LevelRegistry.get_display_number(world_id, level_index), String(_level_data.get("title", "")))


func _on_resumed() -> void:
	_pause_modal.close_modal()
	get_tree().paused = false


## Android back button: close what's open, otherwise pause.
func handle_back() -> void:
	if _result_modal.visible:
		_exit_to_level_select()
	elif get_tree().paused:
		_on_resumed()
	else:
		_on_pause_pressed()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and not _finished and not get_tree().paused:
			_on_pause_pressed()


# ================================================================ input
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
			match key.keycode:
				KEY_SPACE:
					if _droplet != null and not _intro_running:
						_droplet.cycle_state()
				KEY_R:
					restart_level()
				KEY_ESCAPE, KEY_P:
					_on_pause_pressed()


func _handle_playfield_tap(pos: Vector2) -> void:
	if _intro_running:
		return
	_hud.dismiss_hint()
	for s in _sponges:
		var sponge := s as Sponge
		if is_instance_valid(sponge) and sponge.contains_point(pos):
			sponge.squeeze()
			SaveManager.haptic(15)
			_add_ripple(sponge.global_position, Color(0.24, 0.78, 0.98))
			return
	for f in _fans:
		var fan := f as Fan
		if is_instance_valid(fan) and fan.contains_point(pos):
			fan.toggle()
			SaveManager.haptic(12)
			_add_ripple(fan.global_position, Color(0.32, 0.80, 0.68))
			return
	if _droplet != null and is_instance_valid(_droplet):
		if _droplet.cycle_state():
			_add_ripple(pos, Art.state_color(int(_droplet.state)))
			if not _has_tapped:
				_has_tapped = true
				_hud.show_tap_tutorial(false)
		else:
			_add_ripple(pos, Color(1.0, 0.5, 0.4))
			_shake_amp = maxf(_shake_amp, 2.5)


func _add_ripple(pos: Vector2, col: Color) -> void:
	_tap_ripples.append({"pos": pos, "r": 8.0, "life": 0.38, "max_life": 0.38, "col": col})


# ================================================================ events
func _on_glass_shattered(pos: Vector2) -> void:
	_shake_amp = 7.0
	_hitstop_timer = 0.045
	Engine.time_scale = 0.12
	SaveManager.haptic(35)
	_add_ripple(pos, Color(0.76, 0.96, 1.0))


func _on_droplet_state_changed(new_state: int, forced: bool) -> void:
	_hud.set_active_state(new_state)
	SaveManager.haptic(18 if forced else 10)


func _on_collectible_collected(item: Collectible) -> void:
	var slot_idx := _stars_collected
	_stars_collected = mini(3, _stars_collected + 1)
	_hud.animate_star_collect(_world_to_screen(item.global_position), slot_idx)
	AudioManager.play_sfx("collect_star", 1.0 + float(_stars_collected - 1) * 0.12)
	SaveManager.haptic(20)


func _on_seedling_watered() -> void:
	if _finished:
		return
	_finished = true
	var level_id := String(_level_data.get("id", "%s_%02d" % [world_id, level_index + 1]))
	var prev_best := SaveManager.get_stars(level_id)
	var was_completed := SaveManager.is_completed(level_id)
	SaveManager.record_completion(level_id, _stars_collected)
	var nxt := LevelRegistry.get_next_level(world_id, level_index)
	var has_next := not nxt.is_empty() and SaveManager.is_level_unlocked(String(nxt["world"]), int(nxt["index"]))
	var new_world := ""
	if has_next and String(nxt["world"]) != world_id and not was_completed:
		new_world = String(LevelRegistry.get_world(String(nxt["world"])).get("name", ""))

	_hud.show_tap_tutorial(false)
	_hud.dismiss_hint()
	# Slow-mo + camera push-in on the seedling
	_slowmo_timer = 0.55
	Engine.time_scale = 0.45
	var sp := _seedling.global_position + Vector2(0, -30)
	_cam_target_zoom = 1.28
	_cam_target_pos = CENTER.lerp(sp, 0.75)
	SaveManager.haptic(45)
	AudioManager.play_sfx("win_jingle", 1.0, -4.0)
	if AudioManager.has_method("duck_music"):
		AudioManager.duck_music(-10.0, 2.2)

	var serial := _load_serial
	get_tree().create_timer(1.25, true, false, true).timeout.connect(func():
		if serial == _load_serial and is_instance_valid(self) and _finished:
			_result_modal.show_win(_stars_collected, has_next, maxi(prev_best, _stars_collected) > prev_best and was_completed,
				LevelRegistry.get_display_number(world_id, level_index), String(_level_data.get("title", "")), new_world)
	)


func _on_droplet_drained(droplet: Droplet) -> void:
	if _finished:
		return
	droplet.freeze_for_end()
	droplet.play_end_anim("drain")
	_trigger_fail("drain")


func _on_droplet_sizzled(droplet: Droplet) -> void:
	if _finished:
		return
	droplet.freeze_for_end()
	droplet.play_end_anim("sizzle")
	_shake_amp = 5.0
	_trigger_fail("hotplate")


func _on_droplet_lost(reason: String) -> void:
	if _finished:
		return
	if _droplet != null and is_instance_valid(_droplet):
		_droplet.freeze_for_end()
		_droplet.play_end_anim("evaporated" if reason == "evaporated" else "fell")
	_trigger_fail(reason)


func _trigger_fail(reason: String) -> void:
	if _finished:
		return
	_finished = true
	_hud.dismiss_hint()
	match reason:
		"hotplate":
			AudioManager.play_sfx("hotplate_sizzle")
		"evaporated":
			AudioManager.play_sfx("evaporate")
		_:
			AudioManager.play_sfx("fail_drain")
	AudioManager.play_sfx("fail_splat", 1.0, -6.0)
	SaveManager.haptic(60)
	_shake_amp = maxf(_shake_amp, 4.0)
	var serial := _load_serial
	get_tree().create_timer(0.75, true, false, true).timeout.connect(func():
		if serial == _load_serial and is_instance_valid(self) and _finished:
			_result_modal.show_fail(reason, LevelRegistry.get_display_number(world_id, level_index), String(_level_data.get("title", "")))
	)


func _world_to_screen(p: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * p


# ================================================================ frame
func _process(delta: float) -> void:
	var real_dt := delta / maxf(Engine.time_scale, 0.05)
	if not get_tree().paused:
		_level_time += real_dt

	if _hitstop_timer > 0.0:
		_hitstop_timer -= real_dt
		if _hitstop_timer <= 0.0 and _slowmo_timer <= 0.0:
			Engine.time_scale = 1.0
	if _slowmo_timer > 0.0:
		_slowmo_timer -= real_dt
		if _slowmo_timer <= 0.0:
			Engine.time_scale = 1.0

	# Smooth camera push-in
	var k := clampf(real_dt * 3.2, 0.0, 1.0)
	_camera.zoom = _camera.zoom.lerp(Vector2(_cam_target_zoom, _cam_target_zoom), k)
	_camera.position = _camera.position.lerp(_cam_target_pos, k)

	if _shake_amp > 0.05:
		_shake_amp = lerpf(_shake_amp, 0.0, clampf(real_dt * 12.0, 0.0, 1.0))
		_camera.offset = Vector2(randf_range(-_shake_amp, _shake_amp), randf_range(-_shake_amp, _shake_amp))
	elif _camera.offset != Vector2.ZERO:
		_camera.offset = Vector2.ZERO

	if not _tap_ripples.is_empty():
		for i in range(_tap_ripples.size() - 1, -1, -1):
			var rp: Dictionary = _tap_ripples[i]
			rp["life"] = float(rp["life"]) - real_dt
			var prog := 1.0 - float(rp["life"]) / float(rp["max_life"])
			rp["r"] = lerpf(8.0, 70.0, 1.0 - pow(1.0 - clampf(prog, 0.0, 1.0), 3.0))
			if float(rp["life"]) <= 0.0:
				_tap_ripples.remove_at(i)
		_fx_layer.queue_redraw()


func _draw_fx() -> void:
	for rp in _tap_ripples:
		var a: float = clampf(float(rp["life"]) / float(rp["max_life"]), 0.0, 1.0)
		var col: Color = rp["col"]
		_fx_layer.draw_arc(rp["pos"], float(rp["r"]), 0.0, TAU, 40, Color(col.r, col.g, col.b, a * 0.7), 4.0 * a + 1.0, true)
		_fx_layer.draw_arc(rp["pos"], float(rp["r"]) * 0.6, 0.0, TAU, 32, Color(1, 1, 1, a * 0.5), 2.0 * a + 0.5, true)

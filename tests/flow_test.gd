extends Node
## Dev-only end-to-end flow test through the real Main scene.
## godot res://tests/FlowTest.tscn -- <out_dir>      (screenshots need a display)
## godot --headless --fixed-fps 60 res://tests/FlowTest.tscn   (CI smoke test)

var _out := "user://"
var _main: Node
var _t := 0.0
var _step := 0
var _step_t := 0.0
var _phase := 0
var _shots_taken := {}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveManager.reset_progress()
	_main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(_main)


func _shot(name: String) -> void:
	if _shots_taken.has(name):
		return
	_shots_taken[name] = true
	if DisplayServer.get_name() == "headless":
		return
	var img := get_viewport().get_texture().get_image()
	img.save_png(_out.path_join(name + ".png"))
	print("shot ", name)


func _screen() -> Node:
	return _main._current_screen


func _next(name: String) -> void:
	print("step ", _step, " -> ", name, " at ", snappedf(_t, 0.01))
	_step += 1
	_step_t = 0.0


func _process(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.05)
	_t += real
	_step_t += real
	match _step:
		0:
			if _step_t > 1.6:
				_shot("01_menu")
				(_screen() as MainMenu)._play_btn.pressed.emit()
				_next("play pressed")
		1:
			if _step_t > 0.3:
				_shot("02_transition")
			if _screen() is LevelPlayer and _step_t > 0.9:
				_shot("03_level_intro")
				_next("in level 1")
		2:
			var lp := _screen() as LevelPlayer
			if lp._droplet != null and not lp._intro_running:
				var p := lp._droplet.global_position
				if _phase == 0 and p.y > 730.0 and p.x > 250.0 and p.x < 430.0:
					lp._handle_playfield_tap(Vector2(600, 900))
					_phase = 1
					_shot("04_ice")
				elif _phase == 1 and p.y > 955.0:
					lp._handle_playfield_tap(Vector2(600, 900))
					lp._handle_playfield_tap(Vector2(600, 900))
					_phase = 2
			if lp._finished and _step_t > 0.1:
				_next("bloomed")
			if _step_t > 20.0:
				push_error("FLOW: level 1 not solved")
				get_tree().quit(1)
		3:
			if _step_t > 0.6:
				_shot("05_bloom_zoom")
			if _step_t > 2.8:
				_shot("06_win_modal")
				var lp := _screen() as LevelPlayer
				if not lp._result_modal.visible:
					push_error("FLOW: result modal not visible")
				lp._result_modal._next_btn.pressed.emit()
				_next("next level")
		4:
			var lp := _screen() as LevelPlayer
			if _step_t > 1.6:
				if lp.level_index != 1:
					push_error("FLOW: expected level index 1, got %d" % lp.level_index)
				lp._hud.pause_pressed.emit()
				_next("paused")
		5:
			if _step_t > 0.7:
				_shot("07_pause")
				var lp := _screen() as LevelPlayer
				lp._pause_modal.resumed.emit()
				_next("resumed")
		6:
			if _step_t > 0.6:
				var lp := _screen() as LevelPlayer
				if get_tree().paused:
					push_error("FLOW: still paused after resume")
				lp._on_droplet_lost("evaporated")
				_next("forced fail")
		7:
			if _step_t > 1.8:
				_shot("08_fail_modal")
				var lp := _screen() as LevelPlayer
				lp._result_modal.replay_requested.emit()
				_next("retry")
		8:
			if _step_t > 0.25:
				_shot("09_restart_wipe")
			if _step_t > 1.2:
				var lp := _screen() as LevelPlayer
				if lp._finished or lp._result_modal.visible:
					push_error("FLOW: restart did not reset level")
				lp._exit_to_level_select()
				_next("to level select")
		9:
			if _step_t > 1.6:
				_shot("10_level_select")
				if not (_screen() is LevelSelect):
					push_error("FLOW: not on level select")
				_main._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
				_next("back to menu")
		10:
			if _step_t > 1.6:
				_shot("11_menu_continue")
				if not (_screen() is MainMenu):
					push_error("FLOW: not on main menu")
				print("FLOW OK")
				get_tree().quit(0)

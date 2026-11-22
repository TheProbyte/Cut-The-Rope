extends Node

const MAIN_MENU_SCENE := preload("res://scenes/main/MainMenu.tscn")
const LEVEL_SELECT_SCENE := preload("res://scenes/main/LevelSelect.tscn")
const LEVEL_PLAYER_SCENE := preload("res://scenes/main/LevelPlayer.tscn")

var _current_screen: Node = null
var _screen_name: String = ""
var _last_world: String = "greenhouse"
var _transition: TransitionLayer


func _ready() -> void:
	_transition = TransitionLayer.new()
	add_child(_transition)
	_mount_main_menu()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		match _screen_name:
			"level_player":
				show_level_select(_last_world)
			"level_select":
				show_main_menu()
			_:
				get_tree().quit()


func _swap_screen(node: Node, screen_name: String) -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	if _current_screen != null and is_instance_valid(_current_screen):
		_current_screen.queue_free()
	_current_screen = node
	_screen_name = screen_name
	add_child(_current_screen)


func _mount_main_menu() -> void:
	var menu: MainMenu = MAIN_MENU_SCENE.instantiate()
	menu.play_pressed.connect(_on_quick_play)
	menu.levels_pressed.connect(func(): show_level_select(_last_world))
	_swap_screen(menu, "main_menu")


func show_main_menu() -> void:
	_transition.transition_to(_mount_main_menu, Color(0.18, 0.56, 0.72, 1.0))


func show_level_select(world_id: String = "greenhouse") -> void:
	_last_world = world_id
	var curtain := Color(0.18, 0.56, 0.72, 1.0) if world_id == "greenhouse" else Color(0.76, 0.48, 0.26, 1.0)
	_transition.transition_to(func():
		var sel: LevelSelect = LEVEL_SELECT_SCENE.instantiate()
		sel.active_world = world_id
		sel.level_selected.connect(start_level)
		sel.back_pressed.connect(show_main_menu)
		_swap_screen(sel, "level_select")
	, curtain)


func start_level(world_id: String, level_index: int) -> void:
	_last_world = world_id
	var curtain := Color(0.16, 0.54, 0.72, 1.0) if world_id == "greenhouse" else Color(0.76, 0.48, 0.26, 1.0)
	_transition.transition_to(func():
		var player: LevelPlayer = LEVEL_PLAYER_SCENE.instantiate()
		player.world_id = world_id
		player.level_index = level_index
		player.back_to_level_select.connect(func(wid: String): show_level_select(wid))
		_swap_screen(player, "level_player")
	, curtain)


func _on_quick_play() -> void:
	for w in LevelRegistry.get_worlds():
		var wid := String(w.get("id", "greenhouse"))
		var levels := LevelRegistry.get_world_levels(wid)
		for i in range(levels.size()):
			var lvl_id := String(levels[i].get("id", ""))
			if not SaveManager.is_completed(lvl_id):
				start_level(wid, i)
				return
	start_level("greenhouse", 0)

extends Node

const MAIN_MENU_SCENE := preload("res://scenes/main/MainMenu.tscn")
const LEVEL_SELECT_SCENE := preload("res://scenes/main/LevelSelect.tscn")
const LEVEL_PLAYER_SCENE := preload("res://scenes/main/LevelPlayer.tscn")

var _current_screen: Node = null
var _screen_name: String = ""


func _ready() -> void:
	show_main_menu()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		match _screen_name:
			"level_player":
				show_level_select()
			"level_select":
				show_main_menu()
			_:
				get_tree().quit()


func _swap_screen(node: Node, screen_name: String) -> void:
	get_tree().paused = false
	if _current_screen != null and is_instance_valid(_current_screen):
		_current_screen.queue_free()
	_current_screen = node
	_screen_name = screen_name
	add_child(_current_screen)


func show_main_menu() -> void:
	var menu: MainMenu = MAIN_MENU_SCENE.instantiate()
	menu.play_pressed.connect(_on_quick_play)
	menu.levels_pressed.connect(show_level_select)
	_swap_screen(menu, "main_menu")


func show_level_select() -> void:
	var sel: LevelSelect = LEVEL_SELECT_SCENE.instantiate()
	sel.level_selected.connect(start_level)
	sel.back_pressed.connect(show_main_menu)
	_swap_screen(sel, "level_select")


func start_level(world_id: String, level_index: int) -> void:
	var player: LevelPlayer = LEVEL_PLAYER_SCENE.instantiate()
	player.world_id = world_id
	player.level_index = level_index
	player.back_to_level_select.connect(show_level_select)
	_swap_screen(player, "level_player")


func _on_quick_play() -> void:
	# Jump straight to the first uncompleted Greenhouse level (or Level 1 if all finished)
	var levels := LevelRegistry.get_world_levels("greenhouse")
	var target := 0
	for i in range(levels.size()):
		var lvl_id := String(levels[i].get("id", ""))
		if not SaveManager.is_completed(lvl_id):
			target = i
			break
	start_level("greenhouse", target)

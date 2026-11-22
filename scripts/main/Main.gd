extends Node
## Root screen router: main menu <-> level select <-> level player,
## with liquid iris transitions and Android back-button handling.

const MAIN_MENU_SCENE := preload("res://scenes/main/MainMenu.tscn")
const LEVEL_SELECT_SCENE := preload("res://scenes/main/LevelSelect.tscn")
const LEVEL_PLAYER_SCENE := preload("res://scenes/main/LevelPlayer.tscn")

var _current_screen: Node = null
var _screen_name: String = ""
var _last_world: String = "greenhouse"
var _transition: TransitionLayer


func _ready() -> void:
	get_tree().set_auto_accept_quit(true)
	get_tree().set_quit_on_go_back(false)
	_transition = TransitionLayer.new()
	add_child(_transition)
	_mount_main_menu(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _transition.is_busy():
			return
		match _screen_name:
			"level_player":
				(_current_screen as LevelPlayer).handle_back()
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


func _mount_main_menu(first_boot: bool = false) -> void:
	var menu: MainMenu = MAIN_MENU_SCENE.instantiate()
	menu.first_boot = first_boot
	menu.play_pressed.connect(_on_quick_play)
	menu.levels_pressed.connect(func(): show_level_select(_last_world))
	_swap_screen(menu, "main_menu")
	AudioManager.play_music("menu")


func show_main_menu() -> void:
	AudioManager.play_sfx("ui_whoosh", 0.9, -6.0)
	TransitionLayer.run(_mount_main_menu, WorldBackground.curtain_color("greenhouse"))


func show_level_select(world_id: String = "greenhouse") -> void:
	_last_world = world_id
	AudioManager.play_sfx("ui_whoosh", 1.0, -6.0)
	TransitionLayer.run(func():
		var sel: LevelSelect = LEVEL_SELECT_SCENE.instantiate()
		sel.active_world = world_id
		sel.level_selected.connect(start_level)
		sel.back_pressed.connect(show_main_menu)
		_swap_screen(sel, "level_select")
		AudioManager.play_music("menu")
	, WorldBackground.curtain_color(world_id))


func start_level(world_id: String, level_index: int, from_pos: Vector2 = Vector2(-1, -1)) -> void:
	_last_world = world_id
	AudioManager.play_sfx("ui_whoosh", 1.1, -6.0)
	TransitionLayer.run(func():
		var player: LevelPlayer = LEVEL_PLAYER_SCENE.instantiate()
		player.world_id = world_id
		player.level_index = level_index
		player.back_to_level_select.connect(func(wid: String): show_level_select(wid))
		_swap_screen(player, "level_player")
	, WorldBackground.curtain_color(world_id), from_pos)


func _on_quick_play(from_pos: Vector2) -> void:
	var nxt := SaveManager.get_next_unfinished()
	if nxt.is_empty():
		show_level_select(_last_world)
	else:
		start_level(String(nxt["world"]), int(nxt["index"]), from_pos)

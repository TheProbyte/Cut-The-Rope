extends Node
## Dev-only screenshot harness. Usage:
##   godot res://tests/Screenshot.tscn -- <screen> [world] [level] [out.png] [frames]
## screen: menu | select | level

var _frames_left := 90
var _out := "user://shot.png"

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var screen := args[0] if args.size() > 0 else "menu"
	var world := args[1] if args.size() > 1 else "greenhouse"
	var level := int(args[2]) if args.size() > 2 else 0
	_out = args[3] if args.size() > 3 else _out
	_frames_left = int(args[4]) if args.size() > 4 else 90
	var node: Node
	match screen:
		"select":
			node = load("res://scenes/main/LevelSelect.tscn").instantiate()
			node.active_world = world
		"level":
			node = load("res://scenes/main/LevelPlayer.tscn").instantiate()
			node.world_id = world
			node.level_index = level
		_:
			node = load("res://scenes/main/MainMenu.tscn").instantiate()
	add_child(node)

func _process(_d: float) -> void:
	_frames_left -= 1
	if _frames_left == 0:
		var img := get_viewport().get_texture().get_image()
		img.save_png(_out)
		print("saved ", _out)
		get_tree().quit()

class_name LevelLoader
extends RefCounted

const DROPLET_SCENE := preload("res://scenes/entities/Droplet.tscn")
const SEEDLING_SCENE := preload("res://scenes/entities/Seedling.tscn")
const COLLECTIBLE_SCENE := preload("res://scenes/entities/Collectible.tscn")
const PLATFORM_SCENE := preload("res://scenes/elements/Platform.tscn")
const GRATE_SCENE := preload("res://scenes/elements/Grate.tscn")
const GLASS_SCENE := preload("res://scenes/elements/GlassPane.tscn")
const HEAT_LAMP_SCENE := preload("res://scenes/elements/HeatLamp.tscn")
const FREEZER_SCENE := preload("res://scenes/elements/FreezerZone.tscn")
const FAN_SCENE := preload("res://scenes/elements/Fan.tscn")
const COLD_PIPE_SCENE := preload("res://scenes/elements/ColdPipe.tscn")
const DRAIN_SCENE := preload("res://scenes/elements/Drain.tscn")


static func build_level(parent: Node2D, data: Dictionary) -> Dictionary:
	var result := {
		"droplet": null,
		"seedling": null,
		"fans": [],
		"drains": [],
		"collectibles": [],
	}

	# Zones first (rendered behind platforms & droplet)
	for hl in data.get("heat_lamps", []):
		var node: HeatLamp = HEAT_LAMP_SCENE.instantiate()
		parent.add_child(node)
		node.configure(hl)

	for fz in data.get("freezer_zones", []):
		var node: FreezerZone = FREEZER_SCENE.instantiate()
		parent.add_child(node)
		node.configure(fz)

	# Fans
	for fan_cfg in data.get("fans", []):
		var node: Fan = FAN_SCENE.instantiate()
		parent.add_child(node)
		node.configure(fan_cfg)
		result["fans"].append(node)

	# Solid geometry
	for plat_cfg in data.get("platforms", []):
		var node: Platform = PLATFORM_SCENE.instantiate()
		parent.add_child(node)
		node.configure(plat_cfg)

	for grate_cfg in data.get("grates", []):
		var node: Grate = GRATE_SCENE.instantiate()
		parent.add_child(node)
		node.configure(grate_cfg)

	for glass_cfg in data.get("glass_panes", []):
		var node: GlassPane = GLASS_SCENE.instantiate()
		parent.add_child(node)
		node.configure(glass_cfg)

	for pipe_cfg in data.get("cold_pipes", []):
		var node: ColdPipe = COLD_PIPE_SCENE.instantiate()
		parent.add_child(node)
		node.configure(pipe_cfg)

	for drain_cfg in data.get("drains", []):
		var node: Drain = DRAIN_SCENE.instantiate()
		parent.add_child(node)
		node.configure(drain_cfg)
		result["drains"].append(node)

	# Collectibles
	for col_cfg in data.get("collectibles", []):
		var col: Collectible = COLLECTIBLE_SCENE.instantiate()
		var pos_arr: Array = col_cfg.get("pos", [360, 500]) if typeof(col_cfg) == TYPE_DICTIONARY else col_cfg
		col.position = Vector2(float(pos_arr[0]), float(pos_arr[1]))
		parent.add_child(col)
		result["collectibles"].append(col)

	# Seedling
	var seed_cfg: Dictionary = data.get("seedling", {})
	var seed_pos: Array = seed_cfg.get("pos", [360, 1040])
	var seedling: Seedling = SEEDLING_SCENE.instantiate()
	seedling.position = Vector2(float(seed_pos[0]), float(seed_pos[1]))
	parent.add_child(seedling)
	result["seedling"] = seedling

	# Droplet
	var spawn_cfg: Dictionary = data.get("spawn", {})
	var spawn_pos: Array = spawn_cfg.get("pos", [360, 220])
	var init_state_str: String = String(spawn_cfg.get("state", "water")).to_lower()
	var init_state: Droplet.State = Droplet.State.WATER
	match init_state_str:
		"ice":
			init_state = Droplet.State.ICE
		"steam":
			init_state = Droplet.State.STEAM
		_:
			init_state = Droplet.State.WATER

	var droplet: Droplet = DROPLET_SCENE.instantiate()
	droplet.state = init_state
	droplet.position = Vector2(float(spawn_pos[0]), float(spawn_pos[1]))
	parent.add_child(droplet)
	result["droplet"] = droplet

	return result

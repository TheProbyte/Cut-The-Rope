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
const SPONGE_SCENE := preload("res://scenes/elements/Sponge.tscn")
const HOT_PLATE_SCENE := preload("res://scenes/elements/HotPlate.tscn")
const MOVING_PLATFORM_SCENE := preload("res://scenes/elements/MovingPlatform.tscn")


static func build_level(parent: Node2D, data: Dictionary) -> Dictionary:
	var theme_name := String(data.get("theme", data.get("world", "greenhouse"))).to_lower()
	var result := {
		"droplet": null,
		"seedling": null,
		"fans": [],
		"sponges": [],
		"drains": [],
		"hot_plates": [],
		"glass_panes": [],
		"moving_platforms": [],
		"collectibles": [],
		"spout": null,
		"theme": theme_name,
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

	# Moving Platforms
	for mp_cfg in data.get("moving_platforms", []):
		var node: MovingPlatform = MOVING_PLATFORM_SCENE.instantiate()
		parent.add_child(node)
		node.configure(mp_cfg, theme_name)
		result["moving_platforms"].append(node)

	# Static geometry
	for plat_cfg in data.get("platforms", []):
		var node: Platform = PLATFORM_SCENE.instantiate()
		parent.add_child(node)
		node.configure(plat_cfg, theme_name)

	for grate_cfg in data.get("grates", []):
		var node: Grate = GRATE_SCENE.instantiate()
		parent.add_child(node)
		node.configure(grate_cfg)

	for glass_cfg in data.get("glass_panes", []):
		var node: GlassPane = GLASS_SCENE.instantiate()
		parent.add_child(node)
		node.configure(glass_cfg)
		result["glass_panes"].append(node)

	for pipe_cfg in data.get("cold_pipes", []):
		var node: ColdPipe = COLD_PIPE_SCENE.instantiate()
		parent.add_child(node)
		node.configure(pipe_cfg)

	for sp_cfg in data.get("sponges", []):
		var node: Sponge = SPONGE_SCENE.instantiate()
		parent.add_child(node)
		node.configure(sp_cfg)
		result["sponges"].append(node)

	for drain_cfg in data.get("drains", []):
		var node: Drain = DRAIN_SCENE.instantiate()
		parent.add_child(node)
		node.configure(drain_cfg)
		result["drains"].append(node)

	for hp_cfg in data.get("hot_plates", []):
		var node: HotPlate = HOT_PLATE_SCENE.instantiate()
		parent.add_child(node)
		node.configure(hp_cfg)
		result["hot_plates"].append(node)

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

	# Cozy overhead spawn spout
	var spawn_cfg: Dictionary = data.get("spawn", {})
	var spawn_pos: Array = spawn_cfg.get("pos", [360, 220])
	var spout := SpawnSpout.new()
	spout.theme_name = theme_name
	spout.position = Vector2(float(spawn_pos[0]), float(spawn_pos[1]))
	parent.add_child(spout)
	result["spout"] = spout

	# Droplet
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
	seedling.track_droplet(droplet)
	result["droplet"] = droplet

	return result

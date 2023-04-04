extends Node2D

enum Layer {
	FLOOR,
	CLUTTER,
	ROAD,
	TREE
}

@onready var tree_node: PackedScene = preload("res://nodes/Tree.tscn")

@onready var generator: Node = $Generator
@onready var tilemap: TileMap = $TileMap

@onready var player_zone: Node2D = $TileMap/Player
@onready var tree_zone: Node2D = $TileMap/Trees

## Enable/disable block loading optimization
@export var optimized_async := true

var loader_enabled := false

var load_queue := []

# Stores a hash of each block in order to prevent from drawing the same thing over again
# unless the block has been modified, then it will be redrawn
var map_hash := {}

## How far the chunk region extends in the +/-X and +/-Y axis
const chunk_radii := Vector2i(2, 1)

# Preload and instantiate the player character
@onready var player_character := preload("res://nodes/Player.tscn").instantiate()
## Sets the starting position of the example player
@export var starting_position := Vector2(2048, 2048)
## Sets the starting zoom of the camera
@export var starting_zoom := Vector2(1.0, 1.0)
# Tracks the index of the block the player currently resides in
@onready var current_block: int = generator.global_block_index(starting_position):
	set(value):
		current_block = value
		
		var block_pos: Vector2i = generator.block_position(current_block)
		queue_chunk(block_pos)
		
		if not loader_enabled:
			async_loader()

var physics_delta: float = 1.0 / float(ProjectSettings.get_setting("physics/common/physics_ticks_per_second"))

# Gener
func _ready() -> void:
	generator.generate_map()

func _physics_process(_delta: float) -> void:
	check_block()
	
	if Input.is_action_just_released("modify_block"):
		var start_block = 0
		var end_block = 31
		print("[Clearing Blocks]",
				"\nStart: ", start_block,
				"\nEnd: ", end_block,
				"\nTotal: ", (end_block + 1) - start_block)
		for block_idx in range(start_block, end_block + 1):
			clear_block(block_idx)
		print("[Blocks Cleared]")

func spawn_player(spawn_position: Vector2 = starting_position) -> void:
	player_character.position = spawn_position
	player_character.default_camera_zoom = starting_zoom
	player_zone.add_child(player_character)

func check_block() -> void:
	var block_idx: int = generator.global_block_index(player_character.position)
	
	if block_idx == current_block:
		return
	
	current_block = block_idx

# Async Loader
func async_loader() -> void:
	loader_enabled = true
	
	while loader_enabled:
		if not load_queue.size():
			loader_enabled = false
			return
		
		var load_data: Array = load_queue.pop_front()
		var block_layer: int = load_data[0]
		var block_pos: Vector2i = load_data[1]
		var load_priority: bool = load_data[2]
		
		if load_priority == false and optimized_async == true:
			# Since timers 'refreshes' every physics frame
			# Technically any values under 0.05 seconds (According to the Docs)
			# Will "behave in significantly different ways",
			# But, shouldn't be an issue
			await get_tree().create_timer(physics_delta).timeout
		
		load_layer(block_pos, block_layer)

func load_layer(block_pos: Vector2i, block_layer: Layer) -> void:
	var block_idx: int = generator.block_index(block_pos)
	var total_tiles: int = generator.BLOCK_SIZE.x * generator.BLOCK_SIZE.y
	var road_cells := []
	
	for tile_idx in range(total_tiles):
		var tile_pos: Vector2i = generator.tile_position(tile_idx)
		var tile_global_pos: Vector2i = (block_pos * generator.BLOCK_SIZE) + tile_pos
		match block_layer:
			Layer.FLOOR:
				var floor_tile: int = generator.map[block_idx][tile_idx][Layer.FLOOR]
				
				tilemap.set_cell(Layer.FLOOR, tile_global_pos, 0, Vector2i(floor_tile, 0))
			
			Layer.CLUTTER:
				var clutter_tile: int = generator.map[block_idx][tile_idx][Layer.CLUTTER]
				
				if clutter_tile == -1:
					tilemap.set_cell(Layer.CLUTTER, tile_global_pos)
					continue
				
				tilemap.set_cell(Layer.CLUTTER, tile_global_pos, 1, Vector2i(clutter_tile, 0))
			
			Layer.ROAD:
				var road_tile: int = generator.map[block_idx][tile_idx][Layer.ROAD]
				
				if road_tile == -1:
					tilemap.set_cell(2, tile_global_pos)
					continue
				
				road_cells.append(tile_global_pos)
			
			# Objects, unlike Tiles, can overwhelm the game when hundreds of them are spawned
			# Managing them isn't included in this demo
			# This is just to show objects can also be spawned
			Layer.TREE:
				var has_tree: bool = generator.map[block_idx][tile_idx][Layer.TREE]
				
				if not has_tree:
					continue
				
				var tree_instance = tree_node.instantiate()
				tree_instance.position = tilemap.map_to_local(tile_global_pos)
				tree_zone.add_child(tree_instance)
	
	if road_cells.size():
		tilemap.set_cells_terrain_connect(Layer.ROAD, road_cells, 0, 0)

func check_hash(block_idx: int, block_layer) -> bool:
	var block_hash: int = generator.map[block_idx].hash()
	
	if map_hash.has(block_idx):
		if map_hash[block_idx]["HASH"] != block_hash:
			stamp_hash(block_idx, block_hash)
		
		if map_hash[block_idx][block_layer]:
			return false
		
		map_hash[block_idx][block_layer] = true
		return true
	
	stamp_hash(block_idx, block_hash)
	map_hash[block_idx][block_layer] = true
	return true

func stamp_hash(block_idx: int, block_hash: int) -> void:
	map_hash[block_idx] = {
		"HASH": block_hash,
		Layer.FLOOR: false,
		Layer.CLUTTER: false,
		Layer.ROAD: false,
		Layer.TREE: false
	}

# Chunk queuing
func queue_chunk(origin_block_position: Vector2i, priority: bool = false) -> void:
	var chunk_size: Vector2i = (chunk_radii * 2) + Vector2i(1, 1)
	
	for offset_y in range(chunk_size.y):
		for offset_x in range(chunk_size.x):
			var relative_x: int = offset_x - chunk_radii.x
			var relative_y: int = offset_y - chunk_radii.y
			var block_pos: Vector2i = origin_block_position + Vector2i(relative_x, relative_y)
			if in_bounds(block_pos):
				queue_block(block_pos, priority)

func queue_block(block_pos: Vector2i, priority: bool) -> void:
	var layers := [Layer.FLOOR, Layer.CLUTTER, Layer.ROAD, Layer.TREE]
	var block_idx: int = generator.block_index(block_pos)
	
	for layer in layers:
		var layer_ticket := [layer, block_pos, priority]
		if check_hash(block_idx, layer):
			load_queue.append(layer_ticket)

func in_bounds(block_pos:Vector2i) -> bool:
	if(	block_pos.x < 0 or
		block_pos.x >= generator.map_size.x or
		block_pos.y < 0 or
		block_pos.y >= generator.map_size.y):
		return false
	return true

func _on_map_generated() -> void:
	var origin_block: Vector2i = generator.block_position(current_block)
	spawn_player()
	queue_chunk(origin_block, true)
	async_loader()

# clears the block of clutter and roads, for demo purposes
func clear_block(block_idx:int) -> void:
	for tile_y in range(generator.BLOCK_SIZE.y):
		for tile_x in range(generator.BLOCK_SIZE.x):
			var tile_idx = generator.tile_index(Vector2i(tile_x, tile_y))
			generator.map[block_idx][tile_idx][Layer.CLUTTER] = -1
			generator.map[block_idx][tile_idx][Layer.ROAD] = -1

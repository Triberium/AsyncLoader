extends Node

signal map_generated

## The seed to be used in generating the map
@export var global_seed: int = 1337

var rng := RandomNumberGenerator.new()

## The noise that will be used to generate the map
@export var noise:FastNoiseLite
## The size of the map to be generated
@export var map_size := Vector2i(16, 16)
## Toggle clutter generation
@export var clutter_enabled := true
## Toggle road generation
@export var road_enabled := true
## Toggle tree generation
@export var trees_enabled := false
# How many tiles each block consists in both dimensions
const BLOCK_SIZE := Vector2i(16, 16)
# How many pixels each tile consists of
const TILE_SIZE := Vector2i(16, 16)

# Stores block data
var map := []

func _ready():
	setup_seeds()

func setup_seeds(new_seed: int = global_seed) -> void:
	noise.seed = new_seed
	rng.seed = new_seed

# Map data generation
func generate_map() -> void:
	var total_blocks: int = map_size.x * map_size.y
	
	print("[Generating Map]",
		"\nSeed: ", global_seed,
		"\nSize: ", map_size.x, "x", map_size.y,
		"\nBlocks: ", total_blocks,
		"\nClutter: ", clutter_enabled,
		"\nRoads: ", road_enabled, 
		"\nTrees: ", trees_enabled)
	
	var start_time = Time.get_ticks_msec()
	
	for block_idx in range(total_blocks):
		var block_data := generate_block(block_idx)
		
		map.append(block_data)
	
	var generation_time = (float(Time.get_ticks_msec()) - float(start_time)) / 1000
	print("[Map Generated in %.2f" % generation_time, " Secs]")
	map_generated.emit()

func generate_block(block_idx: int) -> Array:
	var total_tiles: int = BLOCK_SIZE.x * BLOCK_SIZE.y
	var block_data := []
	
	for tile_idx in range(total_tiles):
		var tile_data := generate_tile(block_idx, tile_idx)
		
		block_data.append(tile_data)
	
	return block_data

func generate_tile(block_idx: int, tile_idx: int) -> Array:
	var tile_pos := tile_position(tile_idx) + (block_position(block_idx) * BLOCK_SIZE)
	var tile_noise:float = noise.get_noise_2dv(Vector2(tile_pos))
	var floor_tile := int(round((tile_noise + 1.0) * 3.5))
	
	var clutter_chance := rng.randf()
	var clutter_tile := -1
	var road_tile := -1
	var has_tree := false
	var tree_chance := clampf(tile_noise + rng.randf(), 0.0, 1.0)
	
	if clutter_chance <= 0.075 and clutter_enabled:
		var min_val = int(floor(float(floor_tile) * 0.5))
		
		clutter_tile = rng.randi_range(min_val * 2, (min_val * 2) + 1)
	
	if tile_noise > -0.075 and tile_noise < 0.075 and road_enabled:
		road_tile = 0
	
	if road_tile == -1 and tree_chance >= 0.85 and trees_enabled:
		has_tree = true
	
	return [floor_tile, clutter_tile, road_tile, has_tree]

func block_position(block_idx: int) -> Vector2i:
	var block_x: int = block_idx % map_size.x
	var block_y: int = floor(float(block_idx) / float(map_size.x))
	
	return Vector2i(block_x, block_y)

func tile_position(tile_idx: int) -> Vector2i:
	var tile_x: int = tile_idx % BLOCK_SIZE.x
	var tile_y: int = floor(float(tile_idx) / float(BLOCK_SIZE.x))
	
	return Vector2i(tile_x, tile_y)

func block_index(block_pos: Vector2i) -> int:
	var y_value = block_pos.y * map_size.x
	
	return block_pos.x + y_value

func tile_index(tile_pos: Vector2i) -> int:
	var y_value = tile_pos.y * BLOCK_SIZE.y
	
	return tile_pos.x + y_value

func global_block_index(global_pos: Vector2) -> int:
	var block_pos: Vector2i = global_pos / (Vector2(BLOCK_SIZE) * Vector2(TILE_SIZE))
	
	return block_index(block_pos)

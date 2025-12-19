class_name BiomeManager
extends RefCounted

var active_biomes: Array[Biome] = []
var game_seed: int
var biome_grid: Array = []  # 100x100 grid, each cell = {biome_id: percentage}
var grid_size: int = 100

func _init(_seed: int = 0):
	if _seed == 0:
		game_seed = Time.get_ticks_msec()
	else:
		game_seed = _seed
	
	_select_biomes()
	_initialize_grid()
	_generate_biome_distribution()

func _select_biomes() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = game_seed
	
	# Get all available biomes
	var all_biomes = Biome.get_all_biomes()
	
	# Select 5-9 biomes randomly
	var num_biomes = rng.randi_range(5, 9)
	all_biomes.shuffle()
	
	for i in range(num_biomes):
		active_biomes.append(all_biomes[i])
	
	print("Selected ", num_biomes, " biomes: ", active_biomes.map(func(b): return b.id))

func _initialize_grid() -> void:
	# Create 100x100 grid
	biome_grid.resize(grid_size)
	for x in range(grid_size):
		biome_grid[x] = []
		biome_grid[x].resize(grid_size)
		for y in range(grid_size):
			biome_grid[x][y] = {}

func _generate_biome_distribution() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = game_seed
	
	# Assign random origin points for each biome
	for biome in active_biomes:
		biome.origin = Vector2i(
			rng.randi_range(0, grid_size - 1),
			rng.randi_range(0, grid_size - 1)
		)
	
	# Calculate biome influence for each cell based on distance
	for x in range(grid_size):
		for y in range(grid_size):
			var cell_pos = Vector2i(x, y)
			var influences = {}
			
			# Calculate inverse distance to each biome origin
			for biome in active_biomes:
				var distance = _manhattan_distance(cell_pos, biome.origin)
				if distance == 0:
					# Cell is at origin, 100% this biome
					influences[biome.id] = 1.0
					break
				else:
					# Use inverse distance as influence
					influences[biome.id] = 1.0 / (distance + 1.0)
			
			# Normalize influences to percentages
			var total_influence = 0.0
			for influence in influences.values():
				total_influence += influence
			
			if total_influence > 0:
				for biome_id in influences.keys():
					influences[biome_id] = influences[biome_id] / total_influence
			
			biome_grid[x][y] = influences

func _manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

func get_cell_biomes(x: int, y: int) -> Dictionary:
	## Returns biome composition for a cell {biome_id: percentage}
	if x < 0 or x >= grid_size or y < 0 or y >= grid_size:
		return {}
	return biome_grid[x][y]

func get_dominant_biome_color(x: int, y: int) -> Color:
	## Returns the color of the dominant biome in a cell
	var biomes = get_cell_biomes(x, y)
	if biomes.is_empty():
		return Color.WHITE
	
	# Find dominant biome
	var max_percentage = 0.0
	var dominant_id = ""
	for biome_id in biomes.keys():
		if biomes[biome_id] > max_percentage:
			max_percentage = biomes[biome_id]
			dominant_id = biome_id
	
	# Find the biome object and return its color
	for biome in active_biomes:
		if biome.id == dominant_id:
			return biome.color
	
	return Color.WHITE

func get_mixed_biome_color(x: int, y: int) -> Color:
	## Returns a blended color based on all biome percentages in a cell
	var biomes = get_cell_biomes(x, y)
	if biomes.is_empty():
		return Color.WHITE
	
	var result_color = Color.BLACK
	
	for biome_id in biomes.keys():
		var percentage = biomes[biome_id]
		for biome in active_biomes:
			if biome.id == biome_id:
				result_color += biome.color * percentage
				break
	
	return result_color

class_name BiomeManager
extends RefCounted

var active_biomes: Array[Biome] = []
var game_seed: int
var biome_grid: Array = []  # 100x100 grid, each cell = {biome_id: percentage}
var grid_size: int = 100
var noise: FastNoiseLite  # Noise per confini biomi
var tile_noise: FastNoiseLite  # Noise per tile del pavimento

func _init(_seed: int = 0):
	if _seed == 0:
		game_seed = Time.get_ticks_msec()
	else:
		game_seed = _seed
	
	# Inizializza noise per confini biomi
	noise = FastNoiseLite.new()
	noise.seed = game_seed
	noise.frequency = 0.05  # Variazioni smooth sui confini
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	
	# Inizializza noise per variazioni tile pavimento
	tile_noise = FastNoiseLite.new()
	tile_noise.seed = game_seed + 1000
	tile_noise.frequency = 0.3  # Variazioni più fini per ogni tile
	tile_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	
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
					var base_influence = 1.0 / (distance + 1.0)
					# Apply noise to make boundaries less rigid
					var noise_value = noise.get_noise_2d(x, y)
					# Noise is -1 to 1, normalize to 0.5 to 1.5 multiplier
					var noise_multiplier = 1.0 + noise_value * 0.5
					influences[biome.id] = base_influence * noise_multiplier
			
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

func get_tile_color(cell_x: int, cell_y: int, tile_x: int, tile_y: int) -> Color:
	## Returns color for a specific tile with noise variation
	## cell_x, cell_y: global cell coordinates (0-99)
	## tile_x, tile_y: tile coordinates within the cell
	
	var biomes = get_cell_biomes(cell_x, cell_y)
	if biomes.is_empty():
		return Color.WHITE
	
	# Coordinate globali della tile per il noise
	var global_tile_x = cell_x * 100 + tile_x
	var global_tile_y = cell_y * 100 + tile_y
	
	# Determina quale bioma usare per questa tile se ci sono mix
	var base_color: Color
	if biomes.size() == 1:
		# Solo un bioma, usa quello
		var biome_id = biomes.keys()[0]
		for biome in active_biomes:
			if biome.id == biome_id:
				base_color = biome.color
				break
	else:
		# Mix di biomi: usa noise solo se ci sono almeno 2 biomi significativi (>15%)
		var significant_biomes = []
		for biome_id in biomes.keys():
			if biomes[biome_id] > 0.15:
				significant_biomes.append({"id": biome_id, "percentage": biomes[biome_id]})
		
		if significant_biomes.size() > 1:
			# Usa noise per transizioni organiche tra biomi significativi
			var mix_noise = noise.get_noise_2d(global_tile_x * 0.05, global_tile_y * 0.05)
			# Normalizza noise a 0-1
			var mix_value = (mix_noise + 1.0) / 2.0
			
			# Mappa mix_value alle percentuali dei biomi significativi
			var accumulated = 0.0
			for biome_data in significant_biomes:
				accumulated += biome_data["percentage"]
				if mix_value * significant_biomes.reduce(func(sum, b): return sum + b["percentage"], 0.0) <= accumulated:
					for biome in active_biomes:
						if biome.id == biome_data["id"]:
							base_color = biome.color
							break
					break
		else:
			# Un solo bioma significativo, usa quello dominante
			var dominant_id = ""
			var max_percentage = 0.0
			for biome_id in biomes.keys():
				if biomes[biome_id] > max_percentage:
					max_percentage = biomes[biome_id]
					dominant_id = biome_id
			
			for biome in active_biomes:
				if biome.id == dominant_id:
					base_color = biome.color
					break
	
	# Applica variazione di luminosità con tile_noise
	var brightness_noise = tile_noise.get_noise_2d(global_tile_x, global_tile_y)
	# brightness_noise è -1 a 1, normalizza a -0.1 a +0.1 per variazioni sottili
	var brightness_variation = brightness_noise * 0.1
	
	# Schiarisci leggermente il colore base e applica variazione
	var final_color = base_color.lightened(0.3)
	if brightness_variation > 0:
		final_color = final_color.lightened(brightness_variation)
	else:
		final_color = final_color.darkened(-brightness_variation)
	
	return final_color

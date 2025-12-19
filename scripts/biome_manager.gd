class_name BiomeManager
extends RefCounted

var active_biomes: Array[Biome] = []
var game_seed: int
var biome_grid: Array = []  # 100x100 grid, each cell = {biome_id: percentage}
var grid_size: int = 100
var boundary_noise: FastNoiseLite  # Noise per variare i confini tra biomi
var tile_selection_noise: FastNoiseLite  # Noise per scegliere QUALE bioma tra quelli nella cella
var brightness_noise: FastNoiseLite  # Noise per variare la luminosità

func _init(_seed: int = 0):
	if _seed == 0:
		game_seed = Time.get_ticks_msec()
	else:
		game_seed = _seed
	
	# Noise per confini biomi (varia leggermente le distanze)
	boundary_noise = FastNoiseLite.new()
	boundary_noise.seed = game_seed
	boundary_noise.frequency = 0.15
	boundary_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	
	# Noise per SELEZIONARE bioma tra quelli nella cella
	tile_selection_noise = FastNoiseLite.new()
	tile_selection_noise.seed = game_seed + 1000
	tile_selection_noise.frequency = 0.05  # Ridotto per scatter più ampio
	tile_selection_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	
	# Noise per LUMINOSITÀ tile
	brightness_noise = FastNoiseLite.new()
	brightness_noise.seed = game_seed + 2000
	brightness_noise.frequency = 0.4
	brightness_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	
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

	# Assegna punti origine casuali ai biomi
	for biome in active_biomes:
		biome.origin = Vector2i(
			rng.randi_range(0, grid_size - 1),
			rng.randi_range(0, grid_size - 1)
		)

	# Primo passaggio: assegna a ogni cella il bioma più vicino (Voronoi puro)
	for x in range(grid_size):
		for y in range(grid_size):
			var cell_pos = Vector2i(x, y)
			var min_dist = 999999
			var closest_biome_id = ""
			for biome in active_biomes:
				var dist = _manhattan_distance(cell_pos, biome.origin)
				# Applica un piccolo noise ai confini per renderli meno dritti
				var noise = boundary_noise.get_noise_2d(x, y) * 0.5
				var d = dist + noise
				if d < min_dist:
					min_dist = d
					closest_biome_id = biome.id
			# Di default, la cella è SOLO di quel bioma
			biome_grid[x][y] = {closest_biome_id: 1.0}

	# Secondo passaggio: solo sulle celle di confine, mischia con i biomi adiacenti
	for x in range(grid_size):
		for y in range(grid_size):
			var this = biome_grid[x][y].keys()[0]
			var neighbors = []
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					if dx == 0 and dy == 0:
						continue
					var nx = x + dx
					var ny = y + dy
					if nx >= 0 and nx < grid_size and ny >= 0 and ny < grid_size:
						var n_biome = biome_grid[nx][ny].keys()[0]
						if n_biome != this and not neighbors.has(n_biome):
							neighbors.append(n_biome)
			# Se ci sono biomi diversi tra i vicini, siamo su un confine
			if neighbors.size() > 0:
				# Mischia: percentuale dominante 60%, resto diviso tra i vicini
				var mix = {}
				mix[this] = 0.6
				for n in neighbors:
					mix[n] = 0.4 / neighbors.size()
				biome_grid[x][y] = mix

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

func get_dominant_biome_id(x: int, y: int) -> String:
	## Returns the ID of the dominant biome in a cell
	var biomes = get_cell_biomes(x, y)
	if biomes.is_empty():
		return ""
	
	# Find dominant biome
	var max_percentage = 0.0
	var dominant_id = ""
	for biome_id in biomes.keys():
		if biomes[biome_id] > max_percentage:
			max_percentage = biomes[biome_id]
			dominant_id = biome_id
	
	return dominant_id

func get_biome_id_from_color(color: Color) -> String:
	## Returns the biome ID that best matches a given color
	var min_distance = 999999.0
	var closest_biome_id = ""
	
	for biome in active_biomes:
		# Calcola distanza euclidea nel RGB space
		var distance = abs(color.r - biome.color.r) + abs(color.g - biome.color.g) + abs(color.b - biome.color.b)
		if distance < min_distance:
			min_distance = distance
			closest_biome_id = biome.id
	
	return closest_biome_id

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
		# Mix di biomi: usa noise solo se ci sono almeno 2 biomi significativi
		var significant_biomes = []
		for biome_id in biomes.keys():
			# Solo biomi con almeno 20% di influenza = confini più stretti
			if biomes[biome_id] > 0.20:
				significant_biomes.append({"id": biome_id, "percentage": biomes[biome_id]})
		
		if significant_biomes.size() > 1:
			# Usa tile_selection_noise per scegliere tra i biomi possibili
			var selection_value = tile_selection_noise.get_noise_2d(global_tile_x, global_tile_y)
			# Normalizza a 0-1
			selection_value = (selection_value + 1.0) / 2.0
			
			# Calcola totale percentuali
			var total_percentage = 0.0
			for biome_data in significant_biomes:
				total_percentage += biome_data["percentage"]
			
			# Seleziona bioma in base a percentuali cumulative
			var accumulated = 0.0
			for biome_data in significant_biomes:
				accumulated += biome_data["percentage"]
				if selection_value <= (accumulated / total_percentage):
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
	
	# Applica variazione di luminosità con brightness_noise (SEPARATO!)
	var brightness_value = brightness_noise.get_noise_2d(global_tile_x, global_tile_y)
	# brightness_value è -1 a 1, normalizza a -0.1 a +0.1 per variazioni sottili
	var brightness_variation = brightness_value * 0.1
	
	# Schiarisci leggermente il colore base e applica variazione
	var final_color = base_color.lightened(0.3)
	if brightness_variation > 0:
		final_color = final_color.lightened(brightness_variation)
	else:
		final_color = final_color.darkened(-brightness_variation)
	
	return final_color

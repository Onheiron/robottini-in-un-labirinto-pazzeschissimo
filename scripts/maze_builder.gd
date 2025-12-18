class_name MazeBuilder
extends RefCounted

## Classe per la generazione di labirinti usando l'algoritmo di Eller

enum CellType { WALL, PATH }

static func generate_maze_connections(maze_rng: RandomNumberGenerator, size: int) -> Dictionary:
	## Genera un labirinto usando l'algoritmo di Eller e restituisce le connessioni
	var connections: Dictionary = {}
	var sets: Array = []
	var next_set_id: int = 0
	
	# Per ogni riga del labirinto
	for row in range(size):
		# Inizializza i set per questa riga
		if row == 0:
			for col in range(size):
				sets.append(next_set_id)
				next_set_id += 1
		
		# Connetti celle orizzontalmente (casualmente)
		for col in range(size - 1):
			if sets[col] != sets[col + 1]:
				if maze_rng.randf() > 0.5:
					# Connetti le celle orizzontalmente
					_add_connection(connections, col, row, col + 1, row)
					
					# Unisci i set
					var old_set = sets[col + 1]
					var new_set = sets[col]
					for i in range(size):
						if sets[i] == old_set:
							sets[i] = new_set
		
		# Se non è l'ultima riga, crea connessioni verticali
		if row < size - 1:
			# Raggruppa celle per set
			var set_groups = {}
			for col in range(size):
				var set_id = sets[col]
				if not set_groups.has(set_id):
					set_groups[set_id] = []
				set_groups[set_id].append(col)
			
			# Prepara i set per la prossima riga
			var new_sets = []
			for col in range(size):
				new_sets.append(-1)
			
			# Per ogni set, crea almeno una connessione verticale
			for set_id in set_groups.keys():
				var columns = set_groups[set_id]
				var connections_made = false
				
				for col in columns:
					if maze_rng.randf() > 0.5 or not connections_made:
						# Connetti verticalmente
						_add_connection(connections, col, row, col, row + 1)
						new_sets[col] = set_id
						connections_made = true
					else:
						new_sets[col] = next_set_id
						next_set_id += 1
			
			sets = new_sets
		else:
			# Ultima riga: connetti tutte le celle con set diversi
			for col in range(size - 1):
				if sets[col] != sets[col + 1]:
					_add_connection(connections, col, row, col + 1, row)
					
					var old_set = sets[col + 1]
					var new_set = sets[col]
					for i in range(size):
						if sets[i] == old_set:
							sets[i] = new_set
	
	return connections

static func _add_connection(connections: Dictionary, x1: int, y1: int, x2: int, y2: int):
	## Aggiunge una connessione bidirezionale al dizionario specificato
	var key1 = Vector2i(x1, y1)
	var key2 = Vector2i(x2, y2)
	
	if not connections.has(key1):
		connections[key1] = []
	if not connections.has(key2):
		connections[key2] = []
	
	connections[key1].append(key2)
	connections[key2].append(key1)

static func generate_cell_maze(cell_rng: RandomNumberGenerator, width: int, height: int) -> Array:
	## Genera la griglia 32x32 per una singola cella
	var maze: Array = []
	
	# Inizializza la griglia con tutti muri
	for y in range(height * 2 + 1):
		var row = []
		for x in range(width * 2 + 1):
			row.append(CellType.WALL)
		maze.append(row)
	
	var sets: Array = []
	var next_set_id: int = 0
	
	# Per ogni riga
	for row in range(height):
		# Inizializza i set per questa riga
		if row == 0:
			for col in range(width):
				sets.append(next_set_id)
				next_set_id += 1
		
		# Crea passaggio nella cella
		for col in range(width):
			var cell_x = col * 2 + 1
			var cell_y = row * 2 + 1
			maze[cell_y][cell_x] = CellType.PATH
		
		# Connetti celle orizzontalmente (casualmente)
		for col in range(width - 1):
			if sets[col] != sets[col + 1]:
				if cell_rng.randf() > 0.5:
					var wall_x = col * 2 + 2
					var wall_y = row * 2 + 1
					maze[wall_y][wall_x] = CellType.PATH
					
					var old_set = sets[col + 1]
					var new_set = sets[col]
					for i in range(width):
						if sets[i] == old_set:
							sets[i] = new_set
		
		# Se non è l'ultima riga, crea connessioni verticali
		if row < height - 1:
			var set_groups = {}
			for col in range(width):
				var set_id = sets[col]
				if not set_groups.has(set_id):
					set_groups[set_id] = []
				set_groups[set_id].append(col)
			
			var new_sets = []
			for col in range(width):
				new_sets.append(-1)
			
			for set_id in set_groups.keys():
				var columns = set_groups[set_id]
				var connections_made = false
				
				for col in columns:
					if cell_rng.randf() > 0.5 or not connections_made:
						var wall_x = col * 2 + 1
						var wall_y = row * 2 + 2
						maze[wall_y][wall_x] = CellType.PATH
						new_sets[col] = set_id
						connections_made = true
					else:
						new_sets[col] = next_set_id
						next_set_id += 1
			
			sets = new_sets
		else:
			# Ultima riga: connetti tutte le celle con set diversi
			for col in range(width - 1):
				if sets[col] != sets[col + 1]:
					var wall_x = col * 2 + 2
					var wall_y = row * 2 + 1
					maze[wall_y][wall_x] = CellType.PATH
					
					var old_set = sets[col + 1]
					var new_set = sets[col]
					for i in range(width):
						if sets[i] == old_set:
							sets[i] = new_set
	
	return maze

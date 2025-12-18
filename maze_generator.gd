extends Node2D

## Generatore di labirinto con algoritmo di Eller - Sistema a celle multiple

@export var maze_width: int = 32
@export var maze_height: int = 32
@export var cell_size: int = 20
@export var seed_value: int = 0
@export var meta_maze_size: int = 10

var maze: Array = []
var rng: RandomNumberGenerator

# Celle del labirinto: 0 = muro, 1 = passaggio
enum CellType { WALL, PATH }

# Meta-meta-labirinto (labirinto 10x10 padre)
var meta_meta_maze_connections: Dictionary = {}
var current_meta_cell_x: int = 0
var current_meta_cell_y: int = 0

# Meta-labirinto (labirinto 10x10 figlio della cella padre corrente)
var meta_maze_connections: Dictionary = {}
var current_cell_x: int = 0
var current_cell_y: int = 0

func _ready():
	generate_meta_meta_maze()
	select_random_starting_meta_cell()
	generate_meta_maze()
	select_random_starting_cell()
	generate_current_cell_maze()
	draw_maze()

func _process(_delta):
	# Gestione input per cambio cella
	if Input.is_action_just_pressed("ui_right"):
		move_to_cell(current_cell_x + 1, current_cell_y)
	elif Input.is_action_just_pressed("ui_left"):
		move_to_cell(current_cell_x - 1, current_cell_y)
	elif Input.is_action_just_pressed("ui_down"):
		move_to_cell(current_cell_x, current_cell_y + 1)
	elif Input.is_action_just_pressed("ui_up"):
		move_to_cell(current_cell_x, current_cell_y - 1)

func generate_meta_meta_maze():
	## Genera il meta-meta-labirinto 10x10 padre usando Eller
	# Inizializza il generatore random con il seed principale
	rng = RandomNumberGenerator.new()
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	
	print("Meta-meta-labirinto (padre) generato con seed: ", rng.seed)
	
	# Genera connessioni usando Eller
	meta_meta_maze_connections = eller_maze_generation(rng, meta_maze_size)

func select_random_starting_meta_cell():
	## Seleziona casualmente una cella padre di partenza
	current_meta_cell_x = rng.randi_range(0, meta_maze_size - 1)
	current_meta_cell_y = rng.randi_range(0, meta_maze_size - 1)
	print("Cella padre iniziale: (", current_meta_cell_x, ", ", current_meta_cell_y, ")")

func generate_meta_maze():
	## Genera il meta-labirinto 10x10 figlio per la cella padre corrente
	# Crea un seed unico per questa cella padre
	var meta_seed = seed_value + current_meta_cell_x * 100000 + current_meta_cell_y * 10000
	
	var meta_rng = RandomNumberGenerator.new()
	meta_rng.seed = meta_seed
	
	print("Meta-labirinto (figlio) per cella padre (", current_meta_cell_x, ", ", current_meta_cell_y, ") generato con seed: ", meta_seed)
	
	# Genera connessioni usando Eller
	meta_maze_connections = eller_maze_generation(meta_rng, meta_maze_size)

func eller_maze_generation(maze_rng: RandomNumberGenerator, size: int) -> Dictionary:
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
					add_connection_to_dict(connections, col, row, col + 1, row)
					
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
						add_connection_to_dict(connections, col, row, col, row + 1)
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
					add_connection_to_dict(connections, col, row, col + 1, row)
					
					var old_set = sets[col + 1]
					var new_set = sets[col]
					for i in range(size):
						if sets[i] == old_set:
							sets[i] = new_set
	
	return connections

func add_connection_to_dict(connections: Dictionary, x1: int, y1: int, x2: int, y2: int):
	## Aggiunge una connessione bidirezionale al dizionario specificato
	var key1 = Vector2i(x1, y1)
	var key2 = Vector2i(x2, y2)
	
	if not connections.has(key1):
		connections[key1] = []
	if not connections.has(key2):
		connections[key2] = []
	
	connections[key1].append(key2)
	connections[key2].append(key1)

func select_random_starting_cell():
	## Seleziona casualmente una cella figlio di partenza nel labirinto corrente
	var meta_rng = RandomNumberGenerator.new()
	meta_rng.seed = seed_value + current_meta_cell_x * 100000 + current_meta_cell_y * 10000
	
	current_cell_x = meta_rng.randi_range(0, meta_maze_size - 1)
	current_cell_y = meta_rng.randi_range(0, meta_maze_size - 1)
	print("Cella figlio iniziale: (", current_cell_x, ", ", current_cell_y, ")")

func move_to_cell(new_x: int, new_y: int):
	## Sposta alla cella specificata se connessa
	# Verifica che la cella sia valida
	if new_x < 0 or new_x >= meta_maze_size or new_y < 0 or new_y >= meta_maze_size:
		return
	
	# Verifica che ci sia una connessione
	var current_pos = Vector2i(current_cell_x, current_cell_y)
	var new_pos = Vector2i(new_x, new_y)
	
	if meta_maze_connections.has(current_pos):
		if new_pos in meta_maze_connections[current_pos]:
			current_cell_x = new_x
			current_cell_y = new_y
			print("Spostato a cella: (", current_cell_x, ", ", current_cell_y, ")")
			generate_current_cell_maze()
			draw_maze()

func generate_current_cell_maze():
	## Genera il labirinto 32x32 per la cella corrente
	# Crea un seed unico per questa cella (combinando coordinate padre e figlio)
	var cell_seed = seed_value + current_meta_cell_x * 100000 + current_meta_cell_y * 10000 + current_cell_x * 100 + current_cell_y
	
	var cell_rng = RandomNumberGenerator.new()
	cell_rng.seed = cell_seed
	
	# Inizializza la griglia con tutti muri
	maze = []
	for y in range(maze_height * 2 + 1):
		var row = []
		for x in range(maze_width * 2 + 1):
			row.append(CellType.WALL)
		maze.append(row)
	
	# Algoritmo di Eller per questa cella
	eller_algorithm_for_cell(cell_rng)
	
	# Aggiungi aperture nei bordi in base alle connessioni del meta-labirinto
	add_border_openings(cell_rng)
	
	print("Labirinto cella (", current_cell_x, ", ", current_cell_y, ") generato con seed: ", cell_seed)

func has_meta_connection(dx: int, dy: int) -> bool:
	## Verifica se c'è una connessione nella direzione specificata
	var target_x = current_cell_x + dx
	var target_y = current_cell_y + dy
	
	if target_x < 0 or target_x >= meta_maze_size or target_y < 0 or target_y >= meta_maze_size:
		return false
	
	var current_pos = Vector2i(current_cell_x, current_cell_y)
	var target_pos = Vector2i(target_x, target_y)
	
	if meta_maze_connections.has(current_pos):
		return target_pos in meta_maze_connections[current_pos]
	return false

func add_border_openings(cell_rng: RandomNumberGenerator):
	## Aggiunge aperture nei muri di confine in base alle connessioni
	# Prima controlla le connessioni interne del labirinto figlio
	# Poi controlla se questa cella è sul bordo e se il padre ha connessioni
	
	# Apertura a sinistra (ovest)
	if has_meta_connection(-1, 0):
		var opening_y = cell_rng.randi_range(1, maze_height - 1) * 2 + 1
		maze[opening_y][0] = CellType.PATH
	elif current_cell_x == 0 and has_meta_meta_connection(-1, 0):
		# Cella sul bordo sinistro del labirinto figlio E padre ha connessione
		var opening_y = cell_rng.randi_range(1, maze_height - 1) * 2 + 1
		maze[opening_y][0] = CellType.PATH
	
	# Apertura a destra (est)
	if has_meta_connection(1, 0):
		var opening_y = cell_rng.randi_range(1, maze_height - 1) * 2 + 1
		maze[opening_y][maze_width * 2] = CellType.PATH
	elif current_cell_x == meta_maze_size - 1 and has_meta_meta_connection(1, 0):
		# Cella sul bordo destro
		var opening_y = cell_rng.randi_range(1, maze_height - 1) * 2 + 1
		maze[opening_y][maze_width * 2] = CellType.PATH
	
	# Apertura in alto (nord)
	if has_meta_connection(0, -1):
		var opening_x = cell_rng.randi_range(1, maze_width - 1) * 2 + 1
		maze[0][opening_x] = CellType.PATH
	elif current_cell_y == 0 and has_meta_meta_connection(0, -1):
		# Cella sul bordo superiore
		var opening_x = cell_rng.randi_range(1, maze_width - 1) * 2 + 1
		maze[0][opening_x] = CellType.PATH
	
	# Apertura in basso (sud)
	if has_meta_connection(0, 1):
		var opening_x = cell_rng.randi_range(1, maze_width - 1) * 2 + 1
		maze[maze_height * 2][opening_x] = CellType.PATH
	elif current_cell_y == meta_maze_size - 1 and has_meta_meta_connection(0, 1):
		# Cella sul bordo inferiore
		var opening_x = cell_rng.randi_range(1, maze_width - 1) * 2 + 1
		maze[maze_height * 2][opening_x] = CellType.PATH

func has_meta_meta_connection(dx: int, dy: int) -> bool:
	## Verifica se c'è una connessione padre nella direzione specificata
	var target_x = current_meta_cell_x + dx
	var target_y = current_meta_cell_y + dy
	
	if target_x < 0 or target_x >= meta_maze_size or target_y < 0 or target_y >= meta_maze_size:
		return false
	
	var current_pos = Vector2i(current_meta_cell_x, current_meta_cell_y)
	var target_pos = Vector2i(target_x, target_y)
	
	if meta_meta_maze_connections.has(current_pos):
		return target_pos in meta_meta_maze_connections[current_pos]
	return false

func eller_algorithm_for_cell(cell_rng: RandomNumberGenerator):
	## Algoritmo di Eller per generare il labirinto di una singola cella
	var sets: Array = []
	var next_set_id: int = 0
	
	# Per ogni riga
	for row in range(maze_height):
		# Inizializza i set per questa riga
		if row == 0:
			for col in range(maze_width):
				sets.append(next_set_id)
				next_set_id += 1
		
		# Crea passaggio nella cella
		for col in range(maze_width):
			var cell_x = col * 2 + 1
			var cell_y = row * 2 + 1
			maze[cell_y][cell_x] = CellType.PATH
		
		# Connetti celle orizzontalmente (casualmente)
		for col in range(maze_width - 1):
			if sets[col] != sets[col + 1]:
				# Decidi casualmente se connettere (50% di probabilità)
				if cell_rng.randf() > 0.5:
					# Connetti le celle
					var wall_x = col * 2 + 2
					var wall_y = row * 2 + 1
					maze[wall_y][wall_x] = CellType.PATH
					
					# Unisci i set
					var old_set = sets[col + 1]
					var new_set = sets[col]
					for i in range(maze_width):
						if sets[i] == old_set:
							sets[i] = new_set
		
		# Se non è l'ultima riga, crea connessioni verticali
		if row < maze_height - 1:
			# Raggruppa celle per set
			var set_groups = {}
			for col in range(maze_width):
				var set_id = sets[col]
				if not set_groups.has(set_id):
					set_groups[set_id] = []
				set_groups[set_id].append(col)
			
			# Prepara i set per la prossima riga
			var new_sets = []
			for col in range(maze_width):
				new_sets.append(-1)
			
			# Per ogni set, crea almeno una connessione verticale
			for set_id in set_groups.keys():
				var columns = set_groups[set_id]
				var connections_made = false
				
				for col in columns:
					# Decidi casualmente se creare connessione verticale
					if cell_rng.randf() > 0.5 or not connections_made:
						var wall_x = col * 2 + 1
						var wall_y = row * 2 + 2
						maze[wall_y][wall_x] = CellType.PATH
						new_sets[col] = set_id
						connections_made = true
					else:
						# Questa cella inizia un nuovo set
						new_sets[col] = next_set_id
						next_set_id += 1
			
			sets = new_sets
		else:
			# Ultima riga: connetti tutte le celle con set diversi
			for col in range(maze_width - 1):
				if sets[col] != sets[col + 1]:
					var wall_x = col * 2 + 2
					var wall_y = row * 2 + 1
					maze[wall_y][wall_x] = CellType.PATH
					
					# Unisci i set
					var old_set = sets[col + 1]
					var new_set = sets[col]
					for i in range(maze_width):
						if sets[i] == old_set:
							sets[i] = new_set

func draw_maze():
	queue_redraw()

func _draw():
	if maze.is_empty():
		return
	
	for y in range(maze.size()):
		for x in range(maze[y].size()):
			var color = Color.BLACK if maze[y][x] == CellType.WALL else Color.WHITE
			var rect = Rect2(x * cell_size, y * cell_size, cell_size, cell_size)
			draw_rect(rect, color)

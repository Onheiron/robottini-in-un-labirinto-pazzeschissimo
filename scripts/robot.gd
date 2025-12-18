class_name Robot
extends RefCounted

## Robot che esplora autonomamente il labirinto con backtracking DFS

var position: Vector2
var maze_cell_size: int
var move_speed: float = 2.0  # Celle al secondo

# Stack per il backtracking: [{position: Vector2i, unvisited: Array}]
var exploration_stack: Array = []

# Stato movimento
var is_moving: bool = false
var move_target: Vector2
var move_progress: float = 0.0

# Area di spawn (dove non lasciare snodi)
var spawn_center: Vector2i
var spawn_radius: int = 2  # 64px / 20px cell_size ≈ 3 celle di raggio

# Coordinate della cella corrente nel sistema gerarchico
var current_meta_x: int
var current_meta_y: int
var current_cell_x: int
var current_cell_y: int

enum Direction { NORTH, SOUTH, EAST, WEST }

func _init(start_pos: Vector2, cell_size: int, meta_x: int, meta_y: int, cell_x: int, cell_y: int):
	position = start_pos
	maze_cell_size = cell_size
	spawn_center = Vector2i(int(start_pos.x / cell_size), int(start_pos.y / cell_size))
	current_meta_x = meta_x
	current_meta_y = meta_y
	current_cell_x = cell_x
	current_cell_y = cell_y

func get_grid_position() -> Vector2i:
	## Converte posizione pixel in coordinate griglia
	return Vector2i(int(position.x / maze_cell_size), int(position.y / maze_cell_size))

func update(delta: float, maze: Array, world_state) -> bool:
	## Aggiorna lo stato del robot. Ritorna true se si è mosso
	if is_moving:
		return _update_movement(delta, world_state)
	else:
		return _explore_next(maze, world_state)

func _update_movement(delta: float, world_state) -> bool:
	## Gestisce il movimento verso il target
	move_progress += delta * move_speed
	
	if move_progress >= 1.0:
		position = move_target
		is_moving = false
		move_progress = 0.0
		
		# Marca la cella come visitata
		var grid_pos = get_grid_position()
		world_state.mark_tile_visited(current_meta_x, current_meta_y, current_cell_x, current_cell_y, grid_pos.x, grid_pos.y)
		
		return true
	else:
		# Interpola tra posizione corrente e target
		var start_pos = Vector2(
			move_target.x - (move_target.x - position.x) / (1.0 - move_progress) if move_progress < 1.0 else position.x,
			move_target.y - (move_target.y - position.y) / (1.0 - move_progress) if move_progress < 1.0 else position.y
		)
		var t = move_progress
		position = start_pos.lerp(move_target, t)
		return false

func _explore_next(maze: Array, world_state) -> bool:
	## Decide la prossima mossa nell'esplorazione usando DFS
	var grid_pos = get_grid_position()
	
	# Trova tutte le celle accessibili non ancora visitate
	var unvisited_neighbors = _get_unvisited_neighbors(grid_pos, maze, world_state)
	
	if unvisited_neighbors.size() > 0:
		# Prima di muoverci, controlla se questa cella è uno snodo
		var all_neighbors = _get_available_neighbors(grid_pos, maze, world_state)
		if all_neighbors.size() > 2 and not _is_in_spawn_area(grid_pos):
			# È uno snodo (più di 2 aperture) e non nell'area di spawn
			world_state.place_object(current_meta_x, current_meta_y, current_cell_x, current_cell_y, Vector2(grid_pos.x, grid_pos.y), "junction", {})
		
		# Salva questa posizione nello stack se ha più scelte
		if unvisited_neighbors.size() > 1:
			exploration_stack.append({
				"position": grid_pos,
				"unvisited": unvisited_neighbors.duplicate()
			})
		
		# Scegli la prima cella non visitata (DFS)
		var next_pos = unvisited_neighbors[0]
		_move_to_position(next_pos)
		return true
	else:
		# Nessuna cella non visitata accessibile - backtrack
		return _backtrack(maze, world_state)

func _get_unvisited_neighbors(grid_pos: Vector2i, maze: Array, world_state) -> Array:
	## Trova tutte le celle accessibili adiacenti non ancora visitate
	var neighbors = []
	var checks = [
		Vector2i(grid_pos.x, grid_pos.y - 1),  # Nord
		Vector2i(grid_pos.x, grid_pos.y + 1),  # Sud
		Vector2i(grid_pos.x + 1, grid_pos.y),  # Est
		Vector2i(grid_pos.x - 1, grid_pos.y)   # Ovest
	]
	
	for pos in checks:
		if _can_move_to(pos.x, pos.y, maze, world_state):
			if not world_state.is_tile_visited(current_meta_x, current_meta_y, current_cell_x, current_cell_y, pos.x, pos.y):
				neighbors.append(pos)
	
	return neighbors

func _get_available_neighbors(grid_pos: Vector2i, maze: Array, world_state) -> Array:
	## Trova tutte le celle accessibili adiacenti (visitate o no)
	var neighbors = []
	var checks = [
		Vector2i(grid_pos.x, grid_pos.y - 1),  # Nord
		Vector2i(grid_pos.x, grid_pos.y + 1),  # Sud
		Vector2i(grid_pos.x + 1, grid_pos.y),  # Est
		Vector2i(grid_pos.x - 1, grid_pos.y)   # Ovest
	]
	
	for pos in checks:
		if _can_move_to(pos.x, pos.y, maze, world_state):
			neighbors.append(pos)
	
	return neighbors

func _is_in_spawn_area(grid_pos: Vector2i) -> bool:
	## Controlla se una cella è nell'area di spawn (64x64)
	var dx = abs(grid_pos.x - spawn_center.x)
	var dy = abs(grid_pos.y - spawn_center.y)
	return dx <= spawn_radius and dy <= spawn_radius

func _can_move_to(x: int, y: int, maze: Array, world_state) -> bool:
	## Verifica se il robot può muoversi in una cella
	if y < 0 or y >= maze.size() or x < 0 or x >= maze[0].size():
		return false
	
	# Controlla se è un passaggio (non muro)
	var is_removed = world_state.is_wall_removed_current(x, y)
	return maze[y][x] == 1 or is_removed  # 1 = PATH

func _move_to_position(grid_pos: Vector2i):
	## Inizia il movimento verso una posizione griglia
	move_target = Vector2(
		grid_pos.x * maze_cell_size + maze_cell_size / 2.0,
		grid_pos.y * maze_cell_size + maze_cell_size / 2.0
	)
	is_moving = true
	move_progress = 0.0

func _backtrack(maze: Array, world_state) -> bool:
	## Torna indietro all'ultimo snodo con celle non visitate
	while exploration_stack.size() > 0:
		var junction = exploration_stack.pop_back()
		var junction_pos = junction["position"]
		
		# Trova celle non visitate da questo snodo
		var unvisited = _get_unvisited_neighbors(junction_pos, maze, world_state)
		
		if unvisited.size() > 0:
			# C'è ancora qualcosa da esplorare, torna a questo snodo
			_move_to_position(junction_pos)
			return true
	
	# Stack vuoto - esplorazione completata
	return false

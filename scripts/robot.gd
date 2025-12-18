class_name Robot
extends RefCounted

## Robot che esplora autonomamente il labirinto usando diversi comportamenti

var position: Vector2
var maze_cell_size: int
var move_speed: float = 2.0  # Celle al secondo

# Comportamento corrente
var behavior: RobotBehavior

# Maze corrente (riferimento)
var current_maze: Array = []

# Coda di movimento per pathfinding
var move_queue: Array = []  # Array di Vector2i

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

func _init(start_pos: Vector2, cell_size: int, meta_x: int, meta_y: int, cell_x: int, cell_y: int, behavior_type: String = "DFS"):
	position = start_pos
	maze_cell_size = cell_size
	spawn_center = Vector2i(int(start_pos.x / cell_size), int(start_pos.y / cell_size))
	current_meta_x = meta_x
	current_meta_y = meta_y
	current_cell_x = cell_x
	current_cell_y = cell_y
	
	# Inizializza il comportamento
	if behavior_type == "Junction":
		behavior = JunctionBehavior.new(self)
	else:
		behavior = DFSBehavior.new(self)

func get_grid_position() -> Vector2i:
	## Converte posizione pixel in coordinate griglia
	return Vector2i(int(position.x / maze_cell_size), int(position.y / maze_cell_size))

func update(delta: float, maze: Array, world_state) -> bool:
	## Aggiorna lo stato del robot. Ritorna true se si è mosso
	current_maze = maze
	if is_moving:
		return _update_movement(delta, world_state)
	elif move_queue.size() > 0:
		# C'è un percorso da seguire
		var next_pos = move_queue.pop_front()
		move_to_position(next_pos)
		return true
	else:
		return behavior.update(delta, maze, world_state)

func _update_movement(delta: float, world_state) -> bool:
	## Gestisce il movimento verso il target
	move_progress += delta * move_speed
	
	if move_progress >= 1.0:
		position = move_target
		is_moving = false
		move_progress = 0.0
		
		# Notifica il comportamento dell'arrivo
		var grid_pos = get_grid_position()
		behavior.on_arrival(grid_pos, current_maze, world_state)
		
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

## Funzioni di utilità pubbliche per i behavior

func get_unvisited_neighbors(grid_pos: Vector2i, maze: Array, world_state) -> Array:
	## Trova tutte le celle accessibili adiacenti non ancora visitate
	var neighbors = []
	var checks = [
		Vector2i(grid_pos.x, grid_pos.y - 1),  # Nord
		Vector2i(grid_pos.x, grid_pos.y + 1),  # Sud
		Vector2i(grid_pos.x + 1, grid_pos.y),  # Est
		Vector2i(grid_pos.x - 1, grid_pos.y)   # Ovest
	]
	
	for pos in checks:
		if can_move_to(pos.x, pos.y, maze, world_state):
			if not world_state.is_tile_visited(current_meta_x, current_meta_y, current_cell_x, current_cell_y, pos.x, pos.y):
				neighbors.append(pos)
	
	return neighbors

func get_available_neighbors(grid_pos: Vector2i, maze: Array, world_state) -> Array:
	## Trova tutte le celle accessibili adiacenti (visitate o no)
	var neighbors = []
	var checks = [
		Vector2i(grid_pos.x, grid_pos.y - 1),  # Nord
		Vector2i(grid_pos.x, grid_pos.y + 1),  # Sud
		Vector2i(grid_pos.x + 1, grid_pos.y),  # Est
		Vector2i(grid_pos.x - 1, grid_pos.y)   # Ovest
	]
	
	for pos in checks:
		if can_move_to(pos.x, pos.y, maze, world_state):
			neighbors.append(pos)
	
	return neighbors

func is_in_spawn_area(grid_pos: Vector2i) -> bool:
	## Controlla se una cella è nell'area di spawn (64x64)
	var dx = abs(grid_pos.x - spawn_center.x)
	var dy = abs(grid_pos.y - spawn_center.y)
	return dx <= spawn_radius and dy <= spawn_radius

func can_move_to(x: int, y: int, maze: Array, world_state) -> bool:
	## Verifica se il robot può muoversi in una cella
	if y < 0 or y >= maze.size() or x < 0 or x >= maze[0].size():
		return false
	
	# Controlla se è un passaggio (non muro)
	var is_removed = world_state.is_wall_removed_current(x, y)
	return maze[y][x] == 1 or is_removed  # 1 = PATH

func move_to_position(grid_pos: Vector2i):
	## Inizia il movimento verso una posizione griglia
	move_target = Vector2(
		grid_pos.x * maze_cell_size + maze_cell_size / 2.0,
		grid_pos.y * maze_cell_size + maze_cell_size / 2.0
	)
	is_moving = true
	move_progress = 0.0

func move_to_position_with_path(target: Vector2i, maze: Array, world_state):
	## Muove il robot verso una posizione usando pathfinding
	var current_pos = get_grid_position()
	
	# Se siamo già lì, non fare nulla
	if current_pos == target:
		return
	
	# Calcola il percorso con BFS
	var path = _find_path_bfs(current_pos, target, maze, world_state)
	
	if path.size() > 0:
		# Rimuovi la posizione corrente se è la prima
		if path[0] == current_pos:
			path.pop_front()
		
		# Imposta la coda di movimento
		move_queue = path
	else:
		# Nessun percorso trovato, muoviti direttamente
		move_to_position(target)

func _find_path_bfs(start: Vector2i, goal: Vector2i, maze: Array, world_state) -> Array:
	## Trova un percorso con BFS
	var queue: Array = [[start]]
	var visited: Dictionary = {start: true}
	
	while queue.size() > 0:
		var path = queue.pop_front()
		var current = path[path.size() - 1]
		
		if current == goal:
			return path
		
		# Esplora i vicini
		var neighbors = [
			Vector2i(current.x, current.y - 1),
			Vector2i(current.x, current.y + 1),
			Vector2i(current.x + 1, current.y),
			Vector2i(current.x - 1, current.y)
		]
		
		for neighbor in neighbors:
			if not visited.has(neighbor) and can_move_to(neighbor.x, neighbor.y, maze, world_state):
				visited[neighbor] = true
				var new_path = path.duplicate()
				new_path.append(neighbor)
				queue.append(new_path)
	
	return []

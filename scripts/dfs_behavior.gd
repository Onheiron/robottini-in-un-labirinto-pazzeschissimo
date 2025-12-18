class_name DFSBehavior
extends RobotBehavior

## Comportamento DFS classico - esplora sempre verso celle non visitate

# Stack per il backtracking: [{position: Vector2i, unvisited: Array}]
var exploration_stack: Array = []

func get_behavior_name() -> String:
	return "DFS"

func update(_delta: float, maze: Array, world_state) -> bool:
	if robot_ref.is_moving:
		return false
	
	return _explore_next(maze, world_state)

func on_arrival(grid_pos: Vector2i, maze: Array, world_state):
	## Marca la cella visitata e controlla se è uno snodo
	world_state.mark_tile_visited(
		robot_ref.current_meta_x, robot_ref.current_meta_y,
		robot_ref.current_cell_x, robot_ref.current_cell_y,
		grid_pos.x, grid_pos.y
	)
	
	# Controlla se è uno snodo (più di 2 aperture)
	var all_neighbors = robot_ref.get_available_neighbors(grid_pos, maze, world_state)
	if all_neighbors.size() > 2 and not robot_ref.is_in_spawn_area(grid_pos):
		world_state.place_object(
			robot_ref.current_meta_x, robot_ref.current_meta_y,
			robot_ref.current_cell_x, robot_ref.current_cell_y,
			Vector2(grid_pos.x, grid_pos.y), "junction", {}
		)

func _explore_next(maze: Array, world_state) -> bool:
	var grid_pos = robot_ref.get_grid_position()
	
	# Trova tutte le celle accessibili non ancora visitate
	var unvisited_neighbors = robot_ref.get_unvisited_neighbors(grid_pos, maze, world_state)
	
	if unvisited_neighbors.size() > 0:
		# Salva questa posizione nello stack se ha più scelte
		if unvisited_neighbors.size() > 1:
			exploration_stack.append({
				"position": grid_pos,
				"unvisited": unvisited_neighbors.duplicate()
			})
		
		# Scegli la prima cella non visitata (DFS)
		var next_pos = unvisited_neighbors[0]
		robot_ref.move_to_position(next_pos)
		return true
	else:
		# Nessuna cella non visitata accessibile - backtrack
		return _backtrack(maze, world_state)

func _backtrack(maze: Array, world_state) -> bool:
	while exploration_stack.size() > 0:
		var junction = exploration_stack.pop_back()
		var junction_pos = junction["position"]
		
		# Trova celle non visitate da questo snodo
		var unvisited = robot_ref.get_unvisited_neighbors(junction_pos, maze, world_state)
		
		if unvisited.size() > 0:
			# C'è ancora qualcosa da esplorare, torna a questo snodo con pathfinding
			robot_ref.move_to_position_with_path(junction_pos, maze, world_state)
			return true
	
	# Stack vuoto - esplorazione completata
	return false

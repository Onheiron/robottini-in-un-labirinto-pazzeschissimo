class_name JunctionBehavior
extends RobotBehavior

## Comportamento basato su svincoli - esplora in ampiezza (BFS) l'albero di svincoli

# Albero di svincoli: {position: {branches: Array, explored: Array, children: Array[position], parent: position}}
var junction_tree: Dictionary = {}
var root_junctions: Array = []  # Svincoli radice adiacenti all'area spawn
var current_junction_pos: Vector2i
var exploring_branch: bool = false

func get_behavior_name() -> String:
	return "Junction Explorer"

func update(_delta: float, maze: Array, world_state) -> bool:
	if robot_ref.is_moving:
		return false
	
	return _explore_next(maze, world_state)

func on_arrival(grid_pos: Vector2i, maze: Array, world_state):
	## Marca la cella visitata e controlla se è uno svincolo
	world_state.mark_tile_visited(
		robot_ref.current_meta_x, robot_ref.current_meta_y,
		robot_ref.current_cell_x, robot_ref.current_cell_y,
		grid_pos.x, grid_pos.y
	)
	
	# Controlla se è uno svincolo (più di 2 aperture) fuori dall'area spawn
	var all_neighbors = robot_ref.get_available_neighbors(grid_pos, maze, world_state)
	if all_neighbors.size() > 2 and not robot_ref.is_in_spawn_area(grid_pos):
		world_state.place_object(
			robot_ref.current_meta_x, robot_ref.current_meta_y,
			robot_ref.current_cell_x, robot_ref.current_cell_y,
			Vector2(grid_pos.x, grid_pos.y), "junction", {}
		)
		
		# Registra lo svincolo nell'albero se non esiste già
		if not junction_tree.has(grid_pos):
			junction_tree[grid_pos] = {
				"branches": all_neighbors,
				"explored": [],
				"children": [],
				"parent": current_junction_pos if exploring_branch else Vector2i(-1, -1)
			}
			
			# Se stavamo esplorando un ramo, questo è un figlio dello svincolo precedente
			if exploring_branch and junction_tree.has(current_junction_pos):
				junction_tree[current_junction_pos]["children"].append(grid_pos)
			# Se non c'è padre, è una radice
			elif junction_tree[grid_pos]["parent"] == Vector2i(-1, -1):
				if not root_junctions.has(grid_pos):
					root_junctions.append(grid_pos)

func _explore_next(maze: Array, world_state) -> bool:
	var grid_pos = robot_ref.get_grid_position()
	
	# Se stiamo esplorando un ramo, continua
	if exploring_branch:
		return _continue_branch_exploration(grid_pos, maze, world_state)
	
	# Trova il prossimo svincolo da esplorare con ricerca BFS
	var target_junction = _find_next_incomplete_junction_bfs()
	
	if target_junction != Vector2i(-1, -1):
		# Abbiamo uno svincolo da esplorare
		current_junction_pos = target_junction
		
		# Se non siamo già lì, muoviti verso di esso
		if grid_pos != target_junction:
			robot_ref.move_to_position(target_junction)
			return true
		
		# Siamo allo svincolo, scegli un ramo non esplorato
		return _start_exploring_branch(grid_pos, maze, world_state)
	else:
		# Nessuno svincolo da esplorare, cerca nuove radici dall'area spawn
		return _find_new_root_junction(grid_pos, maze, world_state)

func _continue_branch_exploration(grid_pos: Vector2i, maze: Array, world_state) -> bool:
	## Continua a esplorare lungo il ramo corrente
	var neighbors = robot_ref.get_available_neighbors(grid_pos, maze, world_state)
	
	# Se troviamo uno svincolo, ferma l'esplorazione del ramo
	if neighbors.size() > 2 and not robot_ref.is_in_spawn_area(grid_pos):
		exploring_branch = false
		# L'on_arrival lo registrerà nell'albero
		return _explore_next(maze, world_state)
	
	# Continua lungo il percorso
	var unvisited = robot_ref.get_unvisited_neighbors(grid_pos, maze, world_state)
	if unvisited.size() > 0:
		robot_ref.move_to_position(unvisited[0])
		return true
	
	# Vicolo cieco - torna alla ricerca BFS
	exploring_branch = false
	return _explore_next(maze, world_state)

func _find_next_incomplete_junction_bfs() -> Vector2i:
	## Cerca con BFS il primo svincolo non completamente esplorato
	if root_junctions.is_empty():
		return Vector2i(-1, -1)
	
	# Coda per BFS: inizia dalle radici
	var queue: Array = []
	for root in root_junctions:
		queue.append(root)
	
	while queue.size() > 0:
		var current = queue.pop_front()
		
		# Verifica se questo svincolo esiste e non è completamente esplorato
		if not junction_tree.has(current):
			continue
			
		var junction = junction_tree[current]
		if junction["explored"].size() < junction["branches"].size():
			# Trovato uno svincolo incompleto
			return current
		
		# Aggiungi i figli alla coda
		for child in junction["children"]:
			queue.append(child)
	
	# Nessuno svincolo incompleto trovato
	return Vector2i(-1, -1)

func _start_exploring_branch(_grid_pos: Vector2i, _maze: Array, _world_state) -> bool:
	## Inizia a esplorare un ramo dallo svincolo corrente
	if not junction_tree.has(current_junction_pos):
		return false
	
	var junction = junction_tree[current_junction_pos]
	var branches = junction["branches"]
	var explored = junction["explored"]
	
	# Trova rami non esplorati
	var unexplored = []
	for branch in branches:
		var is_explored = false
		for exp_branch in explored:
			if exp_branch == branch:
				is_explored = true
				break
		if not is_explored:
			unexplored.append(branch)
	
	if unexplored.size() > 0:
		# Scegli il primo ramo non esplorato
		var chosen = unexplored[0]
		explored.append(chosen)
		
		# Inizia a esplorare
		exploring_branch = true
		robot_ref.move_to_position(chosen)
		return true
	
	return false

func _find_new_root_junction(grid_pos: Vector2i, maze: Array, world_state) -> bool:
	## Cerca un nuovo svincolo radice adiacente all'area spawn
	# Se non siamo nell'area spawn, torniamo prima lì
	if not robot_ref.is_in_spawn_area(grid_pos):
		# Torna verso il centro dell'area spawn
		var spawn_center = robot_ref.spawn_center
		robot_ref.move_to_position(spawn_center)
		return true
	
	# Cerca svincoli adiacenti non ancora esplorati
	var neighbors = robot_ref.get_available_neighbors(grid_pos, maze, world_state)
	for neighbor in neighbors:
		# Se è uno svincolo non nell'albero, esplora verso di esso
		var is_junction = robot_ref.get_available_neighbors(neighbor, maze, world_state).size() > 2
		if is_junction and not junction_tree.has(neighbor) and not robot_ref.is_in_spawn_area(neighbor):
			robot_ref.move_to_position(neighbor)
			return true
	
	# Prova a muoverti verso celle non visitate
	var unvisited = robot_ref.get_unvisited_neighbors(grid_pos, maze, world_state)
	if unvisited.size() > 0:
		robot_ref.move_to_position(unvisited[0])
		return true
	
	# Tutto esplorato
	return false

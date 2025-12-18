class_name JunctionBehavior
extends RobotBehavior

## Comportamento basato su svincoli - esplora completamente uno svincolo alla volta

# Stack di svincoli da esplorare: [{position: Vector2i, branches: Array, explored: Array}]
var junction_stack: Array = []
var current_junction: Dictionary = {}

# Stato del percorso corrente
var exploring_branch: bool = false
var branch_start_junction: Vector2i

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
	
	# Controlla se è uno svincolo (più di 2 aperture)
	var all_neighbors = robot_ref.get_available_neighbors(grid_pos, maze, world_state)
	if all_neighbors.size() > 2 and not robot_ref.is_in_spawn_area(grid_pos):
		world_state.place_object(
			robot_ref.current_meta_x, robot_ref.current_meta_y,
			robot_ref.current_cell_x, robot_ref.current_cell_y,
			Vector2(grid_pos.x, grid_pos.y), "junction", {}
		)
		
		# Se stavamo esplorando un ramo, abbiamo trovato un nuovo svincolo
		if exploring_branch:
			_handle_new_junction_found(grid_pos, all_neighbors)
			exploring_branch = false

func _handle_new_junction_found(pos: Vector2i, neighbors: Array):
	## Gestisce la scoperta di un nuovo svincolo durante l'esplorazione
	# Se lo svincolo precedente ha ancora rami da esplorare, salva questo nuovo svincolo
	if not current_junction.is_empty():
		var explored = current_junction["explored"]
		var branches = current_junction["branches"]
		
		if explored.size() < branches.size():
			# Lo svincolo precedente ha ancora rami, salviamo questo per dopo
			junction_stack.append({
				"position": pos,
				"branches": neighbors,
				"explored": []
			})
			return
	
	# Altrimenti questo diventa lo svincolo corrente
	current_junction = {
		"position": pos,
		"branches": neighbors,
		"explored": []
	}

func _explore_next(maze: Array, world_state) -> bool:
	var grid_pos = robot_ref.get_grid_position()
	
	# Se stiamo esplorando un ramo, continua lungo quel ramo
	if exploring_branch:
		return _continue_branch_exploration(grid_pos, maze, world_state)
	
	# Se non abbiamo uno svincolo corrente, ne cerchiamo uno
	if current_junction.is_empty():
		return _find_first_junction(grid_pos, maze, world_state)
	
	# Se abbiamo uno svincolo corrente, scegliamo un nuovo ramo da esplorare
	return _start_new_branch(grid_pos, maze, world_state)

func _continue_branch_exploration(grid_pos: Vector2i, maze: Array, world_state) -> bool:
	## Continua a esplorare lungo il ramo corrente
	var neighbors = robot_ref.get_available_neighbors(grid_pos, maze, world_state)
	
	# Se è uno svincolo, lo gestiamo qui
	if neighbors.size() > 2 and not robot_ref.is_in_spawn_area(grid_pos):
		# Abbiamo trovato un nuovo svincolo durante l'esplorazione
		exploring_branch = false
		
		# Se non abbiamo ancora uno svincolo corrente, questo diventa il primo
		if current_junction.is_empty():
			current_junction = {
				"position": grid_pos,
				"branches": neighbors,
				"explored": []
			}
			# Inizia subito a esplorare i suoi rami
			return _start_new_branch(grid_pos, maze, world_state)
		else:
			# Abbiamo già uno svincolo corrente, gestiamo questo nuovo
			var explored = current_junction["explored"]
			var branches = current_junction["branches"]
			
			if explored.size() < branches.size():
				# Lo svincolo precedente ha ancora rami, salviamo questo per dopo
				junction_stack.append({
					"position": grid_pos,
					"branches": neighbors,
					"explored": []
				})
				# Torna allo svincolo precedente per finire i suoi rami
				robot_ref.move_to_position(current_junction["position"])
				return true
			else:
				# Lo svincolo precedente è completato, questo diventa il corrente
				current_junction = {
					"position": grid_pos,
					"branches": neighbors,
					"explored": []
				}
				return _start_new_branch(grid_pos, maze, world_state)
	
	# Altrimenti continua lungo il percorso
	var unvisited = robot_ref.get_unvisited_neighbors(grid_pos, maze, world_state)
	if unvisited.size() > 0:
		robot_ref.move_to_position(unvisited[0])
		return true
	
	# Vicolo cieco o già tutto visitato - torna allo svincolo
	exploring_branch = false
	if not current_junction.is_empty():
		robot_ref.move_to_position(current_junction["position"])
		return true
	
	return false

func _find_first_junction(grid_pos: Vector2i, maze: Array, world_state) -> bool:
	## Trova il primo svincolo da cui iniziare
	var neighbors = robot_ref.get_available_neighbors(grid_pos, maze, world_state)
	
	if neighbors.size() > 2:
		# Questa posizione è già uno svincolo
		current_junction = {
			"position": grid_pos,
			"branches": neighbors,
			"explored": []
		}
		return _start_new_branch(grid_pos, maze, world_state)
	elif neighbors.size() > 0:
		# Muoviti finché non trovi uno svincolo
		var unvisited = robot_ref.get_unvisited_neighbors(grid_pos, maze, world_state)
		if unvisited.size() > 0:
			robot_ref.move_to_position(unvisited[0])
			return true
	
	return false

func _start_new_branch(grid_pos: Vector2i, _maze: Array, _world_state) -> bool:
	## Inizia a esplorare un nuovo ramo dallo svincolo corrente
	var junction_pos = current_junction["position"]
	
	# Se non siamo allo svincolo, torniamo prima lì
	if grid_pos != junction_pos:
		robot_ref.move_to_position(junction_pos)
		return true
	
	# Trova rami non ancora esplorati
	var branches = current_junction["branches"]
	var explored = current_junction["explored"]
	var unexplored_branches = []
	
	for branch in branches:
		var already_explored = false
		for explored_branch in explored:
			if explored_branch == branch:
				already_explored = true
				break
		if not already_explored:
			unexplored_branches.append(branch)
	
	if unexplored_branches.size() > 0:
		# Scegli un ramo casuale
		var chosen_branch = unexplored_branches[randi() % unexplored_branches.size()]
		explored.append(chosen_branch)
		
		# Inizia a esplorare questo ramo
		exploring_branch = true
		branch_start_junction = junction_pos
		robot_ref.move_to_position(chosen_branch)
		return true
	else:
		# Tutti i rami esplorati - passa al prossimo svincolo nello stack
		if junction_stack.size() > 0:
			current_junction = junction_stack.pop_back()
			robot_ref.move_to_position(current_junction["position"])
			return true
		else:
			# Esplorazione completata
			current_junction = {}
			return false

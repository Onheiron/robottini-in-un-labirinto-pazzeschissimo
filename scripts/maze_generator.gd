extends Node2D

## Generatore principale del labirinto gerarchico

@export var maze_width: int = 32
@export var maze_height: int = 32
@export var cell_size: int = 20
@export var seed_value: int = 0
@export var meta_maze_size: int = 10
@export_enum("DFS", "Junction") var robot_behavior: String = "DFS"

var maze: Array = []
var rng: RandomNumberGenerator

# Meta-meta-labirinto (labirinto 10x10 padre)
var meta_meta_maze_connections: Dictionary = {}
var current_meta_cell_x: int = 0
var current_meta_cell_y: int = 0

# Meta-labirinto (labirinto 10x10 figlio della cella padre corrente)
var meta_maze_connections: Dictionary = {}
var current_cell_x: int = 0
var current_cell_y: int = 0

# Minimappa
var minimap: Minimap

# Stato del mondo (modifiche al labirinto procedurale)
var world_state: WorldState

# Robot esploratore
var robot: Robot

# Coordinate iniziali
var start_meta_x: int
var start_meta_y: int
var start_cell_x: int
var start_cell_y: int

# Zoom e pan
var zoom_level: float = 1.0
var pan_offset: Vector2 = Vector2.ZERO
var is_panning: bool = false
var pan_start_mouse: Vector2
var pan_start_offset: Vector2

func _ready():
	minimap = Minimap.new()
	minimap.meta_maze_size = meta_maze_size
	
	world_state = WorldState.new()
	
	generate_meta_meta_maze()
	select_random_starting_meta_cell()
	generate_meta_maze()
	select_random_starting_cell()
	
	# Salva le coordinate iniziali
	start_meta_x = current_meta_cell_x
	start_meta_y = current_meta_cell_y
	start_cell_x = current_cell_x
	start_cell_y = current_cell_y
	
	# Crea area di spawn con cerchio rosso
	setup_spawn_area()
	
	# Crea il robot esploratore
	setup_robot()
	
	generate_current_cell_maze()
	record_current_cell()
	draw_maze()

func _process(_delta):
	# Aggiorna il robot sempre (anche fuori dalla cella corrente)
	if robot != null:
		world_state.set_current_cell(robot.current_meta_x, robot.current_meta_y, robot.current_cell_x, robot.current_cell_y)
		var moved = robot.update(_delta, maze, world_state)
		
		# RIDISEGNA SEMPRE per mostrare il movimento fluido del robot
		if moved or robot.is_moving:
			# Marca la tile visitata solo quando raggiunge effettivamente una nuova cella
			if moved:
				var grid_pos = robot.get_grid_position()
				world_state.mark_tile_visited(robot.current_meta_x, robot.current_meta_y, robot.current_cell_x, robot.current_cell_y, grid_pos.x, grid_pos.y)
			draw_maze()
	
	# Gestione input per cambio cella (solo se non stiamo pannando)
	if not is_panning:
		if Input.is_action_just_pressed("ui_right"):
			move_to_cell(current_cell_x + 1, current_cell_y)
		elif Input.is_action_just_pressed("ui_left"):
			move_to_cell(current_cell_x - 1, current_cell_y)
		elif Input.is_action_just_pressed("ui_down"):
			move_to_cell(current_cell_x, current_cell_y + 1)
		elif Input.is_action_just_pressed("ui_up"):
			move_to_cell(current_cell_x, current_cell_y - 1)

func _unhandled_input(event: InputEvent):
	# Gestione zoom con scroll (wheel mouse o trackpad)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# Calcola la posizione del mouse nel mondo prima dello zoom (relativa a questo Node2D)
			var mouse_pos = get_local_mouse_position()
			var world_pos = (mouse_pos - pan_offset) / zoom_level
			
			# Applica zoom
			var old_zoom = zoom_level
			zoom_level = min(zoom_level * 1.1, 8.0)
			
			# Aggiusta il pan per mantenere il punto sotto il mouse fisso
			pan_offset = mouse_pos - world_pos * zoom_level
			
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# Calcola la posizione del mouse nel mondo prima dello zoom (relativa a questo Node2D)
			var mouse_pos = get_local_mouse_position()
			var world_pos = (mouse_pos - pan_offset) / zoom_level
			
			# Applica zoom
			zoom_level = max(zoom_level / 1.1, 1.0)
			
			# Aggiusta il pan per mantenere il punto sotto il mouse fisso
			if zoom_level == 1.0:
				pan_offset = Vector2.ZERO
			else:
				pan_offset = mouse_pos - world_pos * zoom_level
			
			queue_redraw()
			get_viewport().set_input_as_handled()
		# Gestione pan con drag mouse (solo se zoommato)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and zoom_level > 1.0:
				is_panning = true
				pan_start_mouse = event.position
				pan_start_offset = pan_offset
			else:
				is_panning = false
	
	# Supporto per gesti trackpad su Mac (pinch/pan)
	if event is InputEventPanGesture:
		# Calcola la posizione del mouse nel mondo prima dello zoom (relativa a questo Node2D)
		var mouse_pos = get_local_mouse_position()
		var world_pos = (mouse_pos - pan_offset) / zoom_level
		
		# Delta.y negativo = scroll up = zoom in
		if event.delta.y < 0:
			zoom_level = min(zoom_level * 1.05, 8.0)
		else:
			zoom_level = max(zoom_level / 1.05, 1.0)
		
		# Aggiusta il pan per mantenere il punto sotto il mouse fisso
		if zoom_level == 1.0:
			pan_offset = Vector2.ZERO
		else:
			pan_offset = mouse_pos - world_pos * zoom_level
		
		queue_redraw()
		get_viewport().set_input_as_handled()
		get_viewport().set_input_as_handled()
	
	if event is InputEventMouseMotion and is_panning:
		var delta = event.position - pan_start_mouse
		pan_offset = pan_start_offset + delta
		queue_redraw()

func generate_meta_meta_maze():
	## Genera il meta-meta-labirinto 10x10 padre usando Eller
	rng = RandomNumberGenerator.new()
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	
	print("Meta-meta-labirinto (padre) generato con seed: ", rng.seed)
	meta_meta_maze_connections = MazeBuilder.generate_maze_connections(rng, meta_maze_size)

func select_random_starting_meta_cell():
	## Seleziona casualmente una cella padre di partenza
	current_meta_cell_x = rng.randi_range(0, meta_maze_size - 1)
	current_meta_cell_y = rng.randi_range(0, meta_maze_size - 1)
	print("Cella padre iniziale: (", current_meta_cell_x, ", ", current_meta_cell_y, ")")

func generate_meta_maze():
	## Genera il meta-labirinto 10x10 figlio per la cella padre corrente
	var meta_seed = seed_value + current_meta_cell_x * 100000 + current_meta_cell_y * 10000
	var meta_rng = RandomNumberGenerator.new()
	meta_rng.seed = meta_seed
	
	print("Meta-labirinto (figlio) per cella padre (", current_meta_cell_x, ", ", current_meta_cell_y, ") generato con seed: ", meta_seed)
	meta_maze_connections = MazeBuilder.generate_maze_connections(meta_rng, meta_maze_size)

func select_random_starting_cell():
	## Seleziona casualmente una cella figlio di partenza nel labirinto corrente
	var meta_rng = RandomNumberGenerator.new()
	meta_rng.seed = seed_value + current_meta_cell_x * 100000 + current_meta_cell_y * 10000
	
	current_cell_x = meta_rng.randi_range(0, meta_maze_size - 1)
	current_cell_y = meta_rng.randi_range(0, meta_maze_size - 1)
	print("Cella figlio iniziale: (", current_cell_x, ", ", current_cell_y, ")")

func move_to_cell(new_x: int, new_y: int):
	## Sposta alla cella specificata se connessa (gestisce anche cambio cella padre)
	if new_x >= 0 and new_x < meta_maze_size and new_y >= 0 and new_y < meta_maze_size:
		# Movimento interno al labirinto figlio
		var current_pos = Vector2i(current_cell_x, current_cell_y)
		var new_pos = Vector2i(new_x, new_y)
		
		if meta_maze_connections.has(current_pos):
			if new_pos in meta_maze_connections[current_pos]:
				current_cell_x = new_x
				current_cell_y = new_y
				print("Spostato a cella figlio: (", current_cell_x, ", ", current_cell_y, ")")
				generate_current_cell_maze()
				record_current_cell()
				draw_maze()
	else:
		# Movimento oltre i confini - potenziale cambio cella padre
		var new_meta_x = current_meta_cell_x
		var new_meta_y = current_meta_cell_y
		var new_child_x = new_x
		var new_child_y = new_y
		
		if new_x < 0:
			new_meta_x -= 1
			new_child_x = meta_maze_size - 1
		elif new_x >= meta_maze_size:
			new_meta_x += 1
			new_child_x = 0
		
		if new_y < 0:
			new_meta_y -= 1
			new_child_y = meta_maze_size - 1
		elif new_y >= meta_maze_size:
			new_meta_y += 1
			new_child_y = 0
		
		if new_meta_x < 0 or new_meta_x >= meta_maze_size or new_meta_y < 0 or new_meta_y >= meta_maze_size:
			return
		
		var current_meta_pos = Vector2i(current_meta_cell_x, current_meta_cell_y)
		var new_meta_pos = Vector2i(new_meta_x, new_meta_y)
		
		if meta_meta_maze_connections.has(current_meta_pos):
			if new_meta_pos in meta_meta_maze_connections[current_meta_pos]:
				current_meta_cell_x = new_meta_x
				current_meta_cell_y = new_meta_y
				print("Spostato a cella padre: (", current_meta_cell_x, ", ", current_meta_cell_y, ")")
				
				generate_meta_maze()
				current_cell_x = new_child_x
				current_cell_y = new_child_y
				print("Entrato in cella figlio: (", current_cell_x, ", ", current_cell_y, ")")
				
				generate_current_cell_maze()
				record_current_cell()
				draw_maze()

func setup_spawn_area():
	## Crea l'area di spawn iniziale con cerchio rosso e area sgombra
	var maze_center = Vector2((maze_width * 2 + 1) / 2.0, (maze_height * 2 + 1) / 2.0)
	
	# Rimuovi muri in un'area 64x64 pixel = circa 3.2 celle del labirinto
	var clear_area_size = Vector2(4, 4)  # In unità di griglia
	world_state.clear_area(start_meta_x, start_meta_y, start_cell_x, start_cell_y, maze_center, clear_area_size)
	
	# Piazza il cerchio rosso al centro (48x48 pixel)
	var circle_position = Vector2(maze_center.x * cell_size, maze_center.y * cell_size)
	world_state.place_object(start_meta_x, start_meta_y, start_cell_x, start_cell_y, circle_position, "spawn_circle", {"radius": 24, "color": Color.RED})

func setup_robot():
	## Crea il robot esploratore vicino alla base
	var maze_center = Vector2((maze_width * 2 + 1) / 2.0, (maze_height * 2 + 1) / 2.0)
	var robot_spawn = Vector2((maze_center.x + 2) * cell_size, maze_center.y * cell_size)
	
	robot = Robot.new(robot_spawn, cell_size, start_meta_x, start_meta_y, start_cell_x, start_cell_y, robot_behavior)

func record_current_cell():
	## Registra la cella corrente come visitata
	var openings = {
		"north": has_any_opening_north(),
		"south": has_any_opening_south(),
		"east": has_any_opening_east(),
		"west": has_any_opening_west()
	}
	minimap.record_cell(current_meta_cell_x, current_meta_cell_y, current_cell_x, current_cell_y, openings)

func has_any_opening_north() -> bool:
	return has_meta_connection(0, -1) or (current_cell_y == 0 and has_meta_meta_connection(0, -1))

func has_any_opening_south() -> bool:
	return has_meta_connection(0, 1) or (current_cell_y == meta_maze_size - 1 and has_meta_meta_connection(0, 1))

func has_any_opening_east() -> bool:
	return has_meta_connection(1, 0) or (current_cell_x == meta_maze_size - 1 and has_meta_meta_connection(1, 0))

func has_any_opening_west() -> bool:
	return has_meta_connection(-1, 0) or (current_cell_x == 0 and has_meta_meta_connection(-1, 0))

func generate_current_cell_maze():
	## Genera il labirinto 32x32 per la cella corrente
	var cell_seed = seed_value + current_meta_cell_x * 100000 + current_meta_cell_y * 10000 + current_cell_x * 100 + current_cell_y
	var cell_rng = RandomNumberGenerator.new()
	cell_rng.seed = cell_seed
	
	maze = MazeBuilder.generate_cell_maze(cell_rng, maze_width, maze_height)
	add_border_openings(cell_rng)
	
	print("Labirinto cella (", current_cell_x, ", ", current_cell_y, ") generato con seed: ", cell_seed)

func has_meta_connection(dx: int, dy: int) -> bool:
	## Verifica se c'è una connessione figlio nella direzione specificata
	var target_x = current_cell_x + dx
	var target_y = current_cell_y + dy
	
	if target_x < 0 or target_x >= meta_maze_size or target_y < 0 or target_y >= meta_maze_size:
		return false
	
	var current_pos = Vector2i(current_cell_x, current_cell_y)
	var target_pos = Vector2i(target_x, target_y)
	
	if meta_maze_connections.has(current_pos):
		return target_pos in meta_maze_connections[current_pos]
	return false

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

func add_border_openings(cell_rng: RandomNumberGenerator):
	## Aggiunge aperture nei muri di confine in base alle connessioni
	# Apertura a sinistra (ovest)
	if has_meta_connection(-1, 0):
		var opening_y = cell_rng.randi_range(1, maze_height - 1) * 2 + 1
		maze[opening_y][0] = MazeBuilder.CellType.PATH
	elif current_cell_x == 0 and has_meta_meta_connection(-1, 0):
		var opening_y = cell_rng.randi_range(1, maze_height - 1) * 2 + 1
		maze[opening_y][0] = MazeBuilder.CellType.PATH
	
	# Apertura a destra (est)
	if has_meta_connection(1, 0):
		var opening_y = cell_rng.randi_range(1, maze_height - 1) * 2 + 1
		maze[opening_y][maze_width * 2] = MazeBuilder.CellType.PATH
	elif current_cell_x == meta_maze_size - 1 and has_meta_meta_connection(1, 0):
		var opening_y = cell_rng.randi_range(1, maze_height - 1) * 2 + 1
		maze[opening_y][maze_width * 2] = MazeBuilder.CellType.PATH
	
	# Apertura in alto (nord)
	if has_meta_connection(0, -1):
		var opening_x = cell_rng.randi_range(1, maze_width - 1) * 2 + 1
		maze[0][opening_x] = MazeBuilder.CellType.PATH
	elif current_cell_y == 0 and has_meta_meta_connection(0, -1):
		var opening_x = cell_rng.randi_range(1, maze_width - 1) * 2 + 1
		maze[0][opening_x] = MazeBuilder.CellType.PATH
	
	# Apertura in basso (sud)
	if has_meta_connection(0, 1):
		var opening_x = cell_rng.randi_range(1, maze_width - 1) * 2 + 1
		maze[maze_height * 2][opening_x] = MazeBuilder.CellType.PATH
	elif current_cell_y == meta_maze_size - 1 and has_meta_meta_connection(0, 1):
		var opening_x = cell_rng.randi_range(1, maze_width - 1) * 2 + 1
		maze[maze_height * 2][opening_x] = MazeBuilder.CellType.PATH

func draw_maze():
	queue_redraw()

func _draw():
	if maze.is_empty():
		return
	
	# === PARTE 1: LABIRINTO CON ZOOM E PAN ===
	# Applica trasformazione solo al labirinto
	draw_set_transform(pan_offset, 0.0, Vector2(zoom_level, zoom_level))
	
	# Disegna il labirinto principale con le modifiche dello stato
	for y in range(maze.size()):
		for x in range(maze[y].size()):
			# Controlla se questo muro è stato rimosso dallo stato
			var is_removed = world_state.is_wall_removed(current_meta_cell_x, current_meta_cell_y, current_cell_x, current_cell_y, x, y)
			
			# Se il muro è rimosso, forza a essere un passaggio
			var cell_type = maze[y][x]
			if is_removed:
				cell_type = MazeBuilder.CellType.PATH
			
			# Colora diversamente le tile visitate dal robot
			var color: Color
			if cell_type == MazeBuilder.CellType.WALL:
				color = Color.BLACK
			else:
				# Verifica se la tile è stata visitata
				var is_visited = world_state.is_tile_visited(current_meta_cell_x, current_meta_cell_y, current_cell_x, current_cell_y, x, y)
				color = Color(0.6, 1.0, 0.6) if is_visited else Color.WHITE  # Verde chiaro vs bianco
			
			var rect = Rect2(x * cell_size, y * cell_size, cell_size, cell_size)
			draw_rect(rect, color)
	
	# Disegna gli oggetti piazzati in questa cella
	var objects = world_state.get_objects_in_cell(current_meta_cell_x, current_meta_cell_y, current_cell_x, current_cell_y)
	for obj in objects:
		if obj["type"] == "spawn_circle":
			var radius = obj["data"]["radius"]
			var obj_color = obj["data"]["color"]
			draw_circle(obj["position"], radius, obj_color)
		elif obj["type"] == "junction":
			# Disegna snodi con verde scuro
			var junction_rect = Rect2(obj["position"].x * cell_size, obj["position"].y * cell_size, cell_size, cell_size)
			draw_rect(junction_rect, Color(0.2, 0.6, 0.2))
	
	# Disegna il robot se si trova nella cella attualmente visualizzata
	if robot != null and current_meta_cell_x == robot.current_meta_x and current_meta_cell_y == robot.current_meta_y and current_cell_x == robot.current_cell_x and current_cell_y == robot.current_cell_y:
		draw_circle(robot.position, 8, Color.BLUE)
	
	# === PARTE 2: MINIMAPPA SENZA TRASFORMAZIONI ===
	# Reset trasformazione per disegnare la minimappa normalmente
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	
	# Disegna la minimappa
	var maze_width_pixels = (maze_width * 2 + 1) * cell_size
	minimap.draw_minimap(self, maze_width_pixels, current_meta_cell_x, current_meta_cell_y, current_cell_x, current_cell_y)

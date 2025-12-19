class_name FactionManager
extends RefCounted

var active_factions: Array[Faction] = []
var player_faction: Faction
var game_seed: int

func _init(_seed: int = 0):
	if _seed == 0:
		game_seed = Time.get_ticks_msec()
	else:
		game_seed = _seed
	
	_select_factions()

func _select_factions() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = game_seed
	
	# Get all available factions
	var all_factions = Faction.get_all_factions()
	
	# Shuffle and select 5 factions
	all_factions.shuffle()
	for i in range(5):
		active_factions.append(all_factions[i])
	
	# First faction is the player's faction
	player_faction = active_factions[0]
	player_faction.is_player = true

func assign_base_positions(maze_width: int, maze_height: int, occupied_cells: Dictionary) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = game_seed
	
	# Area ridotta: 8 celle (invece di 64x64)
	var clear_radius = 4
	
	for faction in active_factions:
		var position = _find_valid_base_position(maze_width, maze_height, occupied_cells, rng, clear_radius)
		faction.base_position = position
		
		# Mark area as occupied
		for x in range(-clear_radius, clear_radius):
			for y in range(-clear_radius, clear_radius):
				var cell = Vector2i(position.x + x, position.y + y)
				occupied_cells[cell] = true

func _find_valid_base_position(maze_width: int, maze_height: int, occupied_cells: Dictionary, rng: RandomNumberGenerator, clear_radius: int) -> Vector2i:
	var max_attempts = 100
	var attempt = 0
	
	while attempt < max_attempts:
		# Generate random position with margin from edges
		var x = rng.randi_range(clear_radius, maze_width - clear_radius)
		var y = rng.randi_range(clear_radius, maze_height - clear_radius)
		var pos = Vector2i(x, y)
		
		# Check if area around this position is free (sample check, not every cell)
		var is_valid = true
		# Check only corners and center to speed up
		var check_points = [
			Vector2i(0, 0),
			Vector2i(-clear_radius, -clear_radius),
			Vector2i(clear_radius, -clear_radius),
			Vector2i(-clear_radius, clear_radius),
			Vector2i(clear_radius, clear_radius)
		]
		
		for offset in check_points:
			var check_cell = pos + offset
			if occupied_cells.has(check_cell):
				is_valid = false
				break
		
		if is_valid:
			return pos
		
		attempt += 1
	
	# Fallback: return a position even if not ideal
	return Vector2i(rng.randi_range(clear_radius, maze_width - clear_radius), rng.randi_range(clear_radius, maze_height - clear_radius))

func get_player_faction() -> Faction:
	return player_faction

func get_other_factions() -> Array[Faction]:
	var others: Array[Faction] = []
	for faction in active_factions:
		if not faction.is_player:
			others.append(faction)
	return others

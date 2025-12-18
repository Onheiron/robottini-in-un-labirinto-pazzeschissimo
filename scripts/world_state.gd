class_name WorldState
extends RefCounted

## Gestisce lo stato del mondo e le modifiche al labirinto procedurale

# Struttura: {Vector3i(meta_x, meta_y, cell_id): {Vector2i(x, y): true}}
# Traccia i muri rimossi per ogni cella
var removed_walls: Dictionary = {}

# Struttura: {Vector3i(meta_x, meta_y, cell_id): [{position: Vector2, type: String, data: Dictionary}]}
# Traccia gli oggetti piazzati in ogni cella
var placed_objects: Dictionary = {}

func get_cell_key(meta_x: int, meta_y: int, cell_x: int, cell_y: int) -> Vector3i:
	## Crea una chiave univoca per una cella
	return Vector3i(meta_x, meta_y, cell_x * 10 + cell_y)

func remove_wall(meta_x: int, meta_y: int, cell_x: int, cell_y: int, wall_x: int, wall_y: int):
	## Rimuove un muro in una posizione specifica
	var cell_key = get_cell_key(meta_x, meta_y, cell_x, cell_y)
	
	if not removed_walls.has(cell_key):
		removed_walls[cell_key] = {}
	
	removed_walls[cell_key][Vector2i(wall_x, wall_y)] = true

func is_wall_removed(meta_x: int, meta_y: int, cell_x: int, cell_y: int, wall_x: int, wall_y: int) -> bool:
	## Verifica se un muro è stato rimosso
	var cell_key = get_cell_key(meta_x, meta_y, cell_x, cell_y)
	
	if not removed_walls.has(cell_key):
		return false
	
	return removed_walls[cell_key].has(Vector2i(wall_x, wall_y))

func place_object(meta_x: int, meta_y: int, cell_x: int, cell_y: int, position: Vector2, object_type: String, object_data: Dictionary = {}):
	## Piazza un oggetto in una posizione specifica
	var cell_key = get_cell_key(meta_x, meta_y, cell_x, cell_y)
	
	if not placed_objects.has(cell_key):
		placed_objects[cell_key] = []
	
	placed_objects[cell_key].append({
		"position": position,
		"type": object_type,
		"data": object_data
	})

func get_objects_in_cell(meta_x: int, meta_y: int, cell_x: int, cell_y: int) -> Array:
	## Ottiene tutti gli oggetti in una cella
	var cell_key = get_cell_key(meta_x, meta_y, cell_x, cell_y)
	
	if not placed_objects.has(cell_key):
		return []
	
	return placed_objects[cell_key]

func clear_area(meta_x: int, meta_y: int, cell_x: int, cell_y: int, center: Vector2, size: Vector2):
	## Rimuove tutti i muri in un'area rettangolare
	var half_size = size / 2
	var start = center - half_size
	var end = center + half_size
	
	for y in range(int(start.y), int(end.y) + 1):
		for x in range(int(start.x), int(end.x) + 1):
			remove_wall(meta_x, meta_y, cell_x, cell_y, x, y)

func to_dict() -> Dictionary:
	## Serializza lo stato per il salvataggio
	return {
		"removed_walls": removed_walls,
		"placed_objects": placed_objects
	}

func from_dict(data: Dictionary):
	## Deserializza lo stato da un salvataggio
	removed_walls = data.get("removed_walls", {})
	placed_objects = data.get("placed_objects", {})

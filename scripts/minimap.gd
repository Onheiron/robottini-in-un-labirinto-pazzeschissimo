class_name Minimap
extends Node

## Gestisce la visualizzazione della minimappa

var visited_cells: Dictionary = {}
var cell_size: int = 6
var padding: int = 20
var wall_thickness: int = 3
var meta_maze_size: int = 10

func record_cell(meta_x: int, meta_y: int, cell_x: int, cell_y: int, openings: Dictionary):
	## Registra una cella visitata con le sue aperture
	var cell_key = Vector3i(meta_x, meta_y, cell_x * 10 + cell_y)
	
	if not visited_cells.has(cell_key):
		visited_cells[cell_key] = openings.duplicate()

func draw_minimap(canvas: Node2D, maze_width_pixels: int, current_meta_x: int, current_meta_y: int, current_x: int, current_y: int):
	## Disegna la minimappa completa
	var minimap_x = maze_width_pixels + padding
	var minimap_y = padding
	var total_size = meta_maze_size * meta_maze_size * cell_size
	var section_size = meta_maze_size * cell_size
	
	# Sfondo della minimappa
	canvas.draw_rect(Rect2(minimap_x - 2, minimap_y - 2, total_size + 4, total_size + 4), Color.BLACK)
	
	# Disegna tutte le celle padre (10x10)
	for meta_y in range(meta_maze_size):
		for meta_x in range(meta_maze_size):
			var base_x = minimap_x + meta_x * section_size
			var base_y = minimap_y + meta_y * section_size
			
			# Disegna tutte le celle figlio (10x10) di questa cella padre
			for cell_y in range(meta_maze_size):
				for cell_x in range(meta_maze_size):
					var cell_key = Vector3i(meta_x, meta_y, cell_x * 10 + cell_y)
					var pos_x = base_x + cell_x * cell_size
					var pos_y = base_y + cell_y * cell_size
					
					if visited_cells.has(cell_key):
						_draw_cell(canvas, pos_x, pos_y, visited_cells[cell_key])
					else:
						canvas.draw_rect(Rect2(pos_x, pos_y, cell_size, cell_size), Color.DARK_GRAY)
					
					# Evidenzia la cella corrente
					if meta_x == current_meta_x and meta_y == current_meta_y and cell_x == current_x and cell_y == current_y:
						canvas.draw_rect(Rect2(pos_x, pos_y, cell_size, cell_size), Color.YELLOW, false, 2)
			
			# Evidenzia il bordo della cella padre corrente
			if meta_x == current_meta_x and meta_y == current_meta_y:
				canvas.draw_rect(Rect2(base_x, base_y, section_size, section_size), Color.GREEN, false, 2)

func _draw_cell(canvas: Node2D, x: int, y: int, openings: Dictionary):
	## Disegna una singola cella con le sue aperture
	canvas.draw_rect(Rect2(x, y, cell_size, cell_size), Color.WHITE)
	
	# Disegna i muri tranne dove ci sono aperture
	if not openings["north"]:
		canvas.draw_line(Vector2(x, y), Vector2(x + cell_size, y), Color.BLACK, wall_thickness)
	
	if not openings["south"]:
		canvas.draw_line(Vector2(x, y + cell_size), Vector2(x + cell_size, y + cell_size), Color.BLACK, wall_thickness)
	
	if not openings["west"]:
		canvas.draw_line(Vector2(x, y), Vector2(x, y + cell_size), Color.BLACK, wall_thickness)
	
	if not openings["east"]:
		canvas.draw_line(Vector2(x + cell_size, y), Vector2(x + cell_size, y + cell_size), Color.BLACK, wall_thickness)

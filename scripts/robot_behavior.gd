class_name RobotBehavior
extends RefCounted

## Classe base per i comportamenti di esplorazione del robot

var robot_ref: Robot

func _init(robot: Robot):
	robot_ref = robot

func update(_delta: float, _maze: Array, _world_state) -> bool:
	## Aggiorna il comportamento. Ritorna true se il robot si è mosso
	return false

func on_arrival(_grid_pos: Vector2i, _maze: Array, _world_state):
	## Chiamato quando il robot arriva in una nuova posizione
	pass

func get_behavior_name() -> String:
	## Nome del comportamento
	return "Base"

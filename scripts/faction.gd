class_name Faction
extends RefCounted

var id: String
var color: Color
var base_position: Vector2i
var is_player: bool = false

func _init(_id: String, _color: Color):
	id = _id
	color = _color

static func get_all_factions() -> Array[Faction]:
	var factions: Array[Faction] = []
	
	# 12 possible factions with RGB colors
	factions.append(Faction.new("fa0", Color(1.0, 0.667, 0.0)))   # #ffaa00
	factions.append(Faction.new("f0a", Color(1.0, 0.0, 0.667)))   # #ff00aa
	factions.append(Faction.new("af0", Color(0.667, 1.0, 0.0)))   # #aaff00
	factions.append(Faction.new("0fa", Color(0.0, 1.0, 0.667)))   # #00ffaa
	factions.append(Faction.new("a0f", Color(0.667, 0.0, 1.0)))   # #aa00ff
	factions.append(Faction.new("0af", Color(0.0, 0.667, 1.0)))   # #00aaff
	factions.append(Faction.new("f00", Color(1.0, 0.0, 0.0)))     # #ff0000
	factions.append(Faction.new("0f0", Color(0.0, 1.0, 0.0)))     # #00ff00
	factions.append(Faction.new("00f", Color(0.0, 0.0, 1.0)))     # #0000ff
	factions.append(Faction.new("f0f", Color(1.0, 0.0, 1.0)))     # #ff00ff
	factions.append(Faction.new("0ff", Color(0.0, 1.0, 1.0)))     # #00ffff
	factions.append(Faction.new("ff0", Color(1.0, 1.0, 0.0)))     # #ffff00
	
	return factions

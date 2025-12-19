class_name Biome
extends RefCounted

var id: String
var color: Color
var origin: Vector2i  # Punto di origine del bioma nella matrice 100x100

func _init(_id: String, _color: Color):
	id = _id
	color = _color

static func get_all_biomes() -> Array[Biome]:
	var biomes: Array[Biome] = []
	
	# 12 possible biomes with RGB colors (same as factions)
	biomes.append(Biome.new("fa0", Color(1.0, 0.667, 0.0)))   # #ffaa00
	biomes.append(Biome.new("f0a", Color(1.0, 0.0, 0.667)))   # #ff00aa
	biomes.append(Biome.new("af0", Color(0.667, 1.0, 0.0)))   # #aaff00
	biomes.append(Biome.new("0fa", Color(0.0, 1.0, 0.667)))   # #00ffaa
	biomes.append(Biome.new("a0f", Color(0.667, 0.0, 1.0)))   # #aa00ff
	biomes.append(Biome.new("0af", Color(0.0, 0.667, 1.0)))   # #00aaff
	biomes.append(Biome.new("f00", Color(1.0, 0.0, 0.0)))     # #ff0000
	biomes.append(Biome.new("0f0", Color(0.0, 1.0, 0.0)))     # #00ff00
	biomes.append(Biome.new("00f", Color(0.0, 0.0, 1.0)))     # #0000ff
	biomes.append(Biome.new("f0f", Color(1.0, 0.0, 1.0)))     # #ff00ff
	biomes.append(Biome.new("0ff", Color(0.0, 1.0, 1.0)))     # #00ffff
	biomes.append(Biome.new("ff0", Color(1.0, 1.0, 0.0)))     # #ffff00
	
	return biomes

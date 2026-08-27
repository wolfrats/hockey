class_name Stats extends Node
var Classes = []

enum ClassTypes {
	LIGHT,
	MEDIUM,
	HEAVY
}

class StatBlock extends Node:
	var weight: float
	var speed: float
	var sprite_index: int
	
func _init() -> void:
	for X in ClassTypes.values():
		Classes.push_back(StatBlock.new())
	Classes[ClassTypes.LIGHT].weight = 1
	Classes[ClassTypes.LIGHT].speed = 7
	Classes[ClassTypes.LIGHT].sprite_index = 60
	Classes[ClassTypes.MEDIUM].weight = 1.5
	Classes[ClassTypes.MEDIUM].speed = 5
	Classes[ClassTypes.MEDIUM].sprite_index = 0
	Classes[ClassTypes.HEAVY].weight = 2
	Classes[ClassTypes.HEAVY].speed = 3
	Classes[ClassTypes.HEAVY].sprite_index = 32

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
	var shot_power: float
	var shot_variance: float
	
func _init() -> void:
	for X in ClassTypes.values():
		Classes.push_back(StatBlock.new())
	Classes[ClassTypes.LIGHT].weight = 1
	Classes[ClassTypes.LIGHT].speed = 5
	Classes[ClassTypes.LIGHT].sprite_index = 60
	Classes[ClassTypes.LIGHT].shot_power = 1.3
	Classes[ClassTypes.LIGHT].shot_variance = deg_to_rad(5)
	
	Classes[ClassTypes.MEDIUM].weight = 1.5
	Classes[ClassTypes.MEDIUM].speed = 5.5
	Classes[ClassTypes.MEDIUM].sprite_index = 0
	Classes[ClassTypes.MEDIUM].shot_power = 1
	Classes[ClassTypes.MEDIUM].shot_variance = deg_to_rad(10)
	
	Classes[ClassTypes.HEAVY].weight = 2
	Classes[ClassTypes.HEAVY].speed = 6
	Classes[ClassTypes.HEAVY].sprite_index = 32
	Classes[ClassTypes.HEAVY].shot_power = 1.3
	Classes[ClassTypes.HEAVY].shot_variance = deg_to_rad(30)

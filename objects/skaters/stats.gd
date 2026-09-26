class_name Stats extends Node
var Classes = []

enum ClassTypes {
	LIGHT,
	MEDIUM,
	HEAVY
}

class StatBlock extends Node:
	var weight: float          # mass of skater
	var speed: float           # impulse applied when skating
	var sprite_index: int      # y coordinate of sprite
	var shot_power: float      # maximum shot velocity
	var snap_power: float      # shot velocity with 0 charge
	var shot_variance: float   # cone of inaccuracy
	var check_damage: float
	var max_health: float
	
func _init() -> void:
	for X in ClassTypes.values():
		Classes.push_back(StatBlock.new())
	Classes[ClassTypes.LIGHT].weight = 1
	Classes[ClassTypes.LIGHT].speed = 5
	Classes[ClassTypes.LIGHT].sprite_index = 60
	Classes[ClassTypes.LIGHT].shot_power = 1.3
	Classes[ClassTypes.LIGHT].snap_power = 0.4
	Classes[ClassTypes.LIGHT].shot_variance = deg_to_rad(5)
	Classes[ClassTypes.LIGHT].check_damage = 20.0
	Classes[ClassTypes.LIGHT].max_health = 80.0
	
	Classes[ClassTypes.MEDIUM].weight = 1.5
	Classes[ClassTypes.MEDIUM].speed = 5.5
	Classes[ClassTypes.MEDIUM].sprite_index = 0
	Classes[ClassTypes.MEDIUM].shot_power = 1
	Classes[ClassTypes.MEDIUM].snap_power = 0.3
	Classes[ClassTypes.MEDIUM].shot_variance = deg_to_rad(10)
	Classes[ClassTypes.MEDIUM].check_damage = 30.0
	Classes[ClassTypes.MEDIUM].max_health = 100.0
	
	Classes[ClassTypes.HEAVY].weight = 2
	Classes[ClassTypes.HEAVY].speed = 6
	Classes[ClassTypes.HEAVY].sprite_index = 26
	Classes[ClassTypes.HEAVY].shot_power = 1.3
	Classes[ClassTypes.HEAVY].snap_power = 0.2
	Classes[ClassTypes.HEAVY].shot_variance = deg_to_rad(30)
	Classes[ClassTypes.HEAVY].check_damage = 45.0
	Classes[ClassTypes.HEAVY].max_health = 130.0


const TEAMS = [
	{
		"name": "Wide Street Wackos",
		"composition": [
			ClassTypes.HEAVY,
			ClassTypes.HEAVY,
			ClassTypes.HEAVY,
			ClassTypes.LIGHT,
			ClassTypes.LIGHT
		],
		"head_color": Color(0, 0, 0),
		"body_color": Color(0.957, 0.363, 0.116, 1.0),
		"foot_color": Color(0.874, 0.874, 0.874, 1.0),
		"away_head_color": Color(0.923, 0.477, 0.139, 1.0),
		"away_body_color": Color(0, 0, 0),
		"away_foot_color": Color(0.965, 0.502, 0.142, 1.0),
	},
	{
		"name": "Blue Feathers",
		"composition": [
			ClassTypes.HEAVY,
			ClassTypes.MEDIUM,
			ClassTypes.MEDIUM,
			ClassTypes.LIGHT,
			ClassTypes.LIGHT
		],
		"head_color": Color(0.3, 0.4, 1),
		"body_color": Color(0.2, 0.2, 0.5),
		"foot_color": Color(0.5, 0.5, 1),
		"away_head_color": Color(0.3, 0.4, 1),
		"away_body_color": Color(0.9, 0.9, 0.9),
		"away_foot_color": Color(0.5, 0.5, 1),
	},
	{
		"name": "Flightless Birds",
		"composition": [
			ClassTypes.HEAVY,
			ClassTypes.MEDIUM,
			ClassTypes.MEDIUM,
			ClassTypes.MEDIUM,
			ClassTypes.LIGHT
		],
		"head_color": Color(0.8, 0.675, 0.221, 1.0),
		"body_color": Color(0.8, 0.8, 0.8),
		"foot_color": Color(0.2, 0.2, 0.2),
		"away_head_color": Color(0.8, 0.613, 0.125, 1.0),
		"away_body_color": Color(0.9, 0.9, 0.9),
		"away_foot_color": Color(0.2, 0.2, 0.2),
	},
	{
		"name": "Candy Canes",
		"composition": [
			ClassTypes.MEDIUM,
			ClassTypes.MEDIUM,
			ClassTypes.LIGHT,
			ClassTypes.LIGHT,
			ClassTypes.LIGHT
		],
		"head_color": Color(1, 0.2, 0.2),
		"body_color": Color(1, 1, 1),
		"foot_color": Color(1, 0.2, 0.2),
		"away_head_color": Color(1, 1, 1),
		"away_body_color": Color(1, 0.2, 0.2),
		"away_foot_color": Color(1, 1, 1),
	},
	{
		"name": "The Pinkertons",
		"composition": [
			ClassTypes.MEDIUM,
			ClassTypes.HEAVY,
			ClassTypes.HEAVY,
			ClassTypes.HEAVY,
			ClassTypes.LIGHT
		],
		"head_color": Color(1, 0.5, 0.6),
		"body_color": Color(1, 0.6, 1),
		"foot_color": Color(1, 0.5, 0.6),
		"away_head_color": Color(1, 0.5, 0.6),
		"away_body_color": Color(0.9, 0, 0.9),
		"away_foot_color": Color(1, 0.5, 0.6),
	}
]

extends Node2D

var home_score: int = 0
var away_score: int = 0

func _ready() -> void:
	pass

func goal_scored(goal_name: String) -> void:
	if goal_name == "HomeGoal":
		away_score += 1
	elif goal_name == "AwayGoal":
		home_score += 1

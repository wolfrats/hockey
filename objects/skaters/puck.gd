class_name Puck extends Node2D
@export var posessor: Skater

func _ready() -> void:
	pass # Replace with function body.

func _process(_delta: float) -> void:
	if posessor:
		($Body).freeze = true
		($Body/CollisionShape2D).disabled = ($Body).freeze 
		self.global_position = posessor.get_node("Body").global_position
	else:
		($Body).freeze = false
		($Body/CollisionShape2D).disabled = ($Body).freeze 

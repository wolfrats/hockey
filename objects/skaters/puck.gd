class_name Puck extends RigidBody2D
@export var posessor: Skater
var blocklist: Dictionary[String, int] = {}
var colidable: bool = true

func _process(_delta: float) -> void:
	if posessor:
		freeze = true
		($CollisionShape2D).disabled = freeze 
		self.global_position = posessor.global_position
	else:
		freeze = false
		($CollisionShape2D).disabled = freeze 

func _physics_process(_delta: float) -> void:
	for body in get_colliding_bodies():
		if body is Skater and (not blocklist.has(body.name) or blocklist[body.name] == 0) and colidable:
			posessor = body

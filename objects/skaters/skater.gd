class_name Skater
extends RigidBody2D
var counter = 0
@export var ghost: Ghost
@export var home_team: bool
@export var stats: Stats.ClassTypes
var statbook: Stats.StatBlock
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	statbook = StatBook.Classes[stats]
	mass = statbook.weight
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
	
func _physics_process(delta: float) -> void:
	if ghost:
		ghost.handle(delta, self)
	#counter += 1
	var speed = linear_velocity.length()
	$Sprite.flip_h = (linear_velocity.x > 0)
	var base_offset = 0
	if (linear_velocity.abs().x < linear_velocity.abs().y):
		base_offset = 4
		if (linear_velocity.y < 0):
			base_offset = 11
	if speed > 5 or speed == 0:
		linear_damp = 0.9
	#if speed > 100:
	base_offset += int(counter / 10.0) % 3
	#else:
	#	($Body).linear_damp = 100
	$Sprite.region_rect = Rect2(base_offset * 24 + 4, statbook.sprite_index, 24, 24)

func impulse(dx: float, dy: float) -> void:
	apply_impulse(Vector2(dx, dy) * statbook.speed)

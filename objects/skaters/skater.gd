class_name Skater
extends Node2D
var counter = 0
@export var ghost: Ghost
@export var home_team: bool

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
	
func _physics_process(delta: float) -> void:
	if ghost:
		ghost.handle(delta, self)
	#counter += 1
	var speed = ($Body).linear_velocity.length()
	$Body/Sprite.flip_h = ($Body.linear_velocity.x > 0)
	var base_offset = 0
	if ($Body.linear_velocity.abs().x < $Body.linear_velocity.abs().y):
		base_offset = 4
		if ($Body.linear_velocity.y < 0):
			base_offset = 11
	if speed > 5 or speed == 0:
		($Body).linear_damp = 0.9
	#if speed > 100:
	base_offset += int(counter / 10.0) % 3
	#else:
	#	($Body).linear_damp = 100
	$Body/Sprite.region_rect = Rect2(base_offset * 24 + 4, 0, 24, 24)

func impulse(dx: float, dy: float) -> void:
	($Body).apply_impulse(Vector2(dx, dy))

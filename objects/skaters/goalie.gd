class_name Goalie
extends RigidBody2D
var counter = 0
const OFFSET: int = 32
@export var ghost: Ghost
@export var home_team: bool
@export var stats: Stats.ClassTypes
@export var max_y: float = 650
@export var min_y: float = 400
var statbook: Stats.StatBlock
var rammed: bool = false
var charging: bool = false
var knocked_over: int = 0
var home_x: float
var needs_reset: bool = false

func home() -> void:
	needs_reset = true

func _ready() -> void:
	# add_to_group("skaters")
	home_x = global_position.x
	$Sprite.texture = $Sprite.texture.duplicate()
	#$Sprite.texture.atlas = $Sprite.texture.atlas.duplicate()
	if home_team:
		$Sprite.texture.atlas = Globals.swap_color_in_texture($Sprite.texture.atlas, Color.from_rgba8(96, 176, 248), Globals.home_color.darkened(0.2))
	else:
		$Sprite.texture.atlas = Globals.swap_color_in_texture($Sprite.texture.atlas, Color.from_rgba8(96, 176, 248), Globals.away_color.darkened(0.2))
	$Sprite.flip_h = home_team

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
	
func _physics_process(delta: float) -> void:
	if ghost:
		ghost.handle(delta, self)
		return
	var diffx = global_position.x - home_x
	if abs(diffx) > 4:
		apply_impulse(Vector2.LEFT * diffx)
	var puck = Globals.get_closest_node(global_position, "pucks")
	if puck:
		var diffy = global_position.y - clamp(puck.global_position.y + OFFSET, min_y, max_y)
		if abs(diffy) > 4:
			apply_impulse(Vector2.UP * diffy)
	#counter += 1

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if needs_reset:
		var trans = state.get_transform()
		trans.origin = Vector2(home_x, (min_y + max_y) / 2.0)
		state.set_transform(trans)
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0
		needs_reset = false
		return

	for i in range(state.get_contact_count()):
		 # Get the impulse vector for this specific contact point 
		#var myimpulse: Vector2 = state.get_contact_impulse(i)
		var myimpulse: Vector2 = state.get_contact_local_velocity_at_position(i)
		var collider = state.get_contact_collider_object(i)
		if "mass" in collider:
			myimpulse *= 1 + (collider.mass - mass)
		var impulse_strength: float = myimpulse.length()
		if impulse_strength > 150.0:
		 	# drop the puck
			rammed = true

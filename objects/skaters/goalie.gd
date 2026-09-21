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
var pulled: bool = false
var extra_attacker: Skater = null

func home() -> void:
	needs_reset = true

func pull() -> void:
	if pulled: return
	pulled = true

	# Create an extra skater
	var skater_scene = load("res://objects/skaters/skater.tscn")
	extra_attacker = skater_scene.instantiate()
	extra_attacker.home_team = home_team
	extra_attacker.global_position = global_position
	extra_attacker.stats = stats
	extra_attacker.owner = get_tree().current_scene 
	# Add the extra attacker to the correct team node
	var manager = get_parent()
	if home_team:
		var team1 = manager.get_node_or_null("Team1")
		if team1:
			team1.call_deferred("add_child", extra_attacker)
	else:
		var team2 = manager.get_node_or_null("Team2")
		if team2:
			team2.call_deferred("add_child", extra_attacker)

	# Transfer control if human player is controlling the goalie
	if ghost:
		var temp_ghost = ghost
		ghost.skater = null
		ghost = null
		temp_ghost.skater = extra_attacker
		extra_attacker.ghost = temp_ghost

	# Disable goalie visually and physically
	visible = false
	set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	set_deferred("freeze", true)

func return_to_net() -> void:
	if not pulled: return
	pulled = false

	# Enable goalie visually and physically
	visible = true
	set_deferred("process_mode", Node.PROCESS_MODE_INHERIT)
	set_deferred("freeze", false)
	needs_reset = true

	if extra_attacker:
		# If human is controlling the extra attacker, return control to goalie
		if extra_attacker.ghost:
			var temp_ghost = extra_attacker.ghost
			extra_attacker.ghost.skater = null
			extra_attacker.ghost = null
			temp_ghost.skater = self
			ghost = temp_ghost
		extra_attacker.remove_from_group("skaters")
		extra_attacker.queue_free()
		extra_attacker = null

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
	else:
		var diffx = clamp(global_position.x - home_x, -16, 16)
		if abs(diffx) > 4:
			apply_impulse(Vector2.LEFT * diffx)
		var puck_node = Globals.get_closest_node(global_position, "pucks")
		if puck_node:
			var diffy = global_position.y - clamp(puck_node.global_position.y + OFFSET, min_y, max_y)
			if abs(diffy) > 4:
				apply_impulse(Vector2.UP * diffy)
	#counter += 1

func impulse(dx: float, dy: float) -> void:
	# Ensure Goalies can be pushed freely by ghosts, without being forced to clamp back to net
	var impulse_vec = Vector2(dx, dy) * 20.0

	if impulse_vec.length() > 0:
		counter += 1
	apply_impulse(impulse_vec)

func do_check() -> void:
	pass

func do_grab() -> void:
	pass

var puck = null

func shoot(dir: Vector2, power: float, inaccuracy_modifier: float = 1) -> void:
	if puck:
		var vec = dir.normalized() * 200 * (statbook.snap_power + ((1 - statbook.snap_power) * power)) * statbook.shot_power
		var vec2 = vec.rotated(inaccuracy_modifier * statbook.shot_variance * (1 - (2*randf())))
		puck.shoot(name, vec2)

		var camera = get_viewport().get_camera_2d()
		if camera:
			var shake_amount = 2.0 + (power * 8.0)
			var shake_tween = create_tween()
			shake_tween.tween_property(camera, "offset", Vector2(randf_range(-shake_amount, shake_amount), randf_range(-shake_amount, shake_amount)), 0.05)
			shake_tween.tween_property(camera, "offset", Vector2(randf_range(-shake_amount/2.0, shake_amount/2.0), randf_range(-shake_amount/2.0, shake_amount/2.0)), 0.05)
			shake_tween.tween_property(camera, "offset", Vector2.ZERO, 0.05)

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

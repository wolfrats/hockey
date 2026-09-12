class_name Skater
extends RigidBody2D
var counter = 0
@export var ghost: Ghost
var ai: Ghost
@export var home_team: bool
@export var stats: Stats.ClassTypes
var statbook: Stats.StatBlock
var rammed: bool = false
var charging: bool = false
var knocked_over: int = 0
var checking: int = 0
var holding: int = 0
var puck: Puck = null
var skate_dir: Vector2 = Vector2.ONE
var last_move: Vector2 = Vector2.ONE
var scrape_counter: int = 0
var initial_position: Vector2
var needs_reset: bool = false
var anim_state: String = ""
var health: float
var spring: DampedSpringJoint2D
var penalty_time: float = 0.0
var needs_penalty_reset: bool = false

enum LookDir {
	SIDE,
	DOWN,
	UP
}

func _ready() -> void:
	initial_position = global_position
	add_to_group("skaters")
	statbook = StatBook.Classes[stats]
	mass = statbook.weight
	health = statbook.max_health
	spring = $Spring #DampedSpringJoint2D.new()
	#add_child(spring)
	spring.node_a = get_path()
	$Sprite.texture = $Sprite.texture.duplicate()
	if home_team:
		$Sprite.texture.atlas = Globals.home_texture
	else:
		$Sprite.texture.atlas = Globals.away_texture
	if not %Manager.is_practice:
		ai = preload("res://objects/skaters/ai.tscn").instantiate()
		add_child(ai)

func home() -> void:
	needs_reset = true
	self.puck = null

func penalty(duration: float) -> void:
	penalty_time = duration
	needs_penalty_reset = true
	checking = 0
	charging = false
	if puck:
		puck.shoot(name, Vector2.ZERO)
	if not spring.node_b.is_empty():
		spring.node_b = NodePath("")

func _process(_delta: float) -> void:
	pass
	
func do_check() -> void:
	if penalty_time > 0:
		return
	if checking <= Globals.ticks and knocked_over <= Globals.ticks:
		checking = Globals.ticks + 30
		var skaters = get_tree().get_nodes_in_group("skaters")
		for s in skaters:
			if s != self and global_position.distance_to(s.global_position) < 80:
				s.take_damage(statbook.check_damage * randf_range(0.8, 1.2))
				s.spring.node_b = NodePath("")

		var referees = get_tree().get_nodes_in_group("referees")
		for ref in referees:
			if ref.has_method("is_in_cone") and ref.is_in_cone(global_position):
				if randf() < 0.3: # 30% chance to be sent to penalty box
					penalty(30.0)

func do_grab() -> void:
	if penalty_time > 0:
		return
	if checking <= Globals.ticks and knocked_over <= Globals.ticks:
		checking = Globals.ticks + 30
		var skaters = get_tree().get_nodes_in_group("skaters")
		for s in skaters:
			if s != self and global_position.distance_to(s.global_position) < 80:
				spring.node_b = s.get_path()
				holding = Globals.ticks + 120


func take_damage(damage: float) -> void:
	if knocked_over > Globals.ticks:
		return
	health -= damage
	if health <= 0:
		knocked_over = Globals.ticks + 120
		checking = 0
		charging = false
		if puck:
			puck.shoot(name, Vector2.ZERO)

func _physics_process(delta: float) -> void:
	if penalty_time > 0:
		penalty_time -= delta
		if penalty_time <= 0:
			needs_reset = true
		return

	if knocked_over <= Globals.ticks and health < statbook.max_health:
		health = min(statbook.max_health, health + delta * 15.0) # Regenerate 15 hp per second
	if anim_state == "skating_around":
		if randf() < 0.05:
			impulse(randf_range(-1, 1), randf_range(-1, 1))
		var diff = initial_position - global_position
		if diff.length() > 500:
			impulse(diff.normalized().x, diff.normalized().y)
	elif anim_state == "skating_out":
		var target_y = -200
		var diffy = target_y - global_position.y
		if abs(diffy) > 10:
			impulse(0, sign(diffy))
		if randf() < 0.1:
			impulse(randf_range(-0.5, 0.5), 0)
	elif ghost:
		ghost.handle(delta, self)
	elif ai:
		ai.handle(delta, self)
	var speed = linear_velocity.length()
	var look_dir: LookDir = LookDir.SIDE
	if not spring.node_b.is_empty() and holding <= Globals.ticks:
		spring.node_b = NodePath("")

	if knocked_over <= Globals.ticks and checking <= Globals.ticks:
		$Sprite.flip_h = (linear_velocity.x > 0)
	var base_offset = 1
	if (linear_velocity.abs().x < linear_velocity.abs().y):
		base_offset = 8
		look_dir = LookDir.DOWN
		if (linear_velocity.y < 0):
			base_offset = 15
			look_dir = LookDir.UP

	if not spring.node_b.is_empty():
		var held = get_node_or_null(spring.node_b)
		if held:
			var diff = held.global_position - global_position
			$Sprite.flip_h = (diff.x > 0)
			if abs(diff.x) < abs(diff.y):
				base_offset = 8
				look_dir = LookDir.DOWN
				if diff.y < 0:
					base_offset = 17
					look_dir = LookDir.UP
			else:
				base_offset = 0
				look_dir = LookDir.SIDE
	if speed > 5 or speed == 0:
		linear_damp = 0.9
	base_offset += int(counter / 10.0) % 6
	if rammed:
		rammed = false
		if puck:
			puck.shoot(name, Vector2.ZERO)
	if charging:
		base_offset = 26
	if checking > Globals.ticks:
		base_offset = 21
		if look_dir == LookDir.UP:
			base_offset = 23
		elif look_dir == LookDir.DOWN:
			base_offset = 22
	if knocked_over > Globals.ticks:
		base_offset = 0
	var spacing = 192
	$Sprite.region_rect = Rect2(base_offset * spacing + 0, 0, 192, 192) #statbook.sprite_index
	if abs(last_move.angle_to(linear_velocity)) > 3.1 and Globals.ticks > scrape_counter:
		var s: Icesputter = preload("res://objects/environment/icesplutter.tscn").instantiate()
		%Manager.add_child(s)
		skate_dir = linear_velocity
		scrape_counter = Globals.ticks + 20
		if linear_velocity.x > 0:
			var m: ParticleProcessMaterial = s.process_material
			m.direction.x = -m.direction.x
		s.global_position = (global_position + Vector2.DOWN * 16)
	skate_dir = skate_dir.lerp(self.linear_velocity, 0.03)

func impulse(dx: float, dy: float) -> void:
	if knocked_over > Globals.ticks or checking > Globals.ticks or penalty_time > 0:
		return
	last_move = Vector2(dx, dy)
	apply_impulse(last_move * statbook.speed)

func shoot(dir: Vector2, power: float) -> void:
	if knocked_over > Globals.ticks or checking > Globals.ticks or penalty_time > 0:
		return
	var vec = dir.normalized() * 200 * (statbook.snap_power + ((1 - statbook.snap_power) * power)) * statbook.shot_power
	var vec2 = vec.rotated(statbook.shot_variance * (1 - (2*randf())))
	if puck:
		puck.shoot(name, vec2)

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if anim_state == "lerping" and penalty_time <= 0:
		var trans = state.get_transform()
		trans.origin = trans.origin.lerp(initial_position, 0.05)
		state.set_transform(trans)
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0
		return

	if needs_reset:
		var trans = state.get_transform()
		trans.origin = initial_position
		state.set_transform(trans)
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0
		needs_reset = false
		return

	if needs_penalty_reset:
		var trans = state.get_transform()
		trans.origin = Vector2(1000, 100) # Penalty box position
		state.set_transform(trans)
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0
		needs_penalty_reset = false
		return

	if penalty_time > 0:
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0
		return

	for i in range(state.get_contact_count()):
		var myimpulse: Vector2 = state.get_contact_local_velocity_at_position(i)
		var collider = state.get_contact_collider_object(i)
		if collider is Goalie:
			# Bounce away from goalie
			var bounce_dir = (global_position - collider.global_position).normalized()
			state.linear_velocity = bounce_dir * 300.0
			continue

		if "mass" in collider:
			myimpulse *= 1 + (collider.mass - mass)
		var impulse_strength: float = myimpulse.length()
		if impulse_strength > 150.0:
			rammed = true
			if "statbook" in collider and collider.statbook:
				take_damage(collider.statbook.check_damage * randf_range(0.8, 1.2) * 0.5) # Take half check damage when rammed hard by someone
			else:
				take_damage(10)

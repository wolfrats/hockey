class_name Skater
extends RigidBody2D
var counter = 0
@export var ghost: Ghost
@export var home_team: bool
@export var stats: Stats.ClassTypes
var statbook: Stats.StatBlock
var rammed: bool = false
var charging: bool = false
var knocked_over: int = 0
var puck: Puck = null
var skate_dir: Vector2 = Vector2.ONE
var last_move: Vector2 = Vector2.ONE
var scrape_counter: int = 0
var initial_position: Vector2
var needs_reset: bool = false

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
	$Sprite.texture = $Sprite.texture.duplicate()
	if home_team:
		$Sprite.texture.atlas = Globals.home_texture
	else:
		$Sprite.texture.atlas = Globals.away_texture

func home() -> void:
	needs_reset = true
	self.puck = null

func _process(_delta: float) -> void:
	pass
	
func _physics_process(delta: float) -> void:
	if ghost:
		ghost.handle(delta, self)
	var speed = linear_velocity.length()
	var look_dir: LookDir = LookDir.SIDE
	$Sprite.flip_h = (linear_velocity.x > 0)
	var base_offset = 0
	if (linear_velocity.abs().x < linear_velocity.abs().y):
		base_offset = 4
		look_dir = LookDir.DOWN
		if (linear_velocity.y < 0):
			base_offset = 11
			look_dir = LookDir.UP
	if speed > 5 or speed == 0:
		linear_damp = 0.9
	base_offset += int(counter / 10.0) % 3
	if rammed:
		rammed = false
		if puck:
			puck.shoot(name, Vector2.ZERO)
	if charging:
		base_offset = 3
		if look_dir == LookDir.UP:
			base_offset = 14
		elif look_dir == LookDir.DOWN:
			base_offset = 10
	var spacing = 24
	if (statbook.sprite_index == 60):
		spacing = 23
	$Sprite.region_rect = Rect2(base_offset * spacing + 4, statbook.sprite_index, 24, 24)
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
	last_move = Vector2(dx, dy)
	apply_impulse(last_move * statbook.speed)

func shoot(dir: Vector2, power: float) -> void:
	var vec = dir.normalized() * 200 * (statbook.snap_power + ((1 - statbook.snap_power) * power)) * statbook.shot_power
	var vec2 = vec.rotated(statbook.shot_variance * (1 - (2*randf())))
	if puck:
		puck.shoot(name, vec2)

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if needs_reset:
		var trans = state.get_transform()
		trans.origin = initial_position
		state.set_transform(trans)
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0
		needs_reset = false
		return

	for i in range(state.get_contact_count()):
		var myimpulse: Vector2 = state.get_contact_local_velocity_at_position(i)
		var collider = state.get_contact_collider_object(i)
		if "mass" in collider:
			myimpulse *= 1 + (collider.mass - mass)
		var impulse_strength: float = myimpulse.length()
		if impulse_strength > 150.0:
			rammed = true

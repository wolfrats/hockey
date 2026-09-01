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
# Called when the node enters the scene tree for the first time.

enum LookDir {
	SIDE,
	DOWN,
	UP
}

func _ready() -> void:
	statbook = StatBook.Classes[stats]
	mass = statbook.weight
	$Sprite.material =  $Sprite.material.duplicate();
	if home_team:
		$Sprite.material.set("shader_parameter/replace_0", Globals.home_color);
	else:
		$Sprite.material.set("shader_parameter/replace_0", Globals.away_color);


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
	
func _physics_process(delta: float) -> void:
	if ghost:
		ghost.handle(delta, self)
	#counter += 1
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
	#if speed > 100:
	base_offset += int(counter / 10.0) % 3
	#else:
	#	($Body).linear_damp = 100
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
	if abs(skate_dir.angle_to(linear_velocity)) > 2:
		var s: Icesputter = preload("res://objects/environment/icesplutter.tscn").instantiate()
		%Manager.add_child(s)
		skate_dir = linear_velocity
		if linear_velocity.x > 0:
			var m: ParticleProcessMaterial = s.process_material
			m.direction.x = -m.direction.x
		s.global_position = (global_position + Vector2.DOWN * 16)
	skate_dir = skate_dir.lerp(self.linear_velocity, 0.03)
func impulse(dx: float, dy: float) -> void:
	apply_impulse(Vector2(dx, dy) * statbook.speed)

func shoot(dir: Vector2, power: float) -> void:
	var vec = dir.normalized() * 200 * (statbook.snap_power + ((1 - statbook.snap_power) * power)) * statbook.shot_power
	var vec2 = vec.rotated(statbook.shot_variance * (1 - (2*randf())))
	if puck:
		puck.shoot(name, vec2)

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
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

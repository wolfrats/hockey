class_name Referee
extends RigidBody2D

var initial_position: Vector2
var needs_reset: bool = false
var skate_dir: Vector2 = Vector2.ONE
var last_move: Vector2 = Vector2.ONE
var counter = 0
var anim_state: String = ""

# Cone of sight parameters
var cone_angle: float = PI / 3.0 # 60 degrees
var cone_radius: float = 300.0

@onready var sprite = $Sprite
@onready var sight_polygon = $SightCone

func _ready() -> void:
	initial_position = global_position
	add_to_group("referees")
	mass = 100
	sprite.texture = sprite.texture.duplicate()
	# The referee can use an existing atlas spot, let's use a default one for now
	# or base_offset 0, index 0, but maybe colorized or just black/white
	_update_cone_visuals()

func home() -> void:
	needs_reset = true

func _physics_process(delta: float) -> void:
	if anim_state == "skating_around":
		if randf() < 0.05:
			impulse(randf_range(-1, 1), randf_range(-1, 1))
		var diff = initial_position - global_position
		if diff.length() > 500:
			impulse(diff.normalized().x, diff.normalized().y)
	else:
		# Randomly skate around the rink
		if randf() < 0.02:
			# Rink dimensions roughly 300 to 1700 X, 200 to 800 Y
			var target_x = randf_range(300, 1700)
			var target_y = randf_range(200, 800)
			var target = Vector2(target_x, target_y)
			var diff = target - global_position
			impulse(diff.normalized().x, diff.normalized().y)

	var speed = linear_velocity.length()
	if speed > 5 or speed == 0:
		linear_damp = 0.9

	counter += 1
	var base_offset = int(counter / 10.0) % 3

	# Adjust Sprite facing
	if linear_velocity.x != 0:
		sprite.flip_h = (linear_velocity.x > 0)

	if (linear_velocity.abs().x < linear_velocity.abs().y):
		base_offset += 4
		if (linear_velocity.y < 0):
			base_offset += 7 # 11 is up

	# Black and white referee stripes would be nice, but we can just use regular
	var spacing = 24
	sprite.region_rect = Rect2(base_offset * spacing, 0, 24, 24)

	skate_dir = skate_dir.lerp(self.linear_velocity, 0.03)

	_update_cone_visuals()

func impulse(dx: float, dy: float) -> void:
	last_move = Vector2(dx, dy)
	apply_impulse(last_move * 300.0) # Arbitrary speed

func _update_cone_visuals():
	if not sight_polygon:
		return
	var facing_dir = linear_velocity.normalized()
	if facing_dir.length_squared() < 0.1:
		facing_dir = last_move.normalized()
	if facing_dir.length_squared() < 0.1:
		facing_dir = Vector2.RIGHT

	var points = PackedVector2Array()
	points.append(Vector2.ZERO)
	var num_segments = 10
	var base_angle = facing_dir.angle()
	var start_angle = base_angle - cone_angle / 2.0

	for i in range(num_segments + 1):
		var a = start_angle + cone_angle * (float(i) / num_segments)
		points.append(Vector2(cos(a), sin(a)) * cone_radius)
	sight_polygon.polygon = points

func is_in_cone(point: Vector2) -> bool:
	var diff = point - global_position
	if diff.length() > cone_radius:
		return false

	var facing_dir = linear_velocity.normalized()
	if facing_dir.length_squared() < 0.1:
		facing_dir = last_move.normalized()
	if facing_dir.length_squared() < 0.1:
		facing_dir = Vector2.RIGHT

	var angle_to_point = facing_dir.angle_to(diff.normalized())
	return abs(angle_to_point) <= cone_angle / 2.0

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if anim_state == "lerping":
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

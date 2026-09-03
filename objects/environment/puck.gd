class_name Puck extends RigidBody2D
@export var posessor: Skater
var blocklist: Dictionary[String, int] = {}
var colidable: bool = true
var initial_position: Vector2
var needs_reset: bool = false

func _ready() -> void:
	initial_position = global_position

func home() -> void:
	needs_reset = true
	self.posessor = null
	self.freeze = false

func _process(_delta: float) -> void:
	if posessor:
		freeze = true
		($CollisionShape2D).disabled = freeze 
		self.global_position = posessor.global_position
	else:
		freeze = false
		($CollisionShape2D).disabled = freeze 

func _physics_process(_delta: float) -> void:
	if global_position.x < -200 or global_position.x > 2200 or global_position.y < -200 or global_position.y > 1400:
		home()

	for body in get_colliding_bodies():
		if body is Skater and (not blocklist.has(body.name) or blocklist[body.name] == 0) and colidable and not body.puck:
			posessor = body
			posessor.puck = self
	for key in blocklist:
		blocklist[key] -= 1
		if blocklist[key] <= 0:
			blocklist.erase(key)
			
func shoot(shooter, vector) -> void:
	if not posessor or shooter != posessor.name:
		return
	posessor.puck = null
	posessor = null
	blocklist[shooter] = 15
	get_tree().create_timer(0.5).timeout.connect(_enable_collision)
	set_collision_mask_value(4, false)
	freeze = false
	apply_impulse(vector)
	var new_transform = get_transform() 
	new_transform.origin = global_position
	set_transform(new_transform)

func _enable_collision() -> void:
	set_collision_mask_value(4, true)

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if needs_reset:
		var trans = state.get_transform()
		trans.origin = initial_position
		state.set_transform(trans)
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0
		needs_reset = false

class_name Puck extends RigidBody2D
@export var posessor: Skater
var blocklist: Dictionary[String, int] = {}
var colidable: bool = true
var initial_position: Vector2
var needs_reset: bool = false
var block_all: int = 0

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
	if Globals.ticks > block_all:
		set_collision_mask_value(4, true)

	for body in get_colliding_bodies():
		if body is Skater and (not blocklist.has(body.name) or blocklist[body.name] == 0) and colidable and not body.puck:
			posessor = body
			posessor.puck = self
			if posessor.ghost == null:
				var manager = posessor.get_parent().get_parent()
				var ghosts_node = manager.get_node_or_null("Ghosts")
				if ghosts_node:
					var closest_player = null
					var min_dist = INF
					for p in ghosts_node.get_children():
						if p.name.begins_with("Player") and p.player_index >= 0 and p.player_index < Globals.player_auto_swap.size():
							if Globals.player_auto_swap[p.player_index] and p.skater and p.skater.home_team == posessor.home_team:
								var dist = p.skater.global_position.distance_to(posessor.global_position)
								if dist < min_dist:
									min_dist = dist
									closest_player = p
					if closest_player:
						var old_skater = closest_player.skater
						if old_skater:
							old_skater.ghost = null
						posessor.ghost = closest_player
						closest_player.skater = posessor

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
	block_all = Globals.ticks + 1
	#get_tree().create_timer(1.0/60.0).timeout.connect(_enable_collision)
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

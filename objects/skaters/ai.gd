extends Ghost
var skater: Skater
var puck: Puck
var power: float = 0
var charge: float = 0.03
var shotDir: Vector2
var dx: float
var dy: float

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

func _physics_process(_delta: float) -> void:
	if not skater:
		return
	global_position = global_position.lerp(skater.global_position, 0.1)

func is_delegated_chaser() -> bool:
	if not puck:
		return false
	var nodes = get_tree().get_nodes_in_group("skaters")
	var closest_teammate = null
	var min_distance: float = INF
	for node in nodes:
		if node is Skater and node.home_team == skater.home_team:
			var idx = node.get_index()
			if idx in [1, 2, 3]:
				var distance = node.global_position.distance_squared_to(puck.global_position)
				if distance < min_distance:
					min_distance = distance
					closest_teammate = node
	return closest_teammate == skater

func get_most_forward_teammate() -> Node2D:
	var nodes = get_tree().get_nodes_in_group("skaters")
	var forward_teammate = null
	var max_forward: float = -INF
	var forward_dir = 1.0 if skater.home_team else -1.0
	for node in nodes:
		if node is Skater and node.home_team == skater.home_team and node != skater:
			var forward_pos = node.global_position.x * forward_dir
			if forward_pos > max_forward:
				max_forward = forward_pos
				forward_teammate = node
	return forward_teammate

func get_preferred_spot(attack: bool, index: int, attack_x: float, defend_x: float, forward_dir: float) -> Vector2:
	var base_x = attack_x if attack else defend_x
	var dir = -forward_dir if attack else forward_dir
	match index:
		0:
			return Vector2(base_x + dir * 200, 509)
		1:
			return Vector2(base_x + dir * 300, 509 - 150)
		2:
			return Vector2(base_x + dir * 300, 509 + 150)
		3:
			return Vector2(base_x + dir * 400, 509 - 250)
		4:
			return Vector2(base_x + dir * 400, 509 + 250)
		_:
			return Vector2(base_x + dir * 200, 509)

func handle(_delta: float, curSkater: Skater) -> void:
	self.skater = curSkater
	var forward_dir = 1.0 if skater.home_team else -1.0
	var defend_x = 301.0 if skater.home_team else 1710.0
	var attack_x = 1710.0 if skater.home_team else 301.0

	puck = Globals.get_closest_node(curSkater.global_position, "pucks") as Puck
	var has_puck = (puck and puck.posessor == curSkater)

	var target_pos = curSkater.global_position
	var index = curSkater.get_index()

	var team_has_puck = false
	var other_team_has_puck = false
	if puck and puck.posessor and puck.posessor is Skater:
		if puck.posessor.home_team == curSkater.home_team:
			team_has_puck = true
		else:
			other_team_has_puck = true

	if has_puck:
		if abs(curSkater.global_position.x - attack_x) < 300:
			if randf() > 0.05 and index != 0:
				var y_offset = (509 - curSkater.global_position.y) * 0.5
				curSkater.shoot(Vector2(forward_dir, y_offset / 509).normalized(), 1.0)
			else:
				var teammate = get_most_forward_teammate()
				if teammate:
					curSkater.shoot((teammate.global_position - curSkater.global_position).normalized(), 0.4)
				else:
					curSkater.shoot(Vector2(forward_dir, 0), 1.0)
		else:
			target_pos = Vector2(attack_x, curSkater.global_position.y)
	elif not team_has_puck and is_delegated_chaser() and not other_team_has_puck:
		target_pos = puck.global_position
	else:
		target_pos = get_preferred_spot(team_has_puck, index, attack_x, defend_x, forward_dir)

	var dist = curSkater.global_position.distance_to(target_pos)
	if dist > 10:
		var dir = (target_pos - curSkater.global_position).normalized()
		dx = dir.x
		dy = dir.y
	else:
		dx = 0
		dy = 0

	skater.impulse(dx, dy)

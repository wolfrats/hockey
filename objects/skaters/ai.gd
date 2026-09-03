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

func get_closest_opponent() -> Node2D:
	var nodes = get_tree().get_nodes_in_group("skaters")
	var closest_opponent = null
	var min_distance: float = INF
	for node in nodes:
		if node is Skater and node.home_team != skater.home_team:
			var distance = skater.global_position.distance_squared_to(node.global_position)
			if distance < min_distance:
				min_distance = distance
				closest_opponent = node
	return closest_opponent

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

func handle(_delta: float, curSkater: Skater) -> void:
	self.skater = curSkater
	var forward_dir = 1.0 if skater.home_team else -1.0
	var defend_x = 301.0 if skater.home_team else 1710.0
	var attack_x = 1710.0 if skater.home_team else 301.0

	puck = Globals.get_closest_node(curSkater.global_position, "pucks") as Puck
	var has_puck = (puck and puck.posessor == curSkater)

	var target_pos = curSkater.global_position

	var index = curSkater.get_index()
	match index:
		0:
			# 1. One skater should always stay behind near the net to play defense, and try to ram into players on the opposing team. If this player gets the puck it will pass it to a teammate.
			if has_puck:
				var teammate = get_most_forward_teammate()
				if teammate:
					var pass_dir = (teammate.global_position - curSkater.global_position).normalized()
					curSkater.shoot(pass_dir, 1.0)
			else:
				var closest_opp = get_closest_opponent()
				if closest_opp and abs(closest_opp.global_position.x - defend_x) < 400:
					target_pos = closest_opp.global_position
				else:
					target_pos = Vector2(defend_x + forward_dir * 200, 509)
		1:
			# 2. One skater should always press forward more, hoping to score a goal.
			if has_puck:
				if abs(curSkater.global_position.x - attack_x) < 300:
					var y_offset = (509 - curSkater.global_position.y) * 0.5
					curSkater.shoot(Vector2(forward_dir, y_offset).normalized(), 1.0)
				else:
					target_pos = Vector2(attack_x, 509)
			else:
				if puck and is_delegated_chaser():
					target_pos = puck.global_position
				else:
					target_pos = Vector2(attack_x - forward_dir * 200, 509)
		2, 3:
			# 3. Two skaters should press forward often, hoping to pass or score a goal.
			if has_puck:
				if abs(curSkater.global_position.x - attack_x) < 300:
					if randf() > 0.05:
						var y_offset = (509 - curSkater.global_position.y) * 0.5
						curSkater.shoot(Vector2(forward_dir, y_offset).normalized(), 1.0)
					else:
						var teammate = get_most_forward_teammate()
						if teammate:
							curSkater.shoot((teammate.global_position - curSkater.global_position).normalized(), 0.8)
				else:
					target_pos = Vector2(attack_x, curSkater.global_position.y)
			else:
				if puck and is_delegated_chaser() and (puck.posessor == null or (puck.posessor is Skater and puck.posessor.home_team != curSkater.home_team)):
					target_pos = puck.global_position
				else:
					var y_offset = -150 if index == 2 else 150
					target_pos = Vector2(attack_x - forward_dir * 300, 509 + y_offset)
		4:
			# 4. One skater should tend to stay back, but during breakaways shift to be more aggressive. Otherwise this skater should attempt to ram other players.
			var breakaway = false
			if puck and puck.posessor and puck.posessor is Skater:
				if puck.posessor.home_team == curSkater.home_team:
					if (forward_dir > 0 and puck.posessor.global_position.x > 1000) or (forward_dir < 0 and puck.posessor.global_position.x < 1000):
						breakaway = true

			if breakaway:
				target_pos = Vector2(attack_x - forward_dir * 350, curSkater.global_position.y)
			else:
				var closest_opp = get_closest_opponent()
				if closest_opp and curSkater.global_position.distance_to(closest_opp.global_position) < 400:
					target_pos = closest_opp.global_position
				else:
					target_pos = Vector2(defend_x + forward_dir * 400, 509)

			if has_puck:
				var teammate = get_most_forward_teammate()
				if teammate:
					curSkater.shoot((teammate.global_position - curSkater.global_position).normalized(), 1.0)
				else:
					curSkater.shoot(Vector2(forward_dir, 0), 1.0)
		_:
			target_pos = curSkater.global_position

	var dist = curSkater.global_position.distance_to(target_pos)
	if dist > 10:
		var dir = (target_pos - curSkater.global_position).normalized()
		dx = dir.x
		dy = dir.y
	else:
		dx = 0
		dy = 0

	skater.impulse(dx, dy)

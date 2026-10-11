extends Ghost

static var team_strategies: Dictionary = {}
static var next_strategy_switch: Dictionary = {}

var skater: Skater
var puck: Puck
var power: float = 0
var charge: float = 0.03
var shot_dir: Vector2
var dx: float
var dy: float
var is_charging: bool = false
var target_power: float = 0.0
var shot_aim_dir: Vector2 = Vector2.ZERO
var current_random_spot: Vector2 = Vector2.ZERO
var going_for_puck: bool = false
var going_for_puck_timer: float = 0.0
var anger: float = 0.0
var max_anger: float = 100.0
var is_angry: bool = false
var last_health: float = 0.0

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
	var nodes = skater.get_tree().get_nodes_in_group("skaters")
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
	var nodes = skater.get_tree().get_nodes_in_group("skaters")
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

func get_opponent_to_ram() -> Vector2:
	var nodes = skater.get_tree().get_nodes_in_group("skaters")
	var opponents = []
	for node in nodes:
		if node is Skater and node.home_team != skater.home_team:
			opponents.append(node)

	if opponents.size() > 0:
		var target_idx = skater.get_index() % opponents.size()
		return opponents[target_idx].global_position

	# Fallback if no matching opponent is found
	var defend_x = 301.0 if skater.home_team else 1710.0
	return Vector2(defend_x, 509)

func get_preferred_spot(
	attack: bool, index: int, attack_x: float, defend_x: float, forward_dir: float,
	difficulty: int = 0
) -> Vector2:
	var base_x = attack_x if attack else defend_x
	var dir = -forward_dir if attack else forward_dir
	match index:
		0:
			return Vector2(base_x + dir * 200, 509)
		1:
			if difficulty == 2 and attack:
				return Vector2(base_x + dir * 150, 509 - 100)
			return Vector2(base_x + dir * 300, 509 - 150)
		2:
			if difficulty == 2 and attack:
				return Vector2(base_x + dir * 150, 509 + 100)
			return Vector2(base_x + dir * 300, 509 + 150)
		3:
			return Vector2(base_x + dir * 400, 509 - 250)
		4:
			return Vector2(base_x + dir * 400, 509 + 250)
		_:
			return Vector2(base_x + dir * 200, 509)

func handle(_delta: float, cur_skater) -> void:
	self.skater = cur_skater

	if not team_strategies.has(skater.home_team):
		team_strategies[skater.home_team] = 4
		next_strategy_switch[skater.home_team] = Globals.ticks + randi_range(600, 1200)

	if Globals.ticks >= next_strategy_switch[skater.home_team]:
		team_strategies[skater.home_team] = randi_range(1, 4)
		next_strategy_switch[skater.home_team] = Globals.ticks + randi_range(600, 1200)

	var difficulty = Globals.home_ai_difficulty if skater.home_team else Globals.away_ai_difficulty
	var current_strategy = team_strategies[skater.home_team]

	if difficulty >= 1:
		current_strategy = 2

	if last_health == 0.0:
		last_health = cur_skater.health

	if cur_skater.health < last_health:
		var anger_mult = 10.0 if difficulty >= 1 else 3.0
		anger += (last_health - cur_skater.health) * anger_mult
	last_health = cur_skater.health

	anger = max(0.0, anger - _delta * 10.0)

	if anger >= max_anger:
		is_angry = true
	if anger <= 0.0:
		is_angry = false

	var forward_dir = 1.0 if skater.home_team else -1.0
	var defend_x = 301.0 if skater.home_team else 1710.0
	var attack_x = 1710.0 if skater.home_team else 301.0

	puck = Globals.get_closest_node(cur_skater.global_position, "pucks") as Puck
	var has_puck = (puck and puck.posessor == cur_skater)

	var target_pos = cur_skater.global_position
	var index = cur_skater.get_index()

	var team_has_puck = false
	var other_team_has_puck = false
	if puck and puck.posessor and puck.posessor is Skater:
		if puck.posessor.home_team == cur_skater.home_team:
			team_has_puck = true
		else:
			other_team_has_puck = true

	if is_angry:
		var all_skaters = cur_skater.get_tree().get_nodes_in_group("skaters")
		var target_skater = null
		var min_dist = INF
		for s in all_skaters:
			if s is Skater and s.home_team != cur_skater.home_team:
				var d = cur_skater.global_position.distance_squared_to(s.global_position)
				if d < min_dist:
					min_dist = d
					target_skater = s
		if target_skater:
			target_pos = target_skater.global_position
			if cur_skater.global_position.distance_to(target_pos) < 60:
				if cur_skater.spring.node_b.is_empty() and randf() < 0.3:
					cur_skater.do_grab(true)
				else:
					cur_skater.do_check()
				anger = 0.0
				is_angry = false
	elif has_puck:
		var target_distance = 800 if difficulty == 2 else (500 if difficulty >= 1 else 300)
		if is_charging:
			power += charge
			cur_skater.charging = true
			if power >= target_power:
				var inaccuracy = 0.0 if difficulty >= 1 else 1.0
				cur_skater.shoot(shot_aim_dir, power, inaccuracy)
				power = 0
				is_charging = false
				cur_skater.charging = false
		elif difficulty == 2 and \
		abs(cur_skater.global_position.x - attack_x) >= target_distance and randf() < 0.02:
			var teammate = get_most_forward_teammate()
			if teammate:
				shot_aim_dir = (teammate.global_position - cur_skater.global_position).normalized()
				target_power = 0.4
				is_charging = true
				power = 0.0
		elif abs(cur_skater.global_position.x - attack_x) < target_distance:
			if randf() > 0.05 and index != 0:
				var target_y = 509.0
				var manager = cur_skater.get_parent().get_parent()
				var target_goalie = null
				if manager:
					for child in manager.get_children():
						if child is Goalie and child.home_team != cur_skater.home_team:
							target_goalie = child
							break

				if target_goalie:
					var top_post = 458.0
					var bottom_post = 560.0
					var goalie_y = target_goalie.global_position.y
					var top_gap = goalie_y - top_post
					var bottom_gap = bottom_post - goalie_y

					if top_gap > bottom_gap:
						target_y = top_post + (top_gap / 4.0)
					else:
						target_y = bottom_post - (bottom_gap / 4.0)

				shot_aim_dir = Vector2(
					attack_x - cur_skater.global_position.x,
					target_y - cur_skater.global_position.y
				).normalized()
				if difficulty == 2 and abs(cur_skater.global_position.x - attack_x) < 200:
					target_power = 0.4
				else:
					target_power = 1.0
				is_charging = true
				power = 0.0
			else:
				var teammate = get_most_forward_teammate()
				if teammate:
					shot_aim_dir = (teammate.global_position - cur_skater.global_position).normalized()
					target_power = 0.4
					is_charging = true
					power = 0.0
				else:
					shot_aim_dir = Vector2(forward_dir, 0)
					target_power = 1.0
					is_charging = true
					power = 0.0
		else:
			target_pos = Vector2(attack_x, cur_skater.global_position.y)
	else:
		if is_charging:
			is_charging = false
			power = 0.0
			cur_skater.charging = false

		match current_strategy:
			1:
				if is_delegated_chaser():
					target_pos = puck.global_position if puck else cur_skater.global_position
				else:
					if current_random_spot == Vector2.ZERO or \
					cur_skater.global_position.distance_to(current_random_spot) < 50:
						current_random_spot = Vector2(
							randf_range(min(attack_x, defend_x), max(attack_x, defend_x)),
							randf_range(100, 900)
						)
					target_pos = current_random_spot
			2:
				if is_delegated_chaser():
					target_pos = puck.global_position if puck else cur_skater.global_position
					if difficulty >= 1 and other_team_has_puck and \
					cur_skater.global_position.distance_to(target_pos) < 60:
						var bump_chance = 0.2 if difficulty == 2 else 0.05
						if randf() < bump_chance:
							if cur_skater.spring.node_b.is_empty() and randf() < 0.3:
								cur_skater.do_grab(true)
							else:
								cur_skater.do_check()
				else:
					target_pos = get_opponent_to_ram()
					if difficulty >= 1 and cur_skater.global_position.distance_to(target_pos) < 60:
						var bump_chance = 0.2 if difficulty == 2 else 0.05
						if randf() < bump_chance:
							if cur_skater.spring.node_b.is_empty() and randf() < 0.3:
								cur_skater.do_grab(true)
							else:
								cur_skater.do_check()
			3:
				going_for_puck_timer -= _delta
				if going_for_puck_timer <= 0:
					going_for_puck_timer = randf_range(0.5, 2.0)
					going_for_puck = randf() < 0.3
				if going_for_puck and puck:
					target_pos = puck.global_position
				else:
					target_pos = cur_skater.global_position # Stand still
			_:
				if not team_has_puck and is_delegated_chaser() and not other_team_has_puck:
					target_pos = puck.global_position if puck else cur_skater.global_position
				else:
					target_pos = get_preferred_spot(
						team_has_puck, index, attack_x, defend_x, forward_dir, difficulty
					)

	if not cur_skater.spring.node_b.is_empty() and randf() < 0.02:
		cur_skater.release_grab()

	var dist = cur_skater.global_position.distance_to(target_pos)
	if dist > 10:
		var dir = (target_pos - cur_skater.global_position).normalized()

		if difficulty >= 1:
			var avoidance = Vector2.ZERO
			var obstacles = []

			obstacles.append({"pos": Vector2(301, 509), "radius": 120.0})
			obstacles.append({"pos": Vector2(1710, 509), "radius": 120.0})

			var all_skaters = cur_skater.get_tree().get_nodes_in_group("skaters")
			for s in all_skaters:
				if s != cur_skater and s.is_inside_tree():
					if target_pos.distance_to(s.global_position) > 40:
						obstacles.append({"pos": s.global_position, "radius": 80.0})

			var manager = cur_skater.get_parent().get_parent()
			if manager:
				for child in manager.get_children():
					if child is Goalie and child.is_inside_tree():
						if target_pos.distance_to(child.global_position) > 40:
							obstacles.append({"pos": child.global_position, "radius": 80.0})

			for obs in obstacles:
				var d = cur_skater.global_position.distance_to(obs.pos)
				if d < obs.radius and d > 0.0:
					var to_obs = (obs.pos - cur_skater.global_position).normalized()
					if dir.dot(to_obs) > 0.3:
						var repulse = -to_obs
						var tangent = Vector2(-to_obs.y, to_obs.x)
						if dir.dot(tangent) < 0:
							tangent = -tangent

						var weight = 1.0 - (d / obs.radius)
						avoidance += (repulse * 0.5 + tangent * 1.5) * weight

			if avoidance != Vector2.ZERO:
				dir = (dir + avoidance).normalized()

		dx = dir.x
		dy = dir.y
	else:
		dx = 0
		dy = 0

	skater.impulse(dx, dy)

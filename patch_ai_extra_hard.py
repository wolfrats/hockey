import re

with open("objects/skaters/ai.gd", "r") as f:
    code = f.read()

# "Extra hard" logic
# 1. One player on their team should always chase the puck. They should try bumping the skater with the puck to take it.
# 2. They should try to take the puck back in the other half of the rink, playing aggressively.
# 3. When they get the puck they should pass frequently while moving up the rink, and take shots from fairly far away. One skater should get to a spot of a likely rebound too, and shoot if they get the puck etc.

search_str = """	if difficulty == 1:
		current_strategy = 2"""

replace_str = """	if difficulty == 1:
		current_strategy = 2
	elif difficulty == 2:
		current_strategy = 5""" # Custom strategy 5 for Extra Hard

code = code.replace(search_str, replace_str)

search_str = """	elif has_puck:
		var target_distance = 500 if difficulty >= 1 else 300
		if is_charging:
			power += charge
			curSkater.charging = true
			if power >= target_power:
				var inaccuracy = 0.0 if difficulty >= 1 else 1.0
				curSkater.shoot(shot_aim_dir, power, inaccuracy)
				power = 0
				is_charging = false
				curSkater.charging = false
		elif abs(curSkater.global_position.x - attack_x) < target_distance:
			if randf() > 0.05 and index != 0:
				var target_y = 509.0
				var manager = curSkater.get_parent().get_parent()
				var target_goalie = null
				if manager:
					for child in manager.get_children():
						if child is Goalie and child.home_team != curSkater.home_team:
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

				shot_aim_dir = Vector2(attack_x - curSkater.global_position.x, target_y - curSkater.global_position.y).normalized()
				target_power = 1.0
				is_charging = true
				power = 0.0
			else:
				var teammate = get_most_forward_teammate()
				if teammate:
					shot_aim_dir = (teammate.global_position - curSkater.global_position).normalized()
					target_power = 0.4
					is_charging = true
					power = 0.0
				else:
					shot_aim_dir = Vector2(forward_dir, 0)
					target_power = 1.0
					is_charging = true
					power = 0.0
		else:
			target_pos = Vector2(attack_x, curSkater.global_position.y)"""

replace_str = """	elif has_puck:
		var target_distance = 500 if difficulty >= 1 else 300
		if difficulty == 2:
			target_distance = 650 # Take shots from fairly far away

		if is_charging:
			power += charge
			curSkater.charging = true
			if power >= target_power:
				var inaccuracy = 0.0 if difficulty >= 1 else 1.0
				curSkater.shoot(shot_aim_dir, power, inaccuracy)
				power = 0
				is_charging = false
				curSkater.charging = false
		elif abs(curSkater.global_position.x - attack_x) < target_distance:
			if randf() > 0.05 and index != 0:
				var target_y = 509.0
				var manager = curSkater.get_parent().get_parent()
				var target_goalie = null
				if manager:
					for child in manager.get_children():
						if child is Goalie and child.home_team != curSkater.home_team:
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

				shot_aim_dir = Vector2(attack_x - curSkater.global_position.x, target_y - curSkater.global_position.y).normalized()
				target_power = 1.0
				is_charging = true
				power = 0.0
			else:
				var teammate = get_most_forward_teammate()
				if teammate:
					shot_aim_dir = (teammate.global_position - curSkater.global_position).normalized()
					target_power = 0.4
					is_charging = true
					power = 0.0
				else:
					shot_aim_dir = Vector2(forward_dir, 0)
					target_power = 1.0
					is_charging = true
					power = 0.0
		elif difficulty == 2 and randf() < 0.05: # pass frequently while moving up the rink
			var teammate = get_most_forward_teammate()
			if teammate and teammate.global_position.x * forward_dir > curSkater.global_position.x * forward_dir:
				shot_aim_dir = (teammate.global_position - curSkater.global_position).normalized()
				target_power = 0.6
				is_charging = true
				power = 0.0
			else:
				target_pos = Vector2(attack_x, curSkater.global_position.y)
		else:
			target_pos = Vector2(attack_x, curSkater.global_position.y)"""

code = code.replace(search_str, replace_str)


search_str = """			_:
				if not team_has_puck and is_delegated_chaser() and not other_team_has_puck:
					target_pos = puck.global_position if puck else curSkater.global_position
				else:
					target_pos = get_preferred_spot(team_has_puck, index, attack_x, defend_x, forward_dir)"""

replace_str = """			5: # Extra Hard strategy
				if is_delegated_chaser():
					target_pos = puck.global_position if puck else curSkater.global_position
					# always chase the puck. They should try bumping the skater with the puck to take it.
					# They should try to take the puck back in the other half of the rink, playing aggressively.
					if curSkater.global_position.distance_to(target_pos) < 80:
						if randf() < 0.1:
							if curSkater.spring.node_b.is_empty() and randf() < 0.3:
								curSkater.do_grab(true)
							else:
								curSkater.do_check()
				else:
					if team_has_puck:
						# One skater should get to a spot of a likely rebound too, and shoot if they get the puck etc.
						if index == 1:
							# Go to rebound spot
							target_pos = Vector2(attack_x - forward_dir * 150, 509 + randf_range(-100, 100))
						else:
							target_pos = get_preferred_spot(team_has_puck, index, attack_x, defend_x, forward_dir)
					else:
						# play aggressively in the other half of the rink
						var opponent = get_opponent_to_ram()
						if opponent.x * forward_dir > 0: # If in opponent's half
							target_pos = opponent
							if curSkater.global_position.distance_to(target_pos) < 80:
								if randf() < 0.05:
									if curSkater.spring.node_b.is_empty() and randf() < 0.3:
										curSkater.do_grab(true)
									else:
										curSkater.do_check()
						else:
							target_pos = get_preferred_spot(team_has_puck, index, attack_x, defend_x, forward_dir)
			_:
				if not team_has_puck and is_delegated_chaser() and not other_team_has_puck:
					target_pos = puck.global_position if puck else curSkater.global_position
				else:
					target_pos = get_preferred_spot(team_has_puck, index, attack_x, defend_x, forward_dir)"""

code = code.replace(search_str, replace_str)


with open("objects/skaters/ai.gd", "w") as f:
    f.write(code)

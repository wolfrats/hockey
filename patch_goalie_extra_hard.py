import re

with open("objects/skaters/goalie.gd", "r") as f:
    code = f.read()

# Update goalie behavior for extra hard difficulty
# 1. anticipate where the shot will be shot at
# 2. may even sometimes come out of the net to try to bump skaters away / block more angles.

search_str = """			if difficulty >= 1 and puck_node.posessor and puck_node.posessor.charging:
				var shooter = puck_node.posessor
				var aim_dir = Vector2.ZERO
				if shooter.ghost and "shotDir" in shooter.ghost:
					aim_dir = shooter.ghost.shotDir.normalized()
				elif shooter.ai and "shot_aim_dir" in shooter.ai:
					aim_dir = shooter.ai.shot_aim_dir.normalized()
				if aim_dir.length_squared() > 0 and aim_dir.x != 0:
					var dist_x = home_x - shooter.global_position.x
					if (dist_x > 0 and aim_dir.x > 0) or (dist_x < 0 and aim_dir.x < 0):
						var t = dist_x / aim_dir.x
						target_y = clamp(shooter.global_position.y + aim_dir.y * t + OFFSET, min_y, max_y)"""

replace_str = """			var target_x = home_x
			var target_shooter = null
			if puck_node.posessor and puck_node.posessor is Skater and puck_node.posessor.home_team != home_team:
				target_shooter = puck_node.posessor

			if difficulty == 2 and target_shooter:
				# come out of the net to try to bump skaters away / block more angles
				var dist_to_shooter = global_position.distance_to(target_shooter.global_position)
				if dist_to_shooter < 300:
					target_x = home_x + (target_shooter.global_position.x - home_x) * 0.5
					if dist_to_shooter < 100 and randf() < 0.05:
						# sometimes come out to bump
						target_x = target_shooter.global_position.x
						target_y = target_shooter.global_position.y

			var diffx = clamp(global_position.x - target_x, -16, 16)
			if abs(diffx) > 4:
				apply_impulse(Vector2.LEFT * diffx)

			if difficulty >= 1 and puck_node.posessor and puck_node.posessor.charging:
				var shooter = puck_node.posessor
				var aim_dir = Vector2.ZERO
				if shooter.ghost and "shotDir" in shooter.ghost:
					aim_dir = shooter.ghost.shotDir.normalized()
				elif shooter.ai and "shot_aim_dir" in shooter.ai:
					aim_dir = shooter.ai.shot_aim_dir.normalized()
				if aim_dir.length_squared() > 0 and aim_dir.x != 0:
					var dist_x = home_x - shooter.global_position.x
					if (dist_x > 0 and aim_dir.x > 0) or (dist_x < 0 and aim_dir.x < 0):
						var t = dist_x / aim_dir.x
						target_y = clamp(shooter.global_position.y + aim_dir.y * t + OFFSET, min_y, max_y)
			elif difficulty == 2 and target_shooter and target_shooter.linear_velocity.length() > 10:
				# anticipate where the shot will be shot at
				var predict_time = 0.5
				var predicted_pos = target_shooter.global_position + target_shooter.linear_velocity * predict_time
				target_y = clamp(predicted_pos.y + OFFSET, min_y, max_y)"""

code = code.replace(search_str, replace_str)

code = code.replace("""	else:
		var diffx = clamp(global_position.x - home_x, -16, 16)
		if abs(diffx) > 4:
			apply_impulse(Vector2.LEFT * diffx)
		var puck_node = Globals.get_closest_node(global_position, "pucks")
		if puck_node:
			var target_y = clamp(puck_node.global_position.y + OFFSET, min_y, max_y)
			var difficulty = Globals.home_ai_difficulty if home_team else Globals.away_ai_difficulty""",
"""	else:
		var puck_node = Globals.get_closest_node(global_position, "pucks")
		if puck_node:
			var target_y = clamp(puck_node.global_position.y + OFFSET, min_y, max_y)
			var difficulty = Globals.home_ai_difficulty if home_team else Globals.away_ai_difficulty""")

with open("objects/skaters/goalie.gd", "w") as f:
    f.write(code)

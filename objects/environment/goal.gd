extends Node2D

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is Puck:
		if Globals.manager.is_practice:
			body.home.call_deferred()
			return

		var goal_name = get_parent().name
		if "anim_manager" in Globals.manager and Globals.manager.anim_manager != null:
			if Globals.manager.anim_manager.current_phase == AnimationManager.Phase.SHOOTOUT_ACTIVE:
				if Globals.manager.has_method("on_shootout_goal"):
					Globals.manager.on_shootout_goal(goal_name)
				return

		if body.posessor != null and body.has_method("refresh_current_possessor_info"):
			body.refresh_current_possessor_info()

		if not body.shot_on_goal_counted and body.last_possessor != "":
			if not Globals.shot_stats.has(body.last_possessor):
				Globals.shot_stats[body.last_possessor] = 0
			Globals.shot_stats[body.last_possessor] += 1
			if not body.last_possessor_info.is_empty():
				var info: Dictionary = body.last_possessor_info
				Globals.record_skater_stat(
					int(info.get("team_index", -1)),
					bool(info.get("home_team", false)),
					int(info.get("number", 0)),
					str(info.get("name", "")),
					"shots",
					1
				)
			body.shot_on_goal_counted = true

		Globals.manager.goal_scored(
			goal_name,
			body.last_possessor,
			body.assist_possessor,
			body.last_possessor_info,
			body.assist_possessor_info
		)
		if "anim_manager" in Globals.manager and Globals.manager.anim_manager != null:
			Globals.manager.anim_manager.on_goal_scored(goal_name == "AwayGoal")
		else:
			var pucks = get_tree().get_nodes_in_group("pucks")
			for p in pucks:
				p.home.call_deferred()
			var skaters = get_tree().get_nodes_in_group("skaters")
			for s in skaters:
				if s.has_method("home"):
					s.home.call_deferred()

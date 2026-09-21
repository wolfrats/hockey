extends Node2D

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is Puck:
		if Globals.manager.is_practice:
			body.home.call_deferred()
			return
		Globals.manager.goal_scored(get_parent().name, body.last_possessor, body.assist_possessor)
		if "anim_manager" in Globals.manager and Globals.manager.anim_manager != null:
			Globals.manager.anim_manager.on_goal_scored()
		else:
			var pucks = get_tree().get_nodes_in_group("pucks")
			for p in pucks:
				p.home.call_deferred()
			var skaters = get_tree().get_nodes_in_group("skaters")
			for s in skaters:
				if s.has_method("home"):
					s.home.call_deferred()

class_name AnimationManager
extends Node

enum Phase {
	PRE_GAME_SKATE,
	PRE_GAME_LERP,
	PLAYING,
	POST_GOAL_SKATE,
	POST_GOAL_LERP,
	POST_PERIOD_SKATE_OUT,
	POST_PERIOD_WAIT,
	PRE_PERIOD_SKATE,
	PRE_PERIOD_LERP,
	PRE_PENALTY_SKATE,
	PRE_PENALTY_LERP,
	FACE_OFF,
	REPLAY,
	FIGHT,
	INTERMISSION_MITES,
	SHOOTOUT_SETUP,
	SHOOTOUT_ACTIVE,
	SHOOTOUT_RESULT
}

var lights: Node
var current_phase: Phase = Phase.PRE_GAME_SKATE
var phase_timer: float = 0.0
var manager: Node = null
var scoring_team_home: bool = false

func _ready() -> void:
	manager = get_parent()
	set_phase(Phase.PRE_GAME_SKATE)
	lights = get_tree().root.get_node_or_null("Rink/Lights")

func _unhandled_input(event: InputEvent) -> void:
	if current_phase == Phase.INTERMISSION_MITES:
		if phase_timer > 0.0:
			return
		var press_space: bool = (event is InputEventKey and event.pressed and not event.is_echo() and (event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE)) \
			or event.is_action_pressed("shoot")
		var press_joy: bool = (event is InputEventJoypadButton and event.pressed and not event.is_echo() and (event.button_index == JOY_BUTTON_A or event.button_index == JOY_BUTTON_X))
		if press_space or press_joy:
			if manager and manager.has_method("stop_mites_intermission"):
				manager.stop_mites_intermission()
			get_viewport().set_input_as_handled()
			set_phase(Phase.PRE_PERIOD_LERP)
		return

	if current_phase != Phase.REPLAY:
		return
	if not manager:
		return
	if event.is_action_pressed("ui_cancel"):
		return

	var skip_device_id: int = -1
	if event is InputEventJoypadButton and event.pressed and not event.is_echo():
		skip_device_id = event.device
	elif not (event is InputEventJoypadButton) and not (event is InputEventJoypadMotion):
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("pass") \
				or event.is_action_pressed("shoot") or event.is_action_pressed("swap") \
				or event.is_action_pressed("check") or event.is_action_pressed("grab") \
				or event.is_action_pressed("sprint"):
			skip_device_id = -2

	if skip_device_id != -1 and manager.has_method("mark_player_replay_skip"):
		var all_skipped: bool = manager.mark_player_replay_skip(skip_device_id)
		get_viewport().set_input_as_handled()
		if all_skipped:
			_finish_replay()

func _finish_replay() -> void:
	if manager and manager.has_method("stop_replay"):
		manager.stop_replay()
	if manager and manager.has_method("hide_goal_banner"):
		manager.hide_goal_banner()
	# Sudden-death OT goal ends the match right after replay
	if manager and manager.has_method("is_overtime_active") and manager.is_overtime_active() and manager.home_score != manager.away_score:
		Globals.match_ended_in = "OT"
		manager.finish_match()
		return
	set_phase(Phase.FACE_OFF)

func _process(delta: float) -> void:
	if current_phase == Phase.PLAYING or current_phase == Phase.FIGHT:
		return

	if current_phase == Phase.SHOOTOUT_ACTIVE:
		if manager and manager.has_method("step_shootout"):
			manager.step_shootout(delta)
		return

	phase_timer -= delta

	match current_phase:
		Phase.PRE_GAME_SKATE:
			var start = false
			if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("pass") \
					or Input.is_action_just_pressed("shoot") or Input.is_action_just_pressed("swap") \
					or Input.is_action_just_pressed("check"):
				start = true
			for device in Globals.player_devices:
				if device >= 0:
					if Input.is_joy_button_pressed(device, JOY_BUTTON_A) or \
					Input.is_joy_button_pressed(device, JOY_BUTTON_X) \
						or Input.is_joy_button_pressed(device, JOY_BUTTON_Y) \
				or Input.is_joy_button_pressed(device, JOY_BUTTON_B):
						start = true

			if lights:
				for i in range(0, min(3, lights.get_child_count())):
					var light: PointLight2D = lights.get_children()[i]
					var idx: int = i + 1
					var radius_large = 60 + idx * 9
					var radius_small = 30 - idx * 4
					var dist = 40 + idx * 20
					var scale_val = 3
					var time = Globals.ticks / (90.0 - idx)
					var diff = radius_large - radius_small
					var mult = diff / radius_small * time
					var x = (diff * cos(time) + dist * cos(mult)) * scale_val
					var y = (diff * sin(time) + dist * sin(mult)) * scale_val
					light.global_position = Vector2(1000 + x, 512 + y)
			if start:
				set_phase(Phase.PRE_GAME_LERP)
				var cm := get_tree().root.get_node_or_null("Rink/CanvasModulate")
				if cm:
					cm.color = Color.WHITE
				if lights:
					for i in range(0, min(3, lights.get_child_count())):
						lights.get_children()[i].visible = false
		Phase.PRE_GAME_LERP:
			if phase_timer <= 0:
				set_phase(Phase.FACE_OFF)
		Phase.POST_GOAL_SKATE:
			if phase_timer <= 0:
				set_phase(Phase.POST_GOAL_LERP)
		Phase.POST_GOAL_LERP:
			if phase_timer <= 0:
				set_phase(Phase.REPLAY)
		Phase.REPLAY:
			if manager and manager.has_method("are_all_players_skipping_replay") \
					and manager.are_all_players_skipping_replay():
				_finish_replay()
		Phase.POST_PERIOD_SKATE_OUT:
			if phase_timer <= 0:
				set_phase(Phase.POST_PERIOD_WAIT)
		Phase.POST_PERIOD_WAIT:
			if phase_timer <= 0:
				if manager.current_period >= 3:
					if manager.home_score != manager.away_score:
						manager.finish_match()
					else:
						var action: String = manager.get_next_tiebreaker_action() if manager.has_method("get_next_tiebreaker_action") else "finish_tie"
						if action == "start_playoff_ot":
							manager.prepare_overtime(false)
							set_phase(Phase.PRE_PERIOD_SKATE)
						elif action == "start_3v3_ot":
							manager.prepare_overtime(true)
							set_phase(Phase.PRE_PERIOD_SKATE)
						elif action == "start_shootout":
							manager.start_shootout()
						else:
							manager.finish_match()
				elif manager.current_period == 1:
					set_phase(Phase.INTERMISSION_MITES)
				else:
					set_phase(Phase.PRE_PERIOD_SKATE)
		Phase.INTERMISSION_MITES:
			pass
		Phase.PRE_PERIOD_SKATE:
			var start = false
			if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("pass") \
					or Input.is_action_just_pressed("shoot") or Input.is_action_just_pressed("swap") \
					or Input.is_action_just_pressed("check"):
				start = true
			for device in Globals.player_devices:
				if device >= 0:
					if Input.is_joy_button_pressed(device, JOY_BUTTON_A) or \
					Input.is_joy_button_pressed(device, JOY_BUTTON_X) \
						or Input.is_joy_button_pressed(device, JOY_BUTTON_Y) \
				or Input.is_joy_button_pressed(device, JOY_BUTTON_B):
						start = true
			if start:
				set_phase(Phase.PRE_PERIOD_LERP)
		Phase.PRE_PERIOD_LERP:
			if phase_timer <= 0:
				manager.current_period += 1
				manager.time_remaining = manager.get_period_duration(manager.current_period) if manager.has_method("get_period_duration") else Globals.period_length
				set_phase(Phase.FACE_OFF)
		Phase.PRE_PENALTY_SKATE:
			if phase_timer <= 0:
				set_phase(Phase.PRE_PENALTY_LERP)
		Phase.PRE_PENALTY_LERP:
			if phase_timer <= 0:
				set_phase(Phase.FACE_OFF)
		Phase.FACE_OFF:
			if phase_timer <= 1.0 and phase_timer + delta > 1.0:
				var referees = get_tree().get_nodes_in_group("referees")
				for ref in referees:
					if ref.has_method("shake"):
						ref.shake()

			if phase_timer <= 0:
				var pucks = get_tree().get_nodes_in_group("pucks")
				for p in pucks:
					p.freeze = false
				var has_faceoff_skater: bool = false
				for s in get_tree().get_nodes_in_group("skaters"):
					if s is Skater and s.anim_state == "face_off" and not s.ot_benched:
						has_faceoff_skater = true
						break
				if not has_faceoff_skater:
					set_phase(Phase.PLAYING)
		Phase.SHOOTOUT_SETUP:
			if phase_timer <= 0:
				set_phase(Phase.SHOOTOUT_ACTIVE)
		Phase.SHOOTOUT_RESULT:
			if phase_timer <= 0:
				if manager and manager.has_method("advance_shootout_turn"):
					manager.advance_shootout_turn()

func set_phase(new_phase: Phase) -> void:
	current_phase = new_phase

	var skaters = get_tree().get_nodes_in_group("skaters")
	var pucks = get_tree().get_nodes_in_group("pucks")

	if new_phase != Phase.POST_GOAL_SKATE and new_phase != Phase.POST_GOAL_LERP and new_phase != Phase.SHOOTOUT_RESULT:
		for s in skaters:
			if "celebrating" in s:
				s.celebrating = false

	match current_phase:
		Phase.PRE_GAME_SKATE:
			phase_timer = 3.0
			var circle = true
			for s in skaters:
				if "anim_state" in s:
					if s.is_out_of_play():
						continue
					s.anim_state = "skating_circle" if circle else "skating_figure8"
					circle = not circle
			for p in pucks:
				p.visible = false
				p.freeze = true
				if "colidable" in p:
					p.colidable = false

		Phase.PRE_GAME_LERP:
			phase_timer = 1.5
			for s in skaters:
				if "anim_state" in s:
					if s.is_out_of_play():
						continue
					s.anim_state = "lerping"

		Phase.REPLAY:
			if manager and manager.has_method("start_replay"):
				manager.start_replay()

		Phase.PLAYING:
			($"../../Boards/BoardsCollision").disabled = false
			for s in skaters:
				if "anim_state" in s:
					if s.is_out_of_play():
						continue
					s.anim_state = ""
					if "base_initial_position" in s:
						s.initial_position = s.base_initial_position

			var referees = get_tree().get_nodes_in_group("referees")
			for ref in referees:
				if "anim_state" in ref:
					ref.anim_state = ""

			for p in pucks:
				p.visible = true
				if p.posessor == null:
					p.freeze = false
				if "colidable" in p:
					p.colidable = true

		Phase.FACE_OFF:
			phase_timer = randf_range(3.5, 6.5)
			($"../../Boards/BoardsCollision").disabled = false
			if manager:
				for child in manager.get_children():
					if child is Goalie and child.pulled:
						child.return_to_net()
			skaters = get_tree().get_nodes_in_group("skaters")
			var team_has_penalty = false
			for s in skaters:
				if "anim_state" in s:
					if s is Skater and s.is_in_penalty() and s.penalty_time <= 0.0:
						s.finish_expired_penalty()
					if s.is_in_penalty():
						team_has_penalty = true
						continue
					if s.ot_benched:
						continue
					s.anim_state = "face_off"
					if s is Skater:
						s.release_grab()
						s.charging = false
						s.sprinting = false
						s.checking = 0
						s.knocked_over = 0
						s.was_knocked_over = false
			var faceoff_pos = Vector2(1005.5, 509)
			if team_has_penalty:
				var home_pen_count: int = 0
				var away_pen_count: int = 0
				for s in skaters:
					if s is Skater and s.is_in_penalty() and s.penalty_time > 0:
						if s.home_team:
							home_pen_count += 1
						else:
							away_pen_count += 1
				# Only put faceoff in defensive zone if one team has a man-advantage
				if home_pen_count != away_pen_count:
					if home_pen_count > away_pen_count:
						faceoff_pos = Vector2(590, 282)
					else:
						faceoff_pos = Vector2(1420, 720)

			for p in pucks:
				p.home(faceoff_pos)
				p.visible = true
				p.freeze = true
				if "colidable" in p:
					p.colidable = true

			var referees = get_tree().get_nodes_in_group("referees")
			for ref in referees:
				if "anim_state" in ref:
					ref.anim_state = "skate_to"
					ref.target_pos = faceoff_pos

			var home_skaters = []
			var away_skaters = []
			for s in skaters:
				if "anim_state" in s and s.anim_state == "face_off" and not s.ot_benched:
					if s.home_team:
						home_skaters.append(s)
					else:
						away_skaters.append(s)

			var radius = 150.0

			for i in range(home_skaters.size()):
				var s = home_skaters[i]
				if i == 0:
					s.initial_position = faceoff_pos + Vector2(-60, 0)
				else:
					var num_arc = max(1, home_skaters.size() - 1)
					var angle = PI / 2.0 + PI * (float(i - 1) / max(1, num_arc - 1))
					s.initial_position = faceoff_pos + Vector2(cos(angle) * radius, sin(angle) * radius)
				s.puck = null
				if "statbook" in s and s.statbook != null:
					s.health = s.statbook.max_health
				if "needs_reset" in s:
					s.needs_reset = false

			for i in range(away_skaters.size()):
				var s = away_skaters[i]
				if i == 0:
					s.initial_position = faceoff_pos + Vector2(60, 0)
				else:
					var num_arc = max(1, away_skaters.size() - 1)
					var angle = -PI / 2.0 + PI * (float(i - 1) / max(1, num_arc - 1))
					s.initial_position = faceoff_pos + Vector2(cos(angle) * radius, sin(angle) * radius)
				s.puck = null
				if "statbook" in s and s.statbook != null:
					s.health = s.statbook.max_health
				if "needs_reset" in s:
					s.needs_reset = false

		Phase.POST_GOAL_SKATE:
			phase_timer = 2.0
			for s in skaters:
				if "anim_state" in s:
					if s.is_out_of_play():
						continue
					s.anim_state = "skating_around"
					if "celebrating" in s:
						s.celebrating = (s.home_team == scoring_team_home)
					if "charging" in s:
						s.charging = false
					if "sprinting" in s:
						s.sprinting = false
					if s.has_method("release_grab"):
						s.release_grab()

		Phase.POST_GOAL_LERP:
			phase_timer = 1.5
			for s in skaters:
				if "anim_state" in s:
					if s.is_out_of_play():
						continue
					s.anim_state = "lerping"
					if "celebrating" in s:
						s.celebrating = (s.home_team == scoring_team_home)
			for p in pucks:
				p.visible = false
				p.freeze = true
				if "colidable" in p:
					p.colidable = false

		Phase.POST_PERIOD_SKATE_OUT:
			phase_timer = 2.5
			if manager and manager.has_method("cancel_delayed_penalty"):
				manager.cancel_delayed_penalty()
			for s in skaters:
				if "anim_state" in s:
					if s.is_out_of_play():
						continue
					s.anim_state = "skating_out"
			($"../../Boards/BoardsCollision").disabled = true
			for p in pucks:
				p.visible = false
				p.freeze = true
				if "colidable" in p:
					p.colidable = false

		Phase.POST_PERIOD_WAIT:
			phase_timer = 2.5

		Phase.PRE_PERIOD_SKATE:
			phase_timer = 4.0
			var circle = true
			for s in skaters:
				if "anim_state" in s:
					if s is Skater and s.is_in_penalty() and s.penalty_time <= 0.0:
						s.finish_expired_penalty()
					if s.is_out_of_play():
						continue
					s.anim_state = "skating_circle" if circle else "skating_figure8"
					circle = not circle

		Phase.PRE_PERIOD_LERP:
			phase_timer = 1.5
			for s in skaters:
				if "anim_state" in s:
					if s is Skater and s.is_in_penalty() and s.penalty_time <= 0.0:
						s.finish_expired_penalty()
					if s.is_out_of_play():
						continue
					s.visible = true
					s.anim_state = "lerping"

		Phase.PRE_PENALTY_SKATE:
			phase_timer = 1.8
			for s in skaters:
				if "anim_state" in s:
					if s.is_out_of_play():
						continue
					s.anim_state = "skating_around"
			for p in pucks:
				p.visible = false
				p.freeze = true
				if "colidable" in p:
					p.colidable = false

		Phase.PRE_PENALTY_LERP:
			phase_timer = 1.2
			for s in skaters:
				if "anim_state" in s:
					if s.is_out_of_play():
						continue
					s.anim_state = "lerping"
			for p in pucks:
				p.visible = false
				p.freeze = true
				if "colidable" in p:
					p.colidable = false

		Phase.FIGHT:
			phase_timer = 0.0

		Phase.INTERMISSION_MITES:
			phase_timer = 0.5
			if manager and manager.has_method("start_mites_intermission"):
				manager.start_mites_intermission()

		Phase.SHOOTOUT_SETUP:
			phase_timer = 1.6
			($"../../Boards/BoardsCollision").disabled = false
			if manager and manager.has_method("setup_shootout_turn"):
				manager.setup_shootout_turn()

		Phase.SHOOTOUT_ACTIVE:
			phase_timer = 0.0
			if manager and manager.has_method("begin_shootout_attempt"):
				manager.begin_shootout_attempt()

		Phase.SHOOTOUT_RESULT:
			phase_timer = 2.0

func on_goal_scored(home_team_scored: bool = true) -> void:
	if current_phase == Phase.PLAYING:
		scoring_team_home = home_team_scored
		set_phase(Phase.POST_GOAL_SKATE)

func on_period_end() -> void:
	if current_phase == Phase.PLAYING:
		set_phase(Phase.POST_PERIOD_SKATE_OUT)

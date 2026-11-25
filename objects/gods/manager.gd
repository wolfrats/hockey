class_name Manager extends Node2D

signal shot(team: bool, position: Vector2, vector: Vector2)

const FAN_SCENE = preload("res://objects/environment/fan.tscn")
const PAUSE_MENU_SCRIPT = preload("res://objects/gods/pause_menu.gd")
const FIGHT_CONTROLLER_SCRIPT = preload("res://objects/gods/fight_controller.gd")
const MITES_CONTROLLER_SCRIPT = preload("res://objects/gods/mites_controller.gd")

@export var is_practice: bool = false
var home_score: int = 0
var away_score: int = 0
var current_period: int = 1

var time_remaining: float = 0.0
var ot_is_3v3: bool = false

var ui_layer: CanvasLayer
var score_label: Label
var timer_label: Label
var period_label: Label
var anim_manager: AnimationManager
var main_camera: Camera2D
var pause_menu: PauseMenu = null
var fight_controller: FightController = null
var mites_controller: MitesController = null

# Power play / status / broadcast banner UI
var pp_panel: PanelContainer = null
var pp_label: Label = null
var toast_panel: PanelContainer = null
var toast_label: Label = null
var toast_timer: float = 0.0
var goal_banner_panel: PanelContainer = null
var goal_banner_title: Label = null
var goal_banner_sub: Label = null
var goal_banner_accent: ColorRect = null

# Delayed penalty state
var delayed_penalty_offender: Skater = null
var delayed_penalty_ref: Referee = null
var delayed_penalty_duration: float = 30.0
var delayed_penalty_pulled_goalie: Goalie = null

# Fight cooldown
var fight_cooldown: float = 10.0

# Shootout state
var shootout_active: bool = false
var shootout_round: int = 1
var shootout_turn_home: bool = true
var shootout_home_goals: int = 0
var shootout_away_goals: int = 0
var shootout_home_results: Array[String] = []
var shootout_away_results: Array[String] = []
var shootout_home_idx: int = 0
var shootout_away_idx: int = 0
var shootout_shooter: Skater = null
var shootout_shot_clock: float = 10.0
var shootout_puck_released_timer: float = 0.0
var shootout_goalie_touched: bool = false
var shootout_panel: PanelContainer = null
var shootout_label: Label = null

# Replay state
var replay_buffer: Array = []
var is_replay: bool = false
var replay_index: int = 0
var replay_label: Label = null
var replay_skip_margin: MarginContainer = null
var replay_skip_container: HBoxContainer = null
var replay_skipped_devices: Dictionary = {}


func _enter_tree() -> void:
	Globals.manager = self


func _ready() -> void:
	main_camera = Camera2D.new()
	add_child(main_camera)
	main_camera.make_current()

	pause_menu = PAUSE_MENU_SCRIPT.new()
	pause_menu.manager = self
	add_child(pause_menu)

	setup_multiplayer()

	var ghosts_node = get_node_or_null("Ghosts")
	if ghosts_node:
		for child in ghosts_node.get_children():
			if child.name.begins_with("Player"):
				var cam = child.get_node_or_null("Camera2D")
				if cam:
					child.remove_child(cam)
					cam.queue_free()

	if not is_practice:
		anim_manager = AnimationManager.new()
		add_child(anim_manager)
		fight_controller = FIGHT_CONTROLLER_SCRIPT.new()
		add_child(fight_controller)
		mites_controller = MITES_CONTROLLER_SCRIPT.new()
		add_child(mites_controller)
		time_remaining = Globals.period_length
		setup_ui()
		Globals.clear_match_stats()
		var lights = %Lights.get_children()
		lights[0].color = StatBook.TEAMS[Globals.home_team_index]["body_color"]
		lights[0].color.v = 1
		lights[1].color = StatBook.TEAMS[Globals.home_team_index]["head_color"]
		lights[1].color.v = 1
		lights[2].color = StatBook.TEAMS[Globals.home_team_index]["foot_color"]
		lights[2].color.v = 1
		var home_logo = StatBook.TEAMS[Globals.home_team_index]["logo"]
		var home_logo_type = StatBook.TEAMS[Globals.home_team_index]["logo_style"]
		var logo_texture = load("res://sprites/logos/Clip {0}.png".format([home_logo]))
		if home_logo_type == 2:
			var logol = get_node_or_null("Logo2L")
			var logor = get_node_or_null("Logo2R")
			if logol:
				logol.visible = true
				logol.texture = logo_texture
			if logor:
				logor.visible = true
				logor.texture = logo_texture
		elif home_logo_type == 1:
			var logoc = get_node_or_null("Logo1C")
			if logoc:
				logoc.visible = true
				logoc.texture = logo_texture

	for y in range(0, 4):
		for x in range(0, 2000, 50):
			var path: int = x + y * 50
			@warning_ignore("integer_division")
			if int(path / 150) % 3 == 0:
				continue
			if not (y == 0 and ((x >= 450 and x <= 660) or (x >= 1350 and x <= 1560))):
				var fan = FAN_SCENE.instantiate()
				add_child(fan)
				fan.global_position = Vector2(x + y * 20, 50 + y * -50)

			if x > 900 and x < 1120 and y == 0:  # no people near penalty box
				continue
			var fan2: Fan = FAN_SCENE.instantiate()
			add_child(fan2)
			fan2.global_position = Vector2(x + y * 20, y * 50 + 1024)
			fan2.scale.y = -1
			fan2.z_index = -y
	for x in range(0, 4):
		for y in range(0, 1024, 50):
			var path: int = y + x * 50
			@warning_ignore("integer_division")
			if int(path / 150) % 3 == 0:
				continue
			var fan = FAN_SCENE.instantiate()
			fan.side = true
			add_child(fan)
			fan.global_position = Vector2(x * -50, y + x * 20)

			var fan2: Fan = FAN_SCENE.instantiate()
			fan2.side = true
			add_child(fan2)
			fan2.global_position = Vector2(x * 50 + 2048, y + x * 20)
			fan2.scale.x = -1


func toggle_pause() -> void:
	if pause_menu == null:
		return
	if pause_menu.visible:
		pause_menu.close_menu()
	else:
		pause_menu.open_menu()


func setup_multiplayer() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_update_players()


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_update_players()


func _update_players() -> void:
	var ghosts_node = get_node_or_null("Ghosts")
	if not ghosts_node:
		return
	var player1 = ghosts_node.get_node_or_null("Player")
	if not player1:
		return

	var active_devices = Globals.player_devices.duplicate()

	if active_devices.size() == 0:
		var joypads = Input.get_connected_joypads()
		for joy_id in joypads:
			if active_devices.size() < 4:
				active_devices.append(joy_id)

		if active_devices.size() == 0:
			active_devices.append(-2)

	var current_players = []
	for child in ghosts_node.get_children():
		if child.name.begins_with("Player"):
			current_players.append(child)

	for i in range(current_players.size(), active_devices.size()):
		var new_player = player1.duplicate()
		new_player.name = "Player" + str(i + 1)

		var cam = new_player.get_node_or_null("Camera2D")
		if cam:
			new_player.remove_child(cam)
			cam.queue_free()

		ghosts_node.add_child(new_player)
		current_players.append(new_player)

	var team1 = get_node_or_null("Team1")
	var team2 = get_node_or_null("Team2")
	var home_skaters = team1.get_children() if team1 else []
	var away_skaters = team2.get_children() if team2 else []

	var home_assigned_count = 0
	var away_assigned_count = 0

	var all_team_skaters = home_skaters + away_skaters
	for child in get_children():
		if child is Goalie:
			all_team_skaters.append(child)

	for skater in all_team_skaters:
		skater.ghost = null

	for i in range(current_players.size()):
		var p = current_players[i]
		if i < active_devices.size():
			p.device_id = active_devices[i]
			p.player_index = i
			p.set_color(Globals.player_colors[i])
			var team_choice = 0
			if i < Globals.player_teams.size():
				team_choice = Globals.player_teams[i]

			if team_choice == 0:
				while home_assigned_count < home_skaters.size() and home_skaters[home_assigned_count].ot_benched:
					home_assigned_count += 1
				if home_assigned_count < home_skaters.size():
					home_skaters[home_assigned_count].ghost = p
					p.skater = home_skaters[home_assigned_count]
					home_assigned_count += 1
			else:
				while away_assigned_count < away_skaters.size() and away_skaters[away_assigned_count].ot_benched:
					away_assigned_count += 1
				if away_assigned_count < away_skaters.size():
					away_skaters[away_assigned_count].ghost = p
					p.skater = away_skaters[away_assigned_count]
					away_assigned_count += 1
		else:
			p.device_id = -1

	if is_replay:
		update_replay_skip_ui()


func get_active_players() -> Array:
	var players: Array = []
	var ghosts_node = get_node_or_null("Ghosts")
	if not ghosts_node:
		return players
	for child in ghosts_node.get_children():
		if child.name.begins_with("Player") and child.device_id != -1:
			players.append(child)
	return players


func _team_has_human(is_home: bool) -> bool:
	var team_target: int = 0 if is_home else 1
	var active_players := get_active_players()
	if active_players.is_empty():
		return false
	for p in active_players:
		var idx: int = p.player_index
		var choice: int = Globals.player_teams[idx] if (idx >= 0 and idx < Globals.player_teams.size()) else 0
		if choice == team_target:
			return true
	return false


func get_team_goalie(is_home: bool) -> Goalie:
	for child in get_children():
		if child is Goalie and child.home_team == is_home:
			return child
	return null


func _get_primary_human_is_home() -> bool:
	if _team_has_human(true):
		return true
	if _team_has_human(false):
		return false
	return true


func is_human_goalie_pulled() -> bool:
	var g := get_team_goalie(_get_primary_human_is_home())
	return g != null and g.pulled


func toggle_human_goalie_pull() -> String:
	var is_home: bool = _get_primary_human_is_home()
	var g := get_team_goalie(is_home)
	if g == null:
		return "Goalie not found."
	if g.pulled:
		g.return_to_net()
		return "Goalie returned to net."
	else:
		g.pull()
		var tname: String = StatBook.TEAMS[Globals.home_team_index if is_home else Globals.away_team_index]["name"]
		show_banner("EMPTY NET! %s pulls the goalie!" % tname, Color(1.0, 0.7, 0.15), 2.5)
		return "Goalie pulled! Extra attacker on ice."


func call_human_line_change() -> int:
	var is_home: bool = _get_primary_human_is_home()
	var team_node := get_node_or_null("Team1" if is_home else "Team2")
	var bench := get_tree().root.get_node_or_null("Rink/HomeBench" if is_home else "Rink/AwayBench")
	if team_node == null:
		return 0
	var count: int = 0
	for child in team_node.get_children():
		if child is Skater and not child.is_out_of_play() and child.puck == null and child.anim_state == "":
			child.start_bench_swap(bench)
			count += 1
	return count


func _check_ai_late_goalie_pull() -> void:
	if current_period != 3 or delayed_penalty_offender != null or shootout_active:
		return
	if time_remaining > 45.0 or time_remaining <= 2.0:
		return

	for is_home in [true, false]:
		if _team_has_human(is_home):
			continue
		var g := get_team_goalie(is_home)
		if g == null:
			continue
		var my_score: int = home_score if is_home else away_score
		var opp_score: int = away_score if is_home else home_score
		var deficit: int = opp_score - my_score
		if deficit >= 1 and deficit <= 2 and not g.pulled:
			g.pull()
			var tname: String = StatBook.TEAMS[Globals.home_team_index if is_home else Globals.away_team_index]["name"]
			show_banner("EMPTY NET! %s pulls the goalie!" % tname, Color(1.0, 0.65, 0.1), 3.0)
		elif (deficit <= 0 or deficit >= 3) and g.pulled:
			g.return_to_net()


# --- Delayed Penalties & Power Play ---

func call_penalty_on_skater(offender: Skater, ref: Referee, duration: float = 30.0) -> void:
	if is_practice or anim_manager == null or anim_manager.current_phase != AnimationManager.Phase.PLAYING:
		return
	if delayed_penalty_offender != null:
		return

	# Check who currently controls the puck
	var offending_has_puck: bool = false
	for p in get_tree().get_nodes_in_group("pucks"):
		if p is Puck and p.posessor != null and p.posessor.home_team == offender.home_team:
			offending_has_puck = true
			break

	if offending_has_puck:
		_enforce_penalty(offender, ref, duration)
	else:
		delayed_penalty_offender = offender
		delayed_penalty_ref = ref
		delayed_penalty_duration = duration
		if ref != null and is_instance_valid(ref):
			ref.set_delayed_penalty_signal(true)
		# Pull non-offending team's goalie for 6v5 advantage during delayed penalty
		var non_offending_home: bool = not offender.home_team
		var g := get_team_goalie(non_offending_home)
		if g != null and not g.pulled:
			g.pull()
			delayed_penalty_pulled_goalie = g
		Globals.play_sound_at("Blip2", offender.global_position, false)
		var off_team: String = StatBook.TEAMS[offender.get_team_index()]["name"]
		show_banner("DELAYED PENALTY on %s (%s)!" % [offender.get_skater_display(), off_team], Color(1.0, 0.78, 0.1), 2.5)


func on_puck_possessed(skater: Skater) -> void:
	if delayed_penalty_offender == null or not is_instance_valid(delayed_penalty_offender):
		delayed_penalty_offender = null
		return
	if skater != null and skater.home_team == delayed_penalty_offender.home_team:
		var offender := delayed_penalty_offender
		var ref := delayed_penalty_ref
		var dur := delayed_penalty_duration
		cancel_delayed_penalty()
		_enforce_penalty(offender, ref, dur)


func cancel_delayed_penalty() -> void:
	if delayed_penalty_ref != null and is_instance_valid(delayed_penalty_ref):
		delayed_penalty_ref.set_delayed_penalty_signal(false)
	if delayed_penalty_pulled_goalie != null and is_instance_valid(delayed_penalty_pulled_goalie) and delayed_penalty_pulled_goalie.pulled:
		delayed_penalty_pulled_goalie.return_to_net()
	delayed_penalty_offender = null
	delayed_penalty_ref = null
	delayed_penalty_pulled_goalie = null


func _enforce_penalty(offender: Skater, ref: Referee, duration: float) -> void:
	if offender == null or not is_instance_valid(offender):
		return
	offender.penalty(duration, false)
	Globals.play_sound_at("Blip1", offender.global_position, false)
	show_banner("PENALTY! %s — 0:%02d in the box" % [offender.get_skater_display(), int(duration)], Color(1.0, 0.35, 0.2), 2.5)
	if anim_manager != null:
		anim_manager.set_phase(AnimationManager.Phase.PRE_PENALTY_SKATE)
	if ref != null and is_instance_valid(ref):
		ref.anim_state = "skate_to"
		ref.target_pos = Vector2(1005.5, 509)


func _release_earliest_minor_penalty(penalized_home_team: bool) -> bool:
	var best: Skater = null
	var min_time: float = INF
	for s in get_tree().get_nodes_in_group("skaters"):
		if s is Skater and s.home_team == penalized_home_team and s.is_in_penalty() and not s.is_major_penalty and s.penalty_time > 0.0:
			if s.penalty_time < min_time:
				min_time = s.penalty_time
				best = s
	if best != null:
		best.release_from_penalty_early()
		return true
	return false


# --- Gloves-Off Fights ---

func try_start_fight(s1: Skater, s2: Skater, total_heat: float, was_grabbing: bool) -> bool:
	if is_practice or anim_manager == null or fight_controller == null:
		return false
	if anim_manager.current_phase != AnimationManager.Phase.PLAYING:
		return false
	if fight_controller.active or fight_cooldown > 0.0 or is_overtime_active() or shootout_active:
		return false
	if s1.is_out_of_play() or s2.is_out_of_play():
		return false

	var human_involved: bool = (s1.ghost != null or s2.ghost != null)
	var trigger: bool = false
	if was_grabbing and total_heat >= 50.0:
		trigger = true
	elif total_heat >= 85.0:
		trigger = true if human_involved else (randf() < 0.45)

	if not trigger:
		return false

	cancel_delayed_penalty()
	anim_manager.set_phase(AnimationManager.Phase.FIGHT)
	fight_controller.start_fight(s1, s2, self)
	return true


# --- Overtime & Shootout ---

func is_overtime_active() -> bool:
	return current_period >= 4 and not shootout_active


func is_overtime_3v3() -> bool:
	return current_period >= 4 and ot_is_3v3 and not shootout_active


func is_shootout_active() -> bool:
	return shootout_active


func get_period_duration(period_num: int) -> float:
	if period_num >= 4 and ot_is_3v3:
		return clampf(Globals.period_length * 0.5, 45.0, 90.0)
	return Globals.period_length


func get_next_tiebreaker_action() -> String:
	if Season.is_playoff_match():
		return "start_playoff_ot"
	var effective_ot_mode: int = 2 if Season.season_on else Globals.ot_mode
	if effective_ot_mode == 0:
		return "finish_tie"
	if current_period == 3:
		return "start_3v3_ot"
	if effective_ot_mode == 2:
		return "start_shootout"
	return "finish_ot_tie"


func prepare_overtime(use_3v3: bool) -> void:
	ot_is_3v3 = use_3v3
	if use_3v3:
		for team_name in ["Team1", "Team2"]:
			var team_node := get_node_or_null(team_name)
			if team_node:
				var children := team_node.get_children()
				for i in range(children.size()):
					if children[i] is Skater:
						children[i].set_ot_benched(i >= 3)
		_ensure_players_on_active_skaters()
		show_banner("SUDDEN DEATH OVERTIME (3v3)!", Color(0.95, 0.3, 0.2), 3.5)
	else:
		show_banner("PLAYOFF SUDDEN DEATH OVERTIME!", Color(1.0, 0.8, 0.15), 3.5)


func _ensure_players_on_active_skaters() -> void:
	for p in get_active_players():
		if p.skater is Skater and p.skater.ot_benched:
			var team_node := get_node_or_null("Team1" if p.skater.home_team else "Team2")
			p.skater.ghost = null
			p.skater = null
			if team_node:
				for s in team_node.get_children():
					if s is Skater and not s.ot_benched and s.ghost == null:
						s.ghost = p
						p.skater = s
						break


func start_shootout() -> void:
	shootout_active = true
	shootout_round = 1
	shootout_turn_home = true
	shootout_home_goals = 0
	shootout_away_goals = 0
	shootout_home_results.clear()
	shootout_away_results.clear()
	shootout_home_idx = 0
	shootout_away_idx = 0
	cancel_delayed_penalty()
	if anim_manager:
		anim_manager.set_phase(AnimationManager.Phase.SHOOTOUT_SETUP)


func setup_shootout_turn() -> void:
	# Hide referees during shootout
	for ref in get_tree().get_nodes_in_group("referees"):
		if ref.has_method("set_shootout_hidden"):
			ref.set_shootout_hidden(true)

	# Return goalies to net
	for child in get_children():
		if child is Goalie:
			if child.pulled:
				child.return_to_net()
			child.home()

	# Pick active shooter
	var team_node := get_node_or_null("Team1" if shootout_turn_home else "Team2")
	var chosen: Skater = null
	if team_node and team_node.get_child_count() > 0:
		var idx: int = (shootout_home_idx if shootout_turn_home else shootout_away_idx) % team_node.get_child_count()
		chosen = team_node.get_child(idx) as Skater
		if shootout_turn_home:
			shootout_home_idx += 1
		else:
			shootout_away_idx += 1

	shootout_shooter = chosen
	shootout_shot_clock = 10.0
	shootout_puck_released_timer = 0.0
	shootout_goalie_touched = false

	# Bench everyone except chosen shooter
	for s in get_tree().get_nodes_in_group("skaters"):
		if s is Skater:
			s.ghost = null
			if s == chosen:
				s.set_ot_benched(false)
				s.home()
				s.initial_position = Vector2(1005.5, 509.0)
				s.global_position = Vector2(1005.5, 509.0)
				s.facing_dir = Vector2(1.0, 0.0) if s.home_team else Vector2(-1.0, 0.0)
				s.anim_state = "lerping"
			else:
				s.set_ot_benched(true)

	# Assign human player ghosts to shooter / goalie
	var assigned_shooter: bool = false
	var def_goalie := get_team_goalie(not shootout_turn_home)
	if def_goalie:
		def_goalie.ghost = null
	for p in get_active_players():
		p.skater = null
		var idx: int = p.player_index
		var choice: int = Globals.player_teams[idx] if (idx >= 0 and idx < Globals.player_teams.size()) else 0
		var player_is_home: bool = (choice == 0)
		if player_is_home == shootout_turn_home and not assigned_shooter and chosen != null:
			chosen.ghost = p
			p.skater = chosen
			assigned_shooter = true
		elif player_is_home != shootout_turn_home and Globals.allow_goalie_control and def_goalie != null and def_goalie.ghost == null:
			def_goalie.ghost = p
			p.skater = def_goalie

	# Place puck at center ice
	for p in get_tree().get_nodes_in_group("pucks"):
		if p is Puck:
			p.home()
			p.visible = true
			p.freeze = true
			p.colidable = true
			p.global_position = Vector2(1005.5, 509.0)

	_update_shootout_ui()
	if chosen != null:
		var tname: String = StatBook.TEAMS[chosen.get_team_index()]["name"]
		show_banner("SHOOTOUT RD %d: %s (%s)" % [shootout_round, chosen.get_skater_display(), tname], chosen.get_jersey_color(), 1.6)


func begin_shootout_attempt() -> void:
	if shootout_shooter != null and is_instance_valid(shootout_shooter):
		shootout_shooter.anim_state = ""
		shootout_shooter.needs_reset = false
		for p in get_tree().get_nodes_in_group("pucks"):
			if p is Puck:
				p.freeze = false
				p.assign_possessor(shootout_shooter)
				break
	Globals.play_sound_at("Blip2", Vector2(1005.5, 509.0), false)


func on_shootout_goalie_touch(goalie: Goalie) -> void:
	if anim_manager == null or anim_manager.current_phase != AnimationManager.Phase.SHOOTOUT_ACTIVE:
		return
	if shootout_shooter != null and goalie.home_team != shootout_shooter.home_team:
		shootout_goalie_touched = true


func on_shootout_goal(goal_name: String) -> void:
	if anim_manager == null or anim_manager.current_phase != AnimationManager.Phase.SHOOTOUT_ACTIVE:
		return
	var valid_goal: bool = (shootout_turn_home and goal_name == "AwayGoal") or (not shootout_turn_home and goal_name == "HomeGoal")
	conclude_shootout_attempt(valid_goal)


func step_shootout(delta: float) -> void:
	shootout_shot_clock -= delta
	if shootout_shot_clock <= 0.0:
		conclude_shootout_attempt(false)
		return

	var puck_node: Puck = null
	for p in get_tree().get_nodes_in_group("pucks"):
		if p is Puck:
			puck_node = p
			break
	if puck_node == null:
		return

	if puck_node.posessor != shootout_shooter:
		shootout_puck_released_timer += delta
		if shootout_goalie_touched and shootout_puck_released_timer > 0.35:
			conclude_shootout_attempt(false)
			return
		# Puck went wide past goal line or stopped moving
		if shootout_turn_home and puck_node.global_position.x > 1750.0 and shootout_puck_released_timer > 0.25:
			conclude_shootout_attempt(false)
			return
		if not shootout_turn_home and puck_node.global_position.x < 260.0 and shootout_puck_released_timer > 0.25:
			conclude_shootout_attempt(false)
			return
		if shootout_puck_released_timer > 1.8:
			conclude_shootout_attempt(false)
			return


func conclude_shootout_attempt(scored: bool) -> void:
	if anim_manager == null or anim_manager.current_phase != AnimationManager.Phase.SHOOTOUT_ACTIVE:
		return
	if scored:
		if shootout_turn_home:
			shootout_home_goals += 1
			shootout_home_results.append("O")
			Globals.play_sound_at("GoalHome", global_position, false)
		else:
			shootout_away_goals += 1
			shootout_away_results.append("O")
			Globals.play_sound_at("GoalAway", global_position, false)
		if shootout_shooter != null and is_instance_valid(shootout_shooter):
			shootout_shooter.celebrating = true
			shootout_shooter.anim_state = "skating_around"
		show_banner("SHOOTOUT GOAL!", Color(0.2, 0.9, 0.3), 2.0)
	else:
		if shootout_turn_home:
			shootout_home_results.append("X")
		else:
			shootout_away_results.append("X")
		Globals.play_sound_at("Blip1", global_position, false)
		show_banner("SAVED!" if shootout_goalie_touched else "NO GOAL!", Color(0.95, 0.35, 0.25), 2.0)

	for p in get_tree().get_nodes_in_group("pucks"):
		if p is Puck:
			p.freeze = true
			p.colidable = false

	_update_shootout_ui()
	anim_manager.set_phase(AnimationManager.Phase.SHOOTOUT_RESULT)


func advance_shootout_turn() -> void:
	var h_taken: int = shootout_home_results.size()
	var a_taken: int = shootout_away_results.size()
	var clinched: bool = false

	if shootout_round <= 3:
		var h_rem: int = 3 - h_taken
		var a_rem: int = 3 - a_taken
		if shootout_home_goals > shootout_away_goals + a_rem:
			clinched = true
		elif shootout_away_goals > shootout_home_goals + h_rem:
			clinched = true
		elif h_taken == 3 and a_taken == 3 and shootout_home_goals != shootout_away_goals:
			clinched = true
	else:
		if h_taken == a_taken and shootout_home_goals != shootout_away_goals:
			clinched = true

	if clinched:
		if shootout_home_goals > shootout_away_goals:
			home_score += 1
		else:
			away_score += 1
		Globals.match_ended_in = "SO"
		Globals.match_shootout_home = shootout_home_goals
		Globals.match_shootout_away = shootout_away_goals
		finish_match()
		return

	if shootout_turn_home:
		shootout_turn_home = false
	else:
		shootout_turn_home = true
		shootout_round += 1

	if anim_manager:
		anim_manager.set_phase(AnimationManager.Phase.SHOOTOUT_SETUP)


func _update_shootout_ui() -> void:
	if shootout_panel == null or shootout_label == null:
		return
	shootout_panel.visible = shootout_active
	if not shootout_active:
		return
	var h_name: String = StatBook.TEAMS[Globals.home_team_index]["name"]
	var a_name: String = StatBook.TEAMS[Globals.away_team_index]["name"]
	var h_marks: String = " ".join(shootout_home_results)
	var a_marks: String = " ".join(shootout_away_results)
	var total_slots: int = max(3, shootout_round)
	for _i in range(shootout_home_results.size(), total_slots):
		h_marks = (h_marks + " -").strip_edges()
	for _i in range(shootout_away_results.size(), total_slots):
		a_marks = (a_marks + " -").strip_edges()
	shootout_label.text = "SHOOTOUT — ROUND %d\n%s: %s (%d)   |   %s: %s (%d)" % [
		shootout_round, h_name, h_marks, shootout_home_goals, a_name, a_marks, shootout_away_goals
	]


func finish_match() -> void:
	stop_mites_intermission()
	cancel_delayed_penalty()
	Globals.match_home_score = home_score
	Globals.match_away_score = away_score
	get_tree().change_scene_to_file("res://menu/score_recap.tscn")


func start_mites_intermission() -> void:
	if mites_controller == null:
		return
	# Hide regular skaters, goalies, referee, and outer nets during Mites on Ice
	for s in get_tree().get_nodes_in_group("skaters"):
		if s is Skater and not s.is_in_penalty():
			s.visible = false
	for child in get_children():
		if child is Goalie:
			child.visible = false
	for ref in get_tree().get_nodes_in_group("referees"):
		ref.visible = false
	for net_name in ["Node", "Node2"]:
		var net := get_node_or_null(net_name)
		if net != null:
			net.visible = false
	mites_controller.start_mites(self)


func stop_mites_intermission() -> void:
	if mites_controller != null:
		mites_controller.stop_mites()
	for s in get_tree().get_nodes_in_group("skaters"):
		if s is Skater and not s.ot_benched:
			s.visible = true
	for child in get_children():
		if child is Goalie and not child.pulled:
			child.visible = true
	for ref in get_tree().get_nodes_in_group("referees"):
		ref.visible = true
	for net_name in ["Node", "Node2"]:
		var net := get_node_or_null(net_name)
		if net != null:
			net.visible = true


func _process(delta: float) -> void:
	if not is_practice:
		if fight_cooldown > 0.0 and anim_manager.current_phase == AnimationManager.Phase.PLAYING:
			fight_cooldown = maxf(0.0, fight_cooldown - delta)

		if toast_timer > 0.0:
			toast_timer -= delta
			if toast_timer <= 0.0 and toast_panel:
				toast_panel.visible = false

		if anim_manager.current_phase == AnimationManager.Phase.PLAYING:
			if time_remaining > 0.0:
				time_remaining -= delta
				if time_remaining <= 0.0:
					time_remaining = 0.0
					anim_manager.on_period_end()
			_check_ai_late_goalie_pull()

		update_ui()

	# Update Camera Position & Zoom
	if main_camera:
		var target_pos = Vector2.ZERO
		var target_zoom = Vector2.ONE

		if fight_controller != null and fight_controller.active:
			target_pos = fight_controller.center_pos
			target_zoom = Vector2(1.25, 1.25)
		elif anim_manager != null and (
			anim_manager.current_phase == AnimationManager.Phase.POST_PERIOD_SKATE_OUT
			or anim_manager.current_phase == AnimationManager.Phase.POST_PERIOD_WAIT
			or anim_manager.current_phase == AnimationManager.Phase.INTERMISSION_MITES
			or anim_manager.current_phase == AnimationManager.Phase.PRE_PERIOD_SKATE
			or anim_manager.current_phase == AnimationManager.Phase.PRE_PERIOD_LERP
		):
			target_pos = Vector2(1005.5, 509.0)
		elif shootout_active and shootout_shooter != null and is_instance_valid(shootout_shooter):
			var goal_x: float = 1710.0 if shootout_turn_home else 301.0
			target_pos = shootout_shooter.global_position.lerp(Vector2(goal_x, 509.0), 0.3)
		else:
			var target_count = 0
			var team1 = get_node_or_null("Team1")
			var team2 = get_node_or_null("Team2")
			var all_skaters = []
			if team1:
				all_skaters += team1.get_children()
			if team2:
				all_skaters += team2.get_children()
			for child in get_children():
				if child is Goalie:
					all_skaters.append(child)

			for skater in all_skaters:
				if skater.ghost != null:
					target_pos += skater.global_position
					target_count += 1
			if target_count > 0:
				target_pos /= target_count
			target_count = 1
			var pucks_node = get_node_or_null("Pucks")
			if pucks_node:
				for puck in pucks_node.get_children():
					if puck is Puck:
						target_pos += puck.global_position
						target_count += 1
						break

			if target_count > 0:
				target_pos /= target_count
				if anim_manager:
					var phase = anim_manager.current_phase
					if phase == AnimationManager.Phase.POST_PERIOD_SKATE_OUT \
							or phase == AnimationManager.Phase.POST_PERIOD_WAIT:
						target_pos = Vector2(1005.5, 509)

		main_camera.global_position = main_camera.global_position.lerp(target_pos, 5.0 * delta)
		main_camera.zoom = main_camera.zoom.lerp(target_zoom, 4.0 * delta)


func start_replay() -> void:
	is_replay = true
	replay_index = 0
	replay_skipped_devices.clear()
	for s in get_tree().get_nodes_in_group("skaters"):
		if s is Skater:
			s.replay_grab_target = null
	if ui_layer and not replay_label:
		replay_label = Label.new()
		replay_label.text = "REPLAY"
		replay_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
		replay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		replay_label.add_theme_font_size_override("font_size", 48)
		replay_label.label_settings = LabelSettings.new()
		replay_label.label_settings.outline_size = 6
		replay_label.label_settings.font_size = 64
		replay_label.label_settings.outline_color = Color.BLACK
		replay_label.label_settings.font_color = Color.RED
		replay_label.position = Vector2(0, 100)
		ui_layer.add_child(replay_label)
	if ui_layer and not replay_skip_margin:
		replay_skip_margin = MarginContainer.new()
		replay_skip_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		replay_skip_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		replay_skip_margin.add_theme_constant_override("margin_left", 24)
		replay_skip_margin.add_theme_constant_override("margin_top", 24)
		replay_skip_margin.add_theme_constant_override("margin_right", 24)
		replay_skip_margin.add_theme_constant_override("margin_bottom", 24)
		ui_layer.add_child(replay_skip_margin)

		replay_skip_container = HBoxContainer.new()
		replay_skip_container.size_flags_horizontal = Control.SIZE_SHRINK_END
		replay_skip_container.size_flags_vertical = Control.SIZE_SHRINK_END
		replay_skip_container.alignment = BoxContainer.ALIGNMENT_END
		replay_skip_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		replay_skip_container.add_theme_constant_override("separation", 12)
		replay_skip_margin.add_child(replay_skip_container)
	update_replay_skip_ui()


func mark_player_replay_skip(device_id: int) -> bool:
	if not is_replay:
		return false
	var found := false
	for p in get_active_players():
		if p.device_id == device_id:
			found = true
			break
	if not found:
		return false
	if not replay_skipped_devices.get(device_id, false):
		replay_skipped_devices[device_id] = true
		update_replay_skip_ui()
	return are_all_players_skipping_replay()


func are_all_players_skipping_replay() -> bool:
	var active_players := get_active_players()
	if active_players.is_empty():
		return true
	for p in active_players:
		if not replay_skipped_devices.get(p.device_id, false):
			return false
	return true


func update_replay_skip_ui() -> void:
	if not replay_skip_container:
		return
	for child in replay_skip_container.get_children():
		replay_skip_container.remove_child(child)
		child.queue_free()
	for p in get_active_players():
		if replay_skipped_devices.get(p.device_id, false):
			continue
		var player_color := Color.WHITE
		if p.player_index >= 0 and p.player_index < Globals.player_colors.size():
			player_color = Globals.player_colors[p.player_index]
		var circle := Panel.new()
		circle.custom_minimum_size = Vector2(36, 36)
		circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = player_color
		style.set_corner_radius_all(18)
		style.corner_detail = 16
		style.border_color = Color.BLACK
		style.set_border_width_all(3)
		style.anti_aliasing = true
		circle.add_theme_stylebox_override("panel", style)
		replay_skip_container.add_child(circle)


func stop_replay() -> void:
	is_replay = false
	replay_skipped_devices.clear()
	for p in get_tree().get_nodes_in_group("pucks"):
		if "replay_possessed" in p:
			p.replay_possessed = false
	for s in get_tree().get_nodes_in_group("skaters"):
		if s is Skater:
			s.replay_grab_target = null
			s.apply_active_appearance()
	if replay_label:
		replay_label.queue_free()
		replay_label = null
	if replay_skip_margin:
		replay_skip_margin.queue_free()
		replay_skip_margin = null
		replay_skip_container = null


func _physics_process(_delta: float) -> void:
	if not is_replay:
		var frame_data = {}

		var skaters = get_tree().get_nodes_in_group("skaters")
		var referees = get_tree().get_nodes_in_group("referees")
		var all_skaters = skaters + referees
		for s in all_skaters:
			var sprite = s.get_node_or_null("Sprite")
			if sprite:
				var entry = {
					"type": "skater",
					"position": s.global_position,
					"rotation": s.rotation,
					"z_index": s.z_index,
					"texture": sprite.texture,
					"sprite_pos": sprite.position,
					"region_rect": sprite.region_rect,
					"flip_h": sprite.flip_h,
					"modulate": sprite.modulate
				}
				if s is Skater:
					entry["anim_name"] = s.current_anim_name
					var grabbed: Skater = s.get_grabbed_skater()
					entry["grabbed_id"] = grabbed.get_instance_id() if grabbed else 0
					if sprite.material is ShaderMaterial:
						var mat: ShaderMaterial = sprite.material
						entry["draw_logo"] = mat.get_shader_parameter("draw_logo")
						entry["draw_number"] = mat.get_shader_parameter("draw_number")
						entry["logo_pos"] = mat.get_shader_parameter("logo_pos")
						entry["logo_offset_x"] = mat.get_shader_parameter("logo_offset_x")
						entry["overlay_rotation"] = mat.get_shader_parameter("overlay_rotation")
						entry["overlay_flip_x"] = mat.get_shader_parameter("overlay_flip_x")
						entry["replace_skin"] = mat.get_shader_parameter("replace_skin")
						entry["replace_nose"] = mat.get_shader_parameter("replace_nose")
						entry["replace_eye"] = mat.get_shader_parameter("replace_eye")
						entry["number_tex"] = mat.get_shader_parameter("number_tex")
				frame_data[s.get_instance_id()] = entry

		var pucks = get_tree().get_nodes_in_group("pucks")
		for p in pucks:
			frame_data[p.get_instance_id()] = {
				"type": "puck",
				"position": p.global_position,
				"rotation": p.rotation,
				"visible": p.visible,
				"possessed": p.posessor != null
			}

		replay_buffer.append(frame_data)
		if replay_buffer.size() > 600:
			replay_buffer.pop_front()
	else:
		if replay_buffer.size() > 0:
			var frame_data = replay_buffer[replay_index]
			for id in frame_data:
				var node = instance_from_id(id)
				if node:
					var data = frame_data[id]
					if data["type"] == "skater":
						node.global_position = data["position"]
						node.rotation = data["rotation"]
						node.z_index = data["z_index"]
						var sprite = node.get_node_or_null("Sprite")
						if sprite:
							sprite.texture = data["texture"]
							sprite.position = data["sprite_pos"]
							sprite.region_rect = data["region_rect"]
							sprite.flip_h = data["flip_h"]
							sprite.modulate = data["modulate"]
							if node is Skater:
								node.current_anim_name = data.get("anim_name", "Skate Left")
								var grabbed_id: int = data.get("grabbed_id", 0)
								var grab_target = instance_from_id(grabbed_id) if grabbed_id != 0 else null
								if grab_target != null and is_instance_valid(grab_target) and grab_target is Skater:
									node.replay_grab_target = grab_target
								else:
									node.replay_grab_target = null
								if sprite.material is ShaderMaterial:
									var mat: ShaderMaterial = sprite.material
									mat.set("shader_parameter/draw_logo", data.get("draw_logo", false))
									mat.set("shader_parameter/draw_number", data.get("draw_number", false))
									mat.set("shader_parameter/logo_pos", data.get("logo_pos", Vector2.ZERO))
									mat.set("shader_parameter/logo_offset_x", data.get("logo_offset_x", 0.0))
									mat.set("shader_parameter/overlay_rotation", data.get("overlay_rotation", 0.0))
									mat.set("shader_parameter/overlay_flip_x", data.get("overlay_flip_x", false))
									if data.has("replace_skin"):
										mat.set("shader_parameter/replace_skin", data["replace_skin"])
									if data.has("replace_nose"):
										mat.set("shader_parameter/replace_nose", data["replace_nose"])
									if data.has("replace_eye"):
										mat.set("shader_parameter/replace_eye", data["replace_eye"])
									if data.has("number_tex"):
										mat.set("shader_parameter/number_tex", data["number_tex"])
					elif data["type"] == "puck":
						if node.posessor:
							node.posessor.puck = null
						node.posessor = null
						node.replay_possessed = data.get("possessed", false)
						node.global_position = data["position"]
						node.rotation = data["rotation"]
						node.visible = data["visible"]

			replay_index += 1
			if replay_index >= replay_buffer.size():
				replay_index = 0


func setup_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	score_label = Label.new()
	score_label.text = "0 - 0"
	score_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 48)
	score_label.label_settings = LabelSettings.new()
	score_label.label_settings.outline_size = 6
	score_label.label_settings.font_size = 64
	score_label.label_settings.outline_color = Color.BLACK
	ui_layer.add_child(score_label)

	period_label = Label.new()
	period_label.text = "Period 1"
	period_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	period_label.add_theme_font_size_override("font_size", 32)
	period_label.position = Vector2(20, 20)
	period_label.label_settings = LabelSettings.new()
	period_label.label_settings.outline_size = 6
	period_label.label_settings.font_size = 32
	period_label.label_settings.outline_color = Color.BLACK
	ui_layer.add_child(period_label)

	timer_label = Label.new()
	timer_label.text = "2:00"
	timer_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	timer_label.add_theme_font_size_override("font_size", 32)
	timer_label.label_settings = period_label.label_settings
	timer_label.position = Vector2(-20, 20)
	timer_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ui_layer.add_child(timer_label)

	# Power Play / Delayed Penalty / Momentum Pill under scoreboard
	pp_panel = PanelContainer.new()
	pp_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	pp_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pp_panel.position = Vector2(0, 76)
	pp_panel.visible = false
	pp_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pp_style := StyleBoxFlat.new()
	pp_style.bg_color = Color(0.1, 0.1, 0.14, 0.88)
	pp_style.border_color = Color(1.0, 0.8, 0.15)
	pp_style.set_border_width_all(2)
	pp_style.set_corner_radius_all(8)
	pp_style.content_margin_left = 16
	pp_style.content_margin_right = 16
	pp_style.content_margin_top = 4
	pp_style.content_margin_bottom = 4
	pp_panel.add_theme_stylebox_override("panel", pp_style)
	ui_layer.add_child(pp_panel)

	pp_label = Label.new()
	pp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pp_label.add_theme_font_size_override("font_size", 22)
	pp_panel.add_child(pp_label)

	# Shootout Scoreboard Panel
	shootout_panel = PanelContainer.new()
	shootout_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	shootout_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	shootout_panel.position = Vector2(0, 76)
	shootout_panel.visible = false
	shootout_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var so_style := StyleBoxFlat.new()
	so_style.bg_color = Color(0.08, 0.10, 0.16, 0.9)
	so_style.border_color = Color(0.95, 0.85, 0.25)
	so_style.set_border_width_all(2)
	so_style.set_corner_radius_all(8)
	so_style.content_margin_left = 20
	so_style.content_margin_right = 20
	so_style.content_margin_top = 6
	so_style.content_margin_bottom = 6
	shootout_panel.add_theme_stylebox_override("panel", so_style)
	ui_layer.add_child(shootout_panel)

	shootout_label = Label.new()
	shootout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shootout_label.add_theme_font_size_override("font_size", 20)
	shootout_panel.add_child(shootout_label)

	# Event Toast Banner
	toast_panel = PanelContainer.new()
	toast_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_panel.position = Vector2(0, 126)
	toast_panel.visible = false
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t_style := StyleBoxFlat.new()
	t_style.bg_color = Color(0.08, 0.09, 0.13, 0.9)
	t_style.border_color = Color.WHITE
	t_style.set_border_width_all(2)
	t_style.set_corner_radius_all(8)
	t_style.content_margin_left = 18
	t_style.content_margin_right = 18
	t_style.content_margin_top = 6
	t_style.content_margin_bottom = 6
	toast_panel.add_theme_stylebox_override("panel", t_style)
	ui_layer.add_child(toast_panel)

	toast_label = Label.new()
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 22)
	toast_panel.add_child(toast_label)

	# Broadcast Goal Banner (Bottom Center)
	goal_banner_panel = PanelContainer.new()
	goal_banner_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	goal_banner_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	goal_banner_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	goal_banner_panel.position = Vector2(0, -24)
	goal_banner_panel.visible = false
	goal_banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gb_style := StyleBoxFlat.new()
	gb_style.bg_color = Color(0.07, 0.09, 0.14, 0.92)
	gb_style.border_color = Color(0.92, 0.92, 0.95)
	gb_style.set_border_width_all(3)
	gb_style.set_corner_radius_all(10)
	gb_style.content_margin_left = 16
	gb_style.content_margin_right = 24
	gb_style.content_margin_top = 10
	gb_style.content_margin_bottom = 10
	goal_banner_panel.add_theme_stylebox_override("panel", gb_style)
	ui_layer.add_child(goal_banner_panel)

	var gb_hbox := HBoxContainer.new()
	gb_hbox.add_theme_constant_override("separation", 14)
	goal_banner_panel.add_child(gb_hbox)

	goal_banner_accent = ColorRect.new()
	goal_banner_accent.custom_minimum_size = Vector2(12, 54)
	goal_banner_accent.color = Color.GOLD
	gb_hbox.add_child(goal_banner_accent)

	var gb_vbox := VBoxContainer.new()
	gb_vbox.add_theme_constant_override("separation", 2)
	gb_hbox.add_child(gb_vbox)

	goal_banner_title = Label.new()
	goal_banner_title.add_theme_font_size_override("font_size", 28)
	goal_banner_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.25))
	gb_vbox.add_child(goal_banner_title)

	goal_banner_sub = Label.new()
	goal_banner_sub.add_theme_font_size_override("font_size", 20)
	goal_banner_sub.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
	gb_vbox.add_child(goal_banner_sub)


func show_banner(text: String, accent_color: Color = Color.GOLD, duration: float = 2.5) -> void:
	if toast_panel == null or toast_label == null:
		return
	toast_label.text = text
	var style: StyleBoxFlat = toast_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		style.border_color = accent_color
	toast_panel.visible = true
	toast_timer = duration


func show_goal_banner(team_home: bool, scorer_info: Dictionary, assist_info: Dictionary, tag: String = "") -> void:
	if goal_banner_panel == null:
		return
	var team_idx: int = Globals.home_team_index if team_home else Globals.away_team_index
	var team_data: Dictionary = StatBook.TEAMS[team_idx]
	var team_name: String = str(team_data["name"])
	var team_col: Color = team_data["body_color"] if team_home else team_data.get("away_foot_color", team_data["body_color"])

	goal_banner_accent.color = team_col
	goal_banner_title.text = ("GOAL! %s  —  %s" % [team_name, tag]) if tag != "" else ("GOAL! %s" % team_name)

	var scorer_str: String = "Team Goal"
	if not scorer_info.is_empty():
		var snum: int = int(scorer_info.get("number", 0))
		var sname: String = str(scorer_info.get("name", ""))
		scorer_str = "#%d %s" % [snum, sname] if snum > 0 else sname

	var assist_str: String = "Unassisted"
	if not assist_info.is_empty():
		var anum: int = int(assist_info.get("number", 0))
		var aname: String = str(assist_info.get("name", ""))
		if aname != "":
			assist_str = "Assist: #%d %s" % [anum, aname] if anum > 0 else ("Assist: %s" % aname)

	goal_banner_sub.text = "%s   |   %s" % [scorer_str, assist_str]
	goal_banner_panel.visible = true


func hide_goal_banner() -> void:
	if goal_banner_panel != null:
		goal_banner_panel.visible = false


func _update_power_play_hud() -> void:
	if pp_panel == null or pp_label == null:
		return
	if shootout_active:
		pp_panel.visible = false
		return

	if delayed_penalty_offender != null and is_instance_valid(delayed_penalty_offender):
		var adv_team: String = StatBook.TEAMS[Globals.away_team_index if delayed_penalty_offender.home_team else Globals.home_team_index]["name"]
		pp_label.text = "DELAYED PENALTY  |  %s 6v5" % adv_team
		var style: StyleBoxFlat = pp_panel.get_theme_stylebox("panel") as StyleBoxFlat
		if style:
			style.border_color = Color(1.0, 0.8, 0.1)
		pp_panel.visible = true
		return

	var home_active: int = 0
	var away_active: int = 0
	var home_min_pen: float = INF
	var away_min_pen: float = INF
	var boost_team: int = -1 # 0=home, 1=away
	var boost_max: float = 0.0

	for s in get_tree().get_nodes_in_group("skaters"):
		if not (s is Skater) or s.ot_benched:
			continue
		if s.is_in_penalty() and s.penalty_time > 0.0:
			if s.home_team:
				home_min_pen = minf(home_min_pen, s.penalty_time)
			else:
				away_min_pen = minf(away_min_pen, s.penalty_time)
		else:
			if s.home_team:
				home_active += 1
			else:
				away_active += 1
		if s.morale_boost_timer > boost_max:
			boost_max = s.morale_boost_timer
			boost_team = 0 if s.home_team else 1

	var style: StyleBoxFlat = pp_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if home_active > away_active and away_min_pen < INF:
		var secs: int = int(ceil(away_min_pen))
		var hname: String = StatBook.TEAMS[Globals.home_team_index]["name"]
		pp_label.text = "%s PP  %dv%d  0:%02d" % [hname, home_active, away_active, secs]
		if style:
			style.border_color = Globals.home_color
		pp_panel.visible = true
	elif away_active > home_active and home_min_pen < INF:
		var secs: int = int(ceil(home_min_pen))
		var aname: String = StatBook.TEAMS[Globals.away_team_index]["name"]
		pp_label.text = "%s PP  %dv%d  0:%02d" % [aname, away_active, home_active, secs]
		if style:
			style.border_color = Globals.away_color
		pp_panel.visible = true
	elif home_min_pen < INF and away_min_pen < INF:
		var secs: int = int(ceil(minf(home_min_pen, away_min_pen)))
		pp_label.text = "%dv%d  0:%02d" % [home_active, away_active, secs]
		if style:
			style.border_color = Color(0.85, 0.85, 0.9)
		pp_panel.visible = true
	elif boost_max > 0.0 and boost_team != -1:
		var bname: String = StatBook.TEAMS[Globals.home_team_index if boost_team == 0 else Globals.away_team_index]["name"]
		pp_label.text = "MOMENTUM BOOST: %s  0:%02d" % [bname, int(ceil(boost_max))]
		if style:
			style.border_color = Color(1.0, 0.85, 0.2)
		pp_panel.visible = true
	else:
		pp_panel.visible = false


func update_ui() -> void:
	score_label.text = "%d - %d" % [home_score, away_score]
	if shootout_active:
		period_label.text = "SHOOTOUT"
		timer_label.text = "0:%02d" % maxi(0, int(ceil(shootout_shot_clock)))
	elif anim_manager != null and anim_manager.current_phase == AnimationManager.Phase.INTERMISSION_MITES:
		period_label.text = "1st Intermission"
		timer_label.text = "MITES"
	elif current_period == 4:
		period_label.text = "OT (3v3)" if ot_is_3v3 else "OT"
		var mins = int(time_remaining / 60)
		var secs = int(time_remaining) % 60
		timer_label.text = "%d:%02d" % [mins, secs]
	elif current_period > 4:
		period_label.text = "OT %d" % (current_period - 3)
		var mins = int(time_remaining / 60)
		var secs = int(time_remaining) % 60
		timer_label.text = "%d:%02d" % [mins, secs]
	else:
		period_label.text = "Period %d" % current_period
		var mins = int(time_remaining / 60)
		var secs = int(time_remaining) % 60
		timer_label.text = "%d:%02d" % [mins, secs]

	_update_power_play_hud()


func goal_scored(goal_name: String, scorer: String = "", assister: String = "", scorer_info: Dictionary = {}, assist_info: Dictionary = {}) -> void:
	if anim_manager.current_phase != AnimationManager.Phase.PLAYING:
		return
	var scoring_team_is_home: bool = (goal_name == "AwayGoal")
	if goal_name == "HomeGoal":
		away_score += 1
		Globals.play_sound_at("GoalAway", global_position, false)
	elif goal_name == "AwayGoal":
		home_score += 1
		Globals.play_sound_at("GoalHome", global_position, false)

	var banner_tag: String = ""

	# Check if scored during a delayed penalty (cancels the pending penalty!)
	if delayed_penalty_offender != null and is_instance_valid(delayed_penalty_offender):
		if delayed_penalty_offender.home_team != scoring_team_is_home:
			banner_tag = "DELAYED PENALTY GOAL!"
		cancel_delayed_penalty()

	# Check Power Play Goal -> release earliest minor penalty on defending team
	var score_active: int = 0
	var def_active: int = 0
	for s in get_tree().get_nodes_in_group("skaters"):
		if s is Skater and not s.ot_benched and not s.is_in_penalty():
			if s.home_team == scoring_team_is_home:
				score_active += 1
			else:
				def_active += 1
	if score_active > def_active:
		if _release_earliest_minor_penalty(not scoring_team_is_home):
			banner_tag = "POWER PLAY GOAL!"

	if is_overtime_active():
		banner_tag = "OVERTIME WINNER!"

	if scorer != "":
		if not Globals.scorer_stats.has(scorer):
			Globals.scorer_stats[scorer] = 0
		Globals.scorer_stats[scorer] += 1
	if not scorer_info.is_empty():
		Globals.record_skater_stat(
			int(scorer_info.get("team_index", -1)),
			bool(scorer_info.get("home_team", scoring_team_is_home)),
			int(scorer_info.get("number", 0)),
			str(scorer_info.get("name", "")),
			"goals",
			1
		)

	if assister != "":
		if not Globals.assist_stats.has(assister):
			Globals.assist_stats[assister] = 0
		Globals.assist_stats[assister] += 1
	if not assist_info.is_empty():
		Globals.record_skater_stat(
			int(assist_info.get("team_index", -1)),
			bool(assist_info.get("home_team", scoring_team_is_home)),
			int(assist_info.get("number", 0)),
			str(assist_info.get("name", "")),
			"assists",
			1
		)

	show_goal_banner(scoring_team_is_home, scorer_info, assist_info, banner_tag)

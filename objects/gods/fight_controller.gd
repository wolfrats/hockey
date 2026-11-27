class_name FightController
extends Node

const DROPPED_STICK_SCRIPT = preload("res://objects/environment/dropped_stick.gd")

const FIGHT_RING_RADIUS: float = 170.0
const RINK_MIN_X: float = 210.0
const RINK_MAX_X: float = 1800.0
const RINK_MIN_Y: float = 205.0
const RINK_MAX_Y: float = 855.0
const MIN_FIGHTER_SEPARATION: float = 48.0

const PUNCH_SPECS := {
	"jab": {
		"anim": "Fight Jab",
		"frames": 4,
		"hit_frame": 2,
		"frame_time": 0.06,
		"cooldown": 0.08,
		"dmg_mult": 0.42,
		"reach_x": 88.0,
		"reach_y": 46.0,
		"lunge": 90.0,
		"knockback": 150.0,
		"stagger": 0.14,
		"shake": 5.0,
	},
	"cross": {
		"anim": "Fight Cross",
		"frames": 4,
		"hit_frame": 2,
		"frame_time": 0.085,
		"cooldown": 0.12,
		"dmg_mult": 0.62,
		"reach_x": 96.0,
		"reach_y": 48.0,
		"lunge": 130.0,
		"knockback": 220.0,
		"stagger": 0.22,
		"shake": 8.0,
	},
	"uppercut": {
		"anim": "Fight Uppercut",
		"frames": 5,
		"hit_frame": 3,
		"frame_time": 0.09,
		"cooldown": 0.18,
		"dmg_mult": 0.85,
		"reach_x": 88.0,
		"reach_y": 52.0,
		"lunge": 160.0,
		"knockback": 300.0,
		"stagger": 0.34,
		"shake": 12.0,
	},
}


class FighterState:
	var skater = null
	var hp: float = 100.0
	var max_hp: float = 100.0
	var facing: int = 1 # 1 = right (flip_h true), -1 = left (flip_h false)
	var move_input: Vector2 = Vector2.ZERO
	var walk_cycle: float = 0.0
	var punch_cd: float = 0.25
	var stagger: float = 0.0
	var counter: float = 0.0
	var guard: bool = false
	var attack_type: String = ""
	var attack_timer: float = 0.0
	var attack_hit_checked: bool = false
	var attack_facing: int = 1
	var attack_is_counter: bool = false
	var ai_think: float = 0.35
	var ai_guard_timer: float = 0.0
	var ai_strafe_dir: float = 1.0
	var ai_strafe_timer: float = 0.8
	var ai_retreat_timer: float = 0.0


var manager: Manager = null
var active: bool = false
var stage: String = "" # "intro", "brawl", "outro"
var stage_timer: float = 0.0
var brawl_timer: float = 0.0

var fighter_a = null # Left fighter (Skater or Referee)
var fighter_b = null # Right fighter (Skater or Referee)
var state_a: FighterState = FighterState.new()
var state_b: FighterState = FighterState.new()
var center_pos: Vector2 = Vector2(1005.5, 509.0)
var dropped_sticks: Array[DroppedStick] = []

var winner = null
var loser = null

# UI nodes
var ui_panel: Control = null
var title_label: Label = null
var callout_label: Label = null
var name_a_label: Label = null
var name_b_label: Label = null
var bar_a: ProgressBar = null
var bar_b: ProgressBar = null
var hint_label: Label = null
var callout_timer: float = 0.0


func start_fight(skater1, skater2, mgr: Manager) -> void:
	if active or skater1 == null or skater2 == null or mgr == null:
		return
	manager = mgr
	active = true
	stage = "intro"
	stage_timer = 1.15
	brawl_timer = 18.0
	winner = null
	loser = null

	if skater1.global_position.x <= skater2.global_position.x:
		fighter_a = skater1
		fighter_b = skater2
	else:
		fighter_a = skater2
		fighter_b = skater1

	_assign_auto_swap_to_fighter(fighter_a)
	_assign_auto_swap_to_fighter(fighter_b)

	center_pos = (fighter_a.global_position + fighter_b.global_position) * 0.5
	center_pos.x = clampf(center_pos.x, 420.0, 1590.0)
	center_pos.y = clampf(center_pos.y, 260.0, 760.0)

	state_a = _create_fighter_state(fighter_a, 1)
	state_b = _create_fighter_state(fighter_b, -1)

	# Clear heat so they don't instantly refight after the box
	if fighter_a is Skater:
		fighter_a.fight_heat.clear()
	if fighter_b is Skater:
		fighter_b.fight_heat.clear()

	# Prepare fighters
	for f in [fighter_a, fighter_b]:
		if f is Skater:
			f.release_grab()
			f.charging = false
			f.sprinting = false
			f.checking = 0
			f.knocked_over = 0
			f.was_knocked_over = false
			f.shot_followthrough_until = 0
			f.swapping = 0
			f.swapped_this_shift = false
			f.active_bench = null
			f.anim_state = "fighting"
			if f.has_node("Sprite"):
				f.get_node("Sprite").modulate.a = 1.0
			f.puck = null
			f.linear_velocity = Vector2.ZERO
		elif f is Referee:
			f.knocked_over = 0
			f.health = 100.0
			f.mass = 1.5
			f.set_delayed_penalty_signal(false)
			f.anim_state = "fighting"
			if f.has_node("Sprite"):
				f.get_node("Sprite").modulate = Color.WHITE
			f.linear_velocity = Vector2.ZERO

	_clear_dropped_sticks(true)
	if fighter_a is Skater:
		_chuck_stick(fighter_a, -1.0, true)
	if fighter_b is Skater:
		_chuck_stick(fighter_b, 1.0, false)

	# Spectators form a circle around the fight
	var spectators: Array = []
	for s in get_tree().get_nodes_in_group("skaters"):
		if s is Skater and s != fighter_a and s != fighter_b and not s.is_out_of_play():
			spectators.append(s)
	for i in range(spectators.size()):
		var spec: Skater = spectators[i]
		spec.release_grab()
		spec.charging = false
		spec.sprinting = false
		spec.swapping = 0
		spec.swapped_this_shift = false
		spec.active_bench = null
		spec.anim_state = "fight_spectate"
		if spec.has_node("Sprite"):
			spec.get_node("Sprite").modulate.a = 1.0
		var angle: float = TAU * float(i) / float(max(1, spectators.size()))
		spec.fight_spectate_target = center_pos + Vector2(cos(angle), sin(angle)) * 230.0
		spec.fight_spectate_target.x = clampf(spec.fight_spectate_target.x, 220.0, 1780.0)
		spec.fight_spectate_target.y = clampf(spec.fight_spectate_target.y, 190.0, 840.0)

	# Hide pucks during fight (detach possessor directly without queueing deferred unfreeze)
	for p in get_tree().get_nodes_in_group("pucks"):
		if p is Puck and p.posessor != null:
			p.posessor.puck = null
			p.posessor = null
		p.visible = false
		p.freeze = true
		if "colidable" in p:
			p.colidable = false

	# Non-fighting referees skate near the brawl
	for ref in get_tree().get_nodes_in_group("referees"):
		if ref == fighter_a or ref == fighter_b:
			continue
		if "anim_state" in ref:
			ref.anim_state = "skate_to"
			ref.target_pos = center_pos + Vector2(0, -140)

	# Crowd stands up!
	for child in manager.get_children():
		if child is Fan and not child.missing:
			child.stand(360)

	Globals.play_sound_at("Grab", center_pos)
	_build_ui()


func _assign_auto_swap_to_fighter(fighter) -> void:
	if not (fighter is Skater) or fighter.ghost != null or manager == null:
		return
	var closest_player = null
	var min_dist: float = INF
	for p in manager.get_active_players():
		if p.player_index < 0 or p.skater == null or not is_instance_valid(p.skater):
			continue
		if p.skater == fighter_a or p.skater == fighter_b:
			continue
		if p.skater.home_team != fighter.home_team:
			continue
		var auto_swap_on: bool = (p.player_index >= Globals.player_auto_swap.size() or Globals.player_auto_swap[p.player_index])
		if not auto_swap_on:
			continue
		var dist: float = p.skater.global_position.distance_to(fighter.global_position)
		if dist < min_dist:
			min_dist = dist
			closest_player = p

	if closest_player != null:
		var old_skater = closest_player.skater
		if old_skater != null and is_instance_valid(old_skater):
			if old_skater.has_method("release_grab"):
				old_skater.release_grab()
			if "sprinting" in old_skater:
				old_skater.sprinting = false
			old_skater.ghost = null
		fighter.ghost = closest_player
		closest_player.skater = fighter


func _create_fighter_state(skater, initial_facing: int) -> FighterState:
	var st := FighterState.new()
	st.skater = skater
	if skater is Referee:
		st.max_hp = 135.0
	elif skater is Skater and skater.statbook:
		st.max_hp = skater.statbook.max_health * 1.15
	else:
		st.max_hp = 100.0
	st.hp = st.max_hp
	st.facing = initial_facing
	st.attack_facing = initial_facing
	st.punch_cd = 0.2
	st.ai_think = randf_range(0.25, 0.45)
	st.ai_strafe_dir = -1.0 if randf() < 0.5 else 1.0
	st.ai_strafe_timer = randf_range(0.6, 1.3)
	return st


func _build_ui() -> void:
	_clear_ui()
	if manager == null or manager.ui_layer == null:
		return

	ui_panel = Control.new()
	ui_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	manager.ui_layer.add_child(ui_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	margin.offset_top = -175
	margin.offset_bottom = -16
	margin.add_theme_constant_override("margin_left", 80)
	margin.add_theme_constant_override("margin_right", 80)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_panel.add_child(margin)

	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.88)
	style.border_color = Color(0.95, 0.3, 0.2, 0.95)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	box.add_theme_stylebox_override("panel", style)
	margin.add_child(box)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	box.add_child(vbox)

	title_label = Label.new()
	var is_ref_fight: bool = (fighter_a is Referee) or (fighter_b is Referee)
	title_label.text = "THE REF DROPS THE GLOVES!" if is_ref_fight else "DROP THE GLOVES!"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vbox.add_child(title_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	vbox.add_child(row)

	var col_a := VBoxContainer.new()
	col_a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col_a)

	name_a_label = Label.new()
	name_a_label.text = fighter_a.get_skater_display()
	name_a_label.add_theme_font_size_override("font_size", 18)
	col_a.add_child(name_a_label)

	bar_a = ProgressBar.new()
	bar_a.max_value = state_a.max_hp
	bar_a.value = state_a.hp
	bar_a.show_percentage = false
	bar_a.custom_minimum_size = Vector2(0, 22)
	var fill_a := StyleBoxFlat.new()
	fill_a.bg_color = fighter_a.get_jersey_color().lightened(0.15)
	bar_a.add_theme_stylebox_override("fill", fill_a)
	col_a.add_child(bar_a)

	callout_label = Label.new()
	callout_label.text = "VS"
	callout_label.custom_minimum_size = Vector2(140, 0)
	callout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	callout_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	callout_label.add_theme_font_size_override("font_size", 20)
	callout_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
	row.add_child(callout_label)

	var col_b := VBoxContainer.new()
	col_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col_b)

	name_b_label = Label.new()
	name_b_label.text = fighter_b.get_skater_display()
	name_b_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	name_b_label.add_theme_font_size_override("font_size", 18)
	col_b.add_child(name_b_label)

	bar_b = ProgressBar.new()
	bar_b.max_value = state_b.max_hp
	bar_b.value = state_b.hp
	bar_b.show_percentage = false
	bar_b.fill_mode = ProgressBar.FILL_END_TO_BEGIN
	bar_b.custom_minimum_size = Vector2(0, 22)
	var fill_b := StyleBoxFlat.new()
	fill_b.bg_color = fighter_b.get_jersey_color().lightened(0.15)
	bar_b.add_theme_stylebox_override("fill", fill_b)
	col_b.add_child(bar_b)

	hint_label = Label.new()
	hint_label.text = "MOVE: WASD/L-Stick  |  JAB: E/B  |  CROSS: Space/X  |  UPPERCUT: Shift/LB  |  BLOCK: F/A or M/RB"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 14)
	hint_label.add_theme_color_override("font_color", Color(0.82, 0.86, 0.92))
	vbox.add_child(hint_label)


func _clear_ui() -> void:
	if ui_panel != null and is_instance_valid(ui_panel):
		ui_panel.queue_free()
	ui_panel = null


func _set_callout(text: String, color: Color = Color(1.0, 0.85, 0.25)) -> void:
	if callout_label:
		callout_label.text = text
		callout_label.add_theme_color_override("font_color", color)
		callout_timer = 0.75


func _physics_process(delta: float) -> void:
	if not active:
		return
	if fighter_a == null or fighter_b == null or not is_instance_valid(fighter_a) or not is_instance_valid(fighter_b):
		_finish_fight()
		return

	if callout_timer > 0.0:
		callout_timer -= delta
		if callout_timer <= 0.0 and callout_label and stage == "brawl":
			callout_label.text = "VS"
			callout_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))

	if stage == "intro":
		stage_timer -= delta
		_step_intro_positioning(delta)
		if stage_timer <= 0.0:
			stage = "brawl"
			if title_label:
				title_label.text = "FIGHT!"
			Globals.play_sound_at("Blip2", center_pos)
	elif stage == "brawl":
		brawl_timer -= delta
		_step_fighter_timers(state_a, delta)
		_step_fighter_timers(state_b, delta)

		_step_fighter_input(state_a, state_b, delta)
		_step_fighter_input(state_b, state_a, delta)

		_step_fighter_movement(state_a, state_b, delta)
		_step_fighter_movement(state_b, state_a, delta)
		_separate_fighters()

		_step_fighter_attack(state_a, state_b, delta)
		_step_fighter_attack(state_b, state_a, delta)

		_update_fighter_visual(state_a, state_b, delta)
		_update_fighter_visual(state_b, state_a, delta)

		if bar_a:
			bar_a.value = state_a.hp
		if bar_b:
			bar_b.value = state_b.hp

		if state_a.hp <= 0.0 or state_b.hp <= 0.0 or brawl_timer <= 0.0:
			_enter_outro()
	elif stage == "outro":
		stage_timer -= delta
		fighter_a.linear_velocity = fighter_a.linear_velocity.lerp(Vector2.ZERO, clampf(delta * 8.0, 0.0, 1.0))
		fighter_b.linear_velocity = fighter_b.linear_velocity.lerp(Vector2.ZERO, clampf(delta * 8.0, 0.0, 1.0))
		if winner != null:
			var win_st: FighterState = state_a if winner == fighter_a else state_b
			winner.fight_anim_override = "Celly 1"
			winner.fight_frame_override = -1
			winner.fight_flip_override = win_st.facing
		if loser != null:
			var lose_st: FighterState = state_a if loser == fighter_a else state_b
			loser.fight_anim_override = "Die 1"
			loser.fight_frame_override = 0
			loser.fight_flip_override = lose_st.facing
		if stage_timer <= 0.0:
			_finish_fight()


func _step_intro_positioning(delta: float) -> void:
	var target_a: Vector2 = center_pos + Vector2(-64.0, 0.0)
	var target_b: Vector2 = center_pos + Vector2(64.0, 0.0)
	var dist_a: float = fighter_a.global_position.distance_to(target_a)
	var dist_b: float = fighter_b.global_position.distance_to(target_b)

	fighter_a.global_position = fighter_a.global_position.lerp(target_a, clampf(delta * 8.0, 0.0, 1.0))
	fighter_b.global_position = fighter_b.global_position.lerp(target_b, clampf(delta * 8.0, 0.0, 1.0))
	fighter_a.linear_velocity = Vector2.ZERO
	fighter_b.linear_velocity = Vector2.ZERO

	state_a.facing = 1
	state_b.facing = -1
	_apply_intro_visual(state_a, dist_a > 6.0, delta)
	_apply_intro_visual(state_b, dist_b > 6.0, delta)


func _apply_intro_visual(st: FighterState, moving: bool, delta: float) -> void:
	if moving:
		st.walk_cycle += delta * 8.0
		st.skater.fight_anim_override = "Fight Move"
		st.skater.fight_frame_override = int(st.walk_cycle) % 4
	else:
		st.skater.fight_anim_override = "Fight"
		st.skater.fight_frame_override = 0
	st.skater.fight_flip_override = st.facing


func _step_fighter_timers(st: FighterState, delta: float) -> void:
	st.punch_cd = maxf(0.0, st.punch_cd - delta)
	st.stagger = maxf(0.0, st.stagger - delta)
	st.counter = maxf(0.0, st.counter - delta)


func _get_fighter_walk_speed(f) -> float:
	if f is Referee:
		return 155.0
	if f is Skater:
		if f.stats == Stats.ClassTypes.LIGHT:
			return 175.0
		if f.stats == Stats.ClassTypes.HEAVY:
			return 128.0
	return 150.0


func _step_fighter_input(st: FighterState, opp: FighterState, delta: float) -> void:
	var f = st.skater
	var move_dir := Vector2.ZERO
	var want_punch_type: String = ""
	var want_guard: bool = false

	if f is Skater and f.ghost != null and f.ghost.has_method("is_action_just_pressed_custom"):
		if f.ghost.has_method("get_axis_custom"):
			move_dir = Vector2(f.ghost.get_axis_custom("skate_x"), f.ghost.get_axis_custom("skate_y"))
			if move_dir.length_squared() > 1.0:
				move_dir = move_dir.normalized()

		var press_jab: bool = f.ghost.is_action_just_pressed_custom("check")
		var press_cross: bool = f.ghost.is_action_just_pressed_custom("shoot")
		var press_uppercut: bool = f.ghost.is_action_just_pressed_custom("pass")
		if press_uppercut:
			want_punch_type = "uppercut"
		elif press_cross:
			want_punch_type = "uppercut" if st.counter > 0.0 else "cross"
		elif press_jab:
			want_punch_type = "uppercut" if st.counter > 0.0 else "jab"
		want_guard = f.ghost.is_action_pressed_custom("grab") or f.ghost.is_action_pressed_custom("sprint")
	else:
		var diff: int = 2 if (f is Referee) else (Globals.home_ai_difficulty if f.home_team else Globals.away_ai_difficulty)
		st.ai_guard_timer = maxf(0.0, st.ai_guard_timer - delta)
		st.ai_retreat_timer = maxf(0.0, st.ai_retreat_timer - delta)
		st.ai_strafe_timer -= delta
		if st.ai_strafe_timer <= 0.0:
			st.ai_strafe_timer = randf_range(0.55, 1.35)
			st.ai_strafe_dir = -st.ai_strafe_dir

		var to_opp: Vector2 = opp.skater.global_position - f.global_position
		var dist_x: float = absf(to_opp.x)
		var dist_y: float = absf(to_opp.y)
		var ideal_x: float = 68.0
		var desired_pos := Vector2(
			opp.skater.global_position.x - (ideal_x if to_opp.x >= 0.0 else -ideal_x),
			opp.skater.global_position.y
		)

		if st.ai_retreat_timer > 0.0:
			var away: Vector2 = (-to_opp).normalized() if to_opp.length_squared() > 1.0 else Vector2(-float(st.facing), 0.0)
			var perp := Vector2(-away.y, away.x) * st.ai_strafe_dir
			move_dir = (away * 0.65 + perp * 0.75).normalized()
		else:
			var to_desired: Vector2 = desired_pos - f.global_position
			if to_desired.length() > 14.0:
				move_dir = to_desired.normalized()
				move_dir.y += st.ai_strafe_dir * 0.25
				if move_dir.length_squared() > 1.0:
					move_dir = move_dir.normalized()
			else:
				move_dir = Vector2(0.0, st.ai_strafe_dir * 0.35)

		var in_punch_range: bool = dist_x <= 92.0 and dist_y <= 44.0
		st.ai_think -= delta
		if st.ai_think <= 0.0:
			st.ai_think = maxf(0.16, randf_range(0.28, 0.58) - float(diff) * 0.06)
			var opp_winding_up: bool = opp.attack_type != "" and not opp.attack_hit_checked
			if in_punch_range and opp_winding_up and randf() < 0.22 + float(diff) * 0.14:
				st.ai_guard_timer = randf_range(0.24, 0.45)
			elif in_punch_range:
				if st.counter > 0.0:
					want_punch_type = "uppercut" if randf() < 0.65 else "cross"
				elif randf() < 0.16 + float(diff) * 0.05:
					st.ai_guard_timer = randf_range(0.22, 0.42)
				else:
					var roll: float = randf()
					if f is Referee:
						want_punch_type = "jab" if roll < 0.35 else ("cross" if roll < 0.75 else "uppercut")
					elif f is Skater and f.stats == Stats.ClassTypes.HEAVY:
						want_punch_type = "uppercut" if roll < 0.32 else ("cross" if roll < 0.72 else "jab")
					elif f is Skater and f.stats == Stats.ClassTypes.LIGHT:
						want_punch_type = "jab" if roll < 0.55 else ("cross" if roll < 0.85 else "uppercut")
					else:
						want_punch_type = "jab" if roll < 0.42 else ("cross" if roll < 0.78 else "uppercut")
					if randf() < 0.3:
						st.ai_retreat_timer = randf_range(0.18, 0.38)
		want_guard = st.ai_guard_timer > 0.0

	if st.stagger > 0.0:
		move_dir = Vector2.ZERO
		want_punch_type = ""
		want_guard = false

	st.move_input = move_dir
	st.guard = want_guard and st.attack_type == "" and want_punch_type == ""

	if want_punch_type != "" and st.attack_type == "" and st.punch_cd <= 0.0:
		_start_punch(st, opp, want_punch_type)


func _step_fighter_movement(st: FighterState, opp: FighterState, delta: float) -> void:
	var f = st.skater
	var to_opp_x: float = opp.skater.global_position.x - f.global_position.x
	if st.attack_type == "" and absf(to_opp_x) > 4.0:
		st.facing = 1 if to_opp_x >= 0.0 else -1

	if st.stagger > 0.0:
		f.linear_velocity = f.linear_velocity.lerp(Vector2.ZERO, clampf(delta * 6.0, 0.0, 1.0))
	elif st.attack_type != "":
		f.linear_velocity = f.linear_velocity.lerp(Vector2.ZERO, clampf(delta * 9.0, 0.0, 1.0))
	else:
		var walk_speed: float = _get_fighter_walk_speed(f)
		if st.guard:
			walk_speed *= 0.45
		var desired_vel: Vector2 = st.move_input * walk_speed
		f.linear_velocity = f.linear_velocity.lerp(desired_vel, clampf(delta * 12.0, 0.0, 1.0))

	_clamp_fighter_to_ring(f)


func _clamp_fighter_to_ring(f) -> void:
	var offset: Vector2 = f.global_position - center_pos
	if offset.length() > FIGHT_RING_RADIUS:
		var clamped_offset: Vector2 = offset.normalized() * FIGHT_RING_RADIUS
		f.global_position = center_pos + clamped_offset
		var outward: Vector2 = offset.normalized()
		var out_speed: float = f.linear_velocity.dot(outward)
		if out_speed > 0.0:
			f.linear_velocity -= outward * out_speed

	f.global_position.x = clampf(f.global_position.x, RINK_MIN_X, RINK_MAX_X)
	f.global_position.y = clampf(f.global_position.y, RINK_MIN_Y, RINK_MAX_Y)


func _separate_fighters() -> void:
	var diff: Vector2 = fighter_b.global_position - fighter_a.global_position
	var dist: float = diff.length()
	if dist < MIN_FIGHTER_SEPARATION:
		var dir: Vector2 = diff / dist if dist > 0.001 else Vector2.RIGHT
		var push: float = (MIN_FIGHTER_SEPARATION - dist) * 0.5
		fighter_a.global_position -= dir * push
		fighter_b.global_position += dir * push
		_clamp_fighter_to_ring(fighter_a)
		_clamp_fighter_to_ring(fighter_b)


func _start_punch(st: FighterState, opp: FighterState, punch_type: String) -> void:
	var spec: Dictionary = PUNCH_SPECS[punch_type]
	var to_opp_x: float = opp.skater.global_position.x - st.skater.global_position.x
	if absf(to_opp_x) > 2.0:
		st.facing = 1 if to_opp_x >= 0.0 else -1

	st.attack_type = punch_type
	st.attack_timer = 0.0
	st.attack_hit_checked = false
	st.attack_facing = st.facing
	st.attack_is_counter = st.counter > 0.0
	st.counter = 0.0
	st.guard = false

	# Slight forward step into the punch
	var lunge_dir := Vector2(float(st.attack_facing), st.move_input.y * 0.35).normalized()
	st.skater.linear_velocity = lunge_dir * float(spec["lunge"])


func _step_fighter_attack(st: FighterState, opp: FighterState, delta: float) -> void:
	if st.attack_type == "":
		return
	var spec: Dictionary = PUNCH_SPECS[st.attack_type]
	var frame_time: float = float(spec["frame_time"])
	var total_frames: int = int(spec["frames"])
	var hit_frame: int = int(spec["hit_frame"])
	var total_duration: float = frame_time * float(total_frames)

	st.attack_timer += delta
	var cur_frame: int = int(st.attack_timer / frame_time)

	if not st.attack_hit_checked and cur_frame >= hit_frame:
		st.attack_hit_checked = true
		_resolve_punch_impact(st, opp, st.attack_type, spec)

	if st.attack_timer >= total_duration:
		var class_cd_mult: float = 1.0
		if st.skater is Skater:
			class_cd_mult = 0.85 if st.skater.stats == Stats.ClassTypes.LIGHT else (1.2 if st.skater.stats == Stats.ClassTypes.HEAVY else 1.0)
		st.punch_cd = float(spec["cooldown"]) * class_cd_mult
		st.attack_type = ""
		st.attack_timer = 0.0
		st.attack_hit_checked = false
		st.attack_is_counter = false


func _resolve_punch_impact(attacker_st: FighterState, defender_st: FighterState, punch_type: String, spec: Dictionary) -> void:
	var attacker = attacker_st.skater
	var defender = defender_st.skater

	var delta_pos: Vector2 = defender.global_position - attacker.global_position
	var forward_dist: float = delta_pos.x * float(attacker_st.attack_facing)
	var reach_x: float = float(spec["reach_x"])
	var reach_y: float = float(spec["reach_y"])

	if forward_dist < -12.0 or forward_dist > reach_x or absf(delta_pos.y) > reach_y:
		Globals.play_sound_at("CheckMiss", attacker.global_position)
		return

	var base_dmg: float = 16.0
	if attacker is Referee:
		base_dmg = 35.0 * float(spec["dmg_mult"])
	elif attacker is Skater and attacker.statbook:
		base_dmg = attacker.statbook.check_damage * float(spec["dmg_mult"])
	base_dmg *= randf_range(0.88, 1.12)

	var push_dir: Vector2 = delta_pos.normalized() if delta_pos.length_squared() > 1.0 else Vector2(float(attacker_st.attack_facing), 0.0)

	if defender_st.guard:
		var chip: float = base_dmg * 0.22
		defender_st.hp = maxf(0.0, defender_st.hp - chip)
		attacker_st.stagger = 0.38
		attacker_st.attack_type = ""
		attacker_st.punch_cd = 0.22
		defender_st.counter = 0.85
		attacker.linear_velocity = -push_dir * 120.0
		defender.linear_velocity = push_dir * 65.0
		defender.take_damage(0.0, Color(0.5, 0.8, 1.0))
		Globals.play_sound_at("Bump", defender.global_position)
		_set_callout("BLOCKED!", Color(0.45, 0.85, 1.0))
		return

	if attacker_st.attack_is_counter:
		base_dmg *= 1.45
		_set_callout("COUNTER!", Color(1.0, 0.9, 0.2))
	elif punch_type == "uppercut":
		_set_callout("UPPERCUT!", Color(1.0, 0.4, 0.2))
	elif base_dmg >= 24.0:
		_set_callout("HAYMAKER!", Color(1.0, 0.4, 0.2))

	defender_st.hp = maxf(0.0, defender_st.hp - base_dmg)
	defender_st.stagger = maxf(defender_st.stagger, float(spec["stagger"]))
	if punch_type == "uppercut" or attacker_st.attack_is_counter:
		defender_st.attack_type = ""
	defender.linear_velocity = push_dir * float(spec["knockback"])
	defender.take_damage(0.0, Color(1.0, 0.25, 0.25))
	Globals.play_sound_at("Check", defender.global_position)

	var cam := get_viewport().get_camera_2d()
	if cam:
		var shake_amt: float = float(spec["shake"]) + (4.0 if attacker_st.attack_is_counter else 0.0)
		var tw := create_tween()
		tw.tween_property(cam, "offset", Vector2(randf_range(-shake_amt, shake_amt), randf_range(-shake_amt, shake_amt)), 0.04)
		tw.tween_property(cam, "offset", Vector2.ZERO, 0.06)


func _update_fighter_visual(st: FighterState, _opp: FighterState, delta: float) -> void:
	var f = st.skater
	if st.attack_type != "":
		var spec: Dictionary = PUNCH_SPECS[st.attack_type]
		var total_frames: int = int(spec["frames"])
		var frame_idx: int = mini(int(st.attack_timer / float(spec["frame_time"])), total_frames - 1)
		f.fight_anim_override = str(spec["anim"])
		f.fight_frame_override = frame_idx
		f.fight_flip_override = st.attack_facing
		return

	var is_moving: bool = st.stagger <= 0.0 and (st.move_input.length() > 0.1 or f.linear_velocity.length() > 22.0)
	if is_moving:
		st.walk_cycle += delta * (5.5 if st.guard else 9.0)
		f.fight_anim_override = "Fight Move"
		f.fight_frame_override = int(st.walk_cycle) % 4
	else:
		f.fight_anim_override = "Fight"
		f.fight_frame_override = 0
	f.fight_flip_override = st.facing


func _enter_outro() -> void:
	stage = "outro"
	stage_timer = 2.0
	if state_a.hp >= state_b.hp:
		winner = fighter_a
		loser = fighter_b
	else:
		winner = fighter_b
		loser = fighter_a

	var is_ref_fight: bool = (fighter_a is Referee) or (fighter_b is Referee)
	if winner is Skater:
		Globals.record_skater_stat(winner.get_team_index(), winner.home_team, winner.jersey_number, winner.skater_name, "fights_won", 1)
	Globals.play_sound_at("GoalHome", center_pos, false)

	if title_label:
		title_label.text = "%s WINS THE FIGHT!" % winner.get_skater_display()
	if callout_label:
		callout_label.text = "KO!" if (state_a.hp <= 0.0 or state_b.hp <= 0.0) else "DECISION!"
	if winner is Skater:
		var win_team: String = StatBook.TEAMS[winner.get_team_index()]["name"]
		if hint_label:
			if is_ref_fight:
				hint_label.text = "%s earn a 15s MOMENTUM BOOST! %s gets 30s in the box." % [win_team, winner.get_skater_display()]
			else:
				hint_label.text = "%s earn a 15s MOMENTUM BOOST! Both fighters get 20s in the box." % win_team

		# Grant morale boost to winner's team
		for s in get_tree().get_nodes_in_group("skaters"):
			if s is Skater and s.home_team == winner.home_team and not s.is_out_of_play():
				s.grant_morale_boost(15.0)
		if manager:
			manager.show_banner("MOMENTUM BOOST! %s" % win_team, winner.get_jersey_color(), 3.0)
	else:
		if hint_label:
			hint_label.text = "Don't mess with the stripes! %s gets 30s in the box." % loser.get_skater_display()
		if manager:
			manager.show_banner("THE REFEREE WINS THE BRAWL!", Color(0.95, 0.95, 1.0), 3.0)


func _chuck_stick(fighter: Skater, outward_x: float, facing_right: bool) -> void:
	if manager == null or fighter == null or not is_instance_valid(fighter):
		return
	var stick: DroppedStick = DROPPED_STICK_SCRIPT.new()
	manager.add_child(stick)
	var sprite_scale: Vector2 = fighter.get_sprite_scale().abs()
	var hand_x_offset: float = (18.0 if facing_right else -18.0) * sprite_scale.x
	var feet_y_offset: float = 44.0 * sprite_scale.y
	stick.launch(fighter.global_position + Vector2(hand_x_offset, feet_y_offset), outward_x, facing_right)
	dropped_sticks.append(stick)


func _clear_dropped_sticks(immediate: bool = false) -> void:
	for stick in dropped_sticks:
		if stick != null and is_instance_valid(stick):
			if immediate:
				stick.queue_free()
			else:
				stick.fade_and_free(0.6)
	dropped_sticks.clear()


func _finish_fight() -> void:
	var is_ref_fight: bool = (fighter_a is Referee) or (fighter_b is Referee)
	active = false
	_clear_ui()
	_clear_dropped_sticks(false)

	for s in get_tree().get_nodes_in_group("skaters"):
		if s is Skater:
			s.fight_anim_override = ""
			s.fight_frame_override = -1
			s.fight_flip_override = 0
			if s.anim_state == "fight_spectate" or s.anim_state == "fighting":
				s.anim_state = ""

	for ref in get_tree().get_nodes_in_group("referees"):
		if ref is Referee:
			ref.fight_anim_override = ""
			ref.fight_frame_override = -1
			ref.fight_flip_override = 0
			ref.z_index = 0
			ref.mass = 100.0
			ref.health = 100.0
			if ref.anim_state == "fighting":
				ref.anim_state = ""

	var penalty_duration: float = 30.0 if is_ref_fight else 20.0
	if fighter_a != null and is_instance_valid(fighter_a) and fighter_a is Skater:
		fighter_a.penalty(penalty_duration, true)
	if fighter_b != null and is_instance_valid(fighter_b) and fighter_b is Skater:
		fighter_b.penalty(penalty_duration, true)

	fighter_a = null
	fighter_b = null

	if manager != null and manager.anim_manager != null:
		manager.fight_cooldown = 45.0
		manager.anim_manager.set_phase(AnimationManager.Phase.FACE_OFF)

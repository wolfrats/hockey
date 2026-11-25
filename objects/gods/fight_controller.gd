class_name FightController
extends Node

var manager: Manager = null
var active: bool = false
var stage: String = "" # "intro", "brawl", "outro"
var stage_timer: float = 0.0
var brawl_timer: float = 0.0

var fighter_a: Skater = null # Left fighter
var fighter_b: Skater = null # Right fighter
var center_pos: Vector2 = Vector2(1005.5, 509.0)

var hp_a: float = 100.0
var max_hp_a: float = 100.0
var hp_b: float = 100.0
var max_hp_b: float = 100.0

var punch_cd_a: float = 0.0
var punch_cd_b: float = 0.0
var lunge_a: float = 0.0
var lunge_b: float = 0.0
var stagger_a: float = 0.0
var stagger_b: float = 0.0
var counter_a: float = 0.0
var counter_b: float = 0.0
var guard_a: bool = false
var guard_b: bool = false
var ai_think_a: float = 0.3
var ai_think_b: float = 0.3
var ai_guard_timer_a: float = 0.0
var ai_guard_timer_b: float = 0.0

var winner: Skater = null
var loser: Skater = null

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

func start_fight(skater1: Skater, skater2: Skater, mgr: Manager) -> void:
	if active or skater1 == null or skater2 == null or mgr == null:
		return
	manager = mgr
	active = true
	stage = "intro"
	stage_timer = 1.15
	brawl_timer = 12.0
	winner = null
	loser = null

	if skater1.global_position.x <= skater2.global_position.x:
		fighter_a = skater1
		fighter_b = skater2
	else:
		fighter_a = skater2
		fighter_b = skater1

	center_pos = (fighter_a.global_position + fighter_b.global_position) * 0.5
	center_pos.x = clampf(center_pos.x, 420.0, 1590.0)
	center_pos.y = clampf(center_pos.y, 260.0, 760.0)

	max_hp_a = fighter_a.statbook.max_health * 1.15 if fighter_a.statbook else 100.0
	max_hp_b = fighter_b.statbook.max_health * 1.15 if fighter_b.statbook else 100.0
	hp_a = max_hp_a
	hp_b = max_hp_b

	punch_cd_a = 0.25
	punch_cd_b = 0.25
	lunge_a = 0.0
	lunge_b = 0.0
	stagger_a = 0.0
	stagger_b = 0.0
	counter_a = 0.0
	counter_b = 0.0
	guard_a = false
	guard_b = false
	ai_think_a = 0.35
	ai_think_b = 0.35
	ai_guard_timer_a = 0.0
	ai_guard_timer_b = 0.0

	# Clear heat so they don't instantly refight after the box
	fighter_a.fight_heat.clear()
	fighter_b.fight_heat.clear()

	# Prepare fighters
	for f in [fighter_a, fighter_b]:
		f.release_grab()
		f.charging = false
		f.sprinting = false
		f.checking = 0
		f.knocked_over = 0
		f.was_knocked_over = false
		f.anim_state = "fighting"
		if f.puck:
			f.puck.shoot(f.name, Vector2.ZERO)
			f.puck = null
		f.linear_velocity = Vector2.ZERO

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
		spec.anim_state = "fight_spectate"
		var angle: float = TAU * float(i) / float(max(1, spectators.size()))
		spec.fight_spectate_target = center_pos + Vector2(cos(angle), sin(angle)) * 230.0
		spec.fight_spectate_target.x = clampf(spec.fight_spectate_target.x, 220.0, 1780.0)
		spec.fight_spectate_target.y = clampf(spec.fight_spectate_target.y, 190.0, 840.0)

	# Hide pucks during fight
	for p in get_tree().get_nodes_in_group("pucks"):
		p.visible = false
		p.freeze = true
		if "colidable" in p:
			p.colidable = false

	# Referee skates near the brawl
	for ref in get_tree().get_nodes_in_group("referees"):
		if "anim_state" in ref:
			ref.anim_state = "skate_to"
			ref.target_pos = center_pos + Vector2(0, -140)

	# Crowd stands up!
	for child in manager.get_children():
		if child is Fan and not child.missing:
			child.stand(360)

	Globals.play_sound_at("Grab", center_pos)
	_build_ui()

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
	title_label.text = "DROP THE GLOVES!"
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
	bar_a.max_value = max_hp_a
	bar_a.value = hp_a
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
	bar_b.max_value = max_hp_b
	bar_b.value = hp_b
	bar_b.show_percentage = false
	bar_b.fill_mode = ProgressBar.FILL_END_TO_BEGIN
	bar_b.custom_minimum_size = Vector2(0, 22)
	var fill_b := StyleBoxFlat.new()
	fill_b.bg_color = fighter_b.get_jersey_color().lightened(0.15)
	bar_b.add_theme_stylebox_override("fill", fill_b)
	col_b.add_child(bar_b)

	hint_label = Label.new()
	hint_label.text = "PUNCH: Check (E/B) or Shoot (Space/X)   |   BLOCK & COUNTER: Pass (F/A) or Grab (M/RB)"
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
		_position_fighters(delta, 0.0, 0.0)
		fighter_a.fight_anim_override = "Grab Left"
		fighter_a.fight_flip_override = 1
		fighter_b.fight_anim_override = "Grab Left"
		fighter_b.fight_flip_override = -1
		if stage_timer <= 0.0:
			stage = "brawl"
			if title_label:
				title_label.text = "FIGHT!"
			Globals.play_sound_at("Blip2", center_pos)
	elif stage == "brawl":
		brawl_timer -= delta
		punch_cd_a = maxf(0.0, punch_cd_a - delta)
		punch_cd_b = maxf(0.0, punch_cd_b - delta)
		lunge_a = maxf(0.0, lunge_a - delta)
		lunge_b = maxf(0.0, lunge_b - delta)
		stagger_a = maxf(0.0, stagger_a - delta)
		stagger_b = maxf(0.0, stagger_b - delta)
		counter_a = maxf(0.0, counter_a - delta)
		counter_b = maxf(0.0, counter_b - delta)

		_step_fighter_input(delta, true)
		_step_fighter_input(delta, false)
		_position_fighters(delta, 20.0 if lunge_a > 0.0 else 0.0, -20.0 if lunge_b > 0.0 else 0.0)
		_update_fighter_visuals()

		if bar_a:
			bar_a.value = hp_a
		if bar_b:
			bar_b.value = hp_b

		if hp_a <= 0.0 or hp_b <= 0.0 or brawl_timer <= 0.0:
			_enter_outro()
	elif stage == "outro":
		stage_timer -= delta
		if winner != null:
			winner.fight_anim_override = "Celly 1"
			winner.fight_flip_override = 1 if winner == fighter_a else -1
		if loser != null:
			loser.fight_anim_override = "Die 1"
			loser.fight_flip_override = -1 if loser == fighter_b else 1
		if stage_timer <= 0.0:
			_finish_fight()

func _position_fighters(delta: float, offset_a: float, offset_b: float) -> void:
	var target_a: Vector2 = center_pos + Vector2(-42.0 + offset_a, 0.0)
	var target_b: Vector2 = center_pos + Vector2(42.0 + offset_b, 0.0)
	fighter_a.global_position = fighter_a.global_position.lerp(target_a, clampf(delta * 10.0, 0.0, 1.0))
	fighter_b.global_position = fighter_b.global_position.lerp(target_b, clampf(delta * 10.0, 0.0, 1.0))
	fighter_a.linear_velocity = Vector2.ZERO
	fighter_b.linear_velocity = Vector2.ZERO

func _update_fighter_visuals() -> void:
	if lunge_a > 0.0:
		fighter_a.fight_anim_override = "Check Left"
	elif guard_a:
		fighter_a.fight_anim_override = "Grab Left"
	else:
		fighter_a.fight_anim_override = "Pummel Down" if (Globals.ticks / 12) % 2 == 0 else "Grab Left"
	fighter_a.fight_flip_override = 1

	if lunge_b > 0.0:
		fighter_b.fight_anim_override = "Check Left"
	elif guard_b:
		fighter_b.fight_anim_override = "Grab Left"
	else:
		fighter_b.fight_anim_override = "Pummel Down" if ((Globals.ticks + 6) / 12) % 2 == 0 else "Grab Left"
	fighter_b.fight_flip_override = -1

func _step_fighter_input(delta: float, is_a: bool) -> void:
	var f: Skater = fighter_a if is_a else fighter_b
	var stagger: float = stagger_a if is_a else stagger_b
	var punch_cd: float = punch_cd_a if is_a else punch_cd_b
	var want_punch: bool = false
	var want_guard: bool = false

	if f.ghost != null and f.ghost.has_method("is_action_just_pressed_custom"):
		want_punch = f.ghost.is_action_just_pressed_custom("check") or f.ghost.is_action_just_pressed_custom("shoot")
		want_guard = f.ghost.is_action_pressed_custom("grab") or f.ghost.is_action_pressed_custom("pass")
	else:
		var diff: int = Globals.home_ai_difficulty if f.home_team else Globals.away_ai_difficulty
		if is_a:
			ai_guard_timer_a = maxf(0.0, ai_guard_timer_a - delta)
			ai_think_a -= delta
			if ai_think_a <= 0.0:
				ai_think_a = randf_range(0.32, 0.68) - float(diff) * 0.07
				if randf() < 0.25 + float(diff) * 0.08:
					ai_guard_timer_a = randf_range(0.25, 0.5)
				else:
					want_punch = true
			want_guard = ai_guard_timer_a > 0.0
		else:
			ai_guard_timer_b = maxf(0.0, ai_guard_timer_b - delta)
			ai_think_b -= delta
			if ai_think_b <= 0.0:
				ai_think_b = randf_range(0.32, 0.68) - float(diff) * 0.07
				if randf() < 0.25 + float(diff) * 0.08:
					ai_guard_timer_b = randf_range(0.25, 0.5)
				else:
					want_punch = true
			want_guard = ai_guard_timer_b > 0.0

	if stagger > 0.0:
		want_punch = false
		want_guard = false

	if is_a:
		guard_a = want_guard and not want_punch
	else:
		guard_b = want_guard and not want_punch

	if want_punch and punch_cd <= 0.0:
		_throw_punch(is_a)

func _throw_punch(is_a: bool) -> void:
	var attacker: Skater = fighter_a if is_a else fighter_b
	var defender: Skater = fighter_b if is_a else fighter_a
	var def_guarding: bool = guard_b if is_a else guard_a
	var is_counter: bool = (counter_a > 0.0) if is_a else (counter_b > 0.0)

	var base_cd: float = 0.34 if attacker.stats == Stats.ClassTypes.LIGHT else (0.48 if attacker.stats == Stats.ClassTypes.HEAVY else 0.40)
	var base_dmg: float = (attacker.statbook.check_damage * 0.55) if attacker.statbook else 16.0
	base_dmg *= randf_range(0.85, 1.15)

	if is_a:
		punch_cd_a = base_cd
		lunge_a = 0.16
		counter_a = 0.0
	else:
		punch_cd_b = base_cd
		lunge_b = 0.16
		counter_b = 0.0

	if def_guarding:
		var chip: float = base_dmg * 0.25
		if is_a:
			hp_b = maxf(0.0, hp_b - chip)
			stagger_a = 0.45
			counter_b = 0.8
		else:
			hp_a = maxf(0.0, hp_a - chip)
			stagger_b = 0.45
			counter_a = 0.8
		defender.take_damage(0.0, Color(0.5, 0.8, 1.0))
		Globals.play_sound_at("Bump", center_pos)
		_set_callout("BLOCKED!", Color(0.45, 0.85, 1.0))
		return

	if is_counter:
		base_dmg *= 1.55
		_set_callout("COUNTER!", Color(1.0, 0.9, 0.2))
	elif base_dmg >= 24.0:
		_set_callout("HAYMAKER!", Color(1.0, 0.4, 0.2))

	if is_a:
		hp_b = maxf(0.0, hp_b - base_dmg)
	else:
		hp_a = maxf(0.0, hp_a - base_dmg)

	defender.take_damage(0.0, Color(1.0, 0.25, 0.25))
	Globals.play_sound_at("Check", center_pos)

	var cam := get_viewport().get_camera_2d()
	if cam:
		var shake_amt: float = 11.0 if is_counter else 6.0
		var tw := create_tween()
		tw.tween_property(cam, "offset", Vector2(randf_range(-shake_amt, shake_amt), randf_range(-shake_amt, shake_amt)), 0.04)
		tw.tween_property(cam, "offset", Vector2.ZERO, 0.06)

func _enter_outro() -> void:
	stage = "outro"
	stage_timer = 2.0
	if hp_a >= hp_b:
		winner = fighter_a
		loser = fighter_b
	else:
		winner = fighter_b
		loser = fighter_a

	Globals.record_skater_stat(winner.get_team_index(), winner.home_team, winner.jersey_number, winner.skater_name, "fights_won", 1)
	Globals.play_sound_at("GoalHome", center_pos, false)

	if title_label:
		title_label.text = "%s WINS THE FIGHT!" % winner.get_skater_display()
	if callout_label:
		callout_label.text = "KO!" if (hp_a <= 0.0 or hp_b <= 0.0) else "DECISION!"
	if hint_label:
		var win_team: String = StatBook.TEAMS[winner.get_team_index()]["name"]
		hint_label.text = "%s earn a 15s MOMENTUM BOOST! Both fighters get 20s in the box." % win_team

	# Grant morale boost to winner's team
	for s in get_tree().get_nodes_in_group("skaters"):
		if s is Skater and s.home_team == winner.home_team and not s.is_out_of_play():
			s.grant_morale_boost(15.0)
	if manager:
		manager.show_banner("MOMENTUM BOOST! %s" % StatBook.TEAMS[winner.get_team_index()]["name"], winner.get_jersey_color(), 3.0)

func _finish_fight() -> void:
	active = false
	_clear_ui()

	for s in get_tree().get_nodes_in_group("skaters"):
		if s is Skater:
			s.fight_anim_override = ""
			s.fight_flip_override = 0
			if s.anim_state == "fight_spectate" or s.anim_state == "fighting":
				s.anim_state = ""

	if fighter_a != null and is_instance_valid(fighter_a):
		fighter_a.penalty(20.0, true)
	if fighter_b != null and is_instance_valid(fighter_b):
		fighter_b.penalty(20.0, true)

	fighter_a = null
	fighter_b = null

	if manager != null and manager.anim_manager != null:
		manager.fight_cooldown = 45.0
		manager.anim_manager.set_phase(AnimationManager.Phase.FACE_OFF)

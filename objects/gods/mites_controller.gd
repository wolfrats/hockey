class_name MitesController
extends Node2D

const NET_SCENE = preload("res://objects/environment/netsprite.tscn")
const PUCK_TEXTURE = preload("res://sprites/puck.png")

const CENTER_POS := Vector2(1005.5, 509.0)
const MIN_X: float = 560.0
const MAX_X: float = 1451.0
const MIN_Y: float = 250.0
const MAX_Y: float = 768.0

const LEFT_GOAL_X: float = 640.0
const RIGHT_GOAL_X: float = 1371.0
const GOAL_Y: float = 509.0
const GOAL_HALF_HEIGHT: float = 48.0
const MITES_PER_TEAM: int = 10

var manager: Manager = null
var active: bool = false

var home_score: int = 0
var away_score: int = 0
var celly_timer: float = 0.0
var celly_home_scored: bool = true

var mites: Array = []
var puck_node: Sprite2D = null
var puck_pos: Vector2 = CENTER_POS
var puck_vel: Vector2 = Vector2.ZERO
var puck_carrier_idx: int = -1

var props_root: Node2D = null
var ui_panel: PanelContainer = null
var ui_title: Label = null
var ui_sub: Label = null

func _ready() -> void:
	y_sort_enabled = true

func start_mites(mgr: Manager) -> void:
	stop_mites()
	manager = mgr
	active = true
	home_score = 0
	away_score = 0
	celly_timer = 0.0
	puck_carrier_idx = -1

	props_root = Node2D.new()
	props_root.name = "MitesProps"
	props_root.y_sort_enabled = true
	add_child(props_root)

	_build_mini_rink_and_goals()
	_spawn_mites_teams()
	_spawn_puck()
	_build_ui()
	_reset_faceoff()

func stop_mites() -> void:
	active = false
	mites.clear()
	puck_carrier_idx = -1
	puck_node = null
	if props_root != null and is_instance_valid(props_root):
		props_root.queue_free()
	props_root = null
	if ui_panel != null and is_instance_valid(ui_panel):
		ui_panel.queue_free()
	ui_panel = null
	ui_title = null
	ui_sub = null

func _build_mini_rink_and_goals() -> void:
	# Mini-rink foam divider barriers (cross-ice / shrunk-ice look)
	var border := Line2D.new()
	border.z_index = -10
	border.width = 6.0
	border.default_color = Color(0.15, 0.35, 0.75, 0.55)
	border.points = PackedVector2Array([
		Vector2(MIN_X, MIN_Y),
		Vector2(MAX_X, MIN_Y),
		Vector2(MAX_X, MAX_Y),
		Vector2(MIN_X, MAX_Y),
		Vector2(MIN_X, MIN_Y),
	])
	props_root.add_child(border)

	# Closer left net
	var left_net := NET_SCENE.instantiate()
	left_net.position = Vector2(LEFT_GOAL_X, GOAL_Y - 8.0)
	left_net.scale = Vector2(0.75, 0.75)
	props_root.add_child(left_net)

	# Closer right net
	var right_net := NET_SCENE.instantiate()
	right_net.position = Vector2(RIGHT_GOAL_X, GOAL_Y - 8.0)
	right_net.scale = Vector2(-0.75, 0.75)
	props_root.add_child(right_net)

func _create_mite_material(use_home_jersey: bool, number: int) -> ShaderMaterial:
	var home_team_data: Dictionary = StatBook.TEAMS[Globals.home_team_index]
	var mat: ShaderMaterial = Globals.home_shader_material.duplicate()
	if use_home_jersey:
		mat.set("shader_parameter/replace_helmet", home_team_data["head_color"])
		mat.set("shader_parameter/replace_shirt", home_team_data["body_color"])
		mat.set("shader_parameter/replace_sleeve", home_team_data["body_color"])
		mat.set("shader_parameter/replace_pants", home_team_data["foot_color"])
	else:
		mat.set("shader_parameter/replace_helmet", home_team_data["away_head_color"])
		mat.set("shader_parameter/replace_shirt", home_team_data["away_body_color"])
		mat.set("shader_parameter/replace_sleeve", home_team_data["body_color"])
		mat.set("shader_parameter/replace_pants", home_team_data["away_foot_color"])

	var st: Array[Color] = Globals.random_skin_tone()
	var eye: Color = Globals.random_eye_color()
	var profile := {
		"skin": st[0].to_html(false),
		"nose": st[1].to_html(false),
		"eye": eye.to_html(false),
		"number": number,
	}
	Globals.apply_player_profile(mat, profile)
	return mat

func _spawn_mites_teams() -> void:
	mites.clear()
	for team_side in [true, false]: # true = home team's home jersey (left->right), false = home team's away jersey (right->left)
		for i in range(MITES_PER_TEAM):
			var holder := Node2D.new()
			holder.y_sort_enabled = true
			props_root.add_child(holder)

			var sprite := Sprite2D.new()
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.texture = Globals.skater_texture("light", "Skate Left")
			sprite.region_enabled = true
			sprite.region_rect = Rect2(0, 0, 192, 192)
			var kid_scale: float = randf_range(0.42, 0.48)
			sprite.scale = Vector2(kid_scale, kid_scale)
			var jersey_num: int = randi_range(1, 98)
			sprite.material = _create_mite_material(team_side, jersey_num)
			holder.add_child(sprite)

			var role: String = "goalie" if i == 0 else ("defense" if i <= 2 else "swarm")
			var mite := {
				"node": holder,
				"sprite": sprite,
				"home_jersey": team_side,
				"role": role,
				"pos": Vector2.ZERO,
				"vel": Vector2.ZERO,
				"facing": Vector2(1.0, 0.0) if team_side else Vector2(-1.0, 0.0),
				"step_counter": randf_range(0.0, 60.0),
				"fall_timer": 0.0,
				"pickup_cd": 0.0,
				"shoot_timer": 0.0,
				"wander_offset": Vector2(randf_range(-55.0, 55.0), randf_range(-55.0, 55.0)),
				"wander_timer": randf_range(0.5, 2.0),
				"speed": randf_range(125.0, 165.0) if role != "goalie" else 135.0,
			}
			mites.append(mite)

func _spawn_puck() -> void:
	puck_node = Sprite2D.new()
	puck_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	puck_node.texture = PUCK_TEXTURE
	puck_node.scale = Vector2(0.28, 0.28)
	puck_node.z_index = 1
	props_root.add_child(puck_node)

func _reset_faceoff() -> void:
	puck_carrier_idx = -1
	puck_pos = CENTER_POS
	puck_vel = Vector2(randf_range(-35.0, 35.0), randf_range(-35.0, 35.0))
	if puck_node:
		puck_node.position = puck_pos

	var home_idx: int = 0
	var away_idx: int = 0
	for m in mites:
		m["vel"] = Vector2.ZERO
		m["fall_timer"] = 0.0
		m["pickup_cd"] = 0.35
		m["shoot_timer"] = 0.0
		var is_home: bool = m["home_jersey"]
		var idx: int = home_idx if is_home else away_idx
		if is_home:
			home_idx += 1
		else:
			away_idx += 1

		var start_pos: Vector2
		if idx == 0:
			start_pos = Vector2(LEFT_GOAL_X + 36.0 if is_home else RIGHT_GOAL_X - 36.0, GOAL_Y)
		else:
			var side_sign: float = -1.0 if is_home else 1.0
			var col: int = int((idx - 1) / 3)
			var row: int = (idx - 1) % 3
			var x: float = CENTER_POS.x + side_sign * (55.0 + float(col) * 85.0 + randf_range(-14.0, 14.0))
			var y: float = GOAL_Y + (float(row) - 1.0) * 115.0 + randf_range(-20.0, 20.0)
			start_pos = Vector2(x, y)

		m["pos"] = start_pos
		m["facing"] = Vector2(1.0, 0.0) if is_home else Vector2(-1.0, 0.0)
		m["node"].position = start_pos

func _build_ui() -> void:
	if manager == null or manager.ui_layer == null:
		return
	ui_panel = PanelContainer.new()
	ui_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	ui_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ui_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ui_panel.position = Vector2(0, -24)
	ui_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.11, 0.17, 0.90)
	style.border_color = Color(1.0, 0.85, 0.2)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	ui_panel.add_theme_stylebox_override("panel", style)
	manager.ui_layer.add_child(ui_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	ui_panel.add_child(vbox)

	ui_title = Label.new()
	ui_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_title.add_theme_font_size_override("font_size", 26)
	ui_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.25))
	vbox.add_child(ui_title)

	ui_sub = Label.new()
	ui_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_sub.add_theme_font_size_override("font_size", 18)
	ui_sub.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	vbox.add_child(ui_sub)

	_update_ui_text()

func _update_ui_text() -> void:
	if ui_title == null or ui_sub == null:
		return
	var team_name: String = StatBook.TEAMS[Globals.home_team_index]["name"]
	if celly_timer > 0.0:
		ui_title.text = "MITES GOAL!  %s Home %d - %d %s Away" % [team_name, home_score, away_score, team_name]
	else:
		ui_title.text = "1ST INTERMISSION: MITES ON ICE!  (%d - %d)" % [home_score, away_score]
	ui_sub.text = "%s Home vs %s Away (10 on 10)   |   Press SPACE to start Period 2" % [team_name, team_name]

func _physics_process(delta: float) -> void:
	if not active:
		return

	if celly_timer > 0.0:
		celly_timer -= delta
		_step_mites_celebration(delta)
		if celly_timer <= 0.0:
			_reset_faceoff()
			_update_ui_text()
		return

	_step_mites_ai(delta)
	_step_puck(delta)

func _step_mites_celebration(delta: float) -> void:
	for m in mites:
		var is_scorer_team: bool = (m["home_jersey"] == celly_home_scored)
		var pos: Vector2 = m["pos"]
		var vel: Vector2 = m["vel"]
		if is_scorer_team:
			var wobble := Vector2(cos(float(Globals.ticks) * 0.1 + float(m["step_counter"])), sin(float(Globals.ticks) * 0.12 + float(m["step_counter"]))) * 75.0
			vel = vel.lerp(wobble, delta * 4.0)
		else:
			vel = vel.lerp(Vector2.ZERO, delta * 4.0)
		pos += vel * delta
		pos.x = clampf(pos.x, MIN_X + 18.0, MAX_X - 18.0)
		pos.y = clampf(pos.y, MIN_Y + 18.0, MAX_Y - 18.0)
		m["pos"] = pos
		m["vel"] = vel
		m["node"].position = pos
		_update_mite_visual(m, is_scorer_team)

func _step_mites_ai(delta: float) -> void:
	var count: int = mites.size()
	for i in range(count):
		var m: Dictionary = mites[i]
		m["pickup_cd"] = maxf(0.0, float(m["pickup_cd"]) - delta)
		m["wander_timer"] = float(m["wander_timer"]) - delta
		if float(m["wander_timer"]) <= 0.0:
			m["wander_timer"] = randf_range(0.7, 2.0)
			m["wander_offset"] = Vector2(randf_range(-65.0, 65.0), randf_range(-65.0, 65.0))

		if float(m["fall_timer"]) > 0.0:
			m["fall_timer"] = maxf(0.0, float(m["fall_timer"]) - delta)
			m["vel"] = (m["vel"] as Vector2).lerp(Vector2.ZERO, delta * 5.0)
			m["pos"] = (m["pos"] as Vector2) + (m["vel"] as Vector2) * delta
			m["node"].position = m["pos"]
			_update_mite_visual(m, false)
			continue

		var is_home: bool = m["home_jersey"]
		var role: String = m["role"]
		var pos: Vector2 = m["pos"]
		var vel: Vector2 = m["vel"]
		var attack_goal := Vector2(RIGHT_GOAL_X - 14.0, GOAL_Y) if is_home else Vector2(LEFT_GOAL_X + 14.0, GOAL_Y)
		var defend_goal := Vector2(LEFT_GOAL_X + 32.0, GOAL_Y) if is_home else Vector2(RIGHT_GOAL_X - 32.0, GOAL_Y)
		var is_carrier: bool = (i == puck_carrier_idx)

		var target: Vector2 = puck_pos
		if is_carrier:
			target = attack_goal + Vector2(0.0, sin(float(Globals.ticks) * 0.06 + float(i)) * 45.0)
			m["shoot_timer"] = float(m["shoot_timer"]) + delta
			var dist_to_goal: float = pos.distance_to(attack_goal)
			if dist_to_goal < 210.0 and (float(m["shoot_timer"]) > 0.55 or dist_to_goal < 110.0):
				var aim_y: float = GOAL_Y + randf_range(-GOAL_HALF_HEIGHT * 0.85, GOAL_HALF_HEIGHT * 0.85)
				var shot_dir: Vector2 = (Vector2(attack_goal.x, aim_y) - pos).normalized()
				var shot_speed: float = randf_range(290.0, 410.0)
				_release_puck(m, shot_dir * shot_speed)
				Globals.play_sound_at("HitSlow", pos)
			elif float(m["shoot_timer"]) > 1.4 and randf() < 0.05:
				# Wild little mite pass/dump forward
				var dump_dir: Vector2 = (attack_goal + Vector2(0.0, randf_range(-160.0, 160.0)) - pos).normalized()
				_release_puck(m, dump_dir * randf_range(220.0, 300.0))
				Globals.play_sound_at("HitSlow", pos)
		elif role == "goalie":
			target = Vector2(defend_goal.x, clampf(puck_pos.y, GOAL_Y - 40.0, GOAL_Y + 40.0))
		elif role == "defense":
			var puck_in_my_half: bool = (puck_pos.x < CENTER_POS.x + 60.0) if is_home else (puck_pos.x > CENTER_POS.x - 60.0)
			if puck_in_my_half:
				target = puck_pos + (m["wander_offset"] as Vector2) * 0.45
			else:
				var home_x: float = CENTER_POS.x - 150.0 if is_home else CENTER_POS.x + 150.0
				target = Vector2(home_x, clampf(puck_pos.y, MIN_Y + 70.0, MAX_Y - 70.0)) + (m["wander_offset"] as Vector2) * 0.5
		else:
			# Chaotic beehive swarm around the puck!
			target = puck_pos + (m["wander_offset"] as Vector2) * (0.35 if pos.distance_to(puck_pos) < 110.0 else 0.9)

		var desired: Vector2 = target - pos
		var desired_vel: Vector2 = desired.normalized() * float(m["speed"]) if desired.length() > 8.0 else Vector2.ZERO

		# Soft separation so 20 kids stay visible and bouncy
		var sep := Vector2.ZERO
		for j in range(count):
			if i == j:
				continue
			var other: Dictionary = mites[j]
			var diff: Vector2 = pos - (other["pos"] as Vector2)
			var dist_sq: float = diff.length_squared()
			if dist_sq > 0.01 and dist_sq < 676.0: # 26px radius
				var d: float = sqrt(dist_sq)
				sep += (diff / d) * (26.0 - d) * 6.0
				# Occasional playful mite tumble when colliding with opposing mite
				if other["home_jersey"] != is_home and d < 18.0 and randf() < 0.012:
					if is_carrier:
						_release_puck(m, Vector2(randf_range(-140.0, 140.0), randf_range(-140.0, 140.0)))
					m["fall_timer"] = randf_range(0.65, 1.15)
					Globals.play_sound_at("Bump", pos)

		vel = vel.lerp(desired_vel + sep, clampf(delta * 4.5, 0.0, 1.0))
		pos += vel * delta
		pos.x = clampf(pos.x, MIN_X + 18.0, MAX_X - 18.0)
		pos.y = clampf(pos.y, MIN_Y + 18.0, MAX_Y - 18.0)

		# Keep skaters from standing inside the back of the nets
		if pos.x < LEFT_GOAL_X + 6.0 and absf(pos.y - GOAL_Y) < GOAL_HALF_HEIGHT:
			pos.x = LEFT_GOAL_X + 6.0
		elif pos.x > RIGHT_GOAL_X - 6.0 and absf(pos.y - GOAL_Y) < GOAL_HALF_HEIGHT:
			pos.x = RIGHT_GOAL_X - 6.0

		if vel.length() > 10.0:
			m["facing"] = vel.normalized()
			m["step_counter"] = float(m["step_counter"]) + delta * 60.0

		m["pos"] = pos
		m["vel"] = vel
		m["node"].position = pos
		_update_mite_visual(m, false)

func _release_puck(m: Dictionary, velocity: Vector2) -> void:
	puck_carrier_idx = -1
	m["pickup_cd"] = 0.45
	m["shoot_timer"] = 0.0
	puck_vel = velocity

func _step_puck(delta: float) -> void:
	if puck_carrier_idx >= 0 and puck_carrier_idx < mites.size():
		var carrier: Dictionary = mites[puck_carrier_idx]
		var c_pos: Vector2 = carrier["pos"]
		var c_face: Vector2 = carrier["facing"]
		puck_pos = c_pos + c_face * 15.0 + Vector2(0.0, 12.0)
		puck_vel = carrier["vel"]
		if puck_node:
			puck_node.position = puck_pos
		# Opposing mites can poke the puck loose
		for idx in range(mites.size()):
			if idx == puck_carrier_idx:
				continue
			var m: Dictionary = mites[idx]
			if float(m["fall_timer"]) > 0.0 or float(m["pickup_cd"]) > 0.0:
				continue
			if m["home_jersey"] != carrier["home_jersey"] and (m["pos"] as Vector2).distance_to(puck_pos) < 22.0:
				if randf() < 0.08:
					carrier["pickup_cd"] = 0.55
					puck_carrier_idx = idx
					m["shoot_timer"] = 0.0
					Globals.play_sound_at("HitSlow", puck_pos)
					break
		return

	# Loose puck physics
	puck_pos += puck_vel * delta
	puck_vel = puck_vel.lerp(Vector2.ZERO, clampf(delta * 1.15, 0.0, 1.0))

	# Check goals in closer nets!
	if absf(puck_pos.y - GOAL_Y) <= GOAL_HALF_HEIGHT - 4.0:
		if puck_pos.x <= LEFT_GOAL_X + 6.0 and puck_pos.x >= LEFT_GOAL_X - 34.0 and puck_vel.x < 0.0:
			_on_mites_goal(false) # Away jersey team scored on left net
			return
		elif puck_pos.x >= RIGHT_GOAL_X - 6.0 and puck_pos.x <= RIGHT_GOAL_X + 34.0 and puck_vel.x > 0.0:
			_on_mites_goal(true) # Home jersey team scored on right net
			return

	# Bounce off mini-rink walls
	if puck_pos.x < MIN_X + 10.0:
		puck_pos.x = MIN_X + 10.0
		puck_vel.x = absf(puck_vel.x) * 0.8
	elif puck_pos.x > MAX_X - 10.0:
		puck_pos.x = MAX_X - 10.0
		puck_vel.x = -absf(puck_vel.x) * 0.8

	if puck_pos.y < MIN_Y + 10.0:
		puck_pos.y = MIN_Y + 10.0
		puck_vel.y = absf(puck_vel.y) * 0.8
	elif puck_pos.y > MAX_Y - 10.0:
		puck_pos.y = MAX_Y - 10.0
		puck_vel.y = -absf(puck_vel.y) * 0.8

	if puck_node:
		puck_node.position = puck_pos

	# Check puck pickup / tiny goalie save
	for idx in range(mites.size()):
		var m: Dictionary = mites[idx]
		if float(m["fall_timer"]) > 0.0 or float(m["pickup_cd"]) > 0.0:
			continue
		var dist: float = (m["pos"] as Vector2).distance_to(puck_pos)
		if dist < 24.0:
			if m["role"] == "goalie" and puck_vel.length() > 140.0:
				# Mini goalie kick save!
				var clear_dir := Vector2(1.0 if m["home_jersey"] else -1.0, randf_range(-0.7, 0.7)).normalized()
				puck_vel = clear_dir * 260.0
				m["pickup_cd"] = 0.4
				Globals.play_sound_at("Bump", puck_pos)
				break
			puck_carrier_idx = idx
			m["shoot_timer"] = 0.0
			break

func _on_mites_goal(home_jersey_scored: bool) -> void:
	puck_carrier_idx = -1
	puck_vel = Vector2.ZERO
	celly_timer = 1.9
	celly_home_scored = home_jersey_scored
	if home_jersey_scored:
		home_score += 1
	else:
		away_score += 1
	Globals.play_sound_at("GoalHome", CENTER_POS, true)
	_update_ui_text()

func _update_mite_visual(m: Dictionary, celebrating: bool) -> void:
	var sprite: Sprite2D = m["sprite"]
	var facing: Vector2 = m["facing"]
	var speed: float = (m["vel"] as Vector2).length()
	var anim_name: String = "Skate Left"
	var frame: int = 0
	var flip_h: bool = (facing.x > 0.0)

	if float(m["fall_timer"]) > 0.0:
		anim_name = "Die 1"
		frame = 0
	elif celebrating:
		anim_name = "Celly 1"
		frame = int(Globals.ticks / 8.0) % 6
	else:
		if speed > 12.0:
			frame = int(float(m["step_counter"]) / 8.0) % 6
		if absf(facing.x) < absf(facing.y):
			flip_h = false
			anim_name = "Skate Up" if facing.y < 0.0 else "Skate Down"
		else:
			anim_name = "Skate Left"

	sprite.flip_h = flip_h
	sprite.texture = Globals.skater_texture("light", anim_name)
	sprite.region_rect = Rect2(frame * 192, 0, 192, 192)
	Globals.apply_logo_offset(sprite.material, anim_name, frame, flip_h)

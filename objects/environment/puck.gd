class_name Puck extends RigidBody2D
@export var posessor: Skater
var blocklist: Dictionary[String, float] = {}
var colidable: bool = true
var initial_position: Vector2
var reset_position: Vector2 = Vector2.ZERO
var needs_reset: bool = false
var block_all: int = 0
var last_possessor: String = ""
var assist_possessor: String = ""
var last_possessor_info: Dictionary = {}
var assist_possessor_info: Dictionary = {}
var possessor_team: bool = false
var shot_on_goal_counted: bool = false
var replay_possessed: bool = false

const FAST_SHOT_MIN_DAMAGE_CHANCE: float = 0.35
const FAST_SHOT_MAX_DAMAGE_CHANCE: float = 0.85
const FAST_SHOT_CHANCE_EXCESS_RANGE: float = 500.0
const FAST_SHOT_MIN_DAMAGE: float = 12.0
const FAST_SHOT_MAX_DAMAGE: float = 30.0
const FAST_SHOT_DAMAGE_EXCESS_RANGE: float = 600.0
const PASS_THROUGH_COOLDOWN: float = 0.25

var shot_active: bool = false
var _shot_launched: bool = false
var shot_team: bool = false
var shot_shooter_name: String = ""
var pending_shot_speed: float = 0.0
var pending_shot_frames: int = 0
var excepted_skaters: Dictionary = {}
var overlapping_fast_skaters: Dictionary[int, bool] = {}
var pass_through_cooldowns: Dictionary[int, float] = {}
var _prev_collision_pos: Vector2 = Vector2.ZERO
var _has_prev_collision_pos: bool = false
var _prev_speed: float = 0.0

func _ready() -> void:
	initial_position = global_position
	reset_position = initial_position

func get_visual_position() -> Vector2:
	if has_node("Sprite"):
		return $Sprite.global_position + Vector2(4.0, 2.0)
	return global_position + Vector2(0.0, 38.0)

func home(target_pos: Vector2 = Vector2.INF) -> void:
	reset_position = target_pos if (is_finite(target_pos.x) and is_finite(target_pos.y)) else initial_position
	needs_reset = true
	if self.posessor:
		self.posessor.puck = null
	self.posessor = null
	self.freeze = false
	self.global_position = reset_position
	self.linear_velocity = Vector2.ZERO
	self.angular_velocity = 0.0
	shot_on_goal_counted = false
	last_possessor = ""
	assist_possessor = ""
	last_possessor_info = {}
	assist_possessor_info = {}
	_reset_shot_tracking()
	if has_node("Trail"):
		$Trail.clear()

func _reset_shot_tracking() -> void:
	shot_active = false
	_shot_launched = false
	shot_shooter_name = ""
	pending_shot_speed = 0.0
	pending_shot_frames = 0
	_clear_skater_collision_exceptions()
	overlapping_fast_skaters.clear()
	pass_through_cooldowns.clear()
	_has_prev_collision_pos = false
	_prev_speed = 0.0

func _can_skater_intercept(skater: Skater, puck_speed: float) -> bool:
	if not shot_active:
		return true
	if skater.home_team == shot_team:
		return true
	if skater.statbook == null:
		return true
	return puck_speed <= skater.statbook.max_block_speed

func _clear_skater_collision_exceptions() -> void:
	for skater_id in excepted_skaters:
		var skater = excepted_skaters[skater_id]
		if is_instance_valid(skater):
			remove_collision_exception_with(skater)
	excepted_skaters.clear()

func _update_skater_collision_exceptions(puck_speed: float) -> void:
	var active_exceptions: Dictionary[int, bool] = {}
	if shot_active and colidable and posessor == null:
		for node in get_tree().get_nodes_in_group("skaters"):
			if not (node is Skater):
				continue
			var skater := node as Skater
			if skater.is_out_of_play() or skater.statbook == null:
				continue
			var skater_id: int = skater.get_instance_id()
			if not _can_skater_intercept(skater, puck_speed) or overlapping_fast_skaters.has(skater_id):
				active_exceptions[skater_id] = true
				if not excepted_skaters.has(skater_id):
					add_collision_exception_with(skater)
					excepted_skaters[skater_id] = skater

	var to_remove: Array[int] = []
	for skater_id in excepted_skaters:
		if not active_exceptions.has(skater_id):
			to_remove.append(skater_id)
	for skater_id in to_remove:
		var skater = excepted_skaters[skater_id]
		if is_instance_valid(skater):
			remove_collision_exception_with(skater)
		excepted_skaters.erase(skater_id)

func _get_body_collision_circle(body: Node2D) -> Dictionary:
	var shape_node := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node != null and shape_node.shape is CircleShape2D:
		var circle := shape_node.shape as CircleShape2D
		var scale_abs := shape_node.global_scale.abs()
		var radius: float = circle.radius * maxf(scale_abs.x, scale_abs.y)
		return {"center": shape_node.global_position, "radius": radius}
	return {"center": body.global_position, "radius": 16.0}

func _check_fast_shot_pass_through(impact_speed: float) -> void:
	var puck_circle := _get_body_collision_circle(self)
	var curr_pos: Vector2 = puck_circle["center"]
	var puck_radius: float = puck_circle["radius"]
	var prev_pos: Vector2 = _prev_collision_pos if _has_prev_collision_pos else curr_pos
	var moved: bool = prev_pos.distance_squared_to(curr_pos) > 0.0001

	var still_overlapping: Dictionary[int, bool] = {}
	for skater_id in excepted_skaters:
		var skater = excepted_skaters[skater_id]
		if not is_instance_valid(skater) or not (skater is Skater):
			continue
		if skater.is_out_of_play() or skater.statbook == null:
			continue

		var skater_circle := _get_body_collision_circle(skater)
		var skater_pos: Vector2 = skater_circle["center"]
		var combined_radius: float = puck_radius + float(skater_circle["radius"])
		var radius_sq: float = combined_radius * combined_radius
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(skater_pos, prev_pos, curr_pos) if moved else curr_pos

		if closest.distance_squared_to(skater_pos) <= radius_sq:
			if not overlapping_fast_skaters.has(skater_id) and not pass_through_cooldowns.has(skater_id):
				pass_through_cooldowns[skater_id] = PASS_THROUGH_COOLDOWN
				_try_fast_shot_damage(skater, impact_speed)
		if curr_pos.distance_squared_to(skater_pos) <= radius_sq:
			still_overlapping[skater_id] = true

	overlapping_fast_skaters = still_overlapping

func _try_fast_shot_damage(skater: Skater, impact_speed: float) -> void:
	if skater.statbook == null or skater.knocked_over > Globals.ticks or skater.is_in_penalty():
		return
	var excess_speed: float = impact_speed - skater.statbook.max_block_speed
	if excess_speed <= 0.0:
		return
	var chance_t: float = clampf(excess_speed / FAST_SHOT_CHANCE_EXCESS_RANGE, 0.0, 1.0)
	var damage_chance: float = lerpf(FAST_SHOT_MIN_DAMAGE_CHANCE, FAST_SHOT_MAX_DAMAGE_CHANCE, chance_t)
	if randf() >= damage_chance:
		return

	var dmg_t: float = clampf(excess_speed / FAST_SHOT_DAMAGE_EXCESS_RANGE, 0.0, 1.0)
	var dmg: float = lerpf(FAST_SHOT_MIN_DAMAGE, FAST_SHOT_MAX_DAMAGE, dmg_t) * randf_range(0.85, 1.15)
	var target_downed_before: bool = skater.knocked_over > Globals.ticks
	skater.take_damage(dmg)
	Globals.play_sound_at("Bump", skater.global_position)

	if not target_downed_before and skater.knocked_over > Globals.ticks and shot_shooter_name != "":
		if not Globals.down_stats.has(shot_shooter_name):
			Globals.down_stats[shot_shooter_name] = 0
		Globals.down_stats[shot_shooter_name] += 1

func _process(delta: float) -> void:
	if posessor:
		freeze = true
		($PointerAbove).visible = true
		($CollisionShape2D).disabled = true
		self.global_position = posessor.global_position + posessor.facing_dir * 30.0
	else:
		($CollisionShape2D).disabled = freeze or not colidable
		($PointerAbove).visible = false
	if Globals.ticks > block_all:
		set_collision_mask_value(4, true)
	var to_erase: Array[String] = []
	for key in blocklist:
		blocklist[key] -= delta
		if blocklist[key] <= 0:
			to_erase.append(key)

	for key in to_erase:
		blocklist.erase(key)

func _physics_process(delta: float) -> void:
	if global_position.x < -200 or global_position.x > 2200 or global_position.y < -200 or global_position.y > 1400:
		home()
	_update_pointer()

	var is_replay: bool = Globals.manager != null and Globals.manager.is_replay

	if not is_replay:
		var expired_cooldowns: Array[int] = []
		for skater_id in pass_through_cooldowns:
			pass_through_cooldowns[skater_id] -= delta
			if pass_through_cooldowns[skater_id] <= 0.0:
				expired_cooldowns.append(skater_id)
		for skater_id in expired_cooldowns:
			pass_through_cooldowns.erase(skater_id)

		var current_speed: float = linear_velocity.length()
		var is_launching_shot: bool = shot_active and not _shot_launched and posessor == null and colidable
		var is_live_shot: bool = shot_active and _shot_launched and posessor == null and not freeze and colidable
		if is_live_shot:
			if pending_shot_frames > 0:
				if current_speed > 1.0:
					pending_shot_frames = 0
					pending_shot_speed = 0.0
				else:
					current_speed = maxf(current_speed, pending_shot_speed)
					pending_shot_frames -= 1
					if pending_shot_frames <= 0:
						pending_shot_speed = 0.0

			if not excepted_skaters.is_empty():
				_check_fast_shot_pass_through(maxf(current_speed, _prev_speed))
		elif not is_launching_shot:
			if not excepted_skaters.is_empty():
				_clear_skater_collision_exceptions()
			overlapping_fast_skaters.clear()
			_has_prev_collision_pos = false
			_prev_speed = 0.0

		var can_pickup_phase: bool = true
		if Globals.manager != null and not Globals.manager.is_practice and Globals.manager.anim_manager != null:
			var ph: int = Globals.manager.anim_manager.current_phase
			can_pickup_phase = (ph == AnimationManager.Phase.PLAYING or ph == AnimationManager.Phase.SHOOTOUT_ACTIVE)

		if can_pickup_phase and not posessor and not freeze and not is_launching_shot:
			var pickup_speed: float = maxf(current_speed, pending_shot_speed)
			for body in get_colliding_bodies():
				if body is Skater and (not blocklist.has(body.name)) and colidable and not body.puck and not body.is_out_of_play() and body.anim_state == "":
					var skater_id: int = body.get_instance_id()
					if pass_through_cooldowns.has(skater_id) or not _can_skater_intercept(body, pickup_speed):
						continue
					assign_possessor(body)
					break

		if shot_active and _shot_launched and posessor == null and not freeze and colidable:
			if current_speed < 1.0 and pending_shot_frames <= 0:
				_reset_shot_tracking()
			else:
				_update_skater_collision_exceptions(current_speed)
				_prev_collision_pos = _get_body_collision_circle(self)["center"]
				_has_prev_collision_pos = true
				_prev_speed = current_speed

	if has_node("Trail"):
		var is_possessed: bool = (posessor != null) or (is_replay and replay_possessed)
		$Trail.step_physics(delta, get_visual_position(), linear_velocity, is_possessed, is_replay, is_visible_in_tree(), needs_reset)
			
func _build_possessor_info(skater: Skater) -> Dictionary:
	var current_name: String = "Home AI" if skater.home_team else "Away AI"
	var p_index: int = -1
	var p_color: Color = Color(0, 0, 0, 0)
	if skater.ghost:
		current_name = skater.ghost.name
		var raw_idx = skater.ghost.get("player_index")
		if raw_idx is int and raw_idx >= 0 and raw_idx < Globals.player_colors.size():
			p_index = raw_idx
			p_color = Globals.player_colors[p_index]
		else:
			p_color = Globals.get_player_color_from_label(current_name)
	return {
		"team_index": skater.get_team_index(),
		"home_team": skater.home_team,
		"number": skater.jersey_number,
		"name": skater.skater_name,
		"player_label": current_name,
		"player_index": p_index,
		"player_color": p_color,
	}

func refresh_current_possessor_info() -> void:
	if posessor == null:
		return
	var current_info: Dictionary = _build_possessor_info(posessor)
	var current_name: String = str(current_info["player_label"])
	var same_team: bool = (posessor.home_team == possessor_team) and not last_possessor_info.is_empty()
	var same_skater: bool = same_team and int(last_possessor_info.get("number", -1)) == posessor.jersey_number
	if last_possessor_info.is_empty() or not same_skater:
		if same_team and not same_skater:
			assist_possessor = last_possessor
			assist_possessor_info = last_possessor_info.duplicate()
		elif not same_team:
			assist_possessor = ""
			assist_possessor_info = {}
	last_possessor = current_name
	last_possessor_info = current_info
	possessor_team = posessor.home_team

func assign_possessor(body: Skater) -> void:
	var prev_possessor = posessor
	needs_reset = false
	_reset_shot_tracking()

	if posessor:
		posessor.puck = null

	posessor = body
	posessor.puck = self
	var is_shootout_phase: bool = Globals.manager != null and Globals.manager.anim_manager != null and Globals.manager.anim_manager.current_phase == AnimationManager.Phase.SHOOTOUT_ACTIVE
	if posessor.ghost == null and not is_shootout_phase:
		var manager = posessor.get_parent().get_parent()
		var ghosts_node = manager.get_node_or_null("Ghosts")
		if ghosts_node:
			var closest_player = null
			var min_dist = INF
			for p in ghosts_node.get_children():
				if p.name.begins_with("Player") and p.player_index >= 0:
					if p.skater and p.skater.home_team == posessor.home_team and (p.player_index >= Globals.player_auto_swap.size() or Globals.player_auto_swap[p.player_index]):
						var dist = p.skater.global_position.distance_to(posessor.global_position)
						if dist < min_dist:
							min_dist = dist
							closest_player = p
			if closest_player:
				var old_skater = closest_player.skater
				if old_skater:
					old_skater.ghost = null
				posessor.ghost = closest_player
				closest_player.skater = posessor

	var current_info: Dictionary = _build_possessor_info(posessor)
	var current_name: String = str(current_info["player_label"])

	if prev_possessor != posessor:
		var same_team: bool = (posessor.home_team == possessor_team) and not last_possessor_info.is_empty()
		var same_skater: bool = same_team and int(last_possessor_info.get("number", -1)) == posessor.jersey_number
		if same_team and not same_skater:
			assist_possessor = last_possessor
			assist_possessor_info = last_possessor_info.duplicate()
		elif not same_team:
			assist_possessor = ""
			assist_possessor_info = {}
		last_possessor = current_name
		last_possessor_info = current_info
		possessor_team = posessor.home_team
	else:
		last_possessor = current_name
		last_possessor_info = current_info

	if Globals.manager != null and Globals.manager.has_method("on_puck_possessed"):
		Globals.manager.on_puck_possessed(posessor)

func do_shoot(vector):
	freeze = false
	apply_impulse(vector)
	var new_transform = get_transform() 
	new_transform.origin = global_position
	set_transform(new_transform)
	if shot_active:
		_shot_launched = true
		_prev_collision_pos = _get_body_collision_circle(self)["center"]
		_has_prev_collision_pos = true
		_prev_speed = maxf(linear_velocity.length(), pending_shot_speed)
		_update_skater_collision_exceptions(_prev_speed)
	if has_node("Trail"):
		$Trail.start_from_shot(get_visual_position(), vector / maxf(mass, 0.001))

func passPuck(shooter, vector):
	self.shoot(shooter, vector)
	if has_node("Trail"):
		$Trail.reset_color()

func shoot(shooter, vector) -> bool:
	if not posessor or shooter != posessor.name:
		return false
	
	refresh_current_possessor_info()
	var shooter_home_team: bool = posessor.home_team
	var shooter_name: String = posessor.get_player_name() if posessor.has_method("get_player_name") else last_possessor
	needs_reset = false
	Globals.manager.shot.emit(shooter_home_team, global_position, vector)
	posessor = null
	blocklist[shooter] = 0.25

	pass_through_cooldowns.clear()
	overlapping_fast_skaters.clear()
	var launch_speed: float = vector.length() / maxf(mass, 0.001)
	if vector.length_squared() > 0.0:
		shot_active = true
		_shot_launched = false
		shot_team = shooter_home_team
		shot_shooter_name = shooter_name
		pending_shot_speed = launch_speed
		pending_shot_frames = 2
		_prev_speed = launch_speed
		_prev_collision_pos = _get_body_collision_circle(self)["center"]
		_has_prev_collision_pos = true
		_update_skater_collision_exceptions(launch_speed)
	else:
		_reset_shot_tracking()

	if has_node("Trail"):
		if vector.length() > 100:
			$Trail.set_hue(0.1388 / (vector.length() / 100))
		else:
			$Trail.reset_color()
	
	#block_all = Globals.ticks + 1
	#get_tree().create_timer(1.0/60.0).timeout.connect(_enable_collision)
	#set_collision_mask_value(4, false)
	set_deferred("freeze", false)
	call_deferred("do_shoot", vector)
	shot_on_goal_counted = false
	return true

func _enable_collision() -> void:
	set_collision_mask_value(4, true)

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if needs_reset:
		var trans = state.get_transform()
		trans.origin = reset_position
		state.set_transform(trans)
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0
		needs_reset = false
		if has_node("Trail"):
			$Trail.clear()
		
func _update_pointer() -> void:
	if not has_node("Pointer"):
		return
	var pointer = $Pointer
	var viewport = get_viewport()
	var canvas_transform = viewport.get_canvas_transform()
	var screen_pos = canvas_transform * global_position
	var viewport_rect = viewport.get_visible_rect()

	var margin = 40.0
	var bounds = viewport_rect.grow(-margin)

	if bounds.has_point(screen_pos):
		pointer.visible = false
	else:
		pointer.visible = true

		var clamped_pos = screen_pos
		clamped_pos.x = clamp(screen_pos.x, bounds.position.x, bounds.end.x)
		clamped_pos.y = clamp(screen_pos.y, bounds.position.y, bounds.end.y)

		pointer.global_position = canvas_transform.affine_inverse() * clamped_pos

		var point_dir = (screen_pos - clamped_pos).normalized()
		if point_dir.length_squared() > 0:
			pointer.global_rotation = point_dir.angle() - PI/2

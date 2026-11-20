class_name PuckTrail extends Node2D

@export var min_speed: float = 480.0
@export var full_speed: float = 1150.0
@export var max_length: float = 560.0
@export var base_width: float = 14.0
@export var head_color: Color = Color(0.10, 0.36, 0.74, 0.85)
@export var mid_color: Color = Color(0.24, 0.66, 0.92, 0.58)
@export var tail_color: Color = Color(0.45, 0.86, 1.0, 0.0)

var base_head_color: Color = head_color
var base_mid_color: Color = mid_color
var base_tail_color: Color = tail_color

@export_range(0.05, 0.95) var mid_stop: float = 0.5

const TELEPORT_DISTANCE: float = 150.0
const BOUNCE_ANGLE_RAD: float = 0.06 # ~3.4 degrees
const COLLINEAR_DOT_THRESHOLD: float = 0.9992 # ~2.3 degrees
const MIN_POINT_SPACING: float = 0.5

var _points: Array[Vector2] = []
var _current_length: float = 0.0
var _current_alpha: float = 0.0
var _prev_pos: Vector2 = Vector2.ZERO
var _prev_vel: Vector2 = Vector2.ZERO
var _has_prev: bool = false
var _was_replay: bool = false
var _was_possessed: bool = false
var _is_retracting: bool = false


func _ready() -> void:
	top_level = true
	z_index = -1
	z_as_relative = false
	global_position = Vector2.ZERO
	global_rotation = 0.0
	global_scale = Vector2.ONE
	


func clear() -> void:
	_points.clear()
	_current_length = 0.0
	_current_alpha = 0.0
	_has_prev = false
	_prev_vel = Vector2.ZERO
	_is_retracting = false
	queue_redraw()


func start_from_shot(launch_pos: Vector2, launch_vel: Vector2) -> void:
	var speed := launch_vel.length()
	if speed <= min_speed:
		clear()
		return

	_points.clear()
	_points.append(launch_pos)
	_prev_pos = launch_pos
	_prev_vel = launch_vel
	_has_prev = true
	_was_possessed = false
	_is_retracting = false
	_current_length = _compute_target_length(speed)
	_current_alpha = _compute_target_alpha(speed)
	queue_redraw()


func step_physics(delta: float, curr_pos: Vector2, vel: Vector2, is_possessed: bool, is_replay: bool, is_puck_visible: bool, is_resetting: bool) -> void:
	if not is_puck_visible or is_resetting:
		if not _points.is_empty() or _has_prev:
			clear()
		return

	if is_replay != _was_replay:
		_was_replay = is_replay
		clear()
		_prev_pos = curr_pos
		_has_prev = true
		return

	if not _has_prev:
		_prev_pos = curr_pos
		_prev_vel = vel
		_has_prev = true
		return

	var step_vec := curr_pos - _prev_pos
	var step_dist := step_vec.length()
	if step_dist > TELEPORT_DISTANCE:
		clear()
		_prev_pos = curr_pos
		_prev_vel = vel
		_has_prev = true
		return

	var eff_vel := (step_vec / maxf(delta, 0.0001)) if is_replay else vel
	var speed := eff_vel.length()

	if is_possessed:
		if not _was_possessed and _points.size() >= 2:
			_is_retracting = true
		_was_possessed = true
		_prev_pos = curr_pos
		_prev_vel = Vector2.ZERO
		if _points.size() >= 2:
			_retract_trail(delta, 2400.0, 8.0)
		elif not _points.is_empty():
			clear()
		return

	_was_possessed = false

	if speed > min_speed:
		_is_retracting = false
		var target_length := _compute_target_length(speed)
		var target_alpha := _compute_target_alpha(speed)

		if target_length >= _current_length:
			_current_length = target_length
		else:
			_current_length = move_toward(_current_length, target_length, maxf(speed * 1.5, 900.0) * delta)

		if target_alpha >= _current_alpha:
			_current_alpha = move_toward(_current_alpha, target_alpha, 10.0 * delta)
		else:
			_current_alpha = move_toward(_current_alpha, target_alpha, 4.0 * delta)

		if _points.is_empty():
			_points.append(curr_pos)
			if step_dist > MIN_POINT_SPACING:
				_points.append(_prev_pos)
		else:
			var prev_speed := _prev_vel.length()
			var bounced := false
			var bounce_pt := Vector2.ZERO
			if prev_speed > 50.0 and speed > 50.0:
				var d1 := _prev_vel / prev_speed
				var d2 := eff_vel / speed
				if absf(d1.angle_to(d2)) > BOUNCE_ANGLE_RAD:
					bounced = true
					bounce_pt = _compute_bounce_point(_prev_pos, curr_pos, d1, d2, prev_speed, speed, delta)

			if bounced:
				_push_bounce_vertex(bounce_pt, curr_pos)
			else:
				_advance_head(curr_pos)

		_trim_to_length(_current_length)
		queue_redraw()
	else:
		if _points.size() >= 2 and _current_alpha > 0.005 and _current_length > 1.0:
			if step_dist > 0.25 and not _is_retracting:
				_advance_head(curr_pos)
			_retract_trail(delta, maxf(speed * 1.6, 1100.0), 5.5)
		elif not _points.is_empty():
			clear()

	_prev_pos = curr_pos
	_prev_vel = eff_vel


func _compute_target_length(speed: float) -> float:
	var speed_range := maxf(full_speed - min_speed, 1.0)
	var speed_t := maxf((speed - min_speed) / speed_range, 0.0)
	var len_factor := pow(minf(speed_t, 1.0), 0.85) + maxf(speed_t - 1.0, 0.0) * 0.5
	return max_length * minf(len_factor, 1.18)


func _compute_target_alpha(speed: float) -> float:
	var speed_range := maxf(full_speed - min_speed, 1.0)
	var speed_t := maxf((speed - min_speed) / speed_range, 0.0)
	return clampf(speed_t / 0.25, 0.0, 1.0)


func _compute_bounce_point(prev_pos: Vector2, curr_pos: Vector2, d1: Vector2, d2: Vector2, prev_speed: float, curr_speed: float, delta: float) -> Vector2:
	var delta_p := curr_pos - prev_pos
	var cross := d1.cross(d2)
	var max_step := maxf(prev_speed, curr_speed) * delta * 1.5 + 4.0

	if absf(cross) > 0.08:
		var t := delta_p.cross(d2) / cross
		var s := -delta_p.cross(d1) / cross
		if t >= -2.0 and s >= -2.0 and t <= max_step and s <= max_step:
			return prev_pos + d1 * maxf(t, 0.0)
	elif d1.dot(d2) < -0.9:
		var denom := maxf(delta * (prev_speed + curr_speed), 0.001)
		var f := clampf((delta_p.dot(d1) + delta * curr_speed) / denom, 0.0, 1.0)
		return prev_pos + d1 * (f * delta * prev_speed)

	return prev_pos.lerp(curr_pos, 0.5)


func _push_bounce_vertex(bounce_pt: Vector2, curr_pos: Vector2) -> void:
	if _points.is_empty():
		_points.append(curr_pos)
		if bounce_pt.distance_to(curr_pos) > MIN_POINT_SPACING:
			_points.append(bounce_pt)
		return

	if _points.size() >= 2:
		var seg_vec := _points[0] - _points[1]
		var seg_len := seg_vec.length()
		if seg_len > MIN_POINT_SPACING:
			var seg_dir := seg_vec / seg_len
			var to_bounce := bounce_pt - _points[1]
			var forward := to_bounce.dot(seg_dir)
			var perp := absf(to_bounce.cross(seg_dir))
			if forward >= seg_len - 2.0 and perp < 3.0:
				_points[0] = bounce_pt
			elif bounce_pt.distance_to(_points[0]) > MIN_POINT_SPACING:
				_points.insert(0, bounce_pt)
		elif bounce_pt.distance_to(_points[0]) > MIN_POINT_SPACING:
			_points.insert(0, bounce_pt)
	elif bounce_pt.distance_to(_points[0]) > MIN_POINT_SPACING:
		_points.insert(0, bounce_pt)

	if curr_pos.distance_to(_points[0]) > MIN_POINT_SPACING:
		_points.insert(0, curr_pos)


func _advance_head(curr_pos: Vector2) -> void:
	if _points.is_empty():
		_points.append(curr_pos)
		return

	var move_vec := curr_pos - _points[0]
	var move_dist := move_vec.length()
	if move_dist <= MIN_POINT_SPACING:
		return

	if _points.size() == 1:
		_points.insert(0, curr_pos)
		return

	var prev_seg := _points[0] - _points[1]
	var prev_len := prev_seg.length()
	if prev_len > MIN_POINT_SPACING:
		var prev_dir := prev_seg / prev_len
		var new_dir := move_vec / move_dist
		if prev_dir.dot(new_dir) > COLLINEAR_DOT_THRESHOLD:
			_points[0] = curr_pos
			return

	_points.insert(0, curr_pos)


func _trim_to_length(max_len: float) -> void:
	if _points.size() < 2 or max_len <= 0.0:
		return

	var acc: float = 0.0
	for i in range(_points.size() - 1):
		var seg_len := _points[i].distance_to(_points[i + 1])
		if acc + seg_len >= max_len:
			var remain := max_len - acc
			var t := remain / maxf(seg_len, 0.0001)
			_points[i + 1] = _points[i].lerp(_points[i + 1], t)
			_points.resize(i + 2)
			return
		acc += seg_len


func _retract_trail(delta: float, retract_speed: float, fade_rate: float) -> void:
	_current_length = maxf(_current_length - retract_speed * delta, 0.0)
	_current_alpha = maxf(_current_alpha - fade_rate * delta, 0.0)
	if _current_length <= 1.0 or _current_alpha <= 0.005 or _points.size() < 2:
		clear()
		return
	_trim_to_length(_current_length)
	queue_redraw()


func _sample_color(t: float) -> Color:
	var c: Color
	if t <= mid_stop:
		c = head_color.lerp(mid_color, t / maxf(mid_stop, 0.001))
	else:
		c = mid_color.lerp(tail_color, (t - mid_stop) / maxf(1.0 - mid_stop, 0.001))
	c.a *= _current_alpha
	return c


func _draw_tri(a: Vector2, b: Vector2, c: Vector2, ca: Color, cb: Color, cc: Color) -> void:
	if absf((b - a).cross(c - a)) < 0.01:
		return
	draw_polygon(PackedVector2Array([a, b, c]), PackedColorArray([ca, cb, cc]))

func reset_color() -> void:
	tail_color = base_tail_color
	mid_color = base_mid_color
	head_color = base_head_color
	
func set_hue(h: float) -> void:
	tail_color.h = h * 1.5
	mid_color.h = h * 1.2
	head_color.h = h
	mid_color.v += 0.1
	head_color.v += 0.1

func _draw() -> void:
	if _points.size() < 2 or _current_alpha <= 0.005:
		return

	# Clean out any near-duplicate consecutive vertices
	var clean_pts: Array[Vector2] = [_points[0]]
	for i in range(1, _points.size() - 1):
		if _points[i].distance_to(clean_pts[clean_pts.size() - 1]) > MIN_POINT_SPACING:
			clean_pts.append(_points[i])
	var tail_pt := _points[_points.size() - 1]
	if tail_pt.distance_to(clean_pts[clean_pts.size() - 1]) > MIN_POINT_SPACING:
		clean_pts.append(tail_pt)
	elif clean_pts.size() >= 2:
		clean_pts[clean_pts.size() - 1] = tail_pt

	if clean_pts.size() < 2:
		return

	# Compute total arc length and inject a gradient midpoint vertex so long straight segments still show mid_color
	var raw_total: float = 0.0
	for i in range(clean_pts.size() - 1):
		raw_total += clean_pts[i].distance_to(clean_pts[i + 1])
	if raw_total < 1.0:
		return

	var mid_dist := raw_total * mid_stop
	var pts: Array[Vector2] = [clean_pts[0]]
	var dists: Array[float] = [0.0]
	var acc: float = 0.0
	var mid_inserted: bool = false
	for i in range(clean_pts.size() - 1):
		var p0 := clean_pts[i]
		var p1 := clean_pts[i + 1]
		var seg_len := p0.distance_to(p1)
		if not mid_inserted and acc + seg_len > mid_dist + 2.0 and acc < mid_dist - 2.0:
			var frac := (mid_dist - acc) / maxf(seg_len, 0.0001)
			pts.append(p0.lerp(p1, frac))
			dists.append(mid_dist)
			mid_inserted = true
		acc += seg_len
		pts.append(p1)
		dists.append(acc)

	var n := pts.size()
	var total := dists[n - 1]
	var base_hw := base_width * 0.5

	var dirs: Array[Vector2] = []
	var norms: Array[Vector2] = []
	var lens: Array[float] = []
	dirs.resize(n - 1)
	norms.resize(n - 1)
	lens.resize(n - 1)

	for i in range(n - 1):
		var v := pts[i + 1] - pts[i]
		var l := v.length()
		var d := v / maxf(l, 0.0001)
		dirs[i] = d
		norms[i] = Vector2(-d.y, d.x)
		lens[i] = l

	var hws: Array[float] = []
	var cols: Array[Color] = []
	hws.resize(n)
	cols.resize(n)
	for i in range(n):
		var t := dists[i] / total
		hws[i] = base_hw * (1.0 - t)
		cols[i] = _sample_color(t)

	var seg_s_l: Array[Vector2] = []
	var seg_s_r: Array[Vector2] = []
	var seg_e_l: Array[Vector2] = []
	var seg_e_r: Array[Vector2] = []
	seg_s_l.resize(n - 1)
	seg_s_r.resize(n - 1)
	seg_e_l.resize(n - 1)
	seg_e_r.resize(n - 1)

	# Head base (wide end behind the puck)
	seg_s_l[0] = pts[0] + norms[0] * hws[0]
	seg_s_r[0] = pts[0] - norms[0] * hws[0]

	# Tail tip (sharp triangular point)
	seg_e_l[n - 2] = pts[n - 1]
	seg_e_r[n - 2] = pts[n - 1]

	# Interior corners (ricochet bends)
	for i in range(1, n - 1):
		var d_in := dirs[i - 1]
		var d_out := dirs[i]
		var n_in := norms[i - 1]
		var n_out := norms[i]
		var hw := hws[i]
		var col := cols[i]
		var dot_val := d_in.dot(d_out)
		var cross_val := d_in.cross(d_out)

		if dot_val > 0.9995:
			var l_pt := pts[i] + n_out * hw
			var r_pt := pts[i] - n_out * hw
			seg_e_l[i - 1] = l_pt
			seg_e_r[i - 1] = r_pt
			seg_s_l[i] = l_pt
			seg_s_r[i] = r_pt
		elif dot_val < -0.75:
			# Sharp / hairpin bounce: square off segments cleanly and add an outer corner arc
			seg_e_l[i - 1] = pts[i] + n_in * hw
			seg_e_r[i - 1] = pts[i] - n_in * hw
			seg_s_l[i] = pts[i] + n_out * hw
			seg_s_r[i] = pts[i] - n_out * hw

			var outer_in := -n_in if cross_val >= 0.0 else n_in
			var outer_out := -n_out if cross_val >= 0.0 else n_out
			var a0 := outer_in.angle()
			var a1 := outer_out.angle()
			var da := angle_difference(a0, a1)
			if absf(da) < 0.001:
				da = PI if cross_val >= 0.0 else -PI
			var mid_angle := a0 + da * 0.5
			if Vector2(cos(mid_angle), sin(mid_angle)).dot(d_in) < 0.0:
				da = (da - TAU) if da > 0.0 else (da + TAU)
			var steps := 5
			for k in range(steps):
				var t0 := a0 + da * (float(k) / float(steps))
				var t1 := a0 + da * (float(k + 1) / float(steps))
				var p_a := pts[i] + Vector2(cos(t0), sin(t0)) * hw
				var p_b := pts[i] + Vector2(cos(t1), sin(t1)) * hw
				_draw_tri(pts[i], p_a, p_b, col, col, col)
		else:
			var bis := (n_in + n_out).normalized()
			var cos_half := maxf(bis.dot(n_in), 0.2)
			var miter_len := hw / cos_half
			var proj := absf((bis * miter_len).dot(d_in))
			var max_proj := minf(lens[i - 1], lens[i]) * 0.9
			var inner_len := miter_len
			if proj > max_proj and proj > 0.0001:
				inner_len = miter_len * (max_proj / proj)

			if cross_val > 0.0:
				var inner_pt := pts[i] + bis * inner_len
				seg_e_l[i - 1] = inner_pt
				seg_s_l[i] = inner_pt
				if miter_len <= hw * 2.0:
					var outer_pt := pts[i] - bis * miter_len
					seg_e_r[i - 1] = outer_pt
					seg_s_r[i] = outer_pt
				else:
					var o1 := pts[i] - n_in * hw
					var o2 := pts[i] - n_out * hw
					seg_e_r[i - 1] = o1
					seg_s_r[i] = o2
					_draw_tri(inner_pt, o1, o2, col, col, col)
			else:
				var inner_pt := pts[i] - bis * inner_len
				seg_e_r[i - 1] = inner_pt
				seg_s_r[i] = inner_pt
				if miter_len <= hw * 2.0:
					var outer_pt := pts[i] + bis * miter_len
					seg_e_l[i - 1] = outer_pt
					seg_s_l[i] = outer_pt
				else:
					var o1 := pts[i] + n_in * hw
					var o2 := pts[i] + n_out * hw
					seg_e_l[i - 1] = o1
					seg_s_l[i] = o2
					_draw_tri(inner_pt, o1, o2, col, col, col)

	# Draw segments from head to tail
	for i in range(n - 1):
		var sl := seg_s_l[i]
		var sr := seg_s_r[i]
		var el := seg_e_l[i]
		var er := seg_e_r[i]
		var cs := cols[i]
		var ce := cols[i + 1]

		if i == n - 2:
			_draw_tri(sl, sr, el, cs, cs, ce)
		else:
			# Pick the diagonal that avoids inverted triangles on tight post-bounce segments
			var a1 := (sr - sl).cross(er - sl)
			var a2 := (er - sl).cross(el - sl)
			var b1 := (sr - sl).cross(el - sl)
			var b2 := (er - sr).cross(el - sr)
			if minf(b1, b2) > minf(a1, a2):
				_draw_tri(sl, sr, el, cs, cs, ce)
				_draw_tri(sr, er, el, cs, ce, ce)
			else:
				_draw_tri(sl, sr, er, cs, cs, ce)
				_draw_tri(sl, er, el, cs, ce, ce)

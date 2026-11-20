class_name GrabFabric
extends Node2D

const SEGMENTS: int = 10
const MIN_DRAW_DISTANCE: float = 3.0
const MAX_STRETCH_DISTANCE: float = 260.0
const OUTLINE_WIDTH: float = 1.5
const CREASE_WIDTH: float = 1.25

var _active: bool = false
var _top_pts: PackedVector2Array = PackedVector2Array()
var _bot_pts: PackedVector2Array = PackedVector2Array()
var _tip_cap: Vector2 = Vector2.ZERO
var _crease_a: PackedVector2Array = PackedVector2Array()
var _crease_b: PackedVector2Array = PackedVector2Array()
var _outline_pts: PackedVector2Array = PackedVector2Array()
var _fill_color: Color = Color.WHITE
var _crease_color: Color = Color.GRAY
var _outline_color: Color = Color.BLACK
var _time: float = 0.0


func _ready() -> void:
	top_level = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _clear() -> void:
	if _active:
		_active = false
		queue_redraw()


func _process(delta: float) -> void:
	_time += delta

	var grabber := get_parent() as RigidBody2D
	if grabber == null or not grabber.is_visible_in_tree() or not grabber.has_method("get_visual_grab_target"):
		_clear()
		return

	var grabbed: RigidBody2D = grabber.get_visual_grab_target()
	if grabbed == null or not is_instance_valid(grabbed) or not grabbed.is_visible_in_tree():
		_clear()
		return

	var grabbed_mod: Color = grabbed.get_sprite_modulate()
	var grabber_mod: Color = grabber.get_sprite_modulate()
	var effective_alpha: float = minf(grabbed_mod.a, grabber_mod.a)
	if effective_alpha <= 0.01:
		_clear()
		return

	var hand_world: Vector2 = grabber.get_grab_hand_global_position()
	var anchor: Dictionary = grabbed.get_jersey_anchor_info()
	var torso_center: Vector2 = anchor["center"]
	var torso_radii: Vector2 = anchor["radii"]

	var full_diff: Vector2 = hand_world - torso_center
	var full_dist: float = full_diff.length()
	if full_dist < MIN_DRAW_DISTANCE or full_dist > MAX_STRETCH_DISTANCE:
		_clear()
		return

	# Match Y-sort depth between grabber and grabbed skater so the fabric emerges
	# cleanly from the grabbed jersey and gets gripped by the grabber's hand.
	var grabber_z: int = grabber.z_index
	var grabbed_z: int = grabbed.z_index
	var target_z: int = maxi(grabber_z, grabbed_z)
	z_index = target_z - grabber_z

	var grabber_y: float = grabber.get_sprite_global_y()
	var grabbed_y: float = grabbed.get_sprite_global_y()
	var sort_y: float
	var fabric_behind_grabber: bool

	if grabbed_z < grabber_z:
		sort_y = grabber_y - 0.5
		fabric_behind_grabber = true
	elif grabber_z < grabbed_z:
		sort_y = grabbed_y + 0.5 if grabber_y >= grabbed_y else grabbed_y - 0.5
		fabric_behind_grabber = false
	else:
		if absf(grabber_y - grabbed_y) >= 0.25:
			sort_y = (grabber_y + grabbed_y) * 0.5
			fabric_behind_grabber = grabber_y > grabbed_y
		else:
			sort_y = maxf(grabber_y, grabbed_y) + 0.1
			fabric_behind_grabber = false

	global_position = Vector2((torso_center.x + hand_world.x) * 0.5, sort_y)

	var pull_dir: Vector2 = full_diff / full_dist
	var rx: float = maxf(torso_radii.x, 1.0)
	var ry: float = maxf(torso_radii.y, 1.0)

	# Anchor the fabric base slightly inside the grabbed torso edge facing the hand
	# so it merges seamlessly out of the jersey with no visible seam.
	var edge_denom: float = Vector2(pull_dir.x / rx, pull_dir.y / ry).length()
	var edge_dist: float = 1.0 / maxf(edge_denom, 0.001)
	var inset: float = minf(edge_dist * 0.62, maxf(full_dist - 8.0, 0.0))
	var start_world: Vector2 = torso_center + pull_dir * inset

	# Stop at the inner palm edge when drawing in front of the grabber so the
	# fabric doesn't poke past the back of their fist; extend slightly into the
	# fist when the grabber draws on top of the fabric.
	var end_world: Vector2 = hand_world if fabric_behind_grabber else (hand_world - pull_dir * 2.0)

	var span: Vector2 = end_world - start_world
	var span_dist: float = span.length()
	if span_dist < MIN_DRAW_DISTANCE:
		_clear()
		return

	var dir: Vector2 = span / span_dist
	var perp: Vector2 = Vector2(-dir.y, dir.x)

	# Clamp base half-width to fit cleanly inside the grabbed jersey's torso band.
	var perp_denom: float = Vector2(perp.x / rx, perp.y / ry).length()
	var perp_max: float = 1.0 / maxf(perp_denom, 0.001)
	var base_hw: float = clampf(perp_max * 0.85, 6.0, 10.5 * maxf(absf(grabbed.get_sprite_scale().y), 0.9))

	var stretch: float = clampf((span_dist - 14.0) / 70.0, 0.0, 1.0)
	var tip_hw: float = lerpf(2.8, 2.0, stretch)
	var pinch_exp: float = lerpf(1.3, 2.0, stretch)

	# Slight drape when slack; subtle elastic tug when pulling hard in motion.
	var sag_amt: float = (1.0 - stretch) * minf(span_dist * 0.08, 2.5)
	var rel_speed: float = (grabber.linear_velocity - grabbed.linear_velocity).length()
	var wobble_amp: float = clampf(rel_speed / 220.0, 0.0, 1.0) * stretch * 0.9
	var wobble_offset: float = sin(_time * 24.0) * wobble_amp

	_top_pts.resize(SEGMENTS + 1)
	_bot_pts.resize(SEGMENTS + 1)
	_crease_a.resize(SEGMENTS - 1)
	_crease_b.resize(SEGMENTS - 1)

	var outline_start_idx: int = 0
	var found_outline_start: bool = false

	for i in range(SEGMENTS + 1):
		var t: float = float(i) / float(SEGMENTS)
		var arch: float = sin(t * PI)
		var center_world: Vector2 = start_world + dir * (span_dist * t)
		center_world.y += arch * sag_amt
		center_world += perp * (arch * wobble_offset)

		var hw: float = tip_hw + (base_hw - tip_hw) * pow(1.0 - t, pinch_exp)
		var top_world: Vector2 = center_world + perp * hw
		var bot_world: Vector2 = center_world - perp * hw

		_top_pts[i] = to_local(top_world)
		_bot_pts[i] = to_local(bot_world)

		if not found_outline_start and i < SEGMENTS:
			var rel_torso: Vector2 = center_world - torso_center
			var norm_sq: float = (rel_torso.x / rx) * (rel_torso.x / rx) + (rel_torso.y / ry) * (rel_torso.y / ry)
			if norm_sq >= 0.75:
				outline_start_idx = i
				found_outline_start = true

		if i >= 1 and i <= SEGMENTS - 1:
			_crease_a[i - 1] = to_local(center_world - perp * (hw * 0.36))
			_crease_b[i - 1] = to_local(center_world + perp * (hw * 0.34))

	var tip_ext: float = 2.0 if fabric_behind_grabber else 1.2
	_tip_cap = to_local(end_world + dir * tip_ext)

	# Build outer silhouette outline (excluding the base edge inside the jersey).
	_outline_pts.clear()
	for i in range(outline_start_idx, SEGMENTS + 1):
		_outline_pts.append(_top_pts[i])
	_outline_pts.append(_tip_cap)
	for i in range(SEGMENTS, outline_start_idx - 1, -1):
		_outline_pts.append(_bot_pts[i])

	# Compute jersey fill, adaptive tension crease, and outline colors.
	var base_jersey: Color = grabbed.get_jersey_color()
	var lum: float = 0.299 * base_jersey.r + 0.587 * base_jersey.g + 0.114 * base_jersey.b
	var base_crease: Color = base_jersey.darkened(0.24) if lum > 0.22 else base_jersey.lightened(0.22)

	var mod_rgb := Color(grabbed_mod.r, grabbed_mod.g, grabbed_mod.b, effective_alpha)
	_fill_color = Color(
		base_jersey.r * mod_rgb.r,
		base_jersey.g * mod_rgb.g,
		base_jersey.b * mod_rgb.b,
		effective_alpha
	)
	_crease_color = Color(
		base_crease.r * mod_rgb.r,
		base_crease.g * mod_rgb.g,
		base_crease.b * mod_rgb.b,
		effective_alpha
	)
	_outline_color = Color(0.0, 0.0, 0.0, effective_alpha)

	_active = true
	queue_redraw()


func _draw() -> void:
	if not _active or _top_pts.size() < 2 or _bot_pts.size() < 2:
		return

	# Draw convex quad strip so the concave pinched silhouette never has triangulation artifacts.
	for i in range(_top_pts.size() - 1):
		var quad := PackedVector2Array([_top_pts[i], _top_pts[i + 1], _bot_pts[i + 1], _bot_pts[i]])
		draw_colored_polygon(quad, _fill_color)

	var last: int = _top_pts.size() - 1
	var tip_tri := PackedVector2Array([_top_pts[last], _tip_cap, _bot_pts[last]])
	if absf((tip_tri[1] - tip_tri[0]).cross(tip_tri[2] - tip_tri[0])) > 0.01:
		draw_colored_polygon(tip_tri, _fill_color)

	if _crease_a.size() >= 2:
		draw_polyline(_crease_a, _crease_color, CREASE_WIDTH, false)
	if _crease_b.size() >= 2:
		draw_polyline(_crease_b, _crease_color, CREASE_WIDTH, false)

	if _outline_pts.size() >= 2:
		draw_polyline(_outline_pts, _outline_color, OUTLINE_WIDTH, false)

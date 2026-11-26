class_name DroppedStick
extends Node2D

const STICK_TEXTURE_PATH: String = "res://sprites/Stick.png"

const GRAVITY: float = 560.0
const AIR_DRAG: float = 0.4
const ICE_DRAG: float = 1.35
const ICE_FRICTION: float = 85.0
const BOUNCE_DAMPING: float = 0.25
const MIN_BOUNCE_SPEED: float = 45.0

const ROTATION_EASE_POWER: float = 2.4

const RINK_MIN_X: float = 165.0
const RINK_MAX_X: float = 1855.0
const RINK_MIN_Y: float = 175.0
const RINK_MAX_Y: float = 895.0

static var _cached_texture: Texture2D = null

var sprite: Sprite2D = null
var velocity: Vector2 = Vector2.ZERO
var height: float = 0.0
var vertical_velocity: float = 0.0
var target_rotation: float = 0.0
var rotation_elapsed: float = 0.0
var rotation_duration: float = 1.35
var on_ice: bool = false
var _fade_tween: Tween = null


static func _get_stick_texture() -> Texture2D:
	if _cached_texture != null:
		return _cached_texture
	if ResourceLoader.exists(STICK_TEXTURE_PATH):
		_cached_texture = load(STICK_TEXTURE_PATH) as Texture2D
	if _cached_texture == null:
		var img := Image.new()
		if img.load(ProjectSettings.globalize_path(STICK_TEXTURE_PATH)) == OK:
			_cached_texture = ImageTexture.create_from_image(img)
	return _cached_texture


func _init() -> void:
	z_index = -1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite = Sprite2D.new()
	sprite.name = "Sprite"
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture = _get_stick_texture()
	add_child(sprite)


func launch(start_ground_pos: Vector2, outward_x: float, facing_right: bool) -> void:
	global_position = start_ground_pos
	height = randf_range(16.0, 22.0)
	vertical_velocity = randf_range(25.0, 60.0)
	on_ice = false

	var throw_dir := Vector2(outward_x * randf_range(0.45, 1.0), randf_range(-0.85, 0.85)).normalized()
	var launch_speed: float = randf_range(145.0, 225.0)
	velocity = throw_dir * launch_speed

	var spin_dir: float = -1.0 if randf() < 0.5 else 1.0
	target_rotation = spin_dir * randf_range(0.55, PI)
	rotation_elapsed = 0.0
	var est_slide_time: float = 0.32 + log((ICE_DRAG * launch_speed + ICE_FRICTION) / ICE_FRICTION) / ICE_DRAG
	rotation_duration = clampf(est_slide_time * randf_range(0.95, 1.15), 1.0, 1.8)

	if sprite != null:
		sprite.flip_h = facing_right
		sprite.rotation = 0.0
		sprite.position = Vector2(0.0, -height)


func _physics_process(delta: float) -> void:
	# Vertical drop & small clatter bounce onto the ice
	if height > 0.0 or vertical_velocity > 0.0:
		vertical_velocity -= GRAVITY * delta
		height += vertical_velocity * delta
		if height <= 0.0:
			height = 0.0
			on_ice = true
			if absf(vertical_velocity) > MIN_BOUNCE_SPEED:
				vertical_velocity = -vertical_velocity * BOUNCE_DAMPING
			else:
				vertical_velocity = 0.0

	# Horizontal slide with ice friction until coming to a stop
	if velocity.length_squared() > 0.0:
		global_position += velocity * delta

		if global_position.x < RINK_MIN_X:
			global_position.x = RINK_MIN_X
			velocity.x = absf(velocity.x) * 0.45
		elif global_position.x > RINK_MAX_X:
			global_position.x = RINK_MAX_X
			velocity.x = -absf(velocity.x) * 0.45

		if global_position.y < RINK_MIN_Y:
			global_position.y = RINK_MIN_Y
			velocity.y = absf(velocity.y) * 0.45
		elif global_position.y > RINK_MAX_Y:
			global_position.y = RINK_MAX_Y
			velocity.y = -absf(velocity.y) * 0.45

		if on_ice:
			velocity *= exp(-ICE_DRAG * delta)
			var speed: float = velocity.length()
			var next_speed: float = maxf(0.0, speed - ICE_FRICTION * delta)
			if next_speed <= 1.0:
				velocity = Vector2.ZERO
			else:
				velocity = velocity * (next_speed / speed)
		else:
			velocity *= exp(-AIR_DRAG * delta)

	if sprite != null:
		sprite.position = Vector2(0.0, -height)
		if rotation_elapsed < rotation_duration:
			rotation_elapsed = minf(rotation_duration, rotation_elapsed + delta)
			var progress: float = rotation_elapsed / maxf(rotation_duration, 0.001)
			var eased: float = 1.0 - pow(1.0 - progress, ROTATION_EASE_POWER)
			sprite.rotation = lerpf(0.0, target_rotation, eased)
		else:
			sprite.rotation = target_rotation


func fade_and_free(duration: float = 0.6) -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if duration <= 0.0 or not is_inside_tree():
		queue_free()
		return
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, duration)
	_fade_tween.tween_callback(queue_free)

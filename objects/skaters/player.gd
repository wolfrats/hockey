extends Ghost
var skater
var puck: Puck
var power: float = 0
var charge: float = 0.03
var shotDir: Vector2
@export var device_id: int = 0
var player_index: int = -1

var prev_button_state = {}
var cur_button_state = {}

var action_map = {
	"swap": JOY_BUTTON_Y,
	"check": JOY_BUTTON_B,
	"grab": JOY_BUTTON_RIGHT_SHOULDER,
	"shoot": JOY_BUTTON_X,
	"pass": JOY_BUTTON_A,
}

func _update_buttons() -> void:
	if device_id < 0:
		return
	for action in action_map.keys():
		if not prev_button_state.has(action):
			prev_button_state[action] = false
			cur_button_state[action] = false
		else:
			prev_button_state[action] = cur_button_state[action]

		cur_button_state[action] = Input.is_joy_button_pressed(device_id, action_map[action])

func set_color(c: Color) -> void:
	if has_node("Pointer"):
		$Pointer.modulate = c
	if has_node("CircleFill"):
		$CircleFill.modulate = c
	if has_node("Angle"):
		$Angle.default_color = c

func is_action_just_pressed_custom(action: String) -> bool:
	if device_id == -2 and Input.is_action_just_pressed(action):
		return true
	if device_id >= 0 and cur_button_state.has(action):
		return cur_button_state[action] and not prev_button_state[action]
	return false

func is_action_pressed_custom(action: String) -> bool:
	if device_id == -2 and Input.is_action_pressed(action):
		return true
	if device_id >= 0 and cur_button_state.has(action):
		return cur_button_state[action]
	return false

func is_action_just_released_custom(action: String) -> bool:
	if device_id == -2 and Input.is_action_just_released(action):
		return true
	if device_id >= 0 and cur_button_state.has(action):
		return not cur_button_state[action] and prev_button_state[action]
	return false

func get_axis_custom(axis_name: String) -> float:
	var val = 0.0
	if device_id == -2:
		if axis_name == "skate_x":
			val = Input.get_axis("skate_left", "skate_right")
		elif axis_name == "skate_y":
			val = Input.get_axis("skate_up", "skate_down")
	if device_id >= 0:
		var joy_val = 0.0
		if axis_name == "skate_x":
			joy_val = Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X)
		elif axis_name == "skate_y":
			joy_val = Input.get_joy_axis(device_id, JOY_AXIS_LEFT_Y)

		if abs(joy_val) > 0.2:
			if abs(joy_val) > abs(val):
				val = joy_val
	return val

func _physics_process(_delta: float) -> void:
	_update_buttons()
	visible = (skater != null)
	if not skater:
		return
	global_position = skater.global_position#global_position.lerp(skater.global_position, 0.1)
	if is_action_just_pressed_custom("swap"):
		var siblings = %Manager.get_node("Team1").get_children() if skater.home_team else %Manager.get_node("Team2").get_children() 
		if Globals.allow_goalie_control:
			var manager = %Manager
			if manager:
				for child in manager.get_children():
					if child is Goalie and child.home_team == skater.home_team:
						if not siblings.has(child):
							siblings.append(child)

		var num_siblings = siblings.size()
		var current_idx = siblings.find(skater)

		for i in range(1, num_siblings):
			var idx = (current_idx + i) % num_siblings
			var newskater = siblings[idx]
			if ("ghost" in newskater) and newskater.ghost == null:
				skater.ghost = null
				newskater.ghost = self
				skater = newskater
				return
	
func get_nearest_teammate(curSkater) -> Node2D:
	var nodes = get_tree().get_nodes_in_group("skaters")
	var closest_teammate = null
	var min_distance: float = INF
	for node in nodes:
		if node is Skater and node.home_team == curSkater.home_team and node != curSkater:
			var distance = curSkater.global_position.distance_squared_to(node.global_position)
			if distance < min_distance:
				min_distance = distance
				closest_teammate = node
	return closest_teammate

func handle(_delta: float, curSkater) -> void:
	self.skater = curSkater
	var dx = get_axis_custom("skate_x")
	var dy = get_axis_custom("skate_y")

	if is_action_just_pressed_custom("check"):
		curSkater.do_check()
		
	if is_action_just_pressed_custom("grab"):
		curSkater.do_grab()

	if is_action_just_pressed_custom("pass") and curSkater.puck:
		var teammate = get_nearest_teammate(curSkater)
		if teammate:
			var dir = ((teammate.global_position + Vector2(6, 30)) - curSkater.global_position).normalized()
			curSkater.shoot(dir, 0.2, 0)

	if is_action_just_pressed_custom("shoot"):
		shotDir = Vector2(dx, dy)
	if not is_action_pressed_custom("shoot"):
		#if ((dx != 0) or (dy != 0)): curSkater.counter += 1
		curSkater.impulse(dx, dy)
		charge = 0.03
		#power = 0
		$Power.visible = false
		$Angle.visible = false
		curSkater.charging = false
	else:
		if dx != 0 or dy != 0:
			shotDir = shotDir.lerp(Vector2(dx, dy), 0.1)
		$Power.visible = true
		$Angle.visible = true
		power += charge
		if power > 1:
			power = 1
			#charge = -charge
		elif power < 0:
			power = 0
			charge = -charge
		$Power.value = power * 100
		var style = $Power.get_theme_stylebox("fill").duplicate()
		if power < 0.33:
			style.bg_color = Color(0.2, 0.8, 0.2, 1.0)
		elif power < 0.66:
			style.bg_color = Color(0.8, 0.8, 0.2, 1.0)
		else:
			style.bg_color = Color(0.8, 0.2, 0.2, 1.0)
		$Power.add_theme_stylebox_override("fill", style)
		curSkater.charging = true
		$Angle.set_point_position(1, shotDir.normalized() * 48)
	if is_action_just_released_custom("shoot") and curSkater.puck:
		curSkater.shoot(shotDir, power)
		power = 0
		

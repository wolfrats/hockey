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
	FACE_OFF
}

var current_phase: Phase = Phase.PRE_GAME_SKATE
var phase_timer: float = 0.0
var manager: Node = null

func _ready() -> void:
	manager = get_parent()
	set_phase(Phase.PRE_GAME_SKATE)

func _process(delta: float) -> void:
	if current_phase == Phase.PLAYING:
		return

	phase_timer -= delta

	match current_phase:
		Phase.PRE_GAME_SKATE:
			var start = false
			if Input.is_action_just_pressed("ui_accept"):
				start = true
			for device in Globals.player_devices:
				if device == -2:
					if Input.is_action_just_pressed("pass") or Input.is_action_just_pressed("shoot") or Input.is_action_just_pressed("swap") or Input.is_action_just_pressed("check"):
						start = true
				else:
					if Input.is_joy_button_pressed(device, JOY_BUTTON_A) or Input.is_joy_button_pressed(device, JOY_BUTTON_X) or Input.is_joy_button_pressed(device, JOY_BUTTON_Y) or Input.is_joy_button_pressed(device, JOY_BUTTON_B):
						start = true
			if start:
				set_phase(Phase.PRE_GAME_LERP)
		Phase.PRE_GAME_LERP:
			if phase_timer <= 0:
				set_phase(Phase.FACE_OFF)
		Phase.POST_GOAL_SKATE:
			if phase_timer <= 0:
				set_phase(Phase.POST_GOAL_LERP)
		Phase.POST_GOAL_LERP:
			if phase_timer <= 0:
				set_phase(Phase.FACE_OFF)
		Phase.POST_PERIOD_SKATE_OUT:
			if phase_timer <= 0:
				set_phase(Phase.POST_PERIOD_WAIT)
		Phase.POST_PERIOD_WAIT:
			if phase_timer <= 0:
				if manager.current_period >= 3:
					manager.current_period += 1
					Globals.match_home_score = manager.home_score
					Globals.match_away_score = manager.away_score
					get_tree().change_scene_to_file("res://menu/score_recap.tscn")
				else:
					set_phase(Phase.PRE_PERIOD_SKATE)
		Phase.PRE_PERIOD_SKATE:
			var start = false
			if Input.is_action_just_pressed("ui_accept"):
				start = true
			for device in Globals.player_devices:
				if device == -2:
					if Input.is_action_just_pressed("pass") or Input.is_action_just_pressed("shoot") or Input.is_action_just_pressed("swap") or Input.is_action_just_pressed("check"):
						start = true
				else:
					if Input.is_joy_button_pressed(device, JOY_BUTTON_A) or Input.is_joy_button_pressed(device, JOY_BUTTON_X) or Input.is_joy_button_pressed(device, JOY_BUTTON_Y) or Input.is_joy_button_pressed(device, JOY_BUTTON_B):
						start = true
			if start:
				set_phase(Phase.PRE_PERIOD_LERP)
		Phase.PRE_PERIOD_LERP:
			if phase_timer <= 0:
				# Move to next period
				manager.current_period += 1
				manager.time_remaining = Globals.period_length
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

func set_phase(new_phase: Phase) -> void:
	current_phase = new_phase

	var skaters = get_tree().get_nodes_in_group("skaters")
	var pucks = get_tree().get_nodes_in_group("pucks")

	match current_phase:
		Phase.PRE_GAME_SKATE:
			phase_timer = 3.0
			var circle = true
			for s in skaters:
				if "anim_state" in s:
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
					s.anim_state = "lerping"

		Phase.PLAYING:
			($"../../Boards/BoardsCollision").disabled = false
			for s in skaters:
				if "anim_state" in s:
					s.anim_state = ""

			for p in pucks:
				p.visible = true
				if "colidable" in p:
					p.colidable = true

		Phase.FACE_OFF:
			phase_timer = randf_range(5.0, 10.0)
			for s in skaters:
				if "anim_state" in s:
					s.anim_state = "face_off"
				if s.has_method("home"):
					s.home()
			for p in pucks:
				p.visible = true
				p.freeze = true
				if "colidable" in p:
					p.colidable = true
				p.home()
				# Set puck to center of the rink
				p.global_position = Vector2(1005.5, 509)

		Phase.POST_GOAL_SKATE:
			phase_timer = 2.0
			for s in skaters:
				if "anim_state" in s:
					s.anim_state = "skating_around"

		Phase.POST_GOAL_LERP:
			phase_timer = 1.5
			for s in skaters:
				if "anim_state" in s:
					s.anim_state = "lerping"
			for p in pucks:
				p.visible = false
				p.freeze = true
				if "colidable" in p:
					p.colidable = false

		Phase.POST_PERIOD_SKATE_OUT:
			phase_timer = 2.5
			for s in skaters:
				if "anim_state" in s:
					s.anim_state = "skating_out"
			($"../../Boards/BoardsCollision").disabled = true
			for p in pucks:
				p.visible = false
				p.freeze = true
				if "colidable" in p:
					p.colidable = false

		Phase.POST_PERIOD_WAIT:
			phase_timer = 3.5
			# Wait a bit before coming back

		Phase.PRE_PERIOD_SKATE:
			phase_timer = 4.0
			var circle = true
			for s in skaters:
				if "anim_state" in s:
					s.anim_state = "skating_circle" if circle else "skating_figure8"
					circle = not circle

		Phase.PRE_PERIOD_LERP:
			phase_timer = 1.5
			for s in skaters:
				if "anim_state" in s:
					s.anim_state = "lerping"

func on_goal_scored() -> void:
	if current_phase == Phase.PLAYING:
		set_phase(Phase.POST_GOAL_SKATE)

func on_period_end() -> void:
	if current_phase == Phase.PLAYING:
		set_phase(Phase.POST_PERIOD_SKATE_OUT)

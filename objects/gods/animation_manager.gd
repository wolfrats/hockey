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
	PRE_PERIOD_LERP
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
			if phase_timer <= 0:
				set_phase(Phase.PRE_GAME_LERP)
		Phase.PRE_GAME_LERP:
			if phase_timer <= 0:
				set_phase(Phase.PLAYING)
		Phase.POST_GOAL_SKATE:
			if phase_timer <= 0:
				set_phase(Phase.POST_GOAL_LERP)
		Phase.POST_GOAL_LERP:
			if phase_timer <= 0:
				set_phase(Phase.PLAYING)
		Phase.POST_PERIOD_SKATE_OUT:
			if phase_timer <= 0:
				set_phase(Phase.POST_PERIOD_WAIT)
		Phase.POST_PERIOD_WAIT:
			if phase_timer <= 0:
				set_phase(Phase.PRE_PERIOD_LERP)
		Phase.PRE_PERIOD_LERP:
			if phase_timer <= 0:
				# Move to next period
				manager.current_period += 1
				if manager.current_period > 3:
					manager.current_period = 3
					manager.time_remaining = 0
				else:
					manager.time_remaining = Globals.period_length
				set_phase(Phase.PLAYING)

func set_phase(new_phase: Phase) -> void:
	current_phase = new_phase

	var skaters = get_tree().get_nodes_in_group("skaters")
	var pucks = get_tree().get_nodes_in_group("pucks")

	match current_phase:
		Phase.PRE_GAME_SKATE:
			phase_timer = 3.0
			for s in skaters:
				if "anim_state" in s:
					s.anim_state = "skating_around"
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
			for s in skaters:
				if "anim_state" in s:
					s.anim_state = ""
				if s.has_method("home"):
					s.home()
			for p in pucks:
				p.visible = true
				p.freeze = false
				if "colidable" in p:
					p.colidable = true
				p.home()

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
			for p in pucks:
				p.visible = false
				p.freeze = true
				if "colidable" in p:
					p.colidable = false

		Phase.POST_PERIOD_WAIT:
			phase_timer = 1.5
			# Wait a bit before coming back

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

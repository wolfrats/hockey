extends Node2D

var home_score: int = 0
var away_score: int = 0
var current_period: int = 1
var time_remaining: float = 0.0

@export var is_practice: bool = false

var ui_layer: CanvasLayer
var score_label: Label
var timer_label: Label
var period_label: Label

func _ready() -> void:
	if not is_practice:
		time_remaining = Globals.period_length
		setup_ui()

func _process(delta: float) -> void:
	if not is_practice:
		time_remaining -= delta
		if time_remaining <= 0:
			current_period += 1
			if current_period > 3:
				# Game Over logic could go here, for now just reset to 3rd period 0:00
				current_period = 3
				time_remaining = 0
			else:
				time_remaining = Globals.period_length

		update_ui()

func setup_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	score_label = Label.new()
	score_label.text = "0 - 0"
	score_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 48)
	ui_layer.add_child(score_label)

	period_label = Label.new()
	period_label.text = "Period 1"
	period_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	period_label.add_theme_font_size_override("font_size", 32)
	period_label.position = Vector2(20, 20)
	ui_layer.add_child(period_label)

	timer_label = Label.new()
	timer_label.text = "2:00"
	timer_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	timer_label.add_theme_font_size_override("font_size", 32)
	timer_label.position = Vector2(-20, 20)
	timer_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ui_layer.add_child(timer_label)

func update_ui() -> void:
	score_label.text = "%d - %d" % [home_score, away_score]
	period_label.text = "Period %d" % current_period

	var mins = int(time_remaining) / 60
	var secs = int(time_remaining) % 60
	timer_label.text = "%d:%02d" % [mins, secs]

func goal_scored(goal_name: String) -> void:
	if goal_name == "HomeGoal":
		away_score += 1
	elif goal_name == "AwayGoal":
		home_score += 1

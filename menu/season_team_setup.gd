extends Control

const TIME_MAP = [
	["30s", 30],
	["1 min", 60],
	["2 min", 120],
	["3 min", 180],
	["4 min", 240]
]

const SERIES_OPTIONS = [1, 3, 5, 7]

var team_idx: int = 0
var max_teams: int = 32
var series_opt_idx: int = 1
var series_btn: Button = null

@onready var team_label = %TeamLabel
@onready var head = %Head
@onready var body = %Body
@onready var foot = %Foot

func _ready() -> void:
	team_idx = clampi(Globals.home_team_index, 0, StatBook.TEAMS.size() - 3)
	Globals.period_length = TIME_MAP[2][1]

	series_btn = Button.new()
	series_btn.custom_minimum_size = Vector2(320, 44)
	series_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	series_btn.pressed.connect(_on_series_cycle_pressed)
	$VBoxContainer.add_child(series_btn)
	$VBoxContainer.move_child(series_btn, $VBoxContainer/Buttons.get_index())
	_update_series_label()

	$VBoxContainer/Buttons/Start.grab_focus()
	update_ui()

func _update_series_label() -> void:
	if series_btn:
		var games: int = SERIES_OPTIONS[series_opt_idx]
		series_btn.text = "Playoff Series: Single Elimination" if games == 1 else ("Playoff Series: Best of %d" % games)

func _on_series_cycle_pressed() -> void:
	series_opt_idx = (series_opt_idx + 1) % SERIES_OPTIONS.size()
	_update_series_label()

func update_ui() -> void:
	var team = StatBook.TEAMS[team_idx]

	team_label.text = team["name"]
	head.color = team["head_color"]
	body.color = team["body_color"]
	foot.color = team["foot_color"]

func _on_prev_pressed() -> void:
	team_idx -= 1
	if team_idx < 0:
		team_idx = StatBook.TEAMS.size() - 3 # skip non-league teams (Pinkertons, Bananas)
	update_ui()

func _on_next_pressed() -> void:
	team_idx += 1
	if team_idx >= StatBook.TEAMS.size() - 2: # skip non-league teams (Pinkertons, Bananas)
		team_idx = 0
	update_ui()

func _on_start_pressed() -> void:
	Globals.home_team_index = team_idx
	Globals.save_settings()
	Season.new_season(team_idx, SERIES_OPTIONS[series_opt_idx], Globals.period_length)
	Season.season_on = true
	get_tree().change_scene_to_file("res://menu/season_hub.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://menu/main_menu.tscn")

func _on_time_value_changed(value: float) -> void:
	var setting = TIME_MAP[int(value)]
	%TimeLabel.text = "Period Length: " + setting[0]
	Globals.period_length = setting[1]

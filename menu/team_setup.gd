extends Control

var home_idx: int = 0
var away_idx: int = 1

@onready var home_label = %HomeLabel
@onready var home_head = %HomeHead
@onready var home_body = %HomeBody
@onready var home_foot = %HomeFoot

@onready var away_label = %AwayLabel
@onready var away_head = %AwayHead
@onready var away_body = %AwayBody
@onready var away_foot = %AwayFoot

func _ready() -> void:
	$VBoxContainer/Buttons/Play.grab_focus()
	update_ui()

func update_ui() -> void:
	var home_team = StatBook.TEAMS[home_idx]
	var away_team = StatBook.TEAMS[away_idx]

	home_label.text = home_team["name"]
	home_head.color = home_team["head_color"]
	home_body.color = home_team["body_color"]
	home_foot.color = home_team["foot_color"]

	away_label.text = away_team["name"]
	away_head.color = away_team["head_color"]
	away_body.color = away_team["body_color"]
	away_foot.color = away_team["foot_color"]

func _on_home_prev_pressed() -> void:
	home_idx -= 1
	if home_idx < 0:
		home_idx = StatBook.TEAMS.size() - 1
	update_ui()

func _on_home_next_pressed() -> void:
	home_idx += 1
	if home_idx >= StatBook.TEAMS.size():
		home_idx = 0
	update_ui()

func _on_away_prev_pressed() -> void:
	away_idx -= 1
	if away_idx < 0:
		away_idx = StatBook.TEAMS.size() - 1
	update_ui()

func _on_away_next_pressed() -> void:
	away_idx += 1
	if away_idx >= StatBook.TEAMS.size():
		away_idx = 0
	update_ui()

func _on_play_pressed() -> void:
	Globals.home_team_index = home_idx
	Globals.away_team_index = away_idx
	Globals.update_team_textures()
	get_tree().change_scene_to_file("res://objects/environment/match_rink.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://menu/main_menu.tscn")

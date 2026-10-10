extends Control

var home_team: int = -1
var away_team: int = -1
var is_season_over: bool = false

@onready var standings_container = %StandingsContainer
@onready var matchup_label = %MatchupLabel
@onready var matchup_title = %Title

func _ready() -> void:
	Season.season_on = true
	$VBoxContainer/Buttons/Play.grab_focus()
	update_standings()
	update_matchup()
	#update_schedule()


func update_standings() -> void:
	for child in standings_container.get_children():
		child.queue_free()

	var teams_records = []
	var standings = Season.season_data["standings"]

	for team_id_str in standings:
		var w = standings[team_id_str]["wins"]
		var l = standings[team_id_str]["losses"]
		teams_records.append({
			"id": int(team_id_str),
			"wins": w,
			"losses": l,
			"pts": w * 2
		})

	teams_records.sort_custom(func(a, b): return a["pts"] > b["pts"])

	for i in range(teams_records.size()):
		var tr = teams_records[i]
		var team_name = StatBook.TEAMS[tr["id"]]["name"]
		var lbl = Label.new()
		var text = "%d. %s - %d W, %d L (%d PTS)"
		lbl.text = text % [i + 1, team_name, tr["wins"], tr["losses"], tr["pts"]]

		if tr["id"] == int(Season.season_data["player_team"]):
			lbl.add_theme_color_override("font_color", Color(1, 1, 0))

		standings_container.add_child(lbl)

func update_matchup() -> void:
	var week = int(Season.season_data["current_week"])
	if week >= Season.season_data["schedule"].size():
		is_season_over = true
		matchup_title.text = "Season Finished!"
		matchup_label.text = "All 28 weeks completed."
		%Play.visible = false
		return

	matchup_title.text = "Week %d Matchup" % (week + 1)

	var matches = Season.season_data["schedule"][week]
	var player_team = int(Season.season_data["player_team"])

	for m in matches:
		var h = int(m[0])
		var a = int(m[1])
		if h == player_team or a == player_team:
			home_team = h
			away_team = a
			break

	var h_name = StatBook.TEAMS[home_team]["name"]
	var a_name = StatBook.TEAMS[away_team]["name"]
	matchup_label.text = "%s (Away)\nvs\n%s (Home)" % [a_name, h_name]

func _on_back_pressed() -> void:
	Season.season_on = false
	get_tree().change_scene_to_file("res://menu/main_menu.tscn")

func _on_play_pressed() -> void:
	if is_season_over:
		return

	Globals.home_team_index = home_team
	Globals.away_team_index = away_team

	var player_team = int(Season.season_data["player_team"])
	var good_teams = Season.season_data["good_teams"]

	if home_team == player_team:
		Globals.home_ai_difficulty = 0 # Doesn't matter, player controls
		Globals.away_ai_difficulty = 1 if away_team in good_teams else 0
	else:
		Globals.home_ai_difficulty = 1 if home_team in good_teams else 0
		Globals.away_ai_difficulty = 0

	Globals.update_team_textures()
	get_tree().change_scene_to_file("res://objects/environment/match_rink.tscn")

func _on_reset_pressed() -> void:
	var dir = DirAccess.open("user://")
	if dir.file_exists("season.json"):
		dir.remove("season.json")
	Season.season_on = false
	Season.season_data.clear()
	get_tree().change_scene_to_file("res://menu/main_menu.tscn")

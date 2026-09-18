extends Control

@onready var score_label: Label = %ScoreLabel
@onready var stats_container: VBoxContainer = %StatsContainer

func _ready() -> void:
	$CenterContainer/VBoxContainer/Buttons/Rematch.grab_focus()
	
	score_label.text = "%d - %d" % [Globals.match_home_score, Globals.match_away_score]
	
	var all_players = []
	for p in Globals.scorer_stats.keys():
		if not all_players.has(p):
			all_players.append(p)
	for p in Globals.assist_stats.keys():
		if not all_players.has(p):
			all_players.append(p)
			
	if all_players.size() == 0:
		var empty_label = Label.new()
		empty_label.text = "No stats recorded."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats_container.add_child(empty_label)
	else:
		for p in all_players:
			var g = 0
			if Globals.scorer_stats.has(p):
				g = Globals.scorer_stats[p]
			var a = 0
			if Globals.assist_stats.has(p):
				a = Globals.assist_stats[p]
			
			var display_name = p
			if display_name == "Player":
				display_name = "Player 1"
			elif display_name.begins_with("Player"):
				display_name = "Player " + display_name.trim_prefix("Player")
			var display_color_code = Globals.player_colors_map.get(display_name, "white")
			var stat_label = RichTextLabel.new()
			stat_label.bbcode_enabled = true
			stat_label.text = "[color=#%s]%s[/color]: %d Goals, %d Assists" % [display_color_code, display_name, g, a]
			stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			stats_container.add_child(stat_label)

func _on_rematch_pressed() -> void:
	Globals.scorer_stats.clear()
	Globals.assist_stats.clear()
	Globals.match_home_score = 0
	Globals.match_away_score = 0
	get_tree().change_scene_to_file("res://objects/environment/match_rink.tscn")

func _on_menu_pressed() -> void:
	Globals.scorer_stats.clear()
	Globals.assist_stats.clear()
	Globals.match_home_score = 0
	Globals.match_away_score = 0
	get_tree().change_scene_to_file("res://menu/main_menu.tscn")

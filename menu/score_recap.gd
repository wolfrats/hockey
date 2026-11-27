extends Control

@onready var score_label: Label = %ScoreLabel
@onready var stats_container: VBoxContainer = %StatsContainer

func _ready() -> void:
	if Season.season_on:
		$CenterContainer/VBoxContainer/Buttons/Rematch.visible = false
		$CenterContainer/VBoxContainer/Buttons/Menu.visible = false
		$CenterContainer/VBoxContainer/Buttons/Continue.visible = true
		$CenterContainer/VBoxContainer/Buttons/Continue.grab_focus()
	else:
		$CenterContainer/VBoxContainer/Buttons/Rematch.visible = true
		$CenterContainer/VBoxContainer/Buttons/Menu.visible = true
		$CenterContainer/VBoxContainer/Buttons/Continue.visible = false
		$CenterContainer/VBoxContainer/Buttons/Rematch.grab_focus()

	var home_name: String = StatBook.TEAMS[Globals.home_team_index]["name"]
	var away_name: String = StatBook.TEAMS[Globals.away_team_index]["name"]
	var suffix: String = ""
	if Globals.match_ended_in == "OT":
		suffix = " (OT)"
	elif Globals.match_ended_in == "SO":
		suffix = " (SO %d-%d)" % [Globals.match_shootout_home, Globals.match_shootout_away]
	score_label.text = "%s %d - %d %s%s" % [home_name, Globals.match_home_score, Globals.match_away_score, away_name, suffix]

	# Widen scroll container slightly so named box scores fit nicely
	var scroll := stats_container.get_parent() as ScrollContainer
	if scroll:
		scroll.custom_minimum_size = Vector2(760, 280)

	var all_players = []
	for dict in [
		Globals.scorer_stats, Globals.assist_stats, Globals.shot_stats,
		Globals.faceoff_won_stats, Globals.penalty_stats, Globals.check_stats,
		Globals.hit_stats, Globals.down_stats
	]:
		for p in dict.keys():
			if not all_players.has(p):
				all_players.append(p)

	if all_players.size() == 0 and Globals.skater_match_stats.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No stats recorded."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats_container.add_child(empty_label)
		return

	if all_players.size() > 0:
		var p_hdr := Label.new()
		p_hdr.text = "-- Player Summary --"
		p_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p_hdr.add_theme_color_override("font_color", Color(0.65, 0.8, 1.0))
		stats_container.add_child(p_hdr)

		for p in all_players:
			var g: int = int(Globals.scorer_stats.get(p, 0))
			var a: int = int(Globals.assist_stats.get(p, 0))
			var s: int = int(Globals.shot_stats.get(p, 0))
			var f: int = int(Globals.faceoff_won_stats.get(p, 0))
			var pen: int = int(Globals.penalty_stats.get(p, 0))
			var checks: int = int(Globals.check_stats.get(p, 0))
			var hits: int = int(Globals.hit_stats.get(p, 0))
			var downs: int = int(Globals.down_stats.get(p, 0))

			var display_name = p
			if display_name == "Player":
				display_name = "Player 1"
			elif display_name.begins_with("Player"):
				display_name = "Player " + display_name.trim_prefix("Player")
			var display_color_code = Globals.player_colors_map.get(display_name, "ffffff")
			var stat_label = RichTextLabel.new()
			stat_label.fit_content = true
			stat_label.bbcode_enabled = true
			stat_label.text = (
				"[color=#%s]%s[/color]: %dG, %dA, %d SOG, %d FO, %d PIM, %d CHK, %d HIT, %d KO" %
				[display_color_code, display_name, g, a, s, f, pen, checks, hits, downs]
			)
			stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			stats_container.add_child(stat_label)

	if not Globals.skater_match_stats.is_empty():
		var s_hdr := Label.new()
		s_hdr.text = "\n-- Skater Box Score --"
		s_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s_hdr.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
		stats_container.add_child(s_hdr)

		var rows: Array = []
		for key in Globals.skater_match_stats:
			rows.append(Globals.skater_match_stats[key])
		rows.sort_custom(func(a, b):
			var pa: int = int(a.get("goals", 0)) + int(a.get("assists", 0))
			var pb: int = int(b.get("goals", 0)) + int(b.get("assists", 0))
			if pa != pb:
				return pa > pb
			if int(a.get("goals", 0)) != int(b.get("goals", 0)):
				return int(a.get("goals", 0)) > int(b.get("goals", 0))
			if int(a.get("saves", 0)) != int(b.get("saves", 0)):
				return int(a.get("saves", 0)) > int(b.get("saves", 0))
			return int(a.get("hits", 0)) > int(b.get("hits", 0))
		)

		for row in rows:
			var tid: int = int(row.get("team_index", -1))
			var tname: String = StatBook.TEAMS[tid]["name"] if (tid >= 0 and tid < StatBook.TEAMS.size()) else "Team"
			var num: int = int(row.get("number", 0))
			var sname: String = str(row.get("name", "Skater"))
			var g: int = int(row.get("goals", 0))
			var a: int = int(row.get("assists", 0))
			var sh: int = int(row.get("shots", 0))
			var h: int = int(row.get("hits", 0))
			var p_cnt: int = int(row.get("penalties", 0))
			var fw: int = int(row.get("fights_won", 0))
			var sv: int = int(row.get("saves", 0))

			var lbl := Label.new()
			if sv > 0 and g == 0 and a == 0 and sh == 0 and h == 0 and p_cnt == 0 and fw == 0:
				lbl.text = "#%d %s (%s) — %d SV" % [num, sname, tname, sv]
			else:
				var sv_str: String = (" | %d SV" % sv) if sv > 0 else ""
				var fw_str: String = (", %d Fight W" % fw) if fw > 0 else ""
				lbl.text = "#%d %s (%s) — %dG %dA | %d SOG | %d HIT | %d PIM%s%s" % [
					num, sname, tname, g, a, sh, h, p_cnt, sv_str, fw_str
				]
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			stats_container.add_child(lbl)

func _on_rematch_pressed() -> void:
	Globals.clear_match_stats()
	get_tree().change_scene_to_file("res://objects/environment/match_rink.tscn")

func _on_menu_pressed() -> void:
	Globals.clear_match_stats()
	get_tree().change_scene_to_file("res://menu/main_menu.tscn")

func _on_continue_pressed() -> void:
	Season.merge_match_skater_stats(Globals.skater_match_stats)
	if Season.is_playoff_match():
		Season.record_playoff_game(
			Globals.home_team_index,
			Globals.away_team_index,
			Globals.match_home_score,
			Globals.match_away_score
		)
	else:
		Season.record_match(
			Globals.home_team_index,
			Globals.away_team_index,
			Globals.match_home_score,
			Globals.match_away_score,
			Globals.match_ended_in
		)
		Season.simulate_other_matches()
		Season.advance_week()

	Globals.clear_match_stats()
	get_tree().change_scene_to_file("res://menu/season_hub.tscn")

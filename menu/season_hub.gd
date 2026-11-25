extends Control

var home_team: int = -1
var away_team: int = -1
var is_season_over: bool = false
var current_tab: String = "overview" # "overview", "bracket", "leaders", "roster"
var leaders_sort: String = "points"

@onready var standings_container = %StandingsContainer
@onready var matchup_label = %MatchupLabel
@onready var matchup_title = %Title

var tab_bar: HBoxContainer = null
var overview_hbox: HBoxContainer = null
var alt_panel: ScrollContainer = null
var alt_vbox: VBoxContainer = null
var sim_btn: Button = null

func _ready() -> void:
	Season.season_on = true
	if Season.season_data.has("period_length"):
		Globals.period_length = float(Season.season_data["period_length"])

	overview_hbox = $VBoxContainer/HBoxContainer
	_build_extra_ui()
	_refresh_all()
	$VBoxContainer/Buttons/Play.grab_focus()

func _build_extra_ui() -> void:
	tab_bar = HBoxContainer.new()
	tab_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_bar.add_theme_constant_override("separation", 12)
	$VBoxContainer.add_child(tab_bar)
	$VBoxContainer.move_child(tab_bar, 1)

	for pair in [
		["overview", "Overview"],
		["bracket", "Playoff Bracket"],
		["leaders", "League Leaders"],
		["roster", "My Roster"]
	]:
		var btn := Button.new()
		btn.text = pair[1]
		btn.custom_minimum_size = Vector2(170, 40)
		var tab_id: String = pair[0]
		btn.pressed.connect(func(): _switch_tab(tab_id))
		tab_bar.add_child(btn)

	alt_panel = ScrollContainer.new()
	alt_panel.custom_minimum_size = Vector2(960, 340)
	alt_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	alt_panel.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	alt_panel.visible = false
	$VBoxContainer.add_child(alt_panel)
	$VBoxContainer.move_child(alt_panel, $VBoxContainer/Buttons.get_index())

	alt_vbox = VBoxContainer.new()
	alt_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alt_vbox.add_theme_constant_override("separation", 8)
	alt_panel.add_child(alt_vbox)

	sim_btn = Button.new()
	sim_btn.text = "Sim Week"
	sim_btn.custom_minimum_size = Vector2(180, 60)
	sim_btn.pressed.connect(_on_sim_pressed)
	$VBoxContainer/Buttons.add_child(sim_btn)
	$VBoxContainer/Buttons.move_child(sim_btn, %Play.get_index())

func _switch_tab(tab_id: String) -> void:
	current_tab = tab_id
	overview_hbox.visible = (tab_id == "overview")
	alt_panel.visible = (tab_id != "overview")
	if tab_id == "bracket":
		_populate_bracket_tab()
	elif tab_id == "leaders":
		_populate_leaders_tab()
	elif tab_id == "roster":
		_populate_roster_tab()
	else:
		update_standings()
		update_matchup()
		update_schedule()

func _refresh_all() -> void:
	update_standings()
	update_matchup()
	update_schedule()
	if current_tab == "bracket":
		_populate_bracket_tab()
	elif current_tab == "leaders":
		_populate_leaders_tab()
	elif current_tab == "roster":
		_populate_roster_tab()

func _clear_container(c: Node) -> void:
	for child in c.get_children():
		child.queue_free()

func update_schedule() -> void:
	var schedule_container = %ScheduleContainer
	_clear_container(schedule_container)

	var phase: String = str(Season.season_data.get("phase", "regular"))
	var sched_title := $VBoxContainer/HBoxContainer/ScheduleBox/Title as Label
	if phase == "playoffs" or phase == "champion":
		if sched_title:
			sched_title.text = "Active Bracket"
		var playoffs: Dictionary = Season.season_data.get("playoffs", {})
		var rounds: Array = playoffs.get("rounds", [])
		var r: int = int(playoffs.get("round", 0))
		if r >= 0 and r < rounds.size():
			var round_lbl := Label.new()
			round_lbl.text = Season.ROUND_NAMES[clampi(r, 0, Season.ROUND_NAMES.size() - 1)]
			round_lbl.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0))
			schedule_container.add_child(round_lbl)
			var player_team: int = int(Season.season_data["player_team"])
			for s in rounds[r]:
				var h_name: String = StatBook.TEAMS[int(s["high"])]["name"]
				var l_name: String = StatBook.TEAMS[int(s["low"])]["name"]
				var lbl := Label.new()
				lbl.text = "%s (%d) vs %s (%d)" % [h_name, int(s["high_wins"]), l_name, int(s["low_wins"])]
				if int(s["high"]) == player_team or int(s["low"]) == player_team:
					lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.2))
				elif int(s.get("winner", -1)) != -1:
					lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
				schedule_container.add_child(lbl)
		return

	if sched_title:
		sched_title.text = "Schedule"
	var player_team = int(Season.season_data["player_team"])
	var schedule = Season.season_data["schedule"]

	for w in range(schedule.size()):
		var matches = schedule[w]
		var opp = -1
		var is_home = false

		for m in matches:
			var h = int(m[0])
			var a = int(m[1])
			if h == player_team:
				opp = a
				is_home = true
				break
			elif a == player_team:
				opp = h
				is_home = false
				break

		if opp != -1:
			var lbl = Label.new()
			var opp_name = StatBook.TEAMS[opp]["name"]
			if is_home:
				lbl.text = "Week %d: vs %s (Home)" % [w + 1, opp_name]
			else:
				lbl.text = "Week %d: @ %s (Away)" % [w + 1, opp_name]

			if w < int(Season.season_data["current_week"]):
				lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			elif w == int(Season.season_data["current_week"]):
				lbl.add_theme_color_override("font_color", Color(1, 1, 0))

			schedule_container.add_child(lbl)

func update_standings() -> void:
	_clear_container(standings_container)

	var teams_records: Array = Season.get_sorted_standings()
	var divisions = {
		"city": [],
		"coastal": [],
		"ocean": [],
		"middle": []
	}
	for i in range(teams_records.size()):
		var tr = teams_records[i]
		var team_data = StatBook.TEAMS[tr["id"]]
		var division = team_data.get("division", "")
		if divisions.has(division):
			divisions[division].append({"record": tr, "rank": i + 1, "name": team_data["name"]})

	for div_name in ["city", "coastal", "ocean", "middle"]:
		if divisions[div_name].is_empty():
			continue

		var div_header = Label.new()
		div_header.text = "-- " + div_name.capitalize() + " Division (Top 4 Playoff) --"
		div_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		div_header.add_theme_color_override("font_color", Color(0.6, 0.6, 1.0))
		standings_container.add_child(div_header)

		var div_rank = 1
		for team in divisions[div_name]:
			var lbl = Label.new()
			var r = team["record"]
			var rank = team["rank"]
			var t_name = team["name"]
			var po_mark: String = "*" if div_rank <= 4 else " "
			var otl_total: int = int(r.get("otl", 0)) + int(r.get("ties", 0))
			lbl.text = "%s%d. %s — %d-%d-%d (%d PTS) [#%d]" % [
				po_mark, div_rank, t_name, r["wins"], r["losses"], otl_total, r["pts"], rank
			]

			if r["id"] == int(Season.season_data["player_team"]):
				lbl.add_theme_color_override("font_color", Color(1, 1, 0))
			elif div_rank <= 4:
				lbl.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))

			standings_container.add_child(lbl)
			div_rank += 1

func update_matchup() -> void:
	var phase: String = str(Season.season_data.get("phase", "regular"))
	var player_team: int = int(Season.season_data["player_team"])

	if phase == "champion":
		is_season_over = true
		var champ: int = int(Season.season_data.get("playoffs", {}).get("champion", -1))
		var champ_name: String = StatBook.TEAMS[champ]["name"] if champ >= 0 else "Unknown"
		if champ == player_team:
			matchup_title.text = "CUP CHAMPIONS!"
			matchup_label.text = "%s win the\nOpen Practice Cup!" % champ_name
		else:
			matchup_title.text = "Season Complete"
			matchup_label.text = "Champion:\n%s" % champ_name
		%Play.visible = false
		if sim_btn:
			sim_btn.visible = false
		return

	if phase == "playoffs":
		var active: Dictionary = Season.get_player_active_series()
		var playoffs: Dictionary = Season.season_data.get("playoffs", {})
		var r: int = int(playoffs.get("round", 0))
		var round_name: String = Season.ROUND_NAMES[clampi(r, 0, Season.ROUND_NAMES.size() - 1)]

		if active.is_empty():
			is_season_over = false
			matchup_title.text = round_name
			matchup_label.text = "Your team is out of\nthe playoffs.\nSim to crown a champ!"
			%Play.visible = false
			if sim_btn:
				sim_btn.visible = true
				sim_btn.text = "Sim Round"
			return

		is_season_over = false
		home_team = int(active["home"])
		away_team = int(active["away"])
		var s: Dictionary = active["series"]
		var h_name: String = StatBook.TEAMS[home_team]["name"]
		var a_name: String = StatBook.TEAMS[away_team]["name"]
		var high_name: String = StatBook.TEAMS[int(s["high"])]["name"]
		var low_name: String = StatBook.TEAMS[int(s["low"])]["name"]
		var needed: int = Season.get_series_wins_needed()

		matchup_title.text = "%s\nGame %d (First to %d)" % [round_name, int(active["game_number"]), needed]
		matchup_label.text = "%s (Away)\nvs\n%s (Home)\n\nSeries: %s %d - %d %s" % [
			a_name, h_name, high_name, int(s["high_wins"]), int(s["low_wins"]), low_name
		]
		%Play.visible = true
		%Play.text = "Play Playoff Game"
		if sim_btn:
			sim_btn.visible = true
			sim_btn.text = "Sim Round"
		return

	# Regular season
	var week = int(Season.season_data["current_week"])
	if week >= Season.season_data["schedule"].size():
		Season.start_playoffs()
		_refresh_all()
		return

	is_season_over = false
	matchup_title.text = "Week %d of %d" % [week + 1, Season.season_data["schedule"].size()]

	var matches = Season.season_data["schedule"][week]
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
	%Play.visible = true
	%Play.text = "Play Match"
	if sim_btn:
		sim_btn.visible = true
		sim_btn.text = "Sim Week"

func _populate_bracket_tab() -> void:
	_clear_container(alt_vbox)
	var phase: String = str(Season.season_data.get("phase", "regular"))
	var player_team: int = int(Season.season_data["player_team"])

	if phase == "regular":
		var info := Label.new()
		info.text = "Playoffs begin after Week %d!\nTop 4 teams from each division qualify for the 16-team Open Practice Cup Bracket.\nPlayoff Series Format: Best of %d" % [
			Season.season_data["schedule"].size(),
			int(Season.season_data.get("series_length", 3))
		]
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		alt_vbox.add_child(info)
		return

	var playoffs: Dictionary = Season.season_data.get("playoffs", {})
	var rounds: Array = playoffs.get("rounds", [])
	if int(playoffs.get("champion", -1)) >= 0:
		var champ_id: int = int(playoffs["champion"])
		var banner := Label.new()
		banner.text = "OPEN PRACTICE CUP CHAMPION: %s" % StatBook.TEAMS[champ_id]["name"].to_upper()
		banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		banner.add_theme_font_size_override("font_size", 28)
		banner.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2))
		alt_vbox.add_child(banner)

	for r in range(rounds.size()):
		var hdr := Label.new()
		hdr.text = "=== %s ===" % Season.ROUND_NAMES[clampi(r, 0, Season.ROUND_NAMES.size() - 1)]
		hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hdr.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0))
		alt_vbox.add_child(hdr)

		for s in rounds[r]:
			var high_id: int = int(s["high"])
			var low_id: int = int(s["low"])
			var win_id: int = int(s.get("winner", -1))
			var status: String = ""
			if win_id != -1:
				status = "  [Winner: %s]" % StatBook.TEAMS[win_id]["name"]
			var lbl := Label.new()
			lbl.text = "%s:  %s (%d)  vs  %s (%d)%s" % [
				str(s.get("label", "Series")),
				StatBook.TEAMS[high_id]["name"], int(s["high_wins"]),
				StatBook.TEAMS[low_id]["name"], int(s["low_wins"]),
				status
			]
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			if high_id == player_team or low_id == player_team:
				lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.25))
			alt_vbox.add_child(lbl)

func _populate_leaders_tab() -> void:
	_clear_container(alt_vbox)

	var sort_row := HBoxContainer.new()
	sort_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sort_row.add_theme_constant_override("separation", 8)
	alt_vbox.add_child(sort_row)

	for pair in [
		["points", "Points"],
		["goals", "Goals"],
		["assists", "Assists"],
		["hits", "Hits"],
		["penalties", "PIM"],
		["fights_won", "Fights"]
	]:
		var btn := Button.new()
		btn.text = pair[1]
		btn.custom_minimum_size = Vector2(105, 34)
		var key_str: String = pair[0]
		if leaders_sort == key_str:
			btn.modulate = Color(1.0, 0.95, 0.45)
		btn.pressed.connect(func():
			leaders_sort = key_str
			_populate_leaders_tab()
		)
		sort_row.add_child(btn)

	var leaders: Array = Season.get_league_leaders(leaders_sort, 25)
	if leaders.is_empty():
		var empty := Label.new()
		empty.text = "No season player stats yet. Play or simulate a week to populate League Leaders!"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		alt_vbox.add_child(empty)
		return

	var player_team: int = int(Season.season_data["player_team"])
	for i in range(leaders.size()):
		var entry: Dictionary = leaders[i]
		var tid: int = int(entry["team_index"])
		var tname: String = StatBook.TEAMS[tid]["name"] if (tid >= 0 and tid < StatBook.TEAMS.size()) else "Team"
		var lbl := Label.new()
		lbl.text = "%2d. #%d %s (%s) — %d PTS (%dG, %dA) | %d HIT | %d PIM | %d FW" % [
			i + 1, int(entry["number"]), str(entry["name"]), tname,
			int(entry["points"]), int(entry["goals"]), int(entry["assists"]),
			int(entry["hits"]), int(entry["penalties"]), int(entry["fights_won"])
		]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if tid == player_team:
			lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.25))
		alt_vbox.add_child(lbl)

func _populate_roster_tab() -> void:
	_clear_container(alt_vbox)
	var player_team: int = int(Season.season_data["player_team"])
	var team_data: Dictionary = StatBook.TEAMS[player_team]
	var roster: Dictionary = Globals.get_team_roster(player_team)

	var hdr := Label.new()
	hdr.text = "%s Roster — Edit names & press Enter or Save" % team_data["name"]
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0))
	alt_vbox.add_child(hdr)

	var goalie_profile: Dictionary = roster.get("goalie", {})
	if not goalie_profile.is_empty():
		_add_roster_edit_row(player_team, true, -1, 0, "Goalie", goalie_profile)

	var comp: Array = team_data["composition"]
	var class_names := {
		Stats.ClassTypes.LIGHT: "Light",
		Stats.ClassTypes.MEDIUM: "Medium",
		Stats.ClassTypes.HEAVY: "Heavy",
		Stats.ClassTypes.DMAN: "D-Man"
	}
	var skaters: Array = roster.get("skaters", [])
	for i in range(skaters.size()):
		var pair: Array = skaters[i]
		var cls_label: String = str(class_names.get(comp[i], "Skater")) if i < comp.size() else "Skater"
		for v in range(pair.size()):
			var shift_lbl: String = "Line %d (%s)" % [v + 1, cls_label]
			_add_roster_edit_row(player_team, false, i, v, shift_lbl, pair[v])

func _add_roster_edit_row(team_index: int, is_goalie: bool, slot_idx: int, var_idx: int, role_text: String, profile: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	alt_vbox.add_child(row)

	var num: int = int(profile.get("number", 0))
	var role_lbl := Label.new()
	role_lbl.text = "#%02d  %-16s" % [num, role_text]
	role_lbl.custom_minimum_size = Vector2(210, 0)
	row.add_child(role_lbl)

	var edit := LineEdit.new()
	edit.text = str(profile.get("name", "Skater #%d" % num))
	edit.custom_minimum_size = Vector2(260, 34)
	row.add_child(edit)

	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.custom_minimum_size = Vector2(85, 34)
	row.add_child(save_btn)

	var stat_key: String = Globals.get_skater_stat_key(team_index, num)
	var st: Dictionary = Season.season_data.get("skater_stats", {}).get(stat_key, {})
	var st_lbl := Label.new()
	st_lbl.text = "%dG %dA | %d HIT" % [int(st.get("goals", 0)), int(st.get("assists", 0)), int(st.get("hits", 0))]
	st_lbl.custom_minimum_size = Vector2(160, 0)
	row.add_child(st_lbl)

	var commit_fn := func():
		Globals.set_roster_player_name(team_index, is_goalie, slot_idx, var_idx, edit.text)
		save_btn.text = "Saved!"
	save_btn.pressed.connect(commit_fn)
	edit.text_submitted.connect(func(_new_text): commit_fn.call())

func _on_sim_pressed() -> void:
	var phase: String = str(Season.season_data.get("phase", "regular"))
	if phase == "regular":
		Season.simulate_current_week()
	elif phase == "playoffs":
		Season.simulate_playoff_round()
	_refresh_all()

func _on_back_pressed() -> void:
	Season.season_on = false
	get_tree().change_scene_to_file("res://menu/main_menu.tscn")

func _on_play_pressed() -> void:
	if is_season_over or home_team < 0 or away_team < 0:
		return

	Globals.home_team_index = home_team
	Globals.away_team_index = away_team
	Globals.period_length = float(Season.season_data.get("period_length", Globals.period_length))

	var player_team = int(Season.season_data["player_team"])
	var good_teams = Season.season_data["good_teams"]
	var is_playoffs: bool = Season.is_playoff_match()
	var playoff_round: int = int(Season.season_data.get("playoffs", {}).get("round", 0))

	if home_team == player_team:
		Globals.home_ai_difficulty = 0
		if away_team in good_teams or (is_playoffs and playoff_round >= 2):
			Globals.away_ai_difficulty = 2
		elif is_playoffs:
			Globals.away_ai_difficulty = 1
		else:
			var standings = Season.season_data["standings"][str(away_team)]
			Globals.away_ai_difficulty = 0 if standings["losses"] > standings["wins"] else 1
		for i in range(Globals.player_teams.size()):
			Globals.player_teams[i] = 0
	else:
		if home_team in good_teams or (is_playoffs and playoff_round >= 2):
			Globals.home_ai_difficulty = 2
		elif is_playoffs:
			Globals.home_ai_difficulty = 1
		else:
			var standings = Season.season_data["standings"][str(home_team)]
			Globals.home_ai_difficulty = 0 if standings["losses"] > standings["wins"] else 1
		Globals.away_ai_difficulty = 0
		for i in range(Globals.player_teams.size()):
			Globals.player_teams[i] = 1

	Globals.update_team_textures()
	get_tree().change_scene_to_file("res://objects/environment/match_rink.tscn")

func _on_reset_pressed() -> void:
	var dir = DirAccess.open("user://")
	if dir.file_exists("season.json"):
		dir.remove("season.json")
	Season.season_on = false
	Season.season_data.clear()
	get_tree().change_scene_to_file("res://menu/main_menu.tscn")

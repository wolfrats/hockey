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
var customize_overlay: Control = null

const SKIN_PRESET_DARKEN: Array[float] = [0.0, 0.08, 0.17, 0.27, 0.38, 0.50, 0.62, 0.72, 0.81, 0.89]
const EYE_PRESET_COLORS: Array[Color] = [
	Color("3B2214"), # Dark Brown
	Color("6B3E26"), # Warm Brown
	Color("7C5A2B"), # Hazel
	Color("B87E2A"), # Amber
	Color("1E5AA8"), # Deep Blue
	Color("4DA3E8"), # Sky Blue
	Color("086D40"), # Classic Green
	Color("2E9E5B"), # Emerald
	Color("6C7A89"), # Gray
	Color("6B4E9B"), # Violet
]

func _ready() -> void:
	Season.season_on = true
	if Season.season_data.has("period_length"):
		Globals.period_length = float(Season.season_data["period_length"])
	if str(Season.season_data.get("phase", "regular")) == "playoffs" and Season.get_player_active_series().is_empty():
		Season.simulate_remaining_playoffs()

	overview_hbox = $VBoxContainer/HBoxContainer
	_build_extra_ui()
	_refresh_all()
	$VBoxContainer/Buttons/Play.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if customize_overlay != null and is_instance_valid(customize_overlay) and event.is_action_pressed("ui_cancel"):
		_close_customize_modal()
		get_viewport().set_input_as_handled()

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

func _switch_tab(tab_id: String) -> void:
	_close_customize_modal()
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
		return

	if phase == "playoffs":
		var active: Dictionary = Season.get_player_active_series()
		var playoffs: Dictionary = Season.season_data.get("playoffs", {})
		var r: int = int(playoffs.get("round", 0))
		var round_name: String = Season.ROUND_NAMES[clampi(r, 0, Season.ROUND_NAMES.size() - 1)]

		if active.is_empty():
			Season.simulate_remaining_playoffs()
			update_matchup()
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
		["fights_won", "Fights"],
		["saves", "Saves"]
	]:
		var btn := Button.new()
		btn.text = pair[1]
		btn.custom_minimum_size = Vector2(96, 34)
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
		empty.text = "No season player stats yet. Play a match to populate League Leaders!"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		alt_vbox.add_child(empty)
		return

	var player_team: int = int(Season.season_data["player_team"])
	for i in range(leaders.size()):
		var entry: Dictionary = leaders[i]
		var tid: int = int(entry["team_index"])
		var tname: String = StatBook.TEAMS[tid]["name"] if (tid >= 0 and tid < StatBook.TEAMS.size()) else "Team"
		var lbl := Label.new()
		if leaders_sort == "saves":
			lbl.text = "%2d. #%d %s (%s) — %d SV" % [
				i + 1, int(entry["number"]), str(entry["name"]), tname, int(entry["saves"])
			]
		else:
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
	hdr.text = "%s Roster — Edit names inline or click Edit for Number, Skin & Eyes" % team_data["name"]
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

func _make_color_swatch(col: Color, tooltip_str: String, size_px: int = 22) -> Panel:
	var swatch := Panel.new()
	swatch.custom_minimum_size = Vector2(size_px, size_px)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.tooltip_text = tooltip_str
	var style := StyleBoxFlat.new()
	style.bg_color = col
	style.border_color = Color(0.9, 0.92, 0.96, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	swatch.add_theme_stylebox_override("panel", style)
	return swatch

func _add_roster_edit_row(team_index: int, is_goalie: bool, slot_idx: int, var_idx: int, role_text: String, profile: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	alt_vbox.add_child(row)

	var num: int = int(profile.get("number", 0))
	var role_lbl := Label.new()
	role_lbl.text = "#%02d  %-15s" % [num, role_text]
	role_lbl.custom_minimum_size = Vector2(195, 0)
	row.add_child(role_lbl)

	var skin_col: Color = Color.from_string(str(profile.get("skin", "")), Globals.skin_tone)
	var eye_col: Color = Color.from_string(str(profile.get("eye", "")), Globals.eye_color)
	row.add_child(_make_color_swatch(skin_col, "Skin color"))
	row.add_child(_make_color_swatch(eye_col, "Eye color"))

	var edit := LineEdit.new()
	var fallback_prefix: String = "Goalie" if is_goalie else "Skater"
	edit.text = str(profile.get("name", "%s #%d" % [fallback_prefix, num]))
	edit.custom_minimum_size = Vector2(220, 34)
	row.add_child(edit)

	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.custom_minimum_size = Vector2(76, 34)
	save_btn.add_theme_font_size_override("font_size", 18)
	row.add_child(save_btn)

	var customize_btn := Button.new()
	customize_btn.text = "Edit"
	customize_btn.custom_minimum_size = Vector2(76, 34)
	customize_btn.add_theme_font_size_override("font_size", 18)
	row.add_child(customize_btn)

	var stat_key: String = Globals.get_skater_stat_key(team_index, num)
	var st: Dictionary = Season.season_data.get("skater_stats", {}).get(stat_key, {})
	var st_lbl := Label.new()
	if is_goalie:
		st_lbl.text = "%d SV" % int(st.get("saves", 0))
	else:
		st_lbl.text = "%dG %dA | %d HIT" % [int(st.get("goals", 0)), int(st.get("assists", 0)), int(st.get("hits", 0))]
	st_lbl.custom_minimum_size = Vector2(155, 0)
	row.add_child(st_lbl)

	var commit_fn := func():
		Globals.set_roster_player_name(team_index, is_goalie, slot_idx, var_idx, edit.text)
		save_btn.text = "Saved!"
	save_btn.pressed.connect(commit_fn)
	edit.text_submitted.connect(func(_new_text): commit_fn.call())
	customize_btn.pressed.connect(func():
		_open_customize_modal(team_index, is_goalie, slot_idx, var_idx, role_text)
	)

func _close_customize_modal() -> void:
	if customize_overlay != null and is_instance_valid(customize_overlay):
		customize_overlay.queue_free()
	customize_overlay = null

func _build_preview_material(team_index: int) -> ShaderMaterial:
	var mat: ShaderMaterial = Globals.home_shader_material.duplicate()
	var team_data: Dictionary = StatBook.TEAMS[team_index]
	mat.set("shader_parameter/replace_helmet", team_data["head_color"])
	mat.set("shader_parameter/replace_shirt", team_data["body_color"])
	mat.set("shader_parameter/replace_sleeve", team_data["body_color"])
	mat.set("shader_parameter/replace_pants", team_data["foot_color"])
	mat.set("shader_parameter/logo", load("res://sprites/logos/Clip {0}.png".format([team_data["logo"]])))
	return mat

func _make_swatch_button(col: Color, tooltip_str: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(32, 32)
	btn.tooltip_text = tooltip_str
	btn.text = ""
	_style_swatch_button(btn, col, false)
	return btn

func _style_swatch_button(btn: Button, col: Color, selected: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = col
	normal.border_color = Color(1.0, 0.92, 0.25) if selected else Color(0.2, 0.22, 0.28, 0.9)
	normal.set_border_width_all(3 if selected else 2)
	normal.set_corner_radius_all(5)

	var hover := normal.duplicate()
	hover.border_color = Color(1.0, 1.0, 1.0)
	hover.set_border_width_all(3)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", hover)

func _open_customize_modal(team_index: int, is_goalie: bool, slot_idx: int, var_idx: int, role_text: String) -> void:
	_close_customize_modal()
	var profile: Dictionary = Globals.get_roster_player_profile(team_index, is_goalie, slot_idx, var_idx)
	if profile.is_empty():
		return

	var draft := {
		"name": str(profile.get("name", ("Goalie #%d" if is_goalie else "Skater #%d") % int(profile.get("number", 1)))),
		"number": clampi(int(profile.get("number", 1)), 1, 98),
		"skin": Color.from_string(str(profile.get("skin", "")), Globals.skin_tone),
		"nose": Color.from_string(str(profile.get("nose", "")), Globals.nose_color),
		"eye": Color.from_string(str(profile.get("eye", "")), Globals.eye_color),
	}

	customize_overlay = Control.new()
	customize_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	customize_overlay.z_index = 50
	add_child(customize_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	customize_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	customize_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 0)
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.10, 0.13, 0.19, 0.97)
	pstyle.border_color = Color(0.82, 0.88, 0.96, 0.92)
	pstyle.set_border_width_all(3)
	pstyle.set_corner_radius_all(10)
	pstyle.content_margin_left = 24
	pstyle.content_margin_right = 24
	pstyle.content_margin_top = 18
	pstyle.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", pstyle)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Customize %s" % role_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35))
	vbox.add_child(title)

	# Top Row: Live Sprite Preview + Name & Number
	var top_row := HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.add_theme_constant_override("separation", 20)
	vbox.add_child(top_row)

	var preview_panel := PanelContainer.new()
	var pv_style := StyleBoxFlat.new()
	pv_style.bg_color = Color(0.16, 0.21, 0.30, 0.9)
	pv_style.border_color = Color(0.45, 0.55, 0.72, 0.8)
	pv_style.set_border_width_all(2)
	pv_style.set_corner_radius_all(8)
	pv_style.content_margin_left = 10
	pv_style.content_margin_right = 10
	pv_style.content_margin_top = 6
	pv_style.content_margin_bottom = 6
	preview_panel.add_theme_stylebox_override("panel", pv_style)
	top_row.add_child(preview_panel)

	var preview_hbox := HBoxContainer.new()
	preview_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_hbox.add_theme_constant_override("separation", 4)
	preview_panel.add_child(preview_hbox)

	var front_mat: ShaderMaterial = _build_preview_material(team_index)
	var back_mat: ShaderMaterial = null

	var skater_size: String = "medium"
	if not is_goalie:
		var comp: Array = StatBook.TEAMS[team_index]["composition"]
		if slot_idx >= 0 and slot_idx < comp.size():
			skater_size = StatBook.Classes[comp[slot_idx]].size

	var front_rect := TextureRect.new()
	front_rect.custom_minimum_size = Vector2(112, 112)
	front_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	front_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	front_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	front_rect.material = front_mat
	if is_goalie:
		front_rect.texture = load("res://sprites/goalie/Stand.png")
	else:
		var front_atlas := AtlasTexture.new()
		front_atlas.atlas = Globals.skater_texture(skater_size, "Skate Down")
		front_atlas.region = Rect2(0, 0, 192, 192)
		front_rect.texture = front_atlas
		Globals.apply_logo_offset(front_mat, "Skate Down", 0, false)
	preview_hbox.add_child(front_rect)

	if not is_goalie:
		back_mat = _build_preview_material(team_index)
		var back_rect := TextureRect.new()
		back_rect.custom_minimum_size = Vector2(112, 112)
		back_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		back_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		back_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		back_rect.material = back_mat
		var back_atlas := AtlasTexture.new()
		back_atlas.atlas = Globals.skater_texture(skater_size, "Skate Up")
		back_atlas.region = Rect2(0, 0, 192, 192)
		back_rect.texture = back_atlas
		Globals.apply_logo_offset(back_mat, "Skate Up", 0, false)
		preview_hbox.add_child(back_rect)

	var fields_vbox := VBoxContainer.new()
	fields_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fields_vbox.add_theme_constant_override("separation", 8)
	top_row.add_child(fields_vbox)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	fields_vbox.add_child(name_row)

	var name_lbl := Label.new()
	name_lbl.text = "Name:"
	name_lbl.custom_minimum_size = Vector2(95, 0)
	name_row.add_child(name_lbl)

	var name_edit := LineEdit.new()
	name_edit.text = str(draft["name"])
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.custom_minimum_size = Vector2(220, 34)
	name_row.add_child(name_edit)

	var num_row := HBoxContainer.new()
	num_row.add_theme_constant_override("separation", 10)
	fields_vbox.add_child(num_row)

	var num_lbl := Label.new()
	num_lbl.text = "Number:"
	num_lbl.custom_minimum_size = Vector2(95, 0)
	num_row.add_child(num_lbl)

	var num_spin := SpinBox.new()
	num_spin.min_value = 1
	num_spin.max_value = 98
	num_spin.step = 1
	num_spin.rounded = true
	num_spin.value = int(draft["number"])
	num_spin.custom_minimum_size = Vector2(110, 34)
	num_row.add_child(num_spin)

	var num_status := Label.new()
	num_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	num_status.add_theme_font_size_override("font_size", 15)
	fields_vbox.add_child(num_status)

	# Skin Color Section
	var skin_hdr := Label.new()
	skin_hdr.text = "Skin Color"
	skin_hdr.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0))
	vbox.add_child(skin_hdr)

	var skin_row := HBoxContainer.new()
	skin_row.alignment = BoxContainer.ALIGNMENT_CENTER
	skin_row.add_theme_constant_override("separation", 8)
	vbox.add_child(skin_row)

	var skin_buttons: Array = []
	for t in SKIN_PRESET_DARKEN:
		var preset_skin: Color = Globals.skin_tone.darkened(t)
		var preset_nose: Color = Globals.nose_color.darkened(t)
		var btn: Button = _make_swatch_button(preset_skin, "Skin tone #%s" % preset_skin.to_html(false))
		skin_row.add_child(btn)
		skin_buttons.append({"btn": btn, "skin": preset_skin, "nose": preset_nose})

	var skin_custom_lbl := Label.new()
	skin_custom_lbl.text = "Custom:"
	skin_custom_lbl.add_theme_font_size_override("font_size", 16)
	skin_row.add_child(skin_custom_lbl)

	var skin_picker := ColorPickerButton.new()
	skin_picker.edit_alpha = false
	skin_picker.color = draft["skin"]
	skin_picker.custom_minimum_size = Vector2(56, 34)
	skin_picker.tooltip_text = "Pick custom skin color"
	skin_row.add_child(skin_picker)

	# Eye Color Section
	var eye_hdr := Label.new()
	eye_hdr.text = "Eye Color"
	eye_hdr.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0))
	vbox.add_child(eye_hdr)

	var eye_row := HBoxContainer.new()
	eye_row.alignment = BoxContainer.ALIGNMENT_CENTER
	eye_row.add_theme_constant_override("separation", 8)
	vbox.add_child(eye_row)

	var eye_buttons: Array = []
	for preset_eye in EYE_PRESET_COLORS:
		var btn: Button = _make_swatch_button(preset_eye, "Eye color #%s" % preset_eye.to_html(false))
		eye_row.add_child(btn)
		eye_buttons.append({"btn": btn, "eye": preset_eye})

	var eye_custom_lbl := Label.new()
	eye_custom_lbl.text = "Custom:"
	eye_custom_lbl.add_theme_font_size_override("font_size", 16)
	eye_row.add_child(eye_custom_lbl)

	var eye_picker := ColorPickerButton.new()
	eye_picker.edit_alpha = false
	eye_picker.color = draft["eye"]
	eye_picker.custom_minimum_size = Vector2(56, 34)
	eye_picker.tooltip_text = "Pick custom eye color"
	eye_row.add_child(eye_picker)

	var refresh_preview := func():
		var preview_profile := {
			"skin": (draft["skin"] as Color).to_html(false),
			"nose": (draft["nose"] as Color).to_html(false),
			"eye": (draft["eye"] as Color).to_html(false),
			"number": int(draft["number"]),
		}
		Globals.apply_player_profile(front_mat, preview_profile)
		if back_mat != null:
			Globals.apply_player_profile(back_mat, preview_profile)

		var cur_skin: Color = draft["skin"]
		for item in skin_buttons:
			var c: Color = item["skin"]
			_style_swatch_button(item["btn"], c, c.is_equal_approx(cur_skin))
		skin_picker.color = cur_skin

		var cur_eye: Color = draft["eye"]
		for item in eye_buttons:
			var c: Color = item["eye"]
			_style_swatch_button(item["btn"], c, c.is_equal_approx(cur_eye))
		eye_picker.color = cur_eye

		var chosen_num: int = int(draft["number"])
		var owner_info: Dictionary = Globals.find_roster_member_by_number(team_index, chosen_num)
		if owner_info.get("found", false):
			var same_member: bool = (
				bool(owner_info["is_goalie"]) == is_goalie
				and int(owner_info["slot"]) == slot_idx
				and int(owner_info["variant"]) == var_idx
			)
			if same_member:
				num_status.text = "Current number"
				num_status.add_theme_color_override("font_color", Color(0.75, 0.82, 0.9))
			else:
				var other_name: String = str(owner_info["profile"].get("name", "Teammate"))
				num_status.text = "Will swap with #%d %s" % [chosen_num, other_name]
				num_status.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3))
		else:
			num_status.text = "Number #%d is available" % chosen_num
			num_status.add_theme_color_override("font_color", Color(0.55, 0.95, 0.65))

	for item in skin_buttons:
		var s_col: Color = item["skin"]
		var n_col: Color = item["nose"]
		(item["btn"] as Button).pressed.connect(func():
			draft["skin"] = s_col
			draft["nose"] = n_col
			refresh_preview.call()
		)

	skin_picker.color_changed.connect(func(new_col: Color):
		draft["skin"] = Color(new_col.r, new_col.g, new_col.b, 1.0)
		draft["nose"] = Globals.derive_nose_color(draft["skin"])
		refresh_preview.call()
	)

	for item in eye_buttons:
		var e_col: Color = item["eye"]
		(item["btn"] as Button).pressed.connect(func():
			draft["eye"] = e_col
			refresh_preview.call()
		)

	eye_picker.color_changed.connect(func(new_col: Color):
		draft["eye"] = Color(new_col.r, new_col.g, new_col.b, 1.0)
		refresh_preview.call()
	)

	num_spin.value_changed.connect(func(val: float):
		draft["number"] = clampi(int(round(val)), 1, 98)
		refresh_preview.call()
	)

	# Bottom Actions
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 14)
	vbox.add_child(btn_row)

	var rand_btn := Button.new()
	rand_btn.text = "Randomize Look"
	rand_btn.custom_minimum_size = Vector2(180, 42)
	rand_btn.add_theme_font_size_override("font_size", 18)
	rand_btn.pressed.connect(func():
		var st_cols: Array[Color] = Globals.random_skin_tone()
		draft["skin"] = st_cols[0]
		draft["nose"] = st_cols[1]
		draft["eye"] = Globals.random_eye_color()
		refresh_preview.call()
	)
	btn_row.add_child(rand_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(130, 42)
	cancel_btn.add_theme_font_size_override("font_size", 18)
	cancel_btn.pressed.connect(_close_customize_modal)
	btn_row.add_child(cancel_btn)

	var apply_btn := Button.new()
	apply_btn.text = "Apply"
	apply_btn.custom_minimum_size = Vector2(130, 42)
	apply_btn.add_theme_font_size_override("font_size", 18)
	apply_btn.pressed.connect(func():
		num_spin.apply()
		draft["number"] = clampi(int(round(num_spin.value)), 1, 98)
		draft["name"] = name_edit.text
		var res: Dictionary = Globals.update_roster_player(team_index, is_goalie, slot_idx, var_idx, {
			"name": draft["name"],
			"number": draft["number"],
			"skin": draft["skin"],
			"nose": draft["nose"],
			"eye": draft["eye"],
		})
		if res.get("changed", false):
			Season.remap_player_number(
				team_index,
				int(res.get("old_number", 0)),
				int(res.get("new_number", 0)),
				bool(res.get("swapped", false))
			)
		_close_customize_modal()
		_populate_roster_tab()
	)
	btn_row.add_child(apply_btn)

	refresh_preview.call()
	apply_btn.grab_focus()

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

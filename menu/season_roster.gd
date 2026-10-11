extends Control

@onready var container = $VBoxContainer/ScrollContainer/PlayerList


func _ready() -> void:
	$VBoxContainer/BackButton.grab_focus()
	update_ui()


func update_ui() -> void:
	for child in container.get_children():
		child.queue_free()

	if not Season.season_data.has("roster"):
		return

	var roster = Season.season_data["roster"]
	for i in range(roster.size()):
		var player = roster[i]

		var panel = PanelContainer.new()
		var vbox = VBoxContainer.new()
		panel.add_child(vbox)

		var header = Label.new()
		header.text = (
			"%s - Level %d (XP: %d/4) - Stat Points: %d"
			% [player["name"], player["level"], player["xp"], player["stat_points"]]
		)
		header.add_theme_color_override(
			"font_color", Color(1, 1, 0) if player["stat_points"] > 0 else Color(1, 1, 1)
		)
		vbox.add_child(header)

		var stats_grid = GridContainer.new()
		stats_grid.columns = 6
		vbox.add_child(stats_grid)

		var stat_names = [
			"speed", "shot_max_power", "shot_snap_power", "health", "check_damage", "shot_accuracy"
		]
		var display_names = ["Speed", "Max Pwr", "Snap Pwr", "Health", "Check Dmg", "Accuracy"]

		for j in range(stat_names.size()):
			var s_name = stat_names[j]
			var val = player["stats"][s_name]

			var hbox = HBoxContainer.new()
			var lbl = Label.new()
			lbl.text = "%s: %d/8" % [display_names[j], val]
			hbox.add_child(lbl)

			var btn = Button.new()
			btn.text = "+"
			btn.disabled = (player["stat_points"] <= 0 or val >= 8)
			var scoped_i = i
			var scoped_s = s_name
			btn.pressed.connect(func(): _on_stat_increase(scoped_i, scoped_s))
			hbox.add_child(btn)

			stats_grid.add_child(hbox)

		container.add_child(panel)


func _on_stat_increase(player_index: int, stat_name: String) -> void:
	var player = Season.season_data["roster"][player_index]
	if player["stat_points"] > 0 and player["stats"][stat_name] < 8:
		player["stat_points"] -= 1
		player["stats"][stat_name] += 1
		Season.save_season()
		update_ui()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://menu/season_hub.tscn")

extends Control

@onready var p1_label: Label = %P1Label
@onready var p2_label: Label = %P2Label
@onready var p3_label: Label = %P3Label
@onready var p4_label: Label = %P4Label

func _ready() -> void:
	update_ui()

func _unhandled_input(event: InputEvent) -> void:
	var device_joined = -1

	if event.is_action_pressed("shoot") and not event is InputEventJoypadButton:
		# Keyboard is always -2 now for custom setup logic
		device_joined = -2
	elif event is InputEventJoypadButton and event.pressed:
		device_joined = event.device

	if device_joined != -1 and Globals.player_devices.size() < 4:
		if not Globals.player_devices.has(device_joined):
			Globals.player_devices.append(device_joined)
			Globals.player_teams.append(0) # Default to Home Team (0)
			update_ui()

	# Handle Team Switching
	for i in range(Globals.player_devices.size()):
		var dev = Globals.player_devices[i]
		if dev == -2: # Keyboard
			if event.is_action_pressed("skate_left"):
				Globals.player_teams[i] = 0
				update_ui()
			elif event.is_action_pressed("skate_right"):
				Globals.player_teams[i] = 1
				update_ui()
		elif dev >= 0 and event is InputEventJoypadButton and event.device == dev:
			if event.button_index == JOY_BUTTON_DPAD_LEFT and event.pressed:
				Globals.player_teams[i] = 0
				update_ui()
			elif event.button_index == JOY_BUTTON_DPAD_RIGHT and event.pressed:
				Globals.player_teams[i] = 1
				update_ui()
		elif dev >= 0 and event is InputEventJoypadMotion and event.device == dev:
			if event.axis == JOY_AXIS_LEFT_X:
				if event.axis_value < -0.5:
					Globals.player_teams[i] = 0
					update_ui()
				elif event.axis_value > 0.5:
					Globals.player_teams[i] = 1
					update_ui()

func update_ui() -> void:
	var labels = [p1_label, p2_label, p3_label, p4_label]
	for i in range(4):
		if i < Globals.player_devices.size():
			var dev = Globals.player_devices[i]
			var team_name = "Home" if Globals.player_teams[i] == 0 else "Away"
			if dev == -2:
				labels[i].text = "P%d: Keyboard (%s)" % [(i + 1), team_name]
			else:
				labels[i].text = "P%d: Joypad %d (%s)" % [(i + 1), dev, team_name]
		else:
			labels[i].text = "P%d: Press Join" % (i + 1)

func _on_clear_pressed() -> void:
	Globals.player_devices.clear()
	Globals.player_teams.clear()
	update_ui()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://menu/main_menu.tscn")

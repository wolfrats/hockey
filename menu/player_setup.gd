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
			update_ui()

func update_ui() -> void:
	var labels = [p1_label, p2_label, p3_label, p4_label]
	for i in range(4):
		if i < Globals.player_devices.size():
			var dev = Globals.player_devices[i]
			if dev == -2:
				labels[i].text = "P%d: Keyboard" % (i + 1)
			else:
				labels[i].text = "P%d: Joypad %d" % [(i + 1), dev]
		else:
			labels[i].text = "P%d: Press Join" % (i + 1)

func _on_clear_pressed() -> void:
	Globals.player_devices.clear()
	update_ui()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://menu/main_menu.tscn")

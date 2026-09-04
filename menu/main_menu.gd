extends Control

var Joy: VirtualJoystick
var Shoot: TouchScreenButton
var Swap: TouchScreenButton
var Slash: TouchScreenButton
var Holder: Control

func _ready() -> void:
	Joy = VirtualJoystick.new()
	Joy.action_left = &"skate_left" 
	Joy.action_right = &"skate_right" 
	Joy.action_up = &"skate_up"
	Joy.action_down = &"skate_down"
	Joy.joystick_mode = VirtualJoystick.JOYSTICK_DYNAMIC
	Joy.visibility_mode = VirtualJoystick.VISIBILITY_ALWAYS
	Joy.joystick_size = 150.0 
	Joy.tip_size = 60.0
	Joy.deadzone_ratio = 0.2
	Joy.custom_minimum_size = Vector2(100, 100) 
	Shoot = TouchScreenButton.new()
	Shoot.action = &"shoot"
	Shoot.texture_normal = preload("res://sprites/shoot-button.svg")
	Swap = TouchScreenButton.new()
	Swap.action = &"swap"
	Swap.texture_normal = preload("res://sprites/swap-button.svg")
	Slash = TouchScreenButton.new()
	Slash.action = &"check"
	Slash.texture_normal = preload("res://sprites/slash-button.svg")
	Holder = Control.new()
	Holder.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 50)
	Holder.add_child(Swap)
	Holder.add_child(Shoot) 
	Holder.add_child(Slash) 
	Swap.position = Vector2(-100, -300)
	Swap.scale = Vector2.ONE*(128.0/320.0)
	Shoot.position = Vector2(-100, -100)
	Shoot.scale = Vector2.ONE*(128.0/320.0)
	Slash.position = Vector2(-175, -200)
	Slash.scale = Vector2.ONE*(128.0/320.0)
	%JoystickToggle.button_pressed = Globals.has_node("Holder")



func _on_practice_pressed() -> void:
	get_tree().change_scene_to_file("res://objects/environment/practice_rink.tscn")


func _on_match_pressed() -> void:
		get_tree().change_scene_to_file("res://objects/environment/match_rink.tscn")

func _on_joystick_toggled(toggled_on: bool) -> void:
	if Globals.get_node("Holder") == null && toggled_on:
		Joy.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 150) 
		Holder.name = "Holder"
		Globals.add_child(Holder)
		Joy.name = "Joy"
		Globals.add_child(Joy)
	elif not toggled_on:
		Globals.remove_child(Globals.get_node("Holder"))
		Globals.remove_child(Globals.get_node("Joy"))

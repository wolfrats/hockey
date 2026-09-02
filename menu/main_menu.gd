extends Control

var Joy: VirtualJoystick
var Shoot: TouchScreenButton
var Swap: TouchScreenButton
var Holder: Control

func _ready() -> void:
	Joy = VirtualJoystick.new()
	Joy.action_left = &"skate_left" 
	Joy.action_right = &"skate_right" 
	Joy.action_up = &"skate_up"
	Joy.action_down = &"skate_down" 	
	Shoot = TouchScreenButton.new()
	Shoot.action = &"shoot"
	Shoot.texture_normal = preload("res://sprites/icon.svg")
	Swap = TouchScreenButton.new()
	Swap.action = &"swap"
	Swap.texture_normal = preload("res://sprites/icon.svg")
	Holder = Control.new()
	Holder.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 50)
	Holder.add_child(Swap)
	Holder.add_child(Shoot) 
	Swap.position = Vector2(-100, -300)
	Shoot.position = Vector2(-100, -100)



func _on_practice_pressed() -> void:
	get_tree().change_scene_to_file("res://objects/environment/practice_rink.tscn")


func _on_match_pressed() -> void:
		get_tree().change_scene_to_file("res://objects/environment/match_rink.tscn")

func _on_joystick_toggled(toggled_on: bool) -> void:
	if toggled_on:
		Joy.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 150) 
		Globals.add_child(Joy)
		Globals.add_child(Holder)

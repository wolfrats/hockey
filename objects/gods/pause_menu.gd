class_name PauseMenu
extends CanvasLayer

var manager: Manager = null
var confirm_quit: bool = false

var resume_btn: Button
var goalie_btn: Button
var line_change_btn: Button
var volume_label: Label
var volume_slider: HSlider
var onscreen_check: CheckButton
var restart_btn: Button
var quit_btn: Button
var status_label: Label

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = preload("res://menu/theme.tres")
	add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.68)
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(540, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.13, 0.19, 0.96)
	style.border_color = Color(0.85, 0.88, 0.95, 0.9)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	vbox.add_child(title)

	status_label = Label.new()
	status_label.text = ""
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35))
	status_label.visible = false
	vbox.add_child(status_label)

	resume_btn = Button.new()
	resume_btn.text = "Resume"
	resume_btn.custom_minimum_size = Vector2(0, 46)
	resume_btn.pressed.connect(close_menu)
	vbox.add_child(resume_btn)

	# Coach Commands Row
	var coach_row := HBoxContainer.new()
	coach_row.name = "CoachRow"
	coach_row.add_theme_constant_override("separation", 12)
	vbox.add_child(coach_row)

	goalie_btn = Button.new()
	goalie_btn.text = "Pull Goalie"
	goalie_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goalie_btn.custom_minimum_size = Vector2(0, 44)
	goalie_btn.pressed.connect(_on_toggle_goalie_pressed)
	coach_row.add_child(goalie_btn)

	line_change_btn = Button.new()
	line_change_btn.text = "Call Line Change"
	line_change_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_change_btn.custom_minimum_size = Vector2(0, 44)
	line_change_btn.pressed.connect(_on_line_change_pressed)
	coach_row.add_child(line_change_btn)

	# SFX Volume
	var vol_box := VBoxContainer.new()
	vol_box.add_theme_constant_override("separation", 4)
	vbox.add_child(vol_box)

	volume_label = Label.new()
	volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vol_box.add_child(volume_label)

	volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.05
	volume_slider.value = Globals.sfx_volume
	volume_slider.value_changed.connect(_on_volume_changed)
	vol_box.add_child(volume_slider)

	# On-Screen Controls Toggle
	onscreen_check = CheckButton.new()
	onscreen_check.text = "On-Screen Controls"
	onscreen_check.button_pressed = Globals.use_onscreen_controls
	onscreen_check.toggled.connect(_on_onscreen_toggled)
	vbox.add_child(onscreen_check)

	# Controls Reference
	var controls_panel := PanelContainer.new()
	var cstyle := StyleBoxFlat.new()
	cstyle.bg_color = Color(0.06, 0.08, 0.12, 0.9)
	cstyle.set_corner_radius_all(6)
	cstyle.content_margin_left = 12
	cstyle.content_margin_right = 12
	cstyle.content_margin_top = 8
	cstyle.content_margin_bottom = 8
	controls_panel.add_theme_stylebox_override("panel", cstyle)
	vbox.add_child(controls_panel)

	var controls_lbl := Label.new()
	controls_lbl.text = "CONTROLS (Keyboard / Gamepad)\nMove: WASD / L-Stick  |  Shoot: Space / X  |  Pass: F / A\nCheck: E / B  |  Grab: Hold M / RB  |  Sprint: Shift / LB\nSwap: Q / Y  |  Fight: Move + E=Jab, Space=Cross, Shift=Uppercut, F/M=Block"
	controls_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_lbl.add_theme_font_size_override("font_size", 15)
	controls_lbl.add_theme_color_override("font_color", Color(0.82, 0.87, 0.95))
	controls_panel.add_child(controls_lbl)

	# Bottom Actions
	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 12)
	vbox.add_child(bottom_row)

	restart_btn = Button.new()
	restart_btn.text = "Restart"
	restart_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restart_btn.custom_minimum_size = Vector2(0, 46)
	restart_btn.pressed.connect(_on_restart_pressed)
	bottom_row.add_child(restart_btn)

	quit_btn = Button.new()
	quit_btn.text = "Quit to Menu"
	quit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quit_btn.custom_minimum_size = Vector2(0, 46)
	quit_btn.pressed.connect(_on_quit_pressed)
	bottom_row.add_child(quit_btn)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed and not event.is_echo() and event.button_index == JOY_BUTTON_START:
		close_menu()
		get_viewport().set_input_as_handled()

func open_menu() -> void:
	confirm_quit = false
	status_label.visible = false
	volume_slider.set_value_no_signal(Globals.sfx_volume)
	volume_label.text = "SFX Volume: %d%%" % int(round(Globals.sfx_volume * 100.0))
	onscreen_check.set_pressed_no_signal(Globals.use_onscreen_controls)

	var in_mites: bool = manager != null and manager.anim_manager != null and manager.anim_manager.current_phase == AnimationManager.Phase.INTERMISSION_MITES
	var show_coach: bool = manager != null and not manager.is_practice and not manager.is_shootout_active() and not in_mites
	goalie_btn.visible = show_coach
	line_change_btn.visible = show_coach
	if show_coach:
		_refresh_goalie_button()

	restart_btn.visible = not Season.season_on
	quit_btn.text = "Quit to Season Hub" if Season.season_on else "Quit to Menu"

	visible = true
	get_tree().paused = true
	resume_btn.grab_focus()

func close_menu() -> void:
	visible = false
	confirm_quit = false
	get_tree().paused = false

func _refresh_goalie_button() -> void:
	if manager == null:
		return
	var is_pulled: bool = manager.is_human_goalie_pulled()
	goalie_btn.text = "Return Goalie to Net" if is_pulled else "Pull Goalie (6v5)"

func _on_toggle_goalie_pressed() -> void:
	if manager == null:
		return
	var msg: String = manager.toggle_human_goalie_pull()
	_refresh_goalie_button()
	status_label.text = msg
	status_label.visible = msg != ""

func _on_line_change_pressed() -> void:
	if manager == null:
		return
	var count: int = manager.call_human_line_change()
	status_label.text = "Line change called (%d fresh skaters)!" % count if count > 0 else "No skaters available to swap."
	status_label.visible = true

func _on_volume_changed(val: float) -> void:
	Globals.sfx_volume = clampf(val, 0.0, 1.0)
	volume_label.text = "SFX Volume: %d%%" % int(round(Globals.sfx_volume * 100.0))
	Globals.save_settings()

func _on_onscreen_toggled(toggled_on: bool) -> void:
	Globals.set_onscreen_controls_visible(toggled_on)

func _on_restart_pressed() -> void:
	close_menu()
	Globals.clear_match_stats()
	var scene_path: String = "res://objects/environment/practice_rink.tscn" if (manager != null and manager.is_practice) else "res://objects/environment/match_rink.tscn"
	get_tree().change_scene_to_file(scene_path)

func _on_quit_pressed() -> void:
	if not confirm_quit:
		confirm_quit = true
		quit_btn.text = "Confirm Quit?"
		return
	close_menu()
	Globals.clear_match_stats()
	if Season.season_on:
		get_tree().change_scene_to_file("res://menu/season_hub.tscn")
	else:
		get_tree().change_scene_to_file("res://menu/main_menu.tscn")

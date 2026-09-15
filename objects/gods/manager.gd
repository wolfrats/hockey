extends Node2D

var home_score: int = 0
var away_score: int = 0
var current_period: int = 1
var time_remaining: float = 0.0

@export var is_practice: bool = false

var ui_layer: CanvasLayer
var score_label: Label
var timer_label: Label
var period_label: Label
var anim_manager: AnimationManager

func _ready() -> void:
	setup_multiplayer()
	if not is_practice:
		anim_manager = AnimationManager.new()
		add_child(anim_manager)
		time_remaining = Globals.period_length
		setup_ui()

func setup_multiplayer() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_update_players()

func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_update_players()

func _update_players() -> void:
	var ghosts_node = get_node_or_null("Ghosts")
	if not ghosts_node:
		return
	var player1 = ghosts_node.get_node_or_null("Player")
	if not player1:
		return

	var active_devices = Globals.player_devices.duplicate()

	if active_devices.size() == 0:
		var joypads = Input.get_connected_joypads()
		for joy_id in joypads:
			if active_devices.size() < 4:
				active_devices.append(joy_id)

		# Ensure at least device -2 is active for keyboard/mouse if no controllers are plugged in
		if active_devices.size() == 0:
			active_devices.append(-2)
		else:
			# Keyboard is not added if fallback triggers with at least 1 controller to preserve original behaviour where keyboard mapped to same actions as p1.
			pass

	var current_players = []
	for child in ghosts_node.get_children():
		if child.name.begins_with("Player"):
			current_players.append(child)

	# Add new players
	for i in range(current_players.size(), active_devices.size()):
		var new_player = player1.duplicate()
		new_player.name = "Player" + str(i + 1)

		# Remove camera from duplicate players
		var cam = new_player.get_node_or_null("Camera2D")
		if cam:
			new_player.remove_child(cam)
			cam.queue_free()

		ghosts_node.add_child(new_player)
		current_players.append(new_player)

		# Assign this new player ghost to an available skater on Team1
		var team1 = get_node_or_null("Team1")
		if team1:
			var skaters = team1.get_children()
			if i < skaters.size():
				skaters[i].ghost = new_player

	# Update device IDs and handle disconnected controllers
	var team1 = get_node_or_null("Team1")
	var skaters = team1.get_children() if team1 else []
	for i in range(current_players.size()):
		var p = current_players[i]
		if i < active_devices.size():
			p.device_id = active_devices[i]
			p.set_color(Globals.player_colors[i])
			# Ensure it's assigned to a skater
			if i < skaters.size() and skaters[i].ghost != p:
				skaters[i].ghost = p
		else:
			p.device_id = -1
			# Unassign from skater to revert to AI
			for skater in skaters:
				if skater.ghost == p:
					skater.ghost = null

func _process(delta: float) -> void:
	if not is_practice:
		if anim_manager.current_phase == AnimationManager.Phase.PLAYING:
			if current_period <= 3 and (current_period != 3 or time_remaining > 0):
				time_remaining -= delta
				if time_remaining <= 0:
					anim_manager.on_period_end()

		update_ui()

func setup_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	score_label = Label.new()
	score_label.text = "0 - 0"
	score_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 48)
	score_label.label_settings = LabelSettings.new()
	score_label.label_settings.outline_size = 6
	score_label.label_settings.font_size = 64
	score_label.label_settings.outline_color = Color.BLACK
	ui_layer.add_child(score_label)

	period_label = Label.new()
	period_label.text = "Period 1"
	period_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	period_label.add_theme_font_size_override("font_size", 32)
	period_label.position = Vector2(20, 20)
	period_label.label_settings = LabelSettings.new()
	period_label.label_settings.outline_size = 6
	period_label.label_settings.font_size = 32
	period_label.label_settings.outline_color = Color.BLACK
	ui_layer.add_child(period_label)

	timer_label = Label.new()
	timer_label.text = "2:00"
	timer_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	timer_label.add_theme_font_size_override("font_size", 32)
	timer_label.label_settings = period_label.label_settings
	timer_label.position = Vector2(-20, 20)
	timer_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ui_layer.add_child(timer_label)

func update_ui() -> void:
	score_label.text = "%d - %d" % [home_score, away_score]
	period_label.text = "Period %d" % current_period

	var mins = int(time_remaining) / 60
	var secs = int(time_remaining) % 60
	timer_label.text = "%d:%02d" % [mins, secs]

func goal_scored(goal_name: String) -> void:
	if goal_name == "HomeGoal":
		away_score += 1
	elif goal_name == "AwayGoal":
		home_score += 1

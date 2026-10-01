extends CanvasLayer

var home_color: Color
var away_color: Color
var home_textures: Dictionary = {}
var away_textures: Dictionary = {}
var referee_textures: Dictionary = {}

var home_goalie_texture: Texture2D
var away_goalie_texture: Texture2D

var ticks: int = 0
var period_length: float = 120.0
var shirt_color: Color = Color.from_rgba8(96, 176, 248)
var helmet_color: Color = Color.from_rgba8(16, 100, 174)
var skate_color: Color = Color.from_rgba8(96, 255, 248)

var player_devices: Array[int] = []
var player_teams: Array[int] = []
var player_auto_swap: Array[bool] = []
var player_colors: Array[Color] = [Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW]
var player_colors_map = {}

var scorer_stats: Dictionary = {}
var assist_stats: Dictionary = {}
var match_home_score: int = 0
var match_away_score: int = 0

var home_team_index: int = 0
var away_team_index: int = 1
var allow_goalie_control: bool = false
var home_ai_difficulty: int = 0
var away_ai_difficulty: int = 0
var sounds: Dictionary[String, AudioStreamPlayer2D] = {}
var menu_opened: bool = false
var manager: Node2D = null

func _init() -> void:
	update_team_textures()
	generate_referee_textures()
	for x in range(0, len(player_colors)):
		player_colors_map["Player %d" % [x + 1]] = player_colors[x].to_html(false)

func generate_referee_textures() -> void:
	var sprites = [
		"Skate Left", "Skate Down", "Skate Up", "Glide Left", "Check Left", "Check Down", "Check Up",
		"Grab Left", "Grab Down", "Grab Up", "Pummel Down", "Pummel Up", "Shoot Left", "Die 1"
	]
	for s in sprites:
		var tex = load("res://sprites/medium/" + s + ".png")
		if tex:
			referee_textures[s] = swap_colors_in_texture_referee(tex)

func _ready() -> void:
	for s in get_node("Sounds").get_children():
		sounds[s.name] = s

func update_team_textures() -> void:
	var home_team = StatBook.TEAMS[home_team_index]
	var away_team = StatBook.TEAMS[away_team_index]

	home_color = home_team["body_color"]
	away_color = away_team.get("away_body_color", away_team["body_color"])

	var sprites = [
		"Skate Left", "Skate Down", "Skate Up", "Glide Left", "Check Left", "Check Down", "Check Up",
		"Grab Left", "Grab Down", "Grab Up", "Pummel Down", "Pummel Up", "Shoot Left", "Die 1"
	]
	for t in ["light", "medium", "heavy"]:
		home_textures[t] = {}
		away_textures[t] = {}
		for s in sprites:
			var tex = load("res://sprites/" + t + "/" + s + ".png")
			if tex:
				home_textures[t][s] = swap_colors_in_texture_multi(tex, home_team["head_color"], home_team["body_color"], home_team["foot_color"])
				away_textures[t][s] = swap_colors_in_texture_multi(tex, away_team.get("away_head_color", away_team["head_color"]), away_team.get("away_body_color", away_team["body_color"]), away_team.get("away_foot_color", away_team["foot_color"]))

	home_goalie_texture = swap_colors_in_texture_multi(preload("res://sprites/goalie.png"), home_team["head_color"], home_team["body_color"], home_team["foot_color"])
	away_goalie_texture = swap_colors_in_texture_multi(preload("res://sprites/goalie.png"), away_team.get("away_head_color", away_team["head_color"]), away_team.get("away_body_color", away_team["body_color"]), away_team.get("away_foot_color", away_team["foot_color"]))

func _physics_process(_delta: float) -> void:
	ticks += 1

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://menu/main_menu.tscn")

func get_closest_node(from_position: Vector2, group_name: String) -> Node2D:
	var nodes = get_tree().get_nodes_in_group(group_name)
	if nodes.is_empty():
		return null
	var closest_node = null
	var min_distance: float = INF
	for node in nodes:
		var distance = from_position.distance_squared_to(node.global_position)
		if distance < min_distance:
			min_distance = distance
			closest_node = node
	return closest_node

func swap_colors_in_texture_referee(tex: Texture2D) -> ImageTexture:
	var img: Image = tex.get_image().duplicate()
	for x in range(img.get_width()):
		for y in range(img.get_height()):
			var current_color = img.get_pixel(x, y)
			if current_color.is_equal_approx(shirt_color) or current_color.is_equal_approx(helmet_color) or current_color.is_equal_approx(skate_color):
				var to_col = Color(0.01, 0.01, 0.01)
				if int(x / 6.0) % 2 == 0 and y > 95 and y < 120:
					to_col = Color.LIGHT_GRAY
				img.set_pixel(x, y, to_col)
	return ImageTexture.create_from_image(img)

func swap_colors_in_texture(tex: Texture2D, to_col: Color) -> ImageTexture:
	return swap_colors_in_texture_multi(tex, to_col.darkened(0.3), to_col, to_col.darkened(0.6))

func swap_colors_in_texture_multi(tex: Texture2D, head: Color, body: Color, foot: Color) -> ImageTexture:
	return swap_color_in_texture(
		swap_color_in_texture(
			swap_color_in_texture(
				tex, shirt_color, body
			), helmet_color, head
		), skate_color, foot
	)
func swap_color_in_texture(tex: Texture2D, from_col: Color, to_col: Color) -> ImageTexture:
	# Convert Texture2D to an Image you can edit
	var img: Image = tex.get_image().duplicate()
	#img.lock() # Required for fast pixel manipulation in some contexts
	 # Loop through every pixel coordinates (x, y)
	for x in range(img.get_width()):
		for y in range(img.get_height()):
			var current_color = img.get_pixel(x, y)
			# Optional: add a small tolerance check if dealing with compressed/anti-aliased art
			if current_color.is_equal_approx(from_col):
				img.set_pixel(x, y, to_col)
	#img.unlock()
	# Create a new ImageTexture from the modified Image
	return ImageTexture.create_from_image(img)

func play_sound_at(sound: String, place: Vector2) -> void:
	sounds[sound].global_position = place
	sounds[sound].play()

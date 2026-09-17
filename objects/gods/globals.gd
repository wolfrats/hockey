extends CanvasLayer

var home_color: Color
var away_color: Color
var home_texture: Texture2D
var away_texture: Texture2D
var ticks: int = 0
var period_length: float = 120.0
var SHIRT_COLOR: Color = Color.from_rgba8(96, 176, 248)
var HELMET_COLOR: Color = Color.from_rgba8(16, 100, 174)
var SKATE_COLOR: Color = Color.from_rgba8(96, 255, 248)

var player_devices: Array[int] = []
var player_teams: Array[int] = []
var player_auto_swap: Array[bool] = []
var player_colors: Array[Color] = [Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW]

var scorer_stats: Dictionary = {}
var assist_stats: Dictionary = {}
var match_home_score: int = 0
var match_away_score: int = 0

var home_team_index: int = 0
var away_team_index: int = 1

func _init() -> void:
	update_team_textures()

func update_team_textures() -> void:
	var home_team = StatBook.TEAMS[home_team_index]
	var away_team = StatBook.TEAMS[away_team_index]

	home_color = home_team["body_color"]
	away_color = away_team.get("away_body_color", away_team["body_color"])

	home_texture = swap_colors_in_texture_multi(preload("res://sprites/skater-all.png"), home_team["head_color"], home_team["body_color"], home_team["foot_color"])
	away_texture = swap_colors_in_texture_multi(preload("res://sprites/skater-all.png"), away_team.get("away_head_color", away_team["head_color"]), away_team.get("away_body_color", away_team["body_color"]), away_team.get("away_foot_color", away_team["foot_color"]))

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
	
func swap_colors_in_texture(tex: Texture2D, to_col: Color) -> ImageTexture:
	return swap_colors_in_texture_multi(tex, to_col.darkened(0.3), to_col, to_col.darkened(0.6))

func swap_colors_in_texture_multi(tex: Texture2D, head: Color, body: Color, foot: Color) -> ImageTexture:
	return swap_color_in_texture(
		swap_color_in_texture(
			swap_color_in_texture(
				tex, SHIRT_COLOR, body
			), HELMET_COLOR, head
		), SKATE_COLOR, foot
	)
func swap_color_in_texture(tex: Texture2D, from_col: Color, to_col: Color) -> ImageTexture:
	# Convert Texture2D to an Image you can edit 
	var img: Image = tex.get_image()
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

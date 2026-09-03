extends CanvasLayer

var home_color: Color
var away_color: Color
var home_texture: Texture2D
var away_texture: Texture2D
var ticks: int = 0
var period_length: float = 120.0

func _init() -> void:
	home_color = Color(randf(), randf(), randf())
	away_color = home_color.inverted()
	home_texture = swap_color_in_texture(preload("res://sprites/atlas.png"), Color.from_rgba8(96, 176, 248), home_color)
	away_texture = swap_color_in_texture(preload("res://sprites/atlas.png"), Color.from_rgba8(96, 176, 248), away_color)

func _physics_process(_delta: float) -> void:
	ticks += 1

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

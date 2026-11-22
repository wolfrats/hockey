extends Area2D
@export var home: bool

var bench_sprites: Array[Sprite2D] = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var center_x = 554.25 if home else 1452.0
	if has_node("CollisionShape2D"):
		center_x = $CollisionShape2D.position.x

	if not has_node("Line2D"):
		var line = Line2D.new()
		line.name = "Line2D"
		line.points = PackedVector2Array([
			Vector2(center_x - 100.0, 135.0),
			Vector2(center_x - 100.0, 50.0),
			Vector2(center_x + 100.0, 50.0),
			Vector2(center_x + 100.0, 135.0)
		])
		line.width = 5.0
		line.default_color = Color(0, 0, 0, 1)
		add_child(line)

	var team_index = Globals.home_team_index if home else Globals.away_team_index
	var team_data = StatBook.TEAMS[team_index]
	var composition = team_data["composition"]
	var count = composition.size()

	for i in range(count):
		var stats_type = composition[i]
		var statbook = StatBook.Classes[stats_type]
		var skater_size = statbook.size

		var sprite = Sprite2D.new()
		sprite.name = "BenchSkater" + str(i + 1)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var tex_dict = Globals.home_textures if home else Globals.away_textures
		if tex_dict.has(skater_size) and tex_dict[skater_size].has("Skate Down"):
			sprite.texture = tex_dict[skater_size]["Skate Down"]
		sprite.region_enabled = true
		sprite.region_rect = Rect2(0, 0, 192, 192)

		var mat = Globals.home_shader_material.duplicate() if home else Globals.away_shader_material.duplicate()
		var variants: Array = Globals.get_skater_variants(team_index, i)
		if variants.size() >= 2:
			Globals.apply_player_profile(mat, variants[1])
		elif variants.size() == 1:
			Globals.apply_player_profile(mat, variants[0])
		Globals.apply_logo_offset(mat, "Skate Down", 0, false)
		sprite.material = mat

		if stats_type == Stats.ClassTypes.LIGHT:
			sprite.scale = Vector2(0.9, 1.1)
		elif stats_type == Stats.ClassTypes.HEAVY:
			sprite.scale = Vector2(1.2, 1.0)

		var offset_x = (i - (count - 1) / 2.0) * 34.0
		sprite.position = Vector2(center_x + offset_x, 70.0)
		sprite.z_index = -3
		add_child(sprite)
		bench_sprites.append(sprite)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func set_bench_skater_profile(slot_index: int, profile: Dictionary) -> void:
	if slot_index < 0 or slot_index >= bench_sprites.size():
		return
	var sprite: Sprite2D = bench_sprites[slot_index]
	if sprite != null and sprite.material is ShaderMaterial:
		Globals.apply_player_profile(sprite.material, profile)


func _on_bench_body_entered(body: Node2D) -> void:
	if not body is Skater and not body is Goalie:
		return

	if body is Goalie:
		var goalie: Goalie = body
		if goalie.home_team == home and not goalie.pulled:
			goalie.pull()
		return

	var skater: Skater = body
	if skater.home_team == home and skater.anim_state == "":
		skater.start_bench_swap(self)
		

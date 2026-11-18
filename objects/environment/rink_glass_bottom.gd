extends Sprite2D


func _process(_delta: float) -> void:
	var mat := material as ShaderMaterial
	if not mat or not texture:
		return
	var tex_half_size := texture.get_size() * 0.5
	var pucks := get_tree().get_nodes_in_group("pucks")
	var positions: Array[Vector2] = []
	for node in pucks:
		if node is Node2D and node.is_visible_in_tree():
			var sprite := node.get_node_or_null("Sprite") as Node2D
			var visual_global_pos: Vector2
			if sprite:
				visual_global_pos = sprite.global_position + Vector2(4.0, 2.0)
			else:
				visual_global_pos = node.global_position + Vector2(0.0, 38.0)
			var local_pos := to_local(visual_global_pos)
			var tex_pos := local_pos + (tex_half_size if centered else Vector2.ZERO)
			positions.append(tex_pos)
			if positions.size() >= 8:
				break
	mat.set_shader_parameter("puck_count", positions.size())
	if positions.size() > 0:
		mat.set_shader_parameter("puck_positions", PackedVector2Array(positions))

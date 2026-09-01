extends Node2D

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

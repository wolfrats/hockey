extends Ghost

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
	
func handle(_delta: float, skater: Skater) -> void:
	if Input.is_action_just_pressed("swap"):
		skater.ghost = null
		var Is = skater.name.length() - 5
		Is = (Is % 5) + 1
		print('Skater%s' % "1".repeat(Is))
		get_parent().get_node('Entities/Skater%s' % "1".repeat(Is)).ghost = self
		return
	var dx = Input.get_axis("skate_left", "skate_right") * 5
	var dy = Input.get_axis("skate_up", "skate_down") * 5
	if ((dx != 0) or (dy != 0)): skater.counter += 1
	skater.impulse(dx, dy)

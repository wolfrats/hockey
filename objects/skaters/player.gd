extends Ghost
var skater: Skater
var puck: Puck

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	puck = %Puck


func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("swap") and skater:
		skater.ghost = null
		var Is = skater.name.length() - 5
		Is = (Is % 5) + 1
		print('Skater%s' % "1".repeat(Is))
		get_parent().get_node('Entities/Skater%s' % "1".repeat(Is)).ghost = self
		return
	
func handle(_delta: float, curSkater: Skater) -> void:
	self.skater = curSkater
	var dx = Input.get_axis("skate_left", "skate_right")
	var dy = Input.get_axis("skate_up", "skate_down")
	if ((dx != 0) or (dy != 0)): curSkater.counter += 1
	curSkater.impulse(dx, dy)
	if Input.is_action_just_released("shoot") and puck.posessor == curSkater:
		puck.posessor = null
		puck.blocklist[curSkater.name] = 15
		puck.set_collision_layer_value(1, false)
		puck.apply_impulse(Vector2(dx, dy) * 10)
		puck.freeze = false

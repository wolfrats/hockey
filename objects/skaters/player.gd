extends Ghost
var skater: Skater
var puck: Puck
var power: float = 0
var charge: float = 0.03
var shotDir: Vector2

func _physics_process(_delta: float) -> void:
	if not skater:
		return
	global_position = global_position.lerp(skater.global_position, 0.1)
	if Input.is_action_just_pressed("swap"):
		var Is = skater.get_parent().get_children().find(skater)
		Is = (Is + 1) % 5
		skater.ghost = skater.get_parent().get_children()[Is].ghost
		skater.get_parent().get_children()[Is].ghost = self
		return
	
func handle(_delta: float, curSkater: Skater) -> void:
	self.skater = curSkater
	var dx = Input.get_axis("skate_left", "skate_right")
	var dy = Input.get_axis("skate_up", "skate_down")
	if Input.is_action_just_pressed("shoot"):
		shotDir = Vector2(dx, dy)
	if not Input.is_action_pressed("shoot"):
		if ((dx != 0) or (dy != 0)): curSkater.counter += 1
		curSkater.impulse(dx, dy)
		charge = 0.03
		$Power.visible = false
		$Angle.visible = false
		curSkater.charging = false
	else:
		if dx != 0 or dy != 0:
			shotDir = shotDir.lerp(Vector2(dx, dy), 0.1)
		$Power.visible = true
		$Angle.visible = true
		power += charge
		if power > 1:
			power = 1
			charge = -charge
		elif power < 0:
			power = 0
			charge = -charge
		$Power.value = power * 100
		curSkater.charging = true
		$Angle.set_point_position(1, shotDir.normalized() * 48)
	if Input.is_action_just_released("shoot") and curSkater.puck:
		curSkater.shoot(shotDir, power)
		power = 0
		

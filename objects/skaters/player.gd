extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
	
func _physics_process(_delta: float) -> void:
	var dx = Input.get_axis("skate_left", "skate_right") * 5
	var dy = Input.get_axis("skate_up", "skate_down") * 5
	if ((dx != 0) or (dy != 0)): ($Skater).counter += 1
	($Skater).impulse(dx, dy)

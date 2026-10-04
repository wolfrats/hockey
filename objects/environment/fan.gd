class_name Fan extends Node2D

var home_team: bool
var missing: bool

var stand_timer: int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	home_team = randf() < 0.8
	missing = randf() < 0.3
	
	if missing:
		$Person.visible = false
		
	Globals.manager.shot.connect(on_shot)
	$Person.texture = Globals.fan_textures[home_team]["Sit"]

func _physics_process(_delta: float) -> void:
	if stand_timer > 0:
		stand_timer -= 1
		if stand_timer <= 0:
			$Person.texture = Globals.fan_textures[home_team]["Sit"]

func on_shot(shooting_team: bool, location: Vector2):
	if (global_position.distance_to(location) < 300) and shooting_team == home_team:
		stand()

func stand(timer: int = 180) -> void:
	stand_timer = timer
	$Person.texture = Globals.fan_textures[home_team]["Stand"]

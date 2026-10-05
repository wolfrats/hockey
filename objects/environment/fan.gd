class_name Fan extends Node2D

var side: bool = false
var home_team: bool
var missing: bool
var stand_timer: int = 0
var sitstr: String = "Sit"
var standstr: String = "Stand"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var popularity = StatBook.TEAMS[Globals.home_team_index].get("popularity", 0.8)
	home_team = randf() < popularity
	missing = randf() < (0.24 / popularity)
	
	if Globals.manager.is_practice:
		home_team = true
		missing = randf() < 0.93
	
	if missing:
		$Person.visible = false
		
	Globals.manager.shot.connect(on_shot)
	if side:
		sitstr += "-Side"
		standstr += "-Side"
		$Chair.texture = preload("res://sprites/fan/Chair-Side.png")
		
	$Person.texture = Globals.fan_textures[home_team][sitstr]

func _physics_process(_delta: float) -> void:
	if stand_timer > 0:
		stand_timer -= 1
		if stand_timer <= 0:
			$Person.texture = Globals.fan_textures[home_team][sitstr]

func on_shot(shooting_team: bool, location: Vector2, velocity: Vector2):
	if (global_position.distance_to(location) < 3 * velocity.length()) and shooting_team == home_team:
		stand(120)
	if (shooting_team != home_team and velocity.length() == 0):
		stand(60)

func stand(timer: int = 180) -> void:
	stand_timer = timer
	$Person.texture = Globals.fan_textures[home_team][standstr]

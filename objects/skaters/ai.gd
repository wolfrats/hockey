extends Ghost
var skater: Skater
var puck: Puck
var power: float = 0
var charge: float = 0.03
var shotDir: Vector2
var dx: float
var dy: float
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	timer.call_deferred()

func timer() -> void:
	var periodic_timer = Timer.new()
	add_child(periodic_timer)
	periodic_timer.wait_time = 1.5
	periodic_timer.one_shot = false
	periodic_timer.timeout.connect(_on_periodic_timeout)
	periodic_timer.start()	

func _on_periodic_timeout() -> void:
	dx = 1 - (2 * randf())
	dy = 1 - (2 * randf())

func _physics_process(_delta: float) -> void:
	if not skater:
		return
	global_position = global_position.lerp(skater.global_position, 0.1)
	
func handle(_delta: float, curSkater: Skater) -> void:
	self.skater = curSkater
	skater.impulse(dx, dy)

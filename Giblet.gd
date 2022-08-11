extends RigidBody

func _ready():
    physics_interpolation_mode = PHYSICS_INTERPOLATION_MODE_ON
    pass

var life = 4.0
func _process(delta):
    life -= delta
    if life <= 0.0:
        queue_free()

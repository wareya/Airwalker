extends RigidBody

func _ready():
    physics_interpolation_mode = PHYSICS_INTERPOLATION_MODE_ON
    pass

var max_life = 10.0
var life = max_life
func _process(delta):
    $CSGBox.global_transform = Transform.IDENTITY.translated(Vector3(0, -(1.0-life/max_life)*0.25, 0)) * global_transform
    $Particles.global_transform = $CSGBox.global_transform
    life -= delta
    if life <= 0.0:
        queue_free()

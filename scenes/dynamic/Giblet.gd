extends RigidBody

func _ready():
    old_xform = global_transform
    continuous_cd = true
    max_life += randf()
    life = max_life
    $Particles.emitting = true
    $Particles.lifetime += randf()

var max_life = 10.0
var life = max_life
var physics_ticked = false
func _process(delta):
    # GODOT BUG (3.5): continuous collision detection doesn't work properly
    # check if we traveled through the world and move back to the edge of the world if we did
    if physics_ticked:
        var old_origin = old_xform.origin
        var new_origin = global_translation
        $RayCast.global_translation = old_origin
        $RayCast.global_rotation = Vector3()
        $RayCast.cast_to = new_origin - old_origin
        $RayCast.collision_mask = collision_mask
        $RayCast.force_raycast_update()
        if $RayCast.is_colliding():
            var vec = $RayCast.get_collision_point() - old_origin
            var dist = min(0.125 * scale.x, vec.length())
            var dir = vec.normalized()
            global_translation = $RayCast.get_collision_point()
    physics_ticked = false
    
    var fract = Engine.get_physics_interpolation_fraction()
    var interpolated_xform = old_xform.interpolate_with(global_transform, fract)
    #$CSGBox.global_transform = Transform.IDENTITY.translated(Vector3(0, -(1.0-life/max_life)*0.25, 0)) * interpolated_xform
    $CSGBox.global_transform = interpolated_xform
    $Particles.global_transform = $CSGBox.global_transform
    life -= delta
    if life <= 0.0:
        queue_free()

var old_xform : Transform
func _physics_process(delta):
    old_xform = global_transform
    physics_ticked = true
    angular_damp = 1.0

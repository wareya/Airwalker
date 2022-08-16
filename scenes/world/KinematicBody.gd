extends KinematicBody

# FIXME move all this crap into a new parent script

var previous_global_transform = null
var previous_delta = 0.0

func get_real_velocity(foot_location : Vector3) -> Vector3:
    if previous_global_transform:
        var foreign_foot_location = global_transform.affine_inverse().xform(foot_location)
        var old_foot_location = previous_global_transform.xform(foreign_foot_location)
        return (foot_location - old_foot_location)/previous_delta
    else:
        return Vector3()

var life = 0.0
func _process(delta):
    previous_global_transform = global_transform
    life += delta
    rotation_degrees.y += 120.0*delta
    Gamemode.force_update_transform(self)
    previous_delta = delta

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

var prev_real_velocities = {}

func adjust_player(delta):
    var new_velocities = {}
    for _player in get_tree().get_nodes_in_group("Player"):
        var player : Spatial = _player
        if player.moving_platform_mode == 0:
            continue
        
        var real_velocity = get_real_velocity(player.calculate_foot_position())
        var prev_real_velocity = null
        if player in prev_real_velocities:
            prev_real_velocity = prev_real_velocities[player]
            
        if player.floor_collision and player.floor_collision.collider == self:
            new_velocities[player] = real_velocity
            if player.moving_platform_mode == 3:
                player.velocity.y = real_velocity.y
                if prev_real_velocity:
                    player.global_translation += (real_velocity - prev_real_velocity)*delta
            else:
                if prev_real_velocity:
                    var vel_diff = (real_velocity - prev_real_velocity)
                    player.global_translation += (real_velocity + vel_diff)*delta
                else:
                    player.global_translation += real_velocity*delta
        
    prev_real_velocities = new_velocities

var life = 0.0
func _process(delta):
    adjust_player(delta)
    previous_global_transform = global_transform
    life += delta
    rotation_degrees.y += 120.0*delta
    force_update_transform()
    previous_delta = delta

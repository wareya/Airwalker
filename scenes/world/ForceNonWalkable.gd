extends Spatial

func subtract_hull_size_from_distance(dist : Vector3):
    if $Shape.shape is BoxShape:
        var temp = dist.abs() - ($Shape.shape as BoxShape).extents
        temp.x = max(0, temp.x)
        temp.y = max(0, temp.y)
        temp.z = max(0, temp.z)
        return temp * dist.sign()
    elif $Shape.shape is CylinderShape:
        var height = ($Shape.shape as CylinderShape).height
        var radius = ($Shape.shape as CylinderShape).radius
        var horiz = Vector2(dist.x, dist.z).normalized() * radius
        var temp = dist.abs()
        temp.x -= abs(horiz.x)
        temp.y -= height
        temp.z -= abs(horiz.y)
        
        temp.x = max(0, temp.x)
        temp.y = max(0, temp.y)
        temp.z = max(0, temp.z)
        return temp * dist.sign()

func _process(delta):
    for _player in get_tree().get_nodes_in_group("Player"):
        var player : Spatial = _player
        var pos_diff_raw = player.global_transform.origin - global_transform.origin
        var pos_diff = player.subtract_hull_size_from_distance(pos_diff_raw)
        pos_diff = subtract_hull_size_from_distance(pos_diff)
        if pos_diff.length_squared() == 0.0:
            player.detach_from_floor()
            player.disable_air_control_this_frame()
            player.velocity += pos_diff_raw.normalized()*delta*4.0
        
    pass

extends Spatial

func _ready():
    pass

export var velocity : Vector3 = Vector3(0.0, 16.0, 0.0)

func subtract_hull_size_from_distance(dist : Vector3):
    if $Area/Hull.shape is BoxShape:
        var temp = dist.abs() - ($Area/Hull.shape as BoxShape).extents
        temp.x = max(0, temp.x)
        temp.y = max(0, temp.y)
        temp.z = max(0, temp.z)
        return temp * dist.sign()
    elif $Area/Hull.shape is CylinderShape:
        var height = ($Area/Hull.shape as CylinderShape).height
        var radius = ($Area/Hull.shape as CylinderShape).radius
        var horiz = Vector2(dist.x, dist.z).normalized() * radius
        var temp = dist.abs()
        temp.x -= abs(horiz.x)
        temp.y -= height
        temp.z -= abs(horiz.y)
        
         
        temp.x = max(0, temp.x)
        temp.y = max(0, temp.y)
        temp.z = max(0, temp.z)
        return temp * dist.sign()


func _process(_delta):
    for _player in get_tree().get_nodes_in_group("Player"):
        var player : Spatial = _player
        var pos_diff_raw = player.global_transform.origin - global_transform.origin
        var pos_diff = player.subtract_hull_size_from_distance(pos_diff_raw)
        pos_diff = subtract_hull_size_from_distance(pos_diff)
        if pos_diff.length_squared() == 0.0:
            player.global_translation = $Target.global_translation
            player.set_rotation($Target.global_transform.basis.get_euler().y + PI/2.0)
            player.velocity = $Target.global_transform.basis.xform(Vector3.LEFT) * 400.0/32.0
            player.reset_stair_camera_offset()
            player.detach_from_floor()
            # FIXME force a ground check
            print("teleporter")
            $Target/TeleportSFX.play()

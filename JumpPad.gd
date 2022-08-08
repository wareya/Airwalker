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

var ignore = {}

func _process(delta):
    for player in ignore:
        ignore[player] -= delta
        if ignore[player] <= 0.0:
            ignore.erase(player)
    for _player in get_tree().get_nodes_in_group("Player"):
        if _player in ignore:
            continue
        var player : Spatial = _player
        var pos_diff_raw = player.global_transform.origin - global_transform.origin
        var pos_diff = player.subtract_hull_size_from_distance(pos_diff_raw)
        pos_diff.x = pos_diff_raw.x
        pos_diff.z = pos_diff_raw.z
        pos_diff = subtract_hull_size_from_distance(pos_diff)
        if pos_diff.length_squared() == 0.0:
            player.remove_from_ground()
            player.velocity = global_transform.basis.xform(velocity)
            ignore[player] = 1.0
            print("jump check")
            $JumpSFX.play()
        
    pass

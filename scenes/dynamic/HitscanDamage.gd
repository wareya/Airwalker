extends RayCast
class_name HitscanDamage

var origin_player = null
var origin_player_id = null

# used in child class
var visual_start_position = null
func set_visual_start_position(_pos):
    visual_start_position = _pos

var damage = 5
func set_damage(_damage):
    damage = _damage

var knockback_scale = 1.0
func set_knockback_scale(_knockback_scale):
    knockback_scale = _knockback_scale

var set_distance = 0.0
func set_range(distance):
    set_distance = distance
    cast_to.z = -distance

var startpos = Vector3()
var endpos = Vector3()

var collider = null
func first_frame(_delta):
    startpos = global_translation
    endpos = global_translation
    force_raycast_update()
    if is_colliding():
        endpos = get_collision_point()
        collider = get_collider()
        if get_collider().is_in_group("Player"):
            var dir = (endpos-startpos).normalized()
            collider.apply_knockback(dir * damage * 1000.0 * knockback_scale / collider.unit_scale, "shotgun")
            collider.take_damage(damage, origin_player_id, "bullet")
    else:
        var xform = global_transform
        endpos = xform.xform(cast_to)

func _think(_delta):
    print("destroying via parent function")
    queue_free()

# wrap to avoid gdscript auto-super-call on _process override
func _process(delta):
    _think(delta)

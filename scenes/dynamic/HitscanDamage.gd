extends RayCast
class_name HitscanDamage

var origin_player = null
var origin_player_id = null

# used in child class
var visual_start_position = null
func set_visual_start_position(_pos):
    visual_start_position = _pos
var follow_aim_of = null
func set_follow_aim(_of):
    follow_aim_of = _of

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

func damage_collider():
    if collider and is_instance_valid(collider) and collider.is_in_group("Player"):
        var dir = (endpos-true_startpos).normalized()
        collider.apply_knockback(dir * damage * 1000.0 * knockback_scale / collider.unit_scale, "shotgun")
        collider.take_damage(damage, origin_player_id, "bullet", endpos)

var first = true
var collider = null
var true_startpos
func first_frame(delta):
    true_startpos = global_translation
    
    do_cast()
    damage_collider()
    
    if first and collider:
        var fx = EmitterFactory.emit("hita", self)
        fx.global_translation = endpos
        fx.force_update_transform()
        fx.unit_db -= 12
        fx.max_db -= 12
    
    _think(delta)

var virtual_cast_near_limit = 0.0

func do_cast():
    startpos = global_translation
    endpos = global_translation
    
    force_raycast_update()
    if is_colliding():
        endpos = get_collision_point()
        collider = get_collider()
    else:
        endpos = global_transform.xform(cast_to)
    
    if (endpos-startpos).length() > virtual_cast_near_limit and visual_start_position != null:
        startpos = visual_start_position
        global_transform.origin = startpos
        global_transform.basis = Transform.IDENTITY.looking_at(endpos - startpos, Vector3.UP).basis
    else:
        startpos += (endpos-startpos).normalized()*0.4
    

var spread_xform
func next_frame(delta):
    if !follow_aim_of or !is_instance_valid(follow_aim_of):
        return
    
    global_transform = follow_aim_of.get_aim_transform() * spread_xform
    var pos = follow_aim_of.get_muzzle_refpoint()
    if pos:
        set_visual_start_position(pos)
    
    do_cast()

# overridden by graphical child classes
func _think(_delta):
    queue_free()

# wrap to avoid gdscript auto-super-call on _process override
func _process(delta):
    next_frame(delta)
    _think(delta)

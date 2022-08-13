extends RayCast

var mat : SpatialMaterial
func _ready():
    mat = $MeshInstance.mesh.surface_get_material(0)
    mat = mat.duplicate()
    for _child in get_children():
        var child : GeometryInstance = _child
        child.material_override = mat

var visual_start_position = null
func set_visual_start_position(_pos):
    visual_start_position = _pos

var origin_player = null
var origin_player_id = null

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
func first_frame(delta):
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
    
    var original_distance = (endpos-startpos).length()
    var dir = (endpos-startpos).normalized()
    #print(original_distance)
    if original_distance > 0.5 and visual_start_position != null:
        startpos = visual_start_position
        global_transform.basis = Transform.IDENTITY.looking_at(endpos - startpos, Vector3.UP).basis
    else:
        startpos += dir*0.4
    
    _process(delta)

var fakespeed = 256.0*1.5

var first = false

var force_shrink = true

var max_scale = 32.0
var min_scale = 0.5
var max_life = 1.5
var life = max_life
var untouched_life = 0.0
var base_scale_limit = -1
func _process(delta):
    if collider != null and !is_instance_valid(collider):
        life = 0.0
    life = clamp(life-delta, 0.0, max_life)
    
    var dist = (endpos-startpos).length()
    var traveled = (max_life-life)*fakespeed
    var travel_fraction = traveled/dist
    var travel_scale = travel_fraction*dist
    
    if travel_fraction < 1.0:
        untouched_life = max_life - life
    elif base_scale_limit < 0:
        base_scale_limit = travel_scale
    
    if base_scale_limit > 0:
        var back_end_limit = traveled - max_scale
        var scale_floor = dist - back_end_limit
        scale_floor = max(min_scale, scale_floor)
        travel_scale = min(travel_scale, scale_floor)
    
    #var extra_dist_traveled = max(0.0, (max_life-untouched_life) - life)
    #travel_scale -= extra_dist_traveled*fakespeed
    #travel_scale = max(min(dist, min_scale), travel_scale)
    
    travel_scale = min(travel_scale, max_scale)
    travel_scale = min(travel_scale, dist)
    travel_scale = min(travel_scale, traveled*0.98)
    
    if force_shrink:
        var downscale = clamp(life/max(0.0001, max_life-untouched_life), 0.0, 1.0)
        travel_scale *= lerp(0.0, 1.0, downscale)
    
    if mat:
        var alpha = (life)/(max_life)
        mat.albedo_color.a = alpha*alpha
        mat.vertex_color_use_as_albedo = true
    
    scale.z = travel_scale
    global_translation = lerp(startpos, endpos, min(1.0, travel_fraction))
    if life <= 0.0:
        queue_free()

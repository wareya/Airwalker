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

func first_frame(delta):
    startpos = global_translation
    endpos = global_translation
    force_raycast_update()
    if is_colliding():
        endpos = get_collision_point()
        if get_collider().is_in_group("Player"):
            var player = get_collider()
            var dir = (endpos-startpos).normalized()
            player.apply_knockback(dir * damage * 1000.0 * knockback_scale / player.unit_scale, "shotgun")
            player.take_damage(damage, origin_player_id, "bullet")
    else:
        var xform = global_transform
        endpos = xform.xform(cast_to)
    
    var original_distance = (endpos-startpos).length()
    var dir = (endpos-startpos).normalized()
    print(original_distance)
    if original_distance > 0.5 and visual_start_position != null:
        startpos = visual_start_position
        global_transform.basis = Transform.IDENTITY.looking_at(endpos - startpos, Vector3.UP).basis
    else:
        startpos += dir*0.4
    
    _process(delta)

var fakespeed = 256.0

var first = false

var max_scale = 16.0
var max_life = 0.5
var life = max_life
var untouched_life = max_life
func _process(delta):
    life = clamp(life-delta, 0.0, max_life)
    
    var dist = (endpos-startpos).length()
    var traveled = (max_life-life)*fakespeed
    var travel_fraction = traveled/dist
    var travel_scale = max(0.01, min(travel_fraction*dist, max_scale))
    
    if travel_fraction < 1.0:
        untouched_life = max_life - life
    var downscale = clamp(life/max(0.0001, max_life-untouched_life), 0.0, 1.0)
    
    travel_scale = min(travel_scale, dist)
    travel_scale *= lerp(0.5, 1.0, downscale)
    
    if mat:
        var alpha = (life)/(max_life)
        #var time_alive = max_life - life
        #alpha *= clamp((time_alive-0.0)*30.0, 0.0, 1.0)
        mat.albedo_color.a = alpha*alpha
        mat.vertex_color_use_as_albedo = true
    
    scale.z = travel_scale
    global_translation = lerp(startpos, endpos, min(1.0, travel_fraction))
    if life <= 0.0:
        queue_free()

extends HitscanDamage

var mat : SpatialMaterial
func _ready():
    mat = $MeshInstance.mesh.surface_get_material(0)
    mat = mat.duplicate()
    for _child in get_children():
        var child : GeometryInstance = _child
        child.material_override = mat

var fakespeed = 256.0*1.5

var force_shrink = true

var max_scale = 32.0
var min_scale = 0.5
var max_life = 1.5
var life = max_life
var untouched_life = 0.0
var base_scale_limit = -1
# called by parent _process function
func _think(delta):
    if collider != null and !is_instance_valid(collider):
        life = 0.0
    life = clamp(life-delta, 0.0, max_life)
    
    var dist = (endpos-startpos).length()
    if dist == 0.0:
        return
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

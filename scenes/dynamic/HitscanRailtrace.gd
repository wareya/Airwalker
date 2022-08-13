extends HitscanDamage

var mat : SpatialMaterial
func _ready():
    mat = $MeshInstance.mesh.surface_get_material(0)
    mat = mat.duplicate()
    for _child in get_children():
        var child : GeometryInstance = _child
        child.material_override = mat

func first_frame(delta):
    .first_frame(delta) # call parent function
    
    var original_distance = (endpos-startpos).length()
    var dir = (endpos-startpos).normalized()
    
    if original_distance > 0.5 and visual_start_position != null:
        startpos = visual_start_position
        global_transform.origin = startpos
        global_transform.basis = Transform.IDENTITY.looking_at(endpos - startpos, Vector3.UP).basis
    else:
        startpos += dir*0.4
    
    _process(delta)

var max_life = 2.0
var life = max_life
# called by parent _process function
func _think(delta):
    life = clamp(life-delta, 0.0, max_life)
    
    var dist = (endpos-startpos).length()
    
    if mat:
        var alpha = (life)/(max_life)
        mat.albedo_color.a = alpha*alpha
        mat.vertex_color_use_as_albedo = true
    
    scale.z = -dist/2.0
    if life <= 0.0:
        queue_free()

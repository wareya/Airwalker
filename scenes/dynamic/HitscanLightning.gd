extends HitscanDamage

var mat : SpatialMaterial
func _ready():
    mat = $MeshInstance.mesh.surface_get_material(0)
    mat = mat.duplicate()
    for _child in get_children():
        var child : GeometryInstance = _child
        child.material_override = mat


var max_life = 2.0/15.0
var life = max_life
# called by parent _process function
func _think(delta):
    life = clamp(life-delta, 0.0, max_life)
    
    var dist = (endpos-startpos).length()
    
    if mat:
        var alpha = (life)/(max_life)
        mat.albedo_color.a = alpha*(1.0-alpha)*2.0
        mat.vertex_color_use_as_albedo = true
    
    scale.z = -dist/2.0
    if life <= 0.0:
        queue_free()

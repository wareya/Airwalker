extends Spatial

var max_life = 10.0
var life = max_life

func _ready():
    $RocketParticles2.emitting = false
    print("rocket spawned")
    pass

const unit_scale = 32.0
#var speed = 1150.0/unit_scale
var speed = 1000.0/unit_scale

func _process(delta):
    $CSGPolygon.rotation_degrees.x += delta*1000.0
    if abs(life-max_life) > 0.04:
        $RocketParticles2.emitting = true
    life -= delta
    if life <= 0.0:
        print("rocket killed")
        die()
        queue_free()
    
    advance(speed*delta)

func add_exception(other):
    $RayCast.add_exception(other)

func die():
    EmitterFactory.emit("rocketexplosion2", self)
    var particles : CPUParticles = load("res://RocketParticles.tscn").instance()
    particles.emitting = true
    get_parent().add_child(particles)
    particles.global_transform.origin = global_transform.origin
    particles.global_transform.origin -= global_transform.basis.xform($RayCast.cast_to).normalized()*0.5
    particles.global_transform.origin += $RayCast.get_collision_normal()*0.25
    
    var particles2 = $RocketParticles2
    remove_child(particles2)
    get_parent().add_child(particles2)
    particles2.emitting = false
    
    for _player in get_tree().get_nodes_in_group("Player"):
        var player : Spatial = _player
        var pos_diff_raw = player.global_transform.origin - global_transform.origin
        var pos_diff = player.subtract_hull_size_from_distance(pos_diff_raw)
        
        #var knockback_range = 125.0/unit_scale
        var knockback_range = 120.0/unit_scale
        var knockback_strength_min = 35.0/unit_scale
        var knockback_strength_max = 100.0/unit_scale
        
        var f = 1000.0
        var mass = 200.0
        
        if pos_diff.length() > knockback_range:
            continue
        
        # FIXME: self only?
        var knockback_dir = (pos_diff_raw + Vector3(0, 1.25/2.0, 0)).normalized()
        #var knockback_dir = pos_diff.normalized()
        #var knockback_falloff = 1.0/(pos_diff.length()*pos_diff.length())
        #var knockback_falloff = 1.0/pos_diff.length()
        var knockback_falloff = 1.0 - pos_diff.length()/knockback_range
        var knockback_strength =  lerp(knockback_strength_min, knockback_strength_max, knockback_falloff)
        print(pos_diff.length())
        print(knockback_falloff)
        print(knockback_dir)
        print(knockback_strength)
        player.velocity += knockback_dir * knockback_strength * f / mass
        player.floor_collision = null

var bounces = 0

func advance(distance):
    if life <= 0.0:
        return
    $RayCast.cast_to = Vector3.FORWARD * distance
    $RayCast.force_raycast_update()
    if $RayCast.is_colliding():
        speed = -speed
        bounces -= 1
        if bounces < 0:
            life = 0.0
            global_transform.origin = $RayCast.get_collision_point()
        #else:
        #    global_transform.basis = global_transform.basis.inverse()
    else:
        global_transform.origin += global_transform.basis.xform($RayCast.cast_to)

    

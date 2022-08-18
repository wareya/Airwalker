extends Spatial

var bounce_factor = 0.5 # vq3: 0.25???
var max_life = 1000.0
var life = max_life

func _ready():
    physics_interpolation_mode = PHYSICS_INTERPOLATION_MODE_OFF

const unit_scale = 32.0
var initial_speed = 2000.0/unit_scale # vq3: 700
var velocity = Vector3() 

func check_death():
    if life <= 0.0:
        die()
        queue_free()

var rot = randf()*PI*2.0
func _process(delta):
    life -= delta
    var mat : ShaderMaterial = $Billboard.mesh.surface_get_material(0)
    rot += delta*6.0
    mat.set_shader_param("uv_rotation", rot)
    check_death()
    advance(delta)

func add_exception(other):
    $RayCast.add_exception(other)

func first_frame(delta):
    velocity = global_transform.basis.xform(Vector3(0, 0, -initial_speed))
    global_rotation = Vector3()
    advance(0.05)
    advance(delta)

var origin_player = null
var origin_player_id = null

# CPMA: 18 damage on direct hit, 0~15 on splash
# VQ3: 0~14 on splash, PLUS 20 on direct hit (so 34 on direct hit)
func die():
    EmitterFactory.emit("plasmasplat", self)
    #var particles : CPUParticles = preload("res://scenes/dynamic/RocketParticles.tscn").instance()
    #particles.emitting = true
    #get_parent().add_child(particles)
    #particles.global_transform.origin = global_transform.origin
    #var asdf = global_transform.basis.xform(destination.normalized())*0.5
    #particles.global_transform.origin -= asdf
    #particles.global_transform.origin += 
    
    var light = $OmniLight
    light.fading = true
    remove_child(light)
    get_parent().add_child(light)
    light.global_translation = global_translation
    if $RayCast.is_colliding():
        print("collided")
        light.global_translation += $RayCast.get_collision_normal()*0.25
    else:
        print("not collided")
    
    for _object in get_tree().get_nodes_in_group("Player") + get_tree().get_nodes_in_group("ForceReceiver"):
        var object : Spatial = _object
        var pos_diff_raw = object.global_transform.origin - global_transform.origin
        var pos_diff = pos_diff_raw
        if object.has_method("subtract_hull_size_from_distance"):
            pos_diff = object.subtract_hull_size_from_distance(pos_diff_raw)
        
        var direct_hit = false
        # force direct hits to always be direct hits
        if $RayCast.is_colliding() and $RayCast.get_collider() == object:
            direct_hit = true
            pos_diff *= 0.0
        if force_collider == object:
            direct_hit = true
            pos_diff *= 0.0
        
        var knockback_range = 20.0/unit_scale
        #var knockback_strength_min = 1000.0 * 0.0/unit_scale
        #var knockback_strength_max = 1000.0 * 15.0/unit_scale
        
        if pos_diff.length() > knockback_range:
            continue
        
        var knockback_dir = (pos_diff_raw + Vector3(0, 0.625, 0)).normalized()
        var falloff = 1.0 - pos_diff.length()/knockback_range
        var damage = lerp(0, 15, falloff)
        if direct_hit:
            damage = 18
        var knockback_strength = 1000.0 * damage/unit_scale#lerp(knockback_strength_min, knockback_strength_max,
        
        if object.is_in_group("Player"):
            object.apply_knockback(knockback_dir * knockback_strength, "rocket")
            object.take_damage(damage, origin_player_id, "rocket")
        else:
            var force = knockback_dir * knockback_strength / 200.0
            if "linear_velocity" in object:
                object.linear_velocity += force
            elif "velocity" in object:
                object.velocity += force

var force_collider = null

func check_distance():
    for player in get_tree().get_nodes_in_group("Player"):
        if player == origin_player:
            continue
        var dist = global_translation - player.global_translation
        dist = player.subtract_hull_size_from_distance(dist)
        if dist == Vector3():
            life = 0.0
            force_collider = player
        break

var destination = Vector3()
func advance(delta):
    if life <= 0.0:
        return
    check_distance()
    
    destination = velocity * delta
    $RayCast.cast_to = velocity * (delta * 1.05) # collision margin equivalent for raycasts
    $RayCast.force_raycast_update()
    if $RayCast.is_colliding():
        force_collider = $RayCast.get_collider()
        life = 0.0
        global_transform.origin = $RayCast.get_collision_point()
    else:
        global_transform.origin += global_transform.basis.xform(destination)
    check_distance()
    check_death()

    

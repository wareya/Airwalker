extends Spatial

var max_life = 10.0
var life = max_life

func _ready():
    physics_interpolation_mode = PHYSICS_INTERPOLATION_MODE_OFF
    $RocketParticles2.emitting = false
    #print("rocket spawned")
    pass

const unit_scale = 32.0
#var speed = 1150.0/unit_scale
var speed = 1000.0/unit_scale

func check_death():
    if life <= 0.0:
        die()
        queue_free()

func _process(delta):
    $CSGPolygon.rotation_degrees.x += delta*1000.0
    if abs(life-max_life) > 0.04:
        $RocketParticles2.emitting = true
    life -= delta
    check_death()
        
    advance(speed*delta)

func add_exception(other):
    $RayCast.add_exception(other)

func first_frame(delta):
    advance(0.65)
    advance(speed*delta)
    force_update_transform()
    $RocketParticles.emitting = true

var origin_player = null
var origin_player_id = null

func die():
    EmitterFactory.emit("rocketexplosion2", self)
    var particles : CPUParticles = preload("res://scenes/dynamic/RocketParticles.tscn").instance()
    particles.emitting = true
    get_parent().add_child(particles)
    particles.global_transform.origin = global_transform.origin
    #print("-0-0---")
    var asdf = global_transform.basis.xform(destination.normalized())*0.5
    #print(destination)
    #print(global_transform.basis)
    #print(asdf)
    particles.global_transform.origin -= asdf
    particles.global_transform.origin += $RayCast.get_collision_normal()*0.25
    
    var particles2 = $RocketParticles2
    remove_child(particles2)
    get_parent().add_child(particles2)
    #particles2.emitting = false
    var _unused = get_tree().create_timer(particles2.lifetime, false).connect("timeout", particles2, "queue_free")
    
    for _object in get_tree().get_nodes_in_group("Player") + get_tree().get_nodes_in_group("ForceReceiver"):
        var object : Spatial = _object
        var pos_diff_raw = object.global_transform.origin - global_transform.origin
        var pos_diff = pos_diff_raw
        if object.has_method("subtract_hull_size_from_distance"):
            pos_diff = object.subtract_hull_size_from_distance(pos_diff_raw)
        # force direct hits to always be direct hits
        if $RayCast.is_colliding() and $RayCast.get_collider() == object:
            pos_diff *= 0.0
        if force_collider == object:
            pos_diff *= 0.0
        
        #var knockback_range = 125.0/unit_scale
        var knockback_range = 120.0/unit_scale
        var knockback_strength_min = 1000.0 * 35.0/unit_scale
        var knockback_strength_max = 1000.0 * 100.0/unit_scale
        
        if pos_diff.length() > knockback_range:
            continue
        
        var knockback_dir = (pos_diff_raw + Vector3(0, 0.625, 0)).normalized()
        var falloff = 1.0 - pos_diff.length()/knockback_range
        var knockback_strength = lerp(knockback_strength_min, knockback_strength_max, falloff)
        var damage = lerp(0, 100, falloff)
        
        # FIXME use a knockback function
        if object.is_in_group("Player"):
            object.apply_knockback(knockback_dir * knockback_strength, "rocket")
            object.take_damage(damage, origin_player_id, "rocket")
        else:
            var force = knockback_dir * knockback_strength / 200.0
            if "linear_velocity" in object:
                object.linear_velocity += force
            elif "velocity" in object:
                object.velocity += force
        

var bounces = 0

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
            #print("inside, dead rocket")
        break

var destination = Vector3()
func advance(distance):
    if life <= 0.0:
        return
    check_distance()
    
    destination = Vector3.FORWARD * distance
    $RayCast.cast_to = Vector3.FORWARD * (distance + 0.05) # collision margin equivalent for raycasts
    $RayCast.force_raycast_update()
    if $RayCast.is_colliding():
        if $RayCast.get_collider().is_in_group("Player"):
            bounces = 0
        if bounces > 0:
            var front = global_transform.basis.xform(Vector3.FORWARD)
            var normal = $RayCast.get_collision_normal()
            var amount = -2*front.project(normal)
            front += amount
            global_transform = global_transform.looking_at(global_translation+front, Vector3.UP)
        bounces -= 1
        if bounces < 0:
            #print("colliding, dead rocket")
            force_collider = $RayCast.get_collider()
            life = 0.0
            global_transform.origin = $RayCast.get_collision_point()
            $RayCast.enabled = false
        #else:
        #    global_transform.basis = global_transform.basis.inverse()
    else:
        global_transform.origin += global_transform.basis.xform(destination)
    check_distance()
    check_death()

    

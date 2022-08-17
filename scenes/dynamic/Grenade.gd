extends Spatial

var bounce_factor = 0.5 # vq3: 0.25???
var max_life = 2.0 # vq3: 2.5
var life = max_life

func _ready():
    physics_interpolation_mode = PHYSICS_INTERPOLATION_MODE_OFF

const unit_scale = 32.0
var initial_speed = 800.0/unit_scale # vq3: 700
var velocity = Vector3() 

func check_death():
    if life <= 0.0:
        die()
        queue_free()

var gravity = -800.0/32.0

var rotation_rate = Vector3(0.0, 0.0, 0.5)

func _process(delta):
    $CSGPolygon.rotation += rotation_rate*20.0 * delta
    life -= delta
    check_death()
    
    advance(delta)

func add_exception(other):
    $RayCast.add_exception(other)


func first_frame(delta):
    velocity = global_transform.basis.xform(Vector3(0, 0, -initial_speed))
    
    # push velocity upwards slightly to make aiming similar to quake 3
    velocity = velocity.normalized() + Vector3.UP*0.2
    velocity = velocity.normalized() * initial_speed
    
    advance(0.05)
    advance(delta)

var origin_player = null
var origin_player_id = null

func die():
    EmitterFactory.emit("rocketexplosion2", self)
    var particles : CPUParticles = preload("res://scenes/dynamic/RocketParticles.tscn").instance()
    particles.emitting = true
    get_parent().add_child(particles)
    particles.global_transform.origin = global_transform.origin
    var asdf = global_transform.basis.xform(destination.normalized())*0.5
    particles.global_transform.origin -= asdf
    particles.global_transform.origin += $RayCast.get_collision_normal()*0.25
    
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
        var knockback_range = 150.0/unit_scale
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
        

var bounces = -1

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
func advance(delta, nograv = false):
    if life <= 0.0:
        return
    check_distance()
    
    if !nograv:
        velocity.y += gravity*delta/2.0
    
    var framevel = global_transform.basis.xform_inv(velocity)
    
    destination = framevel * delta
    $RayCast.cast_to = framevel * (delta * 1.05) # collision margin equivalent for raycasts
    $RayCast.force_raycast_update()
    if $RayCast.is_colliding():
        if $RayCast.get_collider().is_in_group("Player"):
            bounces = 0
        if bounces != 0:
            var normal = $RayCast.get_collision_normal()
            var reflection = normal*normal.dot(velocity)
            velocity -= 2.0*reflection
            velocity *= bounce_factor
            bounces -= 1
            if velocity.length() > 2.0 and bounces != 0:
                var fx = EmitterFactory.emit("grenadebounce", self)
                fx.unit_db -= 6
                fx.max_db -= 6
                rotation_rate = Vector3(randf(), randf(), randf())
            else:
                rotation_rate = lerp(rotation_rate, Vector3(), 1.0 - pow(0.001, delta))
        if bounces == 0:
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
    
    if !nograv:
        velocity.y += gravity*delta/2.0

    

extends QuakelikeBody


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

enum {
    MOVING_PLATFORM_IGNORE,
    MOVING_PLATFORM_NO_INHERIT,
    MOVING_PLATFORM_FULL_INHERIT,
    MOVING_PLATFORM_PHYSICAL,
}

export var moving_platform_mode : int = MOVING_PLATFORM_IGNORE
export var moving_platform_jump_ignore_vertical : bool = false

func set_rotation(y):
    $CameraHolder.rotation.y = y
    $CameraHolder.rotation.x = 0

func add_rotation(y):
    $CameraHolder.rotation.y += y

func reset_stair_camera_offset():
    $CameraHolder/Camera.reset_stair_offset()

# Called when the node enters the scene tree for the first time.
func _ready():
    $CameraHolder.rotation.y = rotation.y
    $"CamRelative/WeaponHolder/CSGPolygon".cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
    rotation.y = 0
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    pass # Replace with function body.

func angle_diff(a, b):
    var ret = a - b
    if ret > 180:
        ret -= 360
    if ret < -180:
        ret += 360
    return ret

const unit_scale = 32.0

var maxspeed = 320.0/unit_scale
var accel = maxspeed*15.0
var gravity = 800/unit_scale
var jumpstr = 270.0/unit_scale

var initial_grav = round(gravity*0.013*unit_scale)/0.013/unit_scale

var maxspeed_qwair = 30.0/unit_scale
var accel_qwair = 70.0*maxspeed_qwair

var accel_q3air = maxspeed*1.0

var accel_funnyair = maxspeed * 15.0

# FIXME: non-accurate
# derived from the maxspeed you get bunnyhopping in a straight line
# forwards, but spamming between front-left and front-right wishdir
# which is ~452.
#var funnyair_maxspeed = 450.0/unit_scale

var stopspeed = 100.0/unit_scale
var friction = 6.0#/unit_scale

var velocity = Vector3()

var stair_cooldown = 0.0

func _friction(_velocity : Vector3, delta : float) -> Vector3:
    var _stopspeed = stopspeed#*100.0
    if wishdir != Vector3():
        _stopspeed = 0.0
    var speed = _velocity.length()
    var drag
    if speed >= _stopspeed:
        drag = max(0.0, 1.0 - friction*delta)
    elif speed > 0.0:
        drag = max(0.0, 1.0 - _stopspeed*friction*delta/speed)
    else:
        drag = 1.0
    _velocity *= drag
    return _velocity

var jump_state_timer_max = 0.4
var jump_state_timer = 0

func remove_from_ground():
    floor_collision = null

var air_control_disabled_this_frame = false
func disable_air_control_this_frame():
    air_control_disabled_this_frame = true

func subtract_hull_size_from_distance(dist : Vector3):
    var temp = dist.abs() - ($Hull.shape as BoxShape).extents
    temp.x = max(0, temp.x)
    temp.y = max(0, temp.y)
    temp.z = max(0, temp.z)
    return temp * dist.sign()

var simtimer = 0

onready var peak = global_transform.origin.y
var peak_time = 0

onready var last_jump_coordinate = global_transform.origin

var time_of_shot = 0.0
var time_of_landing = 0.0
var time_alive = 0.0
var sway_timer = 0.0
var sway_rate_multiplier = 1.0

var can_doublejump = false

func calculate_foot_position():
    return global_translation + Vector3.DOWN*$Hull.shape.extents.y

var previous_on_floor = false
var previous_velocity = velocity
var want_to_jump = false
var reload = 0.0
var sway_memory = 0.0
var cam_angle_memory = Vector2()
var cam_sway_memory = Vector2()
var sway_strength = 0.5
var force_sway_to = 0.0
var force_sway_amount = 0.0
var wishdir = Vector3()
var prev_floor_transform = null
var prev_floor_collision = null
func _process(delta):
    stair_query_fallback_distance = 0.05
    use_fallback_stair_logic = true
    #if Input.is_action_pressed("m1"):
    #    Engine.time_scale = 0.1
    #else:
    #    Engine.time_scale = 1.0
    
    time_alive += delta
    if Input.is_action_just_pressed("jump"):
        want_to_jump = true
        can_doublejump = true
    if Input.is_action_just_released("jump"):
        can_doublejump = false
        want_to_jump = false
    
    if Input.is_action_just_pressed("ui_page_up"):
        if get_viewport().debug_draw:
            get_viewport().debug_draw = 0
        else:
            get_viewport().debug_draw = Viewport.DEBUG_DRAW_OVERDRAW
        pass
    
    want_to_jump = Input.is_action_pressed("jump")
    
    var prev_simtimer = simtimer
    simtimer += delta
    delta = (floor(simtimer*1000) - floor(prev_simtimer*1000))/1000
    if delta < 0.001:
        return
    
    
    if global_transform.origin.y > peak:
        peak = global_transform.origin.y
        #print("new peak: %s" % (peak*unit_scale))
        peak_time = simtimer
    
    if peak_time + 1 < simtimer:
        peak = global_transform.origin.y
    
    HUD.get_node("Peak").text = "%s\n%s\n%s\n%s\n%s\n%s\n%s" % \
        [(peak*unit_scale),
        vector_reject(velocity,
        Vector3.DOWN).length()*unit_scale,
        velocity.length()*unit_scale,
        is_on_floor(),
        global_translation*unit_scale,
        velocity.y*unit_scale,
        Engine.get_frames_per_second()]
    if jump_state_timer > 0:
        jump_state_timer -= delta
    
    wishdir = Vector3()
    if Input.is_action_pressed("ui_up"):
        wishdir += Vector3.FORWARD
    if Input.is_action_pressed("ui_down"):
        wishdir += Vector3.BACK
    if Input.is_action_pressed("ui_right"):
        wishdir += Vector3.RIGHT
    if Input.is_action_pressed("ui_left"):
        wishdir += Vector3.LEFT
    if wishdir.length_squared() > 0:
        wishdir = wishdir.normalized()
    
    var closest_ground = null
    closest_ground = my_move_and_collide(Vector3.DOWN*stair_height, true, true)
    
    if !previous_on_floor and floor_collision:
        if previous_velocity.y < -7.5:
            time_of_landing = time_alive
            EmitterFactory.emit("HybridFoley4").volume_db = -9
            sway_timer = fmod(sway_timer, PI*2.0)
            if sway_timer >= PI*1.0:
                force_sway_to = 0.0
            else:
                force_sway_to = PI
            force_sway_amount = 1.0
    
    reload = reload-delta
    if Input.is_action_pressed("m1") and reload <= 0.0:
        time_of_shot = time_alive
        reload += 0.8
        var rocket : Spatial = load("res://Rocket.tscn").instance()
        get_parent().add_child(rocket)
        $CamRelative/RayCast.force_raycast_update()
        if !$CamRelative/RayCast.is_colliding():
            rocket.global_transform = $CamRelative/RocketOrigin.global_transform
        elif $CamRelative/RayCast.get_collision_point().distance_to(
                $CamRelative/RayCast.global_transform.origin
            ) > 10.0:
            rocket.global_transform = $CamRelative/RocketOrigin.global_transform
            rocket.global_transform = rocket.global_transform.looking_at($CamRelative/RayCast.get_collision_point(), Vector3.UP)
        else:
            rocket.global_transform = $CamRelative/RayCast.global_transform
        
        rocket.add_exception(self)
        EmitterFactory.emit("rocketshot")
        rocket.advance(0.65)
        rocket.force_update_transform()
        (rocket.get_node("RocketParticles") as CPUParticles).emitting = true
    reload = max(reload, 0.0)

    var floor_velocity = Vector3()
    if (moving_platform_mode == 3 and is_on_floor() and delta > 0.0
    and floor_collision and is_instance_valid(floor_collision.collider)
    and prev_floor_collision and is_instance_valid(prev_floor_collision.collider)
    and prev_floor_collision.collider == floor_collision.collider
    and prev_floor_transform):
        var floor_object : Spatial = floor_collision.collider
        if floor_object.has_method("get_real_velocity"):
            floor_velocity = floor_object.get_real_velocity(calculate_foot_position())
        else:
            var foot_location = calculate_foot_position()
            var foreign_foot_location = floor_object.global_transform.affine_inverse().xform(foot_location)
            var old_foot_location = prev_floor_transform.xform(foreign_foot_location)
            floor_velocity = (foot_location - old_foot_location)/delta
    
    if is_on_floor() and want_to_jump:
        #EmitterFactory.emit("HybridFoley")
        if !$JumpSound.playing or $JumpSound.get_playback_position() > 0.20 or can_doublejump:
            #print($JumpSound.get_playback_position())
            if jump_state_timer > 0 and can_doublejump:
                $JumpSound.pitch_scale = 1.15
            else:
                $JumpSound.pitch_scale = 1.0
            $JumpSound.play()
        want_to_jump = false
        #print("jumping....")
        #print(velocity*unit_scale)
        #print(floor_collision.normal)
        velocity = vector_reject(velocity, floor_collision.normal)
        print("-----")
        print(floor_collision.collider_velocity)
        #print(velocity*unit_scale)
        
        var my_jumpstr = jumpstr
        
        if jump_state_timer > 0 and can_doublejump:
            print("doublejumped")
            my_jumpstr *= 38.0/27.0
            if jump_state_timer < 0.35:
                jump_state_timer = 0
            else:
                jump_state_timer = jump_state_timer_max
        else:
            jump_state_timer = jump_state_timer_max
        can_doublejump = false
        
        if velocity.y > 0 and velocity.length() < 200:
            velocity.y += my_jumpstr*Vector3.UP.y
        else: 
            velocity.y = max(velocity.y, my_jumpstr*Vector3.UP.y)
        #print(velocity*unit_scale)
        
        var floor_boost = Vector3()
        if moving_platform_mode == 2:
            floor_boost = floor_collision.collider_velocity
        elif moving_platform_mode == 3:
            floor_boost = vector_project(floor_collision.collider_velocity, floor_collision.normal)
        if moving_platform_jump_ignore_vertical:
            floor_boost.y = 0.0
        print(floor_boost)
        velocity += floor_boost
        
        #print(my_jumpstr)
        floor_collision = null
        last_jump_coordinate = global_transform.origin
        #print(velocity.y)
    
    var forward = Vector3.FORWARD.rotated(Vector3.UP, $CameraHolder.rotation.y)
    var right   = Vector3.RIGHT  .rotated(Vector3.UP, $CameraHolder.rotation.y)
    if is_on_floor():
        forward = vector_reject(forward, floor_collision.normal).normalized()
        right   = vector_reject(right  , floor_collision.normal).normalized()
    
    var global_wishdir = wishdir.x*right - wishdir.z*forward
    
    #print(velocity.y)
    
    var oldvel = velocity
    
    if is_on_floor():
        velocity += delta*Vector3.DOWN*gravity*0.0 # no gravity at all on ground
    elif jump_state_timer > 0:
        velocity += delta*Vector3.DOWN*initial_grav
    else:
        velocity += delta*Vector3.DOWN*gravity
    
    if is_on_floor():
        velocity -= floor_velocity
        velocity = _friction(velocity, delta)
    
    if wishdir != Vector3():
        var down = Vector3.DOWN
        if floor_collision:
            down = floor_collision.normal
        
        var acceldirspeed = vector_reject(velocity, down).dot(global_wishdir)
        #print("-----")
        #print(wishdir)
        #print(acceldirspeed)
        #print(maxspeed)
        var actual_accel = accel
        var actual_maxspeed = maxspeed
        if !is_on_floor() and air_control_disabled_this_frame:
            actual_accel *= 0.0
        if !is_on_floor() and !air_control_disabled_this_frame:
            if abs(wishdir.x) == 1.0:
                actual_accel = accel_qwair
                actual_maxspeed = maxspeed_qwair
                #print(actual_accel)
                #print(actual_maxspeed)
            else:
                #print("????")
                actual_accel = accel_q3air
                # if pointing straight forward
                if abs(wishdir.z) == 1.0:
                    #print("bwuh")
                    var flatdir = Vector3(velocity.x, 0, velocity.z)
                    var flatspeed = flatdir.length()
                    
                    # faster when going forwards, and also forwards-only
                    # (otherwise only base air accel will be effective)
                    var accel_factor = max(flatdir.normalized().dot(global_wishdir), 0.0)
                    var new_accel = accel_funnyair * accel_factor * accel_factor
                    flatdir += global_wishdir * new_accel * delta
                    flatdir = flatdir.normalized() * flatspeed
                    velocity.x = flatdir.x
                    velocity.z = flatdir.z
                    
                    #if accel_factor > 0.5:
                    #    do something with funnyair_maxspeed
        
        
        if acceldirspeed < actual_maxspeed:
            #print("adding...")
            velocity += global_wishdir*actual_accel*delta
            acceldirspeed = vector_reject(velocity, down).dot(global_wishdir)
            
            if acceldirspeed > actual_maxspeed:
                var overshoot = velocity - global_wishdir*actual_maxspeed
                overshoot = overshoot.project(global_wishdir)
                #print(overshoot.length())
                velocity -= overshoot
    
    air_control_disabled_this_frame = false
    
    if floor_collision and velocity.length() > 0.01:
        var tempdot = velocity.normalized().dot(-floor_collision.normal)
        #var tempdot = velocity.normalized().dot(Vector3.DOWN)
        var oldspeed = velocity.length()
        velocity = vector_reject(velocity, floor_collision.normal)
        #velocity = vector_reject(velocity, Vector3.DOWN)
        if tempdot > 0.0 and tempdot < 0.7 and velocity.length() > 0:
            velocity *= oldspeed/velocity.length()
            #print("dot: ", tempdot)
            #print(floor_collision.normal)
            #print("overbounce fixed")
            #print(vector_reject(velocity, Vector3.DOWN).length())
        #elif tempdot > 0.
    
    if is_on_floor():
        velocity += floor_velocity
    
    var newvel = velocity
    velocity = oldvel
    var vel_delta = newvel - oldvel
    
    velocity.x += vel_delta.x
    vel_delta.x = 0
    
    velocity.z += vel_delta.z
    vel_delta.z = 0
    
    velocity += vel_delta/2
    
    
    $CamRelative/WeaponHolder.transform = Transform.IDENTITY
    
    var kickback_amount = clamp(time_of_shot + 0.5 - time_alive, 0.0, 1.0) / 0.5
    $CamRelative/WeaponHolder.transform.origin.z += lerp(0.0, 0.4, kickback_amount*kickback_amount)
    $CamRelative/WeaponHolder.transform.basis = Basis.IDENTITY.rotated(Vector3.RIGHT, smoothstep(0.0, 1.0, kickback_amount)*0.1)
    
    var kickdown_amount = clamp(time_of_landing + 1.0 - time_alive, 0.0, 1.0) / 1.0
    #var raw_kickdown_amount = kickdown_amount
    kickdown_amount = kickdown_amount*kickdown_amount
    kickdown_amount = kickdown_amount*kickdown_amount
    kickdown_amount = kickdown_amount*kickdown_amount
    kickdown_amount = kickdown_amount * (1.0-kickdown_amount) * 4.0
    kickdown_amount = kickdown_amount*kickdown_amount
    $CamRelative/WeaponHolder.transform.origin.y -= lerp(0.0, 0.05, kickdown_amount)
    
    if is_on_floor():
        sway_rate_multiplier = 1.0
    else:
        sway_rate_multiplier = move_toward(sway_rate_multiplier, 0.25, delta/4.0)
    if force_sway_amount > 0.0:
        sway_timer = fmod(sway_timer, PI*2.0)
        var target = fmod(force_sway_to, PI*2.0)
        if target < sway_timer:
            target += PI*2.0
        sway_timer = lerp(sway_timer, target, clamp(delta*4.0/force_sway_amount, 0.0, 1.0))
        force_sway_amount = clamp(force_sway_amount-delta*4.0, 0.0, 1.0)
    else:
        sway_timer += delta*PI*sway_rate_multiplier
    var sway_amount = lerp(0.001, 0.05, clamp(((velocity - floor_velocity)*Vector3(1, 0, 1)).length()/32.0, 0.0, 1.0)*0.5)
    sway_amount = lerp(sway_memory, sway_amount, 1.0 - pow(0.001, delta))
    sway_memory = sway_amount
    sway_amount *= sway_strength
    #sway_amount *= 1.0 - kickdown_amount
    $CamRelative/WeaponHolder.transform.origin.y += sin(sway_timer*2.0)*sway_amount
    $CamRelative/WeaponHolder.transform.origin.x += sin(sway_timer+1.5)*sway_amount*2.0*4.0
    
    var cam_sway_amount_y = 0.001*angle_diff($CamRelative.rotation_degrees.y, cam_angle_memory.y)/delta
    var cam_sway_amount_x = 0.001*angle_diff($CamRelative.rotation_degrees.x, cam_angle_memory.x)/delta
    var cam_sway_amount = Vector2(cam_sway_amount_x, cam_sway_amount_y)
    cam_angle_memory = Vector2($CamRelative.rotation_degrees.x, $CamRelative.rotation_degrees.y)
    cam_sway_amount = (cam_sway_amount as Vector2).limit_length(1.0)
    cam_sway_amount = cam_sway_memory.linear_interpolate(cam_sway_amount, 1.0 - pow(0.001, delta))
    cam_sway_memory = cam_sway_amount
    $CamRelative/WeaponHolder.transform.origin.x += cam_sway_amount.y * 0.2
    $CamRelative/WeaponHolder.transform.origin.y += cam_sway_amount.x * -0.2
    
    
    var actual_stair_height = stair_height
    do_stairs = is_on_floor() or jump_state_timer > 0.0 or velocity.y <= 0
    if !do_stairs and closest_ground:
        do_stairs = true
        stair_height = abs(closest_ground.remainder.y)
    
    if moving_platform_mode > 1:
        if floor_collision and prev_floor_collision and floor_collision.collider == prev_floor_collision.collider:
            var rotation_diff = floor_collision.collider.global_rotation.y - prev_floor_transform.basis.get_euler().y
            add_rotation(rotation_diff)
    
    if floor_collision and is_instance_valid(floor_collision.collider):
        prev_floor_transform = floor_collision.collider.global_transform
        prev_floor_collision = floor_collision
    else:
        prev_floor_transform = null
        prev_floor_collision = null
    
    previous_velocity = velocity
    previous_on_floor = floor_collision != null
    
    force_update_transform()
    #move_and_collide(Vector3(), true, true)
    var new_velocity = custom_move_and_slide(delta, velocity)
    velocity.y = new_velocity.y
    
    # hack to make badly placed jumppads work
    var minspeed = 0.1
    if !is_on_floor() and velocity.y > 0.0 and abs(new_velocity.x) < minspeed and abs(velocity.x) > minspeed:
        velocity.x = sign(velocity.x)*minspeed
    else:
        velocity.x = new_velocity.x
    if !is_on_floor() and velocity.y > 0.0 and abs(new_velocity.z) < minspeed and abs(velocity.z) > minspeed:
        velocity.z = sign(velocity.z)*minspeed
    else:
        velocity.z = new_velocity.z
    
    stair_height = actual_stair_height
    
    if did_stairs:
        stair_cooldown = $CameraHolder/Camera.correction_window
        print("stepped")
    
    if !is_on_floor() or stair_cooldown == 0.0:
        reset_stair_camera_offset()
    stair_cooldown = clamp(stair_cooldown-delta, 0.0, 1.0)
    
    #    print("stairstepped")
    #    print("before stairs: ", before_velocity*unit_scale)
    #    print("after stairs : ", velocity*unit_scale)
    #    print("would-be delta : ", vel_delta/2*unit_scale)
    
    velocity += vel_delta/2
    
        
    
    
    pass

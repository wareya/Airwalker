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

export var moving_platform_mode : int = MOVING_PLATFORM_NO_INHERIT
export var moving_platform_jump_ignore_vertical : bool = false
export var pogostick_jumping : bool = true
export var is_player : bool = false

func set_rotation(y):
    $CameraHolder.rotation.y = y
    $CameraHolder.rotation.x = 0

func add_rotation(y):
    $CameraHolder.rotation.y += y

func reset_stair_camera_offset():
    camera.reset_stair_offset()
    pass

onready var base_model_offset = $Model.translation
func _ready():
    #NavigationServer.region_bake_navmesh()
    $CameraHolder.rotation.y = rotation.y
    rotation.y = 0
    check_first_person_visibility()
    $Hull2.queue_free()

var third_person = false

var weapon_offset = Vector3()

onready var camera : Camera = $CameraHolder/Camera

func check_first_person_visibility():
    third_person = false
    camera.input_enabled = is_player
    var player_check = !is_player or third_person
    
    camera.current = !is_player
    
    if !player_check:
        for child in $Model/Armature/Skeleton.get_children():
            child.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_ON
            child.visible = true
        $Model.visible = true
        $"CamRelative/WeaponHolder/CSGPolygon".cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_ON
        weapon_offset.x = 0.3
        weapon_offset.y = 0.1
        $CameraHolder/CamBasePos.translation = Vector3(0, 0.5 * cos($CameraHolder.rotation.x), 2)
    else:
        for _child in $Model/Armature/Skeleton.get_children():
            var child : MeshInstance = _child
            child.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
            child.visible = false
        $Model.visible = false
        $"CamRelative/WeaponHolder/CSGPolygon".cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
        weapon_offset.x = 0
        weapon_offset.y = 0
        $CameraHolder/CamBasePos.translation = Vector3()
    
    $Model.rotation.y = $CameraHolder.rotation.y + PI - offset_angle
    
func update_from_camera_smoothing():
    var amount = camera.smoothing_amount
    if amount > 0.0001:
        print(amount)
    $Model.translation.y = base_model_offset.y + amount
    $CamRelative.visible = true
    $CamRelative.global_transform = $CameraHolder.global_transform
    $CamRelative.global_translation.y += amount


var anim_lock_time = 0.0
func play_no_self_override(anim, speed, blendmult) -> bool:
    for anim_name in $Model/AnimationPlayer.get_animation_list():
        var _anim : Animation = $Model/AnimationPlayer.get_animation(anim_name)
        for t in _anim.get_track_count():
            _anim.track_set_interpolation_type(t, Animation.INTERPOLATION_LINEAR)
            _anim.track_set_interpolation_loop_wrap(t, true)
    for anim in ["Walk", "Idle", "Run", "Air", "Float"]:
        $Model/AnimationPlayer.get_animation(anim).loop = true
    for anim in ["Land", "Jump", "ArmSwing"]:
        $Model/AnimationPlayer.get_animation(anim).loop = false
    if anim_lock_time > 0.0:
        return false
    if $Model/AnimationPlayer.current_animation != anim:
        var blendrate = 0.1 * blendmult
        blendrate *= abs(speed)
        $Model/AnimationPlayer.play(anim, blendrate, 1.0)
        $Model/AnimationPlayer.advance(0.0)
        $Model/AnimationPlayer.playback_speed = speed
        return true
    else:
        $Model/AnimationPlayer.playback_speed = speed
        return false

func play_animation(anim : String, speed : float = 1.0):
    var anim_table = {
        "idle"  :  {name="Idle" , speed=0.25},
        "float" :  {name="Float", speed=1.0, blend=2.0},
        "air"   :  {name="Air"  , speed=1.0, blend=2.0},
        "walk"  :  {name="Walk" , speed=2.0},
        "run"   :  {name="Run" , speed=2.0},
        "jump"  :  {name="Jump" , speed=1.0, blend=0.5, override_lock=true},
        "land"  :  {name="Land" , speed=1.5, lock=0.2},
    }
    if anim in anim_table:
        var blendmult = 1.0
        if "blend" in anim_table[anim]:
            blendmult = anim_table[anim]["blend"]
        if "override_lock" in anim_table[anim]:
            anim_lock_time = 0.0
        if play_no_self_override(anim_table[anim].name, speed*anim_table[anim].speed, blendmult):
            if "lock" in anim_table[anim]:
                anim_lock_time = anim_table[anim].lock

var last_offset_angle = 0.0
var offset_angle = 0.0
var anim_walk_backwards = false
func do_evil_anim_things(delta):
    anim_walk_backwards = false
    offset_angle = 0.0
    if wishdir.length_squared() > 0.0:
        offset_angle = Vector2().angle_to_point(Vector2(wishdir.z, -wishdir.x))
    if wishdir.z > 0:
        anim_walk_backwards = true
        offset_angle = Vector2().angle_to_point(Vector2(-wishdir.z, wishdir.x))
    
    offset_angle = lerp(last_offset_angle, offset_angle, 1.0 - pow(0.0001, delta))
    
    last_offset_angle = offset_angle
    
    var skele : Skeleton = $Model/Armature/Skeleton
    var root = skele.find_bone("Bone")
    var leg_L = skele.find_bone("Bone_L.002")
    var leg_R = skele.find_bone("Bone_R.002")
    var lower_chest = skele.find_bone("Bone.002")
    var upper_chest = skele.find_bone("Bone.003")
    var neck = skele.find_bone("Bone.004")
    
    skele.clear_bones_global_pose_override()
    
    #var offset_amount = -0.05
    var xform3 = Transform.IDENTITY.rotated(Vector3.UP, offset_angle/6.0)
    var xform4 = Transform.IDENTITY.rotated(Vector3.UP, -offset_angle/2.0).rotated(Vector3.RIGHT, -$CameraHolder.rotation.x/8.0).rotated(Vector3.UP, offset_angle/1.666)
    
    for target in [root, leg_L, leg_R, lower_chest, upper_chest, neck]:
        var xform : Transform = skele.get_bone_global_pose(target)
        if target == lower_chest:
            xform = xform3 * xform * xform3
        elif target == upper_chest:
            xform = xform4 * xform * xform4
        elif target == leg_L or target == leg_R:
            xform = xform3.inverse() * xform
        elif target == root:
            xform = xform3 * xform
        elif target == neck:
            xform = xform4 * xform * xform4
        else:
            xform = xform3 * xform * xform3
        skele.set_bone_global_pose_override(target, xform, 1.0, true)
    

func angle_diff(a, b):
    var ret = a - b
    if ret > 180:
        ret -= 360
    if ret < -180:
        ret += 360
    return ret

const unit_scale = 32.0

var maxspeed = 320.0/unit_scale
var accel_ratio = 15.0
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

class Inputs extends Reference:
    var jump : bool
    var jump_pressed : bool
    var jump_released : bool
    
    var m1 : bool
    var m1_pressed : bool
    var m1_released : bool
    
    var m2 : bool
    var m2_pressed : bool
    var m2_released : bool
    
    var walk : bool
    
    func clear():
        jump = false
        jump_pressed = false
        jump_released = false
        
        m1 = false
        m1_pressed = false
        m1_released = false
        
        m2 = false
        m2_pressed = false
        m2_released = false
        
        walk = false

var wishdir = Vector3()
var inputs : Inputs = Inputs.new()

func update_inputs():
    if !is_player:
        return
    inputs.jump = Input.is_action_pressed("jump")
    inputs.jump_pressed = Input.is_action_just_pressed("jump")
    inputs.jump_released = Input.is_action_just_released("jump")
    
    inputs.m1 = Input.is_action_pressed("m1")
    inputs.m1_pressed = Input.is_action_just_pressed("m1")
    inputs.m1_released = Input.is_action_just_released("m1")
    
    inputs.m2 = false
    inputs.m2_pressed = false
    inputs.m2_released = false
    
    inputs.walk = Input.is_action_pressed("walk")
    
    wishdir = Vector3()
    if Input.is_action_pressed("ui_up"):
        wishdir += Vector3.FORWARD
    if Input.is_action_pressed("ui_down"):
        wishdir += Vector3.BACK
    if Input.is_action_pressed("ui_right"):
        wishdir += Vector3.RIGHT
    if Input.is_action_pressed("ui_left"):
        wishdir += Vector3.LEFT
    if wishdir.length_squared() > 1.0:
        wishdir = wishdir.normalized()

func angle_get_delta(a : float, b : float) -> float:
    a = fposmod(a, PI*2.0)
    b = fposmod(b, PI*2.0)
    var delta = b-a
    if delta < -PI:
        delta += PI*2.0
    elif delta > PI:
        delta -= PI*2.0
    return delta

func angle_move_toward(a : float, b : float, amount : float) -> float:
    var delta = angle_get_delta(a, b)
    var motion = clamp(delta, -amount, amount)
    return fposmod(a+motion, PI*2.0)

var ai_angle_inertia = 0.0
var ai_angle_accel = PI*16.0
var ai_turn_rate_limit = PI*2.0
func ai_apply_turn_logic(target_angle, delta):
    ai_angle_accel = PI*12.0
    var old_angle = $CameraHolder.rotation.y
    var new_angle = angle_move_toward(old_angle, target_angle, ai_turn_rate_limit*delta)
    var target_angle_velocity = -angle_get_delta(new_angle, old_angle)/delta
    
    var actual_accel = ai_angle_accel
    
    var to_target = angle_get_delta(old_angle, target_angle)
    
    var stopping_distance = ai_angle_inertia*ai_angle_inertia / (2.0*actual_accel)
    
    #if Engine.get_frames_drawn() % 10 == 0:
    #    print([round(rad2deg(to_target)), round(rad2deg(stopping_distance))])
    if abs(to_target) < abs(stopping_distance):
        target_angle_velocity = 0.0
    
    ai_angle_inertia = move_toward(ai_angle_inertia, target_angle_velocity, actual_accel*delta)
    $CameraHolder.rotation.y = old_angle + ai_angle_inertia*delta

var last_used_nav_pos = Vector3()
func do_ai(delta):
    #if Engine.time_scale > 0.5:
    #    print("----")
    #    print(angle_get_delta(0.0, PI*1.01))
    #    print(angle_get_delta(0.0, PI*0.99))
    #    print(angle_get_delta(PI*1.01, 0.0))
    #    print(angle_get_delta(PI*0.99, 0.0))
    #    print(angle_get_delta(PI+0.0, PI+PI*1.01))
    #    print(angle_get_delta(PI+0.0, PI+PI*0.99))
    #    print(angle_get_delta(PI+PI*1.01, PI+0.0))
    #    print(angle_get_delta(PI+PI*0.99, PI+0.0))
    $CSGBox.visible = false
    if is_player:
        return
    inputs.clear()
    
    wishdir = Vector3()
    
    var player = null
    for other in get_tree().get_nodes_in_group("Player"):
        if other.is_player:
            player = other
            break
    if !player:
        return
    #if !is_on_floor():
    #    return
    
    #$CSGBox.visible = true
    if navigable_floor_is_up_to_date:
        $CSGBox.global_translation = navigable_floor
        $Navigation.global_translation = navigable_floor
        
    $Navigation/Agent.set_target_location(player.navigable_floor)
    var next_pos = $Navigation/Agent.get_next_location()
    var target_pos = $Navigation/Agent.get_target_location()
    
    if !$Navigation/Agent.is_target_reachable():
        if (last_used_nav_pos - navigable_floor).length() > 0.1:
            print("resetting", last_used_nav_pos, navigable_floor)
        navigable_floor = last_used_nav_pos
        $CSGBox.global_translation = last_used_nav_pos
        $Navigation.global_translation = last_used_nav_pos
        $Navigation/Agent.set_target_location(player.navigable_floor)
        next_pos = $Navigation/Agent.get_next_location()
        target_pos = $Navigation/Agent.get_target_location()
    
    if !$Navigation/Agent.is_target_reachable():
        #print("not reachable")
        return
    last_used_nav_pos = $Navigation.global_translation
    
    var target_diff = player.global_translation - global_translation
    $TargetFinder.collision_mask = 3
    $TargetFinder.cast_to = target_diff
    $TargetFinder.force_raycast_update()
    var found_player = null
    if $TargetFinder.is_colliding() and $TargetFinder.get_collider() == player:
        found_player = player
    
    # try to avoid getting stuck when the navigation system deletes essential points
    if is_on_wall():
        var new_next_pos = next_pos + $Model.global_transform.basis.xform(Vector3(2.0 * sign(sin(time_alive*4.0)), 0.0, 1.0 * sign(sin(time_alive*7.1))))
        next_pos = new_next_pos
        $CSGBox.visible = true
        $CSGBox.global_translation = new_next_pos
    var diff = next_pos - global_translation
    var horiz_diff = Vector3(target_diff.x, 0, target_diff.z)
    #if abs(ai_angle_inertia) > PI and Engine.time_scale > 0.5:
    #    print(ai_angle_inertia)
    if horiz_diff.length() > 0.1:
        if target_diff.length() > 6.0 or !found_player:
            var target_angle = Vector2().angle_to_point(Vector2(diff.z, diff.x))
            ai_apply_turn_logic(target_angle, delta)
            
            var angle_diff = target_angle - $CameraHolder.rotation.y
            while angle_diff < -PI:
                angle_diff += PI*2.0
            while angle_diff > PI:
                angle_diff -= PI*2.0
            angle_diff = rad2deg(angle_diff)
            if abs(angle_diff) < 22.5:
                wishdir = Vector3.FORWARD
            elif angle_diff > 0.0 and angle_diff < 90.0:
                wishdir = Vector3.FORWARD + Vector3.LEFT
            elif angle_diff < 0.0 and angle_diff > -90.0:
                wishdir = Vector3.FORWARD + Vector3.RIGHT
        else:
            var target_angle = Vector2().angle_to_point(Vector2(target_diff.z, target_diff.x))
            ai_apply_turn_logic(target_angle, delta)
            
            var strafe_time = 2.0
            var strafe_timer = fmod(time_alive, strafe_time*3.0)/strafe_time*2.0
            var strafe_dir = 0.0 
            if strafe_timer < 2.0:
                strafe_dir = sin(strafe_timer*PI) + sin(strafe_timer*PI*3.0)*1.5
            elif strafe_timer < 4.0:
                strafe_dir = cos(strafe_timer*PI) + cos(strafe_timer*PI*3.0)*0.5
            else:
                strafe_dir = sin(strafe_timer*PI*2.0)
                
            wishdir = Vector3.RIGHT * strafe_dir
            
        wishdir = wishdir.normalized()

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
var prev_floor_transform = null
var prev_floor_collision = null
func _process(delta):
    time_alive += delta
    anim_lock_time -= delta
    
    check_first_person_visibility()
    update_inputs()
    do_ai(delta)
    
    if is_player:
        if Input.is_action_just_pressed("ui_page_down"):
            if Engine.time_scale > 0.5:
                Engine.time_scale = 0.00001
            else:
                Engine.time_scale = 1.0
        
        # FIXME move to hud
        if Input.is_action_just_pressed("ui_page_up"):
            if get_viewport().debug_draw:
                get_viewport().debug_draw = 0
            else:
                get_viewport().debug_draw = Viewport.DEBUG_DRAW_OVERDRAW
            pass
    
    if inputs.jump_pressed:
        want_to_jump = true
        can_doublejump = true
    if inputs.jump_released:
        can_doublejump = false
        want_to_jump = false
    
    if pogostick_jumping:
        want_to_jump = inputs.jump
    
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
    if jump_state_timer > 0:
        jump_state_timer -= delta
    
    var closest_ground = null
    closest_ground = my_move_and_collide(Vector3.DOWN*stair_height, true, true)
    
    if !previous_on_floor and floor_collision:
        velocity = vector_reject(velocity, floor_collision.normal)
        var floor_boost = Vector3()
        if moving_platform_mode == 2:
            floor_boost = floor_collision.collider_velocity
        elif moving_platform_mode == 3:
            floor_boost = vector_project(floor_collision.collider_velocity, floor_collision.normal)
        if moving_platform_jump_ignore_vertical:
            floor_boost.y = 0.0
        #print(floor_boost)
        velocity -= floor_boost
        #print("subtracting... " + str(floor_boost))
        
        if previous_velocity.y < -7.5:
            time_of_landing = time_alive
            if is_player:
                EmitterFactory.emit("HybridFoley4").volume_db = -9.0
            else:
                var effect : AudioStreamPlayer3D = EmitterFactory.emit("HybridFoley4", self)
                effect.max_db = -9.0
                effect.unit_db = 40
            sway_timer = fmod(sway_timer, PI*2.0)
            if sway_timer >= PI*1.0:
                force_sway_to = 0.0
            else:
                force_sway_to = PI
            force_sway_amount = 1.0
            play_animation("land")
    
    reload = reload-delta
    if inputs.m1 and reload <= 0.0:
        time_of_shot = time_alive
        reload += 0.8
        var rocket : Spatial = load("res://Rocket.tscn").instance()
        rocket.origin_player = self
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
        if is_player:
            EmitterFactory.emit("rocketshot").volume_db = -9.0
        else:
            (EmitterFactory.emit("rocketshot", self) as AudioStreamPlayer3D).unit_db -= 9.0
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
    
    var floor_collision_before_jump = floor_collision
    var did_jump = false
    if is_on_floor() and want_to_jump:
        did_jump = true
        sway_rate_multiplier = 1.0
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
        #print("-----")
        #print(floor_collision.collider_velocity)
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
        var actual_maxspeed = maxspeed
        if inputs.walk:
            actual_maxspeed *= 160.0/320.0
        var actual_accel = actual_maxspeed*accel_ratio
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
    $CamRelative/WeaponHolder.translation.z += lerp(0.0, 0.4, kickback_amount*kickback_amount)
    $CamRelative/WeaponHolder.transform.basis = Basis.IDENTITY.rotated(Vector3.RIGHT, smoothstep(0.0, 1.0, kickback_amount)*0.1)
    
    var kickdown_amount = clamp(time_of_landing + 1.0 - time_alive, 0.0, 1.0) / 1.0
    #var raw_kickdown_amount = kickdown_amount
    kickdown_amount = kickdown_amount*kickdown_amount
    kickdown_amount = kickdown_amount*kickdown_amount
    kickdown_amount = kickdown_amount*kickdown_amount
    kickdown_amount = kickdown_amount * (1.0-kickdown_amount) * 4.0
    kickdown_amount = kickdown_amount*kickdown_amount
    $CamRelative/WeaponHolder.translation.y -= lerp(0.0, 0.05, kickdown_amount)
    $CamRelative/WeaponHolder.translation += weapon_offset
    if third_person:
        $CamRelative/WeaponHolder.global_translation += Transform.IDENTITY.rotated(Vector3.RIGHT, $CameraHolder.rotation.x+PI/2.0).rotated(Vector3.UP, $CameraHolder.rotation.y).xform(Vector3(0, 0, -0.5))*Vector3(1, 0, 1)
    
    if is_on_floor():
        sway_rate_multiplier = 1.0
    else:
        sway_rate_multiplier = move_toward(sway_rate_multiplier, 0.25, delta*0.25)
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
    
    # FIXME move to HUD
    
    if is_player:
        HUD.get_node("Peak").text = "%s\n%s\n%s\n%s\n%s\n%s\n%s" % \
            [(peak*unit_scale),
            (velocity * Vector3(1,0,1)).length()*unit_scale,
            velocity.length()*unit_scale,
            is_on_floor(),
            global_translation*unit_scale,
            velocity.y*unit_scale,
            Engine.get_frames_per_second()]
        
        HUD.get_node("ArrowUp").visible = wishdir.z < 0
        HUD.get_node("ArrowDown").visible = wishdir.z > 0
        HUD.get_node("ArrowLeft").visible = wishdir.x < 0
        HUD.get_node("ArrowRight").visible = wishdir.x > 0
        HUD.get_node("ArrowJump").visible = inputs.jump
        if can_doublejump and jump_state_timer > 0:
            HUD.get_node("ArrowJump").modulate = Color.turquoise
        else:
            HUD.get_node("ArrowJump").modulate = Color.white
        if !want_to_jump and !pogostick_jumping:
            HUD.get_node("ArrowJump").modulate.a = 0.5
        else:
            HUD.get_node("ArrowJump").modulate.a = 1.0
    
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
    
    # check for having left the floor (jump or otherwise)
    if !floor_collision and floor_collision_before_jump:
        var floor_boost = Vector3()
        if moving_platform_mode == 2:
            floor_boost = floor_collision_before_jump.collider_velocity
        elif moving_platform_mode == 3:
            floor_boost = vector_project(floor_collision_before_jump.collider_velocity, floor_collision_before_jump.normal)
        if moving_platform_jump_ignore_vertical:
            floor_boost.y = 0.0
        #print(floor_boost)
        velocity += floor_boost
    
    stair_height = actual_stair_height
    
    if did_stairs:
        stair_cooldown = camera.correction_window
        print("stepped")
    
    if !is_on_floor() or stair_cooldown == 0.0:
        reset_stair_camera_offset()
    stair_cooldown = clamp(stair_cooldown-delta, 0.0, 1.0)
    
    #    print("stairstepped")
    #    print("before stairs: ", before_velocity*unit_scale)
    #    print("after stairs : ", velocity*unit_scale)
    #    print("would-be delta : ", vel_delta/2*unit_scale)
    
    var floorspeed = (velocity*Vector3(1, 0, 1)).length()
    
    if is_on_floor():
        if floorspeed*unit_scale > 280:
            var walkspeed = clamp(floorspeed*unit_scale/320, 0.0, 1.0)
            if anim_walk_backwards:
                walkspeed *= -1.0
            play_animation("run", walkspeed)
        elif floorspeed*unit_scale > 0.5:
            var walkspeed = clamp(floorspeed*unit_scale/320, 0.0, 1.0)
            if anim_walk_backwards:
                walkspeed *= -1.0
            play_animation("walk", walkspeed)
        else:
            play_animation("idle", 1.0)
    elif did_jump:
        play_animation("jump", 1.0)
    elif $Model/AnimationPlayer.current_animation != "Jump":
        if abs(velocity.y*unit_scale) > 320.0:
            play_animation("float", 1.0)
        else:
            play_animation("air", 1.0)
    do_evil_anim_things(delta)
    
    velocity += vel_delta/2
    
    find_navigable_floor()

var navigable_floor = null
var navigable_floor_is_up_to_date = false
func find_navigable_floor():
    navigable_floor_is_up_to_date = false
    collision_mask ^= 2
    var collision = find_real_collision(Vector3.DOWN*64.0)
    if collision and collision_is_floor({normal=collision.collision_normal}):
        navigable_floor = global_translation + collision.motion
        navigable_floor_is_up_to_date = true
    collision_mask ^= 2


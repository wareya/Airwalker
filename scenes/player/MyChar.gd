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

var player_id = -1

func force_take_camera():
    $CameraHolder/Camera.make_current()

func remove_camera():
    var ret = $CameraHolder/Camera
    $CameraHolder.remove_child($CameraHolder/Camera)
    return ret

func get_camera_transform():
    return $CameraHolder.global_transform

func set_rotation(y, x = 0):
    print("setting rotation")
    $CameraHolder.rotation.y = y
    $CameraHolder.rotation.x = x
    cam_angle_memory = Vector2(rad2deg(x), rad2deg(y))
    update_from_camera_smoothing()

func add_rotation(y):
    $CameraHolder.rotation.y += y
    cam_angle_memory.y += y
    update_from_camera_smoothing()

func reset_stair_camera_offset():
    camera.reset_stair_offset()

onready var base_model_offset = $Model.translation
func _ready():
    $CameraHolder.rotation.y = rotation.y
    rotation.y = 0
    check_first_person_visibility()
    $Hull2.queue_free()
    
    for anim in ["Walk", "Idle", "Run", "Air", "Float"]:
        $Model/AnimationPlayer.get_animation(anim).loop = true
    for anim in ["Land", "Jump", "ArmSwing"]:
        $Model/AnimationPlayer.get_animation(anim).loop = false
    
    for anim_name in $Model/AnimationPlayer.get_animation_list():
        var _anim : Animation = $Model/AnimationPlayer.get_animation(anim_name)
        for t in _anim.get_track_count():
            _anim.track_set_interpolation_type(t, Animation.INTERPOLATION_LINEAR)
            _anim.track_set_interpolation_loop_wrap(t, true)
    
    $Model/Armature.translation.z = -0.08

var bone_index_cache = {}
func do_ik_for_side(solver_name : String, root : String, tip : String, skip_if_above):
    var index
    if tip in bone_index_cache:
        index = bone_index_cache[tip]
    else:
        index = $Model/Armature/Skeleton.find_bone(tip)
        bone_index_cache[tip] = index
    
    var xform = $Model/Armature/Skeleton.global_transform * $Model/Armature/Skeleton.get_bone_global_pose(index)
    var origin = xform.origin
    
    var add_to_skeleton = false
    var solver
    if get(solver_name) == null:
        solver = SkeletonIK.new()
        set(solver_name, solver)
        add_to_skeleton = true
    else:
        solver = get(solver_name)
    
    $IKFinder.global_rotation = $Model.global_rotation
    $IKFinder.global_translation = origin + Vector3(0, 1.0, 0)
    $IKFinder.cast_to = Vector3(0, -2.0, 0)
    $IKFinder.force_raycast_update()
    var end_pos = $IKFinder.global_translation + $IKFinder.cast_to
    if $IKFinder.is_colliding():
        end_pos = $IKFinder.get_collision_point()
        #print(end_pos)
    end_pos.y = max($DummyIKThing.global_translation.y + $Model/Armature/Skeleton.translation.y, end_pos.y)
    
    if end_pos.y < origin.y and skip_if_above:
        return
    
    if root.ends_with(".003"):
        solver.use_magnet = false
    else:
        solver.magnet = Vector3.BACK*4.0
        solver.use_magnet = true
    solver.root_bone = root
    solver.tip_bone  = tip
    solver.max_iterations = 3
    solver.min_distance = 0.01
    solver.override_tip_basis = false
    solver.target = $IKFinder.global_transform.translated(end_pos - $IKFinder.global_translation)
    #solver.target = Transform.IDENTITY.translated(end_pos)
    
    if add_to_skeleton:
        $Model/Armature/Skeleton.add_child(solver)
    solver.start(true)

# offset into ground for slopes stairs etc so it doesn't look like you're floating
# note: we don't want to use this for the camera; it's not what people are used to & affects aiming
var offset_memory = 0.0

var foot_ik_l1 = null
var foot_ik_l2 = null
var foot_ik_r1 = null
var foot_ik_r2 = null

func do_anim_ik(delta):
    # TODO: make this optional. it has a meaningful performance impact (~0.25ms per character on an i5 6600)
    if true:
        return
    var offset_average = 0.0
    if is_on_floor():
        var normalize = 0.0
        var _range = 1
        $OffsetFinder.translation.y = 0.0
        $OffsetFinder.cast_to.y = -stair_height + $DummyIKThing.translation.y
        for x in range(-_range, _range+1):
            for z in range(-_range, _range+1):
                var _x = x/float(_range)*0.1
                var _z = z/float(_range)*0.1
                $OffsetFinder.translation.x = _x + _z/float(_range*2+1)
                $OffsetFinder.translation.z = _z - _x/float(_range*2+1)
                $OffsetFinder.force_raycast_update()
                if $OffsetFinder.is_colliding() and $OffsetFinder.get_collision_normal().y > floor_normal_threshold:
                    var end_pos = $OffsetFinder.get_collision_point().y
                    end_pos -= $DummyIKThing.global_translation.y
                    offset_average += end_pos
                    normalize += 1.0
        if normalize > 0.0:
            offset_average /= normalize
        #if is_player:
        #    print(offset_average, " ", normalize)
    
    offset_memory = lerp(offset_memory, offset_average, 1.0 - pow(0.0001, delta))
    $Model/Armature.translation.y = 1.24
    $Model/Armature/Skeleton.translation.y = offset_memory
    
    if !is_on_floor():
        return
    
    var current_anim = $Model/AnimationPlayer.current_animation
    var force = current_anim == "Idle"
    
    if force or current_anim in ["Walk", "Run"]:
        do_ik_for_side("foot_ik_r1", "Bone_R.001", "Bone_R.003", !force)
        do_ik_for_side("foot_ik_r2", "Bone_R.003", "Bone_R.004", !force)
    if force or current_anim in ["Walk", "Run"]:
        do_ik_for_side("foot_ik_l1", "Bone_L.001", "Bone_L.003", !force)
        do_ik_for_side("foot_ik_l2", "Bone_L.003", "Bone_L.004", !force)

var third_person = false

var weapon_offset = Vector3()

onready var camera : Camera = $CameraHolder/Camera

var first_person_see_body = false

var is_perspective = false
func check_first_person_visibility():
    third_person = false
    camera.input_enabled = is_player
    
    is_perspective = is_player
    if Gamemode.watch_ai:
        is_perspective = !is_perspective
    camera.current = is_perspective
    
    if !is_perspective or third_person or first_person_see_body:
        for child in $Model/Armature/Skeleton.get_children():
            if not child is GeometryInstance:
                continue
            child.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_ON
            child.visible = true
            ((child as GeometryInstance).get_active_material(0) as SpatialMaterial).params_cull_mode = SpatialMaterial.CULL_BACK
        $Model.visible = true
    else:
        for _child in $Model/Armature/Skeleton.get_children():
            if not _child is GeometryInstance:
                continue
            var child : GeometryInstance = _child
            child.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
            child.visible = false
        $Model.visible = false
    
    if !is_perspective or third_person:
        for _child in $CamRelative/WeaponHolder.get_children():
            if not _child is GeometryInstance:
                continue
            var child : GeometryInstance = _child
            child.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_ON
        weapon_offset.x = 0.3
        weapon_offset.y = 0.1
        $CameraHolder/CamBasePos.translation = Vector3(0, 0.5 * cos($CameraHolder.rotation.x), 2)
    else:
        for _child in $CamRelative/WeaponHolder.get_children():
            if not _child is GeometryInstance:
                continue
            var child : GeometryInstance = _child
            child.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
        weapon_offset.x = 0
        weapon_offset.y = 0
        $CameraHolder/CamBasePos.translation = Vector3()
    
    $Model.rotation.y = $CameraHolder.rotation.y + PI - offset_angle
    
func update_from_camera_smoothing():
    var amount = camera.smoothing_amount
    #if amount > 0.0001:
    #    print(amount)
    $Model.translation.y = base_model_offset.y + amount
    $CamRelative.visible = true
    $CamRelative.global_transform = $CameraHolder.global_transform
    $CamRelative.global_translation.y += amount


var anim_lock_time = 0.0
func play_no_self_override(anim, speed, blendmult) -> bool:
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

var anim_table = {
    "idle"  :  {name="Idle" , speed=0.25},
    "float" :  {name="Float", speed=1.0, blend=2.0},
    "air"   :  {name="Air"  , speed=1.0, blend=2.0},
    "walk"  :  {name="Walk" , speed=2.0},
    "run"   :  {name="Run"  , speed=2.0},
    "jump"  :  {name="Jump" , speed=1.0, blend=0.5, override_lock=true},
    "land"  :  {name="Land" , speed=1.5, lock=0.2},
}
func play_animation(anim : String, speed : float = 1.0):
    if anim in anim_table:
        var blendmult = 1.0
        if "blend" in anim_table[anim]:
            blendmult = anim_table[anim]["blend"]
        if "override_lock" in anim_table[anim]:
            anim_lock_time = 0.0
        if play_no_self_override(anim_table[anim].name, speed*anim_table[anim].speed, blendmult):
            if "lock" in anim_table[anim]:
                anim_lock_time = anim_table[anim].lock
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
    
    do_anim_ik(delta)
    

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
    
    var weapon_intent = ""
    var mwheel_change = 0
    
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
        
        weapon_intent = ""
        mwheel_change = 0

var wishdir = Vector3()
var global_wishdir = Vector3()
var inputs : Inputs = Inputs.new()

func update_inputs():
    if !is_player:
        return
    inputs.clear()
    
    inputs.jump = Input.is_action_pressed("jump")
    inputs.jump_pressed = Input.is_action_just_pressed("jump")
    inputs.jump_released = Input.is_action_just_released("jump")
    
    inputs.m1 = Input.is_action_pressed("m1")
    inputs.m1_pressed = Input.is_action_just_pressed("m1")
    inputs.m1_released = Input.is_action_just_released("m1")
    
    inputs.m2 = Input.is_action_pressed("m2")
    inputs.m2_pressed = Input.is_action_just_pressed("m2")
    inputs.m2_released = Input.is_action_just_released("m2")
    
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
    
    if Input.is_action_just_pressed("w_machine"):
        inputs.weapon_intent = "machinegun"
    if Input.is_action_just_pressed("w_rail"):
        inputs.weapon_intent = "railgun"
    if Input.is_action_just_pressed("w_rocket"):
        inputs.weapon_intent = "rocket"
    if Input.is_action_just_pressed("w_shaft"):
        inputs.weapon_intent = "lightninggun"
    if Input.is_action_just_pressed("w_shotgun"):
        inputs.weapon_intent = "shotgun"
    if Input.is_action_just_pressed("w_grenade"):
        inputs.weapon_intent = "grenade"
    if Input.is_action_just_pressed("w_plasma"):
        inputs.weapon_intent = "plasma"
    
    if Input.is_action_just_released("mwheelup"):
        inputs.mwheel_change -= 1
    if Input.is_action_just_released("mwheeldown"):
        inputs.mwheel_change += 1


func process_inputs():
    if inputs.jump_pressed:
        want_to_jump = true
        can_doublejump = true
    if inputs.jump_released:
        can_doublejump = false
        want_to_jump = false
    
    if pogostick_jumping:
        want_to_jump = inputs.jump
    
    if inputs.mwheel_change != 0:
        var current_index = weapon_list.find(desired_weapon)
        var next_index = (current_index + inputs.mwheel_change) % weapon_list.size()
        desired_weapon = weapon_list[next_index]
    
    if inputs.weapon_intent != "":
        desired_weapon = inputs.weapon_intent

func build_weapon_db():
    return {
        "rocket" : {
            model = preload("res://scenes/player/RocketLauncherCSG.tscn"),
            #model_offset = Vector3(0.023, -0.375, -0.115),
            model_offset = Vector3(0.15, -0.45, -0.1),
            projectile = preload("res://scenes/dynamic/Rocket.tscn"),
            projectile_origin = $CamRelative/RocketOrigin,
            projectile_count = 1,
            projectile_spread = 0.0,
            hitscan_count = 0,
            hitscan_spread = 0.0,
            hitscan_damage = 0,
            hitscan_range = 0.0,
            hitscan_knockback_scale = 0.0,
            hitscan_scene = "",
            hitscan_follows_aim = false,
            kickback_scale = 1.0,
            sfx = "rocketshot",
            sfx_once = "",
            sfx_idle = null,
            sfx_idle_shoot = null,
            reload_time = 0.8,
        },
        "grenade" : {
            model = preload("res://scenes/player/GrenadeLauncherCSG.tscn"),
            model_offset = Vector3(0.15, -0.35, -0.1),
            projectile = preload("res://scenes/dynamic/Grenade.tscn"),
            projectile_origin = $CamRelative/RocketOrigin,
            projectile_count = 1,
            projectile_spread = 0.0,
            hitscan_count = 0,
            hitscan_spread = 0.0,
            hitscan_damage = 0,
            hitscan_range = 0.0,
            hitscan_knockback_scale = 0.0,
            hitscan_scene = "",
            hitscan_follows_aim = false,
            kickback_scale = 0.65,
            sfx = "grenadeshot",
            sfx_once = "",
            sfx_idle = null,
            sfx_idle_shoot = null,
            reload_time = 0.8,
        },
        "plasma" : {
            model = preload("res://scenes/player/PlasmagunCSG.tscn"),
            model_offset = Vector3(0.0, -0.6, -0.2),
            projectile = preload("res://scenes/dynamic/Plasma.tscn"),
            projectile_origin = $CamRelative/RocketOrigin,
            projectile_count = 1,
            projectile_spread = 0.0,
            hitscan_count = 0,
            hitscan_spread = 0.0,
            hitscan_damage = 0,
            hitscan_range = 0.0,
            hitscan_knockback_scale = 0.0,
            hitscan_scene = "",
            hitscan_follows_aim = false,
            kickback_scale = 0.5,
            sfx = "plasmashot",
            sfx_once = "",
            sfx_idle = preload("res://sfx/PlasmaIdle.wav"),
            sfx_idle_shoot = preload("res://sfx/PlasmaIdle.wav"),
            reload_time = 0.1,
        },
        "shotgun" : {
            model = preload("res://scenes/player/ShotgunCSG.tscn"),
            model_offset = Vector3(0.0, -0.6, -0.4),
            projectile = null,
            projectile_origin = null,
            projectile_count = 0,
            projectile_spread = 0.0,
            hitscan_count = 16,
            #hitscan_spread = atan(700.0/8192.0), # vq3
            hitscan_spread = atan(900.0/8192.0), # cpma
            hitscan_damage = 6,
            hitscan_range = 8192.0/unit_scale, # FIXME double check
            hitscan_knockback_scale = 1.0/3.0,
            hitscan_scene = preload("res://scenes/dynamic/HitscanTracer.tscn"),
            hitscan_follows_aim = false,
            kickback_scale = 1.0,
            sfx = "shotgunshot",
            sfx_once = "",
            sfx_idle = null,
            sfx_idle_shoot = null,
            reload_time = 0.95,
            # FIXME the way "penetration" works for CPMA's shotgun is very weird
        },
        "machinegun" : {
            model = preload("res://scenes/player/MachinegunCSG.tscn"),
            model_offset = Vector3(0.0, -0.5, -0.2),
            projectile = null,
            projectile_origin = null,
            projectile_count = 0,
            projectile_spread = 0.0,
            hitscan_count = 1,
            hitscan_spread = atan(200.0/8192.0),
            hitscan_damage = 5, # vq3 damage is gamemode-sensitive :| just use cpma damage
            hitscan_range = 8192.0/unit_scale, # FIXME double check
            hitscan_knockback_scale = 1.0,
            hitscan_scene = preload("res://scenes/dynamic/HitscanTracer.tscn"),
            hitscan_follows_aim = false,
            kickback_scale = 0.4,
            sfx = "machinegunshot",
            sfx_once = "",
            sfx_idle = null,
            sfx_idle_shoot = null,
            reload_time = 0.1,
        },
        "lightninggun" : {
            model = preload("res://scenes/player/LightninggunCSG.tscn"),
            model_offset = Vector3(0.0, -0.55, -0.3),
            projectile = null,
            projectile_origin = null,
            projectile_count = 0,
            projectile_spread = 0.0,
            hitscan_count = 1,
            hitscan_spread = 0.0,
            hitscan_damage = 10,
            hitscan_range = 768.0/unit_scale,
            hitscan_knockback_scale = 1.5,
            hitscan_scene = preload("res://scenes/dynamic/HitscanLightning.tscn"),
            hitscan_follows_aim = true,
            kickback_scale = 0.5,
            sfx = "",
            sfx_once = "thunderclap",
            sfx_idle = preload("res://sfx/LightningIdle.wav"),
            sfx_idle_shoot = preload("res://sfx/LightningBuzz.wav"),
            reload_time = 1.0/15.0,
            # FIXME add 100ms cooldown
        },
        "railgun" : {
            model = preload("res://scenes/player/RailgunCSG.tscn"),
            model_offset = Vector3(0.15, -0.475, -0.115),
            projectile = null,
            projectile_origin = null,
            projectile_count = 0,
            projectile_spread = 0.0,
            hitscan_count = 1,
            hitscan_spread = 0.0,
            hitscan_damage = 80,
            hitscan_range = 8192.0/unit_scale, # FIXME double check
            hitscan_knockback_scale = 1.0,
            hitscan_scene = preload("res://scenes/dynamic/HitscanRailtrace.tscn"),
            hitscan_follows_aim = false,
            kickback_scale = 1.0,
            sfx = "railgunshot",
            sfx_once = "",
            sfx_idle = preload("res://sfx/RailgunIdle.wav"),
            sfx_idle_shoot = null,
            reload_time = 1.25,
            # FIXME pierce
        },
    }

func get_aim_transform():
    $CamRelative/RayCast.force_raycast_update()
    var aim_transform = Transform.IDENTITY
    if !$CamRelative/RayCast.is_colliding():
        aim_transform = $CamRelative/RocketOrigin.global_transform
    elif $CamRelative/RayCast.get_collision_point().distance_to(
            $CamRelative/RayCast.global_transform.origin
        ) > 10.0: # not if it's too close
        aim_transform = $CamRelative/RocketOrigin.global_transform
        aim_transform = aim_transform.looking_at($CamRelative/RayCast.get_collision_point(), Vector3.UP)
    else:
        aim_transform = $CamRelative/RayCast.global_transform
    return aim_transform

func get_muzzle_refpoint():
    var refpos = $CamRelative/WeaponHolder.find_node("EffectReference", true, false)
    if refpos:
        var pos = refpos.global_translation
        if is_perspective:
            var center = $CamRelative/RayCast.global_translation
            pos = (pos-center)*3.0 + center
        return pos
    return null

onready var weapon_db = build_weapon_db()

# melee, mg, shotgun, grenade, rocket, lg, railgun, plasma, bfg, grapple
var weapon_list = ["machinegun", "shotgun", "grenade", "rocket", "lightninggun", "railgun", "plasma"]
var current_weapon = ""
var desired_weapon = "machinegun"
func weapon_think(delta):
    var first_shot = reload == 0.0
    var weapon_info = weapon_db[current_weapon]
    if reload > 0.0 and weapon_info.sfx_idle_shoot != null:
        if $WeaponSoundLoop.stream != weapon_info.sfx_idle_shoot:
            $WeaponSoundLoop.stream = weapon_info.sfx_idle_shoot
            $WeaponSoundLoop.playing = true
    elif weapon_info.sfx_idle != null:
        if $WeaponSoundLoop.stream != weapon_info.sfx_idle:
            $WeaponSoundLoop.stream = weapon_info.sfx_idle
            $WeaponSoundLoop.playing = true
    else:
        $WeaponSoundLoop.stream = null
        $WeaponSoundLoop.stop()
    
    reload = reload - delta # NOTE: do not clamp here. clamp at the end
    if inputs.m1 and reload <= 0.0 and desired_weapon == current_weapon: # FIXME: loop...?
        #if is_player:
        #    print("firing!!!")
        time_of_shot = time_alive
        reload += weapon_info.reload_time
         
        # point shot at the point we're looking at
        var aim_transform = get_aim_transform()
            
        if weapon_info.projectile:
            for _i in range(weapon_info.projectile_count):
                var scene = weapon_info.projectile
                if scene is String:
                    scene = load(scene)
                var object : Spatial = scene.instance()
                object.origin_player = self
                object.origin_player_id = player_id
                get_parent().add_child(object)
                object.global_transform = aim_transform
                
                object.add_exception(self)
                object.first_frame(delta)
        
        if weapon_info.hitscan_count > 0:
            for _i in range(weapon_info.hitscan_count):
                var scene = weapon_info.hitscan_scene
                if scene is String:
                    scene = load(scene)
                var object : Spatial = scene.instance()
                if _i != 0:
                    object.first = false
                object.origin_player = self
                object.origin_player_id = player_id
                get_parent().add_child(object)
                var spread_r = sqrt(randf())*weapon_info.hitscan_spread
                var spread_d = randf()*PI*2.0
                var spread_x = sin(spread_d) * spread_r
                var spread_y = cos(spread_d) * spread_r
                #var spread_x = (randf()*2.0-1.0)*weapon_info.hitscan_spread
                #var spread_y = (randf()*2.0-1.0)*weapon_info.hitscan_spread
                
                var spread_xform = Transform.IDENTITY.rotated(Vector3.LEFT, spread_y).rotated(Vector3.UP, spread_x)
                object.spread_xform = spread_xform
                object.global_transform = aim_transform*spread_xform
                
                if _i == 0 and "first" in object:
                    object.first = true
                
                object.set_damage(weapon_info.hitscan_damage)
                object.set_knockback_scale(weapon_info.hitscan_knockback_scale)
                object.set_range(weapon_info.hitscan_range)
                
                var pos = get_muzzle_refpoint()
                if pos:
                    object.set_visual_start_position(pos)
                
                if weapon_info.hitscan_follows_aim:
                    object.set_follow_aim(self)
                
                object.add_exception(self)
                object.first_frame(delta)
        
        if is_perspective:
            if first_shot:
                EmitterFactory.emit(weapon_info.sfx_once).volume_db = -4.5
            EmitterFactory.emit(weapon_info.sfx).volume_db = -4.5
        else:
            if first_shot:
                var fx : AudioStreamPlayer3D = EmitterFactory.emit(weapon_info.sfx_once, self)
                fx.unit_db -= 4.5
                fx.max_db = -4.5
            var fx : AudioStreamPlayer3D = EmitterFactory.emit(weapon_info.sfx, self)
            fx.unit_db -= 4.5
            fx.max_db = -4.5
    
    reload = max(reload, 0.0) # NOTE: correctly clamping at the end

func check_weapon_changed():
    if reload > 0.0:
        return
    if desired_weapon != current_weapon:
        time_of_shot = 0.0
        current_weapon = desired_weapon
        weapon_db = build_weapon_db()
        for child in $CamRelative/WeaponHolder.get_children():
            child.queue_free()
        var weapon_info = weapon_db[current_weapon]
        if weapon_info.model:
            var scene = weapon_info.model
            if scene is String:
                scene = load(weapon_info.model)
            var model = scene.instance()
            $CamRelative/WeaponHolder.add_child(model)
            model.translation = weapon_info.model_offset * 0.5
            model.rotation = Vector3()

var mass = 200.0
func apply_knockback(force, source):
    velocity += force/mass
    # FIXME compare to floor velocity
    # TODO: hitstun
    if velocity.y > 0.0:
        detach_from_floor()
    if source == "rocket":
        detach_from_floor()

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

var ai_angle_inertia : Vector3 = Vector3()
var ai_angle_accel = PI*12.0
var ai_turn_rate_limit = PI*2.0
func ai_apply_turn_logic(delta, target_angle, axis):
    var old_angle = $CameraHolder.rotation[axis]
    var new_angle = angle_move_toward(old_angle, target_angle, ai_turn_rate_limit*delta)
    var target_angle_velocity = -angle_get_delta(new_angle, old_angle)/delta
    
    var to_target = angle_get_delta(old_angle, target_angle)
    var stopping_distance = ai_angle_inertia[axis]*ai_angle_inertia[axis] / (2.0*ai_angle_accel)
    if abs(to_target) < abs(stopping_distance):
        target_angle_velocity = 0.0
    
    ai_angle_inertia[axis] = move_toward(ai_angle_inertia[axis], target_angle_velocity, ai_angle_accel*delta)
    $CameraHolder.rotation[axis] = old_angle + ai_angle_inertia[axis]*delta

var do_no_ai_aim = false
var do_no_ai_move = false
var do_no_ai = false
var do_no_attack = false
var last_used_nav_pos = Vector3()
func do_ai(delta):
    do_no_ai = true
    $CSGBox.visible = false
    if is_player or do_no_ai:
        return
    inputs.clear()
    desired_weapon = "shotgun"
    
    wishdir = Vector3()
    
    var player = null
    for other in get_tree().get_nodes_in_group("Player"):
        if other.is_player:
            player = other
            break
    if !player:
        return
    #$CSGBox.visible = true
    
    if navigable_floor_is_up_to_date:
        $CSGBox.global_translation = navigable_floor
        $Navigation.global_translation = navigable_floor
    
    $Navigation/Agent.set_target_location(player.navigable_floor)
    var next_pos = $Navigation/Agent.get_next_location()
    
    if !$Navigation/Agent.is_target_reachable():
        #if (last_used_nav_pos - navigable_floor).length() > 0.1:
        #    print("resetting", last_used_nav_pos, navigable_floor)
        navigable_floor = last_used_nav_pos
        $CSGBox.global_translation = last_used_nav_pos
        $Navigation.global_translation = last_used_nav_pos
        $Navigation/Agent.set_target_location(player.navigable_floor)
        next_pos = $Navigation/Agent.get_next_location()
    
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
        #$CSGBox.visible = true
        #$CSGBox.global_translation = new_next_pos
    
    var target_diff_for_aiming = target_diff
    # FIXME: calculate in player, using physics traces
    if found_player and player.previous_positions.size() > 2:
        var first = player.previous_positions[0]
        var subdelta = player.total_prev_position_time - first.delta
        var second = player.previous_positions[1]
        var third = player.previous_positions[2]
        var _penult = player.previous_positions[player.previous_positions.size()-2]
        var last = player.previous_positions[player.previous_positions.size()-1]
        
        var first_vel  = (second.pos - first.pos)/second.delta
        var second_vel = (third.pos - second.pos)/third.delta
        var accel = (second_vel - first_vel)/(second.delta + third.delta)*2.0
        var _truaccel = (second.vel - first.vel)/second.delta
        #if Engine.get_frames_drawn()%10 == 0:
        #    print(accel, truaccel, " ", second.vel, " ", (third.pos-second.pos)/second.delta)
        #var current_accel = (last.vel - penult.vel)/last.delta
        #var full_accel = (last.vel - first.vel)/subdelta
        
        var _actual_motion = (last.pos - first.pos)
        #var retro_motion = current_accel * subdelta
        
        # acceleration on the horizontal axis will probably be too large and short-lived to be useful
        var used_accel = accel
        if player.is_on_floor():
            used_accel.x = 0.0
            used_accel.z = 0.0
        
        var predicted_motion = (first_vel + used_accel * 0.5 * subdelta) * subdelta
        
        #if player.is_on_floor():
        #    predicted_motion.y = max(predicted_motion.y, predicted_motion.y*0.5)
        
        target_diff_for_aiming = first.pos + predicted_motion - global_translation
        #$CSGBox.visible = true
        #$CSGBox.global_translation = global_translation + target_diff_for_aiming
    
    # follow player off ledges
    if found_player and ((target_diff.length() < 20.0 and target_diff.y < 1.0) or (target_diff.length() < 50.0 and target_diff.y < -1.0)):
        next_pos = player.global_translation
    
    var diff = next_pos - global_translation
    var horiz_diff = Vector3(target_diff.x, 0, target_diff.z)
    
    #if abs(ai_angle_inertia) > PI and Engine.time_scale > 0.5:
    #    print(ai_angle_inertia)
    var target_yaw = 0.0
    var target_pitch = 0.0
    var want_to_attack = false
    var engagement_range = 8.0
    if horiz_diff.length() > 0.1:
        if target_diff.length() > engagement_range or !found_player:
            if is_on_wall():
                if (velocity * Vector3(1, 0, 1)).normalized().dot(horiz_diff) > 0.5:
                    inputs.jump_pressed = true
                    inputs.jump = true
            
            if !do_no_ai_aim:
                # TODO: look at player while moving if we want to attack. adjust wishdir accordingly
                if found_player and target_diff.length() < engagement_range + 2.0:
                    target_yaw = Vector2().angle_to_point(Vector2(target_diff_for_aiming.z, target_diff_for_aiming.x))
                    ai_apply_turn_logic(delta, target_yaw, 1)
                    
                    target_pitch = acos(clamp(-(target_diff_for_aiming-Vector3(0,0.5,0)).normalized().y, -1, 1))-PI/2.0
                    ai_apply_turn_logic(delta, target_pitch, 0)
                    want_to_attack = true
                else:
                    target_yaw = Vector2().angle_to_point(Vector2(diff.z, diff.x))
                    ai_apply_turn_logic(delta, target_yaw, 1)
                    
                    var diff2 = diff
                    diff2.y = max(abs(diff2.y)-0.5, 0.0) * sign(diff2.y);
                    target_pitch = acos(clamp(min(0, -diff2.normalized().y), -1, 1))-PI/2.0
                    ai_apply_turn_logic(delta, target_pitch, 0)
            
            var angle_diff = target_yaw - $CameraHolder.rotation.y
            while angle_diff < -PI:
                angle_diff += PI*2.0
            while angle_diff > PI:
                angle_diff -= PI*2.0
            angle_diff = rad2deg(angle_diff)
            # TODO support all angles
            if abs(angle_diff) < 22.5 or !is_on_floor():
                wishdir = Vector3.FORWARD
            elif angle_diff > 0.0 and angle_diff < 90.0:
                wishdir = Vector3.FORWARD + Vector3.LEFT
            elif angle_diff < 0.0 and angle_diff > -90.0:
                wishdir = Vector3.FORWARD + Vector3.RIGHT
        else:
            want_to_attack = true
            if !do_no_ai_aim:
                target_yaw = Vector2().angle_to_point(Vector2(target_diff_for_aiming.z, target_diff_for_aiming.x))
                ai_apply_turn_logic(delta, target_yaw, 1)
                target_pitch = acos(clamp(-(target_diff_for_aiming-Vector3(0,0.5,0)).normalized().y, -1, 1))-PI/2.0
                ai_apply_turn_logic(delta, target_pitch, 0)
            
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
            #wishdir = Vector3()
        
        # TODO: make it so keys have to be pressed/depressed for a certain amount of time (0.1s?) before their opposite can be pressed
        wishdir = wishdir.normalized()
        if do_no_ai_move:
            wishdir *= 0.0
    
    if do_no_attack:
        want_to_attack = false
    if want_to_attack:
        var angle = Vector2($CameraHolder.rotation.x, $CameraHolder.rotation.y)
        var target_angle = Vector2(target_pitch, target_yaw)
        # FIXME wrong but whatever
        var limit = deg2rad(5)
        var diff_a = abs(angle_get_delta(angle.x, target_angle.x))
        var diff_b = abs(angle_get_delta(angle.y, target_angle.y))
        if diff_a < limit and diff_b < limit:
            inputs.m1 = true

func do_viewmodel_dynamics(delta):
    $CamRelative/WeaponHolder.transform = Transform.IDENTITY
    
    var weapon_info = weapon_db[current_weapon]
    
    var kickback_amount = clamp(time_of_shot + 0.5 - time_alive, 0.0, 1.0) / 0.5
    if weapon_info:
        kickback_amount *= weapon_info.kickback_scale
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
    
    # prevent viewmodel from sticking into walls
    if is_perspective:
        $CamRelative/WeaponHolder.scale *= 0.5
        $CamRelative/WeaponHolder.translation *= 0.5

var total_prev_position_time = 0.0
# note that delta is the time since the previous entry, not the time to the next entry
var previous_positions = []
func cycle_prev_positions(delta):
    previous_positions.push_back({delta=delta, pos=global_translation, vel=velocity})
    total_prev_position_time = 0.0
    for prev in previous_positions:
        total_prev_position_time += prev.delta
    while total_prev_position_time > 0.20:
        var front = previous_positions[0]
        previous_positions.pop_front()
        total_prev_position_time -= front.delta

func handle_jump(_delta):
    if !is_on_floor() or !want_to_jump:
        return false
    sway_rate_multiplier = 1.0
    
    var effect : Node
    # streamplayer3ds have a one-frame delay on replaying
    if is_perspective:
        effect = $JumpSound0D
    else:
        effect = $JumpSound
    
    if !effect.playing or effect.get_playback_position() > 0.20 or can_doublejump:
        if jump_state_timer > 0 and can_doublejump:
            effect.pitch_scale = 1.15
        else:
            effect.pitch_scale = 1.0
        effect.play()
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
        # FIXME: research objectively correct value for doublejump boost.
        # why? because this seems arbitrary. (comes out suspiciously close to 140%)
        my_jumpstr *= 38.0/27.0
        if jump_state_timer < 0.35:
            jump_state_timer = 0
        else:
            jump_state_timer = jump_state_timer_max
    else:
        jump_state_timer = jump_state_timer_max
    can_doublejump = false
    
    #my_jumpstr *= 2.0
    
    if velocity.y > 0 and velocity.length() < 200:
        velocity.y += my_jumpstr*Vector3.UP.y
    else: 
        velocity.y = max(velocity.y, my_jumpstr*Vector3.UP.y)
    #print(velocity*unit_scale)
    
    #print(my_jumpstr)
    #floor_collision = null
    detach_from_floor()
    last_jump_coordinate = global_transform.origin
    #print(velocity.y)
    return true

func handle_gravity(delta):
    if is_on_floor():
        velocity += delta*Vector3.DOWN*gravity*0.0 # no gravity at all on ground
    elif jump_state_timer > 0:
        velocity += delta*Vector3.DOWN*initial_grav
    else:
        velocity += delta*Vector3.DOWN*gravity
    
func handle_friction(delta):
    if is_on_floor():
        velocity = _friction(velocity, delta)

func handle_accel(delta):
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
    
var floor_velocity = Vector3()

func check_landing(_delta):
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
            if is_perspective:
                EmitterFactory.emit("HybridFoley4").volume_db = -9.0
            else:
                var effect : AudioStreamPlayer3D = EmitterFactory.emit("HybridFoley4", self)
                effect.max_db = -9.0
                effect.unit_db -= 9
            sway_timer = fmod(sway_timer, PI*2.0)
            if sway_timer >= PI*1.0:
                force_sway_to = 0.0
            else:
                force_sway_to = PI
            force_sway_amount = 1.0
            play_animation("land")


# FIXME use the floor_follow_start() etc data instead of this
func check_floor_velocity(delta):
    floor_velocity = Vector3()
    if (moving_platform_mode == 3 and is_on_floor() and delta > 0.0
    and floor_collision and is_instance_valid(floor_collision.collider)
    and prev_floor_collision and is_instance_valid(prev_floor_collision.collider)
    and prev_floor_collision.collider == floor_collision.collider
    and prev_floor_transform
    ):
        var floor_object : Spatial = floor_collision.collider
        if floor_object.has_method("get_real_velocity"):
            floor_velocity = floor_object.get_real_velocity(calculate_foot_position())
        else:
            var foot_location = calculate_foot_position()
            var foreign_foot_location = floor_object.global_transform.affine_inverse().xform(foot_location)
            var old_foot_location = prev_floor_transform.xform(foreign_foot_location)
            floor_velocity = (foot_location - old_foot_location)/delta

func check_moving_platform_rotation():
    if moving_platform_mode > 1:
        if floor_collision and prev_floor_collision and is_instance_valid(floor_collision.collider) and floor_collision.collider == prev_floor_collision.collider:
            var rotation_diff = floor_collision.collider.global_rotation.y - prev_floor_transform.basis.get_euler().y
            add_rotation(rotation_diff)

func pre_move_and_slide_bookkeeping():
    if floor_collision and is_instance_valid(floor_collision.collider):
        prev_floor_transform = floor_collision.collider.global_transform
        prev_floor_collision = floor_collision
    else:
        prev_floor_transform = null
        prev_floor_collision = null
    
    previous_velocity = velocity
    previous_on_floor = floor_collision != null

func update_global_wishdir():
    var forward = Vector3.FORWARD.rotated(Vector3.UP, $CameraHolder.rotation.y)
    var right   = Vector3.RIGHT  .rotated(Vector3.UP, $CameraHolder.rotation.y)
    if is_on_floor():
        forward = vector_reject(forward, floor_collision.normal).normalized()
        right   = vector_reject(right  , floor_collision.normal).normalized()
    
    global_wishdir = wishdir.x*right - wishdir.z*forward

func cycle_debugging_info():
    if global_transform.origin.y > peak:
        peak = global_transform.origin.y
        #print("new peak: %s" % (peak*unit_scale))
        peak_time = simtimer
    if peak_time + 1 < simtimer:
        peak = global_transform.origin.y

var floor_follow_collision = null
var floor_relative_location = Vector3()
var floor_foot_position_memory = Vector3()
func floor_follow_start():
    if floor_collision and is_instance_valid(floor_collision.collider):
        floor_follow_collision = floor_collision
        floor_foot_position_memory = calculate_foot_position()
        floor_relative_location = floor_collision.collider.global_transform.affine_inverse().xform(floor_foot_position_memory)
    else:
        floor_follow_collision = null

func floor_follow_end():
    if floor_collision and is_instance_valid(floor_collision.collider):
        #var old_pos_valid = false
        var old_relative_location = null
        if "previous_global_transform" in floor_collision.collider:
            old_relative_location = floor_collision.collider.previous_global_transform.affine_inverse().xform(floor_foot_position_memory)
        elif floor_follow_collision and floor_collision.collider == floor_follow_collision.collider:
            old_relative_location = floor_relative_location
        if old_relative_location == null:
            return
        var new_relative_location = floor_collision.collider.global_transform.affine_inverse().xform( floor_foot_position_memory)
        var difference = old_relative_location - new_relative_location
        # FIXME: is this right? do we need scale too?
        difference = floor_collision.collider.global_transform.basis.xform(difference)
        if moving_platform_mode != MOVING_PLATFORM_PHYSICAL:
            var _unused = my_move_and_collide(difference)
        # TODO set floor velocity here too

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
var processing_disabled = false
func _process(delta):
    if is_player and Input.is_key_pressed(KEY_0):
        global_translation.y = 4.0
    
    if processing_disabled:
        return
    hit_this_frame = false
    
    moving_platform_mode = MOVING_PLATFORM_FULL_INHERIT
    
    check_first_person_visibility()
    update_inputs()
    do_ai(delta)
    process_inputs()
    
    check_weapon_changed()
    
    # round delta for this frame to per-millisecond granularity
    simtimer += delta
    delta = (floor(simtimer*1000) - floor((simtimer-delta)*1000))/1000
    if delta < 0.001:
        return
    
    time_alive += delta
    anim_lock_time = max(0.0, anim_lock_time - delta)
    jump_state_timer = max(0.0, jump_state_timer - delta)
    
    
    cycle_debugging_info()
    
    var closest_ground = null
    closest_ground = my_move_and_collide(Vector3.DOWN*stair_height, true, true)
    
    check_landing(delta)
    
    check_floor_velocity(delta)
    #if floor_velocity != Vector3():
    #    print(floor_velocity)
    
    var floor_collision_before_jump = floor_collision
    var did_jump = handle_jump(delta)
    
    camera.update_input(delta, inputs)
    
    update_global_wishdir()
    
    var oldvel = velocity
    
    if is_on_floor():
        velocity -= floor_velocity
    
    handle_gravity(delta)
    handle_friction(delta)
    handle_accel(delta)
    
    if is_on_floor():
        velocity += floor_velocity
    
    var newvel = velocity
    velocity = oldvel
    var vel_delta = newvel - oldvel
    
    velocity += vel_delta * Vector3(1, 0, 1)
    vel_delta *= Vector3(0, 1, 0)
    
    velocity += vel_delta/2
    
    do_viewmodel_dynamics(delta)
    
    var reset_stair_height = check_stair_height_override(closest_ground)
    
    check_moving_platform_rotation()
    if moving_platform_mode != 0:
        floor_follow_end()
    if moving_platform_mode != 0:
        floor_follow_start()
    
    pre_move_and_slide_bookkeeping()
    
    var new_velocity = custom_move_and_slide(delta, velocity)
    apply_new_velocity(new_velocity)
    
    check_if_left_floor(floor_collision_before_jump)
    
    stair_height = reset_stair_height
    
    check_stair_smoothing_cooldown(delta)
    check_anim_state(delta, did_jump)
    
    velocity += vel_delta/2
    
    camera.update_smoothing(delta)
    weapon_think(delta)
    Gamemode.force_update_transform(self)
    do_evil_anim_things(delta)
    cycle_prev_positions(delta)
    find_navigable_floor()


func check_stair_height_override(closest_ground):
    var reset_stair_height = stair_height
    do_stairs = is_on_floor() or jump_state_timer > 0.0 or velocity.y <= 0
    if !do_stairs and closest_ground:
        do_stairs = true
        stair_height = abs(closest_ground.remainder.y)
    return reset_stair_height
        
func check_stair_smoothing_cooldown(delta):
    if did_stairs:
        stair_cooldown = camera.correction_window
    
    if !is_on_floor() or stair_cooldown == 0.0:
        reset_stair_camera_offset()
    stair_cooldown = clamp(stair_cooldown-delta, 0.0, 1.0)
    
func apply_new_velocity(new_velocity):
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
    

func check_if_left_floor(floor_collision_before_jump):
    # check for having left the floor (jump or otherwise), do inertia inheritance if necessary
    if !floor_collision and floor_collision_before_jump:
        var floor_boost = Vector3()
        if moving_platform_mode == 2:
            floor_boost = floor_collision_before_jump.collider_velocity
        elif moving_platform_mode == 3:
            floor_boost = vector_project(floor_collision_before_jump.collider_velocity, floor_collision_before_jump.normal)
        if moving_platform_jump_ignore_vertical:
            floor_boost.y = 0.0
        velocity += floor_boost

func check_anim_state(_delta, did_jump):
    var floorspeed = (velocity*Vector3(1, 0, 1)).length()
    if is_on_floor():
        if floorspeed*unit_scale > 280:
            var walkspeed = clamp(floorspeed*unit_scale/320, 0.2, 1.0)
            if anim_walk_backwards:
                walkspeed *= -1.0
            play_animation("run", walkspeed)
        elif floorspeed*unit_scale > 28 or wishdir != Vector3():
            var walkspeed = max(floorspeed*unit_scale/320*1.5, 0.2)
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

var health = 100
var armor  = 100

var armor_ratio = 2.0/3.0

var last_hurtsound = 0.0
var hit_this_frame = false
func take_damage(amount, other_player_id, type, location = null):
    if health <= 0:
        return
    if player_id == other_player_id:
        amount *= 0.5
    amount = ceil(amount)
    
    Gamemode.inform_damage(player_id, other_player_id, amount)
    
    var to_armor = ceil(min(armor, armor_ratio*amount))
    armor -= to_armor
    
    health -= amount - to_armor
    if health <= 0:
        collision_layer = 0
        Gamemode.kill_player(player_id, other_player_id, type)
    
    if location != null and !hit_this_frame:
        if is_perspective and time_alive - last_hurtsound > 0.15:
            last_hurtsound = time_alive
            EmitterFactory.emit("hurtsound").volume_db = -6
    
    hit_this_frame = true

onready var navigable_floor = global_translation
var navigable_floor_is_up_to_date = false
func find_navigable_floor():
    navigable_floor_is_up_to_date = false
    #FIXME don't use xor use and and or with bitwise not (or vice versa)
    collision_mask ^= 2
    var collision = find_real_collision(Vector3.DOWN*64.0)
    if collision and collision_is_floor({normal=collision.normal}):
        navigable_floor = global_translation + collision.travel
        navigable_floor_is_up_to_date = true
    collision_mask ^= 2

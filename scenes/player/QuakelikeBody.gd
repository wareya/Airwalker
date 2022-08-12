extends KinematicBody

class_name QuakelikeBody


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
    pass # Replace with function body.

class CollisionData:
    var collider
    var collider_id
    var collider_rid
    var collider_shape
    var collider_velocity
    var normal
    var position
    var remainder
    var travel
    var query_result

func find_real_collision(motion : Vector3, infinite_inertia : bool = true) -> PhysicsTestMotionResult:
    var max_exclusions = 16
    var exclusions = []
    var result = PhysicsTestMotionResult.new()
    var any = false
    while true:
        any = PhysicsServer.body_test_motion(get_rid(), global_transform, motion, infinite_inertia, result, true, exclusions)
        if any and motion.dot(result.collision_normal) > 0.0:
            if exclusions.size() >= max_exclusions:
                break
            exclusions.push_back(result.collider_rid)
            continue
        break
    if any:
        return result
    else:
        return null

var collision_margin = 0.001
func my_move_and_collide_internal(motion : Vector3, infinite_inertia : bool = true, test_only : bool = false) -> CollisionData:
    var normal_motion = motion.normalized()
    var marginal_motion = normal_motion*collision_margin
    var old_translation = global_translation
    var target_translation = old_translation+motion
    var test_motion = motion + normal_motion*collision_margin
    var result = find_real_collision(test_motion, infinite_inertia)
    
    if result:
        if !test_only:
            # reject along test vector
            global_translation = old_translation + result.motion
            
            if collision_margin > 0.0:
                var result_reject_a = find_real_collision(-marginal_motion, infinite_inertia)
                if result_reject_a:
                    global_translation += result_reject_a.motion
                else:
                    global_translation += -marginal_motion
                
                var normal_rejection = result.collision_normal*collision_margin*2.0
                var result_reject_b = find_real_collision(normal_rejection, infinite_inertia)
                if result_reject_b:
                    global_translation += result_reject_b.motion/2.0
                else:
                    global_translation += normal_rejection/2.0
    else:
        if !test_only:
            global_translation = target_translation
        return null
    return result

func my_move_and_collide(motion : Vector3, infinite_inertia : bool = true, test_only : bool = false) -> CollisionData:
    var old_translation = global_translation
    var target_translation = old_translation+motion
    var result = my_move_and_collide_internal(motion, infinite_inertia, test_only)
    if result:
        var ret = CollisionData.new()
        ret.collider = result.collider
        ret.collider_id = result.collider_id
        ret.collider_rid = result.collider_rid
        ret.collider_shape = result.collider_shape
        if ret.collider.has_method("get_real_velocity"):
            ret.collider_velocity = ret.collider.get_real_velocity(global_translation)
        else:
            ret.collider_velocity = result.collider_velocity
        ret.normal = result.collision_normal
        ret.position = global_translation
        ret.remainder = target_translation - global_translation
        ret.travel = global_translation - old_translation
        ret.query_result = result
        return ret
    else:
        return null

var floor_collision = null
var wall_collision = null

export var stair_height = 18.0/32.0
export var floor_search_distance = 0.05
#export var stair_query_fallback_distance = 0.05
export var stair_query_fallback_distance = 0.06
# allows 45.5ish degrees and shallower (rad2deg(acos(0.7)) is about 45.573 degrees)
export var floor_normal_threshold = 0.7

export var slopes_are_stairs = false
export var use_fallback_stair_logic = true
export var do_stairs = true
export var stick_to_ground = false


var hit_a_wall = false
var hit_a_floor = false
func is_on_wall():
    return hit_a_wall

func is_on_floor():
    return floor_collision != null and collision_is_floor(floor_collision)

func collision_is_floor(collision):
    if !collision:
        return false
    return collision.normal.y > floor_normal_threshold

func collide_into_floor(motion):
    var max_iters = 8
    var collision = null
    for i in range(max_iters):
        collision = my_move_and_collide(motion, false)
        if collision == null:
            break
        else:
            motion -= collision.travel
            if collision_is_floor(collision):
                return [collision, translation, i]
            else:
                motion = vector_reject(motion, collision.normal)
        if motion.length_squared() == 0:
            break
    return null

func collide_into_floor_and_reset(motion):
    var temp_translation = translation
    var stuff = collide_into_floor(motion)
    translation = temp_translation
    return stuff

func map_to_floor(pseudomotion, distance):
    
    floor_collision = null
    var stuff = collide_into_floor_and_reset(Vector3(0, -(distance+floor_search_distance), 0))
    if stuff == null and pseudomotion != null:
        pseudomotion.y = 0
        pseudomotion = pseudomotion.normalized()
        pseudomotion *= stair_query_fallback_distance
        stuff = collide_into_floor_and_reset(Vector3(pseudomotion.x, -(distance+floor_search_distance), pseudomotion.z))
        
    if stuff != null:
        var collision = stuff[0]
        var temp_translation = stuff[1]
        var bounces = stuff[2]
        if collision_is_floor(collision):
            # the y of temp_translation should be negativer than translation
            var actual_distance = translation.y - temp_translation.y
            if bounces == 0:
                if actual_distance > floor_search_distance:
                    translation.y = temp_translation.y + floor_search_distance
            else:
                translation = temp_translation
            floor_collision = collision

# b must be normalized
func vector_project(a, b) -> Vector3:
    var scalar_projection = a.dot(b)
    var vector_projection = b * scalar_projection
    return vector_projection

# b must be normalized
func vector_reject(a, b) -> Vector3:
    var overbounce = 1.0 + 0.001/32.0
    var backoff = a.dot(b)
    if backoff > 0:
        backoff *= overbounce
    else:
        backoff /= overbounce
    return a - (b*backoff)

func move_and_collide_vertically(motion_y):
    return my_move_and_collide(Vector3(0, motion_y, 0), false)

var did_stairs = false

# fallback is for physics engine badness at low delta times like 8ms
func attempt_stair_step(motion, raw_velocity, is_wall, fallback = false):
    if !do_stairs:
        return null
    if motion.x == 0 and motion.z == 0:
        return null
    
    var start_translation = translation
    
    var translation_before_upward = translation
    var upward_contact = move_and_collide_vertically(stair_height)
    var translation_after_upward = translation
    
    var actual_upward_motion = stair_height
    if upward_contact:
        actual_upward_motion = translation_after_upward.y - translation_before_upward.y
    
    var original_motion = motion
    
    motion.y = 0
    if fallback:
        motion = motion.normalized()
        motion *= stair_query_fallback_distance
        #print("========")
        #print(motion)
        #print(actual_upward_motion)
    
    var horizontal_contact = my_move_and_collide(motion, false)
    
    var down_contact = move_and_collide_vertically(-(actual_upward_motion))
    
    var end_translation = translation
    translation = start_translation
    
    var test_offset = 0.05 if upward_contact else 0.0
    
    if collision_is_floor(down_contact):
        if end_translation.y-test_offset > start_translation.y:
            if horizontal_contact:
                return [
                    motion - horizontal_contact.travel,
                    end_translation,
                    raw_velocity,
                    down_contact
                    ]
            else:
                return [Vector3(0, 0, 0), end_translation, raw_velocity, down_contact]
    #else:
    #    print("found collision was not a floor: %s" % down_contact)
    
    if !use_fallback_stair_logic or fallback or !is_wall:
        return null
    elif motion.length_squared() < stair_query_fallback_distance*stair_query_fallback_distance:
        return attempt_stair_step(original_motion, raw_velocity, is_wall, true)

# FIXME: prevent inertia inheritance from other players
func custom_move_and_slide(delta, velocity):
    # before doing anything else: see if we're stick inside the world, and if so, try to get outside of it
    for dir in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
        var dist = 0.001
        var result = find_real_collision(dir*dist, true)
        if result and result.motion.length() > 0.001 and result.motion.dot(dir) < 0.0:
            global_translation += result.motion
            
            var test_velocity = velocity
            var collider_velocity = result.collider_velocity
            if result.collider.has_method("get_real_velocity"):
                collider_velocity = result.collider.get_real_velocity(global_translation)
            test_velocity = vector_reject(test_velocity, result.collision_normal)
            test_velocity += vector_project(collider_velocity, result.collision_normal)
            if vector_project(test_velocity, result.collision_normal).length_squared() > vector_project(velocity, result.collision_normal).length_squared():
                velocity = test_velocity
            
            result = find_real_collision(dir*dist, true)
            if result and result.motion.dot(dir) > 0.0:
                global_translation += result.motion/2.0
            else:
                global_translation += dir*dist/2.0
    
    var raw_velocity = velocity
    var delta_velocity = velocity*delta
    
    var start_velocity = velocity
    #var start_translation = translation
    var started_on_ground = floor_collision != null
    
    var max_iters = 12
    hit_a_floor = false
    hit_a_wall = false
    did_stairs = false
    wall_collision = null
    for _i in range(max_iters):
        var collision = my_move_and_collide(delta_velocity, false)
        if collision == null:
            break
        else:
            delta_velocity -= collision.travel
            #print("testing stairs on bounce " + str(i))
            #print("original vel: " + str(raw_velocity))
            #print("delta vel: " + str(delta_velocity))
            
            #var old_pos = global_transform.origin
            var stair_residual = null
            var is_wall = !collision_is_floor(collision)
            if (slopes_are_stairs or is_wall):
                #print("trying stairs")
                stair_residual = attempt_stair_step(delta_velocity, raw_velocity, is_wall)
            
            if stair_residual:
                did_stairs = true
                #print("stair residual exists")
                delta_velocity = stair_residual[0]
                translation = stair_residual[1]
                raw_velocity = stair_residual[2]
                var down_contact = stair_residual[3]
                
                #print("ypos before stairstep: ", old_pos.y*16.0)
                #print("ypos after stairstep: ", global_transform.origin.y*16.0)
                #print("raw velocity before stairstep: ", raw_velocity*16.0)
                #print("normal: ", down_contact.normal)
                
                ## FIXME: base on time spent in air somehow
                if true:#started_on_ground:
                    delta_velocity = vector_reject(delta_velocity, down_contact.normal)
                    raw_velocity = vector_reject(raw_velocity, down_contact.normal)
                    raw_velocity += vector_project(down_contact.collider_velocity, down_contact.normal)
                #print("raw velocity after stairstep: ", raw_velocity*16.0)
                
                #raw_velocity.y = 0
                continue
            else:
                #print("no stair data, checking slides")
                # don't use collision.remainder here - it already does the vector rejection step if using bullet physics
                if is_wall:
                    #print("it's a wall")
                    hit_a_wall = true
                    wall_collision = collision
                    delta_velocity = vector_reject(delta_velocity, collision.normal)
                    raw_velocity = vector_reject(raw_velocity, collision.normal)
                    raw_velocity += vector_project(collision.collider_velocity, collision.normal)
                else:
                    #print("it's a floor")
                    hit_a_floor = true
                    
                    var delta_v_horizontal = delta_velocity
                    delta_v_horizontal.y = 0
                    
                    delta_velocity = vector_reject(delta_velocity, collision.normal)
                    raw_velocity = vector_reject(raw_velocity, collision.normal)
                    raw_velocity += vector_project(collision.collider_velocity, collision.normal)
                    #print(collision.collider_velocity)
                    #raw_velocity.y = 0
                    
                    # retain horizontal velocity going up slopes
                    if delta_velocity.length_squared() != 0:
                        delta_velocity = delta_velocity.normalized()
                        delta_velocity *= delta_v_horizontal.length()
                    
        if delta_velocity.length_squared() == 0:
            #print("breaking early because remaining travel vector empty")
            break
    
    if !stick_to_ground:
        map_to_floor(null, 0)
    elif started_on_ground:
        map_to_floor(raw_velocity*delta, stair_height)
    elif hit_a_floor or start_velocity.y < 0:
        map_to_floor(null, 0)
    else:
        floor_collision = null
    
    #if floor_collision != null:
    #    raw_velocity.y = 0
    
    return raw_velocity

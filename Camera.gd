extends Camera


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
    
    pass # Replace with function body.

var mouselook_speed = -0.022*3.0
var mouse_motion = Vector2()

onready var holder = get_parent()

func _input(event):
    if event is InputEventMouseButton:
        if event.pressed and event.button_index == 2:
            if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
                Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
                #holder.get_parent().enable_autocam()
            else:
                Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
                #holder.get_parent().disable_autocam()
    elif event is InputEventMouseMotion:
        if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
            mouse_motion += event.relative
    if event is InputEventMouseMotion:
        #print(HUD.get_viewport().get_visible_rect())
        #print(event.relative)
        pass

var rotate_speed = 360
# Called every frame. 'delta' is the elapsed time since the previous frame.
var prev_prev_global_position = null
var prev_global_position = null
var prev_ydelta = null

func reset_stair_offset():
    var parent_position = get_parent().global_transform.origin
    prev_prev_global_position = prev_global_position
    prev_global_position = parent_position

var correction_speed = 5
var correction_window = 0.05

func _process(delta):
    var correction_range_clamp = 8.0/32.0
    correction_range_clamp = 16.0/32.0
    correction_window = 0.05
    
    var parent_position = get_parent().global_transform.origin
    
    if delta > 0.0:
        if prev_global_position:
            var ydelta = (parent_position.y - prev_global_position.y)/delta
            if abs(ydelta) > 0:
                #print("bouncing")
                global_transform.origin.y -= ydelta*delta
                correction_speed = abs(global_transform.origin.y - parent_position.y)
                correction_speed /= correction_window # 100ms
        prev_prev_global_position = prev_global_position
        prev_global_position = parent_position
    
    var correction_delta = correction_speed*delta
    if abs(parent_position.y - global_transform.origin.y) <= correction_delta:
        global_transform.origin.y = parent_position.y
    else:
        global_transform.origin.y += correction_delta * sign(parent_position.y - global_transform.origin.y)
    if abs(parent_position.y - global_transform.origin.y) > correction_range_clamp:
        global_transform.origin.y = parent_position.y - sign(parent_position.y - global_transform.origin.y)*correction_range_clamp
    
    global_transform.origin.x = parent_position.x
    global_transform.origin.z = parent_position.z
    
    var y = holder.rotation_degrees.y
    var x = holder.rotation_degrees.x
    #y += Input.get_action_strength("camera_right")*rotate_speed*delta
    #y -= Input.get_action_strength("camera_left")*rotate_speed*delta
    #x += Input.get_action_strength("camera_up")*rotate_speed*delta
    #x -= Input.get_action_strength("camera_down")*rotate_speed*delta
    x += mouse_motion.y*mouselook_speed
    y += mouse_motion.x*mouselook_speed
    mouse_motion = Vector2()
    x = clamp(x, -90, 90)
    #x = clamp(x, -88, 88)
    holder.rotation_degrees.y = y
    holder.rotation_degrees.x = x
    #if Input.get_action_strength("camera_right") == 0 and Input.get_action_strength("camera_left") == 0:
    #    if $LeftPush.get_overlapping_bodies().size() > 0:
    #        holder.rotate_y(-deg2rad(rotate_speed)*delta*0.1)
    #    if $RightPush.get_overlapping_bodies().size() > 0:
    #        holder.rotate_y( deg2rad(rotate_speed)*delta*0.1)
    #print("----")
    #print(holder.rotation_degrees.z)
    #print(holder.rotation_degrees.y)
    #print(holder.rotation_degrees.x)
    #if holder.rotation_degrees.x > 20:
    #    holder.rotation_degrees.x = 20
    #if holder.rotation_degrees.x < -80:
    #    holder.rotation_degrees.x = -80
    #var distance = holder.rotation_degrees.x+80.0
    #distance /= 100.0
    #transform.origin.z = lerp(1.0, 5.0, 1.0-distance)
    #look_at(holder.global_transform.origin, Vector3.UP)
    pass

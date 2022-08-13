extends Camera

var mouselook_speed = -0.022*2.75
var mouse_motion = Vector2()

onready var holder = get_parent()

var input_enabled = false

func _input(event):
    if !input_enabled:
        return
    if event is InputEventMouseMotion:
        var ratio : Vector2
        # FIXME: in godot 3.5 (and older, and probably newer), mouse relatie motion is tied to window size
        # ...in 2d scaling mode only
        if ProjectSettings.get_setting("display/window/stretch/mode") == "2d":
            ratio = get_viewport().size / get_viewport().get_visible_rect().size
        else:
            ratio = Vector2.ONE
        if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
            mouse_motion += event.relative*ratio
    if event is InputEventMouseMotion:
        #print(HUD.get_viewport().get_visible_rect())
        #print(event.relative)
        pass

var rotate_speed = 360
var prev_global_position = null
var prev_ydelta = null

func reset_stair_offset():
    var basic_position = get_parent().global_translation
    prev_global_position = basic_position

var correction_speed = 5
var correction_window = 0.05
var smoothing_amount = 0.0

func update_input(_delta):
    correction_window = 0.05
    
    var y = holder.rotation_degrees.y
    var x = holder.rotation_degrees.x
    
    x += mouse_motion.y*mouselook_speed
    y += mouse_motion.x*mouselook_speed
    mouse_motion = Vector2()
    x = clamp(x, -90, 90)
    
    holder.rotation_degrees.y = y
    holder.rotation_degrees.x = x

func update_smoothing(delta):
    var correction_range_clamp = 16.0/32.0
    
    var basic_position = holder.global_translation
    if delta > 0.0 and prev_global_position:
        var ydelta = (basic_position.y - prev_global_position.y)
        if abs(ydelta) > 0.01:
            #print("bouncing")
            #print(ydelta)
            smoothing_amount -= ydelta
            correction_speed = abs(ydelta)/correction_window
    prev_global_position = basic_position
    
    smoothing_amount = move_toward(smoothing_amount, 0.0, correction_speed*delta)
    smoothing_amount = clamp(smoothing_amount, -correction_range_clamp, correction_range_clamp)
    
    translation = holder.get_node("CamBasePos").translation
    global_translation.y += smoothing_amount
    
    holder.get_parent().update_from_camera_smoothing()
    force_update_transform()
    
    

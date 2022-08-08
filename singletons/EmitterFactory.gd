extends Node

var sounds = ResourcePreloader.new()
func _ready():
    print("loading")
    var dir = Directory.new()
    dir.change_dir("res://sfx/")
    dir.list_dir_begin(true)
    var file_name = dir.get_next()
    while file_name != "":
        if !dir.current_is_dir() and file_name.ends_with(".wav"):
            sounds.add_resource(file_name.replace(".wav", ""), load(dir.get_current_dir() + "/" + file_name))
        file_name = dir.get_next()


#var loud_mode = false

class Emitter3D extends AudioStreamPlayer3D:
    var ready = false
    var frame_counter = 0

    func _process(_delta):
        if ready and !playing:
            frame_counter += 1
        if frame_counter > 2:
            queue_free()

    func emit(parent : Node, sound, arg_position, channel):
        parent.add_child(self)
        transform.origin = arg_position
        var abs_position = global_transform.origin
        parent.remove_child(self)
        parent.get_tree().get_root().add_child(self)
        global_transform.origin = abs_position
        
        stream = sound
        bus = channel
        
        attenuation_model = ATTENUATION_INVERSE_SQUARE_DISTANCE
        unit_db = 55
        unit_size = 0.5
        ## note: unit size is meaningless for ATTENUATION_INVERSE_SQUARE_DISTANCE
        ## doubling unit size is the same as changing unit_db by approx. 6db (or was it -6db? either way)
        
        #attenuation_model = ATTENUATION_INVERSE_DISTANCE
        #unit_db = 20
        #unit_size = 4
        
        
        max_db = 6
        
        attenuation_filter_cutoff_hz = 22000.0
        attenuation_filter_db = -0.001
        
        play()
        ready = true
        return self


class Emitter extends AudioStreamPlayer:
    var ready = false
    var frame_counter = 0

    func _process(_delta):
        if ready and !playing:
            frame_counter += 1
        if frame_counter > 2:
            queue_free()

    func emit(parent : Node, sound, channel):
        parent.add_child(self)
        
        stream = sound
        bus = channel
        
        volume_db = -3
        play()
        ready = true
        return self

func emit(sound, parent = null, arg_position = Vector3(), channel = "SFX"):
    var stream = null
    if sound is String and sounds.has_resource(sound):
        stream = sounds.get_resource (sound)
    elif sound is AudioStream:
        stream = sound
    if parent:
        return Emitter3D.new().emit(parent, stream, arg_position, channel)
    else:
        return Emitter.new().emit(self, stream, channel)

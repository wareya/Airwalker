extends Node

var sounds = {
    "HybridFoley2" : preload("res://sfx/HybridFoley2.wav"),
    "HybridFoley3" : preload("res://sfx/HybridFoley3.wav"),
    "HybridFoley4" : preload("res://sfx/HybridFoley4.wav"),
    "HybridFoley" : preload("res://sfx/HybridFoley.wav"),
    "rocketexplosion2" : preload("res://sfx/rocketexplosion2.wav"),
    "rocketexplosion" : preload("res://sfx/rocketexplosion.wav"),
    "rocketloop" : preload("res://sfx/rocketloop.wav"),
    "rocketshot" : preload("res://sfx/rocketshot.wav"),
    "shotgunshot" : preload("res://sfx/ShotgunShot.wav"),
    "machinegunshot" : preload("res://sfx/MachinegunShot.wav"),
    "railgunshot" : preload("res://sfx/RailgunShot2.wav"),
    "teleporter fx" : preload("res://sfx/teleporter fx.wav"),
    "TubeSound3" : preload("res://sfx/TubeSound3.wav"),
    "GibFrag" : preload("res://sfx/cc0/impactsplat01.wav"),
    "GibBounce1" : preload("res://sfx/cc0/random2.wav"),
    "GibBounce2" : preload("res://sfx/cc0/random3.wav"),
    "lightningidle" : preload("res://sfx/LightningIdle.wav"),
    "lightningbuzz" : preload("res://sfx/LightningBuzz.wav"),
    "thunderclap" : preload("res://sfx/ThunderClap.wav"),
    
    "hita" : preload("res://sfx/HitA.wav"),
    "hitb" : preload("res://sfx/HitB.wav"),
}

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
    if sound is String and sound in sounds:
        stream = sounds[sound]
    elif sound is AudioStream:
        stream = sound
    if parent or arg_position != Vector3():
        if !parent:
            parent = get_tree().current_scene
        return Emitter3D.new().emit(parent, stream, arg_position, channel)
    else:
        return Emitter.new().emit(self, stream, channel)

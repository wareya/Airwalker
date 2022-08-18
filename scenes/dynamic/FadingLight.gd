extends Light

var fading = false
func _process(delta):
    if fading:
        light_energy = move_toward(light_energy, 0.0, delta*16.0)
    if light_energy <= 0.0:
        queue_free()

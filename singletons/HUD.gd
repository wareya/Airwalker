extends CanvasLayer

func _ready():
    pass

func _input(event):
    if event is InputEventMouseButton:
        if event.pressed and event.button_index == 2:
            if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
                Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
            else:
                Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(_delta):
    $Crosshair.visible = false
    $ArrowUp.visible = false
    $ArrowLeft.visible = false
    $ArrowDown.visible = false
    $ArrowRight.visible = false
    $ArrowJump.visible = false
    $HealthLabel.visible = false
    $ArmorLabel.visible = false

func update(player):
    $Peak.text = "%s\n%s\n%s\n%s\n%s\n%s\n%s" % \
        [(player.peak*player.unit_scale),
        (player.velocity * Vector3(1,0,1)).length()*player.unit_scale,
        player.velocity.length()*player.unit_scale,
        player.is_on_floor(),
        player.global_translation*player.unit_scale,
        player.velocity.y*player.unit_scale,
        Engine.get_frames_per_second()]
    
    $Crosshair.visible = true
    
    $ArrowUp.visible = player.wishdir.z < 0
    $ArrowDown.visible = player.wishdir.z > 0
    $ArrowLeft.visible = player.wishdir.x < 0
    $ArrowRight.visible = player.wishdir.x > 0
    $ArrowJump.visible = player.inputs.jump
    if player.can_doublejump and player.jump_state_timer > 0:
        $ArrowJump.modulate = Color.turquoise
    else:
        $ArrowJump.modulate = Color.white
    if !player.want_to_jump and !player.pogostick_jumping:
        $ArrowJump.modulate.a = 0.5
    else:
        $ArrowJump.modulate.a = 1.0
    
    $HealthLabel.visible = true
    $HealthLabel.text = str(player.health)
    
    $ArmorLabel.visible = true
    $ArmorLabel.text = str(player.armor)

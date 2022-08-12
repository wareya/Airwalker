extends CanvasLayer

func _ready():
    yield(get_tree(), "idle_frame")
    do_spawn()

var player_kills = 0
var enemy_kills  = 0

func array_pick_random(array : Array, destructive = false):
    if array.size() == 0:
        return null
    var i = randi() % array.size()
    var ele = array[i]
    if destructive:
        array.pop_at(i)
    return ele

var players = {
    0 : {name="Player", score=0, entity=null, is_player=true , is_bot=false, respawn_time=0.0},
    1 : {name="Bot"   , score=0, entity=null, is_player=false, is_bot=true , respawn_time=0.0},
}

func find_world():
    var _world = get_tree().get_nodes_in_group("NavWorld")
    if _world.size() > 0:
        _world = _world[0]
    else:
        _world = get_tree().current_scene
    return _world

onready var world = find_world()

func kill_player(which : int, killed_by : int, type : String):
    var player = players[which]
    var other  = players[killed_by]
    if !player or !player.entity or !is_instance_valid(player.entity):
        return
    
    if other and player != other:
        other.score += 1
    elif other:
        other.score -= 1
    
    var camera_xform = player.entity.get_camera_transform()
    
    if player.is_player:
        var death_cam = preload("res://scenes/player/DeathCamera.tscn").instance()
        var camera : Camera = player.entity.remove_camera()
        camera.set_script(null)
        death_cam.add_child(camera)
        world.add_child(death_cam)
        death_cam.global_transform = camera_xform
    
    var location = player.entity.global_translation
    var velocity = player.entity.velocity
    
    if player.entity and is_instance_valid(player.entity):
        player.entity.queue_free()
    
    player.respawn_time = 5.0
    if type == "rocket":
        randomize()
        for _i in range(16):
            var gibs : Spatial = load("res://scenes/dynamic/Giblet.tscn").instance()
            world.add_child(gibs)
            var offset = Vector3(randf()*2.0-1.0, randf()*2.0-1.0, randf()*2.0-1.0).normalized()
            gibs.scale *= randf()/2.0 + 0.5
            gibs.global_translation = location
            gibs.linear_velocity = velocity*0.5 + offset*8.0
            gibs.angular_velocity = Vector3(randf()*2.0-1.0, randf()*2.0-1.0, randf()*2.0-1.0)*0.25
        var fx : AudioStreamPlayer3D = EmitterFactory.emit("GibFrag", null, location)
        fx.unit_db -= 12
        fx.max_db = 0

var char_scene = preload("res://scenes/player/MyChar.tscn")
func spawn_player_at(which : int, spawner : Spatial):
    var player = players[which]
    
    var found_player = null
    for character in get_tree().get_nodes_in_group("Player"):
        if character.player_id == which:
            found_player = character
            break
    
    var mychar
    if !found_player:
        mychar = char_scene.instance()
        mychar.player_id = which
        world.add_child(mychar)
    else:
        mychar = found_player
    
    player.entity = mychar
    
    if spawner:
        mychar.set_rotation(spawner.rotation.y)
        mychar.global_translation = spawner.global_translation + Vector3(0, 0.5, 0)
    
    mychar.map_to_floor(null, 1.0)
    if player.is_player:
        mychar.is_player = true
        mychar.force_take_camera()
    
    yield(get_tree(), "idle_frame")
    var fx : AudioStreamPlayer3D = EmitterFactory.emit("teleporter fx", mychar)
    fx.unit_db -= 6
    fx.max_db = -6


func do_spawn():
    randomize()
    var mut_spawners = get_tree().get_nodes_in_group("Spawner")
    for i in players:
        var spawner = array_pick_random(mut_spawners, true)
        if !spawner:
            spawner = array_pick_random(spawners)
        spawn_player_at(i, spawner)

func playerside_processing():
    var text = ""
    for i in players:
        var player = players[i]
        text += "%s: %s\n" % [player.name, player.score]
    $Label.text = text
    
    $Label2.visible = false
    for i in players:
        var player = players[i]
        if player.is_player:
            if is_instance_valid(player.entity):
                HUD.update(player.entity)
            if player.respawn_time <= 0.0:
                for cam in get_tree().get_nodes_in_group("DeathCam"):
                    cam.queue_free()
            else:
                $Label2.visible = true
                $Label2.text = "Respawning in %s..." % [ceil(player.respawn_time)]

onready var spawners = get_tree().get_nodes_in_group("Spawner")
func _process(delta : float):
    for i in players:
        var player = players[i]
        if player.respawn_time > 0.0:
            player.respawn_time -= delta
            if player.respawn_time <= 0.0:
                var spawner = array_pick_random(spawners)
                spawn_player_at(i, spawner)
    
    playerside_processing()
    

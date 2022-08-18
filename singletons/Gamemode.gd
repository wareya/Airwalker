extends CanvasLayer

func serialize(update_type : int):
    if update_type == Networker.UPDATE_STATE:
        return [players]

remote func deserialize(update_type : int, data):
    if get_tree().get_rpc_sender_id() > 1:
        return
    
    var old_players = players
    if update_type == Networker.UPDATE_STATE:
        players = data[0]
    for i in players:
        if i in old_players and players[i].player_id == old_players[i].player_id:
            players[i].entity = old_players[i].entity
        if players[i].client_id == get_tree().network_peer.get_unique_id():
            players[i].is_player = true
        else:
            players[i].is_player = false

var players = {
    0 : {name="Player", score=0, entity=null, is_player=true , is_bot=false, respawn_time=0.0, player_id=0, client_id=1},
    1 : {name="Bot"   , score=0, entity=null, is_player=false, is_bot=true , respawn_time=0.0, player_id=0, client_id=1},
}

var next_player_id = 0
remote func add_player(client_id : int, bot : bool):
    if get_tree().get_rpc_sender_id() > 1:
        return
    
    next_player_id += 1
    
    var player = {name="Player", score=0, entity=null, is_player=false, is_bot=bot, respawn_time=0.1, player_id=next_player_id, client_id=client_id}
    print("building a player...")
    print(get_tree().network_peer.get_unique_id())
    print(client_id)
    
    if !bot and get_tree().network_peer.get_unique_id() == client_id:
        player.is_local_player = true
    
    players[next_player_id] = player
    return player

remote func remove_player(client_id : int):
    if get_tree().get_rpc_sender_id() > 1:
        return
    
    for id in players:
        if players[id].client_id == client_id:
            for character in get_tree().get_nodes_in_group("Player"):
                if character.player_id == id:
                    character.despawn()
            players.erase(id)

var dummy_space = PhysicsServer.space_create()
func force_update_transform(object : CollisionObject):
    object.force_update_transform()
    # GODOT BUG: force_update_transform doesn't actually work properly (3.5)
    # (it doesn't update the broadphase)
    # (doesn't seem to work at all with godot physics)
    # however, removing the object from the physics space and then re-adding it DOES work
    # (it updates the broadphase)
    # (also doesn't work at all with godot physics)
    if object is Area:
        PhysicsServer.area_set_space(object.get_rid(), dummy_space)
        PhysicsServer.area_set_space(object.get_rid(), object.get_world().space)
    else:
        PhysicsServer.body_set_space(object.get_rid(), dummy_space)
        PhysicsServer.body_set_space(object.get_rid(), object.get_world().space)

var ___forced_preload = []
func _ready():
    for f in [
        "res://art/texture/blockmesh texture black.png",
        "res://art/texture/blockmesh texture blue.png",
        "res://art/texture/blockmesh texture darkgray.png",
        "res://art/texture/blockmesh texture green.png",
        "res://art/texture/blockmesh texture lightgray.png",
        "res://art/texture/blockmesh texture lightgreen.png",
        "res://art/texture/blockmesh texture orange.png",
        "res://art/texture/blockmesh texture purple.png",
        "res://art/texture/blockmesh texture red.png",
        "res://art/texture/blockmesh texture white.png",
        "res://art/texture/blockmesh texture yellow.png",
        "res://art/texture/blockmesh texture.png"
        ]:
        ___forced_preload.push_back(load(f))

func array_random_index(array : Array):
    if array.size() == 0:
        return -1
    return randi() % array.size()

func array_pick_random(array : Array, destructive = false):
    if array.size() == 0:
        return null
    var i = array_random_index(array)
    var ele = array[i]
    if destructive:
        array.pop_at(i)
    return ele

func find_world():
    var _world = get_tree().get_nodes_in_group("NavWorld")
    if _world.size() > 0:
        _world = _world[0]
    else:
        _world = get_tree().current_scene
    return _world

onready var world = find_world()
var player_damage_dealt_this_frame = 0.0

func inform_damage(_target : int, _attacker : int, damage : float):
    var target   = players[_target]
    var attacker = players[_attacker]
    if !target or !target.entity or !attacker:
        return
    
    if !target.is_player and attacker.is_player:
        player_damage_dealt_this_frame += damage

remote func kill_player(which : int, killed_by : int, _type : String):
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
        player.entity.processing_disabled = true
    
    player.respawn_time = 5.0
    # FIXME: implement other death types
    #if type == "rocket":
    if true:
        randomize()
        for _i in range(16):
            var gib : Spatial = load("res://scenes/dynamic/Giblet.tscn").instance()
            world.add_child(gib)
            var offset = Vector3(randf()*2.0-1.0, randf()*2.0-1.0, randf()*2.0-1.0).normalized()
            gib.scale *= randf()/2.0 + 0.5
            gib.global_translation = location
            gib.linear_velocity = velocity*(randf()/2.0+0.5) + offset*8.0
            gib.angular_velocity = Vector3(randf()*2.0-1.0, randf()*2.0-1.0, randf()*2.0-1.0)*0.25
        var fx : AudioStreamPlayer3D = EmitterFactory.emit("GibFrag", null, location)
        fx.unit_db -= 12
        fx.max_db = 0

var char_scene = preload("res://scenes/player/MyChar.tscn")
remote func spawn_player_at(which : int, where : int, network_id : int = -1):
    if get_tree().get_rpc_sender_id() > 1:
        return
    print("spawning player...")
    if which < 0:
        print("no spawner")
        return
    var spawner = spawners[where]
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
        mychar.is_local_player = true
        mychar.force_take_camera()
    if player.is_bot:
        mychar.is_bot = true
    
    network_id = Networker.net_id_setup(mychar, network_id)
    if Networker.is_server and get_tree().get_rpc_sender_id() == 0:
        rpc("spawn_player_at", which, where, network_id)

func pick_spawner():
    return array_random_index(spawners)

func spawn_player(i):
    spawn_player_at(i, array_random_index(spawners))

func respawn_all():
    randomize()
    var mut_spawners = range(spawners.size())
    for i in players:
        var spawner = array_pick_random(mut_spawners, true)
        if !spawner:
            spawner = array_random_index(spawners)
        spawn_player_at(i, spawner)

var watch_ai = false

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
    
    if player_damage_dealt_this_frame > 0.0:
        var dmg_min = 20
        var dmg_max = 80
        var pitch_min = 1.6
        var pitch_max = 0.68
        var vol_min = -6
        var vol_max = -3
        
        var amount = clamp(inverse_lerp(dmg_min, dmg_max, player_damage_dealt_this_frame), 0.0, 1.0)
        
        var fx : AudioStreamPlayer = EmitterFactory.emit("horn")
        fx.pitch_scale = lerp(pitch_min, pitch_max, amount)
        fx.volume_db += lerp(vol_min, vol_max, amount)
        
        player_damage_dealt_this_frame = 0.0

onready var spawners = get_tree().get_nodes_in_group("Spawner")
func _process(delta : float):
    if Networker.is_server:
        for i in players:
            var player = players[i]
            if player.respawn_time > 0.0:
                player.respawn_time -= delta
                if player.respawn_time <= 0.0:
                    var spawner = array_random_index(spawners)
                    spawn_player_at(i, spawner)
    
    playerside_processing()
    
    # FIXME move to hud
    if Input.is_action_just_pressed("ui_page_up"):
        Gamemode.watch_ai = !Gamemode.watch_ai
        pass
    

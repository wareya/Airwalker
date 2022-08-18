extends Node

func _ready():
    # warning-ignore:return_value_discarded
    get_tree().connect("network_peer_connected", self, "peer_connected")
    # warning-ignore:return_value_discarded
    get_tree().connect("network_peer_disconnected", self, "peer_disconnected")
    # warning-ignore:return_value_discarded
    get_tree().connect("connected_to_server", self, "connected")
    # warning-ignore:return_value_discarded
    get_tree().connect("connection_failed", self, "connect_failed")
    # warning-ignore:return_value_discarded
    get_tree().connect("server_disconnected", self, "disconnected")

var peers = {}

func peer_connected(id : int):
    if !is_server:
        return
    print("got a connection...? ", id)
    peers[id] = null
    var player = Gamemode.add_player(id, false)
    Gamemode.rpc("add_player", id, false)
    Gamemode.rpc_id(id, "deserialize", Networker.UPDATE_STATE, Gamemode.serialize(Networker.UPDATE_STATE))

func peer_disconnected(id : int):
    if !is_server:
        return
    print(id, " disconnected")
    Gamemode.remove_player(id)
    Gamemode.rpc("remove_player", id)
    peers.erase(id)

func connected():
    print("connected to server")
    pass
func connect_failed():
    print("failed to connect to server")
    pass
func disconnected():
    for id in networked_objects:
        if is_instance_valid(networked_objects[id]):
            print("freeing object...")
            networked_objects[id].queue_free()
    print("disconnected from server")
    pass

var is_server = false
var is_client = false

func set_up_server(port : int = 8193):
    is_server = true
    is_client = false
    if get_tree().network_peer:
        get_tree().network_peer.close_connection()
    
    var peer = NetworkedMultiplayerENet.new()
    peer.create_server(port, 64)
    get_tree().network_peer = peer

func connect_as_client(address : String, port : int = 8193):
    is_server = false
    is_client = true
    if get_tree().network_peer:
        get_tree().network_peer.close_connection()
    
    var peer = NetworkedMultiplayerENet.new()
    peer.create_client(address, port)
    #if peer.
    peer.set_target_peer(NetworkedMultiplayerENet.TARGET_PEER_SERVER)
    get_tree().network_peer = peer

func force_disconnect():
    rpc("disconnect_me")

# network id for networked nodes with serialize/deserialize functions
var node_network_id = 100

enum {
    UPDATE_CLIENT_INPUTS,
    UPDATE_INPUTS,
    UPDATE_STATE,
    UPDATE_EVENT,
    UPDATE_INITIAL,
}

func _process(_delta):
    if is_server:
        var messages = {}
        for _node in get_tree().get_nodes_in_group("Networked"):
            var node : Node = _node
            if node.network_id < 0:
                node.network_id = node_network_id
                node_network_id += 1
            
            var data = node.serialize(UPDATE_STATE)
            messages[node.network_id] = data
        
        rpc("update_state", messages)
        
        Gamemode.rpc("deserialize", Networker.UPDATE_STATE, Gamemode.serialize(Networker.UPDATE_STATE))
    
    if is_client:
        for character in get_tree().get_nodes_in_group("Player"):
            if character.is_local_player:
                character.update_inputs_intent()
                rpc("input_update", character.serialize_inputs())
                break
    pass

# functions that run on the server
remote func disconnect_me():
    var who = get_tree().get_rpc_sender_id()
    print("disconnecting ", who)
    get_tree().network_peer.disconnect_peer(who)

remote func input_update(new_inputs):
    var who = get_tree().get_rpc_sender_id()
    for id in Gamemode.players:
        var player = Gamemode.players[id]
        if player.client_id == who:
            player.entity.deserialize_inputs(new_inputs)
            break

# functions that run on the client
remote func update_state(update_data):
    if get_tree().get_rpc_sender_id() > 1:
        return
    
    for id in update_data:
        #print("deserializing ", id)
        var info = update_data[id]
        if id in networked_objects:
            networked_objects[id].deserialize(UPDATE_STATE, info)
        else:
            #print("doesn't exist")
            pass
    pass

var networked_objects = {}
func net_id_setup(node : Node, force_id : int = -1):
    if !node.is_in_group("Networked"):
        return -1
    else:
        if force_id >= 0:
            node.network_id = force_id
        else:
            node.network_id = node_network_id
            node_network_id += 1
        networked_objects[node.network_id] = node
        return node.network_id

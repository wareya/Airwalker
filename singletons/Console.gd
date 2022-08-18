extends LineEdit

func _ready():
    # warning-ignore:return_value_discarded
    connect("text_entered", self, "command")

var command_cursor = 0
var command_history = []

var oldpos = 0
func _input(_event : InputEvent):
    var start_oldpos = oldpos
    if _event is InputEventKey:
        var event : InputEventKey = _event
        if event.pressed:
            var do_history = false
            if event.scancode == KEY_UP and command_history.size() > 0:
                command_cursor = clamp(command_cursor+1, 0, command_history.size())
                do_history = true
            if event.scancode == KEY_DOWN and command_history.size() > 0:
                command_cursor = clamp(command_cursor-1, 0, command_history.size())
                do_history = true
            if do_history:
                var which = command_history.size()-command_cursor
                if which < command_history.size():
                    text = command_history[which]
                else:
                    text = ""
                yield(get_tree(), "idle_frame")
                caret_position = start_oldpos
        

func _process(_delta):
    if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        release_focus()
    oldpos = caret_position

func command(new_text : String):
    var stuff = new_text.split(" ", false, 1)
    while stuff.size() < 2:
        stuff.push_back("")
    #print(stuff)
    var cmd : String = stuff[0]
    var arg : String = stuff[1]
    if cmd == "connect":
        Networker.disconnected()
        var parts = arg.rsplit(":")
        var ip : String = parts[0]
        if parts.size() == 2:
            var port : String = parts[1]
            if port.is_valid_integer():
                Networker.connect_as_client(ip, port.to_int())
            else:
                Networker.connect_as_client(ip)
        else:
            Networker.connect_as_client(ip)
    if cmd == "host":
        if arg.is_valid_integer():
            Networker.set_up_server(arg.to_int())
        else:
            Networker.set_up_server()
    if cmd == "disconnect":
        Networker.force_disconnect()
    command_history.push_back(text)
    text = ""
    command_cursor = 0
    

class_name Game
extends Node

@onready var lobby_view: LobbyView = $LobbyView
@onready var room_view: RoomView = $RoomView
@onready var battle_view: BattleView = $BattleView

const URL := "ws://localhost:%d" % Server.PORT

var peer_id: int

func _ready() -> void:
	_create_peer()
	lobby_view.create_room_button.pressed.connect(create_room)
	room_view.leave_button.pressed.connect(leave_room)
	lobby_view.room_chosen.connect(enter_room)
	room_view.monster_mode_check.toggled.connect(set_monster_mode)
	room_view.start_button.pressed.connect(start_battle)
	room_view.local_multi_check.toggled.connect(set_local_multi)
	battle_view.move_requested.connect(move)
	battle_view.water_balloon_requested.connect(place_water_balloon)
	multiplayer.connected_to_server.connect(on_connected_to_server)

func _create_peer() -> void:
	var peer := WebSocketMultiplayerPeer.new()
	var error := peer.create_client(URL)
	if error != OK:
		push_error("%d failed to create client: %s" % [URL, error_string(error)])
		return
	multiplayer.multiplayer_peer = peer

func on_connected_to_server() -> void:
	peer_id = multiplayer.get_unique_id()

@rpc("any_peer", "call_remote", "reliable")
func request_create_room() -> void:
	pass

@rpc("any_peer", "call_remote", "reliable")
func request_enter_room(_room_id: String) -> void:
	pass

@rpc("any_peer", "call_remote", "reliable")
func request_leave_room() -> void:
	pass

@rpc("any_peer", "call_remote", "reliable")
func request_start_battle() -> void:
	pass

@rpc("any_peer", "call_remote", "reliable")
func request_set_local_multi(_enabled: bool) -> void:
	pass

@rpc("any_peer", "call_remote", "reliable")
func request_set_monster_mode(_enabled: bool) -> void:
	pass

@rpc("any_peer", "call_remote", "reliable")
func request_move(_number: int, _direction: Vector2i) -> void:
	pass

@rpc("any_peer", "call_remote", "reliable")
func request_place_water_balloon(_number: int) -> void:
	pass

@rpc("authority", "call_remote", "reliable")
func screen_changed(snapshot: Dictionary) -> void:
	match snapshot["screen"]:
		Screen.LOBBY:
			lobby_view.visible = true
			room_view.visible = false
			battle_view.visible = false
			lobby_view.render(snapshot["lobby"])
		Screen.ROOM:
			lobby_view.visible = false
			room_view.visible = true
			battle_view.visible = false
			room_view.render(snapshot["room"])
		Screen.BATTLE:
			lobby_view.visible = false
			room_view.visible = false
			battle_view.visible = true
			battle_view.render(snapshot["battle"], peer_id)

func move(number: int, direction: Vector2i) -> void:
	request_move.rpc_id(1, number, direction)

func place_water_balloon(number: int) -> void:
	request_place_water_balloon.rpc_id(1, number)

func create_room() -> void:
	request_create_room.rpc_id(1)

func enter_room(room_id: String) -> void:
	request_enter_room.rpc_id(1, room_id)

func leave_room() -> void:
	request_leave_room.rpc_id(1)

func start_battle() -> void:
	request_start_battle.rpc_id(1)

func set_local_multi(enabled: bool) -> void:
	request_set_local_multi.rpc_id(1, enabled)

func set_monster_mode(enabled: bool) -> void:
	request_set_monster_mode.rpc_id(1, enabled)

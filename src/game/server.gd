class_name Server
extends Node

const PORT := 8080

var lobby := Lobby.new()

func _ready() -> void:
	_create_peer()
	multiplayer.peer_connected.connect(on_peer_connected)
	multiplayer.peer_disconnected.connect(on_peer_disconnected)

func _create_peer() -> void:
	var peer := WebSocketMultiplayerPeer.new()
	var error := peer.create_server(PORT)
	if error != OK:
		push_error("%d failed to create server: %s" % [PORT, error_string(error)])
		return
	multiplayer.multiplayer_peer = peer
	print("server listen on %d" % PORT)

func on_peer_connected(id: int) -> void:
	print("피어 접속: %d" % id)
	var character := Character.new(Vector2i.ZERO, 0, Color.RED, id)
	lobby.add_character(character)

func on_peer_disconnected(id: int) -> void:
	print("피어 접속 끊김: %d" % id)
	var character := lobby.find_character(id)
	lobby.remove_character(character)

@rpc("any_peer", "call_remote", "reliable")
func request_create_room() -> void:
	create_room()

@rpc("any_peer", "call_remote", "reliable")
func request_enter_room(room_id: String) -> void:
	enter_room(room_id, multiplayer.get_remote_sender_id())

@rpc("any_peer", "call_remote", "reliable")
func request_leave_room(room_id: String) -> void:
	leave_room(room_id, multiplayer.get_remote_sender_id())

@rpc("authority", "call_remote", "reliable")
func lobby_changed(lobby: Lobby) -> void:
	pass

func create_room() -> Room:
	return lobby.create_room()

func enter_room(room_id: String, peer_id: int) -> void:
	lobby.enter_room(room_id, peer_id)

func leave_room(room_id: String, peer_id: int) -> void:
	lobby.leave_room(room_id, peer_id)

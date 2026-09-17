class_name Server
extends Node

const PORT := 8080

func _ready() -> void:
	_create_peer()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _create_peer() -> void:
	var peer := WebSocketMultiplayerPeer.new()
	var error := peer.create_server(PORT)
	if error != OK:
		push_error("%d failed to create server: %s" % [PORT, error_string(error)])
		return
	multiplayer.multiplayer_peer = peer
	print("server listen on %d" % PORT)

func _on_peer_connected(id: int) -> void:
	print("피어 접속: %d" % id)

func _on_peer_disconnected(id: int) -> void:
	print("피어 접속 끊김: %d" % id)

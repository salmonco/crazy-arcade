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
	# TODO: lobby_changed.rpc()

func on_peer_disconnected(id: int) -> void:
	print("피어 접속 끊김: %d" % id)
	var character := lobby.find_character(id)
	if character.joined_room_id != "":
		leave_room(character.joined_room_id, id)
	lobby.remove_character(character)
	# TODO: lobby_changed.rpc()

@rpc("any_peer", "call_remote", "reliable")
func request_create_room() -> void:
	create_room()
	# TODO: lobby_changed.rpc()

@rpc("any_peer", "call_remote", "reliable")
func request_enter_room(room_id: String) -> void:
	enter_room(room_id, multiplayer.get_remote_sender_id())
	# TODO: lobby_changed.rpc()

@rpc("any_peer", "call_remote", "reliable")
func request_leave_room(room_id: String) -> void:
	leave_room(room_id, multiplayer.get_remote_sender_id())
	# TODO: lobby_changed.rpc()

@rpc("any_peer", "call_remote", "reliable")
func request_start_battle(room_id: String) -> void:
	start_battle(room_id)
	# TODO: lobby_changed.rpc()

@rpc("any_peer", "call_remote", "reliable")
func request_finish_battle(room_id: String) -> void:
	finish_battle(room_id)
	# TODO: lobby_changed.rpc()

@rpc("any_peer", "call_remote", "reliable")
func request_set_local_multi(room_id: String, enabled: bool) -> void:
	set_local_multi(room_id, enabled, multiplayer.get_remote_sender_id())
	# TODO: lobby_changed.rpc()

@rpc("any_peer", "call_remote", "reliable")
func request_set_monster_mode(room_id: String, enabled: bool) -> void:
	set_monster_mode(room_id, enabled, multiplayer.get_remote_sender_id())
	# TODO: lobby_changed.rpc()

@rpc("authority", "call_remote", "reliable")
func lobby_changed(_lobby: Lobby) -> void:
	pass

func create_room() -> Room:
	return lobby.create_room()

func enter_room(room_id: String, peer_id: int) -> void:
	lobby.enter_room(room_id, peer_id)

func leave_room(room_id: String, peer_id: int) -> void:
	lobby.leave_room(room_id, peer_id)

func start_battle(room_id: String) -> void:
	var room := lobby.find_room(room_id)
	room.game_start()

func finish_battle(room_id: String) -> void:
	var room := lobby.find_room(room_id)
	room.game_over()

func set_local_multi(room_id: String, enabled: bool, peer_id: int) -> void:
	var room := lobby.find_room(room_id)
	var second_player := room.find_2p(peer_id)
	if enabled:
		if second_player != null:
			return
		var new_2p = Character.new(Vector2i.ZERO, 2, _second_player_color(room.battle_mode), peer_id, true)
		room.add_character(new_2p)
	else:
		if second_player == null:
			return
		room.remove_character(second_player)

func set_monster_mode(room_id: String, enabled: bool, peer_id: int) -> void:
	var room := lobby.find_room(room_id)
	var second_player := room.find_2p(peer_id)
	room.set_battle_mode(BattleMode.MONSTER if enabled else BattleMode.LOCAL_MULTI)
	if second_player != null:
		second_player.color = _second_player_color(room.battle_mode)

func _second_player_color(battle_mode: StringName) -> Color:
	return Team.PLAYER_COLOR if battle_mode == BattleMode.MONSTER else Team.SECOND_PLAYER_COLOR

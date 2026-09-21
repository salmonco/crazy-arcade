class_name Server
extends Node

const PORT := 8080

var lobby := Lobby.new()

func _ready() -> void:
	_create_peer()
	multiplayer.peer_connected.connect(on_peer_connected)
	multiplayer.peer_disconnected.connect(on_peer_disconnected)

func _process(delta: float) -> void:
	_send(tick(delta, _connected_peers()))

func tick(delta: float, peer_ids: Array = []) -> Array:
	var battle_rooms := lobby.rooms_in_battle()
	lobby.tick(delta)
	return peers_in_rooms(peer_ids, battle_rooms)

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
	_broadcast()

func on_peer_disconnected(id: int) -> void:
	print("피어 접속 끊김: %d" % id)
	var character := lobby.find_character(id)
	if character.joined_room_id != "":
		leave_room(id)
	lobby.remove_character(character)
	_broadcast()

@rpc("any_peer", "call_remote", "reliable")
func request_create_room() -> void:
	create_room()
	_broadcast()

@rpc("any_peer", "call_remote", "reliable")
func request_enter_room(room_id: String) -> void:
	enter_room(room_id, multiplayer.get_remote_sender_id())
	_broadcast()

@rpc("any_peer", "call_remote", "reliable")
func request_leave_room() -> void:
	leave_room(multiplayer.get_remote_sender_id())
	_broadcast()

@rpc("any_peer", "call_remote", "reliable")
func request_start_battle() -> void:
	start_battle(multiplayer.get_remote_sender_id())
	_broadcast()

@rpc("any_peer", "call_remote", "reliable")
func request_set_local_multi(enabled: bool) -> void:
	set_local_multi(enabled, multiplayer.get_remote_sender_id())
	_broadcast()

@rpc("any_peer", "call_remote", "reliable")
func request_set_monster_mode(enabled: bool) -> void:
	set_monster_mode(enabled, multiplayer.get_remote_sender_id())
	_broadcast()

@rpc("any_peer", "call_remote", "reliable")
func request_move(number: int, direction: Vector2i) -> void:
	set_heading(number, direction, multiplayer.get_remote_sender_id())

@rpc("any_peer", "call_remote", "reliable")
func request_place_water_balloon(number: int) -> void:
	place_water_balloon(number, multiplayer.get_remote_sender_id())

@rpc("authority", "call_remote", "reliable")
func screen_changed(_snapshot: Dictionary) -> void:
	pass

func create_room() -> Room:
	return lobby.create_room()

func enter_room(room_id: String, peer_id: int) -> void:
	lobby.enter_room(room_id, peer_id)

func leave_room(peer_id: int) -> void:
	var room := lobby.room_of(peer_id)
	if room == null:
		return
	lobby.leave_room(room.id, peer_id)

func start_battle(peer_id: int) -> void:
	var room := lobby.room_of(peer_id)
	if room == null:
		return
	room.game_start()

func finish_battle(peer_id: int) -> void:
	var room := lobby.room_of(peer_id)
	if room == null:
		return
	room.game_over()

func set_local_multi(enabled: bool, peer_id: int) -> void:
	var room := lobby.room_of(peer_id)
	if room == null:
		return
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

func set_monster_mode(enabled: bool, peer_id: int) -> void:
	var room := lobby.room_of(peer_id)
	if room == null:
		return
	var second_player := room.find_2p(peer_id)
	room.set_battle_mode(BattleMode.MONSTER if enabled else BattleMode.LOCAL_MULTI)
	if second_player != null:
		second_player.color = _second_player_color(room.battle_mode)

func set_heading(number: int, direction: Vector2i, peer_id: int) -> void:
	var room := lobby.room_of(peer_id)
	if room == null:
		return
	room.set_heading(peer_id, number, direction)

func place_water_balloon(number: int, peer_id: int) -> void:
	var room := lobby.room_of(peer_id)
	if room == null:
		return
	room.place_water_balloon(peer_id, number)

func _second_player_color(battle_mode: StringName) -> Color:
	return Team.PLAYER_COLOR if battle_mode == BattleMode.MONSTER else Team.SECOND_PLAYER_COLOR

func peers_in_rooms(peer_ids: Array, rooms: Array) -> Array:
	var found: Array = []
	for peer_id in peer_ids:
		if lobby.room_of(peer_id) in rooms:
			found.append(peer_id)
	return found

func _connected_peers() -> Array:
	if multiplayer == null:
		return []
	return Array(multiplayer.get_peers())

func _broadcast() -> void:
	_send(_connected_peers())

func _send(peer_ids: Array) -> void:
	for peer_id in peer_ids:
		screen_changed.rpc_id(peer_id, lobby.snapshot_for(peer_id))

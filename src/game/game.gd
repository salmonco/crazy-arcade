class_name Game
extends Node

@onready var lobby_view: LobbyView = $LobbyView
@onready var room_view: RoomView = $RoomView
@onready var battle_view: BattleView = $BattleView

const URL := "ws://localhost:%d" % Server.PORT

var current_room: Room
var second_player_character: Character
var peer_id: int

func _ready() -> void:
	_create_peer()
	lobby_view.create_room_button.pressed.connect(create_room)
	room_view.leave_button.pressed.connect(leave_room)
	lobby_view.room_chosen.connect(enter_room)
	room_view.monster_mode_check.toggled.connect(set_monster_mode)
	room_view.start_button.pressed.connect(start_battle)
	room_view.local_multi_check.toggled.connect(set_local_multi)
	battle_view.game_over.connect(finish_game)
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
func request_enter_room(room_id: String) -> void:
	pass

@rpc("any_peer", "call_remote", "reliable")
func request_leave_room(room_id: String) -> void:
	pass

@rpc("any_peer", "call_remote", "reliable")
func request_start_battle(room_id: String) -> void:
	pass

@rpc("any_peer", "call_remote", "reliable")
func request_finish_battle(room_id: String) -> void:
	pass

@rpc("authority", "call_remote", "reliable")
func lobby_changed(_lobby: Lobby) -> void:
	lobby_view.render(_lobby)
	var character := _lobby.find_character(peer_id)
	if character == null:
		return
	var room := _lobby.find_room(character.joined_room_id)
	if room == null:
		_remove_second_player()
		current_room = null
		room_view.visible = false
		lobby_view.visible = true
		return
	current_room = room
	room_view.render(room)
	lobby_view.visible = false
	if room.get_battle() != null and not room.get_battle().is_finished:
		battle_view.show_battle(current_room.get_battle())
		room_view.visible = false
		battle_view.visible = true
	else:
		room_view.visible = true
		battle_view.visible = false

func create_room() -> void:
	request_create_room.rpc_id(1)

func enter_room(room_id: String) -> void:
	request_enter_room.rpc_id(1, room_id)

func leave_room(room_id: String) -> void:
	request_leave_room.rpc_id(1, room_id)

func start_battle() -> void:
	request_start_battle.rpc_id(1, current_room.id)

func finish_game() -> void:
	request_finish_battle.rpc_id(1, current_room.id)

func set_local_multi(enabled: bool) -> void:
	if enabled:
		_add_second_player()
	else:
		_remove_second_player()
	room_view.render(current_room)

func _add_second_player() -> void:
	if second_player_character != null:
		return
	second_player_character = Character.new(Vector2i.ZERO, 2, _second_player_color())
	current_room.add_character(second_player_character)

func _remove_second_player() -> void:
	if second_player_character == null:
		return
	current_room.remove_character(second_player_character)
	second_player_character = null

func set_monster_mode(enabled: bool) -> void:
	current_room.set_battle_mode(BattleMode.MONSTER if enabled else BattleMode.LOCAL_MULTI)
	if second_player_character != null:
		second_player_character.color = _second_player_color()
	room_view.render(current_room)

func _second_player_color() -> Color:
	if current_room.battle_mode == BattleMode.MONSTER:
		return Team.PLAYER_COLOR
	return Team.SECOND_PLAYER_COLOR

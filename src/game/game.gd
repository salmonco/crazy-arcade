class_name Game
extends Node

@onready var lobby_view: LobbyView = $LobbyView
@onready var room_view: RoomView = $RoomView
@onready var battle_view: BattleView = $BattleView

var lobby := Lobby.new()
var current_room: Room
var player_character := Character.new(Vector2i.ZERO, 1, Color.RED)
var second_player_character: Character

func _ready() -> void:
	lobby_view.create_room_button.pressed.connect(create_room)
	room_view.leave_button.pressed.connect(leave_room)
	lobby_view.room_chosen.connect(enter_room)
	room_view.monster_mode_check.toggled.connect(set_monster_mode)
	room_view.start_button.pressed.connect(start_game)
	room_view.local_multi_check.toggled.connect(set_local_multi)
	battle_view.game_over.connect(finish_game)
	multiplayer.peer_connected.connect(on_peer_connected)

func on_peer_connected(peer_id: int) -> void:
	var character := Character.new(Vector2i(1, 2), 0, Color.RED, peer_id)
	lobby.add_character(character)

func create_room() -> void:
	enter_room(lobby.create_room().id)

func start_game() -> void:
	current_room.game_start()
	battle_view.show_battle(current_room.get_battle())
	room_view.visible = false
	battle_view.visible = true

func finish_game() -> void:
	current_room.game_over()
	room_view.visible = true
	battle_view.visible = false

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
		return player_character.color
	return Team.SECOND_PLAYER_COLOR

func leave_room(peer_id: int = 0) -> void:
	if peer_id == 0:
		current_room.remove_character(player_character)
	else:
		var character := lobby.find_character(peer_id)
		current_room.remove_character(character)
	_remove_second_player()
	current_room = null
	lobby_view.render(lobby)
	room_view.visible = false
	lobby_view.visible = true

func enter_room(room_id: String, peer_id: int = 0) -> void:
	var room := lobby.find_room(room_id)
	if room == null:
		return
	if current_room != null:
		leave_room()
	current_room = room
	if peer_id == 0:
		room.add_character(player_character)
	else:
		var character := lobby.find_character(peer_id)
		room.add_character(character)
	room_view.render(room)
	lobby_view.visible = false
	room_view.visible = true

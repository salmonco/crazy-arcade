class_name Room
extends RefCounted

const MINIMUM_TEAM_COUNT_TO_START_BATTLE := 2

var _characters: Array[Character] = []
var _battle: Battle = null
var id: String
var battle_mode: StringName = BattleMode.LOCAL_MULTI
var messages: Array[Message] = []

func _init() -> void:
	id = UUID.v4()

func add_character(character: Character) -> void:
	if has_npc():
		var npc := _npc()
		_characters.erase(npc)
		character.number = _empty_seat_number()
		_characters.append(character)
		npc.number = _empty_seat_number()
		_characters.append(npc)
	else:
		character.number = _empty_seat_number()
		_characters.append(character)
	character.joined_room_id = id

func find_character(peer_id: int) -> Character:
	for character in _characters:
		if character.id == peer_id:
			return character
	return null

func send_message(character_id: int, contents: String) -> void:
	var message := Message.new()
	message.sender_id = character_id
	message.contents = contents
	messages.append(message)

func _empty_seat_number() -> int:
	var taken: Array[int] = []
	for character in _characters:
		taken.append(character.number)
	var number := 1
	while number in taken:
		number += 1
	return number

func game_start() -> void:
	var map := Map.new()
	for character in _characters:
		character.continuous_position = Map.SEAT_START_CELLS[character.number - 1]
		map.add_character(character)
	_place_game_items(map)
	_battle = Battle.new(map, battle_mode)

func game_over() -> void:
	for character in _characters:
		character.init_player()
	_battle = null

func get_battle() -> Battle:
	return _battle

func set_battle_mode(mode: StringName) -> void:
	battle_mode = mode
	if mode == BattleMode.MONSTER:
		_add_npc()
	else:
		if has_npc():
			_remove_npcs()

func remove_character(character: Character) -> void:
	_characters.erase(character)
	character.joined_room_id = ""

func characters() -> Array[Character]:
	return _characters

func team_count() -> int:
	return Team.colors(_characters).size()

func can_game_start() -> bool:
	return team_count() >= MINIMUM_TEAM_COUNT_TO_START_BATTLE

func has_npc() -> bool:
	for character in _characters:
		if character is Npc:
			return true
	return false

func find_2p(peer_id: int) -> Character:
	for character in _characters:
		if character.id == peer_id and character.is_2p:
			return character
	return null

func _remove_npcs() -> void:
	for character in _characters.duplicate():
		if character is Npc:
			_characters.erase(character)

func _add_npc() -> void:
	var npc := Npc.new(Vector2i.ZERO, 0, Team.MONSTER_COLOR)
	add_character(npc)

func _npc() -> Npc:
	for character in _characters:
		if character is Npc:
			return character
	return null

func _place_game_items(map: Map) -> void:
	# 물풍선 아이템 배치
	map.add_game_item(GameItem.INCREASE_WATER_BALLOON_COUNT, Vector2i(5, 4))
	map.add_game_item(GameItem.INCREASE_WATER_BALLOON_COUNT, Vector2i(1, 7))
	map.add_game_item(GameItem.INCREASE_WATER_BALLOON_COUNT, Vector2i(8, 5))
	map.add_game_item(GameItem.INCREASE_WATER_BALLOON_COUNT, Vector2i(13, 12))
	map.add_game_item(GameItem.INCREASE_WATER_BALLOON_COUNT, Vector2i(12, 6))
	map.add_game_item(GameItem.INCREASE_WATER_BALLOON_COUNT, Vector2i(15, 1))
	map.add_game_item(GameItem.INCREASE_WATER_BALLOON_COUNT, Vector2i(0, 11))
	map.add_game_item(GameItem.INCREASE_WATER_BALLOON_COUNT, Vector2i(11, 11))
	map.add_game_item(GameItem.INCREASE_WATER_BALLOON_COUNT, Vector2i(2, 2))
	# 물줄기 아이템 배치
	map.add_game_item(GameItem.INCREASE_WATER_STREAM_LENGTH, Vector2i(11, 6))
	map.add_game_item(GameItem.INCREASE_WATER_STREAM_LENGTH, Vector2i(1, 3))
	map.add_game_item(GameItem.INCREASE_WATER_STREAM_LENGTH, Vector2i(15, 13))
	map.add_game_item(GameItem.INCREASE_WATER_STREAM_LENGTH, Vector2i(10, 9))
	map.add_game_item(GameItem.INCREASE_WATER_STREAM_LENGTH, Vector2i(10, 0))
	# 스피드 아이템 배치
	map.add_game_item(GameItem.INCREASE_SPEED, Vector2i(9, 9))
	map.add_game_item(GameItem.INCREASE_SPEED, Vector2i(5, 9))
	map.add_game_item(GameItem.INCREASE_SPEED, Vector2i(8, 10))
	map.add_game_item(GameItem.INCREASE_SPEED, Vector2i(14, 1))
	map.add_game_item(GameItem.INCREASE_SPEED, Vector2i(0, 1))

func snapshot(peer_id: int) -> Dictionary:
	var seats_snapshot: Array[Dictionary] = []
	for character in _characters:
		seats_snapshot.append({
			"number": character.number,
			"color": character.color,
			"is_npc": character is Npc
		})
	return {
		"id": id,
		"mode": battle_mode,
		"can_battle_start": can_game_start(),
		"local_multi_on": find_2p(peer_id) != null,
		"seats": seats_snapshot,
	}

func battle_snapshot() -> Dictionary:
	var characters_snapshot: Array[Dictionary] = []
	var seats_snapshot: Array[Dictionary] = []
	var water_balloons_snapshot: Array[Dictionary] = []
	var water_streams_snapshot: Array[Dictionary] = []
	var game_items_snapshot: Array[Dictionary] = []
	for character in _battle.get_map().characters():
		characters_snapshot.append({
			"number": character.number,
			"is_npc": character is Npc,
			"cell": character.continuous_position,
			"color": character.color,
			"facing": character.facing,
			"is_trapped": character.is_trapped(),
		})
	for character in _characters:
		seats_snapshot.append({
			"number": character.number,
			"is_npc": character is Npc,
			"color": character.color,
			"is_out": character.is_out
		})
	for water_balloon in _battle.get_map().water_balloons():
		water_balloons_snapshot.append({
			"cell": water_balloon.position,
			"owner_number": water_balloon.placed_by.number
		})
	for water_stream in _battle.get_map().water_streams():
		water_streams_snapshot.append({
			"cell": water_stream.position,
			"direction": water_stream.direction,
			"position_type": water_stream.position_type
		})
	for game_item in _battle.get_map().game_items():
		game_items_snapshot.append({
			"cell": game_item.position,
			"type": game_item.type
		})
	return {
		"characters": characters_snapshot,
		"seats": seats_snapshot,
		"water_balloons": water_balloons_snapshot,
		"water_streams": water_streams_snapshot,
		"game_items": game_items_snapshot,
		"winner_color": _battle.winner,
		"is_draw": _battle.is_draw,
	}

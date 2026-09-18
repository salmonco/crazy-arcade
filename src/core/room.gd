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
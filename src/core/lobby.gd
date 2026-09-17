class_name Lobby
extends RefCounted

var rooms: Array[Room] = []
var characters: Array[Character] = []

func _init() -> void:
	pass

func create_room() -> Room:
	var room := Room.new()
	rooms.append(room)
	return room

func room_count() -> int:
	return rooms.size()

func find_room(id: String) -> Room:
	for room in rooms:
		if room.id == id:
			return room
	return null

func add_character(character: Character) -> void:
	characters.append(character)

func remove_character(character: Character) -> void:
	characters.erase(character)

func find_character(peer_id: int) -> Character:
	for character: Character in characters:
		if character.id == peer_id:
			return character
	return null

func enter_room(room_id: String, peer_id: int) -> bool:
	var room := find_room(room_id)
	var character := find_character(peer_id)
	if character == null:
		return false
	room.add_character(character)
	return true

func leave_room(room_id: String, peer_id: int) -> bool:
	var room := find_room(room_id)
	var character := find_character(peer_id)
	room.remove_character(character)
	return true

class_name Lobby
extends RefCounted

var rooms: Array[Room] = []
var characters: Array[Character] = []

func _init() -> void:
	pass

func create_room() -> Room:
	var room := Room.new()
	add_room(room)
	return room

func add_room(room: Room) -> void:
	rooms.append(room)

func room_count() -> int:
	return rooms.size()

func find_room(id: String) -> Room:
	for room in rooms:
		if room.id == id:
			return room
	return null

func add_character(character: Character) -> void:
	characters.append(character)

func find_character(peer_id: int) -> Character:
	for character: Character in characters:
		if character.id == peer_id:
			return character
	return null
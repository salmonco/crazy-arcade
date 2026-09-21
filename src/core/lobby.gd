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
	if room == null:
		return false
	var character := find_character(peer_id)
	if character == null:
		return false
	if character.joined_room_id != "":
		leave_room(character.joined_room_id, peer_id)
	room.add_character(character)
	return true

func leave_room(room_id: String, peer_id: int) -> bool:
	var room := find_room(room_id)
	if room == null:
		return false
	var character := find_character(peer_id)
	if character == null:
		return false
	var second_player := room.find_2p(peer_id)
	if second_player != null:
		room.remove_character(second_player)
	room.remove_character(character)
	return true

func tick(delta: float) -> void:
	for room in rooms:
		room.tick(delta)

func rooms_in_battle() -> Array[Room]:
	var running: Array[Room] = []
	for room in rooms:
		if room.get_battle() != null:
			running.append(room)
	return running

func snapshot() -> Dictionary:
	var rooms_snapshot: Array[Dictionary] = []
	for room in rooms:
		rooms_snapshot.append({
			"id": room.id,
			"character_count": room.characters().size(),
			"mode": room.battle_mode
		})
	return { "rooms": rooms_snapshot }

func room_of(peer_id: int) -> Room:
	var character := find_character(peer_id)
	if character == null:
		return null
	return find_room(character.joined_room_id)

func snapshot_for(peer_id: int) -> Dictionary:
	var character := find_character(peer_id)
	if character == null:
		return { "screen": null }
	var room := find_room(character.joined_room_id)
	if room == null:
		return { "screen": Screen.LOBBY, "lobby": snapshot() }
	var is_playing_battle := room.get_battle() != null and not room.get_battle().is_finished
	if is_playing_battle:
		return { "screen": Screen.BATTLE, "battle": room.battle_snapshot() }
	return { "screen": Screen.ROOM, "room": room.snapshot(peer_id) }

class_name LobbyView
extends Control

const ROOM_ID_DIGITS := 8
const ENTRY_SIZE := Vector2(320, 74)
const MODE_NAMES: Dictionary[StringName, String] = {
	BattleMode.MONSTER: "협공배틀",
	BattleMode.LOCAL_MULTI: "로컬멀티",
}

signal room_chosen(room_id: String)

@onready var room_list: GridContainer = %RoomList
@onready var create_room_button: Button = %CreateRoomButton

func render(snapshot: Dictionary) -> void:
	_clear_room_list()
	var rooms: Array = snapshot["rooms"]
	for room in rooms:
		room_list.add_child(_create_room_entry(room))

func room_count() -> int:
	return room_list.get_child_count()

func room_entry(index: int) -> Button:
	return room_list.get_child(index)

func _clear_room_list() -> void:
	for entry in room_list.get_children():
		room_list.remove_child(entry)
		entry.queue_free()

func _create_room_entry(room: Dictionary) -> Button:
	var entry := Button.new()
	entry.theme_type_variation = &"RoomRow"
	entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
	entry.custom_minimum_size = ENTRY_SIZE
	entry.text = "방 %s\n%d / %d  ·  %s" % [
		room["id"].substr(0, ROOM_ID_DIGITS),
		room["character_count"],
		Map.SEAT_START_CELLS.size(),
		MODE_NAMES.get(room["mode"]),
	]
	entry.pressed.connect(room_chosen.emit.bind(room.id))
	return entry

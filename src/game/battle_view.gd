class_name BattleView
extends Node2D

const WATER_STREAM_TEXTURES: Dictionary[String, Texture2D] = {
	"center": preload("res://assets/water_streams/center.png"),
	"straight": preload("res://assets/water_streams/straight_up.png"),
	"end": preload("res://assets/water_streams/end_up.png"),
}
const WATER_BALLOON_WATER_MELON_TEXTURE: Texture2D = preload("res://assets/water_balloons/water_melon.png")
const WATER_BALLOON_NIGHTMARE_TEXTURE: Texture2D = preload("res://assets/water_balloons/nightmare.png")
const WATER_BALLOON_GREEN_FAIRY_TEXTURE: Texture2D = preload("res://assets/water_balloons/green_fairy.png")
const PLAYER_WATER_BALLOON_TEXTURE := WATER_BALLOON_WATER_MELON_TEXTURE
const SECOND_PLAYER_WATER_BALLOON_TEXTURE := WATER_BALLOON_GREEN_FAIRY_TEXTURE
const NPC_WATER_BALLOON_TEXTURE := WATER_BALLOON_NIGHTMARE_TEXTURE
const GAME_ITEM_WATER_BALLOON_TEXTURE: Texture2D = preload("res://assets/game_items/water_balloon.png")
const GAME_ITEM_WHITE_POTION_TEXTURE: Texture2D = preload("res://assets/game_items/white_potion.png")
const GAME_ITEM_SPEED_TEXTURE: Texture2D = preload("res://assets/game_items/speed.png")

const ZOMKKAN_VIEW := preload("res://scenes/zomkkan_view.tscn")
const BAZZI_VIEW := preload("res://scenes/bazzi_view.tscn")

var view_by_character_number: Dictionary[int, CharacterView] = {}

signal move_requested(number: int, direction: Vector2i)
signal water_balloon_requested(number: int)

@onready var character_views: Node2D = $CharacterViews
@onready var water_balloon_views: Node2D = $WaterBalloonViews
@onready var water_stream_views: Node2D = $WaterStreamViews
@onready var game_item_views: Node2D = $GameItemViews
@onready var overlay: CanvasLayer = $CanvasLayer
@onready var win_label: Label = $CanvasLayer/WinLabel
@onready var lose_label: Label = $CanvasLayer/LoseLabel
@onready var draw_label: Label = $CanvasLayer/DrawLabel

var peer_id: int
var pressed_move_keys: Array[Key] = []
var pressed_move_keys_local_multi: Array[Key] = []

var _snapshot: Dictionary = {}
var _sent_direction: Dictionary[int, Vector2i] = {}

func _ready() -> void:
	visibility_changed.connect(sync_overlay)
	sync_overlay()

func sync_overlay() -> void:
	overlay.visible = visible

func render(snapshot: Dictionary, my_peer_id: int) -> void:
	_snapshot = snapshot
	peer_id = my_peer_id
	_render_characters()
	_render_water_balloons()
	_render_water_streams()
	_render_game_items()
	_render_game_over_label()

func my_character_numbers() -> Array[int]:
	var numbers: Array[int] = []
	for seat in _seats():
		if not seat["is_npc"] and seat["peer_id"] == peer_id:
			numbers.append(seat["number"])
	numbers.sort()
	return numbers

func handle_key_pressed(key: Key, location: KeyLocation = KEY_LOCATION_UNSPECIFIED) -> void:
	var game_key := GameKey.from_key(key, location)
	var numbers := my_character_numbers()
	if game_key == GameKey.SPACE and numbers.size() == 1:
		water_balloon_requested.emit(numbers[0])
	if game_key == GameKey.SHIFT_LEFT and numbers.size() > 1:
		water_balloon_requested.emit(numbers[0])
	if game_key == GameKey.SHIFT_RIGHT and numbers.size() > 1:
		water_balloon_requested.emit(numbers[1])
	if Direction.has(key) and key not in pressed_move_keys:
		pressed_move_keys.append(key)
	if Direction.has_local_multi(key) and key not in pressed_move_keys_local_multi:
		pressed_move_keys_local_multi.append(key)
	_send_directions()

func handle_key_released(key: Key) -> void:
	if Direction.has(key):
		pressed_move_keys.erase(key)
	if Direction.has_local_multi(key):
		pressed_move_keys_local_multi.erase(key)
	_send_directions()

func _send_directions() -> void:
	var numbers := my_character_numbers()
	for index in numbers.size():
		var number: int = numbers[index]
		var direction := _direction_for(index, numbers.size())
		if _sent_direction.get(number, Vector2i.ZERO) == direction:
			continue
		_sent_direction[number] = direction
		move_requested.emit(number, direction)

func _direction_for(index: int, count: int) -> Vector2i:
	if count == 1 or index == 1:
		return _read_move_direction()
	return _read_move_direction_local_multi()

func _read_move_direction() -> Vector2i:
	if pressed_move_keys.is_empty():
		return Vector2i.ZERO
	return Direction.from_key(pressed_move_keys.back())

func _read_move_direction_local_multi() -> Vector2i:
	if pressed_move_keys_local_multi.is_empty():
		return Vector2i.ZERO
	return Direction.from_key_local_multi(pressed_move_keys_local_multi.back())

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.is_echo():
		var key_event := (event as InputEventKey)
		if key_event.is_pressed():
			handle_key_pressed(key_event.physical_keycode, key_event.location)
		else:
			handle_key_released(key_event.physical_keycode)

func _seats() -> Array:
	return _snapshot.get("seats", [])

func _render_characters() -> void:
	var drawn: Array = _snapshot.get("characters", [])
	var alive := {}
	for character in drawn:
		alive[character["number"]] = true
	for number in view_by_character_number.keys():
		if number not in alive:
			var gone: CharacterView = view_by_character_number[number]
			view_by_character_number.erase(number)
			character_views.remove_child(gone)
			gone.queue_free()
	for character in drawn:
		var number: int = character["number"]
		if number not in view_by_character_number:
			var scene: PackedScene = ZOMKKAN_VIEW if character["is_npc"] else BAZZI_VIEW
			var view: CharacterView = scene.instantiate()
			view_by_character_number[number] = view
			character_views.add_child(view)
		view_by_character_number[number].sync(character)

func _render_water_balloons() -> void:
	for view in water_balloon_views.get_children():
		water_balloon_views.remove_child(view)
		view.queue_free()

	for water_balloon in _snapshot.get("water_balloons", []):
		var view := Sprite2D.new()
		view.texture = _water_balloon_texture(water_balloon["owner_number"])
		view.scale = Vector2.ONE * (Map.PIXELS_PER_CELL / 42.0)
		view.position = Map.to_pixel(water_balloon["cell"])
		view.centered = false
		water_balloon_views.add_child(view)

func _water_balloon_texture(owner_number: int) -> Texture2D:
	for seat in _seats():
		if seat["number"] != owner_number:
			continue
		if seat["is_npc"]:
			return NPC_WATER_BALLOON_TEXTURE
		break
	return PLAYER_WATER_BALLOON_TEXTURE if owner_number == 1 else SECOND_PLAYER_WATER_BALLOON_TEXTURE

func _render_water_streams() -> void:
	for view in water_stream_views.get_children():
		water_stream_views.remove_child(view)
		view.queue_free()

	for water_stream in _snapshot.get("water_streams", []):
		var view := Sprite2D.new()
		view.texture = WATER_STREAM_TEXTURES[water_stream["position_type"]]
		match water_stream["direction"]:
			Vector2i.DOWN:
				view.flip_v = true
			Vector2i.LEFT:
				view.rotation_degrees = -90
			Vector2i.RIGHT:
				view.rotation_degrees = 90
		view.scale = Vector2.ONE * (Map.PIXELS_PER_CELL / 42.0)
		view.position = Map.to_pixel_center(water_stream["cell"])
		water_stream_views.add_child(view)

func _render_game_items() -> void:
	for view in game_item_views.get_children():
		game_item_views.remove_child(view)
		view.queue_free()

	for game_item in _snapshot.get("game_items", []):
		var view := Sprite2D.new()
		match game_item["type"]:
			GameItem.INCREASE_WATER_BALLOON_COUNT:
				view.texture = GAME_ITEM_WATER_BALLOON_TEXTURE
			GameItem.INCREASE_WATER_STREAM_LENGTH:
				view.texture = GAME_ITEM_WHITE_POTION_TEXTURE
			GameItem.INCREASE_SPEED:
				view.texture = GAME_ITEM_SPEED_TEXTURE
		view.scale = Vector2.ONE * (Map.PIXELS_PER_CELL / 64.0)
		view.position = Map.to_pixel(game_item["cell"]) + Vector2(Map.PIXELS_PER_CELL / 2.0, Map.PIXELS_PER_CELL)
		view.offset = Vector2(-32, -96) # (-w/2, -h)
		view.centered = false
		game_item_views.add_child(view)

func _render_game_over_label() -> void:
	var winner_color: Color = _snapshot.get("winner_color", Color.BLACK)
	var has_winner := winner_color != Color.BLACK
	draw_label.visible = _snapshot.get("is_draw", false)

	var my_colors := _my_colors()
	if my_colors.is_empty():
		win_label.visible = false
		lose_label.visible = false
		return
	if my_colors.size() == 1:
		win_label.visible = has_winner and winner_color == my_colors[0]
		lose_label.visible = has_winner and winner_color != my_colors[0]
		return
	win_label.visible = has_winner
	lose_label.visible = false
	if has_winner:
		win_label.text = "1P WIN!!" if winner_color == my_colors[0] else "2P WIN!!"

func _my_colors() -> Array[Color]:
	var numbers := my_character_numbers()
	var colors: Array[Color] = []
	for seat in _seats():
		if seat["number"] in numbers and seat["color"] not in colors:
			colors.append(seat["color"])
	return colors

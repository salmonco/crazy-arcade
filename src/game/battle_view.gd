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
var view_by_character: Dictionary[Character, CharacterView] = {}

signal game_over()

@onready var character_views: Node2D = $CharacterViews
@onready var water_balloon_views: Node2D = $WaterBalloonViews
@onready var water_stream_views: Node2D = $WaterStreamViews
@onready var game_item_views: Node2D = $GameItemViews
@onready var overlay: CanvasLayer = $CanvasLayer
@onready var win_label: Label = $CanvasLayer/WinLabel
@onready var lose_label: Label = $CanvasLayer/LoseLabel
@onready var draw_label: Label = $CanvasLayer/DrawLabel

var battle: Battle
var first_character: Character
var second_character: Character
var humans: Array[Character] = []
var pressed_move_keys: Array[Key] = []
var pressed_move_keys_local_multi: Array[Key] = []

func _ready() -> void:
	visibility_changed.connect(sync_overlay)
	sync_overlay()

func sync_overlay() -> void:
	overlay.visible = visible

func show_battle(new_battle: Battle) -> void:
	battle = new_battle
	humans = _seated_humans()
	_render_characters()
	first_character = _character_at_seat(1)
	second_character = _character_at_seat(2)
	_place_game_items()
	_render_game_items()
	_render_game_over_label()

func _seated_humans() -> Array[Character]:
	var seated: Array[Character] = []
	for character in battle.get_map().characters():
		if character is Npc:
			continue
		seated.append(character)
	seated.sort_custom(func(a: Character, b: Character) -> bool: return a.number < b.number)
	return seated

func _read_direction_for(character: Character) -> Vector2i:
	if humans.size() == 1 or character != humans[0]:
		return _read_move_direction()
	return _read_move_direction_local_multi()

func _character_at_seat(number: int) -> Character:
	for character in battle.get_map().characters():
		if character.number == number:
			return character
	return null

func start_battle(mode: StringName) -> void:
	var map := Map.new()
	match mode:
		BattleMode.MONSTER:
			var monster := Npc.new(Vector2i(1, 6), 1, Team.MONSTER_COLOR)
			var human := Character.new(Vector2i(13, 6), 2, Color.RED)
			map.add_character(monster)
			map.add_character(human)
		BattleMode.LOCAL_MULTI:
			var human1 := Character.new(Vector2i(1, 6), 1, Color.RED)
			var human2 := Character.new(Vector2i(13, 6), 2, Color.BLUE)
			map.add_character(human1)
			map.add_character(human2)
	show_battle(Battle.new(map, mode))

func handle_key_pressed(key: Key, location: KeyLocation = KEY_LOCATION_UNSPECIFIED) -> void:
	var game_key := GameKey.from_key(key, location)
	if game_key == GameKey.SPACE and humans.size() == 1:
		humans[0].place_water_balloon(battle.get_map())
		_render_water_balloons()
	if game_key == GameKey.SHIFT_LEFT and humans.size() > 1:
		humans[0].place_water_balloon(battle.get_map())
		_render_water_balloons()
	if game_key == GameKey.SHIFT_RIGHT and humans.size() > 1:
		humans[1].place_water_balloon(battle.get_map())
		_render_water_balloons()
	if Direction.has(key) and key not in pressed_move_keys:
		pressed_move_keys.append(key)
	if Direction.has_local_multi(key) and key not in pressed_move_keys_local_multi:
		pressed_move_keys_local_multi.append(key)

func handle_key_released(key: Key) -> void:
	if Direction.has(key):
		pressed_move_keys.erase(key)
	if Direction.has_local_multi(key):
		pressed_move_keys_local_multi.erase(key)

func tick(delta: float) -> void:
	if battle == null:
		return
	battle.tick(delta)
	_handle_characters(delta)
	_render_water_balloons()
	_render_water_streams()
	_render_characters()
	_render_game_items()
	_render_game_over_label()
	if battle.should_go_to_room:
		game_over.emit()

func _place_game_items() -> void:
	# 물풍선 아이템 배치
	battle.get_map().add_game_item(GameItem.INCREASE_WATER_BALLOON_COUNT, Vector2i(5, 4))
	battle.get_map().add_game_item(GameItem.INCREASE_WATER_BALLOON_COUNT, Vector2i(1, 7))
	battle.get_map().add_game_item(GameItem.INCREASE_WATER_BALLOON_COUNT, Vector2i(8, 5))
	battle.get_map().add_game_item(GameItem.INCREASE_WATER_BALLOON_COUNT, Vector2i(13, 12))
	battle.get_map().add_game_item(GameItem.INCREASE_WATER_BALLOON_COUNT, Vector2i(12, 6))
	battle.get_map().add_game_item(GameItem.INCREASE_WATER_BALLOON_COUNT, Vector2i(15, 1))
	battle.get_map().add_game_item(GameItem.INCREASE_WATER_BALLOON_COUNT, Vector2i(0, 11))
	battle.get_map().add_game_item(GameItem.INCREASE_WATER_BALLOON_COUNT, Vector2i(11, 11))
	battle.get_map().add_game_item(GameItem.INCREASE_WATER_BALLOON_COUNT, Vector2i(2, 2))
	# 물줄기 아이템 배치
	battle.get_map().add_game_item(GameItem.INCREASE_WATER_STREAM_LENGTH, Vector2i(11, 6))
	battle.get_map().add_game_item(GameItem.INCREASE_WATER_STREAM_LENGTH, Vector2i(1, 3))
	battle.get_map().add_game_item(GameItem.INCREASE_WATER_STREAM_LENGTH, Vector2i(15, 13))
	battle.get_map().add_game_item(GameItem.INCREASE_WATER_STREAM_LENGTH, Vector2i(10, 9))
	battle.get_map().add_game_item(GameItem.INCREASE_WATER_STREAM_LENGTH, Vector2i(10, 0))
	# 스피드 아이템 배치
	battle.get_map().add_game_item(GameItem.INCREASE_SPEED, Vector2i(9, 9))
	battle.get_map().add_game_item(GameItem.INCREASE_SPEED, Vector2i(5, 9))
	battle.get_map().add_game_item(GameItem.INCREASE_SPEED, Vector2i(8, 10))
	battle.get_map().add_game_item(GameItem.INCREASE_SPEED, Vector2i(14, 1))
	battle.get_map().add_game_item(GameItem.INCREASE_SPEED, Vector2i(0, 1))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.is_echo():
		var key_event := (event as InputEventKey)
		if key_event.is_pressed():
			handle_key_pressed(key_event.physical_keycode, key_event.location)
		else:
			handle_key_released(key_event.physical_keycode)

func _process(delta: float) -> void:
	tick(delta)

func _handle_characters(delta: float) -> void:
	for character in battle.get_map().characters():
		if character is Npc:
			character.move(character.decide_move_direction(battle.get_map()), delta, battle.get_map().water_balloon_positions())
			if character.should_place_water_balloon(battle.get_map()):
				character.place_water_balloon(battle.get_map())
		else:
			character.move(_read_direction_for(character), delta, battle.get_map().water_balloon_positions())

func _render_characters() -> void:
	# 사라진 캐릭터의 뷰 정리
	for character in view_by_character.keys():
		if character not in battle.get_map().characters():
			var view: CharacterView = view_by_character[character]
			view_by_character.erase(character)
			character_views.remove_child(view)
			view.queue_free()
	# 새 캐릭터 뷰 생성
	for character in battle.get_map().characters():
		if character not in view_by_character:
			var view: CharacterView
			if character is Npc:
				view = ZOMKKAN_VIEW.instantiate()
			else:
				view = BAZZI_VIEW.instantiate()
			view_by_character[character] = view
			character_views.add_child(view)
	# sync하여 position 갱신
	for character in battle.get_map().characters():
		view_by_character[character].sync(character)

func _render_water_balloons() -> void:
	for view in water_balloon_views.get_children():
		water_balloon_views.remove_child(view)
		view.queue_free()

	for water_balloon in battle.get_map().water_balloons():
		var view := Sprite2D.new()
		if water_balloon.placed_by is Npc:
			view.texture = NPC_WATER_BALLOON_TEXTURE
		else:
			if water_balloon.placed_by.number == 1:
				view.texture = PLAYER_WATER_BALLOON_TEXTURE
			else:
				view.texture = SECOND_PLAYER_WATER_BALLOON_TEXTURE
		view.scale = Vector2.ONE * (Map.PIXELS_PER_CELL / 42.0)
		view.position = Map.to_pixel(water_balloon.position)
		view.centered = false
		water_balloon_views.add_child(view)

func _render_water_streams() -> void:
	for view in water_stream_views.get_children():
		water_stream_views.remove_child(view)
		view.queue_free()

	for water_stream in battle.get_map().water_streams():
		var view := Sprite2D.new()
		view.texture = WATER_STREAM_TEXTURES[water_stream.position_type]
		match water_stream.direction:
			Vector2i.DOWN:
				view.flip_v = true
			Vector2i.LEFT:
				view.rotation_degrees = -90
			Vector2i.RIGHT:
				view.rotation_degrees = 90
		view.scale = Vector2.ONE * (Map.PIXELS_PER_CELL / 42.0)
		view.position = Map.to_pixel(water_stream.position) + Vector2.ONE * (Map.PIXELS_PER_CELL / 2.0)
		water_stream_views.add_child(view)

func _render_game_items() -> void:
	for view in game_item_views.get_children():
		game_item_views.remove_child(view)
		view.queue_free()

	for game_item in battle.get_map().game_items():
		var view := Sprite2D.new()
		match game_item.type:
			GameItem.INCREASE_WATER_BALLOON_COUNT:
				view.texture = GAME_ITEM_WATER_BALLOON_TEXTURE
			GameItem.INCREASE_WATER_STREAM_LENGTH:
				view.texture = GAME_ITEM_WHITE_POTION_TEXTURE
			GameItem.INCREASE_SPEED:
				view.texture = GAME_ITEM_SPEED_TEXTURE
		view.scale = Vector2.ONE * (Map.PIXELS_PER_CELL / 64.0)
		view.position = Map.to_pixel(game_item.position) + Vector2(Map.PIXELS_PER_CELL / 2.0, Map.PIXELS_PER_CELL)
		view.offset = Vector2(-32, -96) # (-w/2, -h)
		view.centered = false
		game_item_views.add_child(view)

func _render_game_over_label() -> void:
	draw_label.visible = battle.is_draw
	if Team.colors(humans).size() == 1:
		win_label.visible = battle.has_winner() and battle.winner == humans[0].color
		lose_label.visible = battle.has_winner() and battle.winner != humans[0].color
		return
	win_label.visible = battle.has_winner()
	lose_label.visible = false
	if battle.has_winner():
		win_label.text = "1P WIN!!" if battle.winner == humans[0].color else "2P WIN!!"

func _read_move_direction() -> Vector2i:
	if pressed_move_keys.is_empty():
		return Vector2i.ZERO
	return Direction.from_key(pressed_move_keys.back())

func _read_move_direction_local_multi() -> Vector2i:
	if pressed_move_keys_local_multi.is_empty():
		return Vector2i.ZERO
	return Direction.from_key_local_multi(pressed_move_keys_local_multi.back())

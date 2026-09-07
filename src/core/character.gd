class_name Character
extends RefCounted

const SPEED := 4.0
const SPEED_IN_BUBBLE := 1.0
const WATER_BALLOON_COUNT := 1
const WATER_STREAM_LENGTH := 1
const FACING_DIRECTION := Vector2i.DOWN

# 스프라이트(64x96)를 offset(0,-32)로 그린 결과라 아트가 바뀌면 같이 바뀐다.
const FEET_FROM_ANCHOR := 0.5

# 갇힘 판정 거리. 물줄기 칸 중심에서 이만큼 떨어져 있어도 갇힌다.
const TRAP_REACH_BELOW := 0.8 # 물줄기가 캐릭터보다 아래
const TRAP_REACH_ABOVE := 0.2 # 물줄기가 캐릭터보다 위
const TRAP_REACH_SIDE := 0.35

# 갇힘 판정 상자. 스프라이트 전체가 아니라 발 위쪽 하반신만 담는다.
const TRAP_BOX_TOP := WaterStream.TRAP_REACH_EXPOSED - TRAP_REACH_ABOVE
const TRAP_BOX_BOTTOM := TRAP_REACH_BELOW - WaterStream.TRAP_REACH_EXPOSED
const TRAP_BOX_SIDE := TRAP_REACH_SIDE - WaterStream.TRAP_REACH_EXPOSED

var continuous_position: Vector2
var is_out: bool = false
var bubble: Bubble = null
var facing: Vector2i = FACING_DIRECTION
var number: int
var color: Color

var max_water_balloon_count := WATER_BALLOON_COUNT
var max_water_stream_length := WATER_STREAM_LENGTH
var speed := SPEED

var joined_room_id: String

func _init(start_position: Vector2i, seat_number: int = 0, team_color: Color = Color.RED) -> void:
	continuous_position = start_position
	number = seat_number
	color = team_color

func init_player() -> void:
	speed = Character.SPEED
	max_water_balloon_count = Character.WATER_BALLOON_COUNT
	max_water_stream_length = Character.WATER_STREAM_LENGTH
	bubble = null
	facing = Character.FACING_DIRECTION
	is_out = false

func move(direction: Vector2i, delta: float, water_balloon_positions: Array[Vector2i]) -> bool:
	if direction != Vector2i.ZERO:
		facing = direction

	var water_balloon_positions_except_character_position: Array[Vector2i] = []
	for cell in water_balloon_positions:
		if cell != position():
			water_balloon_positions_except_character_position.append(cell)
	
	var character_speed: float
	if is_trapped():
		character_speed = SPEED_IN_BUBBLE
	else:
		character_speed = speed
	var new_position := continuous_position + direction * character_speed * delta
	var clamped_position := new_position.clamp(Vector2i.ZERO, Map.GRID_SIZE - Vector2i.ONE)
	var cell := Vector2i(clamped_position.round())
	if water_balloon_positions_except_character_position.has(cell):
		return false
	continuous_position = clamped_position
	return true

func place_water_balloon(map: Map) -> bool:
	if is_trapped():
		return false
	if map.water_balloon_count_by_character(self) == max_water_balloon_count:
		return false
	var water_balloon := WaterBalloon.new(position(), self)
	return map.add_water_balloon(water_balloon)

func trapped() -> void:
	bubble = Bubble.new()

func rescued() -> void:
	bubble = null

func out() -> void:
	bubble = null
	is_out = true

func position() -> Vector2i:
	return Vector2i(continuous_position.round())

func pixel_position() -> Vector2:
	return continuous_position * Map.PIXELS_PER_CELL

func trap_box() -> Rect2:
	return Rect2(
		continuous_position + Vector2(-TRAP_BOX_SIDE, TRAP_BOX_TOP),
		Vector2(TRAP_BOX_SIDE * 2.0, TRAP_BOX_BOTTOM - TRAP_BOX_TOP)
	)

func is_trapped() -> bool:
	return bubble != null

func get_game_item(type: StringName) -> void:
	match type:
		GameItem.INCREASE_WATER_BALLOON_COUNT:
			max_water_balloon_count += 1
		GameItem.INCREASE_WATER_STREAM_LENGTH:
			max_water_stream_length += 1
		GameItem.INCREASE_SPEED:
			speed += 0.5

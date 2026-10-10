extends GdUnitTestSuite

# 맵 밖으로 이동 제한
func test_캐릭터는_위쪽_맵_밖으로_이동하지_못한다() -> void:
	var character := Character.new(Vector2i(1, 0))
	character.move(Vector2i.UP, 1.0, [])
	assert_vector(character.position()).is_equal(Vector2i(1, 0))

func test_캐릭터는_아래쪽_맵_밖으로_이동하지_못한다() -> void:
	var bottom_row := Map.GRID_SIZE.y - 1
	var character := Character.new(Vector2i(1, bottom_row))
	character.move(Vector2i.DOWN, 1.0, [])
	assert_vector(character.position()).is_equal(Vector2i(1, bottom_row))

func test_캐릭터는_왼쪽_맵_밖으로_이동하지_못한다() -> void:
	var character := Character.new(Vector2i(0, 1))
	character.move(Vector2i.LEFT, 1.0, [])
	assert_vector(character.position()).is_equal(Vector2i(0, 1))

func test_캐릭터는_오른쪽_맵_밖으로_이동하지_못한다() -> void:
	var right_column := Map.GRID_SIZE.x - 1
	var character := Character.new(Vector2i(right_column, 1))
	character.move(Vector2i.RIGHT, 1.0, [])
	assert_vector(character.position()).is_equal(Vector2i(right_column, 1))

# 물풍선 놓기
func test_캐릭터는_물풍선을_놓을_수_있다() -> void:
	var map := Map.new()
	var character := Character.new(Vector2i(1, 0))
	var is_placed := character.place_water_balloon(map)
	assert_bool(is_placed).is_true()

func test_캐릭터는_물풍선이_있는_칸에_또_물풍선을_놓을_수_없다() -> void:
	var map := Map.new()
	var character := Character.new(Vector2i(1, 0))
	character.place_water_balloon(map)
	var is_placed := character.place_water_balloon(map)
	assert_bool(is_placed).is_false()

# 물방울에 갇힘
func test_물줄기가_있는_동안에_캐릭터가_물줄기_위치에_있으면_물방울에_갇힌다() -> void:
	var map := Map.new()
	var water_stream := WaterStream.new(Vector2i(3, 4), Vector2i.ZERO, "center")
	map.add_water_stream(water_stream)
	var character := Character.new(Vector2i(3, 4))
	map.add_character(character)
	map.tick(WaterStream.DURATION * 0.5)
	assert_bool(character.is_trapped()).is_true()

func test_물줄기가_있는_동안에_캐릭터가_물줄기_위치에_있지_않으면_물방울에_갇히지_않는다() -> void:
	var map := Map.new()
	var water_stream := WaterStream.new(Vector2i(3, 4), Vector2i.ZERO, "center")
	map.add_water_stream(water_stream)
	var character := Character.new(Vector2i(2, 3))
	map.add_character(character)
	map.tick(WaterStream.DURATION * 0.5)
	assert_bool(character.is_trapped()).is_false()

func test_물줄기가_있는_동안에_캐릭터가_이전_물줄기_위치로_이동하면_물방울에_갇힌다() -> void:
	var map := Map.new()
	map.add_water_streams(Vector2i(2, 3), 1)
	var character := Character.new(Vector2i(1, 2))
	map.add_character(character)
	map.tick(WaterStream.DURATION * 0.5)
	character.move(Vector2i.RIGHT, 0.25, [])
	map.tick(WaterStream.DURATION * 0.1)
	assert_bool(character.is_trapped()).is_true()

func test_물줄기가_사라진_후에_캐릭터가_이전_물줄기_위치로_이동하면_물방울에_갇히지_않는다() -> void:
	var map := Map.new()
	var water_stream := WaterStream.new(Vector2i(2, 3), Vector2i.ZERO, "center")
	map.add_water_stream(water_stream)
	var character := Character.new(Vector2i(1, 2))
	map.add_character(character)
	map.tick(WaterStream.DURATION * 1.5)
	character.move(Vector2i.RIGHT, 0.25, [])
	map.tick(0.1)
	assert_bool(character.is_trapped()).is_false()

func test_물방울에_갇힌_상태의_캐릭터는_물풍선을_놓을_수_없다() -> void:
	var map := Map.new()
	var character := Character.new(Vector2i(1, 5))
	character.max_water_balloon_count = 2
	map.add_character(character)
	assert_bool(character.place_water_balloon(map)).is_true()
	character.trapped()
	character.move(Vector2i.DOWN, 0.25, map.water_balloon_positions())
	map.tick(0.25)
	assert_bool(character.place_water_balloon(map)).is_false()

func test_물방울에_갇힌_상태의_캐릭터는_이동_속도가_느려진다() -> void:
	var map := Map.new()
	var character := Character.new(Vector2i(1, 5))
	map.add_character(character)
	assert_vector(character.position()).is_equal(Vector2i(1, 5))
	character.move(Vector2i.RIGHT, 0.25, map.water_balloon_positions())
	assert_vector(character.position()).is_equal(Vector2i(2, 5))
	character.trapped()
	character.move(Vector2i.RIGHT, 0.25, map.water_balloon_positions())
	assert_vector(character.position()).is_not_equal(Vector2i(3, 5))

# 자동 아웃
func test_캐릭터가_물방울에_갇히고_일정_시간이_지나면_자동_아웃된다() -> void:
	var map := Map.new()
	var water_stream := WaterStream.new(Vector2i(2, 3), Vector2i.ZERO, "center")
	map.add_water_stream(water_stream)
	var character := Character.new(Vector2i(2, 3))
	map.add_character(character)
	map.tick(WaterStream.DURATION * 0.5)
	assert_bool(character.is_out).is_false()
	map.tick(WaterStream.DURATION * 0.5)
	assert_bool(character.is_out).is_false()
	map.tick(Bubble.ALIVE_SECONDS * 0.5)
	assert_bool(character.is_out).is_false()
	map.tick(Bubble.ALIVE_SECONDS * 1.5)
	assert_bool(character.is_out).is_true()

# 걸치기
func test_캐릭터는_격자_사이를_걸쳐서_움직일_수_있다() -> void:
	var character := Character.new(Vector2i(3, 2))
	character.move(Vector2i.RIGHT, 0.1, [])
	assert_bool(character.position() != Vector2i(4, 2)).is_true()

func test_캐릭터의_격자_위치는_연속된_위치로부터_파생한다() -> void:
	var character := Character.new(Vector2i(3, 2))
	character.move(Vector2i.RIGHT, 0.15, [])
	assert_vector(character.position()).is_equal(Vector2i(4, 2))

func test_캐릭터는_칸에_걸쳐져_있는_상태에서_물줄기를_맞으면_물방울에_갇히지_않는다() -> void:
	var map := Map.new()
	var character := Character.new(Vector2i(3, 4))
	map.add_character(character)
	character.place_water_balloon(map)
	character.move(Vector2i.DOWN, 0.25, map.water_balloon_positions())
	character.move(Vector2i.LEFT, 0.125, map.water_balloon_positions())
	map.tick(WaterBalloon.POP_AFTER_SECONDS * 1.5)
	assert_bool(character.is_trapped()).is_false()

# 물방울에 갇힘
func test_갇힘_판정_상자는_앵커와_발_사이에_있다() -> void:
	assert_bool(Character.TRAP_BOX_TOP >= 0.0).is_true()
	assert_bool(Character.TRAP_BOX_TOP < Character.TRAP_BOX_BOTTOM).is_true()
	assert_bool(Character.TRAP_BOX_BOTTOM <= Character.FEET_FROM_ANCHOR).is_true()
	assert_bool(Character.TRAP_BOX_SIDE > 0.0).is_true()

# 가두기
func test_캐릭터는_다른_칸에_있는_물풍선_위치로_이동할_수_없다() -> void:
	var map := Map.new()
	var character := Character.new(Vector2i(3, 4))
	var water_balloon := WaterBalloon.new(Vector2i(4, 4), character)
	map.add_character(character)
	map.add_water_balloon(water_balloon)
	assert_bool(character.move(Vector2i.RIGHT, 0.25, map.water_balloon_positions())).is_false()

func test_캐릭터는_물풍선이_없는_칸으로_이동할_수_있다() -> void:
	var map := Map.new()
	var character := Character.new(Vector2i(3, 4))
	var water_balloon := WaterBalloon.new(Vector2i(3, 3), character)
	map.add_character(character)
	map.add_water_balloon(water_balloon)
	assert_bool(character.move(Vector2i.RIGHT, 0.25, map.water_balloon_positions())).is_true()

func test_캐릭터는_물풍선을_놓고_나서_바로_이동할_수_있다() -> void:
	var map := Map.new()
	var character := Character.new(Vector2i(3, 4))
	map.add_character(character)
	character.place_water_balloon(map)
	assert_bool(character.move(Vector2i.RIGHT, 0.1, map.water_balloon_positions())).is_true()

# 게임 아이템
func test_캐릭터는_기본적으로_물풍선_하나밖에_놓지_못한다() -> void:
	var map := Map.new()
	var character := Character.new(Vector2i(3, 4))
	map.add_character(character)
	assert_bool(character.place_water_balloon(map)).is_true()
	character.move(Vector2i.RIGHT, 0.25, map.water_balloon_positions())
	assert_bool(character.place_water_balloon(map)).is_false()

func test_캐릭터는_물풍선_아이템을_먹으면_물풍선을_하나_더_놓을_수_있다() -> void:
	var map := Map.new()
	var character := Character.new(Vector2i(3, 4))
	map.add_character(character)
	assert_bool(character.place_water_balloon(map)).is_true()
	character.move(Vector2i.RIGHT, 0.25, map.water_balloon_positions())
	assert_bool(character.place_water_balloon(map)).is_false()
	character.get_game_item(GameItem.INCREASE_WATER_BALLOON_COUNT)
	assert_bool(character.place_water_balloon(map)).is_true()
	assert_bool(character.place_water_balloon(map)).is_false()

func test_캐릭터가_게임_아이템의_위치에_있으면_아이템을_먹을_수_있다() -> void:
	var map := Map.new()
	var character := Character.new(Vector2i(5, 1))
	map.add_character(character)
	assert_int(character.max_water_balloon_count).is_equal(1)
	map.add_game_item(GameItem.INCREASE_WATER_BALLOON_COUNT, Vector2i(5, 2))
	character.move(Vector2i.DOWN, 0.25, map.water_balloon_positions())
	map.tick(0.25)
	assert_int(character.max_water_balloon_count).is_equal(2)

func test_캐릭터는_물방울에_갇힌_상태에서는_게임_아이템을_먹을_수_없다() -> void:
	var map := Map.new()
	var character := Character.new(Vector2i(3, 4))
	map.add_character(character)
	character.trapped()
	assert_int(character.max_water_balloon_count).is_equal(1)
	map.add_game_item(GameItem.INCREASE_WATER_BALLOON_COUNT, Vector2i(4, 4))
	character.move(Vector2i.RIGHT, 0.25, map.water_balloon_positions())
	map.tick(0.25)
	assert_int(character.max_water_balloon_count).is_equal(1)

func test_캐릭터가_물줄기_아이템을_먹으면_물줄기가_한_칸_증가한다() -> void:
	var map := Map.new()
	var character := Character.new(Vector2i(3, 4))
	map.add_character(character)
	assert_int(character.max_water_stream_length).is_equal(1)
	character.get_game_item(GameItem.INCREASE_WATER_STREAM_LENGTH)
	assert_int(character.max_water_stream_length).is_equal(2)

func test_캐릭터가_스피드_아이템을_먹으면_스피드가_증가한다() -> void:
	var map := Map.new()
	var character := Character.new(Vector2i(3, 4))
	map.add_character(character)
	assert_float(character.speed).is_equal(4.0)
	character.get_game_item(GameItem.INCREASE_SPEED)
	assert_float(character.speed).is_equal(4.5)

func test_캐릭터가_물방울에_갇혔다가_풀려나면_원래의_스피드로_돌아온다() -> void:
	var map := Map.new()
	var character := Character.new(Vector2i(3, 4))
	map.add_character(character)
	character.move(Vector2i.RIGHT, 0.25, map.water_balloon_positions())
	assert_vector(character.position()).is_equal(Vector2i(4, 4))
	character.trapped()
	character.move(Vector2i.RIGHT, 0.25, map.water_balloon_positions())
	var position := Vector2(4, 4) + Vector2.RIGHT * Character.SPEED_IN_BUBBLE * 0.25
	assert_vector(character.continuous_position).is_equal(position)
	character.rescued()
	character.move(Vector2i.RIGHT, 0.25, map.water_balloon_positions())
	assert_vector(character.continuous_position).is_equal(position + Vector2.RIGHT * character.speed * 0.25)

# 얼굴 방향
func test_캐릭터가_위쪽으로_이동하면_얼굴_방향이_위쪽이_된다() -> void:
	var map := Map.new()
	var character := Character.new(Vector2i(3, 4))
	map.add_character(character)
	character.move(Vector2i.UP, 0.25, map.water_balloon_positions())
	assert_vector(character.facing).is_equal(Vector2i.UP)

func test_캐릭터가_아래쪽으로_이동하면_얼굴_방향이_아래쪽이_된다() -> void:
	var map := Map.new()
	var character := Character.new(Vector2i(3, 4))
	map.add_character(character)
	character.move(Vector2i.DOWN, 0.25, map.water_balloon_positions())
	assert_vector(character.facing).is_equal(Vector2i.DOWN)

func test_캐릭터가_왼쪽으로_이동하면_얼굴_방향이_왼쪽이_된다() -> void:
	var map := Map.new()
	var character := Character.new(Vector2i(3, 4))
	map.add_character(character)
	character.move(Vector2i.LEFT, 0.25, map.water_balloon_positions())
	assert_vector(character.facing).is_equal(Vector2i.LEFT)

func test_캐릭터가_오른쪽으로_이동하면_얼굴_방향이_오른쪽이_된다() -> void:
	var map := Map.new()
	var character := Character.new(Vector2i(3, 4))
	map.add_character(character)
	character.move(Vector2i.RIGHT, 0.25, map.water_balloon_positions())
	assert_vector(character.facing).is_equal(Vector2i.RIGHT)

func test_캐릭터의_이동_방향이_영벡터면_얼굴_방향을_바꾸지_않는다() -> void:
	var map := Map.new()
	var character := Character.new(Vector2i(3, 4))
	map.add_character(character)
	character.move(Vector2i.RIGHT, 0.25, map.water_balloon_positions())
	assert_vector(character.facing).is_equal(Vector2i.RIGHT)
	character.move(Vector2i.ZERO, 0.25, map.water_balloon_positions())
	assert_vector(character.facing).is_equal(Vector2i.RIGHT)

# 상대방 아웃
func test_인간_캐릭터는_물방울에_갇힌_NPC의_위치로_이동하면_NPC를_아웃시킬_수_있다() -> void:
	var map := Map.new()
	var human := Character.new(Vector2i(5, 1))
	var npc := Npc.new(Vector2i(5, 2), 0, Color.BLUE)
	map.add_character(human)
	map.add_character(npc)
	npc.trapped()
	assert_bool(npc.is_out).is_false()
	human.move(Vector2i.DOWN, 0.25, map.water_balloon_positions())
	map.tick(0.25)
	assert_bool(npc.is_out).is_true()

func test_NPC는_물방울에_갇힌_인간_캐릭터의_위치로_이동하면_인간_캐릭터를_아웃시킬_수_있다() -> void:
	var map := Map.new()
	var human := Character.new(Vector2i(5, 1))
	var npc := Npc.new(Vector2i(5, 2), 0, Color.BLUE)
	map.add_character(human)
	map.add_character(npc)
	human.trapped()
	assert_bool(human.is_out).is_false()
	npc.move(Vector2i.UP, 0.25, map.water_balloon_positions())
	map.tick(0.25)
	assert_bool(human.is_out).is_true()

# 방
func test_캐릭터는_방_ID_로_방에_입장할_수_있다() -> void:
	var room := Room.new()
	var character := Character.new(Vector2i(1, 2))
	room.add_character(character)
	assert_str(character.joined_room_id).is_equal(room.id)

# 색상
func test_캐릭터는_자신의_색상을_변경할_수_있다() -> void:
	var character := Character.new(Vector2i.ZERO, 0, Color.ORANGE)
	assert_that(character.color).is_equal(Color.ORANGE)
	character.color = Color.GREEN
	assert_that(character.color).is_equal(Color.GREEN)

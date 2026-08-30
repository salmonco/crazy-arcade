extends GdUnitTestSuite

var _map: Map

func before_test() -> void:
	_map = Map.new()

func test_그리드를_픽셀로_변환한다() -> void:
	var grid := Vector2i(2, 3)
	assert_vector(Map.to_pixel(grid)).is_equal(Vector2(2 * Map.PIXELS_PER_CELL, 3 * Map.PIXELS_PER_CELL))

func test_그리드가_원점이면_픽셀도_원점을_반환한다() -> void:
	var grid := Vector2i.ZERO
	assert_vector(Map.to_pixel(grid)).is_equal(Vector2.ZERO)

# 물풍선 놓기
func test_캐릭터가_물풍선을_놓으면_맵에_물풍선이_생긴다() -> void:
	var character := Character.new(Vector2i(1, 0))
	character.place_water_balloon(_map)
	assert_bool(_map.has_water_balloon(Vector2i(1, 0))).is_true()

func test_캐릭터가_물풍선이_있는_칸에_또_물풍선을_놓으면_기존_물풍선을_유지한다() -> void:
	var character := Character.new(Vector2i(1, 0))
	character.place_water_balloon(_map)
	character.place_water_balloon(_map)
	assert_int(_map.water_balloon_count()).is_equal(1)

# 물풍선 터지기
func test_터진_물풍선은_맵에서_사라진다() -> void:
	var character := Character.new(Vector2i(1, 0))
	var water_balloon := WaterBalloon.new(Vector2i(4, 2), character)
	_map.add_water_balloon(water_balloon)
	assert_int(_map.water_balloon_count()).is_equal(1)
	_map.tick(4.0)
	assert_int(_map.water_balloon_count()).is_equal(0)

func test_물풍선_중에_안_터진_물풍선은_맵에_남아있다() -> void:
	var character := Character.new(Vector2i(1, 0))
	var old_balloon := WaterBalloon.new(Vector2i(4, 2), character)
	_map.add_water_balloon(old_balloon)
	_map.tick(2.0)
	var new_balloon := WaterBalloon.new(Vector2i(5, 7), character)
	_map.add_water_balloon(new_balloon)
	_map.tick(2.0)
	assert_bool(_map.has_water_balloon(Vector2i(4, 2))).is_false()
	assert_bool(_map.has_water_balloon(Vector2i(5, 7))).is_true()

func test_같은_칸에_물풍선을_다시_놓아도_먼저_놓인_물풍선의_시간은_리셋되지_않는다() -> void:
	var character := Character.new(Vector2i(1, 0))
	var old_balloon := WaterBalloon.new(Vector2i(4, 2), character)
	_map.add_water_balloon(old_balloon)
	_map.tick(2.0)
	var new_balloon := WaterBalloon.new(Vector2i(4, 2), character)
	_map.add_water_balloon(new_balloon)
	_map.tick(2.0)
	assert_bool(_map.has_water_balloon(Vector2i(4, 2))).is_false()

# 물줄기 생김
func test_물풍선이_터지면_물줄기가_생긴다() -> void:
	var character := Character.new(Vector2i(1, 0))
	var water_balloon := WaterBalloon.new(Vector2i(4, 2), character)
	_map.add_water_balloon(water_balloon)
	_map.tick(WaterBalloon.POP_AFTER_SECONDS)
	assert_bool(_map.has_water_stream(Vector2i(4, 2))).is_true()

func test_물풍선은_터지고_나서_제_수명만큼_유지된다() -> void:
	var character := Character.new(Vector2i(1, 0))
	var water_balloon := WaterBalloon.new(Vector2i(4, 2), character)
	_map.add_water_balloon(water_balloon)
	_map.tick(WaterBalloon.POP_AFTER_SECONDS)
	_map.tick(WaterStream.DURATION * 0.4)
	_map.tick(WaterStream.DURATION * 0.4)
	assert_bool(_map.has_water_stream(Vector2i(4, 2))).is_true()

func test_물풍선이_터질_때만_물줄기가_생긴다() -> void:
	var character := Character.new(Vector2i(1, 0))
	var water_balloon := WaterBalloon.new(Vector2i(4, 2), character)
	_map.add_water_balloon(water_balloon)
	_map.tick(WaterBalloon.POP_AFTER_SECONDS)
	assert_bool(_map.has_water_stream(Vector2i(4, 2))).is_true()
	_map.tick(WaterBalloon.POP_AFTER_SECONDS)
	assert_bool(_map.has_water_stream(Vector2i(4, 2))).is_false()

func test_물풍선_여러_개를_놓으면_터진_물풍선에만_물줄기가_생긴다() -> void:
	var character := Character.new(Vector2i(1, 0))
	var old_balloon := WaterBalloon.new(Vector2i(4, 2), character)
	_map.add_water_balloon(old_balloon)
	_map.tick(WaterBalloon.POP_AFTER_SECONDS)
	var new_balloon := WaterBalloon.new(Vector2i(6, 8), character)
	_map.add_water_balloon(new_balloon)
	assert_bool(_map.has_water_stream(Vector2i(4, 2))).is_true()
	assert_bool(_map.has_water_stream(Vector2i(6, 8))).is_false()

func test_물풍선이_터지면_물줄기가_중앙과_상하좌우로_한_칸씩_생긴다() -> void:
	var character := Character.new(Vector2i(1, 0))
	var water_balloon := WaterBalloon.new(Vector2i(4, 2), character)
	_map.add_water_balloon(water_balloon)
	_map.tick(WaterBalloon.POP_AFTER_SECONDS)
	assert_array(_map.water_stream_positions()).contains_exactly([Vector2i(4, 2), Vector2i(4, 1), Vector2i(4, 3), Vector2i(3, 2), Vector2i(5, 2)])

# 물방울에 갇힘
func test_캐릭터가_물방울에_갇혀도_맵에_남아있다() -> void:
	var water_stream := WaterStream.new(Vector2i(4, 2), Vector2i.ZERO, "center")
	var character := Character.new(Vector2i(4, 2))
	_map.add_water_stream(water_stream)
	_map.add_character(character)
	_map.tick(0.1)
	assert_bool(_map.has_character(Vector2i(4, 2))).is_true()

func test_물방울에_갇힌_상태의_캐릭터가_물풍선을_놓아도_맵에_물풍선이_추가되지_않는다() -> void:
	var character := Character.new(Vector2i(1, 5))
	character.max_water_balloon_count = 2
	_map.add_character(character)
	character.place_water_balloon(_map)
	assert_int(_map.water_balloon_count()).is_equal(1)
	character.trapped()
	character.move(Vector2i.DOWN, 0.25, _map.water_balloon_positions())
	_map.tick(0.25)
	character.place_water_balloon(_map)
	assert_int(_map.water_balloon_count()).is_equal(1)

func test_가로_물줄기_위에서_x축만_두_칸에_걸쳐_있으면_물방울에_갇힌다() -> void:
	var placer := Character.new(Vector2i(4, 2))
	_map.add_water_balloon(WaterBalloon.new(Vector2i(4, 2), placer))
	var victim := Character.new(Vector2i(3, 2))
	victim.continuous_position = Vector2(3.47, 2.0)
	_map.add_character(victim)
	_map.tick(WaterBalloon.POP_AFTER_SECONDS)
	_map.tick(0.1)
	assert_bool(victim.is_trapped()).is_true()

func test_물줄기_위에서_x축과_y축_모두_두_칸에_걸쳐_있으면_물방울에_갇히지_않는다() -> void:
	var placer := Character.new(Vector2i(4, 2))
	_map.add_water_balloon(WaterBalloon.new(Vector2i(4, 2), placer))
	var victim := Character.new(Vector2i(3, 2))
	victim.continuous_position = Vector2(3.47, 2.47)
	_map.add_character(victim)
	_map.tick(WaterBalloon.POP_AFTER_SECONDS)
	_map.tick(0.1)
	assert_bool(victim.is_trapped()).is_false()

func test_캐릭터의_발이_아래_칸_물줄기에_들어가면_물방울에_갇힌다() -> void:
	var character := Character.new(Vector2i(3, 5))
	character.continuous_position = Vector2(3.0, 5.3)
	_map.add_character(character)
	_map.add_water_stream(WaterStream.new(Vector2i(3, 6), Vector2i.LEFT, "end"))
	_map.tick(0.1)
	assert_bool(character.is_trapped()).is_true()

func test_캐릭터의_머리만_위_칸_물줄기에_닿으면_물방울에_갇히지_않는다() -> void:
	var character := Character.new(Vector2i(3, 5))
	character.continuous_position = Vector2(3.0, 4.7)
	_map.add_character(character)
	_map.add_water_stream(WaterStream.new(Vector2i(3, 4), Vector2i.LEFT, "end"))
	_map.tick(0.1)
	assert_bool(character.is_trapped()).is_false()

func test_물줄기가_아래로_0_75칸_떨어져_있으면_물방울에_갇힌다() -> void:
	var character := Character.new(Vector2i(3, 5))
	character.continuous_position = Vector2(3.0, 5.25)
	_map.add_character(character)
	_map.add_water_stream(WaterStream.new(Vector2i(3, 6), Vector2i.LEFT, "end"))
	_map.tick(0.1)
	assert_bool(character.is_trapped()).is_true()

func test_물줄기가_아래로_0_9칸_떨어져_있으면_물방울에_갇히지_않는다() -> void:
	var character := Character.new(Vector2i(3, 5))
	character.continuous_position = Vector2(3.0, 5.1)
	_map.add_character(character)
	_map.add_water_stream(WaterStream.new(Vector2i(3, 6), Vector2i.LEFT, "end"))
	_map.tick(0.1)
	assert_bool(character.is_trapped()).is_false()

func test_물줄기가_위로_0_1칸_떨어져_있으면_물방울에_갇힌다() -> void:
	var character := Character.new(Vector2i(3, 4))
	character.continuous_position = Vector2(3.0, 4.1)
	_map.add_character(character)
	_map.add_water_stream(WaterStream.new(Vector2i(3, 4), Vector2i.LEFT, "end"))
	_map.tick(0.1)
	assert_bool(character.is_trapped()).is_true()

func test_물줄기가_위로_0_3칸_떨어져_있으면_물방울에_갇히지_않는다() -> void:
	var character := Character.new(Vector2i(3, 4))
	character.continuous_position = Vector2(3.0, 4.3)
	_map.add_character(character)
	_map.add_water_stream(WaterStream.new(Vector2i(3, 4), Vector2i.LEFT, "end"))
	_map.tick(0.1)
	assert_bool(character.is_trapped()).is_false()

func test_물줄기가_옆으로_0_25칸_떨어져_있으면_물방울에_갇힌다() -> void:
	var character := Character.new(Vector2i(3, 6))
	character.continuous_position = Vector2(2.75, 5.6)
	_map.add_character(character)
	_map.add_water_stream(WaterStream.new(Vector2i(3, 6), Vector2i.DOWN, "end"))
	_map.tick(0.1)
	assert_bool(character.is_trapped()).is_true()

func test_물줄기가_옆으로_0_45칸_떨어져_있으면_물방울에_갇히지_않는다() -> void:
	var character := Character.new(Vector2i(3, 6))
	character.continuous_position = Vector2(2.55, 5.6)
	_map.add_character(character)
	_map.add_water_stream(WaterStream.new(Vector2i(3, 6), Vector2i.DOWN, "end"))
	_map.tick(0.1)
	assert_bool(character.is_trapped()).is_false()

# 자동 아웃
func test_캐릭터가_물방울에_갇힌_후_일정_시간이_지나면_자동_아웃되어_맵에서_사라진다() -> void:
	var water_stream := WaterStream.new(Vector2i(4, 2), Vector2i.ZERO, "center")
	var character := Character.new(Vector2i(4, 2))
	_map.add_water_stream(water_stream)
	_map.add_character(character)
	_map.tick(WaterStream.DURATION * 0.5)
	assert_bool(_map.has_character(Vector2i(4, 2))).is_true()
	_map.tick(Bubble.ALIVE_SECONDS * 1.5)
	assert_bool(_map.has_character(Vector2i(4, 2))).is_false()

# 물줄기 전파
func test_물풍선이_물줄기_위치에_있으면_같이_터진다() -> void:
	var character := Character.new(Vector2i(1, 0))
	var water_balloon := WaterBalloon.new(Vector2i(4, 2), character)
	var water_stream := WaterStream.new(Vector2i(4, 2), Vector2i.ZERO, "center")
	_map.add_water_balloon(water_balloon)
	_map.add_water_stream(water_stream)
	_map.tick(WaterStream.DURATION * 0.1)
	assert_bool(_map.has_water_balloon(Vector2i(4, 2))).is_false()

func test_물줄기에_맞아_같이_터진_물풍선에도_물줄기가_생긴다() -> void:
	var character := Character.new(Vector2i(1, 0))
	var water_balloon := WaterBalloon.new(Vector2i(4, 2), character)
	_map.add_water_balloon(water_balloon)
	_map.add_water_streams(Vector2i(5, 2), 1)
	_map.tick(WaterStream.DURATION * 0.1)
	assert_array(_map.water_stream_positions()).contains(
		[Vector2i(4, 2), Vector2i(4, 1), Vector2i(4, 3), Vector2i(3, 2), Vector2i(5, 2)
		,Vector2i(5, 1), Vector2i(5, 3), Vector2i(6, 2)])

func test_물풍선_하나가_터지면_물줄기_위치에_있는_물풍선도_같이_터진다() -> void:
	var character := Character.new(Vector2i(1, 0))
	var water_balloon1 := WaterBalloon.new(Vector2i(4, 2), character)
	_map.add_water_balloon(water_balloon1)
	_map.tick(WaterBalloon.POP_AFTER_SECONDS * 0.5)
	var water_balloon2 := WaterBalloon.new(Vector2i(5, 2), character)
	_map.add_water_balloon(water_balloon2)
	_map.tick(WaterBalloon.POP_AFTER_SECONDS * 0.5)
	assert_array(_map.water_stream_positions()).contains(
		[Vector2i(4, 2), Vector2i(4, 1), Vector2i(4, 3), Vector2i(3, 2), Vector2i(5, 2)
		,Vector2i(5, 1), Vector2i(5, 3), Vector2i(6, 2)])

func test_물줄기에_의해_같이_터진_물풍선의_물줄기_지속_시간은_인접한_물줄기의_지속_시간과_동일하다() -> void:
	var character := Character.new(Vector2i(1, 0))
	_map.add_water_streams(Vector2i(4, 2), 1)
	_map.tick(WaterStream.DURATION * 0.5)
	var water_balloon := WaterBalloon.new(Vector2i(5, 2), character)
	_map.add_water_balloon(water_balloon)
	_map.tick(WaterStream.DURATION * 0.3)
	assert_bool(_map.has_water_stream(Vector2i(4, 2))).is_true()
	assert_bool(_map.has_water_stream(Vector2i(5, 3))).is_true()
	_map.tick(WaterStream.DURATION * 0.5)
	assert_bool(_map.has_water_stream(Vector2i(4, 2))).is_false()
	assert_bool(_map.has_water_stream(Vector2i(5, 3))).is_false()

# 게임 아이템
func test_맵의_특정_위치에_게임_아이템을_배치할_수_있다() -> void:
	assert_bool(_map.add_game_item(GameItem.INCREASE_WATER_BALLOON_COUNT, Vector2i(3, 2))).is_true()

func test_게임_아이템은_맵의_중복된_위치에_배치할_수_없다() -> void:
	assert_bool(_map.add_game_item(GameItem.INCREASE_WATER_BALLOON_COUNT, Vector2i(3, 2))).is_true()
	assert_bool(_map.add_game_item(GameItem.INCREASE_WATER_BALLOON_COUNT, Vector2i(3, 2))).is_false()

func test_게임_아이템은_물줄기를_맞으면_제거된다() -> void:
	_map.add_game_item(GameItem.INCREASE_WATER_BALLOON_COUNT, Vector2i(5, 2))
	assert_bool(_map.has_game_item(Vector2i(5, 2))).is_true()
	_map.add_water_streams(Vector2i(6, 2), 1)
	_map.tick(0.1)
	assert_bool(_map.has_game_item(Vector2i(5, 2))).is_false()

func test_캐릭터가_게임_아이템_위치로_이동하면_아이템이_먹혀_맵에서_사라진다() -> void:
	var character := Character.new(Vector2i(4, 7))
	_map.add_character(character)
	_map.add_game_item(GameItem.INCREASE_WATER_BALLOON_COUNT, Vector2i(4, 8))
	assert_bool(_map.has_game_item(Vector2i(4, 8))).is_true()
	character.move(Vector2i.DOWN, 0.25, _map.water_balloon_positions())
	_map.tick(0.25)
	assert_bool(_map.has_game_item(Vector2i(4, 8))).is_false()

func test_물방울에_갇힌_캐릭터가_게임_아이템_위치로_이동하면_아이템이_사라지지_않는다() -> void:
	var character := Character.new(Vector2i(4, 7))
	_map.add_character(character)
	_map.add_game_item(GameItem.INCREASE_WATER_BALLOON_COUNT, Vector2i(4, 8))
	assert_bool(_map.has_game_item(Vector2i(4, 8))).is_true()
	character.trapped()
	character.move(Vector2i.DOWN, 0.25, _map.water_balloon_positions())
	_map.tick(0.25)
	assert_bool(_map.has_game_item(Vector2i(4, 8))).is_true()

func test_캐릭터가_물줄기_아이템을_먹고_물풍선을_놓으면_맵에서_물줄기가_한_칸_늘어난다() -> void:
	var character := Character.new(Vector2i(2, 3))
	_map.add_character(character)
	_map.add_game_item(GameItem.INCREASE_WATER_STREAM_LENGTH, Vector2i(2, 3))
	_map.tick(0.1)
	character.place_water_balloon(_map)
	_map.tick(WaterBalloon.POP_AFTER_SECONDS)
	_map.tick(WaterStream.DURATION * 0.5)
	assert_bool(_map.has_water_stream(Vector2i(3, 3))).is_true()
	assert_bool(_map.has_water_stream(Vector2i(4, 3))).is_true()
	assert_bool(_map.has_water_stream(Vector2i(5, 3))).is_false()

# 상대방 아웃
func test_캐릭터는_물방울에_갇혀_있는_상대_팀의_캐릭터를_아웃시킬_수_있다() -> void:
	var character1 := Character.new(Vector2i(3, 4), 1, Color.RED)
	var character2 := Character.new(Vector2i(2, 3), 2, Color.BLUE)
	_map.add_character(character1)
	_map.add_character(character2)
	_map.add_water_streams(Vector2i(2, 3), 1)
	_map.tick(WaterStream.DURATION * 0.5)
	assert_bool(character2.is_trapped()).is_true()
	assert_bool(character2.is_out).is_false()
	assert_bool(_map.has_character(Vector2i(2, 3))).is_true()
	_map.tick(WaterStream.DURATION * 1.5)
	character1.move(Vector2i.UP, 0.25, _map.water_balloon_positions())
	character1.move(Vector2i.LEFT, 0.25, _map.water_balloon_positions())
	_map.tick(0.1)
	assert_bool(character2.is_trapped()).is_false()
	assert_bool(character2.is_out).is_true()
	assert_bool(_map.has_character(Vector2i(2, 3))).is_true()
	character1.move(Vector2i.RIGHT, 0.25, _map.water_balloon_positions())
	character1.move(Vector2i.DOWN, 0.25, _map.water_balloon_positions())
	_map.tick(0.1)
	assert_bool(character2.is_trapped()).is_false()
	assert_bool(character2.is_out).is_true()
	assert_bool(_map.has_character(Vector2i(2, 3))).is_false()

# 같은 팀 물방울 구출
func test_캐릭터는_물방울에_갇혀_있는_같은_팀의_캐릭터를_구출할_수_있다() -> void:
	var character1 := Character.new(Vector2i(3, 4), 1, Color.RED)
	var character2 := Character.new(Vector2i(2, 3), 2, Color.BLUE)
	_map.add_character(character1)
	_map.add_character(character2)
	_map.add_water_streams(Vector2i(2, 3), 1)
	_map.tick(WaterStream.DURATION * 0.5)
	assert_bool(character2.is_trapped()).is_true()
	assert_bool(character1.is_trapped()).is_false()
	_map.tick(WaterStream.DURATION)
	assert_bool(character2.is_trapped()).is_true()
	assert_bool(character1.is_trapped()).is_false()
	character1.move(Vector2i.LEFT, 0.25, _map.water_balloon_positions())
	character1.move(Vector2i.UP, 0.25, _map.water_balloon_positions())
	_map.tick(Bubble.ALIVE_SECONDS * 0.5)
	assert_bool(character2.is_trapped()).is_false()
	assert_bool(character1.is_trapped()).is_false()
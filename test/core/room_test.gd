extends GdUnitTestSuite

func test_방에서_게임을_시작하면_방에_있는_캐릭터가_맵에_추가된다() -> void:
	var room := Room.new()
	var character := Character.new(Vector2i(1, 2))
	room.add_character(character)
	room.game_start()
	assert_array(room.get_battle().get_map().characters()).is_equal([character])

func test_방에_들어온_순서대로_자리_번호를_받는다() -> void:
	var room := Room.new()
	var first := Character.new(Vector2i(1, 2), 7, Color.RED)
	var second := Character.new(Vector2i(3, 5), 7, Color.BLUE)
	room.add_character(first)
	room.add_character(second)
	assert_int(first.number).is_equal(1)
	assert_int(second.number).is_equal(2)

func test_가운데_자리가_비면_새로_들어온_캐릭터가_그_자리를_받는다() -> void:
	var room := Room.new()
	var first := Character.new(Vector2i(1, 2))
	var second := Character.new(Vector2i(3, 5))
	var third := Character.new(Vector2i(4, 7))
	room.add_character(first)
	room.add_character(second)
	room.add_character(third)
	room.remove_character(second)
	var joined := Character.new(Vector2i(6, 9))
	room.add_character(joined)
	assert_int(joined.number).is_equal(2)

func test_방에서_캐릭터가_나가면_그_캐릭터만_빠진다() -> void:
	var room := Room.new()
	var leaving := Character.new(Vector2i(1, 2))
	var staying := Character.new(Vector2i(3, 5))
	room.add_character(leaving)
	room.add_character(staying)
	room.remove_character(leaving)
	assert_array(room.characters()).is_equal([staying])

func test_방에서_나간_캐릭터는_방에_속하지_않는다() -> void:
	var room := Room.new()
	var character := Character.new(Vector2i(1, 2))
	room.add_character(character)
	room.remove_character(character)
	assert_str(character.joined_room_id).is_not_equal(room.id)

func test_게임을_시작하면_자리_번호에_맞는_칸에서_시작한다() -> void:
	var room := Room.new()
	var first := Character.new(Vector2i(9, 9))
	var second := Character.new(Vector2i(9, 9))
	room.add_character(first)
	room.add_character(second)
	room.game_start()
	assert_vector(first.position()).is_equal(Vector2i(1, 6))
	assert_vector(second.position()).is_equal(Vector2i(13, 6))

func test_방에서_배틀_모드를_변경할_수_있다() -> void:
	var room := Room.new()
	room.set_battle_mode(BattleMode.MONSTER)
	assert_str(room.battle_mode).is_equal(BattleMode.MONSTER)

func test_게임을_시작하면_설정한_배틀_모드가_배틀에_반영된다() -> void:
	var room := Room.new()
	room.set_battle_mode(BattleMode.MONSTER)
	room.game_start()
	assert_str(room.get_battle().get_mode()).is_equal(BattleMode.MONSTER)

func test_두_팀_이상이어야_게임_시작이_가능하다() -> void:
	var room := Room.new()
	var character1 := Character.new(Vector2i(1, 2), 0, Color.RED)
	var character2 := Character.new(Vector2i(1, 2), 0, Color.RED)
	room.add_character(character1)
	room.add_character(character2)
	assert_int(room.team_count()).is_equal(1)
	assert_bool(room.can_game_start()).is_false()
	var character3 := Character.new(Vector2i(1, 2), 0, Color.BLUE)
	room.add_character(character3)
	assert_int(room.team_count()).is_equal(2)
	assert_bool(room.can_game_start()).is_true()

func test_몬스터_모드로_바꾸면_NPC가_다른_팀이_되어_게임을_시작할_수_있다() -> void:
	var room := Room.new()
	room.add_character(Character.new(Vector2i(1, 2), 1, Color.RED))
	assert_int(room.team_count()).is_equal(1)
	room.set_battle_mode(BattleMode.MONSTER)
	assert_int(room.team_count()).is_equal(2)
	assert_bool(room.can_game_start()).is_true()

func test_몬스터_모드면_방에_NPC가_들어와_있는다() -> void:
	var room := Room.new()
	assert_bool(room.has_npc()).is_false()
	room.set_battle_mode(BattleMode.MONSTER)
	assert_bool(room.has_npc()).is_true()

func test_NPC만_남은_방에_캐릭터가_들어와도_NPC는_뒷자리로_밀린다() -> void:
	var room := Room.new()
	var first := Character.new(Vector2i(4, 2), 1, Color.RED)
	room.add_character(first)
	room.set_battle_mode(BattleMode.MONSTER)
	var npc := room.characters()[1]
	room.remove_character(first)
	assert_array(room.characters()).is_equal([npc])
	var second := Character.new(Vector2i(9, 10), 1, Color.BLUE)
	room.add_character(second)
	assert_array(room.characters()).is_equal([second, npc])
	assert_int(second.number).is_not_equal(npc.number)

# 멀티플레이어
func test_접속된_피어_ID로_해당_캐릭터를_찾을_수_있다() -> void:
	var peer_id := 1
	var room := Room.new()
	var character := Character.new((Vector2i(1, 2)), 1, Color.RED, peer_id)
	room.add_character(character)
	var found_character := room.find_character(peer_id)
	assert_that(found_character).is_equal(character)

func test_캐릭터가_방에_보낸_메시지는_순서대로_쌓인다() -> void:
	var peer1_id := 1
	var peer2_id := 2
	var room := Room.new()
	var character1 := Character.new(Vector2i(1, 2), 1, Color.RED, peer1_id)
	var character2 := Character.new(Vector2i(1, 2), 2, Color.RED, peer2_id)
	room.add_character(character1)
	room.add_character(character2)
	room.send_message(character1.id, "hi")
	var message1 := Message.new()
	message1.sender_id = character1.id
	message1.contents = "hi"
	assert_that(room.messages).is_equal([message1])
	room.send_message(character2.id, "hello")
	var message2 := Message.new()
	message2.sender_id = character2.id
	message2.contents = "hello"
	assert_that(room.messages).is_equal([message1, message2])

# 스냅샷
func _room_with_four_seats() -> Room:
	var room := Room.new()
	room.add_character(Character.new(Vector2i(3, 5), 0, Color.RED, 11))
	room.add_character(Character.new(Vector2i(7, 2), 0, Color.GREEN, 22))
	room.add_character(Character.new(Vector2i(4, 9), 0, Color.YELLOW, 11, true))
	room.set_battle_mode(BattleMode.MONSTER)
	return room

func test_방_스냅샷은_방_정보와_자리_목록을_담는다() -> void:
	var room := _room_with_four_seats()
	assert_that(room.snapshot(11)).is_equal({
		"id": room.id,
		"mode": BattleMode.MONSTER,
		"can_battle_start": true,
		"local_multi_on": true,
		"seats": [
			{"number": 1, "color": Color.RED, "is_npc": false},
			{"number": 2, "color": Color.GREEN, "is_npc": false},
			{"number": 3, "color": Color.YELLOW, "is_npc": false},
			{"number": 4, "color": Team.MONSTER_COLOR, "is_npc": true},
		],
	})

func test_방_스냅샷의_로컬멀티_켜짐은_피어마다_다르다() -> void:
	var room := _room_with_four_seats()
	assert_bool(room.snapshot(11)["local_multi_on"]).is_true()
	assert_bool(room.snapshot(22)["local_multi_on"]).is_false()

func test_방_스냅샷은_RPC로_보낼_수_있다() -> void:
	var snapshot: Dictionary = _room_with_four_seats().snapshot(11)
	assert_that(bytes_to_var(var_to_bytes(snapshot))).is_equal(snapshot)

# 배틀 스냅샷
func _room_in_battle() -> Room:
	var room := Room.new()
	room.add_character(Character.new(Vector2i.ZERO, 0, Color.RED, 11))
	room.add_character(Character.new(Vector2i.ZERO, 0, Color.GREEN, 22))
	room.game_start()
	var map := room.get_battle().get_map()
	map.add_water_balloon(WaterBalloon.new(Vector2i(2, 11), room.characters()[0]))
	map.add_water_stream(WaterStream.new(Vector2i(7, 3), Vector2i.UP, "end"))
	map.let_character_out(room.characters()[1])
	room.get_battle().tick(0.001)
	return room

func test_배틀_스냅샷은_맵_위의_것과_참가자_명부를_담는다() -> void:
	var room := _room_in_battle()
	var expected_game_items: Array[Dictionary] = []
	for game_item in room.get_battle().get_map().game_items():
		expected_game_items.append({"cell": game_item.position, "type": game_item.type})

	assert_that(room.battle_snapshot()).is_equal({
		"characters": [
			{
				"number": 1, "is_npc": false, "cell": Vector2(1, 6),
				"color": Color.RED, "facing": Vector2i.DOWN, "is_trapped": false,
			},
		],
		"seats": [
			{"number": 1, "is_npc": false, "color": Color.RED, "is_out": false},
			{"number": 2, "is_npc": false, "color": Color.GREEN, "is_out": true},
		],
		"water_balloons": [{"cell": Vector2i(2, 11), "owner_number": 1}],
		"water_streams": [{"cell": Vector2i(7, 3), "direction": Vector2i.UP, "position_type": "end"}],
		"game_items": expected_game_items,
		"winner_color": Color.RED,
		"is_draw": false,
	})

func test_배틀_스냅샷에서_탈락한_캐릭터는_그리는_목록에서_빠지고_명부에_남는다() -> void:
	var snapshot: Dictionary = _room_in_battle().battle_snapshot()
	var drawn: Array = snapshot["characters"]
	var seats: Array = snapshot["seats"]
	assert_int(drawn.size()).is_equal(1)
	assert_int(seats.size()).is_equal(2)
	assert_bool(seats[1]["is_out"]).is_true()

func test_배틀_스냅샷은_RPC로_보낼_수_있다() -> void:
	var snapshot: Dictionary = _room_in_battle().battle_snapshot()
	assert_that(bytes_to_var(var_to_bytes(snapshot))).is_equal(snapshot)

# 게임 아이템
func test_게임_시작_시_정해진_칸에_게임_아이템이_놓인다() -> void:
	var room := Room.new()
	room.add_character(Character.new(Vector2i.ZERO, 0, Color.RED, 11))
	room.add_character(Character.new(Vector2i.ZERO, 0, Color.GREEN, 22))
	room.game_start()
	var type_by_cell := {}
	for game_item in room.get_battle().get_map().game_items():
		type_by_cell[game_item.position] = game_item.type
	assert_that(type_by_cell.get(Vector2i(5, 4))).is_equal(GameItem.INCREASE_WATER_BALLOON_COUNT)
	assert_that(type_by_cell.get(Vector2i(11, 6))).is_equal(GameItem.INCREASE_WATER_STREAM_LENGTH)
	assert_that(type_by_cell.get(Vector2i(9, 9))).is_equal(GameItem.INCREASE_SPEED)

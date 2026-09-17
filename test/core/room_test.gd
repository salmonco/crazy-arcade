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

# 멀티 플레이어
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

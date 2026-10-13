extends GdUnitTestSuite

func test_로비에서_방을_추가할_수_있다() -> void:
	var lobby := Lobby.new()
	lobby.create_room()
	assert_int(lobby.room_count()).is_equal(1)

func test_방_목록을_알_수_있다() -> void:
	var lobby := Lobby.new()
	var room1 := lobby.create_room()
	var room2 := lobby.create_room()
	assert_array(lobby.rooms).is_equal([room1, room2])

func test_로비에서_방을_만들면_방_목록에_들어간다() -> void:
	var lobby := Lobby.new()
	var room := lobby.create_room()
	assert_int(lobby.room_count()).is_equal(1)
	assert_that(lobby.find_room(room.id)).is_equal(room)

func test_방을_두_번_만들면_서로_다른_방이_만들어진다() -> void:
	var lobby := Lobby.new()
	var first := lobby.create_room()
	var second := lobby.create_room()
	assert_that(first).is_not_equal(second)
	assert_int(lobby.room_count()).is_equal(2)

func test_ID로_방을_찾는다() -> void:
	var lobby := Lobby.new()
	var room := lobby.create_room()
	assert_that(lobby.find_room(room.id)).is_equal(room)

# 멀티플레이어
func test_피어는_방에_입장할_수_있다() -> void:
	var lobby := Lobby.new()
	var peer_id := 12345
	var character := Character.new(Vector2i.ZERO, 0, Color.RED, peer_id)
	lobby.add_character(character)
	var room := lobby.create_room()
	assert_bool(lobby.enter_room(room.id, peer_id)).is_true()

func test_피어가_방에_입장하면_방에_피어의_캐릭터가_생긴다() -> void:
	var lobby := Lobby.new()
	var peer_id := 12345
	var character := Character.new(Vector2i.ZERO, 0, Color.RED, peer_id)
	lobby.add_character(character)
	var room := lobby.create_room()
	assert_int(room.characters().size()).is_equal(0)
	assert_that(room.find_character(peer_id)).is_null()
	lobby.enter_room(room.id, peer_id)
	assert_int(room.characters().size()).is_equal(1)
	assert_that(room.find_character(peer_id)).is_equal(character)

func test_피어는_방에서_퇴장할_수_있다() -> void:
	var lobby := Lobby.new()
	var peer_id := 12345
	var character := Character.new(Vector2i.ZERO, 0, Color.RED, peer_id)
	lobby.add_character(character)
	var room := lobby.create_room()
	lobby.enter_room(room.id, peer_id)
	assert_bool(lobby.leave_room(room.id, peer_id)).is_true()

func test_피어가_방에서_퇴장하면_방에_피어의_캐릭터가_사라진다() -> void:
	var lobby := Lobby.new()
	var peer_id := 12345
	var character := Character.new(Vector2i.ZERO, 0, Color.RED, peer_id)
	lobby.add_character(character)
	var room := lobby.create_room()
	lobby.enter_room(room.id, peer_id)
	assert_that(room.find_character(peer_id)).is_equal(character)
	lobby.leave_room(room.id, peer_id)
	assert_that(room.find_character(peer_id)).is_null()

func test_로비에_없는_피어는_방에_입장하지_못한다() -> void:
	var lobby := Lobby.new()
	var room := lobby.create_room()
	assert_bool(lobby.enter_room(room.id, 47324)).is_false()
	assert_array(room.characters()).is_empty()

# 스냅샷
func _enter_new_character(lobby: Lobby, room: Room, peer_id: int) -> void:
	lobby.add_character(Character.new(Vector2i.ZERO, 0, Color.RED, peer_id))
	lobby.enter_room(room.id, peer_id)

func test_로비_스냅샷은_방마다_아이디와_인원수와_모드와_상태를_담는다() -> void:
	var lobby := Lobby.new()
	var quiet_room := lobby.create_room()
	var crowded_room := lobby.create_room()
	_enter_new_character(lobby, quiet_room, 11)
	_enter_new_character(lobby, crowded_room, 22)
	_enter_new_character(lobby, crowded_room, 33)
	_enter_new_character(lobby, crowded_room, 44)
	crowded_room.set_battle_mode(BattleMode.MONSTER)
	assert_that(lobby.snapshot()).is_equal({
		"rooms": [
			{"id": quiet_room.id, "character_count": 1, "mode": BattleMode.LOCAL_MULTI, "status": RoomStatus.WAITING},
			{"id": crowded_room.id, "character_count": 4, "mode": BattleMode.MONSTER, "status": RoomStatus.FULL},
		]
	})

func test_로비_스냅샷은_RPC로_보낼_수_있다() -> void:
	var lobby := Lobby.new()
	var room := lobby.create_room()
	_enter_new_character(lobby, room, 11)
	var snapshot: Dictionary = lobby.snapshot()
	assert_that(bytes_to_var(var_to_bytes(snapshot))).is_equal(snapshot)

# 화면 스냅샷
func _add_character(lobby: Lobby, peer_id: int, color: Color = Color.RED) -> Character:
	var character := Character.new(Vector2i.ZERO, 0, color, peer_id)
	lobby.add_character(character)
	return character

func _room_with_two_peers(lobby: Lobby) -> Room:
	var room := lobby.create_room()
	_add_character(lobby, 11)
	_add_character(lobby, 22, Color.GREEN)
	lobby.enter_room(room.id, 11)
	lobby.enter_room(room.id, 22)
	return room

func test_같은_로비라도_피어마다_다른_화면을_본다() -> void:
	var lobby := Lobby.new()
	var room := lobby.create_room()
	_add_character(lobby, 11)
	_add_character(lobby, 22, Color.GREEN)
	lobby.enter_room(room.id, 11)
	assert_that(lobby.snapshot_for(11)["screen"]).is_equal(Screen.ROOM)
	assert_that(lobby.snapshot_for(22)["screen"]).is_equal(Screen.LOBBY)

func test_로비_화면_스냅샷에는_방_목록이_함께_실린다() -> void:
	var lobby := Lobby.new()
	lobby.create_room()
	_add_character(lobby, 11)
	assert_that(lobby.snapshot_for(11)).is_equal({
		"screen": Screen.LOBBY,
		"lobby": lobby.snapshot(),
	})

func test_방_화면_스냅샷에는_방의_내용이_함께_실린다() -> void:
	var lobby := Lobby.new()
	var room := lobby.create_room()
	_add_character(lobby, 11)
	lobby.enter_room(room.id, 11)
	assert_that(lobby.snapshot_for(11)).is_equal({
		"screen": Screen.ROOM,
		"room": room.snapshot(11),
	})

func test_방_화면_스냅샷의_로컬멀티는_받는_피어_기준이다() -> void:
	var lobby := Lobby.new()
	var room := _room_with_two_peers(lobby)
	room.add_character(Character.new(Vector2i.ZERO, 0, Color.YELLOW, 11, true))
	assert_bool(lobby.snapshot_for(11)["room"]["local_multi_on"]).is_true()
	assert_bool(lobby.snapshot_for(22)["room"]["local_multi_on"]).is_false()

func test_배틀_중이면_배틀_화면을_본다() -> void:
	var lobby := Lobby.new()
	var room := _room_with_two_peers(lobby)
	room.game_start()
	var snapshot: Dictionary = lobby.snapshot_for(11)
	assert_that(snapshot["screen"]).is_equal(Screen.BATTLE)
	assert_int(snapshot["battle"]["characters"].size()).is_equal(2)

func test_배틀이_끝나면_다시_방_화면을_본다() -> void:
	var lobby := Lobby.new()
	var room := _room_with_two_peers(lobby)
	room.game_start()
	room.get_battle().is_finished = true
	assert_that(lobby.snapshot_for(11)["screen"]).is_equal(Screen.ROOM)

func test_로비에_없는_피어에게는_화면을_지시하지_않는다() -> void:
	var lobby := Lobby.new()
	lobby.create_room()
	assert_that(lobby.snapshot_for(47324)).is_equal({"screen": null})

func test_화면_스냅샷은_RPC로_보낼_수_있다() -> void:
	var lobby := Lobby.new()
	var room := _room_with_two_peers(lobby)
	room.game_start()
	var snapshot: Dictionary = lobby.snapshot_for(11)
	assert_that(bytes_to_var(var_to_bytes(snapshot))).is_equal(snapshot)

# tick
func _room_in_battle_with_balloon(lobby: Lobby, first_peer: int, second_peer: int, cell: Vector2i) -> Map:
	var room := lobby.create_room()
	_add_character(lobby, first_peer)
	_add_character(lobby, second_peer, Color.GREEN)
	lobby.enter_room(room.id, first_peer)
	lobby.enter_room(room.id, second_peer)
	room.game_start()
	var map := room.get_battle().get_map()
	map.add_water_balloon(WaterBalloon.new(cell, room.characters()[0]))
	return map

func test_로비가_시간을_흘리면_모든_방의_배틀이_흐른다() -> void:
	var lobby := Lobby.new()
	var first_map := _room_in_battle_with_balloon(lobby, 11, 22, Vector2i(2, 11))
	var second_map := _room_in_battle_with_balloon(lobby, 33, 44, Vector2i(4, 9))
	var step := WaterBalloon.POP_AFTER_SECONDS * 0.4
	lobby.tick(step)
	lobby.tick(step)
	assert_int(first_map.water_balloon_count()).is_equal(1)
	assert_int(second_map.water_balloon_count()).is_equal(1)
	lobby.tick(step)
	lobby.tick(step)
	assert_int(first_map.water_balloon_count()).is_equal(0)
	assert_int(second_map.water_balloon_count()).is_equal(0)

func test_배틀이_시작되지_않은_방에_시간을_흘려도_터지지_않는다() -> void:
	var lobby := Lobby.new()
	var room := _room_with_two_peers(lobby)
	lobby.tick(1.0)
	assert_that(room.get_battle()).is_null()

func test_배틀_중인_방만_고른다() -> void:
	var lobby := Lobby.new()
	var idle := lobby.create_room()
	var playing := _room_with_two_peers(lobby)
	playing.game_start()
	assert_array(lobby.rooms_in_battle()).is_equal([playing])
	assert_that(idle.get_battle()).is_null()

func test_배틀이_끝나면_그_방은_목록에서_빠진다() -> void:
	var lobby := Lobby.new()
	var room := _room_with_two_peers(lobby)
	room.game_start()
	assert_int(lobby.rooms_in_battle().size()).is_equal(1)
	room.game_over()
	assert_array(lobby.rooms_in_battle()).is_empty()

# 배틀 중 퇴장
func test_배틀_중_상대_팀이_모두_나가면_남은_팀이_이긴다() -> void:
	var lobby := Lobby.new()
	var room := _room_with_two_peers(lobby)
	room.game_start()
	lobby.leave_room(room.id, 22)
	lobby.tick(0.1)
	assert_that(room.get_battle().winner).is_equal(Color.RED)

func test_배틀_중_한_명이_나가도_두_팀_이상_남으면_계속한다() -> void:
	var lobby := Lobby.new()
	var room := _room_with_two_peers(lobby)
	_add_character(lobby, 33, Color.GREEN)
	lobby.enter_room(room.id, 33)
	room.game_start()
	lobby.leave_room(room.id, 33)
	lobby.tick(0.1)
	assert_bool(room.get_battle().is_game_over()).is_false()

func test_배틀_중_로컬_멀티_피어가_나가면_2P도_함께_빠진다() -> void:
	var lobby := Lobby.new()
	var room := _room_with_two_peers(lobby)
	room.add_character(Character.new(Vector2i.ZERO, 0, Color.YELLOW, 11, true))
	room.game_start()
	lobby.leave_room(room.id, 11)
	lobby.tick(0.1)
	assert_that(room.get_battle().winner).is_equal(Color.GREEN)

func test_배틀_중_모두_나가면_방이_사라진다() -> void:
	var lobby := Lobby.new()
	var room := _room_with_two_peers(lobby)
	room.game_start()
	lobby.leave_room(room.id, 11)
	lobby.leave_room(room.id, 22)
	assert_that(lobby.find_room(room.id)).is_null()
	assert_array(lobby.rooms_in_battle()).is_empty()

func test_상대가_나가서_이긴_피어는_잠시_뒤_방_화면으로_돌아간다() -> void:
	var lobby := Lobby.new()
	var room := _room_with_two_peers(lobby)
	room.game_start()
	lobby.leave_room(room.id, 22)
	var step := Battle.GAME_OVER_AFTER_SECOND * 0.6
	lobby.tick(step) # 승부 판정
	lobby.tick(step)
	lobby.tick(step)
	assert_that(lobby.snapshot_for(11)["screen"]).is_equal(Screen.ROOM)

# 배틀 중 입장
func test_배틀_중인_방에는_입장하지_못한다() -> void:
	var lobby := Lobby.new()
	var room := _room_with_two_peers(lobby)
	room.game_start()
	_add_character(lobby, 33, Color.BLUE)
	assert_bool(lobby.enter_room(room.id, 33)).is_false()
	assert_int(room.characters().size()).is_equal(2)
	assert_that(lobby.snapshot_for(33)["screen"]).is_equal(Screen.LOBBY)

func test_배틀이_끝난_방에는_다시_입장할_수_있다() -> void:
	var lobby := Lobby.new()
	var room := _room_with_two_peers(lobby)
	room.game_start()
	room.game_over()
	_add_character(lobby, 33, Color.BLUE)
	assert_bool(lobby.enter_room(room.id, 33)).is_true()
	assert_int(room.characters().size()).is_equal(3)

func test_다른_방에_있다가_배틀_중인_방에_입장하려_하면_원래_방에_남는다() -> void:
	var lobby := Lobby.new()
	var playing := _room_with_two_peers(lobby)
	playing.game_start()
	var waiting := lobby.create_room()
	_add_character(lobby, 33, Color.BLUE)
	lobby.enter_room(waiting.id, 33)
	lobby.enter_room(playing.id, 33)
	assert_that(lobby.room_of(33)).is_equal(waiting)

func test_배틀_중_나간_캐릭터는_남은_피어의_화면에서_사라진다() -> void:
	var lobby := Lobby.new()
	var room := _room_with_two_peers(lobby)
	room.game_start()
	lobby.leave_room(room.id, 22)
	var drawn_numbers := []
	for character in lobby.snapshot_for(11)["battle"]["characters"]:
		drawn_numbers.append(character["number"])
	assert_array(drawn_numbers).is_equal([1])

# 정원
const OUTSIDER := 999

func _room_with_peers(lobby: Lobby, count: int) -> Room:
	var room := lobby.create_room()
	for i in count:
		var peer_id := 100 + i
		_add_character(lobby, peer_id, Color.RED if i % 2 == 0 else Color.GREEN)
		lobby.enter_room(room.id, peer_id)
	return room

func test_꽉_찬_방에는_입장하지_못한다() -> void:
	var lobby := Lobby.new()
	var room := _room_with_peers(lobby, Room.capacity())
	_add_character(lobby, OUTSIDER, Color.BLUE)
	assert_bool(lobby.enter_room(room.id, OUTSIDER)).is_false()
	assert_int(room.characters().size()).is_equal(Room.capacity())
	assert_that(lobby.snapshot_for(OUTSIDER)["screen"]).is_equal(Screen.LOBBY)

func test_정원보다_한_명_적은_방에는_입장할_수_있다() -> void:
	var lobby := Lobby.new()
	var room := _room_with_peers(lobby, Room.capacity() - 1)
	_add_character(lobby, OUTSIDER, Color.BLUE)
	assert_bool(lobby.enter_room(room.id, OUTSIDER)).is_true()
	assert_int(room.characters().size()).is_equal(Room.capacity())

func test_다른_방에_있다가_꽉_찬_방에_입장하려_하면_원래_방에_남는다() -> void:
	var lobby := Lobby.new()
	var full := _room_with_peers(lobby, Room.capacity())
	var waiting := lobby.create_room()
	_add_character(lobby, OUTSIDER, Color.BLUE)
	lobby.enter_room(waiting.id, OUTSIDER)
	lobby.enter_room(full.id, OUTSIDER)
	assert_that(lobby.room_of(OUTSIDER)).is_equal(waiting)

func test_몬스터_모드에서는_NPC도_자리를_차지한다() -> void:
	var lobby := Lobby.new()
	var room := _room_with_peers(lobby, Room.capacity() - 1)
	room.set_battle_mode(BattleMode.MONSTER)
	_add_character(lobby, OUTSIDER, Color.BLUE)
	assert_bool(lobby.enter_room(room.id, OUTSIDER)).is_false()
	assert_int(room.characters().size()).is_equal(Room.capacity())

func test_꽉_찬_방에서도_배틀이_시작된다() -> void:
	var lobby := Lobby.new()
	var room := _room_with_peers(lobby, Room.capacity())
	room.game_start()
	assert_that(room.get_battle()).is_not_null()

# 빈 방
func test_마지막_사람이_나가면_방이_사라진다() -> void:
	var lobby := Lobby.new()
	var room := lobby.create_room()
	_add_character(lobby, 11)
	lobby.enter_room(room.id, 11)
	lobby.leave_room(room.id, 11)
	assert_that(lobby.find_room(room.id)).is_null()
	assert_int(lobby.room_count()).is_equal(0)

func test_사람이_남아_있으면_방은_사라지지_않는다() -> void:
	var lobby := Lobby.new()
	var room := _room_with_two_peers(lobby)
	lobby.leave_room(room.id, 11)
	assert_that(lobby.find_room(room.id)).is_same(room)

func test_NPC만_남으면_방이_사라진다() -> void:
	var lobby := Lobby.new()
	var room := lobby.create_room()
	_add_character(lobby, 11)
	lobby.enter_room(room.id, 11)
	room.set_battle_mode(BattleMode.MONSTER)
	lobby.leave_room(room.id, 11)
	assert_that(lobby.find_room(room.id)).is_null()

func test_다른_방으로_옮겨서_비게_된_방은_사라진다() -> void:
	var lobby := Lobby.new()
	var left := lobby.create_room()
	var other := lobby.create_room()
	_add_character(lobby, 11)
	lobby.enter_room(left.id, 11)
	lobby.enter_room(other.id, 11)
	assert_that(lobby.find_room(left.id)).is_null()
	assert_that(lobby.find_room(other.id)).is_same(other)

func test_다른_방의_빈_방은_건드리지_않는다() -> void:
	var lobby := Lobby.new()
	var untouched := lobby.create_room()
	var room := lobby.create_room()
	_add_character(lobby, 11)
	lobby.enter_room(room.id, 11)
	lobby.leave_room(room.id, 11)
	assert_that(lobby.find_room(untouched.id)).is_same(untouched)

# 로비 목록의 방 상태
func _status_in_snapshot(lobby: Lobby, room: Room) -> StringName:
	for entry in lobby.snapshot()["rooms"]:
		if entry["id"] == room.id:
			return entry["status"]
	return &""

func test_로비_스냅샷은_배틀_중인_방을_게임_중으로_알린다() -> void:
	var lobby := Lobby.new()
	var room := _room_with_two_peers(lobby)
	room.game_start()
	assert_that(_status_in_snapshot(lobby, room)).is_equal(RoomStatus.PLAYING)

func test_로비_스냅샷은_배틀이_끝난_방을_다시_대기_중으로_알린다() -> void:
	var lobby := Lobby.new()
	var room := _room_with_two_peers(lobby)
	room.game_start()
	room.game_over()
	assert_that(_status_in_snapshot(lobby, room)).is_equal(RoomStatus.WAITING)

func test_꽉_찬_방이_배틀_중이면_게임_중으로_알린다() -> void:
	var lobby := Lobby.new()
	var room := _room_with_peers(lobby, Room.capacity())
	room.game_start()
	assert_that(_status_in_snapshot(lobby, room)).is_equal(RoomStatus.PLAYING)

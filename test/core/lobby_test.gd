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

func test_로비_스냅샷은_방마다_아이디와_인원수와_모드를_담는다() -> void:
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
			{"id": quiet_room.id, "character_count": 1, "mode": BattleMode.LOCAL_MULTI},
			{"id": crowded_room.id, "character_count": 4, "mode": BattleMode.MONSTER},
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

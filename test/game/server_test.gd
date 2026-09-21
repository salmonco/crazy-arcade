extends GdUnitTestSuite

const SCENE_PATH := "res://scenes/server.tscn"

var _runner: GdUnitSceneRunner
var _server: Server

func before_test() -> void:
	_runner = scene_runner(SCENE_PATH)
	_server = _runner.scene()

func test_서버가_로비를_갖고_있다() -> void:
	assert_that(_server.lobby).is_not_null()

func test_피어가_접속하면_로비에_캐릭터가_늘어난다() -> void:
	assert_int(_server.lobby.characters.size()).is_equal(0)
	_server.on_peer_connected(12345)
	assert_int(_server.lobby.characters.size()).is_equal(1)
	_server.on_peer_connected(98765)
	assert_int(_server.lobby.characters.size()).is_equal(2)

func test_피어가_접속하면_로비에_해당_피어의_캐릭터가_생긴다() -> void:
	var peer_id := 12345
	assert_that(_server.lobby.find_character(peer_id)).is_null()
	_server.on_peer_connected(peer_id)
	assert_that(_server.lobby.find_character(peer_id)).is_not_null()

func test_피어가_접속을_끊으면_로비에_캐릭터가_감소한다() -> void:
	var peer_id := 12345
	var peer2_id := 98765
	_server.on_peer_connected(peer_id)
	_server.on_peer_connected(peer2_id)
	assert_int(_server.lobby.characters.size()).is_equal(2)
	_server.on_peer_disconnected(peer_id)
	assert_int(_server.lobby.characters.size()).is_equal(1)
	_server.on_peer_disconnected(peer2_id)
	assert_int(_server.lobby.characters.size()).is_equal(0)

func test_피어가_접속을_끊으면_로비에_해당_피어의_캐릭터가_사라진다() -> void:
	var peer_id := 12345
	_server.on_peer_connected(peer_id)
	assert_that(_server.lobby.find_character(peer_id)).is_not_null()
	_server.on_peer_disconnected(peer_id)
	assert_that(_server.lobby.find_character(peer_id)).is_null()

func test_방을_생성한다() -> void:
	assert_int(_server.lobby.room_count()).is_equal(0)
	var room := _server.create_room()
	assert_int(_server.lobby.room_count()).is_equal(1)
	assert_that(_server.lobby.find_room(room.id)).is_equal(room)

func test_피어가_방에_입장하면_방에_피어의_캐릭터가_생긴다() -> void:
	var peer_id := 12345
	_server.on_peer_connected(peer_id)
	var room := _server.create_room()
	assert_int(room.characters().size()).is_equal(0)
	assert_that(room.find_character(peer_id)).is_null()
	_server.enter_room(room.id, peer_id)
	assert_int(room.characters().size()).is_equal(1)
	assert_that(room.find_character(peer_id)).is_equal(_server.lobby.find_character(peer_id))

func test_피어가_방에서_떠나면_방에_피어의_캐릭터가_사라진다() -> void:
	var peer_id := 12345
	_server.on_peer_connected(peer_id)
	var room := _server.create_room()
	_server.enter_room(room.id, peer_id)
	assert_int(room.characters().size()).is_equal(1)
	assert_that(room.find_character(peer_id)).is_equal(_server.lobby.find_character(peer_id))
	_server.leave_room(peer_id)
	assert_int(room.characters().size()).is_equal(0)
	assert_that(room.find_character(peer_id)).is_null()

func test_피어가_방에_입장한_상태인데_접속을_끊으면_방과_로비에서_피어의_캐릭터가_사라진다() -> void:
	var peer_id := 12345
	_server.on_peer_connected(peer_id)
	var room := _server.create_room()
	_server.enter_room(room.id, peer_id)
	assert_that(_server.lobby.find_room(room.id).find_character(peer_id)).is_not_null()
	assert_that(_server.lobby.find_character(peer_id)).is_not_null()
	_server.on_peer_disconnected(peer_id)
	assert_that(_server.lobby.find_room(room.id).find_character(peer_id)).is_null()
	assert_that(_server.lobby.find_character(peer_id)).is_null()

func test_피어가_접속하고_방에_입장해도_로비엔_해당_피어의_캐릭터가_남아있다() -> void:
	var peer_id := 12345
	_server.on_peer_connected(peer_id)
	assert_that(_server.lobby.find_character(peer_id)).is_not_null()
	var room := _server.create_room()
	_server.enter_room(room.id, peer_id)
	assert_that(_server.lobby.find_character(peer_id)).is_not_null()

func test_배틀을_시작할_수_있다() -> void:
	var peer_id := 12345
	_server.on_peer_connected(peer_id)
	var room := _server.create_room()
	_server.enter_room(room.id, peer_id)
	assert_that(room.get_battle()).is_null()
	_server.start_battle(peer_id)
	assert_that(room.get_battle()).is_not_null()

func test_배틀을_종료할_수_있다() -> void:
	var peer_id := 12345
	_server.on_peer_connected(peer_id)
	var room := _server.create_room()
	_server.enter_room(room.id, peer_id)
	_server.start_battle(peer_id)
	assert_that(room.get_battle()).is_not_null()
	_server.finish_battle(peer_id)
	assert_that(room.get_battle()).is_null()

func test_로컬_멀티_모드를_활성화하면_2P_캐릭터가_생긴다() -> void:
	var peer_id := 12345
	_server.on_peer_connected(peer_id)
	var room := _server.create_room()
	_server.enter_room(room.id, peer_id)
	assert_that(room.find_2p(peer_id)).is_null()
	_server.set_local_multi(true, peer_id)
	assert_that(room.find_2p(peer_id)).is_not_null()

func test_몬스터_모드를_활성화하면_방에_NPC가_생긴다() -> void:
	var peer_id := 12345
	_server.on_peer_connected(peer_id)
	var room := _server.create_room()
	_server.enter_room(room.id, peer_id)
	assert_bool(room.has_npc()).is_false()
	_server.set_monster_mode(true, peer_id)
	assert_bool(room.has_npc()).is_true()

# tick
func test_서버가_시간을_흘리면_방의_배틀이_흐른다() -> void:
	var room := _server.create_room()
	_server.on_peer_connected(11)
	_server.on_peer_connected(22)
	_server.enter_room(room.id, 11)
	_server.enter_room(room.id, 22)
	_server.start_battle(11)
	var map := room.get_battle().get_map()
	map.add_water_balloon(WaterBalloon.new(Vector2i(2, 11), room.characters()[0]))
	var step := WaterBalloon.POP_AFTER_SECONDS * 0.8
	_server.tick(step)
	assert_int(map.water_balloon_count()).is_equal(1)
	_server.tick(step)
	assert_int(map.water_balloon_count()).is_equal(0)

# 입력
func _battle_room_with_two_peers() -> Room:
	var room := _server.create_room()
	_server.on_peer_connected(11)
	_server.on_peer_connected(22)
	_server.enter_room(room.id, 11)
	_server.enter_room(room.id, 22)
	_server.start_battle(11)
	return room

func _seat(room: Room, number: int) -> Character:
	for character in room.get_battle().get_map().characters():
		if character.number == number:
			return character
	return null

func test_서버가_받은_이동_입력이_캐릭터에_전달된다() -> void:
	var room := _battle_room_with_two_peers()
	_server.set_heading(1, Vector2i.UP, 11)
	assert_that(_seat(room, 1).heading).is_equal(Vector2i.UP)

func test_서버는_남의_캐릭터를_움직이라는_입력을_무시한다() -> void:
	var room := _battle_room_with_two_peers()
	_server.set_heading(2, Vector2i.UP, 11)
	assert_that(_seat(room, 2).heading).is_equal(Vector2i.ZERO)

func test_서버가_받은_물풍선_입력이_맵에_전달된다() -> void:
	var room := _battle_room_with_two_peers()
	_server.place_water_balloon(1, 11)
	var map := room.get_battle().get_map()
	assert_bool(map.has_water_balloon(_seat(room, 1).position())).is_true()

func test_방에_없는_피어의_입력은_아무_일도_일으키지_않는다() -> void:
	_battle_room_with_two_peers()
	_server.on_peer_connected(33)
	_server.set_heading(1, Vector2i.UP, 33)
	_server.place_water_balloon(1, 33)
	assert_that(_server.lobby.room_of(33)).is_null()

func _two_rooms_two_peers() -> Array[Room]:
	var other := _server.create_room()
	var mine := _server.create_room()
	_server.on_peer_connected(11)
	_server.on_peer_connected(22)
	_server.enter_room(other.id, 22)
	_server.enter_room(mine.id, 11)
	return [mine, other]

func test_배틀은_그_피어가_있는_방에서만_시작된다() -> void:
	var rooms := _two_rooms_two_peers()
	_server.start_battle(11)
	assert_that(rooms[0].get_battle()).is_not_null()
	assert_that(rooms[1].get_battle()).is_null()

func test_모드_변경은_그_피어가_있는_방에만_적용된다() -> void:
	var rooms := _two_rooms_two_peers()
	_server.set_monster_mode(true, 11)
	assert_that(rooms[0].battle_mode).is_equal(BattleMode.MONSTER)
	assert_that(rooms[1].battle_mode).is_equal(BattleMode.LOCAL_MULTI)

func test_방에_없는_피어의_방_요청은_아무_일도_일으키지_않는다() -> void:
	var room := _server.create_room()
	_server.on_peer_connected(11)
	_server.start_battle(11)
	_server.finish_battle(11)
	_server.leave_room(11)
	_server.set_local_multi(true, 11)
	_server.set_monster_mode(true, 11)
	assert_that(room.get_battle()).is_null()
	assert_array(room.characters()).is_empty()
	assert_that(room.battle_mode).is_equal(BattleMode.LOCAL_MULTI)

func test_배틀_중인_방_사람에게_프레임을_보낸다() -> void:
	_battle_room_with_two_peers()
	assert_array(_server.tick(0.1, [11, 22])).contains([11, 22])

func test_배틀이_없는_방_사람에게는_보내지_않는다() -> void:
	var room := _server.create_room()
	_server.on_peer_connected(11)
	_server.enter_room(room.id, 11)
	assert_array(_server.tick(0.1, [11])).is_empty()

func test_배틀이_끝나는_프레임에도_그_방_사람에게_보낸다() -> void:
	var room := _battle_room_with_two_peers()
	room.get_battle().get_map().let_character_out(room.characters()[1])
	var step := Battle.GAME_OVER_AFTER_SECOND * 0.6
	_server.tick(step)
	_server.tick(step)
	assert_array(_server.tick(step, [11])).is_equal([11])
	assert_that(room.get_battle()).is_null()
	assert_that(_server.lobby.snapshot_for(11)["screen"]).is_equal(Screen.ROOM)

# 캐릭터 색상
func test_캐릭터의_색상을_변경할_수_있다() -> void:
	var room := _server.create_room()
	_server.on_peer_connected(11)
	_server.enter_room(room.id, 11)
	_server.set_character_color(1, Color.ORANGE, 11)
	assert_that(_server.lobby.find_character(11).color).is_equal(Color.ORANGE)
	_server.set_character_color(1, Color.GREEN, 11)
	assert_that(_server.lobby.find_character(11).color).is_equal(Color.GREEN)

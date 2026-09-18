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
	_server.leave_room(room.id, peer_id)
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
	_server.start_battle(room.id)
	assert_that(room.get_battle()).is_not_null()

func test_배틀을_종료할_수_있다() -> void:
	var peer_id := 12345
	_server.on_peer_connected(peer_id)
	var room := _server.create_room()
	_server.enter_room(room.id, peer_id)
	_server.start_battle(room.id)
	assert_that(room.get_battle()).is_not_null()
	_server.finish_battle(room.id)
	assert_that(room.get_battle()).is_null()

func test_로컬_멀티_모드를_활성화하면_2P_캐릭터가_생긴다() -> void:
	var peer_id := 12345
	_server.on_peer_connected(peer_id)
	var room := _server.create_room()
	assert_that(room.find_2p(peer_id)).is_null()
	_server.set_local_multi(room.id, true, peer_id)
	assert_that(room.find_2p(peer_id)).is_not_null()

func test_몬스터_모드를_활성화하면_방에_NPC가_생긴다() -> void:
	var peer_id := 12345
	_server.on_peer_connected(peer_id)
	var room := _server.create_room()
	assert_bool(room.has_npc()).is_false()
	_server.set_monster_mode(room.id, true, peer_id)
	assert_bool(room.has_npc()).is_true()

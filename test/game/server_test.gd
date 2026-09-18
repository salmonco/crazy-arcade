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

func test_방을_생성한다() -> void:
	assert_int(_server.lobby.room_count()).is_equal(0)
	var room := _server.create_room()
	assert_int(_server.lobby.room_count()).is_equal(1)
	assert_that(_server.lobby.find_room(room.id)).is_equal(room)

func test_피어를_방에_입장시킨다() -> void:
	var peer_id := 12345
	_server.on_peer_connected(peer_id)
	var room := _server.create_room()
	assert_int(room.characters().size()).is_equal(0)
	assert_that(room.find_character(peer_id)).is_null()
	_server.enter_room(room.id, peer_id)
	assert_int(room.characters().size()).is_equal(1)
	assert_that(room.find_character(peer_id)).is_equal(_server.lobby.find_character(peer_id))

func test_피어를_방에서_떠나보낸다() -> void:
	var peer_id := 12345
	_server.on_peer_connected(peer_id)
	var room := _server.create_room()
	_server.enter_room(room.id, peer_id)
	assert_int(room.characters().size()).is_equal(1)
	assert_that(room.find_character(peer_id)).is_equal(_server.lobby.find_character(peer_id))
	_server.leave_room(room.id, peer_id)
	assert_int(room.characters().size()).is_equal(0)
	assert_that(room.find_character(peer_id)).is_null()

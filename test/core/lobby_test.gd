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

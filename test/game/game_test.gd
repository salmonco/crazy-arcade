extends GdUnitTestSuite

const SCENE_PATH := "res://scenes/game.tscn"

var _runner: GdUnitSceneRunner
var _game: Game
var _server: Server
var _player_character: Character

func before_test() -> void:
	_runner = scene_runner(SCENE_PATH)
	_game = _runner.scene()
	_server = Server.new()
	_on_connected_peer(47324)
	_game.battle_view.move_requested.connect(func(number: int, direction: Vector2i) -> void:
		_server.set_heading(number, direction, _game.peer_id))
	_game.battle_view.water_balloon_requested.connect(func(number: int) -> void:
		_server.place_water_balloon(number, _game.peer_id))
	_game.room_view.local_multi_check.toggled.connect(func(toggled_on: bool) -> void: _request_set_local_multi(toggled_on))
	_game.room_view.monster_mode_check.toggled.connect(func(toggled_on: bool) -> void: _request_set_monster_mode(toggled_on))

func after_test() -> void:
	_server.free()

func _on_connected_peer(id: int) -> void:
	_server.on_peer_connected(id)
	_game.peer_id = id
	_player_character = _server.lobby.find_character(id)

func _sync() -> void:
	_game.screen_changed(_server.lobby.snapshot_for(_game.peer_id))

func _request_create_room_and_enter_room() -> void:
	var room := _server.create_room()
	_request_enter_room(room.id)

func _request_enter_room(room_id: String) -> void:
	_server.enter_room(room_id, _game.peer_id)
	_sync()

func _request_leave_room() -> void:
	_server.leave_room(_game.peer_id)
	_sync()

func _request_start_battle() -> void:
	_server.start_battle(_game.peer_id)
	_sync()

func _request_set_local_multi(enabled: bool) -> void:
	_server.set_local_multi(enabled, _game.peer_id)
	_sync()

func _request_set_monster_mode(enabled: bool) -> void:
	_server.set_monster_mode(enabled, _game.peer_id)
	_sync()

func _request_set_character_color(number: int, color: Color) -> void:
	_server.set_character_color(number, color, _game.peer_id)
	_sync()

# 로비에서 방 입장
func test_방_ID로_입장하면_방_화면이_된다() -> void:
	_request_create_room_and_enter_room()
	assert_bool(_game.room_view.visible).is_true()
	assert_bool(_game.lobby_view.visible).is_false()

func test_없는_방_ID로는_입장하지_못한다() -> void:
	_request_enter_room("없는-방-id")
	assert_bool(_game.room_view.visible).is_false()
	assert_bool(_game.lobby_view.visible).is_true()

func test_방을_만들면_만든_방에_들어가_있다() -> void:
	_request_create_room_and_enter_room()
	assert_bool(_game.room_view.visible).is_true()
	assert_bool(_game.lobby_view.visible).is_false()

func test_방에서_나가면_로비_화면이_된다() -> void:
	_request_create_room_and_enter_room()
	_request_leave_room()
	var current_room := _current_room()
	assert_that(current_room).is_null()
	assert_bool(_game.lobby_view.visible).is_true()
	assert_bool(_game.room_view.visible).is_false()

func test_방에서_나가도_방은_로비에_남는다() -> void:
	_request_create_room_and_enter_room()
	var left_room := _current_room()
	_request_leave_room()
	_request_enter_room(left_room.id)
	var current_room := _current_room()
	assert_that(current_room).is_equal(left_room)

func test_로비에_방_수만큼_목록이_보인다() -> void:
	_create_room_and_leave()
	_create_room_and_leave()
	_create_room_and_leave()
	assert_int(_game.lobby_view.room_count()).is_equal(3)

func test_로비_목록에서_방을_고르면_그_방에_입장한다() -> void:
	_create_room_and_leave()
	_create_room_and_leave()
	var second_room := _server.lobby.rooms[1]
	_request_enter_room(second_room.id)
	var current_room := _current_room()
	assert_that(current_room).is_equal(second_room)
	assert_bool(_game.room_view.visible).is_true()

func test_로비_목록의_방_항목이_입장에_연결되어_있다() -> void:
	assert_bool(_game.lobby_view.room_chosen.is_connected(_game.enter_room)).is_true()

func test_방의_나가기_버튼이_나가기에_연결되어_있다() -> void:
	assert_bool(_game.room_view.leave_button.pressed.is_connected(_game.leave_room)).is_true()

func test_로비의_방_만들기_버튼이_방_만들기에_연결되어_있다() -> void:
	assert_bool(_game.lobby_view.create_room_button.pressed.is_connected(_game.create_room)).is_true()

func test_방에_들어가면_캐릭터_수만큼_슬롯이_생긴다() -> void:
	var room := _room_with_characters(2)
	_request_enter_room(room.id)
	assert_int(_game.room_view.slot_count()).is_equal(3)

func test_방에_입장하면_내_캐릭터가_슬롯에_보인다() -> void:
	_request_create_room_and_enter_room()
	var current_room := _current_room()
	assert_array(current_room.characters()).is_equal([_player_character])
	assert_int(_game.room_view.slot_count()).is_equal(1)

func test_방에_있는_채로_다른_방에_들어가면_이전_방에서_빠진다() -> void:
	var first_room := _room_with_characters(0)
	var second_room := _room_with_characters(0)
	_request_enter_room(first_room.id)
	_request_enter_room(second_room.id)
	assert_array(first_room.characters()).is_empty()
	assert_array(second_room.characters()).is_equal([_player_character])

func test_방을_나갔다_다시_들어가도_내_캐릭터는_하나다() -> void:
	_request_create_room_and_enter_room()
	var room := _current_room()
	_request_leave_room()
	_request_enter_room(room.id)
	assert_int(_game.room_view.slot_count()).is_equal(1)

# 배틀 모드 설정
func test_몬스터_모드를_켜면_NPC_슬롯이_NPC로_그려진다() -> void:
	_request_create_room_and_enter_room()
	_request_set_monster_mode(true)
	assert_object(_game.room_view.slot(0).texture).is_equal(RoomView.PLAYER_SLOT_TEXTURE)
	assert_object(_game.room_view.slot(1).texture).is_equal(RoomView.NPC_SLOT_TEXTURE)

func _slot_color(index: int) -> Color:
	return (_game.room_view.slot(index).material as ShaderMaterial).get_shader_parameter("color")

func test_로컬_멀티면_1P와_2P_슬롯이_다른_색으로_그려진다() -> void:
	_request_create_room_and_enter_room()
	_request_set_local_multi(true)
	assert_that(_slot_color(0)).is_equal(_player_character.color)
	var current_room := _current_room()
	assert_that(_slot_color(1)).is_equal(current_room.find_2p(_game.peer_id).color)
	assert_that(_slot_color(0)).is_not_equal(_slot_color(1))

func test_몬스터_모드면_사람_슬롯은_같은_색이고_NPC만_다른_색이다() -> void:
	_request_create_room_and_enter_room()
	_request_set_monster_mode(true)
	_request_set_local_multi(true)
	var current_room := _current_room()
	var npc_index := 1 if current_room.characters()[1] is Npc else 2
	var second_player_index := 2 if npc_index == 1 else 1
	assert_that(_slot_color(second_player_index)).is_equal(_slot_color(0))
	assert_that(_slot_color(npc_index)).is_not_equal(_slot_color(0))

func test_로컬_멀티를_켜면_2P가_들어와_게임을_시작할_수_있다() -> void:
	_request_create_room_and_enter_room()
	_request_set_local_multi(true)
	assert_int(_game.room_view.slot_count()).is_equal(2)
	assert_bool(_game.room_view.start_button.disabled).is_false()

func test_로컬_멀티를_끄면_2P가_방에서_빠진다() -> void:
	_request_create_room_and_enter_room()
	_request_set_local_multi(true)
	_request_set_local_multi(false)
	var current_room := _current_room()
	assert_array(current_room.characters()).is_equal([_player_character])
	assert_int(_game.room_view.slot_count()).is_equal(1)

func test_로컬_멀티를_두_번_켜도_2P는_하나다() -> void:
	_request_create_room_and_enter_room()
	_request_set_local_multi(true)
	_request_set_local_multi(true)
	assert_int(_game.room_view.slot_count()).is_equal(2)

func test_방에서_나가면_2P도_방에서_빠진다() -> void:
	_request_create_room_and_enter_room()
	var room := _current_room()
	_request_set_local_multi(true)
	_request_leave_room()
	assert_array(room.characters()).is_empty()

func test_방의_로컬_멀티_체크가_2P_추가에_연결되어_있다() -> void:
	assert_bool(_game.room_view.local_multi_check.toggled.is_connected(_game.set_local_multi)).is_true()

func test_몬스터_모드를_켜면_2P가_나와_같은_팀이_된다() -> void:
	_request_create_room_and_enter_room()
	_request_set_local_multi(true)
	var current_room := _current_room()
	assert_int(current_room.team_count()).is_equal(2)
	_request_set_monster_mode(true)
	var second_player := current_room.find_2p(_game.peer_id)
	assert_that(second_player.color).is_equal(_player_character.color)
	assert_int(current_room.team_count()).is_equal(2)

func test_몬스터_모드를_끄면_2P가_다시_다른_팀이_된다() -> void:
	_request_create_room_and_enter_room()
	_request_set_local_multi(true)
	_request_set_monster_mode(true)
	_request_set_monster_mode(false)
	var current_room := _current_room()
	var second_player := current_room.find_2p(_game.peer_id)
	assert_that(second_player.color).is_not_equal(_player_character.color)
	assert_int(current_room.team_count()).is_equal(2)

func test_몬스터_모드에서_켠_로컬_멀티의_2P도_나와_같은_팀이다() -> void:
	_request_create_room_and_enter_room()
	_request_set_monster_mode(true)
	_request_set_local_multi(true)
	var current_room := _current_room()
	var second_player := current_room.find_2p(_game.peer_id)
	assert_that(second_player.color).is_equal(_player_character.color)
	assert_int(current_room.team_count()).is_equal(2)

func test_방에서_몬스터_모드를_켜면_NPC가_슬롯에_늘어난다() -> void:
	_request_create_room_and_enter_room()
	assert_int(_game.room_view.slot_count()).is_equal(1)
	_request_set_monster_mode(true)
	var current_room := _current_room()
	assert_str(current_room.battle_mode).is_equal(BattleMode.MONSTER)
	assert_int(_game.room_view.slot_count()).is_equal(2)

func test_방에서_몬스터_모드를_끄면_NPC가_슬롯에서_빠진다() -> void:
	_request_create_room_and_enter_room()
	_request_set_monster_mode(true)
	_request_set_monster_mode(false)
	var current_room := _current_room()
	assert_str(current_room.battle_mode).is_equal(BattleMode.LOCAL_MULTI)
	assert_int(_game.room_view.slot_count()).is_equal(1)

func test_다른_방에_들어가면_몬스터_모드_체크가_그_방을_따른다() -> void:
	_request_create_room_and_enter_room()
	_game.room_view.monster_mode_check.button_pressed = true
	var current_room := _current_room()
	assert_str(current_room.battle_mode).is_equal(BattleMode.MONSTER)
	_request_create_room_and_enter_room()
	assert_bool(_game.room_view.monster_mode_check.button_pressed).is_false()

func test_방의_몬스터_모드_체크가_모드_변경에_연결되어_있다() -> void:
	assert_bool(_game.room_view.monster_mode_check.toggled.is_connected(_game.set_monster_mode)).is_true()

func test_몬스터_모드를_선택하고_로컬_멀티_모드를_선택해도_2P_플레이어의_자리_번호는_2다() -> void:
	_request_create_room_and_enter_room()
	_game.room_view.monster_mode_check.button_pressed = true
	_game.room_view.local_multi_check.button_pressed = true
	var current_room := _current_room()
	var second_player := current_room.find_2p(_game.peer_id)
	assert_int(second_player.number).is_equal(2)

# 방에서 게임 시작
func _server_tick(delta: float) -> void:
	for peer_id in _server.tick(delta, [_game.peer_id]):
		_game.screen_changed(_server.lobby.snapshot_for(peer_id))

func _current_room() -> Room:
	return _server.lobby.room_of(_game.peer_id)

func _battle_map() -> Map:
	return _current_room().get_battle().get_map()

func _npc_in_battle() -> Character:
	for character in _battle_map().characters():
		if character is Npc:
			return character
	return null

func _start_monster_battle() -> void:
	_request_create_room_and_enter_room()
	_request_set_monster_mode(true)
	_request_start_battle()

func _start_monster_battle_with_second_player() -> void:
	_request_create_room_and_enter_room()
	_request_set_monster_mode(true)
	_request_set_local_multi(true)
	_request_start_battle()

func test_방에서_게임을_시작하면_배틀_화면이_된다() -> void:
	_start_monster_battle()
	assert_bool(_game.battle_view.visible).is_true()
	assert_bool(_game.room_view.visible).is_false()
	assert_int(_game.battle_view.view_by_character_number.size()).is_equal(2)

func test_스페이스를_누르면_서버_맵에_물풍선이_놓인다() -> void:
	_start_monster_battle()
	_game.battle_view.handle_key_pressed(KEY_SPACE)
	assert_bool(_battle_map().has_water_balloon(_player_character.position())).is_true()

func test_방향키를_누르면_서버에서_내_캐릭터가_움직인다() -> void:
	_start_monster_battle()
	var start_cell := _player_character.position()
	_game.battle_view.handle_key_pressed(KEY_RIGHT)
	_server_tick(1.0 / Character.SPEED)
	assert_vector(_player_character.position()).is_equal(start_cell + Vector2i.RIGHT)

func test_2P가_있으면_1P는_RFDG_2P는_방향키로_움직인다() -> void:
	_start_monster_battle_with_second_player()
	var second_player := _current_room().find_2p(_game.peer_id)
	var my_start := _player_character.position()
	var second_start := second_player.position()
	_game.battle_view.handle_key_pressed(KEY_G)
	_game.battle_view.handle_key_pressed(KEY_DOWN)
	_server_tick(1.0 / Character.SPEED)
	assert_vector(_player_character.position()).is_equal(my_start + Vector2i.RIGHT)
	assert_vector(second_player.position()).is_equal(second_start + Vector2i.DOWN)

func test_2P가_있으면_좌우_시프트로_각자_물풍선을_놓는다() -> void:
	_start_monster_battle_with_second_player()
	var second_player := _current_room().find_2p(_game.peer_id)
	_game.battle_view.handle_key_pressed(KEY_SHIFT, KEY_LOCATION_LEFT)
	_game.battle_view.handle_key_pressed(KEY_SHIFT, KEY_LOCATION_RIGHT)
	assert_array(_battle_map().water_balloon_positions()).contains(
		[_player_character.position(), second_player.position()])

# 승패
func test_로비_화면에서는_승패_라벨이_보이지_않는다() -> void:
	assert_bool(_game.battle_view.win_label.is_visible_in_tree()).is_false()
	assert_bool(_game.battle_view.lose_label.is_visible_in_tree()).is_false()
	assert_bool(_game.battle_view.draw_label.is_visible_in_tree()).is_false()

func test_NPC를_이기면_WIN이_뜬다() -> void:
	_start_monster_battle()
	_battle_map().let_character_out(_npc_in_battle())
	_server_tick(0.1)
	assert_bool(_game.battle_view.win_label.visible).is_true()
	assert_bool(_game.battle_view.lose_label.visible).is_false()

func test_지면_LOSE가_뜬다() -> void:
	_start_monster_battle()
	_battle_map().let_character_out(_player_character)
	_server_tick(0.1)
	assert_bool(_game.battle_view.lose_label.visible).is_true()
	assert_bool(_game.battle_view.win_label.visible).is_false()

func test_방의_시작_버튼이_게임_시작에_연결되어_있다() -> void:
	assert_bool(_game.room_view.start_button.pressed.is_connected(_game.start_battle)).is_true()

func test_한_팀뿐이면_시작_버튼이_비활성이다() -> void:
	var room := _room_with_characters(2)
	_request_enter_room(room.id)
	assert_bool(_game.room_view.start_button.disabled).is_true()

func test_두_팀_이상이면_시작_버튼이_활성이다() -> void:
	var room := _room_with_characters(2)
	room.add_character(Character.new(Vector2i(4, 6), 3, Color.BLUE))
	_request_enter_room(room.id)
	assert_bool(_game.room_view.start_button.disabled).is_false()

func test_다른_방에_들어가면_이전_방의_슬롯이_남지_않는다() -> void:
	var crowded_room := _room_with_characters(3)
	var empty_room := _room_with_characters(0)
	_request_enter_room(crowded_room.id)
	_request_enter_room(empty_room.id)
	assert_int(_game.room_view.slot_count()).is_equal(1)

func _create_room_and_leave() -> void:
	_request_create_room_and_enter_room()
	_request_leave_room()

func _room_with_characters(count: int) -> Room:
	var room := _server.create_room()
	for i in count:
		room.add_character(Character.new(Vector2i(i + 1, i + 3), i + 1, Color.RED))
	return room

# 배틀 종료
func test_배틀이_끝나면_몇_초_뒤에_방_화면으로_돌아간다() -> void:
	_start_monster_battle()
	_battle_map().let_character_out(_npc_in_battle())
	var step := Battle.GAME_OVER_AFTER_SECOND * 0.6
	_server_tick(step) # 승부 판정
	_server_tick(step)
	assert_bool(_game.battle_view.visible).is_true()
	assert_bool(_game.room_view.visible).is_false()
	_server_tick(step)
	assert_bool(_game.battle_view.visible).is_false()
	assert_bool(_game.room_view.visible).is_true()

# 멀티플레이어
func test_다른_피어_말고_내가_방에_입장해야_방_화면이_보인다() -> void:
	var peer2_id := 32412
	_server.on_peer_connected(peer2_id)
	var room := _server.create_room()
	_server.enter_room(room.id, peer2_id)
	assert_bool(_game.room_view.visible).is_false()
	_request_enter_room(room.id)
	assert_bool(_game.room_view.visible).is_true()

func test_나_말고_다른_피어가_방에서_떠나도_방_화면은_유지된다() -> void:
	var peer2_id := 32412
	_server.on_peer_connected(peer2_id)
	var room := _server.create_room()
	_request_enter_room(room.id)
	_server.enter_room(room.id, peer2_id)
	assert_bool(_game.room_view.visible).is_true()
	_server.leave_room(peer2_id)
	assert_bool(_game.room_view.visible).is_true()

# 캐릭터 색상
func _character_color_in_battle(number: int) -> Color:
	return (_game.battle_view.view_by_character_number[number].material as ShaderMaterial).get_shader_parameter("color")

func test_피어는_자신의_캐릭터_색상을_변경할_수_있다() -> void:
	_request_create_room_and_enter_room()
	_request_set_character_color(1, Color.ORANGE)
	assert_that(_slot_color(0)).is_equal(Color.ORANGE)
	_request_start_battle()
	assert_that(_character_color_in_battle(1)).is_equal(Color.ORANGE)

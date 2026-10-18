extends GdUnitTestSuite

const SCENE_PATH := "res://scenes/battle_view.tscn"
const MY_PEER := 11
const OTHER_PEER := 22

var _runner: GdUnitSceneRunner
var _battle_view: BattleView

func before_test() -> void:
	_runner = scene_runner(SCENE_PATH)
	_battle_view = _runner.scene()

func _seat(number: int, color: Color, peer: int, is_npc := false, is_out := false) -> Dictionary:
	return {"number": number, "is_npc": is_npc, "color": color, "is_out": is_out, "peer_id": peer}

func _character(number: int, cell: Vector2, color: Color, is_npc := false) -> Dictionary:
	return {
		"number": number, "is_npc": is_npc, "cell": cell,
		"color": color, "facing": Vector2i.DOWN, "is_trapped": false,
	}

func _solo_snapshot() -> Dictionary:
	return {
		"characters": [
			_character(1, Vector2(3, 5), Color.RED),
			_character(2, Vector2(9, 2), Team.MONSTER_COLOR, true),
		],
		"seats": [
			_seat(1, Color.RED, MY_PEER),
			_seat(2, Team.MONSTER_COLOR, 0, true),
		],
		"water_balloons": [], "water_streams": [], "game_items": [],
		"winner_color": Color.BLACK, "is_draw": false,
	}

func _local_multi_snapshot() -> Dictionary:
	var snapshot := _solo_snapshot()
	snapshot["characters"].append(_character(3, Vector2(7, 11), Color.GREEN))
	snapshot["seats"].append(_seat(3, Color.GREEN, MY_PEER))
	return snapshot

func _render(snapshot: Dictionary, peer := MY_PEER) -> void:
	_battle_view.render(snapshot, peer)

func test_스냅샷의_캐릭터마다_뷰를_만든다() -> void:
	_render(_solo_snapshot())
	assert_int(_battle_view.view_by_character_number.size()).is_equal(2)
	assert_that(_battle_view.view_by_character_number[1].position).is_equal(Map.to_pixel_continuous(Vector2(3, 5)))
	assert_that(_battle_view.view_by_character_number[2].position).is_equal(Map.to_pixel_continuous(Vector2(9, 2)))

# 내 캐릭터는 예측 위치에 그리므로, 서버 위치를 그대로 그리는 남의 캐릭터(NPC)로 확인한다.
func test_다시_그려도_같은_자리의_뷰는_살아남는다() -> void:
	_render(_solo_snapshot())
	var before_view: CharacterView = _battle_view.view_by_character_number[2]
	var moved := _solo_snapshot()
	moved["characters"][1]["cell"] = Vector2(10, 2)
	_render(moved)
	assert_that(_battle_view.view_by_character_number[2]).is_same(before_view)
	assert_that(_battle_view.view_by_character_number[2].position).is_equal(Map.to_pixel_continuous(Vector2(10, 2)))

func test_목록에서_사라진_캐릭터의_뷰는_지운다() -> void:
	_render(_solo_snapshot())
	var without_npc := _solo_snapshot()
	without_npc["characters"].remove_at(1)
	_render(without_npc)
	assert_int(_battle_view.view_by_character_number.size()).is_equal(1)
	assert_bool(_battle_view.view_by_character_number.has(2)).is_false()

func test_물풍선은_놓은_자리에_따라_다른_텍스쳐다() -> void:
	var snapshot := _local_multi_snapshot()
	snapshot["water_balloons"] = [
		{"cell": Vector2i(1, 6), "owner_number": 1},
		{"cell": Vector2i(4, 9), "owner_number": 3},
		{"cell": Vector2i(8, 2), "owner_number": 2},
	]
	_render(snapshot)
	var views := _battle_view.water_balloon_views.get_children()
	assert_int(views.size()).is_equal(3)
	assert_object(views[0].texture).is_equal(BattleView.PLAYER_WATER_BALLOON_TEXTURE)
	assert_object(views[1].texture).is_equal(BattleView.SECOND_PLAYER_WATER_BALLOON_TEXTURE)
	assert_object(views[2].texture).is_equal(BattleView.NPC_WATER_BALLOON_TEXTURE)
	assert_that(views[0].position).is_equal(Map.to_pixel(Vector2i(1, 6)))

func test_물줄기는_방향에_맞게_돌려_그린다() -> void:
	var snapshot := _solo_snapshot()
	snapshot["water_streams"] = [
		{"cell": Vector2i(3, 5), "direction": Vector2i.ZERO, "position_type": "center"},
		{"cell": Vector2i(3, 4), "direction": Vector2i.UP, "position_type": "end"},
		{"cell": Vector2i(4, 5), "direction": Vector2i.RIGHT, "position_type": "straight"},
	]
	_render(snapshot)
	var views := _battle_view.water_stream_views.get_children()
	assert_int(views.size()).is_equal(3)
	assert_object(views[0].texture).is_equal(BattleView.WATER_STREAM_TEXTURES["center"])
	assert_float(views[1].rotation_degrees).is_equal(0.0)
	assert_float(views[2].rotation_degrees).is_equal(90.0)

func test_게임_아이템은_종류에_맞는_텍스쳐다() -> void:
	var snapshot := _solo_snapshot()
	snapshot["game_items"] = [
		{"cell": Vector2i(5, 4), "type": GameItem.INCREASE_WATER_BALLOON_COUNT},
		{"cell": Vector2i(9, 9), "type": GameItem.INCREASE_SPEED},
	]
	_render(snapshot)
	var views := _battle_view.game_item_views.get_children()
	assert_object(views[0].texture).is_equal(BattleView.GAME_ITEM_WATER_BALLOON_TEXTURE)
	assert_object(views[1].texture).is_equal(BattleView.GAME_ITEM_SPEED_TEXTURE)

# 승패
func test_내_색이_이기면_WIN을_표시하고_지면_LOSE를_표시한다() -> void:
	var won := _solo_snapshot()
	won["winner_color"] = Color.RED
	_render(won)
	assert_bool(_battle_view.win_label.visible).is_true()
	assert_bool(_battle_view.lose_label.visible).is_false()
	var lost := _solo_snapshot()
	lost["winner_color"] = Team.MONSTER_COLOR
	_render(lost)
	assert_bool(_battle_view.win_label.visible).is_false()
	assert_bool(_battle_view.lose_label.visible).is_true()

func test_탈락해도_내_색을_알아서_LOSE를_그린다() -> void:
	var lost := _solo_snapshot()
	lost["characters"].remove_at(0)
	lost["seats"][0]["is_out"] = true
	lost["winner_color"] = Team.MONSTER_COLOR
	_render(lost)
	assert_bool(_battle_view.lose_label.visible).is_true()

func test_로컬_멀티에서는_몇_P가_이겼는지_적는다() -> void:
	var snapshot := _local_multi_snapshot()
	snapshot["winner_color"] = Color.GREEN
	_render(snapshot)
	assert_str(_battle_view.win_label.text).is_equal("2P WIN!!")

# 나는 로컬 멀티로 1P(빨강)와 2P(초록)를, 다른 피어는 노랑을 조종한다.
func _local_multi_against_other_peer_snapshot(winner: Color) -> Dictionary:
	var snapshot := _solo_snapshot()
	snapshot["characters"] = [_character(3, Vector2(7, 11), Color.YELLOW)]
	snapshot["seats"] = [
		_seat(1, Color.RED, MY_PEER, false, true),
		_seat(2, Color.GREEN, MY_PEER, false, true),
		_seat(3, Color.YELLOW, OTHER_PEER),
	]
	snapshot["winner_color"] = winner
	return snapshot

func test_로컬_멀티에서_다른_피어가_이기면_LOSE를_표시한다() -> void:
	_render(_local_multi_against_other_peer_snapshot(Color.YELLOW))
	assert_bool(_battle_view.win_label.visible).is_false()
	assert_bool(_battle_view.lose_label.visible).is_true()

func test_다른_피어가_있어도_로컬_멀티에서_내_1P가_이기면_1P_WIN을_표시한다() -> void:
	_render(_local_multi_against_other_peer_snapshot(Color.RED))
	assert_bool(_battle_view.win_label.visible).is_true()
	assert_str(_battle_view.win_label.text).is_equal("1P WIN!!")
	assert_bool(_battle_view.lose_label.visible).is_false()

func test_다른_피어가_있어도_로컬_멀티에서_내_2P가_이기면_2P_WIN을_표시한다() -> void:
	_render(_local_multi_against_other_peer_snapshot(Color.GREEN))
	assert_bool(_battle_view.win_label.visible).is_true()
	assert_str(_battle_view.win_label.text).is_equal("2P WIN!!")
	assert_bool(_battle_view.lose_label.visible).is_false()

func test_무승부면_무승부_라벨만_보인다() -> void:
	var snapshot := _solo_snapshot()
	snapshot["is_draw"] = true
	_render(snapshot)
	assert_bool(_battle_view.draw_label.visible).is_true()
	assert_bool(_battle_view.win_label.visible).is_false()

# 입력
func test_남의_캐릭터_자리는_내_것으로_치지_않는다() -> void:
	_render(_solo_snapshot(), OTHER_PEER)
	assert_array(_battle_view.my_character_numbers()).is_empty()

func test_방향키를_누르면_내_캐릭터를_그_방향으로_이동시킨다() -> void:
	_render(_solo_snapshot())
	var sent: Array = []
	_battle_view.move_requested.connect(func(number: int, d: Vector2i) -> void: sent.append([number, d]))
	_battle_view.handle_key_pressed(KEY_UP)
	assert_array(sent).is_equal([[1, Vector2i.UP]])

func test_같은_방향을_유지하면_이동_방향_요청을_다시_보내지_않는다() -> void:
	_render(_solo_snapshot())
	var sent: Array = []
	_battle_view.move_requested.connect(func(number: int, d: Vector2i) -> void: sent.append([number, d]))
	_battle_view.handle_key_pressed(KEY_UP)
	_battle_view.handle_key_pressed(KEY_UP)
	assert_int(sent.size()).is_equal(1)
	_battle_view.handle_key_released(KEY_UP)
	assert_array(sent).is_equal([[1, Vector2i.UP], [1, Vector2i.ZERO]])

func test_로컬_멀티에서는_1P는_RFDG로_움직이고_2P는_방향키로_움직인다() -> void:
	_render(_local_multi_snapshot())
	var sent: Array = []
	_battle_view.move_requested.connect(func(number: int, d: Vector2i) -> void: sent.append([number, d]))
	_battle_view.handle_key_pressed(KEY_R)
	_battle_view.handle_key_pressed(KEY_RIGHT)
	assert_array(sent).is_equal([[1, Vector2i.UP], [3, Vector2i.RIGHT]])

func test_혼자일_때는_스페이스로_물풍선을_놓는다() -> void:
	_render(_solo_snapshot())
	var sent: Array = []
	_battle_view.water_balloon_requested.connect(func(number: int) -> void: sent.append(number))
	_battle_view.handle_key_pressed(KEY_SPACE)
	assert_array(sent).is_equal([1])

func test_로컬_멀티에서는_좌우_시프트로_각자_물풍선을_놓는다() -> void:
	_render(_local_multi_snapshot())
	var sent: Array = []
	_battle_view.water_balloon_requested.connect(func(number: int) -> void: sent.append(number))
	_battle_view.handle_key_pressed(KEY_SHIFT, KEY_LOCATION_LEFT)
	_battle_view.handle_key_pressed(KEY_SHIFT, KEY_LOCATION_RIGHT)
	assert_array(sent).is_equal([1, 3])

# 예측
func _drawn_x(number: int) -> float:
	return _battle_view.view_by_character_number[number].position.x

func _walk(direction_key: Key, frames: int) -> void:
	_battle_view.handle_key_pressed(direction_key)
	for i in frames:
		_battle_view.tick(0.02)

func test_예측을_켜면_새_스냅샷_없이도_내_캐릭터가_누른_방향으로_움직인다() -> void:
	_render(_solo_snapshot())
	_walk(KEY_RIGHT, 5)
	assert_float(_drawn_x(1)).is_greater(Map.to_pixel_continuous(Vector2(3, 5)).x)

func test_남의_캐릭터는_예측하지_않는다() -> void:
	_render(_solo_snapshot())
	_walk(KEY_RIGHT, 5)
	assert_float(_drawn_x(2)).is_equal(Map.to_pixel_continuous(Vector2(9, 2)).x)

func test_예측을_끄면_스냅샷이_올_때까지_움직이지_않는다() -> void:
	_battle_view.prediction_enabled = false
	_render(_solo_snapshot())
	_walk(KEY_RIGHT, 5)
	assert_float(_drawn_x(1)).is_equal(Map.to_pixel_continuous(Vector2(3, 5)).x)

func test_예측_중에_RTT만큼_늦은_스냅샷이_와도_내_캐릭터를_되돌리지_않는다() -> void:
	_battle_view.rtt = 0.1
	_render(_solo_snapshot())
	_walk(KEY_RIGHT, 10) # 0.2초 동안 0.8칸 → 3.8
	var late := _solo_snapshot()
	late["characters"][0]["cell"] = Vector2(3.4, 5) # 0.1초 전의 위치
	_render(late)
	assert_float(_drawn_x(1)).is_greater(Map.to_pixel_continuous(Vector2(3.7, 5)).x)

func test_F2로_예측을_끄고_켠다() -> void:
	_render(_solo_snapshot())
	_battle_view.handle_key_pressed(KEY_F2)
	assert_bool(_battle_view.prediction_enabled).is_false()
	_battle_view.handle_key_pressed(KEY_F2)
	assert_bool(_battle_view.prediction_enabled).is_true()

# 입력 지연 측정
func test_예측을_켜면_스냅샷_없이도_입력_지연이_재진다() -> void:
	_render(_solo_snapshot())
	_walk(KEY_RIGHT, 1)
	assert_int(_battle_view.input_latency.count()).is_equal(1)

func test_예측을_끄면_움직인_스냅샷이_와야_입력_지연이_재진다() -> void:
	_battle_view.prediction_enabled = false
	_render(_solo_snapshot())
	_walk(KEY_RIGHT, 1)
	assert_int(_battle_view.input_latency.count()).is_equal(0)
	var moved := _solo_snapshot()
	moved["characters"][0]["cell"] = Vector2(3.1, 5)
	_render(moved)
	assert_int(_battle_view.input_latency.count()).is_equal(1)

func test_탈락해서_맵에_없는_내_캐릭터는_입력_지연을_재지_않는다() -> void:
	var lost := _solo_snapshot()
	lost["characters"].remove_at(0)
	lost["seats"][0]["is_out"] = true
	_render(lost)
	_walk(KEY_RIGHT, 1)
	_render(_solo_snapshot()) # 다음 배틀에서 시작 칸에 다시 나타난다
	assert_int(_battle_view.input_latency.count()).is_equal(0)

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

func test_다시_그려도_같은_자리의_뷰는_살아남는다() -> void:
	_render(_solo_snapshot())
	var before_view: CharacterView = _battle_view.view_by_character_number[1]
	var moved := _solo_snapshot()
	moved["characters"][0]["cell"] = Vector2(4, 5)
	_render(moved)
	assert_that(_battle_view.view_by_character_number[1]).is_same(before_view)
	assert_that(_battle_view.view_by_character_number[1].position).is_equal(Map.to_pixel_continuous(Vector2(4, 5)))

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

extends GdUnitTestSuite

const SCENE_PATH := "res://scenes/room_view.tscn"
const MY_PEER := 11
const OTHER_PEER := 22

var _runner: GdUnitSceneRunner
var _room_view: RoomView

func before_test() -> void:
	_runner = scene_runner(SCENE_PATH)
	_room_view = _runner.scene()

func _snapshot() -> Dictionary:
	return {
		"id": "alpha-11112222",
		"mode": BattleMode.MONSTER,
		"can_battle_start": true,
		"local_multi_on": true,
		"seats": [
			{"number": 1, "color": Color.RED, "is_npc": false, "peer_id": MY_PEER},
			{"number": 2, "color": Color.GREEN, "is_npc": false, "peer_id": OTHER_PEER},
			{"number": 3, "color": Color.BLUE, "is_npc": true, "peer_id": 0},
		],
	}

func _seat_color(index: int) -> Color:
	return (_room_view.slot(index).material as ShaderMaterial).get_shader_parameter("color")

func test_자리_수만큼_슬롯을_그리고_남는_자리는_빈_칸으로_채운다() -> void:
	_room_view.render(_snapshot(), MY_PEER)
	assert_int(_room_view.slot_count()).is_equal(3)
	assert_int(_room_view.slots.get_child_count()).is_equal(RoomView.SEAT_COUNT)

func test_방_아이디_앞자리를_적는다() -> void:
	_room_view.render(_snapshot(), MY_PEER)
	assert_str(_room_view.room_id_label.text).is_equal("방 alpha-11")

func test_NPC_자리와_사람_자리를_다른_그림으로_그린다() -> void:
	_room_view.render(_snapshot(), MY_PEER)
	assert_object(_room_view.slot(0).texture).is_equal(RoomView.PLAYER_SLOT_TEXTURE)
	assert_object(_room_view.slot(2).texture).is_equal(RoomView.NPC_SLOT_TEXTURE)

func test_자리마다_그_자리의_색으로_칠한다() -> void:
	_room_view.render(_snapshot(), MY_PEER)
	assert_that(_seat_color(0)).is_equal(Color.RED)
	assert_that(_seat_color(1)).is_equal(Color.GREEN)
	assert_that(_seat_color(2)).is_equal(Color.BLUE)

func test_자리_이름표에_자리_번호와_NPC_를_적는다() -> void:
	_room_view.render(_snapshot(), MY_PEER)
	assert_str(_room_view.slot_label(0)).is_equal("1P")
	assert_str(_room_view.slot_label(1)).is_equal("2P")
	assert_str(_room_view.slot_label(2)).is_equal("NPC")

func test_시작할_수_없으면_시작_버튼이_잠긴다() -> void:
	var cannot_start := _snapshot()
	cannot_start["can_battle_start"] = false
	_room_view.render(cannot_start, MY_PEER)
	assert_bool(_room_view.start_button.disabled).is_true()
	_room_view.render(_snapshot(), MY_PEER)
	assert_bool(_room_view.start_button.disabled).is_false()

func test_협공배틀_모드면_모드_체크가_켜진다() -> void:
	_room_view.render(_snapshot(), MY_PEER)
	assert_bool(_room_view.monster_mode_check.button_pressed).is_true()
	var local_multi := _snapshot()
	local_multi["mode"] = BattleMode.LOCAL_MULTI
	_room_view.render(local_multi, MY_PEER)
	assert_bool(_room_view.monster_mode_check.button_pressed).is_false()

func test_로컬멀티_체크는_스냅샷이_정한다_방의_사람_수로_세지_않는다() -> void:
	var off := _snapshot()
	off["local_multi_on"] = false
	_room_view.render(off, MY_PEER)
	assert_bool(_room_view.local_multi_check.button_pressed).is_false()
	_room_view.render(_snapshot(), MY_PEER)
	assert_bool(_room_view.local_multi_check.button_pressed).is_true()

func test_RPC를_전달된_스냅샷으로도_그릴_수_있다() -> void:
	var wired: Dictionary = bytes_to_var(var_to_bytes(_snapshot()))
	_room_view.render(wired, MY_PEER)
	assert_int(_room_view.slot_count()).is_equal(3)
	assert_that(_seat_color(2)).is_equal(Color.BLUE)
	assert_bool(_room_view.monster_mode_check.button_pressed).is_true()

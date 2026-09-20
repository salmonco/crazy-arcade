extends GdUnitTestSuite

const SCENE_PATH := "res://scenes/lobby_view.tscn"

var _runner: GdUnitSceneRunner
var _lobby_view: LobbyView

func before_test() -> void:
	_runner = scene_runner(SCENE_PATH)
	_lobby_view = _runner.scene()

func _snapshot() -> Dictionary:
	return {
		"rooms": [
			{"id": "alpha-11112222", "character_count": 1, "mode": BattleMode.LOCAL_MULTI},
			{"id": "bravo-33334444", "character_count": 3, "mode": BattleMode.MONSTER},
		]
	}

func test_스냅샷의_방_수만큼_방_항목을_그린다() -> void:
	_lobby_view.render(_snapshot())
	assert_int(_lobby_view.room_count()).is_equal(2)

func test_방_항목에_아이디_앞자리와_인원수와_모드를_적는다() -> void:
	_lobby_view.render(_snapshot())
	assert_str(_lobby_view.room_entry(0).text).is_equal("방 alpha-11\n1 / 4  ·  로컬멀티")
	assert_str(_lobby_view.room_entry(1).text).is_equal("방 bravo-33\n3 / 4  ·  협공배틀")

func test_다시_그리면_이전_방_항목이_남지_않는다() -> void:
	_lobby_view.render(_snapshot())
	_lobby_view.render({"rooms": []})
	assert_int(_lobby_view.room_count()).is_equal(0)

func test_방_항목을_누르면_그_방의_아이디를_알린다() -> void:
	_lobby_view.render(_snapshot())
	var chosen: Array[String] = []
	_lobby_view.room_chosen.connect(func(room_id: String) -> void: chosen.append(room_id))
	_lobby_view.room_entry(1).pressed.emit()
	assert_array(chosen).is_equal(["bravo-33334444"])

func test_RPC를_전달된_스냅샷으로도_모드_이름을_찾는다() -> void:
	var wired: Dictionary = bytes_to_var(var_to_bytes(_snapshot()))
	_lobby_view.render(wired)
	assert_str(_lobby_view.room_entry(1).text).is_equal("방 bravo-33\n3 / 4  ·  협공배틀")

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
			{"id": "alpha-11112222", "character_count": 1, "mode": BattleMode.LOCAL_MULTI, "status": RoomStatus.WAITING},
			{"id": "bravo-33334444", "character_count": 4, "mode": BattleMode.MONSTER, "status": RoomStatus.FULL},
		]
	}

func test_스냅샷의_방_수만큼_방_항목을_그린다() -> void:
	_lobby_view.render(_snapshot())
	assert_int(_lobby_view.room_count()).is_equal(2)

func test_방_항목에_아이디_앞자리와_인원수와_모드와_들어갈_수_없는_이유를_적는다() -> void:
	_lobby_view.render(_snapshot())
	assert_str(_lobby_view.room_entry(0).text).is_equal("방 alpha-11\n1 / 4  ·  로컬멀티")
	assert_str(_lobby_view.room_entry(1).text).is_equal("방 bravo-33\n4 / 4  ·  협공배틀  ·  꽉 참")

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
	assert_str(_lobby_view.room_entry(1).text).is_equal("방 bravo-33\n4 / 4  ·  협공배틀  ·  꽉 참")
	assert_bool(_lobby_view.room_entry(1).disabled).is_true()

func test_들어갈_수_없는_방_항목은_누를_수_없다() -> void:
	_lobby_view.render(_snapshot())
	assert_bool(_lobby_view.room_entry(0).disabled).is_false()
	assert_bool(_lobby_view.room_entry(1).disabled).is_true()

func test_들어갈_수_없는_방_항목도_방_항목과_같은_틀로_그린다() -> void:
	_lobby_view.render(_snapshot())
	var entry := _lobby_view.room_entry(1)
	var normal := entry.get_theme_stylebox("normal") as StyleBoxFlat
	assert_object(entry.get_theme_stylebox("disabled")).is_instanceof(StyleBoxFlat)
	var disabled := entry.get_theme_stylebox("disabled") as StyleBoxFlat
	if disabled == null:
		return
	assert_float(disabled.content_margin_left).is_equal(normal.content_margin_left)
	assert_float(disabled.content_margin_top).is_equal(normal.content_margin_top)
	assert_int(disabled.corner_radius_top_left).is_equal(normal.corner_radius_top_left)

func test_들어갈_수_없는_방_항목은_들어갈_수_있는_방과_달라_보인다() -> void:
	_lobby_view.render(_snapshot())
	var entry := _lobby_view.room_entry(1)
	var normal := entry.get_theme_stylebox("normal") as StyleBoxFlat
	assert_object(entry.get_theme_stylebox("disabled")).is_instanceof(StyleBoxFlat)
	var disabled := entry.get_theme_stylebox("disabled") as StyleBoxFlat
	if disabled == null:
		return
	assert_that(disabled.bg_color).is_not_equal(normal.bg_color)
	assert_that(entry.get_theme_color("font_disabled_color")).is_not_equal(entry.get_theme_color("font_color"))

func test_배틀_중인_방_항목에는_게임_중이라고_적고_누를_수_없다() -> void:
	_lobby_view.render({"rooms": [
		{"id": "charlie-5556666", "character_count": 2, "mode": BattleMode.LOCAL_MULTI, "status": RoomStatus.PLAYING},
	]})
	assert_str(_lobby_view.room_entry(0).text).is_equal("방 charlie-\n2 / 4  ·  로컬멀티  ·  게임 중")
	assert_bool(_lobby_view.room_entry(0).disabled).is_true()

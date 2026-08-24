extends GdUnitTestSuite

const SCENE_PATH := "res://scenes/battle_view.tscn"

var _runner: GdUnitSceneRunner
var _battle_view: BattleView

func before_test() -> void:
	_runner = scene_runner(SCENE_PATH)
	_battle_view = _runner.scene()
	_battle_view.start_battle(BattleMode.LOCAL_MULTI)

func test_씬을_띄우기만_하면_배틀이_시작되지_않는다() -> void:
	var runner := scene_runner(SCENE_PATH)
	var battle_view: BattleView = runner.scene()
	assert_that(battle_view.battle).is_null()

func test_밖에서_만든_배틀을_받아_그린다() -> void:
	var runner := scene_runner(SCENE_PATH)
	var battle_view: BattleView = runner.scene()
	var map := Map.new()
	map.add_character(Character.new(Vector2i(3, 5), 1, Color.RED))
	map.add_character(Character.new(Vector2i(9, 2), 2, Color.BLUE))
	var battle := Battle.new(map, BattleMode.LOCAL_MULTI)
	battle_view.show_battle(battle)
	assert_that(battle_view.battle).is_equal(battle)
	assert_that(battle_view.first_character).is_equal(map.characters()[0])
	assert_int(battle_view.view_by_character.size()).is_equal(2)

func test_1P와_2P를_맵에_들어간_순서가_아니라_자리_번호로_찾는다() -> void:
	var runner := scene_runner(SCENE_PATH)
	var battle_view: BattleView = runner.scene()
	var map := Map.new()
	map.add_character(Character.new(Vector2i(9, 2), 2, Color.BLUE))
	map.add_character(Character.new(Vector2i(3, 5), 1, Color.RED))
	battle_view.show_battle(Battle.new(map, BattleMode.LOCAL_MULTI))
	assert_int(battle_view.first_character.number).is_equal(1)
	assert_int(battle_view.second_character.number).is_equal(2)

func test_배틀_화면을_숨기면_승패_라벨도_숨는다() -> void:
	_battle_view.win_label.visible = true
	_battle_view.visible = false
	assert_bool(_battle_view.win_label.is_visible_in_tree()).is_false()
	_battle_view.visible = true
	assert_bool(_battle_view.win_label.is_visible_in_tree()).is_true()

func test_배틀이_없으면_tick해도_아무_일도_일어나지_않는다() -> void:
	var runner := scene_runner(SCENE_PATH)
	var battle_view: BattleView = runner.scene()
	battle_view.tick(4.0)
	assert_that(battle_view.battle).is_null()

# 캐릭터 이동
func test_시작_시_캐릭터가_맵의_시작_칸에_위치한다() -> void:
	var view: CharacterView = _battle_view.view_by_character[_battle_view.second_character]
	assert_vector(view.position).is_equal(_battle_view.second_character.pixel_position())

func test_캐릭터가_이동하면_뷰가_새_칸을_따라온다() -> void:
	var start_cell := _battle_view.second_character.position()
	_battle_view.second_character.move(Vector2i.RIGHT, 0.25, [])
	_battle_view.tick(0.25)
	var moved_cell := _battle_view.second_character.position()
	assert_vector(moved_cell).is_not_equal(start_cell)
	var view: CharacterView = _battle_view.view_by_character[_battle_view.second_character]
	assert_vector(view.position).is_equal(Map.to_pixel(moved_cell))

func test_키보드_방향키_입력을_떼면_캐릭터가_이동하지_않는다() -> void:
	var start_cell := _battle_view.second_character.position()
	var view: CharacterView = _battle_view.view_by_character[_battle_view.second_character]
	_battle_view.handle_key_pressed(KEY_LEFT)
	_battle_view.tick(0.25)
	_battle_view.handle_key_released(KEY_LEFT)
	_battle_view.tick(0.25)
	assert_vector(view.position).is_equal(Map.to_pixel(start_cell + Vector2i.LEFT))

func test_캐릭터는_방향을_바꿔도_연속으로_이동할_수_있다() -> void:
	var start_cell := _battle_view.second_character.position()
	var view: CharacterView = _battle_view.view_by_character[_battle_view.second_character]
	_battle_view.handle_key_pressed(KEY_LEFT)
	_battle_view.tick(0.25)
	_battle_view.handle_key_pressed(KEY_DOWN)
	_battle_view.tick(0.25)
	_battle_view.handle_key_released(KEY_LEFT)
	_battle_view.tick(0.25)
	assert_vector(view.position).is_equal(Map.to_pixel(start_cell + Vector2i.LEFT + Vector2i.DOWN * 2))

# 물풍선 놓기
func test_키보드_스페이스_바를_누르면_캐릭터가_물풍선을_놓는다() -> void:
	_battle_view.start_battle(BattleMode.MONSTER)
	_battle_view.handle_key_pressed(KEY_SPACE)
	_battle_view.tick(0.1)
	var views := _battle_view.water_balloon_views.get_children()
	assert_vector((views[0] as Sprite2D).position).is_equal(_battle_view.second_character.pixel_position())

func test_서로_다른_두_칸에_물풍선을_놓으면_물풍선이_두_개_그려진다() -> void:
	_battle_view.start_battle(BattleMode.MONSTER)
	_battle_view.handle_key_pressed(KEY_SPACE)
	_battle_view.tick(0.1)
	_battle_view.second_character.move(Vector2i.RIGHT, 0.25, [])
	_battle_view.second_character.get_game_item(GameItem.INCREASE_WATER_BALLOON_COUNT)
	_battle_view.handle_key_pressed(KEY_SPACE)
	_battle_view.tick(0.1)
	assert_int(_battle_view.water_balloon_views.get_child_count()).is_equal(2)

# 물풍선 터지기
func test_시간이_다_지나면_물풍선이_화면에서_사라진다() -> void:
	_battle_view.start_battle(BattleMode.LOCAL_MULTI)
	_battle_view.handle_key_pressed(KEY_SHIFT, KEY_LOCATION_RIGHT)
	_battle_view.tick(0.1)
	assert_int(_battle_view.water_balloon_views.get_child_count()).is_equal(1)
	_battle_view.tick(WaterBalloon.POP_AFTER_SECONDS * 1.5)
	assert_int(_battle_view.water_balloon_views.get_child_count()).is_equal(0)

func test_시간이_다_지나지_않으면_물풍선이_화면에서_사라지지_않는다() -> void:
	_battle_view.start_battle(BattleMode.LOCAL_MULTI)
	_battle_view.handle_key_pressed(KEY_SHIFT, KEY_LOCATION_RIGHT)
	_battle_view.tick(0.1)
	assert_int(_battle_view.water_balloon_views.get_child_count()).is_equal(1)
	_battle_view.tick(WaterBalloon.POP_AFTER_SECONDS * 0.5)
	assert_int(_battle_view.water_balloon_views.get_child_count()).is_equal(1)

# 물줄기 보이기
func test_물풍선_하나가_터질_때_물줄기가_5칸_보인다() -> void:
	_battle_view.start_battle(BattleMode.MONSTER)
	_battle_view.handle_key_pressed(KEY_SPACE)
	_battle_view.tick(WaterBalloon.POP_AFTER_SECONDS)
	assert_int(_battle_view.water_stream_views.get_child_count()).is_equal(5)

func test_물줄기_방향에_맞는_텍스쳐가_보인다() -> void:
	_battle_view.start_battle(BattleMode.MONSTER)
	_battle_view.handle_key_pressed(KEY_SPACE)
	_battle_view.tick(WaterBalloon.POP_AFTER_SECONDS)
	var cells := {}
	for view: Sprite2D in _battle_view.water_stream_views.get_children():
		cells[view.position] = view.texture
	var center_cell := _battle_view.second_character.position()
	assert_that(cells[Map.to_pixel_center(center_cell)]).is_equal(_battle_view.WATER_STREAM_TEXTURES["center"])
	assert_that(cells[Map.to_pixel_center(center_cell + Vector2i.UP)]).is_equal(_battle_view.WATER_STREAM_TEXTURES["end"])
	assert_that(cells[Map.to_pixel_center(center_cell + Vector2i.DOWN)]).is_equal(_battle_view.WATER_STREAM_TEXTURES["end"])
	assert_that(cells[Map.to_pixel_center(center_cell + Vector2i.LEFT)]).is_equal(_battle_view.WATER_STREAM_TEXTURES["end"])
	assert_that(cells[Map.to_pixel_center(center_cell + Vector2i.RIGHT)]).is_equal(_battle_view.WATER_STREAM_TEXTURES["end"])

# 물방울에 갇힘
func test_캐릭터는_물줄기를_맞으면_물방울에_갇혀_보인다() -> void:
	_battle_view.start_battle(BattleMode.MONSTER)
	_battle_view.handle_key_pressed(KEY_SPACE)
	_battle_view.tick(WaterBalloon.POP_AFTER_SECONDS)
	var view: CharacterView = _battle_view.view_by_character[_battle_view.second_character]
	assert_str(view.animation).is_equal("bubble")

# 자동 아웃
func test_아웃된_캐릭터는_화면에서_사라진다() -> void:
	var original_count = _battle_view.character_views.get_child_count()
	_battle_view.battle.get_map().let_character_out(_battle_view.second_character)
	_battle_view.tick(0.1)
	assert_int(_battle_view.character_views.get_child_count()).is_equal(original_count - 1)

# 게임 오버
func test_몬스터_모드에서_게임에서_지면_졌다는_텍스트가_표시된다() -> void:
	_battle_view.start_battle(BattleMode.MONSTER)
	_battle_view.tick(0.1)
	assert_bool(_battle_view.lose_label.visible).is_false()
	assert_bool(_battle_view.win_label.visible).is_false()
	assert_bool(_battle_view.draw_label.visible).is_false()
	_battle_view.battle.get_map().let_character_out(_battle_view.second_character)
	_battle_view.tick(0.1)
	assert_bool(_battle_view.lose_label.visible).is_true()
	assert_bool(_battle_view.win_label.visible).is_false()
	assert_bool(_battle_view.draw_label.visible).is_false()
	_battle_view.battle.get_map().let_character_out(_battle_view.first_character)
	_battle_view.tick(0.1)
	assert_bool(_battle_view.lose_label.visible).is_true()
	assert_bool(_battle_view.win_label.visible).is_false()
	assert_bool(_battle_view.draw_label.visible).is_false()

func test_로컬멀티_모드에서_한_명이_이기면_해당_캐릭터가_이겼다는_텍스트가_표시된다() -> void:
	_battle_view.start_battle(BattleMode.LOCAL_MULTI)
	_battle_view.tick(0.1)
	assert_bool(_battle_view.win_label.visible).is_false()
	assert_bool(_battle_view.lose_label.visible).is_false()
	assert_bool(_battle_view.draw_label.visible).is_false()
	_battle_view.battle.get_map().let_character_out(_battle_view.second_character)
	_battle_view.tick(0.1)
	assert_bool(_battle_view.win_label.visible).is_true()
	assert_str(_battle_view.win_label.text).contains("1P")
	assert_bool(_battle_view.lose_label.visible).is_false()
	assert_bool(_battle_view.draw_label.visible).is_false()
	_battle_view.battle.get_map().let_character_out(_battle_view.first_character)
	_battle_view.tick(0.1)
	assert_bool(_battle_view.win_label.visible).is_true()
	assert_str(_battle_view.win_label.text).contains("1P")
	assert_bool(_battle_view.lose_label.visible).is_false()
	assert_bool(_battle_view.draw_label.visible).is_false()

# 게임 아이템
func test_게임_시작_시_맵의_특정_위치에_게임_아이템이_표시된다() -> void:
	assert_that((_battle_view.game_item_views.get_child(0) as Sprite2D).texture).is_equal(_battle_view.GAME_ITEM_WATER_BALLOON_TEXTURE)

# 로컬 멀티플레이어
func test_키보드_위쪽_방향키를_누르면_2P_플레이어가_위쪽_방향으로_보인다() -> void:
	_battle_view.start_battle(BattleMode.LOCAL_MULTI)
	_battle_view.tick(0.1)
	assert_vector(_battle_view.second_character.facing).is_not_equal(Vector2i.UP)
	_battle_view.handle_key_pressed(KEY_UP)
	_battle_view.tick(0.1)
	assert_vector(_battle_view.second_character.facing).is_equal(Vector2i.UP)

func test_키보드_아래쪽_방향키를_누르면_2P_플레이어가_아래쪽_방향으로_보인다() -> void:
	_battle_view.start_battle(BattleMode.LOCAL_MULTI)
	_battle_view.handle_key_pressed(KEY_DOWN)
	_battle_view.tick(0.1)
	assert_vector(_battle_view.second_character.facing).is_equal(Vector2i.DOWN)

func test_키보드_왼쪽_방향키를_누르면_2P_플레이어가_왼쪽_방향으로_보인다() -> void:
	_battle_view.start_battle(BattleMode.LOCAL_MULTI)
	_battle_view.tick(0.1)
	assert_vector(_battle_view.second_character.facing).is_not_equal(Vector2i.LEFT)
	_battle_view.handle_key_pressed(KEY_LEFT)
	_battle_view.tick(0.1)
	assert_vector(_battle_view.second_character.facing).is_equal(Vector2i.LEFT)

func test_키보드_오른쪽_방향키를_누르면_2P_플레이어가_오른쪽_방향으로_보인다() -> void:
	_battle_view.start_battle(BattleMode.LOCAL_MULTI)
	_battle_view.tick(0.1)
	assert_vector(_battle_view.second_character.facing).is_not_equal(Vector2i.RIGHT)
	_battle_view.handle_key_pressed(KEY_RIGHT)
	_battle_view.tick(0.1)
	assert_vector(_battle_view.second_character.facing).is_equal(Vector2i.RIGHT)

func test_키보드_오른쪽_시프트_키를_누르면_2P_플레이어가_물풍선을_놓도록_보인다() -> void:
	_battle_view.start_battle(BattleMode.LOCAL_MULTI)
	_battle_view.tick(0.1)
	assert_int(_battle_view.water_balloon_views.get_child_count()).is_equal(0)
	_battle_view.handle_key_pressed(KEY_SHIFT, KEY_LOCATION_RIGHT)
	_battle_view.tick(0.1)
	assert_int(_battle_view.water_balloon_views.get_child_count()).is_equal(1)

func test_키보드_R_키를_누르면_1P_플레이어가_위쪽_방향으로_보인다() -> void:
	_battle_view.start_battle(BattleMode.LOCAL_MULTI)
	_battle_view.tick(0.1)
	assert_vector(_battle_view.first_character.facing).is_not_equal(Vector2i.UP)
	_battle_view.handle_key_pressed(KEY_R)
	_battle_view.tick(0.1)
	assert_vector(_battle_view.first_character.facing).is_equal(Vector2i.UP)

func test_키보드_F_키를_누르면_1P_플레이어가_아래쪽_방향으로_보인다() -> void:
	_battle_view.start_battle(BattleMode.LOCAL_MULTI)
	_battle_view.handle_key_pressed(KEY_F)
	_battle_view.tick(0.1)
	assert_vector(_battle_view.first_character.facing).is_equal(Vector2i.DOWN)

func test_키보드_D_키를_누르면_1P_플레이어가_왼쪽_방향으로_보인다() -> void:
	_battle_view.start_battle(BattleMode.LOCAL_MULTI)
	_battle_view.tick(0.1)
	assert_vector(_battle_view.first_character.facing).is_not_equal(Vector2i.LEFT)
	_battle_view.handle_key_pressed(KEY_D)
	_battle_view.tick(0.1)
	assert_vector(_battle_view.first_character.facing).is_equal(Vector2i.LEFT)

func test_키보드_G_키를_누르면_1P_플레이어가_오른쪽_방향으로_보인다() -> void:
	_battle_view.start_battle(BattleMode.LOCAL_MULTI)
	_battle_view.tick(0.1)
	assert_vector(_battle_view.first_character.facing).is_not_equal(Vector2i.RIGHT)
	_battle_view.handle_key_pressed(KEY_G)
	_battle_view.tick(0.1)
	assert_vector(_battle_view.first_character.facing).is_equal(Vector2i.RIGHT)

func test_키보드_왼쪽_시프트_키를_누르면_1P_플레이어가_물풍선을_놓도록_보인다() -> void:
	_battle_view.start_battle(BattleMode.LOCAL_MULTI)
	_battle_view.tick(0.1)
	assert_int(_battle_view.water_balloon_views.get_child_count()).is_equal(0)
	_battle_view.handle_key_pressed(KEY_SHIFT, KEY_LOCATION_LEFT)
	_battle_view.tick(0.1)
	assert_int(_battle_view.water_balloon_views.get_child_count()).is_equal(1)

# 캐릭터 색상
func test_캐릭터의_색상에_맞게_뷰의_쉐이더_색상이_적용된다() -> void:
	_battle_view.start_battle(BattleMode.LOCAL_MULTI)
	_battle_view.tick(0.1)
	var first_view := _battle_view.view_by_character[_battle_view.first_character]
	var second_view := _battle_view.view_by_character[_battle_view.second_character]
	assert_that((first_view.material as ShaderMaterial).get_shader_parameter("color")).is_equal(Color.RED)
	assert_that((second_view.material as ShaderMaterial).get_shader_parameter("color")).is_equal(Color.BLUE)

func test_캐릭터가_바라보는_방향의_마스크가_적용된다() -> void:
	_battle_view.start_battle(BattleMode.LOCAL_MULTI)
	_battle_view.tick(0.1)
	var second_view = _battle_view.view_by_character[_battle_view.second_character]
	_battle_view.handle_key_pressed(KEY_UP)
	_battle_view.tick(0.1)
	assert_that((second_view.material as ShaderMaterial).get_shader_parameter("mask_texture")).is_equal(second_view.masks["walk_up"])

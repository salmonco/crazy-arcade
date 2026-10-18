# 입력 지연을 예측 OFF(before)와 ON(after)으로 번갈아 재는 측정 봇.
#
#   사용법: godot --headless --path . -s tools/measure_latency.gd -- [--url wss://...] [--samples 20]
#     --url 이 없으면 project.godot 의 network/server_url (로컬 서버) 로 붙습니다.
#
# 클라이언트(game.tscn)를 그대로 띄워 방을 만들고 몬스터 모드로 배틀을 시작한 뒤,
# 좌우로 한 번씩 움직이며 "키를 누른 순간 → 내 캐릭터 뷰가 처음 움직인 순간"을 잽니다.
# 브라우저와 같게 60fps로 돕니다. 화면 출력(vsync) 지연은 OFF/ON 모두 같으므로 빠져 있습니다.
extends SceneTree

const HOLD_SECONDS := 0.25
const REST_SECONDS := 0.5

var _samples_per_mode := 20
var _game: Game
var _elapsed := 0.0
var _next_action_at := 1.0
var _holding: Key = KEY_NONE
var _next_key: Key = KEY_RIGHT
var _results: Dictionary[String, Array] = {}
var _setup_step := 0
# 키를 뗀 순간의 위치 → 다음에 누르기 직전의 위치. 키를 뗐는데도 더 간(미끄러진) 거리.
var _released_at := Vector2.INF
var _slides: Array[float] = []

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--url" and i + 1 < args.size():
			ProjectSettings.set_setting("network/server_url", args[i + 1])
		if args[i] == "--samples" and i + 1 < args.size():
			_samples_per_mode = int(args[i + 1])
	Engine.max_fps = 60
	_game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	root.add_child(_game)

func _process(delta: float) -> bool:
	_elapsed += delta
	if _elapsed < _next_action_at:
		return false
	if _elapsed > 600.0:
		print("시간 초과")
		return true
	if _game.peer_id == 0:
		_next_action_at = _elapsed + 0.5
		return false
	if not _game.battle_view.visible:
		_set_up_battle()
		return false
	return _step_battle()

func _set_up_battle() -> void:
	_release()
	match _setup_step:
		0:
			_game.create_room()
		1:
			_game.set_monster_mode(true)
		_:
			_game.start_battle()
	_setup_step += 1
	_next_action_at = _elapsed + 1.0

func _step_battle() -> bool:
	var view := _game.battle_view
	if _holding != KEY_NONE:
		_release()
		_next_action_at = _elapsed + REST_SECONDS
		return false
	if view.input_latency.count() >= _samples_per_mode:
		_results[_mode(view)] = [
			view.input_latency.average_msec(), view.input_latency.median_msec(), view.input_latency.count(), view.rtt,
		]
		_results[_mode(view)].append(_average(_slides))
		_slides.clear()
		if view.prediction_enabled:
			_report()
			return true
		view.toggle_prediction()
	if view.prediction_enabled and not _results.has("예측 OFF"):
		view.toggle_prediction() # 먼저 OFF(before)부터 잰다
	var my_number := _my_number()
	if _released_at != Vector2.INF and my_number in view.view_by_character_number:
		_slides.append(_released_at.distance_to(_drawn(my_number)))
	_holding = _next_key
	_next_key = KEY_LEFT if _next_key == KEY_RIGHT else KEY_RIGHT
	view.handle_key_pressed(_holding)
	_next_action_at = _elapsed + HOLD_SECONDS
	return false

func _release() -> void:
	if _holding == KEY_NONE:
		return
	_game.battle_view.handle_key_released(_holding)
	_holding = KEY_NONE
	var my_number := _my_number()
	_released_at = _drawn(my_number) if my_number in _game.battle_view.view_by_character_number else Vector2.INF

func _my_number() -> int:
	var numbers := _game.battle_view.my_character_numbers()
	return numbers[0] if not numbers.is_empty() else -1

func _drawn(number: int) -> Vector2:
	return _game.battle_view.view_by_character_number[number].position / Map.PIXELS_PER_CELL

func _mode(view: BattleView) -> String:
	return "예측 ON" if view.prediction_enabled else "예측 OFF"

func _average(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += value
	return total / values.size()

func _report() -> void:
	print("")
	print("| 모드 | 입력 지연 평균 | 중앙값 | 표본 | RTT | 키를 뗀 뒤 미끄러진 거리 |")
	print("|---|---|---|---|---|---|")
	for mode in ["예측 OFF", "예측 ON"]:
		var r: Array = _results[mode]
		print("| %s | %d ms | %d ms | %d | %d ms | %.2f 칸 |" % [mode, r[0], r[1], r[2], roundi(r[3] * 1000), r[4]])

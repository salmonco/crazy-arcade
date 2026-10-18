class_name Prediction
extends RefCounted

# 서버 위치와 이만큼(칸) 넘게 어긋나면 당기지 않고 바로 옮긴다. 배틀 시작, 순간이동 등.
const SNAP_DISTANCE := 1.0
# 스냅샷 한 번에 오차의 몇 할을 메우는가. 스냅샷은 초당 60번 오므로 0.2면 0.1초 안에 거의 다 메운다.
const CORRECTION_RATE := 0.2
# 이보다 오래된 기록은 버린다. RTT가 이보다 길면 가장 오래된 기록과 비교한다.
const HISTORY_SECONDS := 1.0

# 이동 규칙은 Character.move를 그대로 빌려 쓴다. 서버와 같은 규칙이어야 예측이 맞는다.
var _character: Character
var _clock := 0.0
# [시각, 위치]. 오래된 것부터.
var _history: Array[Array] = []

func _init(start_position: Vector2) -> void:
	_character = Character.new(Vector2i.ZERO)
	_character.continuous_position = start_position

func tick(delta: float, direction: Vector2i, water_balloon_positions: Array[Vector2i]) -> void:
	_clock += delta
	if direction != Vector2i.ZERO:
		_character.move(direction, delta, water_balloon_positions)
	_history.append([_clock, _character.continuous_position])
	while _history.size() > 1 and _history[0][0] < _clock - HISTORY_SECONDS:
		_history.pop_front()

func sync(is_trapped: bool, speed: float) -> void:
	_character.speed = speed
	if is_trapped and not _character.is_trapped():
		_character.trapped()
	elif not is_trapped and _character.is_trapped():
		_character.rescued()

# 서버가 보낸 위치는 내 입력이 RTT만큼 늦게 반영된 결과다.
# 그래서 지금 위치가 아니라 RTT만큼 과거의 예측 위치와 비교해야 한다.
func reconcile(server_position: Vector2, rtt: float) -> void:
	var error := server_position - _position_at(_clock - rtt)
	if error.length() > SNAP_DISTANCE:
		_character.continuous_position = server_position
		_history.clear()
		return
	var correction := error * CORRECTION_RATE
	_character.continuous_position += correction
	# 과거 기록도 같이 옮겨야 다음 스냅샷이 이미 메운 오차를 또 메우지 않는다.
	for record in _history:
		record[1] += correction

func position() -> Vector2:
	return _character.continuous_position

func _position_at(time: float) -> Vector2:
	if _history.is_empty():
		return _character.continuous_position
	if time <= _history[0][0]:
		return _history[0][1]
	for i in range(_history.size() - 1, 0, -1):
		var before: Array = _history[i - 1]
		var after: Array = _history[i]
		if before[0] <= time:
			var weight := clampf((time - before[0]) / (after[0] - before[0]), 0.0, 1.0)
			return (before[1] as Vector2).lerp(after[1], weight)
	return _history[0][1]

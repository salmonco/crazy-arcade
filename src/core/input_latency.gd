class_name InputLatency
extends RefCounted

# 자리 번호 → [키를 누른 시각, 그때의 위치]
var _pending: Dictionary[int, Array] = {}
var _samples: Array[int] = []

func start(number: int, position: Vector2, time_msec: int) -> void:
	_pending[number] = [time_msec, position]

# 위치가 처음 바뀐 순간이면 걸린 시간(ms)을, 아니면 -1을 돌려준다.
func observe(number: int, position: Vector2, time_msec: int) -> int:
	if number not in _pending:
		return -1
	var started_msec: int = _pending[number][0]
	var start_position: Vector2 = _pending[number][1]
	if position == start_position:
		return -1
	_pending.erase(number)
	var latency := time_msec - started_msec
	_samples.append(latency)
	return latency

func count() -> int:
	return _samples.size()

func average_msec() -> int:
	if _samples.is_empty():
		return 0
	var total := 0
	for sample in _samples:
		total += sample
	return total / _samples.size()

func median_msec() -> int:
	if _samples.is_empty():
		return 0
	var sorted := _samples.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]

func clear() -> void:
	_pending.clear()
	_samples.clear()

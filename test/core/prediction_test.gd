extends GdUnitTestSuite

const FRAME := 0.02

func _walk(prediction: Prediction, direction: Vector2i, frames: int, water_balloon_positions: Array[Vector2i] = []) -> void:
	for i in frames:
		prediction.tick(FRAME, direction, water_balloon_positions)

# 이동
func test_서버_응답_없이_바로_움직인다() -> void:
	var prediction := Prediction.new(Vector2(3, 5))
	prediction.tick(0.1, Vector2i.RIGHT, [])
	assert_float(prediction.position().x).is_greater(3.0)
	assert_float(prediction.position().y).is_equal(5.0)

func test_물풍선이_있는_칸으로는_들어가지_못한다() -> void:
	var prediction := Prediction.new(Vector2(3, 5))
	_walk(prediction, Vector2i.RIGHT, 50, [Vector2i(4, 5)])
	# 물풍선 칸 경계(3.5) 바로 앞까지는 간다
	assert_float(prediction.position().x).is_between(3.3, 3.5)

func test_갇히면_느리게_움직인다() -> void:
	var prediction := Prediction.new(Vector2(3, 5))
	prediction.sync(true, Character.SPEED)
	prediction.tick(0.5, Vector2i.RIGHT, [])
	# 평소 속도라면 2칸, 물방울 속도라면 0.5칸
	assert_float(prediction.position().x).is_between(3.25, 4.0)

func test_서버가_알려준_속도로_움직인다() -> void:
	var prediction := Prediction.new(Vector2(3, 5))
	prediction.sync(false, Character.SPEED + 2.0)
	prediction.tick(0.25, Vector2i.RIGHT, [])
	# 기본 속도라면 1칸, 빨라진 속도라면 1.5칸
	assert_float(prediction.position().x).is_greater(4.25)

# 보정
func test_서버_위치가_RTT만큼_과거의_예측과_같으면_보정하지_않는다() -> void:
	var prediction := Prediction.new(Vector2(3, 5))
	_walk(prediction, Vector2i.RIGHT, 10) # 0.2초 동안 0.8칸 → 3.8
	# 서버는 RTT(0.1초)만큼 과거의 위치를 알려준다: 0.1초 동안 0.4칸 → 3.4
	prediction.reconcile(Vector2(3.4, 5), 0.1)
	assert_float(prediction.position().x).is_greater(3.7)

func test_RTT만큼_과거의_예측과_어긋난_만큼_서버_쪽으로_당긴다() -> void:
	var prediction := Prediction.new(Vector2(3, 5))
	_walk(prediction, Vector2i.RIGHT, 10)
	# 서버에서는 0.4칸 덜 갔다 (예: 서버에만 있던 물풍선에 막힘)
	for i in 30:
		prediction.reconcile(Vector2(3.0, 5), 0.1)
	# 지금 위치 3.8에서 0.4칸 당겨진 3.4로 수렴한다. 서버 위치(3.0)까지 끌려가면 안 된다.
	assert_float(prediction.position().x).is_between(3.35, 3.45)
	assert_float(prediction.position().y).is_equal(5.0)

func test_크게_어긋나면_서버_위치로_바로_옮긴다() -> void:
	var prediction := Prediction.new(Vector2(3, 5))
	_walk(prediction, Vector2i.RIGHT, 10)
	prediction.reconcile(Vector2(10, 2), 0.1)
	assert_vector(prediction.position()).is_equal(Vector2(10, 2))

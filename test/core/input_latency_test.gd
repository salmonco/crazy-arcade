extends GdUnitTestSuite

func test_키를_누른_뒤_위치가_처음_바뀐_순간까지의_시간을_잰다() -> void:
	var latency := InputLatency.new()
	latency.start(1, Vector2(3, 5), 1000)
	assert_int(latency.observe(1, Vector2(3, 5), 1030)).is_equal(-1)
	assert_int(latency.observe(1, Vector2(3.1, 5), 1085)).is_equal(85)
	assert_int(latency.count()).is_equal(1)

func test_한_번_잰_뒤에는_다시_누를_때까지_재지_않는다() -> void:
	var latency := InputLatency.new()
	latency.start(1, Vector2(3, 5), 1000)
	latency.observe(1, Vector2(3.1, 5), 1085)
	assert_int(latency.observe(1, Vector2(3.2, 5), 1100)).is_equal(-1)
	assert_int(latency.count()).is_equal(1)

func test_다른_자리의_캐릭터가_움직인_것은_재지_않는다() -> void:
	var latency := InputLatency.new()
	latency.start(1, Vector2(3, 5), 1000)
	assert_int(latency.observe(3, Vector2(7, 11), 1050)).is_equal(-1)
	assert_int(latency.count()).is_equal(0)

func test_평균과_중앙값() -> void:
	var latency := InputLatency.new()
	for sample in [80, 100, 30]:
		latency.start(1, Vector2(3, 5), 1000)
		latency.observe(1, Vector2(4, 5), 1000 + sample)
	assert_int(latency.average_msec()).is_equal(70)
	assert_int(latency.median_msec()).is_equal(80)

func test_초기화하면_샘플을_버린다() -> void:
	var latency := InputLatency.new()
	latency.start(1, Vector2(3, 5), 1000)
	latency.observe(1, Vector2(4, 5), 1080)
	latency.clear()
	assert_int(latency.count()).is_equal(0)

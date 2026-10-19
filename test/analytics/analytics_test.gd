extends GdUnitTestSuite

var _posted: Array = []

func before_test() -> void:
	_posted = []

func _record(body: String) -> void:
	_posted.append(JSON.parse_string(body))

func _sent_device_ids() -> Array:
	return _posted.map(func(body: Dictionary) -> String: return body["events"][0]["device_id"])

func test_이벤트를_Amplitude_형식으로_보낸다() -> void:
	var analytics := Analytics.new("api-key-1", _record)
	analytics.register_device(11, "device-abc")
	analytics.track(11, "room_created", {"battle_mode": "monster"})
	assert_int(_posted.size()).is_equal(1)
	assert_str(_posted[0]["api_key"]).is_equal("api-key-1")
	var event: Dictionary = _posted[0]["events"][0]
	assert_str(event["device_id"]).is_equal("device-abc")
	assert_str(event["event_type"]).is_equal("room_created")
	assert_dict(event["event_properties"]).is_equal({"battle_mode": "monster"})

func test_피어마다_자기_기기_ID로_보낸다() -> void:
	var analytics := Analytics.new("api-key-1", _record)
	analytics.register_device(11, "device-eleven")
	analytics.register_device(22, "device-twenty-two")
	analytics.track(22, "room_created")
	analytics.track(11, "room_created")
	assert_array(_sent_device_ids()).contains_exactly(["device-twenty-two", "device-eleven"])

func test_API_키가_없으면_보내지_않는다() -> void:
	var analytics := Analytics.new("", _record)
	analytics.register_device(11, "device-abc")
	analytics.track(11, "room_created")
	assert_int(_posted.size()).is_equal(0)

func test_기기_ID를_모르는_피어의_이벤트는_보내지_않는다() -> void:
	var analytics := Analytics.new("api-key-1", _record)
	analytics.register_device(11, "device-abc")
	analytics.track(22, "room_created")
	assert_array(_sent_device_ids()).is_empty()

func test_잊은_피어의_이벤트는_보내지_않는다() -> void:
	var analytics := Analytics.new("api-key-1", _record)
	analytics.register_device(11, "device-abc")
	analytics.forget_device(11)
	analytics.track(11, "room_created")
	assert_array(_sent_device_ids()).is_empty()

func test_너무_긴_기기_ID는_받지_않는다() -> void:
	var analytics := Analytics.new("api-key-1", _record)
	analytics.register_device(11, "x".repeat(Analytics.MAX_DEVICE_ID_LENGTH + 1))
	analytics.register_device(22, "x".repeat(Analytics.MAX_DEVICE_ID_LENGTH))
	analytics.track(11, "room_created")
	analytics.track(22, "room_created")
	assert_int(_posted.size()).is_equal(1)

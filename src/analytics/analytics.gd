class_name Analytics
extends RefCounted

## 서버에서 Amplitude HTTP API로 이벤트를 보낸다.
## 피어가 어느 기기인지 기억했다가, 피어 ID로 받은 이벤트를 그 기기의 것으로 보낸다.
## 보내는 방법(post)은 밖에서 받는다. 실제로는 http_post를, 테스트에서는 기록용 Callable을 넣는다.

const ENDPOINT := "https://api2.amplitude.com/2/httpapi"
## 웹 빌드도 bin/build-web.sh가 이 값을 index.html에 끼워 넣는다. 키는 여기 한 곳에만 둔다.
const API_KEY_SETTING := "analytics/amplitude_api_key"
## 클라이언트가 보내는 값이라 길이를 막는다. Amplitude 기기 ID(UUID)는 36자.
const MAX_DEVICE_ID_LENGTH := 64

## export된 빌드에서만 키를 준다. 에디터, ./t, 로컬 실행에서는 빈 값이라 아무것도 보내지 않는다.
static func configured_api_key() -> String:
	if not OS.has_feature("template"):
		return ""
	return ProjectSettings.get_setting(API_KEY_SETTING, "")

## 클라이언트에서 쓴다. 웹에서만 Amplitude 브라우저 SDK(export_presets.cfg의 head_include)가
## 기기 ID를 준다. 웹이 아니거나 SDK가 아직 없으면 빈 값이고, 서버는 그 피어의 이벤트를 보내지 않는다.
static func browser_device_id() -> String:
	if not OS.has_feature("web"):
		return ""
	var device_id = JavaScriptBridge.eval("(window.amplitude && window.amplitude.getDeviceId()) || ''", true)
	return device_id if device_id is String else ""

## 실제 전송. HTTPRequest는 Node라서 붙일 부모(host)가 필요하다. 응답은 기다리지 않는다.
## 테스트가 지켜주지 않는 껍데기이니 늘리지 않는다.
static func http_post(body: String, host: Node) -> void:
	var request := HTTPRequest.new()
	host.add_child(request)
	request.request_completed.connect(func(_result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
		if code != 200:
			push_warning("analytics failed: %d" % code)
		request.queue_free())
	if request.request(ENDPOINT, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body) != OK:
		request.queue_free()

var _api_key: String
var _post: Callable
var _device_ids := {}

func _init(api_key: String = "", post: Callable = Callable()) -> void:
	_api_key = api_key
	_post = post

func register_device(peer_id: int, device_id: String) -> void:
	if device_id.length() > MAX_DEVICE_ID_LENGTH:
		return
	_device_ids[peer_id] = device_id

func forget_device(peer_id: int) -> void:
	_device_ids.erase(peer_id)

## 기기 ID를 모르는 피어(웹이 아닌 클라이언트)의 이벤트는 보내지 않는다.
func track(peer_id: int, event_type: String, properties: Dictionary = {}) -> void:
	var device_id: String = _device_ids.get(peer_id, "")
	if _api_key == "" or device_id == "" or not _post.is_valid():
		return
	_post.call(JSON.stringify({
		"api_key": _api_key,
		"events": [{
			"device_id": device_id,
			"event_type": event_type,
			"event_properties": properties,
		}],
	}))

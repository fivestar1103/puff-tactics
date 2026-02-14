extends Node

signal auth_state_changed(is_authenticated: bool, user_id: String, guest_id: String)
signal auth_token_refreshed(expires_at_unix: int)
signal apple_sign_in_requested

const AUTH_STORAGE_PATH: String = "user://auth/supabase_auth.dat"
const DEVICE_SECRET_PATH: String = "user://auth/device_secret.cfg"
const TOKEN_REFRESH_BUFFER_SECONDS: int = 60

const SETTINGS_SUPABASE_URL: String = "puff_tactics/supabase/url"
const SETTINGS_SUPABASE_PUBLISHABLE_KEY: String = "puff_tactics/supabase/publishable_key"

var _supabase_url: String = ""
var _publishable_key: String = ""

var _access_token: String = ""
var _refresh_token: String = ""
var _token_expires_at_unix: int = 0
var _authenticated_user_id: String = ""
var _guest_id: String = ""

var _refresh_timer: Timer


func _ready() -> void:
	_load_project_settings()
	_load_auth_state_securely()
	_ensure_guest_id()
	_setup_refresh_timer()
	_schedule_token_refresh()

	if _should_refresh_access_token():
		call_deferred("_refresh_access_token_deferred")

	_emit_auth_state_changed()


func configure(supabase_url: String, publishable_key: String) -> void:
	_supabase_url = _normalize_supabase_url(supabase_url)
	_publishable_key = publishable_key.strip_edges()


func is_configured() -> bool:
	return not _supabase_url.is_empty() and not _publishable_key.is_empty()


func get_guest_id() -> String:
	return _guest_id


func get_authenticated_user_id() -> String:
	return _authenticated_user_id


func has_authenticated_session() -> bool:
	if _access_token.is_empty():
		return false
	if _token_expires_at_unix <= 0:
		return false
	return int(Time.get_unix_time_from_system()) < _token_expires_at_unix


func sign_in_as_guest() -> String:
	_access_token = ""
	_refresh_token = ""
	_token_expires_at_unix = 0
	_authenticated_user_id = ""
	_ensure_guest_id()
	_schedule_token_refresh()
	_save_auth_state_securely()
	_emit_auth_state_changed()
	return _guest_id


func begin_apple_sign_in() -> Dictionary:
	emit_signal("apple_sign_in_requested")
	return {
		"ok": false,
		"error": "Apple Sign-In native flow is a stub. On iOS export, obtain an identity token via plugin and call sign_in_with_apple_identity_token().",
		"platform": OS.get_name()
	}


func sign_in_with_password(email: String, password: String) -> Dictionary:
	var payload: Dictionary = {
		"email": email.strip_edges(),
		"password": password
	}
	var response: Dictionary = await request_auth(
		HTTPClient.METHOD_POST,
		"token",
		{"grant_type": "password"},
		payload
	)
	if bool(response.get("ok", false)):
		_apply_auth_payload(response.get("data", {}))
	return response


func sign_in_with_apple_identity_token(identity_token: String, nonce: String = "") -> Dictionary:
	var cleaned_token: String = identity_token.strip_edges()
	if cleaned_token.is_empty():
		return _error_result(0, "Identity token is required for Apple Sign-In.")

	var payload: Dictionary = {
		"provider": "apple",
		"id_token": cleaned_token
	}
	if not nonce.is_empty():
		payload["nonce"] = nonce

	var response: Dictionary = await request_auth(
		HTTPClient.METHOD_POST,
		"token",
		{"grant_type": "id_token"},
		payload
	)
	if bool(response.get("ok", false)):
		_apply_auth_payload(response.get("data", {}))
	return response


func ensure_valid_access_token() -> bool:
	if has_authenticated_session() and not _should_refresh_access_token():
		return true

	if _refresh_token.is_empty():
		return false

	var refresh_result: Dictionary = await refresh_access_token()
	return bool(refresh_result.get("ok", false))


func refresh_access_token() -> Dictionary:
	if _refresh_token.is_empty():
		return _error_result(0, "No refresh token available.")

	var payload: Dictionary = {"refresh_token": _refresh_token}
	var response: Dictionary = await request_auth(
		HTTPClient.METHOD_POST,
		"token",
		{"grant_type": "refresh_token"},
		payload
	)
	if bool(response.get("ok", false)):
		_apply_auth_payload(response.get("data", {}))
		emit_signal("auth_token_refreshed", _token_expires_at_unix)
	return response


func sign_out() -> void:
	_access_token = ""
	_refresh_token = ""
	_token_expires_at_unix = 0
	_authenticated_user_id = ""
	_schedule_token_refresh()
	_save_auth_state_securely()
	_emit_auth_state_changed()


func request_rest(
	method: int,
	endpoint: String,
	query_params: Dictionary = {},
	body: Variant = null,
	extra_headers: Array[String] = []
) -> Dictionary:
	if not is_configured():
		return _error_result(
			0,
			"Supabase is not configured. Set %s and %s in project settings." % [
				SETTINGS_SUPABASE_URL,
				SETTINGS_SUPABASE_PUBLISHABLE_KEY
			]
		)

	await ensure_valid_access_token()

	var normalized_endpoint: String = endpoint.strip_edges().trim_prefix("/")
	var url: String = _build_url("rest/v1/%s" % normalized_endpoint, query_params)
	var headers: PackedStringArray = get_auth_headers(extra_headers)
	_append_header_if_missing(headers, "Accept", "application/json")

	var payload: String = ""
	if body != null:
		payload = JSON.stringify(body)
		_append_header_if_missing(headers, "Content-Type", "application/json")

	return await _execute_http_request(method, url, headers, payload)


func request_auth(
	method: int,
	endpoint: String,
	query_params: Dictionary = {},
	body: Variant = null,
	extra_headers: Array[String] = []
) -> Dictionary:
	if not is_configured():
		return _error_result(
			0,
			"Supabase is not configured. Set %s and %s in project settings." % [
				SETTINGS_SUPABASE_URL,
				SETTINGS_SUPABASE_PUBLISHABLE_KEY
			]
		)

	var normalized_endpoint: String = endpoint.strip_edges().trim_prefix("/")
	var url: String = _build_url("auth/v1/%s" % normalized_endpoint, query_params)
	var headers: PackedStringArray = get_auth_headers(extra_headers)
	_append_header_if_missing(headers, "Accept", "application/json")

	var payload: String = ""
	if body != null:
		payload = JSON.stringify(body)
		_append_header_if_missing(headers, "Content-Type", "application/json")

	return await _execute_http_request(method, url, headers, payload)


func get_auth_headers(extra_headers: Array[String] = []) -> PackedStringArray:
	var headers: PackedStringArray = PackedStringArray()
	if not _publishable_key.is_empty():
		headers.append("apikey: %s" % _publishable_key)

	var bearer_token: String = _access_token if not _access_token.is_empty() else _publishable_key
	if not bearer_token.is_empty():
		headers.append("Authorization: Bearer %s" % bearer_token)

	if not _guest_id.is_empty():
		headers.append("X-Guest-Id: %s" % _guest_id)

	for header in extra_headers:
		headers.append(header)

	return headers


func _build_url(path: String, query_params: Dictionary) -> String:
	var normalized_path: String = path.strip_edges().trim_prefix("/")
	var url: String = "%s/%s" % [_supabase_url, normalized_path]
	if query_params.is_empty():
		return url

	var http_client: HTTPClient = HTTPClient.new()
	var query_string: String = http_client.query_string_from_dict(query_params)
	if query_string.is_empty():
		return url
	return "%s?%s" % [url, query_string]


func _execute_http_request(
	method: int,
	url: String,
	headers: PackedStringArray,
	payload: String = ""
) -> Dictionary:
	var request: HTTPRequest = HTTPRequest.new()
	add_child(request)

	var request_error: int = request.request(url, headers, method, payload)
	if request_error != OK:
		request.queue_free()
		return _error_result(0, "Could not start HTTP request: %s" % error_string(request_error))

	var completed: Array = await request.request_completed
	request.queue_free()

	if completed.size() < 4:
		return _error_result(0, "HTTPRequest returned an unexpected response payload.")

	var transport_result: int = int(completed[0])
	var status_code: int = int(completed[1])
	var response_headers: PackedStringArray = completed[2]
	var body_bytes: PackedByteArray = completed[3]

	var response_text: String = body_bytes.get_string_from_utf8()
	var parsed_payload: Variant = {}
	if not response_text.is_empty():
		var parser: JSON = JSON.new()
		var parse_error: int = parser.parse(response_text)
		if parse_error == OK:
			parsed_payload = parser.data
		else:
			parsed_payload = response_text

	if transport_result != HTTPRequest.RESULT_SUCCESS:
		return {
			"ok": false,
			"status": status_code,
			"error": "HTTP transport failed with code %d." % transport_result,
			"data": parsed_payload,
			"headers": response_headers
		}

	if status_code >= 200 and status_code < 300:
		return {
			"ok": true,
			"status": status_code,
			"data": parsed_payload,
			"headers": response_headers
		}

	return {
		"ok": false,
		"status": status_code,
		"error": _extract_error_message(parsed_payload, status_code),
		"data": parsed_payload,
		"headers": response_headers
	}


func _extract_error_message(payload: Variant, status_code: int) -> String:
	if payload is Dictionary:
		var payload_dict: Dictionary = payload
		for key in ["msg", "message", "error_description", "error"]:
			if payload_dict.has(key):
				return "%s (HTTP %d)" % [str(payload_dict[key]), status_code]
	return "Request failed with HTTP %d." % status_code


func _append_header_if_missing(headers: PackedStringArray, name: String, value: String) -> void:
	var header_prefix: String = "%s:" % name.to_lower()
	for existing_header in headers:
		var lowered: String = existing_header.to_lower()
		if lowered.begins_with(header_prefix):
			return
	headers.append("%s: %s" % [name, value])


func _apply_auth_payload(payload_variant: Variant) -> void:
	if not (payload_variant is Dictionary):
		return
	var payload: Dictionary = payload_variant

	_access_token = str(payload.get("access_token", _access_token))
	_refresh_token = str(payload.get("refresh_token", _refresh_token))
	_token_expires_at_unix = _compute_expiry_timestamp(payload)
	_authenticated_user_id = _extract_user_id(payload)

	_schedule_token_refresh()
	_save_auth_state_securely()
	_emit_auth_state_changed()


func _compute_expiry_timestamp(payload: Dictionary) -> int:
	var expires_in_seconds: int = int(payload.get("expires_in", 0))
	if expires_in_seconds <= 0:
		return _token_expires_at_unix
	return int(Time.get_unix_time_from_system()) + expires_in_seconds


func _extract_user_id(payload: Dictionary) -> String:
	if payload.has("user_id"):
		return str(payload.get("user_id", ""))

	var user_variant: Variant = payload.get("user", {})
	if user_variant is Dictionary:
		var user_dict: Dictionary = user_variant
		return str(user_dict.get("id", ""))

	return _authenticated_user_id


func _should_refresh_access_token() -> bool:
	if _refresh_token.is_empty():
		return false
	if _token_expires_at_unix <= 0:
		return true
	return int(Time.get_unix_time_from_system()) >= (_token_expires_at_unix - TOKEN_REFRESH_BUFFER_SECONDS)


func _schedule_token_refresh() -> void:
	if _refresh_timer == null:
		return
	_refresh_timer.stop()

	if _refresh_token.is_empty() or _token_expires_at_unix <= 0:
		return

	var now_unix: int = int(Time.get_unix_time_from_system())
	var seconds_until_refresh: int = maxi(1, _token_expires_at_unix - now_unix - TOKEN_REFRESH_BUFFER_SECONDS)
	_refresh_timer.wait_time = float(seconds_until_refresh)
	_refresh_timer.start()


func _setup_refresh_timer() -> void:
	if _refresh_timer != null:
		return
	_refresh_timer = Timer.new()
	_refresh_timer.one_shot = true
	add_child(_refresh_timer)
	if not _refresh_timer.timeout.is_connected(_on_refresh_timer_timeout):
		_refresh_timer.timeout.connect(_on_refresh_timer_timeout)


func _on_refresh_timer_timeout() -> void:
	if _refresh_token.is_empty():
		return
	await refresh_access_token()


func _refresh_access_token_deferred() -> void:
	await refresh_access_token()


func _load_project_settings() -> void:
	_supabase_url = _normalize_supabase_url(str(ProjectSettings.get_setting(SETTINGS_SUPABASE_URL, "")))
	_publishable_key = str(ProjectSettings.get_setting(SETTINGS_SUPABASE_PUBLISHABLE_KEY, "")).strip_edges()


func _normalize_supabase_url(raw_url: String) -> String:
	var normalized: String = raw_url.strip_edges()
	while normalized.ends_with("/"):
		normalized = normalized.left(normalized.length() - 1)
	return normalized


func _ensure_guest_id() -> void:
	if not _guest_id.is_empty():
		return
	_guest_id = "guest_%s" % _generate_uuid_v4()
	_save_auth_state_securely()


func _load_auth_state_securely() -> void:
	if not FileAccess.file_exists(AUTH_STORAGE_PATH):
		return

	var file: FileAccess = FileAccess.open_encrypted_with_pass(
		AUTH_STORAGE_PATH,
		FileAccess.READ,
		_storage_password()
	)
	if file == null:
		push_warning("Unable to open encrypted auth storage.")
		return

	var raw_text: String = file.get_as_text()
	file.close()
	if raw_text.is_empty():
		return

	var parser: JSON = JSON.new()
	var parse_error: int = parser.parse(raw_text)
	if parse_error != OK:
		push_warning("Failed to parse encrypted auth storage JSON.")
		return
	if not (parser.data is Dictionary):
		return

	var payload: Dictionary = parser.data
	_access_token = str(payload.get("access_token", ""))
	_refresh_token = str(payload.get("refresh_token", ""))
	_token_expires_at_unix = int(payload.get("token_expires_at_unix", 0))
	_authenticated_user_id = str(payload.get("authenticated_user_id", ""))
	_guest_id = str(payload.get("guest_id", ""))


func _save_auth_state_securely() -> void:
	var ensure_dir_error: int = DirAccess.make_dir_recursive_absolute(AUTH_STORAGE_PATH.get_base_dir())
	if ensure_dir_error != OK:
		push_warning("Unable to create auth storage directory: %s" % AUTH_STORAGE_PATH.get_base_dir())
		return

	var file: FileAccess = FileAccess.open_encrypted_with_pass(
		AUTH_STORAGE_PATH,
		FileAccess.WRITE,
		_storage_password()
	)
	if file == null:
		push_warning("Unable to write encrypted auth storage.")
		return

	var payload: Dictionary = {
		"access_token": _access_token,
		"refresh_token": _refresh_token,
		"token_expires_at_unix": _token_expires_at_unix,
		"authenticated_user_id": _authenticated_user_id,
		"guest_id": _guest_id
	}
	file.store_string(JSON.stringify(payload))
	file.close()


func _storage_password() -> String:
	var project_name: String = str(ProjectSettings.get_setting("application/config/name", "PuffTactics"))
	var device_identifier: String = OS.get_unique_id().strip_edges()
	if device_identifier.is_empty():
		device_identifier = _load_or_create_device_secret()
	return "%s::%s::supabase_auth_v1" % [project_name, device_identifier]


func _load_or_create_device_secret() -> String:
	var config: ConfigFile = ConfigFile.new()
	if config.load(DEVICE_SECRET_PATH) == OK:
		var existing_secret: String = str(config.get_value("identity", "secret", ""))
		if not existing_secret.is_empty():
			return existing_secret

	var new_secret: String = _generate_uuid_v4()
	config.set_value("identity", "secret", new_secret)
	var ensure_dir_error: int = DirAccess.make_dir_recursive_absolute(DEVICE_SECRET_PATH.get_base_dir())
	if ensure_dir_error == OK:
		config.save(DEVICE_SECRET_PATH)
	return new_secret


func _generate_uuid_v4() -> String:
	var crypto: Crypto = Crypto.new()
	var bytes: PackedByteArray = crypto.generate_random_bytes(16)
	if bytes.size() < 16:
		return "fallback_%d" % Time.get_unix_time_from_system()

	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var hex: String = bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [
		hex.substr(0, 8),
		hex.substr(8, 4),
		hex.substr(12, 4),
		hex.substr(16, 4),
		hex.substr(20, 12)
	]


func _emit_auth_state_changed() -> void:
	emit_signal("auth_state_changed", has_authenticated_session(), _authenticated_user_id, _guest_id)


func _error_result(status: int, message: String) -> Dictionary:
	return {
		"ok": false,
		"status": status,
		"error": message,
		"data": {}
	}

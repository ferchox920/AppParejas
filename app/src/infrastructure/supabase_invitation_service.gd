class_name SupabaseInvitationService
extends InvitationService

var base_url: String = ""
var public_key: String = ""
var _access_token: String = ""
var _refresh_token: String = ""
var _expires_at: float = 0.0
var _session: Dictionary = {}
var _http: HTTPRequest
var _generation: int = 0
var _create_token: String = ""
var _create_invitation_id: String = ""
var _operation_ids: Dictionary = {}
var _pending_email: String = ""
var _pending_name: String = ""
var _pending_consent: bool = false

func _init() -> void:
	is_demo = false

func cancel_pending() -> void:
	_generation += 1
	if is_instance_valid(_http):
		_http.cancel_request()
		_http.queue_free()
		_http = null

func request(operation: String, payload: Dictionary, request_id: int) -> void:
	cancel_pending()
	_execute(operation, payload.duplicate(true), request_id, _generation)

func _execute(operation: String, payload: Dictionary, request_id: int, generation: int) -> void:
	var result: Dictionary
	if not base_url.begins_with("https://") or public_key.is_empty():
		result = {"ok": false, "error": "configuration"}
	elif operation == "send_code":
		_pending_email = str(payload.get("email", "")).strip_edges().to_lower()
		_pending_name = str(payload.get("name", "")).strip_edges()
		_pending_consent = payload.get("consent", false) == true
		if _pending_name.length() < 2 or _pending_name.length() > 30:
			result = {"ok": false, "error": "name"}
		elif not _pending_consent:
			result = {"ok": false, "error": "consent"}
		elif not "@" in _pending_email or _pending_email.length() > 254:
			result = {"ok": false, "error": "email"}
		else:
			result = await _send("/auth/v1/otp", {"email": _pending_email, "create_user": true}, false)
	elif operation == "verify_code":
		if _pending_email.is_empty() or not _pending_consent:
			result = {"ok": false, "error": "auth"}
		else:
			var verification := verification_payload(str(payload.get("code", "")))
			if verification.is_empty():
				result = {"ok": false, "error": "invalid_code"}
			elif not _access_token.is_empty():
				# Recuperar un perfil cuya respuesta se perdió sin consumir otra vez el enlace.
				result = {"ok": true, "data": {}}
			else:
				result = await _send("/auth/v1/verify", verification, false)
			if result.ok and generation == _generation:
				if not _access_token.is_empty() or _set_session(result.data):
					result = await _rpc("register_profile", {"p_name": _pending_name, "p_consent": _pending_consent})
					if result.ok:
						_session.name = _pending_name
						result = {"ok": true, "session": _session.duplicate()}
				else: result = {"ok": false, "error": "auth"}
	elif operation == "logout":
		if not _access_token.is_empty(): await _send("/auth/v1/logout?scope=local", {}, true)
		if generation != _generation: return
		_clear_session()
		result = {"ok": true}
	elif operation == "bootstrap" and _access_token.is_empty():
		result = {"ok": true}
	elif operation in ["bootstrap", "status", "create", "resolve", "accept", "cancel"]:
		result = await _ensure_session()
		if result.ok and generation == _generation:
			match operation:
				"bootstrap", "status": result = await _rpc("get_connection_state", {})
				"create":
					if _create_token.is_empty(): _create_token = Crypto.new().generate_random_bytes(16).hex_encode()
					result = await _rpc("create_invitation", {"p_token": _create_token, "p_operation_id": _operation_id("create")})
				"resolve": result = await _rpc("resolve_invitation", {"p_token": str(payload.get("reference", "")).strip_edges().to_lower()})
				"accept": result = await _rpc("accept_invitation", {"p_token": str(payload.get("reference", "")).strip_edges().to_lower(), "p_operation_id": _operation_id("accept:" + str(payload.get("reference", "")))})
				"cancel":
					result = await _rpc("cancel_invitation", {"p_invitation_id": str(payload.get("invitation_id", "")), "p_operation_id": _operation_id("cancel:" + str(payload.get("invitation_id", "")))})
					if result.ok and generation == _generation:
						_create_token = ""
						_create_invitation_id = ""
						_operation_ids.erase("create")
			if generation != _generation: return
			if result.get("ok", false) and operation == "create" and result.get("invitation") is Dictionary:
				_create_invitation_id = str(result.invitation.get("id", ""))
			if result.get("ok", false) and operation in ["bootstrap", "status"]:
				result.session = _session.duplicate()
				if not result.get("invitation") is Dictionary:
					# El servidor confirmó que ya no hay una invitación pendiente.
					_create_token = ""
					_create_invitation_id = ""
					_operation_ids.erase("create")
			if result.get("invitation") is Dictionary:
				# El servidor sólo conserva hash. Recuperar el código saliente sólo en esta sesión.
				if operation in ["bootstrap", "status"] and not _create_token.is_empty() and str(result.invitation.get("id", "")) == _create_invitation_id:
					result.invitation.pin = _create_token
					result.invitation.link = _create_token
				if operation == "resolve":
					result.invitation.link = str(payload.reference).strip_edges().to_lower()
	else:
		result = {"ok": false, "error": "unavailable"}
	if generation == _generation: completed.emit(request_id, result)

func verification_payload(value: String) -> Dictionary:
	var code := value.strip_edges()
	if code.length() < 6 or code.length() > 10: return {}
	for character: String in code:
		if character not in "0123456789": return {}
	return {"email": _pending_email, "token": code, "type": "email"}

func _operation_id(key: String) -> String:
	if not _operation_ids.has(key):
		var raw := Crypto.new().generate_random_bytes(16).hex_encode()
		_operation_ids[key] = "%s-%s-%s-%s-%s" % [raw.substr(0, 8), raw.substr(8, 4), raw.substr(12, 4), raw.substr(16, 4), raw.substr(20, 12)]
	return _operation_ids[key]

func _ensure_session() -> Dictionary:
	var generation := _generation
	if _access_token.is_empty(): return {"ok": false, "error": "auth"}
	if Time.get_unix_time_from_system() < _expires_at - 60.0: return {"ok": true}
	var response := await _send("/auth/v1/token?grant_type=refresh_token", {"refresh_token": _refresh_token}, false)
	if generation != _generation: return {"ok": false, "error": "cancelled"}
	if not response.ok: return response
	if not _set_session(response.data): return {"ok": false, "error": "auth"}
	return {"ok": true}

func _set_session(data: Variant) -> bool:
	if not data is Dictionary or not data.get("user") is Dictionary: return false
	for value: Variant in [data.get("access_token"), data.get("refresh_token"), data.user.get("id")]:
		if not value is String or value.is_empty(): return false
	var lifetime: Variant = data.get("expires_in", 3600)
	if not lifetime is int and not lifetime is float: return false
	if not float(lifetime) > 0.0 or float(lifetime) > 604800.0: return false
	_access_token = data.access_token
	_refresh_token = str(data.get("refresh_token", ""))
	_expires_at = Time.get_unix_time_from_system() + float(data.get("expires_in", 3600))
	_session = {"id": str(data.user.get("id", "")), "name": _pending_name, "demo": false}
	return not str(_session.id).is_empty()

func _clear_session() -> void:
	_access_token = ""
	_refresh_token = ""
	_expires_at = 0.0
	_session = {}
	_operation_ids = {}
	_create_token = ""
	_create_invitation_id = ""
	_pending_email = ""
	_pending_name = ""
	_pending_consent = false

func _rpc(operation: String, body: Dictionary) -> Dictionary:
	var response := await _send("/rest/v1/rpc/" + operation, body, true)
	if not response.ok: return response
	if not response.data is Dictionary or not response.data.get("ok") is bool:
		return {"ok": false, "error": "unavailable"}
	return response.data

func _send(path: String, body: Dictionary, authenticated: bool) -> Dictionary:
	var generation := _generation
	var http := HTTPRequest.new()
	_http = http
	http.timeout = 10.0
	http.body_size_limit = 65536
	http.max_redirects = 0
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json", "apikey: " + public_key])
	if authenticated: headers.append("Authorization: Bearer " + _access_token)
	var error := http.request(base_url + path, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if error != OK:
		http.queue_free()
		if _http == http: _http = null
		return {"ok": false, "error": "offline"}
	var response: Array = await http.request_completed
	http.queue_free()
	if _http == http: _http = null
	if generation != _generation: return {"ok": false, "error": "cancelled"}
	if response[0] != HTTPRequest.RESULT_SUCCESS: return {"ok": false, "error": "offline"}
	var data: Variant = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
	var status: int = response[1]
	if status < 200 or status >= 300:
		if status == 429: return {"ok": false, "error": "rate_limited"}
		if path.begins_with("/auth/v1/verify") and status in [400, 401, 403, 422]: return {"ok": false, "error": "invalid_code"}
		if path.begins_with("/auth/v1/token") and status in [400, 401, 403]:
			_clear_session()
			return {"ok": false, "error": "auth"}
		if status == 401 or status == 403:
			_clear_session()
			return {"ok": false, "error": "auth"}
		return {"ok": false, "error": "unavailable"}
	if data == null: data = {}
	return {"ok": true, "data": data}

class_name FirstOpenFlow
extends Node

signal changed
var state := FirstOpenState.new()
var store := FirstOpenStore.new()
var service: InvitationService
var screen: String = "loading"
var error: String = ""
var busy: bool = false
var invitation_view: Dictionary = {}
var intro_step: int = 0
var access_draft: Dictionary = {"name": "", "email": "", "consent": false}
var timeout_seconds: float = 12.0
var _request_id: int = 0
var _operation: String = ""
var _payload: Dictionary = {}
var _retry_screen: String = "connect"
var _timer: Timer
var _poll_timer: Timer

func is_demo() -> bool:
	return service == null or service.is_demo

func _ready() -> void:
	if service == null: service = LocalInvitationService.new()
	add_child(service)
	service.completed.connect(_completed)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_timeout)
	add_child(_timer)
	_poll_timer = Timer.new()
	_poll_timer.wait_time = 15.0
	_poll_timer.timeout.connect(func() -> void:
		if screen == "waiting" and not busy and not is_demo(): refresh()
	)
	add_child(_poll_timer)
	_poll_timer.start()

func _notification(what: int) -> void:
	if not is_instance_valid(_poll_timer): return
	if what == NOTIFICATION_APPLICATION_PAUSED: _poll_timer.stop()
	elif what == NOTIFICATION_APPLICATION_RESUMED: _poll_timer.start()

func start() -> void:
	if busy: return
	screen = "loading"
	error = ""
	changed.emit()
	_bootstrap.call_deferred()

func _bootstrap() -> void:
	var result := store.load_state()
	if not result.ok:
		_fail("storage", "loading")
		return
	state = result.state
	_request("bootstrap", _actor(), "loading")

func navigate(next: String) -> void:
	if busy: return
	error = ""
	screen = next
	changed.emit()

func finish_introduction(skipped: bool = false) -> void:
	state.introduction = "skipped" if skipped else "completed"
	if _persist(): navigate("connect")

func connect_route(action: String) -> void:
	if busy or action not in ["invite", "join"]: return
	if state.introduction == "new": state.introduction = "skipped"
	state.invitation.action = action
	if not _persist(): return
	if action == "join":
		navigate("join")
	elif not state.has_session():
		navigate("access")
	elif not str(state.invitation.outgoing_id).is_empty():
		refresh()
	else:
		_request("create", _actor(), "connect")

func access(display_name: String) -> void:
	_request("access", {"name": display_name}, "access")

func send_access_code(display_name: String, email: String, consent: bool) -> void:
	_request("send_code", {"name": display_name, "email": email, "consent": consent}, "access")

func verify_access_code(code: String) -> void:
	_request("verify_code", {"code": code}, "verify")

func logout() -> void:
	_request("logout", {}, screen)

func receive_reference(reference: String) -> void:
	if busy: return
	var normalized := reference.strip_edges()
	if normalized.is_empty() or normalized.length() > 512:
		_fail("invalid_pin", "join")
		return
	state.invitation.pending_reference = normalized
	state.invitation.action = "join"
	if state.introduction == "new": state.introduction = "skipped"
	if not _persist(): return
	if not state.has_session():
		navigate("access")
	else:
		_resolve()

func _resolve() -> void:
	var payload := _actor()
	payload.reference = state.invitation.pending_reference
	_request("resolve", payload, "join")

func accept() -> void:
	# Only the explicit acceptance control may call this command.
	if screen != "review" or invitation_view.is_empty(): return
	var payload := _actor()
	payload.invitation_id = invitation_view.id
	payload.reference = state.invitation.pending_reference
	_request("accept", payload, "review")

func refresh() -> void:
	_request("status", _actor(), "waiting")

func simulate_acceptance() -> void:
	if screen != "waiting": return
	_request("simulate_accept", _actor(), "waiting")

func cancel_invitation() -> void:
	_request("cancel", _actor(), "waiting")

func fixture(kind: String = "active") -> void:
	_request("fixture", {"kind": kind}, "join")

func decline() -> void:
	if busy: return
	state.invitation.pending_reference = ""
	invitation_view = {}
	if _persist(): navigate("connect")

func continue_to_qualities() -> void:
	if not is_demo() or not state.has_pair(): return
	state.pair.continued = true
	if _persist(): navigate("selection")

func retry() -> void:
	if busy: return
	if _retry_screen == "loading":
		start()
	elif error == "storage":
		if _persist(): navigate(state.route())
	elif not _operation.is_empty():
		_request(_operation, _payload, _retry_screen)
	else:
		navigate(_retry_screen)

func return_from_error() -> void:
	if busy: return
	error = ""
	# A missing/unavailable invitation must not trap every subsequent launch.
	if _retry_screen != "loading":
		state.invitation.pending_reference = ""
		if screen == "error" and _operation in ["status", "bootstrap"]:
			state.invitation.outgoing_id = ""
		if not _persist(): return
	navigate(("garden" if is_demo() else "confirmed") if state.has_pair() else "connect")

func save_preferences(scale: float, motion: bool) -> void:
	state.preferences = {"text_scale": scale, "reduced_motion": motion}
	_persist()

func save_selection(ids: Array[String]) -> void:
	state.selection = ids.duplicate()
	_persist()

func _actor() -> Dictionary:
	return {"user_id": state.session.get("id", ""), "name": state.session.get("name", ""),
		"invitation_id": state.invitation.get("outgoing_id", "")}

func _request(operation: String, payload: Dictionary, origin: String) -> void:
	if busy: return
	busy = true
	error = ""
	_operation = operation
	_payload = payload.duplicate(true)
	_retry_screen = origin
	_request_id += 1
	_timer.start(timeout_seconds)
	changed.emit()
	service.request(operation, payload, _request_id)

func _completed(id: int, result: Dictionary) -> void:
	if id != _request_id or not busy: return
	_timer.stop()
	busy = false
	if not result.get("ok", false):
		var reason := str(result.get("error", "unavailable"))
		if _operation == "bootstrap" and reason not in ["storage", "offline"]:
			_retry_screen = "waiting" if not str(state.invitation.outgoing_id).is_empty() else "join"
		_fail(reason, _retry_screen)
		return
	match _operation:
		"send_code": navigate("verify")
		"logout":
			access_draft = {"name": "", "email": "", "consent": false}
			state.session = {}
			state.pair = {}
			state.selection.clear()
			state.invitation = {"action": "", "outgoing_id": "", "pending_reference": ""}
			invitation_view = {}
			if _persist(): navigate("connect")
		"bootstrap", "status":
			if not is_demo(): state.session = result.get("session", {})
			if result.has("pair"):
				var continued := bool(state.pair.get("continued", false))
				state.pair = result.pair
				state.pair.continued = continued
				state.invitation.pending_reference = ""
				state.invitation.outgoing_id = ""
			else:
				state.pair = {}
			invitation_view = result.get("invitation", {})
			if not is_demo(): state.invitation.outgoing_id = str(invitation_view.get("id", ""))
			if not _persist(): return
			if not str(state.invitation.pending_reference).is_empty() and state.has_session():
				_resolve()
			elif not is_demo() and not state.has_session() and state.introduction != "new": navigate("access")
			elif not is_demo() and state.invitation.action == "invite" and state.has_session() and not state.has_pair() and str(state.invitation.outgoing_id).is_empty(): connect_route("invite")
			else: navigate(state.route())
		"access", "verify_code":
			state.session = result.session
			if not _persist(): return
			if not is_demo(): _request("status", _actor(), "access")
			elif not str(state.invitation.pending_reference).is_empty(): _resolve()
			elif state.invitation.action == "invite": connect_route("invite")
			else: navigate("join")
		"create":
			invitation_view = result.invitation
			state.invitation.outgoing_id = invitation_view.id
			if _persist(): navigate("invite")
		"resolve":
			invitation_view = result.invitation
			navigate("review")
		"accept", "simulate_accept":
			state.pair = result.pair
			state.invitation.pending_reference = ""
			state.invitation.outgoing_id = ""
			invitation_view = {}
			if _persist(): navigate("confirmed")
		"cancel":
			state.invitation.outgoing_id = ""
			state.invitation.action = ""
			invitation_view = {}
			if _persist(): navigate("connect")
		"fixture":
			invitation_view = result.invitation
			navigate("join")

func _persist() -> bool:
	if store.save_state(state): return true
	_fail("storage", screen)
	return false

func _fail(reason: String, origin: String) -> void:
	if reason == "auth" and not is_demo():
		state.session = {}
		state.pair = {}
		state.selection.clear()
		state.invitation.outgoing_id = ""
		invitation_view = {}
	error = reason
	_retry_screen = origin
	screen = "error"
	changed.emit()

func _timeout() -> void:
	service.cancel_pending()
	busy = false
	_request_id += 1
	_fail("offline", _retry_screen)

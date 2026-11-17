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
var selection_base_revision: int = -1
var selection_view: Dictionary = {}
var agreement_draft: Dictionary = {}
var _selection_catalog_version: int = 0
var _draft_cleanup_failed := false
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
	if next not in ["selection", "selection_waiting", "selection_revealed", "agreement", "agreement_edit"]:
		selection_view.clear()
	if next != "agreement_edit": agreement_draft.clear()
	if next != "selection":
		selection_base_revision = -1
		if not is_demo(): state.selection.clear()
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
	if busy:
		if is_demo() or _operation == "logout": return
		service.cancel_pending()
		busy = false
	if not is_demo():
		var drafts := _draft_store()
		_draft_cleanup_failed = drafts != null and not drafts.clear()
		_discard_account_state()
		screen = "connect"
	_request("logout", {}, screen)

func _discard_account_state() -> void:
	access_draft = {"name": "", "email": "", "consent": false}
	state.session = {}
	state.pair = {}
	state.selection.clear()
	selection_view.clear()
	agreement_draft.clear()
	state.invitation = {"action": "", "outgoing_id": "", "pending_reference": ""}
	invitation_view = {}

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
	_request("status", _actor(), "confirmed" if screen == "confirmed" else "waiting")

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
	if busy or not state.has_pair(): return
	if not is_demo():
		_request("pair_state", {"pair_id": state.pair.id}, "confirmed")
		return
	state.pair.continued = true
	if _persist(): navigate("selection")

func revalidate_private_selection() -> void:
	if busy or is_demo() or not state.has_pair(): return
	if screen not in ["selection", "selection_waiting", "selection_revealed"]: return
	# Ocultar el contenido anterior mientras se vuelve a consultar el vínculo.
	screen = "loading"
	continue_to_qualities()

func share_selection(ids: Array[String]) -> void:
	if busy or is_demo() or screen != "selection" or not state.has_pair(): return
	if selection_view.get("phase") != "private": return
	if not QualityCatalog.validate_selection(ids, QualityCatalog.load_catalog()).is_empty(): return
	var own: Variant = selection_view.get("own_selection")
	screen = "loading"
	_request("submit_selection", {
		"pair_id": state.pair.id, "quality_ids": ids.duplicate(),
		"catalog_version": _selection_catalog_version,
		"expected_pair_revision": selection_view.pair_revision,
		"expected_selection_revision": int(own.get("revision", 0)) if own is Dictionary else 0
	}, "confirmed")

func reopen_selection() -> void:
	if busy or not state.has_pair() or screen not in ["selection_waiting", "selection_revealed"]: return
	screen = "loading"
	_request("reopen_selection", {
		"pair_id": state.pair.id, "expected_pair_revision": selection_view.pair_revision
	}, "confirmed")

func agreement() -> Dictionary:
	if selection_view.get("phase") != "revealed": return {}
	var value: Variant = selection_view.get("agreement")
	if not value is Dictionary or not value.get("recipe") is Dictionary: return {}
	var version: Variant = value.get("version")
	if (not version is int and not version is float) or version < 1 or version > 2147483647 or version != floorf(version):
		return {}
	return value

func refresh_agreement() -> void:
	if busy or is_demo() or not state.has_pair(): return
	var origin := "agreement_edit" if screen == "agreement_edit" else "agreement"
	screen = "loading"
	_request("pair_state", {"pair_id": state.pair.id}, origin)

func edit_agreement() -> void:
	var current := agreement()
	if busy or screen != "agreement" or current.is_empty(): return
	agreement_draft = {"name": current.name, "intention": current.intention, "version": current.version}
	navigate("agreement_edit")

func save_agreement() -> void:
	var current := agreement()
	if busy or screen != "agreement_edit" or current.is_empty() or agreement_draft.is_empty(): return
	var seed_name: String = agreement_draft.name
	var intention: String = agreement_draft.intention
	if seed_name.strip_edges().is_empty(): return
	screen = "loading"
	_request("update_agreement", {"pair_id": state.pair.id, "expected_agreement_version": int(current.version),
		"name": seed_name, "intention": intention}, "agreement")

func approve_agreement() -> void:
	var current := agreement()
	if busy or screen != "agreement" or current.is_empty() or current.name.is_empty() or current.own_approved:
		return
	screen = "loading"
	_request("approve_agreement", {"pair_id": state.pair.id, "agreement_version": int(current.version)}, "agreement")

func retry() -> void:
	if busy: return
	if _retry_screen == "loading":
		start()
	elif _retry_screen in ["agreement", "agreement_edit"]:
		refresh_agreement()
	elif _operation in ["submit_selection", "reopen_selection"]:
		continue_to_qualities()
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

func uses_secure_drafts() -> bool:
	return Engine.has_singleton("AndroidRuntime") and service is SupabaseInvitationService

func _draft_store() -> AndroidSessionStore:
	if not uses_secure_drafts() or not state.has_session(): return null
	return AndroidSessionStore.new((service as SupabaseInvitationService).base_url, state.session.id)

func save_private_draft(ids: Array[String]) -> bool:
	if is_demo() or screen != "selection" or selection_base_revision < 0 or not state.has_pair(): return false
	var drafts := _draft_store()
	if drafts == null: return not uses_secure_drafts()
	var raw := drafts.read_token()
	var entries: Variant = {} if raw.is_empty() else JSON.parse_string(raw)
	if not entries is Dictionary: return false
	entries[state.pair.id] = {"ids": ids, "catalog_version": _selection_catalog_version, "revision": selection_base_revision}
	return drafts.write_token(JSON.stringify(entries))

func _restore_private_draft(catalog: Dictionary) -> void:
	state.selection.clear()
	var own: Variant = selection_view.get("own_selection")
	if own is Dictionary:
		var ids: Array[String] = []
		ids.assign(own.get("quality_ids", []))
		if QualityCatalog.validate_selection(ids, catalog).is_empty(): state.selection = ids
	var drafts := _draft_store()
	if drafts == null: return
	var raw := drafts.read_token()
	if raw.is_empty(): return
	var entries: Variant = JSON.parse_string(raw)
	if not entries is Dictionary: return
	var entry: Variant = entries.get(state.pair.id)
	if not entry is Dictionary or entry.get("catalog_version") != _selection_catalog_version: return
	var ids: Variant = entry.get("ids")
	var revision: Variant = entry.get("revision")
	if not ids is Array or ids.size() > 5 or (not revision is int and not revision is float): return
	if revision < 0 or revision > selection_base_revision or revision != floorf(revision): return
	var known := QualityCatalog.index(catalog)
	var restored: Array[String] = []
	for id: Variant in ids:
		if not id is String or not known.has(id) or restored.has(id): return
		restored.append(id)
	state.selection = restored
	selection_base_revision = int(revision)

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
		if reason == "invalid_agreement" and _operation == "update_agreement":
			error = reason
			screen = "agreement_edit"
			changed.emit()
			return
		_fail(reason, _retry_screen)
		return
	match _operation:
		"pair_state":
			var revision: Variant = result.get("pair_revision")
			var phase: String = str(result.get("phase", ""))
			if phase not in ["private", "waiting", "revealed"] or (not revision is int and not revision is float):
				_fail("selection_unavailable", "confirmed")
				return
			if revision < 0 or revision > 2147483647 or revision != floorf(revision):
				_fail("selection_unavailable", "confirmed")
				return
			var catalog := QualityCatalog.load_catalog()
			if result.get("catalog_version") != catalog.get("catalog_version"):
				_fail("catalog_outdated", "confirmed")
				return
			selection_view = result
			selection_view.pair_revision = int(revision)
			selection_base_revision = int(revision)
			_selection_catalog_version = int(catalog.catalog_version)
			match phase:
				"private":
					_restore_private_draft(catalog)
					navigate("selection")
				"waiting": navigate("selection_waiting")
				"revealed":
					var current := agreement()
					if _retry_screen == "agreement_edit" and not current.is_empty() and agreement_draft.get("version") == current.version:
						navigate("agreement_edit")
					elif _retry_screen in ["agreement", "agreement_edit"] and not current.is_empty():
						navigate("agreement")
					else:
						navigate("selection_revealed")
		"submit_selection", "reopen_selection":
			continue_to_qualities()
		"update_agreement", "approve_agreement":
			refresh_agreement()
		"send_code": navigate("verify")
		"logout":
			_discard_account_state()
			if _draft_cleanup_failed:
				_fail("draft_cleanup", "connect")
			elif _persist(): navigate("connect")
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
			if not is_demo():
				state.invitation.outgoing_id = str(invitation_view.get("id", ""))
				if _retry_screen != "access" and not state.has_pair() and state.invitation.outgoing_id.is_empty() and state.invitation.action == "invite":
					state.invitation.action = ""
			if not _persist(): return
			if not str(state.invitation.pending_reference).is_empty() and state.has_session():
				_resolve()
			elif not is_demo() and not state.has_session() and state.introduction != "new": navigate("access")
			elif not is_demo() and _operation == "status" and _retry_screen == "access" and state.invitation.action == "invite" and state.has_session() and not state.has_pair() and str(state.invitation.outgoing_id).is_empty(): connect_route("invite")
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
	if not is_demo() and _operation in ["bootstrap", "status"]:
		state.pair = {}
		invitation_view = {}
	if reason in ["auth", "session_storage"] and not is_demo():
		state.session = {}
		state.pair = {}
		state.selection.clear()
		state.invitation.outgoing_id = ""
		invitation_view = {}
	selection_base_revision = -1
	selection_view.clear()
	agreement_draft.clear()
	if not is_demo(): state.selection.clear()
	error = reason
	_retry_screen = origin
	screen = "error"
	changed.emit()

func _timeout() -> void:
	service.cancel_pending()
	busy = false
	_request_id += 1
	_fail("offline", _retry_screen)

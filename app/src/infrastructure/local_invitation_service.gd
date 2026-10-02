class_name LocalInvitationService
extends InvitationService

const PREFIX := "appparejas-demo://invitation/"
var path: String = "user://demo_invitations.json"
var online: bool = true
var invitations: Dictionary = {}
var now_override: float = -1.0

func request(operation: String, payload: Dictionary, request_id: int) -> void:
	_execute.call_deferred(operation, payload.duplicate(true), request_id)

func _execute(operation: String, payload: Dictionary, request_id: int) -> void:
	completed.emit(request_id, perform(operation, payload))

func perform(operation: String, payload: Dictionary) -> Dictionary:
	if not online:
		return _error("offline")
	if operation == "bootstrap":
		if FileAccess.file_exists(path):
			var file := FileAccess.open(path, FileAccess.READ)
			if file == null or file.get_length() > 262144:
				return _error("storage")
			var value: Variant = JSON.parse_string(file.get_as_text())
			if not value is Dictionary or value.get("version") != 1 or not value.get("invitations") is Dictionary:
				return _error("storage")
			invitations = value.invitations
			for key: Variant in invitations:
				var item: Variant = invitations[key]
				if not item is Dictionary or not key is String:
					return _error("storage")
				for field: String in ["id", "pin", "link", "inviter_id", "inviter_name", "status"]:
					if not item.get(field) is String or str(item[field]).length() > 512:
						return _error("storage")
				if item.id != key or item.get("demo") != true or item.status not in ["active", "cancelled", "accepted"]:
					return _error("storage")
				if not item.get("expires_at") is float and not item.get("expires_at") is int:
					return _error("storage")
				if not item.get("members", []) is Array:
					return _error("storage")
				for member: Variant in item.get("members", []):
					if not member is String: return _error("storage")
				if item.status == "accepted" and item.get("members", []).size() != 2:
					return _error("storage")
		return _status(payload)
	if operation == "access":
		var display_name := str(payload.get("name", "")).strip_edges()
		if display_name.length() < 2 or display_name.length() > 30 or "\n" in display_name:
			return _error("name")
		return {"ok": true, "session": {"id": _id(), "name": display_name, "demo": true}}
	if operation == "fixture":
		return _create("demo-alex", "Alex · personaje de ejemplo", str(payload.get("kind", "active")))
	var actor := str(payload.get("user_id", ""))
	if actor.is_empty():
		return _error("auth")
	if operation == "create":
		for item: Dictionary in invitations.values():
			if item.inviter_id == actor and _availability(item) == "":
				return {"ok": true, "invitation": item.duplicate(true)}
			if actor in item.get("members", []):
				return _error("already_linked")
		return _create(actor, str(payload.get("name", "")), "active")
	if operation == "resolve":
		var reference := str(payload.get("reference", "")).strip_edges()
		if reference.length() > 512:
			return _error("invalid_pin")
		for item: Dictionary in invitations.values():
			if reference == str(item.pin) or reference == PREFIX + str(item.id):
				var reason := _availability(item)
				if not reason.is_empty():
					return _error(reason)
				if item.inviter_id == actor:
					return _error("self_invitation")
				return {"ok": true, "invitation": item.duplicate(true)}
		return _error("invalid_pin")
	if operation == "status":
		return _status(payload)
	var id := str(payload.get("invitation_id", ""))
	if not invitations.has(id):
		return _error("unavailable")
	var item: Dictionary = invitations[id]
	if operation == "cancel":
		if item.inviter_id != actor:
			return _error("unavailable")
		if item.status != "active":
			return _error("used" if item.status == "accepted" else "cancelled")
		return _commit_item(id, {"status": "cancelled"})
	if operation in ["accept", "simulate_accept"]:
		var other := "demo-other-" + id if operation == "simulate_accept" else actor
		if operation == "simulate_accept" and item.inviter_id != actor:
			return _error("unavailable")
		if item.status == "accepted" and other in item.get("members", []):
			return {"ok": true, "pair": _pair(item)}
		var reason := _availability(item)
		if not reason.is_empty():
			return _error(reason)
		if item.inviter_id == other:
			return _error("self_invitation")
		for existing: Dictionary in invitations.values():
			if other in existing.get("members", []) or item.inviter_id in existing.get("members", []):
				return _error("already_linked")
		var changed := _commit_item(id, {"status": "accepted", "members": [item.inviter_id, other]})
		if not changed.ok:
			return changed
		return {"ok": true, "pair": _pair(invitations[id])}
	return _error("unavailable")

func _create(actor: String, display_name: String, kind: String) -> Dictionary:
	var id := _id()
	var pin := ""
	while pin.is_empty() or _pin_exists(pin):
		pin = "%06d" % (Crypto.new().generate_random_bytes(4).decode_u32(0) % 1000000)
	var item := {"id": id, "pin": pin, "link": PREFIX + id, "inviter_id": actor,
		"inviter_name": display_name, "demo": true, "status": "cancelled" if kind == "cancelled" else "active",
		"expires_at": _now() - 1.0 if kind == "expired" else _now() + 259200.0}
	invitations[id] = item
	if not _save():
		invitations.erase(id)
		return _error("storage")
	return {"ok": true, "invitation": item.duplicate(true)}

func _status(payload: Dictionary) -> Dictionary:
	var actor := str(payload.get("user_id", ""))
	for item: Dictionary in invitations.values():
		if not actor.is_empty() and actor in item.get("members", []):
			return {"ok": true, "pair": _pair(item)}
	var id := str(payload.get("invitation_id", ""))
	if not id.is_empty():
		if not invitations.has(id) or invitations[id].inviter_id != actor:
			return _error("unavailable")
		var item: Dictionary = invitations[id]
		var reason := _availability(item)
		if not reason.is_empty():
			return _error(reason)
		return {"ok": true, "invitation": item.duplicate(true)}
	return {"ok": true}

func _commit_item(id: String, changes: Dictionary) -> Dictionary:
	var previous: Dictionary = invitations[id].duplicate(true)
	invitations[id].merge(changes, true)
	if not _save():
		invitations[id] = previous
		return _error("storage")
	return {"ok": true, "invitation": invitations[id].duplicate(true)}

func _availability(item: Dictionary) -> String:
	if item.get("status") == "cancelled": return "cancelled"
	if item.get("status") == "accepted": return "used"
	if float(item.expires_at) <= _now(): return "expired"
	return ""

func _pair(item: Dictionary) -> Dictionary:
	return {"id": "demo-pair-" + str(item.id), "status": "confirmed", "demo": true, "continued": false}

func _save() -> bool:
	return FirstOpenStore.write_json(path, {"version": 1, "invitations": invitations})

func _pin_exists(pin: String) -> bool:
	for item: Dictionary in invitations.values():
		if item.pin == pin: return true
	return false

func _id() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()

func _now() -> float:
	return now_override if now_override >= 0.0 else Time.get_unix_time_from_system()

func _error(code: String) -> Dictionary:
	return {"ok": false, "error": code}

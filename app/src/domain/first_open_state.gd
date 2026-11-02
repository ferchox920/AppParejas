class_name FirstOpenState
extends RefCounted

const VERSION := 1
var introduction: String = "new"
var session: Dictionary = {}
var invitation: Dictionary = {"action": "", "outgoing_id": "", "pending_reference": ""}
var pair: Dictionary = {}
var preferences: Dictionary = {"text_scale": 1.0, "reduced_motion": true}
var selection: Array[String] = []

func has_session() -> bool:
	return not str(session.get("id", "")).is_empty()

func has_pair() -> bool:
	return pair.get("status", "") == "confirmed" and not str(pair.get("id", "")).is_empty()

func route() -> String:
	if not str(invitation.get("pending_reference", "")).is_empty():
		return "review" if has_session() else "access"
	if has_pair():
		return "garden" if pair.get("continued", false) else "confirmed"
	if not str(invitation.get("outgoing_id", "")).is_empty():
		return "waiting" if has_session() else "access"
	if invitation.get("action", "") == "join":
		return "join"
	if invitation.get("action", "") == "invite":
		return "invite" if has_session() else "access"
	return "welcome" if introduction == "new" else "connect"

func serialize() -> Dictionary:
	return {"version": VERSION, "introduction": introduction, "session": session.duplicate(true),
		"invitation": invitation.duplicate(true), "pair": pair.duplicate(true),
		"preferences": preferences.duplicate(true), "selection": selection.duplicate()}

static func parse(data: Dictionary) -> FirstOpenState:
	if data.get("version", 0) != VERSION or data.get("introduction", "") not in ["new", "completed", "skipped"]:
		return null
	for key: String in ["session", "invitation", "pair", "preferences"]:
		if not data.get(key) is Dictionary:
			return null
	if not data.get("selection") is Array:
		return null
	var result := FirstOpenState.new()
	result.introduction = data.introduction
	result.session = data.session.duplicate(true)
	result.invitation = data.invitation.duplicate(true)
	result.pair = data.pair.duplicate(true)
	result.preferences = data.preferences.duplicate(true)
	# This store is deliberately for the local demonstration. Never restore real JWTs here.
	if not result.session.is_empty() and (result.session.get("demo") != true or not result.session.get("id") is String):
		return null
	if not result.session.is_empty() and (not result.session.get("name") is String or str(result.session.name).length() > 30):
		return null
	if not result.pair.is_empty() and (result.pair.get("demo") != true or not result.pair.get("id") is String):
		return null
	if not result.pair.is_empty() and (result.pair.get("status") != "confirmed" or not result.pair.get("continued", false) is bool):
		return null
	for key: String in ["action", "outgoing_id", "pending_reference"]:
		if not result.invitation.get(key) is String or str(result.invitation[key]).length() > 512:
			return null
	if result.invitation.action not in ["", "invite", "join"]:
		return null
	if not result.preferences.get("text_scale") is float and not result.preferences.get("text_scale") is int:
		return null
	if not result.preferences.get("reduced_motion") is bool:
		return null
	result.preferences.text_scale = clampf(float(result.preferences.text_scale), 1.0, 2.0)
	for id: Variant in data.selection:
		if not id is String or result.selection.size() >= 5:
			return null
		result.selection.append(id)
	return result

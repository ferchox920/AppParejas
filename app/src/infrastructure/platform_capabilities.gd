class_name PlatformCapabilities
extends Node

signal invitation_received(reference: String)
signal scan_finished(result: Dictionary)
signal share_finished(ok: bool)
var _scanning: bool = false
var _last_intent: String = ""

func _ready() -> void:
	get_tree().on_request_permissions_result.connect(_permission_result)
	if Engine.has_singleton("AppParejasPlatform"):
		var bridge := Engine.get_singleton("AppParejasPlatform")
		if bridge.has_signal("invitation_received"):
			bridge.connect("invitation_received", func(value: String) -> void: invitation_received.emit(value))
		if bridge.has_signal("qr_scanned"):
			bridge.connect("qr_scanned", func(value: String) -> void:
				_scanning = false
				scan_finished.emit({"ok": true, "reference": value})
			)
		if bridge.has_signal("scan_failed"):
			bridge.connect("scan_failed", func(code: String) -> void:
				_scanning = false
				scan_finished.emit({"ok": false, "error": code})
			)

func copy_text(value: String) -> bool:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD): return false
	DisplayServer.clipboard_set(value)
	return true

func share_text(value: String) -> bool:
	if not Engine.has_singleton("AndroidRuntime"):
		return false
	var runtime := Engine.get_singleton("AndroidRuntime")
	var activity: JavaObject = runtime.getActivity()
	var intent_class := JavaClassWrapper.wrap("android.content.Intent")
	var send: JavaObject = intent_class.Intent()
	send.setAction("android.intent.action.SEND")
	send.setType("text/plain")
	send.putExtra("android.intent.extra.TEXT", value)
	var chooser: JavaObject = intent_class.createChooser(send, "Compartir invitación de demostración")
	if JavaClassWrapper.get_exception() != null: return false
	activity.runOnUiThread(runtime.createRunnableFromGodotCallable(func() -> void:
		activity.startActivity(chooser)
		var success := JavaClassWrapper.get_exception() == null
		_finish_share.call_deferred(success)
	))
	return true

func _finish_share(ok: bool) -> void:
	share_finished.emit(ok)

func request_scan() -> void:
	if _scanning: return
	_scanning = true
	if OS.get_name() != "Android":
		_finish_scan({"ok": false, "error": "scanner_unavailable"})
	elif OS.request_permission("android.permission.CAMERA"):
		_start_scanner()

func _permission_result(permission: String, granted: bool) -> void:
	if permission != "android.permission.CAMERA" or not _scanning: return
	if granted: _start_scanner()
	else: _finish_scan({"ok": false, "error": "camera_denied"})

func _start_scanner() -> void:
	if Engine.has_singleton("AppParejasPlatform"):
		var bridge := Engine.get_singleton("AppParejasPlatform")
		if bridge.has_method("scan_qr"):
			bridge.call("scan_qr")
			return
	_finish_scan({"ok": false, "error": "scanner_unavailable"})

func _finish_scan(result: Dictionary) -> void:
	_scanning = false
	scan_finished.emit(result)

func cancel_scan() -> void:
	_scanning = false
	if Engine.has_singleton("AppParejasPlatform"):
		var bridge := Engine.get_singleton("AppParejasPlatform")
		if bridge.has_method("cancel_scan"): bridge.call("cancel_scan")

func read_launch_invitation() -> void:
	# Works for explicit ACTION_VIEW intents. Public verified links still need a domain/manifest.
	if not Engine.has_singleton("AndroidRuntime"): return
	var activity: JavaObject = Engine.get_singleton("AndroidRuntime").getActivity()
	var intent: JavaObject = activity.getIntent()
	if intent == null: return
	var value: Variant = intent.getDataString()
	if JavaClassWrapper.get_exception() != null or value == null: return
	var reference := str(value)
	if reference.begins_with(LocalInvitationService.PREFIX) and reference != _last_intent:
		_last_intent = reference
		invitation_received.emit(reference)

func open_app_settings() -> bool:
	if not Engine.has_singleton("AndroidRuntime"): return false
	var runtime := Engine.get_singleton("AndroidRuntime")
	var activity: JavaObject = runtime.getActivity()
	var intent_class := JavaClassWrapper.wrap("android.content.Intent")
	var uri_class := JavaClassWrapper.wrap("android.net.Uri")
	var intent: JavaObject = intent_class.Intent("android.settings.APPLICATION_DETAILS_SETTINGS")
	intent.setData(uri_class.parse("package:" + str(activity.getPackageName())))
	activity.runOnUiThread(runtime.createRunnableFromGodotCallable(func() -> void: activity.startActivity(intent)))
	return true

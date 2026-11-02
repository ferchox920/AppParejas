extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := BackendConfig.load_settings()
	if config.mode != "supabase":
		push_error("Falta configuración Supabase")
		quit(1)
		return
	var http := HTTPRequest.new()
	http.timeout = 10.0
	http.max_redirects = 0
	root.add_child(http)
	var error := http.request(config.url + "/auth/v1/health", PackedStringArray(["apikey: " + config.public_key]))
	if error != OK:
		quit(1)
		return
	var response: Array = await http.request_completed
	print("HTTPS: TLS=%s HTTP=%d" % [response[0] == HTTPRequest.RESULT_SUCCESS, response[1]])
	var ok: bool = response[0] == HTTPRequest.RESULT_SUCCESS and response[1] == 200
	http.queue_free()
	await process_frame
	quit(0 if ok else 1)

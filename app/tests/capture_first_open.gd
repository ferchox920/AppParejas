extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var directory := ProjectSettings.globalize_path("res://../.artifacts/first_open/captures")
	DirAccess.make_dir_recursive_absolute(directory)
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.auto_start = false
	app.first_open.store = FirstOpenStore.new("user://capture_first_open_state.json")
	root.add_child(app)
	var service: LocalInvitationService = app.first_open.service
	service.path = "user://capture_first_open_service.json"
	var fixture := service.perform("fixture", {})
	app.first_open.invitation_view = fixture.invitation
	app.first_open.state.session = {"id": "capture", "name": "Sol", "demo": true}
	for width: int in [360, 390]:
		root.size = Vector2i(width, 844)
		root.content_scale_size = Vector2i(width, 844)
		for scale: float in [1.0, 1.5]:
			app._set_text_scale(scale)
			for screen_name: String in ["loading", "welcome", "intro", "connect", "access", "invite", "join", "scan", "review", "waiting", "confirmed", "error"]:
				app.first_open.error = "camera_denied"
				app.first_open.intro_step = 0
				app.show_screen(screen_name)
				await process_frame
				await process_frame
				await RenderingServer.frame_post_draw
				var filename := "%s/%s_%d_%d.png" % [directory, screen_name, width, roundi(scale * 100)]
				if root.get_texture().get_image().save_png(filename) != OK:
					push_error("No se pudo guardar " + filename)
					quit(1)
					return
				if screen_name == "invite":
					var qr: TextureRect = app.find_child("InvitationQR", true, false)
					qr.texture.get_image().save_png(directory + "/qr.png")
					var reference := FileAccess.open(directory + "/qr-reference.txt", FileAccess.WRITE)
					reference.store_string(str(fixture.invitation.link))
	app.queue_free()
	await process_frame
	print("PRIMERA APERTURA: 48 capturas renderizadas a 360/390 y texto 100/150%")
	quit()

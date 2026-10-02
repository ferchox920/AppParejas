extends SceneTree

var checks: int = 0
var failures: Array[String] = []
var base: String

class SilentService extends InvitationService:
	func request(_operation: String, _payload: Dictionary, _request_id: int) -> void:
		pass

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func settle(flow: FirstOpenFlow) -> void:
	for frame: int in range(20):
		await process_frame
		if not flow.busy and flow.screen != "loading": return

func new_flow(suffix: String) -> FirstOpenFlow:
	var flow := FirstOpenFlow.new()
	flow.store = FirstOpenStore.new(base + suffix + "_state.json")
	var service := LocalInvitationService.new()
	service.path = base + suffix + "_service.json"
	flow.service = service
	root.add_child(flow)
	return flow

func _run() -> void:
	base = "user://tests_%d_" % Time.get_ticks_usec()
	var flow := new_flow("invite")
	flow.start()
	check(flow.screen == "loading", "Carga visible antes de completar la recuperación real")
	await settle(flow)
	check(flow.screen == "welcome" and flow.state.session.is_empty(), "Primera apertura sin acceso ficticio automático")
	flow.finish_introduction()
	check(flow.screen == "connect" and flow.state.introduction == "completed", "Introducción completada")
	flow.start()
	await settle(flow)
	check(flow.screen == "connect", "Reapertura no repite introducción completada")
	flow.connect_route("invite")
	check(flow.screen == "access" and flow.state.session.is_empty(), "Invitar exige acceso explícito de demo")
	flow.access("A")
	await settle(flow)
	check(flow.error == "name", "Nombre inválido recuperable")
	flow.navigate("access")
	flow.access("Sol")
	await settle(flow)
	check(flow.screen == "invite" and not flow.invitation_view.is_empty(), "Acceso genera invitación de demo")
	var invitation: Dictionary = flow.invitation_view.duplicate(true)
	check(str(invitation.link).begins_with(LocalInvitationService.PREFIX) and invitation.demo, "Sin URL pública ni invitación de producción inventada")
	check(not flow.state.has_pair(), "Crear no confirma vínculo")
	flow.navigate("waiting")
	flow.refresh()
	await settle(flow)
	check(flow.screen == "waiting" and not flow.state.has_pair(), "Consultar no simula aceptación")
	flow.start()
	await settle(flow)
	check(flow.screen == "waiting" and flow.state.invitation.outgoing_id == invitation.id, "Reapertura retoma espera")
	flow.simulate_acceptance()
	await settle(flow)
	check(flow.screen == "confirmed" and flow.state.has_pair() and flow.state.pair.demo, "Aceptación simulada explícita confirma sólo demo")
	flow.continue_to_qualities()
	check(flow.screen == "selection", "Vínculo confirmado permite cualidades")
	flow.start()
	await settle(flow)
	check(flow.screen == "garden", "Persona vinculada retoma jardín")
	flow.queue_free()
	await process_frame

	var join := new_flow("join")
	join.start()
	await settle(join)
	join.finish_introduction(true)
	join.start()
	await settle(join)
	check(join.state.introduction == "skipped" and join.screen == "connect", "Salto de introducción persiste")
	join.connect_route("join")
	join.fixture()
	await settle(join)
	var received: Dictionary = join.invitation_view.duplicate(true)
	join.receive_reference(received.link)
	check(join.screen == "access" and not join.state.has_pair(), "Link antes de acceso conserva invitación sin aceptar")
	join.start()
	await settle(join)
	check(join.screen == "access" and join.state.invitation.pending_reference == received.link, "Invitación pendiente persiste entre aperturas")
	join.access("Luz")
	await settle(join)
	check(join.screen == "review" and join.invitation_view.inviter_name.contains("Alex"), "Después de acceso muestra quién invita")
	check(not join.state.has_pair(), "Resolver link nunca vincula automáticamente")
	join.start()
	await settle(join)
	check(join.screen == "review" and not join.state.has_pair(), "Reapertura mantiene revisión sin aceptación")
	join.decline()
	check(join.state.invitation.pending_reference.is_empty() and not join.state.has_pair(), "Rechazar no vincula")
	join.receive_reference(received.pin)
	await settle(join)
	check(join.screen == "review" and not join.state.has_pair(), "Resolver PIN también exige revisión")
	join.accept()
	await settle(join)
	check(join.screen == "confirmed", "Aceptación explícita desde revisión")
	var service: LocalInvitationService = join.service
	var accepted := service.perform("accept", {"user_id": join.state.session.id, "invitation_id": received.id})
	check(accepted.ok and accepted.pair.id == join.state.pair.id, "Reintentar aceptación es idempotente")
	var outsider := service.perform("resolve", {"user_id": "another", "reference": received.pin})
	check(outsider.error == "used", "Invitación consumida no admite otra persona")
	join.queue_free()
	await process_frame

	var errors := new_flow("errors")
	errors.start()
	await settle(errors)
	errors.connect_route("join")
	errors.access("Mar")
	await settle(errors)
	errors.receive_reference("000000")
	await settle(errors)
	check(errors.error == "invalid_pin" and not errors.state.has_pair(), "PIN incorrecto no confirma")
	errors.return_from_error()
	check(errors.screen == "connect" and errors.state.invitation.pending_reference.is_empty(), "Recuperación elimina referencia inválida")
	var local: LocalInvitationService = errors.service
	for kind: String in ["expired", "cancelled"]:
		errors.fixture(kind)
		await settle(errors)
		errors.receive_reference(errors.invitation_view.link)
		await settle(errors)
		check(errors.error == kind and not errors.state.has_pair(), "Rechazo de invitación " + kind)
		errors.return_from_error()
	local.online = false
	errors.fixture()
	await settle(errors)
	check(errors.error == "offline", "Falta de conexión tiene error finito")
	local.online = true
	errors.retry()
	await settle(errors)
	check(errors.screen == "join" and not errors.invitation_view.is_empty(), "Reintento recupera operación")
	var expiring: Dictionary = errors.invitation_view.duplicate(true)
	errors.receive_reference(expiring.link)
	await settle(errors)
	local.now_override = float(expiring.expires_at) + 1.0
	errors.accept()
	await settle(errors)
	check(errors.error == "expired" and not errors.state.has_pair(), "Aceptar revalida vencimiento posterior a revisión")
	local.now_override = -1.0
	errors.return_from_error()
	errors.connect_route("invite")
	await settle(errors)
	var own: Dictionary = errors.invitation_view.duplicate(true)
	errors.receive_reference(own.link)
	await settle(errors)
	check(errors.error == "self_invitation", "No permite aceptar invitación propia")
	errors.return_from_error()
	errors.connect_route("invite")
	await settle(errors)
	errors.cancel_invitation()
	await settle(errors)
	check(errors.screen == "connect" and errors.state.invitation.outgoing_id.is_empty(), "Cancelación persiste y libera ruta")
	errors.start()
	await settle(errors)
	check(errors.screen == "connect", "Reapertura después de cancelación")
	errors.queue_free()
	await process_frame

	var broken := new_flow("broken")
	FirstOpenStore.write_json(broken.store.path, {"version": 999})
	broken.start()
	await settle(broken)
	check(broken.error == "storage", "Archivo incompatible no se borra ni reinicia silenciosamente")
	check(FileAccess.file_exists(broken.store.path), "Error de carga conserva archivo original")
	broken.queue_free()
	await process_frame
	var timeout := FirstOpenFlow.new()
	timeout.service = SilentService.new()
	timeout.store = FirstOpenStore.new(base + "timeout.json")
	timeout.timeout_seconds = 0.02
	root.add_child(timeout)
	timeout.start()
	await create_timer(0.05).timeout
	check(timeout.error == "offline" and not timeout.busy, "Servicio sin respuesta alcanza tiempo límite")
	timeout.service.completed.emit(1, {"ok": true, "pair": {"status": "confirmed"}})
	check(not timeout.state.has_pair(), "Respuesta tardía no altera estado")
	timeout.queue_free()
	await process_frame
	await _layout_tests()
	print("PRIMERA APERTURA: %d verificaciones, %d fallos" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _layout_tests() -> void:
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.auto_start = false
	app.first_open.store = FirstOpenStore.new(base + "ui.json")
	root.add_child(app)
	var fixture: Dictionary = (app.first_open.service as LocalInvitationService).perform("fixture", {})
	app.first_open.invitation_view = fixture.invitation
	app.first_open.state.session = {"id": "test", "name": "Sol", "demo": true}
	for width: int in [360, 390]:
		root.size = Vector2i(width, 844)
		root.content_scale_size = Vector2i(width, 844)
		for scale: float in [1.0, 1.5]:
			app._set_text_scale(scale)
			for screen_name: String in ["loading", "welcome", "intro", "connect", "access", "invite", "join", "scan", "review", "waiting", "confirmed", "error"]:
				app.first_open.intro_step = 1
				app.first_open.error = "camera_denied"
				app.show_screen(screen_name)
				await process_frame
				await process_frame
				var view: FirstOpenView = app.find_child("FirstOpenView", true, false)
				check(view != null and view.size.x <= width - 47, "Vista adaptable %s %d %.1f" % [screen_name, width, scale])
				check(view.mouse_filter == Control.MOUSE_FILTER_PASS and view.get_parent().mouse_filter == Control.MOUSE_FILTER_PASS, "Gestos llegan al contenedor de desplazamiento")
				_validate_geometry(view, width, screen_name)
				if screen_name == "review":
					check(app.find_child("AcceptInvitation", true, false) != null, "Aceptación visible y explícita")
				if screen_name == "error":
					check(app.find_child("CameraSettings", true, false) != null and app.find_child("UsePIN", true, false) != null, "Permiso denegado ofrece ajustes y PIN")
	app.queue_free()
	await process_frame

func _validate_geometry(node: Node, width: int, screen_name: String) -> void:
	for child: Node in node.get_children():
		if child is Control:
			check(child.get_global_rect().end.x <= width - 23 and child.get_global_rect().position.x >= 23, "Sin desborde horizontal en " + screen_name)
		if child is Button:
			check(child.size.y >= 56, "Área táctil mínima en " + screen_name)
		_validate_geometry(child, width, screen_name)

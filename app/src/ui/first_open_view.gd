class_name FirstOpenView
extends VBoxContainer

var flow: FirstOpenFlow
var platform: PlatformCapabilities
var text_scale: float = 1.0
var _status: Label
var _pin: LineEdit
var _link: LineEdit

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 16)
	_label("DEMOSTRACIÓN LOCAL", 14, AppTheme.FOREST)
	_label("Sin cuentas reales ni conexión entre teléfonos.", 14, AppTheme.MUTED)
	match flow.screen:
		"loading": _loading()
		"welcome": _welcome()
		"intro": _introduction()
		"connect": _connect()
		"access": _access()
		"invite": _invite()
		"join": _join()
		"scan": _scan()
		"review": _review()
		"waiting": _waiting()
		"confirmed": _confirmed()
		"error": _error()
	_status = _label("", 14, AppTheme.MUTED)
	_status.name = "Status"
	if flow.busy:
		_status.text = "Preparando tu espacio…" if flow.screen == "loading" else "Consultando…"
		_disable_actions(self)
	if flow.screen != "loading": _preferences()

func _loading() -> void:
	_brand(180)
	_title("AppParejas")
	_label("Preparando tu espacio", 20)
	_label("Recuperamos tu recorrido y el acceso guardado.", 16, AppTheme.MUTED)

func _welcome() -> void:
	_brand(150)
	_title("Una semilla para ustedes")
	_label("Un espacio para elegir qué quieren cultivar en su vínculo y darle una forma compartida.")
	_label("A su ritmo, sin puntajes ni rachas.", 16, AppTheme.MUTED)
	_button("Conocer nuestro espacio", "MeetSpace", func() -> void: flow.navigate("intro"))
	_button("Tengo una invitación", "WelcomeInvitation", func() -> void: flow.connect_route("join"), true)

func _introduction() -> void:
	_label("%d de 2 · CONOCER EL ESPACIO" % (flow.intro_step + 1), 14, AppTheme.MUTED)
	_brand(140)
	if flow.intro_step == 0:
		_title("Cada elección empieza en vos")
		_card("Elegí entre 3 y 5 cualidades", "Cada persona elige lo que quiere cultivar. Las elecciones son individuales y se encuentran cuando ambas deciden compartirlas.")
		_card("Una semilla compartida", "Sus aportes se reúnen en una misma semilla, conservando lo que cada persona eligió.")
		_button("Continuar", "IntroNext", func() -> void:
			flow.intro_step = 1
			flow.navigate("intro")
		)
	else:
		_title("Cultiven a su propio ritmo")
		_card("Un acuerdo para sembrar", "Antes de sembrar, las dos personas revisan y aceptan el mismo acuerdo.")
		_card("Tiempo para crecer", "La semilla da su primer brote con el tiempo. No hay rachas, castigos ni tareas obligatorias.")
		_button("Conectar con mi pareja", "IntroFinish", func() -> void: flow.finish_introduction())
		_button("Anterior", "IntroBack", func() -> void:
			flow.intro_step = 0
			flow.navigate("intro")
		, true)
	_button("Saltar introducción", "IntroSkip", func() -> void: flow.finish_introduction(true), true)

func _connect() -> void:
	_brand(150)
	_title("Un espacio para compartir")
	if flow.state.has_pair():
		_label("Tu vínculo de demostración ya está confirmado. Podés retomar tu jardín.")
		_button("Volver a mi jardín", "ReturnGarden", func() -> void: flow.navigate("garden"))
		return
	_label("Conecten sus recorridos con una invitación. Cada persona decide si quiere aceptar.")
	_button("Invitar a mi pareja", "ChooseInvite", func() -> void: flow.connect_route("invite"))
	_button("Tengo una invitación", "ChooseJoin", func() -> void: flow.connect_route("join"), true)
	_button("Volver a conocer el espacio", "ReadIntro", func() -> void:
		flow.intro_step = 0
		flow.navigate("intro")
	, true)

func _access() -> void:
	_title("Tu acceso de demostración")
	_label("Para revisar quién invita, primero identificá tu recorrido local. Esto no crea una cuenta ni verifica tu identidad.")
	if not str(flow.state.invitation.pending_reference).is_empty():
		_card("Tu invitación sigue pendiente", "Después de este acceso podrás revisarla. Todavía no aceptaste ningún vínculo.")
	_label("Cómo querés aparecer en la demostración")
	var field := _field("DisplayName", "Tu nombre", 30)
	_button("Continuar en demostración", "DemoAccess", func() -> void: flow.access(field.text))
	_button("Volver", "AccessBack", func() -> void: flow.navigate("join" if flow.state.invitation.action == "join" else "connect"), true)

func _invite() -> void:
	_title("Una invitación para empezar juntos")
	_label("Elegí la forma que les quede más cómoda.")
	if flow.invitation_view.is_empty():
		_button("Preparar invitación local", "CreateInvitation", func() -> void: flow.connect_route("invite"))
		return
	_qr(str(flow.invitation_view.link))
	_label("PIN de demostración · válido sólo en este dispositivo", 14, AppTheme.MUTED)
	_card(str(flow.invitation_view.pin), "Vence en 72 horas. No sirve para conectar otro teléfono.")
	_label("Link local de demostración", 14, AppTheme.MUTED)
	_label(str(flow.invitation_view.link), 14)
	_button("Compartir link", "ShareLink", _share)
	_button("Copiar link", "CopyLink", _copy, true)
	_button("Ver estado de la invitación", "InvitationStatus", func() -> void: flow.navigate("waiting"), true)
	_button("Volver", "InviteBack", func() -> void: flow.navigate("connect"), true)

func _join() -> void:
	_title("Entrá con una invitación")
	_label("Podés ingresar un PIN, escanear un QR o abrir un link recibido. Siempre revisarás quién invita antes de aceptar.")
	_label("PIN de invitación")
	_pin = _field("InvitationPIN", "Ingresá el PIN", 6)
	_pin.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_pin.text_submitted.connect(func(value: String) -> void: flow.receive_reference(value))
	_button("Revisar PIN", "ResolvePIN", func() -> void: flow.receive_reference(_pin.text))
	_button("Escanear un QR", "ScanQR", func() -> void: flow.navigate("scan"), true)
	_label("Link recibido")
	_link = _field("InvitationLink", "Pegá el link recibido", 512)
	_link.text_submitted.connect(func(value: String) -> void: flow.receive_reference(value))
	_button("Abrir link recibido", "ResolveLink", func() -> void: flow.receive_reference(_link.text), true)
	_button("Pegar link del portapapeles", "PasteLink", func() -> void:
		_link.text = DisplayServer.clipboard_get()
		_status.text = "Link pegado. Elegí Abrir link recibido para revisarlo."
	, true)
	_card("Para probar sin otra cuenta", "Prepará una invitación de Alex, personaje ficticio. No representa a una persona real ni conecta dispositivos.")
	if not flow.invitation_view.is_empty() and flow.invitation_view.get("inviter_id") == "demo-alex":
		_label("PIN de ejemplo: " + str(flow.invitation_view.pin), 20, AppTheme.FOREST)
		_button("Usar invitación de ejemplo", "UseFixture", func() -> void: flow.receive_reference(str(flow.invitation_view.link)), true)
	_button("Preparar ejemplo local", "CreateFixture", func() -> void: flow.fixture(), true)
	_button("Volver", "JoinBack", func() -> void: flow.decline(), true)

func _scan() -> void:
	_title("Escaneá la invitación")
	_label("La cámara sólo se solicita al elegir escanear. Un QR recibido abre la revisión; nunca confirma el vínculo.")
	_card("Lectura de cámara pendiente", "Este APK permite solicitar el permiso. Para leer QR hace falta conectar el adaptador nativo documentado. Mientras tanto, usá el PIN o pegá el link.")
	_button("Habilitar cámara", "CameraPermission", func() -> void:
		_status.text = "Esperando el permiso de cámara…"
		platform.request_scan()
	)
	_button("Usar un PIN o link", "ScanBack", func() -> void:
		platform.cancel_scan()
		flow.navigate("join")
	, true)

func _review() -> void:
	_title("Una invitación para vos")
	if flow.invitation_view.is_empty():
		_label("Recuperando la invitación…")
		return
	_card(str(flow.invitation_view.inviter_name), "Te invita a probar un espacio compartido de demostración.")
	_label("Aceptar confirma únicamente un vínculo local de ejemplo. Tus cualidades no se envían ni se comparten en este paso.")
	_button("Aceptar invitación de demo", "AcceptInvitation", func() -> void: flow.accept())
	_button("Ahora no", "DeclineInvitation", func() -> void: flow.decline(), true)

func _waiting() -> void:
	_brand(130)
	_title("Esperando la aceptación")
	_label("La invitación está creada. El vínculo todavía no está confirmado.")
	_label("Compartir o copiar el link no significa que la otra persona haya aceptado.", 16, AppTheme.MUTED)
	_button("Consultar estado", "RefreshInvitation", func() -> void: flow.refresh())
	_button("Ver PIN y QR", "SeeInvitation", func() -> void: flow.navigate("invite"), true)
	_button("Volver más tarde", "Later", func() -> void: flow.navigate("connect"), true)
	_button("Cancelar invitación", "CancelInvitation", func() -> void: flow.cancel_invitation(), true)
	_card("Prueba local", "No hay otra cuenta conectada. Podés representar su aceptación para probar la siguiente etapa.")
	_button("Simular aceptación en demo", "SimulateAcceptance", func() -> void: flow.simulate_acceptance(), true)

func _confirmed() -> void:
	_brand(160)
	_title("El espacio de ejemplo está conectado")
	_label("Vínculo de demostración confirmado. No conecta dos cuentas ni dos teléfonos reales.")
	_label("Ahora podés probar la elección individual de 3 a 5 cualidades.")
	_button("Elegir mis cualidades", "ContinueQualities", func() -> void: flow.continue_to_qualities())

func _error() -> void:
	var messages := {
		"storage": ["No pudimos recuperar tu espacio", "No se pudo leer o guardar el recorrido local. Reintentá sin borrar tus datos."],
		"offline": ["No pudimos conectar", "No se pudo consultar el estado. Reintentá cuando recuperes la conexión."],
		"invalid_pin": ["Ese PIN no coincide", "Revisá el PIN o el link. En esta demostración sólo funcionan las invitaciones creadas en este dispositivo."],
		"expired": ["La invitación venció", "Pedí una nueva invitación o prepará otro ejemplo local."],
		"cancelled": ["La invitación fue cancelada", "Podés pedir otra invitación o usar una nueva forma de acceso."],
		"used": ["Esta invitación ya se usó", "No puede crear otro vínculo. Volvé a tu recorrido o pedí una nueva invitación."],
		"self_invitation": ["Esta invitación es tuya", "Para unirte necesitás la invitación de otra persona. Podés preparar la de Alex en la demostración."],
		"already_linked": ["Ya hay un vínculo confirmado", "Volvé al espacio existente. Una persona no puede pertenecer a dos vínculos activos."],
		"name": ["Revisá tu nombre", "Ingresá entre 2 y 30 caracteres para identificar tu acceso de demostración."],
		"camera_denied": ["La cámara no está habilitada", "Podés usar un PIN o un link. Si querés cambiar el permiso, abrí los ajustes de la app."],
		"scanner_unavailable": ["El lector QR aún no está conectado", "Usá el PIN o pegá el link recibido. El adaptador de cámara queda preparado para la integración nativa."],
		"auth": ["Necesitás acceder primero", "Tu invitación permanece pendiente. Completá el acceso para revisarla."],
		"unavailable": ["Invitación no disponible", "Revisá el acceso o pedí una nueva invitación."]
	}
	var message: Array = messages.get(flow.error, messages.unavailable)
	_title(message[0])
	_label(message[1], 16, AppTheme.ERROR)
	if flow.error == "camera_denied":
		_button("Abrir ajustes de la app", "CameraSettings", func() -> void:
			if not platform.open_app_settings(): _status.text = "Abrí los ajustes de permisos de tu dispositivo."
		)
	if flow.error in ["camera_denied", "scanner_unavailable"]:
		_button("Volver al escáner", "RetryCamera", func() -> void: flow.navigate("scan"), true)
		_button("Usar PIN o link", "UsePIN", func() -> void: flow.navigate("join"))
	elif flow.error == "storage" and flow._retry_screen == "loading":
		_button("Reintentar", "RetryLoad", func() -> void: flow.retry())
	elif flow.error == "name":
		_button("Editar nombre", "FixName", func() -> void: flow.navigate("access"))
	else:
		_button("Reintentar", "RetryOperation", func() -> void: flow.retry())
		_button("Volver al espacio" if flow.state.has_pair() else "Usar otra invitación", "RecoverInvitation", func() -> void: flow.return_from_error(), true)

func _preferences() -> void:
	var size_button := _button("Texto normal" if text_scale > 1.0 else "Texto más grande", "OnboardingText", func() -> void:
		flow.save_preferences(1.0 if text_scale > 1.0 else 1.5, true)
		flow.changed.emit()
	, true)
	size_button.disabled = flow.busy
	_label("Movimiento reducido activado. Sin animaciones de carga.", 14, AppTheme.MUTED)

func _brand(height: int) -> void:
	var image := TextureRect.new()
	image.texture = load("res://assets/brand.svg")
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size = Vector2(0, height)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(image)

func _qr(value: String) -> void:
	var encoder := QrCode.new()
	var source := encoder.get_texture(value).get_image()
	encoder.free()
	# Four modules of quiet zone on every side, integer scaling, no smoothing.
	var padded := Image.create(source.get_width() + 8, source.get_height() + 8, false, Image.FORMAT_RGBA8)
	padded.fill(Color.WHITE)
	padded.blit_rect(source, Rect2i(0, 0, source.get_width(), source.get_height()), Vector2i(4, 4))
	padded.resize(padded.get_width() * 5, padded.get_height() * 5, Image.INTERPOLATE_NEAREST)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(center)
	var image := TextureRect.new()
	image.name = "InvitationQR"
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.texture = ImageTexture.create_from_image(padded)
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.custom_minimum_size = Vector2(200, 200)
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	center.add_child(image)
	_label("QR del link local · también podés usar el PIN", 14, AppTheme.MUTED)

func _copy() -> void:
	_status.text = "Link local copiado." if platform.copy_text(str(flow.invitation_view.link)) else "El portapapeles no está disponible. Podés usar el PIN."

func _share() -> void:
	var content := "AppParejas · demostración local. Este link no conecta cuentas ni funciona en otro teléfono.\n" + str(flow.invitation_view.link)
	if not platform.share_text(content): _status.text = "Compartir no está disponible en esta plataforma. Podés copiar el link."
	else: _status.text = "Elegí una app para compartir. La invitación sigue pendiente de aceptación."

func _field(id: String, placeholder: String, length: int) -> LineEdit:
	var field := LineEdit.new()
	field.name = id
	field.placeholder_text = placeholder
	field.max_length = length
	field.custom_minimum_size.y = 56
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_theme_font_size_override("font_size", roundi(16 * text_scale))
	add_child(field)
	return field

func _card(title: String, body: String) -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_theme_stylebox_override("panel", AppTheme.box(AppTheme.SAGE))
	add_child(panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	_label(title, 20, AppTheme.FOREST, column)
	_label(body, 16, AppTheme.INK, column)

func _title(value: String) -> void:
	var label := _label(value, 31)
	label.add_theme_font_override("font", load("res://assets/fonts/Lora.ttf"))

func _label(value: String, size: int = 16, color: Color = AppTheme.INK, parent: Node = null) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", roundi(size * text_scale))
	label.add_theme_constant_override("line_spacing", 5)
	label.add_theme_color_override("font_color", color)
	(parent if parent != null else self).add_child(label)
	return label

func _button(value: String, id: String, action: Callable, secondary: bool = false) -> Button:
	var button := Button.new()
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.name = id
	button.text = value
	button.custom_minimum_size.y = 56
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", roundi(16 * text_scale))
	if secondary:
		var style := AppTheme.box(AppTheme.BACKGROUND)
		style.set_border_width_all(1)
		style.border_color = AppTheme.FOREST
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_color_override("font_color", AppTheme.FOREST)
	button.pressed.connect(action)
	add_child(button)
	return button

func _disable_actions(node: Node) -> void:
	for child: Node in node.get_children():
		if child is BaseButton: child.disabled = true
		if child is LineEdit: child.editable = false
		_disable_actions(child)

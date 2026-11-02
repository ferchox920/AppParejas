extends Control

const OTHER_EXAMPLE: Array[String] = ["sos_respeto", "sos_paciencia", "afe_calidez", "vit_juego", "cui_gratitud"]

var catalog: Dictionary = {}
var selection: Array[String] = ["afe_carino", "sos_respeto", "sos_paciencia", "con_escucha"]
var screen: String = "loading"
var stage: String = "seed"
var active_family: String = "afe"
var reduced_motion: bool = true
var text_scale: float = 1.0
var garden: GardenView
var _body: VBoxContainer
var _counter: Label
var _apply: Button
var first_open := FirstOpenFlow.new()
var platform := PlatformCapabilities.new()
var auto_start: bool = true
var _queued_reference: String = ""
var _margin: MarginContainer
var _scroll: ScrollContainer
var _keyboard_height: int = 0

func _process(_delta: float) -> void:
	if OS.get_name() != "Android": return
	var height := DisplayServer.virtual_keyboard_get_height()
	if height == _keyboard_height: return
	_keyboard_height = height
	_update_safe_area()
	_reveal_focused_field.call_deferred()

func _reveal_focused_field() -> void:
	if not is_instance_valid(_scroll): return
	var focused := get_viewport().gui_get_focus_owner()
	if is_instance_valid(focused) and _scroll.is_ancestor_of(focused):
		_scroll.ensure_control_visible(focused)

func _ready() -> void:
	# Android envía la misma solicitud al usar el gesto o el botón del sistema.
	get_tree().quit_on_go_back = false
	get_tree().auto_accept_quit = false
	get_viewport().size_changed.connect(_update_safe_area)
	theme = AppTheme.create()
	catalog = QualityCatalog.load_catalog()
	if auto_start:
		var connection := BackendConfig.load_settings()
		if connection.mode != "demo":
			var remote := SupabaseInvitationService.new()
			remote.base_url = str(connection.get("url", ""))
			remote.public_key = str(connection.get("public_key", ""))
			first_open.service = remote
			first_open.store = AccountPreferencesStore.new()
	add_child(first_open)
	add_child(platform)
	first_open.changed.connect(_flow_changed)
	platform.invitation_received.connect(func(reference: String) -> void:
		if first_open.busy or screen == "loading": _queued_reference = reference
		else: first_open.receive_reference(reference)
	)
	platform.scan_finished.connect(func(result: Dictionary) -> void:
		if screen != "scan": return
		if result.ok: first_open.receive_reference(result.reference)
		else: first_open._fail(result.error, "scan")
	)
	platform.share_finished.connect(func(ok: bool) -> void:
		if not ok: first_open._fail("unavailable", "invite")
	)
	_render()
	if auto_start: first_open.start()

func _flow_changed() -> void:
	screen = first_open.screen
	text_scale = float(first_open.state.preferences.text_scale)
	reduced_motion = bool(first_open.state.preferences.reduced_motion)
	if DisplayServer.accessibility_should_reduce_animation() == 1: reduced_motion = true
	theme.default_font_size = roundi(16 * text_scale)
	theme.set_font_size("font_size", "Button", roundi(16 * text_scale))
	if not first_open.state.selection.is_empty():
		if QualityCatalog.validate_selection(first_open.state.selection, catalog).is_empty():
			selection = first_open.state.selection.duplicate()
	_render()
	if not first_open.busy and screen != "loading":
		if not _queued_reference.is_empty():
			var reference := _queued_reference
			_queued_reference = ""
			first_open.receive_reference.call_deferred(reference)
		else: platform.read_launch_invitation.call_deferred()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: get_tree().quit()
	if what == NOTIFICATION_APPLICATION_RESUMED and is_instance_valid(platform):
		_update_safe_area.call_deferred()
		platform.read_launch_invitation.call_deferred()
		if first_open.screen == "waiting" and not first_open.busy: first_open.refresh()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_instance_valid(first_open):
		# Esperar a que termine la propagación antes de reconstruir la interfaz.
		_go_back.call_deferred()

func _go_back() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit:
		DisplayServer.virtual_keyboard_hide()
		get_viewport().gui_release_focus()
		return
	if first_open.busy or screen == "loading": return
	platform.cancel_scan()
	match screen:
		"welcome", "garden": pass
		"confirmed":
			if first_open.is_demo(): first_open.navigate("connect")
		"selection": show_screen("garden")
		"scan": first_open.navigate("join")
		"access": first_open.navigate("join" if first_open.state.invitation.action == "join" else "connect")
		"verify": first_open.navigate("access")
		"review", "join": first_open.decline()
		"intro":
			if first_open.intro_step > 0:
				first_open.intro_step -= 1
				first_open.navigate("intro")
			else:
				first_open.navigate("welcome" if first_open.state.introduction == "new" else "connect")
		"connect":
			if first_open.state.has_pair():
				first_open.navigate("garden" if first_open.is_demo() else "confirmed")
			else: first_open.navigate("welcome")
		"error": first_open.return_from_error()
		_: first_open.navigate("connect")

func show_screen(next_screen: String) -> void:
	screen = next_screen
	first_open.screen = next_screen
	_render()

func set_stage(next_stage: String) -> void:
	stage = next_stage
	if is_instance_valid(garden):
		garden.show_recipe(RecipePreview.build(selection, OTHER_EXAMPLE, catalog), stage)

func _render() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()
	for child: Node in get_children():
		if child == first_open or child == platform: continue
		remove_child(child)
		child.queue_free()
	var background := ColorRect.new()
	background.color = AppTheme.BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	_margin = margin
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	add_child(margin)
	_update_safe_area()
	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	margin.add_child(scroll)
	_body = VBoxContainer.new()
	_body.mouse_filter = Control.MOUSE_FILTER_PASS
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 16)
	scroll.add_child(_body)
	if screen not in ["garden", "selection"]:
		var view := FirstOpenView.new()
		view.name = "FirstOpenView"
		view.flow = first_open
		view.platform = platform
		view.text_scale = text_scale
		_body.add_child(view)
		get_viewport().gui_release_focus()
		return
	_label("AppParejas · Demostración local", 14, AppTheme.FOREST)
	match screen:
		"selection": _selection()
		_: _garden_screen()
	# Evitar que el foco o un click perteneciente a una pantalla eliminada se reutilice.
	get_viewport().gui_release_focus()

func _update_safe_area() -> void:
	if not is_instance_valid(_margin): return
	var insets := Vector4i.ZERO
	if OS.get_name() == "Android":
		var window := Rect2(Vector2(DisplayServer.window_get_position()), Vector2(DisplayServer.window_get_size()))
		insets = ScreenLayout.safe_insets(Rect2(DisplayServer.get_display_safe_area()), window, get_viewport_rect().size)
	_margin.add_theme_constant_override("margin_left", 24 + insets.x)
	_margin.add_theme_constant_override("margin_top", 24 + insets.y)
	_margin.add_theme_constant_override("margin_right", 24 + insets.z)
	var keyboard_inset := 0
	if OS.get_name() == "Android" and DisplayServer.window_get_size().y > 0:
		keyboard_inset = ceili(_keyboard_height * get_viewport_rect().size.y / DisplayServer.window_get_size().y)
	_margin.add_theme_constant_override("margin_bottom", 24 + maxi(insets.w, keyboard_inset))

func _garden_controls() -> BoxContainer:
	# Con texto aumentado, las acciones se apilan para conservar el ancho táctil.
	var row: BoxContainer = VBoxContainer.new() if text_scale > 1.0 else HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_body.add_child(row)
	return row

func _garden_screen() -> void:
	_title("Alba")
	_label("Dos elecciones de ejemplo, una forma compartida.")
	var stage_row := _garden_controls()
	_button("Semilla", func() -> void: set_stage("seed"), stage_row)
	_button("Primer brote", func() -> void: set_stage("sprout"), stage_row)
	_add_garden()
	var turn_row := _garden_controls()
	_button("Girar ←", func() -> void: garden.turn(-15), turn_row)
	_button("Girar →", func() -> void: garden.turn(15), turn_row)
	var zoom_row := _garden_controls()
	_button("Acercar +", func() -> void: garden.zoom(-0.25), zoom_row)
	_button("Alejar −", func() -> void: garden.zoom(0.25), zoom_row)
	_button("Restablecer cámara", func() -> void: garden.reset_camera())
	var motion := CheckBox.new()
	motion.text = "Movimiento reducido"
	motion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	motion.custom_minimum_size.y = 48
	motion.button_pressed = reduced_motion
	motion.toggled.connect(func(enabled: bool) -> void:
		reduced_motion = enabled
		garden.set_reduced_motion(enabled)
		first_open.save_preferences(text_scale, enabled)
	)
	_body.add_child(motion)
	var text_row := _garden_controls()
	_button("Texto normal", func() -> void: _set_text_scale(1.0), text_row)
	_button("Texto grande", func() -> void: _set_text_scale(1.5), text_row)
	_label("Lo que eligieron cultivar", 20, AppTheme.FOREST)
	var known: Dictionary = QualityCatalog.index(catalog)
	var recipe: Dictionary = RecipePreview.build(selection, OTHER_EXAMPLE, catalog)
	for id: String in recipe.get("selected_union", []):
		var quality: Dictionary = known[id]
		_label(quality["label"], 17, AppTheme.FOREST)
		_label(quality["definition"], 14, AppTheme.MUTED)
	_button("Probar otras cualidades", func() -> void: show_screen("selection"))
	_button("Ver recorrido de conexión", func() -> void: first_open.navigate("connect"))
	_label("Podés explorar ambas etapas de esta vista previa. En la app, el brote aparecerá con el tiempo.", 13, AppTheme.MUTED)

func _selection() -> void:
	_title("¿Qué querés cultivar?")
	_label("Probá entre 3 y 5 cualidades. La otra elección es un ejemplo fijo.")
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 8)
	tabs.add_theme_constant_override("v_separation", 8)
	_body.add_child(tabs)
	for family: Dictionary in catalog["families"]:
		var family_id: String = family["id"]
		var tab: Button = _button(family["label"], func() -> void:
			active_family = family_id
			_render()
		, tabs)
		tab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var text_width: float = theme.default_font.get_string_size(family["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(16 * text_scale)).x
		tab.custom_minimum_size.x = text_width + 32
		if active_family != family_id:
			tab.add_theme_stylebox_override("normal", AppTheme.box(AppTheme.SAGE))
			tab.add_theme_color_override("font_color", AppTheme.FOREST)
	for quality: Dictionary in catalog["qualities"]:
		if quality["family_id"] != active_family:
			continue
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", AppTheme.box(Color.WHITE))
		_body.add_child(card)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 8)
		card.add_child(column)
		var check := CheckBox.new()
		var id: String = quality["id"]
		check.name = id
		check.text = quality["label"]
		check.custom_minimum_size.y = 48
		check.add_theme_font_size_override("font_size", roundi(18 * text_scale))
		check.button_pressed = selection.has(id)
		check.toggled.connect(func(enabled: bool) -> void: _toggle_quality(id, enabled, check))
		column.add_child(check)
		_label(quality["definition"], 14, AppTheme.MUTED, column)
	_counter = _label("", 16, AppTheme.FOREST)
	_apply = _button("Ver semilla de ejemplo", func() -> void:
		first_open.save_selection(selection)
		stage = "seed"
		show_screen("garden")
	)
	_button("Volver", func() -> void: show_screen("garden"))
	_update_selection_status()

func _toggle_quality(id: String, enabled: bool, check: CheckBox) -> void:
	if enabled and not selection.has(id):
		if selection.size() == 5:
			check.set_pressed_no_signal(false)
			_counter.text = "Ya elegiste 5. Quitá una para probar otra."
			return
		selection.append(id)
	elif not enabled:
		selection.erase(id)
	_update_selection_status()

func _update_selection_status() -> void:
	_counter.text = "%d elegidas de 5 · mínimo 3" % selection.size()
	_apply.disabled = QualityCatalog.validate_selection(selection, catalog) != ""

func _set_text_scale(value: float) -> void:
	text_scale = value
	theme.default_font_size = roundi(16 * value)
	theme.set_font_size("font_size", "Button", roundi(16 * value))
	first_open.save_preferences(value, reduced_motion)
	_render()

func _add_garden() -> void:
	garden = GardenView.new()
	garden.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	garden.show_recipe(RecipePreview.build(selection, OTHER_EXAMPLE, catalog), stage)
	garden.reduced_motion = reduced_motion
	_body.add_child(garden)

func _title(text: String) -> void:
	var label: Label = _label(text, 31)
	label.add_theme_font_override("font", load("res://assets/fonts/Lora.ttf"))

func _label(text: String, font_size: int = 16, color: Color = AppTheme.INK, parent: Node = null) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", roundi(font_size * text_scale))
	label.add_theme_color_override("font_color", color)
	(parent if parent != null else _body).add_child(label)
	return label

func _button(text: String, action: Callable, parent: Node = null) -> Button:
	var button := Button.new()
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.text = text
	button.custom_minimum_size.y = 56
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(action)
	(parent if parent != null else _body).add_child(button)
	return button

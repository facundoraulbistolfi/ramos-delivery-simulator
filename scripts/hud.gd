class_name MotoHUD
extends CanvasLayer
## Simplified 2-panel HUD + full-screen North-oriented street map (M) + Teleport selector (TAB).

signal resume_requested
signal restart_requested
signal teleport_requested(target_transform: Transform3D, title: String, subtitle: String)
signal overlay_state_changed(is_blocking_drive: bool)
signal start_location_chosen(location_id: int)
signal order_offer_chosen(offer_index: int)
signal shift_restart_requested
signal game_mode_chosen(mode: int)
signal switch_mode_requested

const INK: Color = Color("101d29")
const PAPER: Color = Color("f4eee2")
const MUTED: Color = Color("a7b6bc")
const ORANGE: Color = Color("ff9854")
const CYAN: Color = Color("68d1d2")
const GREEN: Color = Color("28e070")
const GAME_VERSION: String = "alpha-0.0.2"

var _order_panel: PanelContainer
var _speed_label: Label
var _speed_bar: ProgressBar
var _boost_bar: ProgressBar
var _lap_label: Label
var _time_label: Label
var _best_label: Label
var _toast_panel: PanelContainer
var _toast_label: Label
var _toast_remaining: float = 0.0
var _pause_overlay: ColorRect
var _resume_button: Button
var _route_bar: ProgressBar
var _mission_header_label: Label
var _mission_step_label: Label
var _mission_target_label: Label
var _mission_ref_label: Label
var _mission_item_label: Label
var _mission_payout_label: Label

var _map_overlay: ColorRect
var _map_canvas: FullMapCanvas
var _map_open: bool = false

var _teleport_overlay: ColorRect
var _teleport_list_vbox: VBoxContainer
var _teleport_search: LineEdit
var _teleport_open: bool = false
var _teleport_destinations: Array[Dictionary] = []
var _teleport_active_category: String = "Todos"

# Night shift dialogs
var _start_overlay: ColorRect
var _start_dialog_open: bool = false
var _start_buttons_vbox: VBoxContainer
var _current_start_locations: Array[Dictionary] = []

var _order_overlay: ColorRect
var _order_dialog_open: bool = false
var _order_cards_container: HBoxContainer
var _current_order_offers: Array[Dictionary] = []

var _summary_overlay: ColorRect
var _summary_dialog_open: bool = false
var _summary_money_label: Label
var _summary_orders_label: Label
var _summary_tips_label: Label
var _summary_fines_label: Label
var _summary_duration_label: Label

# Mode selection dialog (Free Roam vs Delivery)
var _mode_selection_overlay: ColorRect
var _mode_selection_open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	var screen: Control = Control.new()
	screen.name = "Interface"
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)

	# 1. Left panel: Delivery order info ("info del pedido por un lado")
	_build_order_panel(screen)
	# 2. Right panel: Speed, current location & bike status ("velocidad, ubicación actual y eso en el otro")
	_build_status_panel(screen)

	_build_toast(screen)
	_build_map_overlay(screen)
	_build_teleport_overlay(screen)
	_build_mode_selection_dialog(screen)
	_build_start_location_dialog(screen)
	_build_order_selection_dialog(screen)
	_build_shift_summary_dialog(screen)
	_build_pause(screen)

	var credit: LinkButton = LinkButton.new()
	credit.text = "© OpenStreetMap contributors · ODbL"
	credit.uri = "https://www.openstreetmap.org/copyright"
	credit.anchor_top = 1.0
	credit.anchor_bottom = 1.0
	credit.offset_left = 24.0
	credit.offset_top = -26.0
	credit.offset_right = 280.0
	credit.offset_bottom = -6.0
	credit.add_theme_font_size_override("font_size", 11)
	credit.add_theme_color_override("font_color", Color(PAPER.r, PAPER.g, PAPER.b, 0.65))
	screen.add_child(credit)

	var ver_lbl: Label = Label.new()
	ver_lbl.text = "Ramos Delivery Simulator · %s" % GAME_VERSION
	ver_lbl.anchor_left = 1.0
	ver_lbl.anchor_right = 1.0
	ver_lbl.anchor_top = 1.0
	ver_lbl.anchor_bottom = 1.0
	ver_lbl.offset_left = -320.0
	ver_lbl.offset_top = -26.0
	ver_lbl.offset_right = -24.0
	ver_lbl.offset_bottom = -6.0
	ver_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ver_lbl.add_theme_font_size_override("font_size", 11)
	ver_lbl.add_theme_color_override("font_color", Color(PAPER.r, PAPER.g, PAPER.b, 0.45))
	screen.add_child(ver_lbl)

	update_route(0.0, 1.0, 0.0, 1647.63, 0.0, "Larrea")
	show_message("SALÍ A RODAR", 3.5)


func setup_map_data(track_node: MotoTrack) -> void:
	if track_node == null:
		return
	if is_instance_valid(_map_canvas):
		_map_canvas.setup_from_track(track_node)
	_teleport_destinations = track_node.get_teleport_destinations()
	_rebuild_teleport_list()


func update_player_transform(world_pos: Vector3, forward_dir: Vector3) -> void:
	if is_instance_valid(_map_canvas):
		_map_canvas.set_player_state(Vector2(world_pos.x, world_pos.z), Vector2(forward_dir.x, forward_dir.z))


func is_map_open() -> bool:
	return _map_open


func is_teleport_open() -> bool:
	return _teleport_open


func is_blocking_gameplay() -> bool:
	return _map_open or _teleport_open or _start_dialog_open or _order_dialog_open or _summary_dialog_open or _mode_selection_open


func show_mode_selection_dialog() -> void:
	_mode_selection_open = true
	if is_instance_valid(_mode_selection_overlay):
		_mode_selection_overlay.visible = true
	overlay_state_changed.emit(is_blocking_gameplay())


func close_mode_selection_dialog() -> void:
	_mode_selection_open = false
	if is_instance_valid(_mode_selection_overlay):
		_mode_selection_overlay.visible = false
	overlay_state_changed.emit(is_blocking_gameplay())


func is_mode_selection_open() -> bool:
	return _mode_selection_open


func set_delivery_mode_active(active: bool) -> void:
	if is_instance_valid(_order_panel):
		_order_panel.visible = active


func show_start_location_dialog(locations: Array[Dictionary]) -> void:
	_current_start_locations = locations
	_rebuild_start_buttons()
	_start_dialog_open = true
	if is_instance_valid(_start_overlay):
		_start_overlay.visible = true
	overlay_state_changed.emit(is_blocking_gameplay())


func close_start_location_dialog() -> void:
	_start_dialog_open = false
	if is_instance_valid(_start_overlay):
		_start_overlay.visible = false
	overlay_state_changed.emit(is_blocking_gameplay())


func show_order_selection_dialog(offers: Array[Dictionary]) -> void:
	_current_order_offers = offers
	_rebuild_order_cards()
	_order_dialog_open = true
	if is_instance_valid(_order_overlay):
		_order_overlay.visible = true
	overlay_state_changed.emit(is_blocking_gameplay())


func close_order_selection_dialog() -> void:
	_order_dialog_open = false
	if is_instance_valid(_order_overlay):
		_order_overlay.visible = false
	overlay_state_changed.emit(is_blocking_gameplay())


func show_shift_summary(summary: Dictionary) -> void:
	_summary_dialog_open = true
	if is_instance_valid(_summary_overlay):
		_summary_overlay.visible = true
		if is_instance_valid(_summary_money_label):
			_summary_money_label.text = "$ %d" % int(summary.get("total_money", 0))
		if is_instance_valid(_summary_orders_label):
			_summary_orders_label.text = "%d pedidos" % int(summary.get("completed_count", 0))
		if is_instance_valid(_summary_tips_label):
			_summary_tips_label.text = "$ %d" % int(summary.get("total_tips", 0))
		if is_instance_valid(_summary_fines_label):
			var fines: int = int(summary.get("total_crash_fines", 0))
			var crashes: int = int(summary.get("crash_count", 0))
			_summary_fines_label.text = "-$ %d (%d)" % [fines, crashes]
	overlay_state_changed.emit(is_blocking_gameplay())


func close_shift_summary() -> void:
	_summary_dialog_open = false
	if is_instance_valid(_summary_overlay):
		_summary_overlay.visible = false
	overlay_state_changed.emit(is_blocking_gameplay())


func close_all_modals() -> void:
	close_mode_selection_dialog()
	close_start_location_dialog()
	close_order_selection_dialog()
	close_shift_summary()
	set_map_open(false)
	set_teleport_open(false)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	var key: int = (event as InputEventKey).physical_keycode
	if _mode_selection_open:
		if key == KEY_1 or key == KEY_KP_1:
			close_mode_selection_dialog()
			game_mode_chosen.emit(1)
			get_viewport().set_input_as_handled()
		elif key == KEY_2 or key == KEY_KP_2:
			close_mode_selection_dialog()
			game_mode_chosen.emit(2)
			get_viewport().set_input_as_handled()
		elif key == KEY_ENTER or key == KEY_SPACE:
			close_mode_selection_dialog()
			game_mode_chosen.emit(1)
			get_viewport().set_input_as_handled()
	elif _start_dialog_open:
		if key >= KEY_1 and key <= KEY_6:
			var loc_id: int = key - KEY_1 + 1
			close_start_location_dialog()
			start_location_chosen.emit(loc_id)
			get_viewport().set_input_as_handled()
		elif key == KEY_ENTER or key == KEY_SPACE:
			close_start_location_dialog()
			start_location_chosen.emit(1)
			get_viewport().set_input_as_handled()
	elif _order_dialog_open:
		if key >= KEY_1 and key <= KEY_3:
			var off_idx: int = key - KEY_1
			close_order_selection_dialog()
			order_offer_chosen.emit(off_idx)
			get_viewport().set_input_as_handled()
		elif key == KEY_ENTER or key == KEY_SPACE:
			close_order_selection_dialog()
			order_offer_chosen.emit(0)
			get_viewport().set_input_as_handled()
	elif _summary_dialog_open:
		if key == KEY_R or key == KEY_ENTER or key == KEY_SPACE:
			close_shift_summary()
			shift_restart_requested.emit()
			get_viewport().set_input_as_handled()


func toggle_map() -> void:
	set_map_open(not _map_open)


func set_map_open(open: bool) -> void:
	if open and _teleport_open:
		_teleport_open = false
		if is_instance_valid(_teleport_overlay):
			_teleport_overlay.visible = false
	_map_open = open
	if is_instance_valid(_map_overlay):
		_map_overlay.visible = _map_open
	if _map_open and is_instance_valid(_map_canvas):
		_map_canvas.center_on_player()
		_map_canvas.queue_redraw()
	overlay_state_changed.emit(is_blocking_gameplay())


func toggle_teleport_menu() -> void:
	set_teleport_open(not _teleport_open)


func set_teleport_open(open: bool) -> void:
	if open and _map_open:
		_map_open = false
		if is_instance_valid(_map_overlay):
			_map_overlay.visible = false
	_teleport_open = open
	if is_instance_valid(_teleport_overlay):
		_teleport_overlay.visible = _teleport_open
		if _teleport_open and is_instance_valid(_teleport_search):
			_teleport_search.text = ""
			_rebuild_teleport_list()
			_teleport_search.grab_focus()
	overlay_state_changed.emit(is_blocking_gameplay())


func update_route(speed_kmh: float, boost_ratio: float, station: float, length_m: float, elapsed: float, crossing: String) -> void:
	_speed_label.text = "%03d" % roundi(absf(speed_kmh))
	_speed_bar.value = clampf(absf(speed_kmh) / 160.0, 0.0, 1.0)
	_boost_bar.value = boost_ratio
	_best_label.text = crossing
	_lap_label.text = "%04d / %04d m" % [roundi(station), roundi(length_m)]
	_time_label.text = _format_time(elapsed)
	_route_bar.value = station / maxf(1.0, length_m)


func update_mission(state_data: Dictionary) -> void:
	if not is_instance_valid(_mission_target_label):
		return
	var st: int = int(state_data.get("state", 0))
	var completed: int = int(state_data.get("completed", 0))
	var money: int = int(state_data.get("total_money", 0))
	var shift_time: float = float(state_data.get("shift_time_remaining", 600.0))
	var shift_mins: int = floori(shift_time / 60.0)
	var shift_secs: int = int(shift_time) % 60
	if money >= 0:
		_mission_header_label.text = "TURNO: %02d:%02d · BILLETERA: $ %d · ENTREGAS: %d" % [
			shift_mins, shift_secs, money, completed
		]
		_mission_header_label.add_theme_color_override("font_color", CYAN)
	else:
		_mission_header_label.text = "TURNO: %02d:%02d · BILLETERA: -$ %d (EN ROJO) · ENTREGAS: %d" % [
			shift_mins, shift_secs, abs(money), completed
		]
		_mission_header_label.add_theme_color_override("font_color", Color("ff4838"))

	if st == 1: # PICKUP
		var prep_rem: float = float(state_data.get("prep_time_remaining", 0.0))
		var is_ready: bool = bool(state_data.get("order_ready", false))
		if is_ready:
			_mission_step_label.text = "RETIRAR EN LOCAL · ¡LISTO EN COCINA! (TIEMPO PAR CORRIENDO):"
			_mission_step_label.add_theme_color_override("font_color", GREEN)
		else:
			_mission_step_label.text = "RETIRAR EN LOCAL · PREPARACIÓN EN COCINA: %d s" % roundi(prep_rem)
			_mission_step_label.add_theme_color_override("font_color", ORANGE)
		_mission_target_label.text = str(state_data.get("locale_name", "")).to_upper()
		_mission_ref_label.text = "%s (%s)" % [str(state_data.get("locale_address", "")), str(state_data.get("locale_between", ""))]
		_mission_item_label.text = "Ítem: %s (Precio: $ %d)" % [str(state_data.get("order_item", "")), int(state_data.get("product_price", 0))]
		_mission_payout_label.text = "Tarifa base: $ %d · Propina máx: $ %d" % [
			int(state_data.get("base_fee", 0)), int(state_data.get("max_tip", 0))
		]
		_mission_payout_label.add_theme_color_override("font_color", CYAN)
	elif st == 2: # DELIVER
		var cur_tip: int = roundi(float(state_data.get("current_tip", 0.0)))
		var max_tip: int = int(state_data.get("max_tip", 0))
		var par_t: float = float(state_data.get("par_time", 60.0))
		var deliv_el: float = float(state_data.get("delivery_elapsed", 0.0))
		var par_rem: float = par_t - deliv_el
		if par_rem >= 0.0:
			_mission_step_label.text = "ENTREGAR EN DIRECCIÓN · TIEMPO PAR: %02d:%02d (A TIEMPO):" % [
				floori(par_rem / 60.0), int(par_rem) % 60
			]
			_mission_step_label.add_theme_color_override("font_color", GREEN)
			_mission_payout_label.text = "Tarifa: $ %d · Propina: $ %d (100%% intacta)" % [
				int(state_data.get("base_fee", 0)), cur_tip
			]
			_mission_payout_label.add_theme_color_override("font_color", GREEN)
		else:
			var overdue: int = roundi(-par_rem)
			_mission_step_label.text = "ENTREGAR · DEMORADO +%d s (PERDIENDO PROPINA):" % overdue
			_mission_step_label.add_theme_color_override("font_color", Color("ff4838"))
			_mission_payout_label.text = "Tarifa: $ %d · Propina restante: $ %d / $ %d" % [
				int(state_data.get("base_fee", 0)), cur_tip, max_tip
			]
			_mission_payout_label.add_theme_color_override("font_color", ORANGE if cur_tip > 0 else Color("ff4838"))

		_mission_target_label.text = str(state_data.get("dest_address", "")).to_upper()
		_mission_ref_label.text = "%s · Ramos Mejía" % str(state_data.get("dest_between", ""))
		_mission_item_label.text = "Llevando: %s (%s)" % [str(state_data.get("order_item", "")), str(state_data.get("locale_name", ""))]
	elif st == 3: # ORDER_SELECTION
		_mission_step_label.text = "SELECCIÓN DE PEDIDOS:"
		_mission_step_label.add_theme_color_override("font_color", CYAN)
		_mission_target_label.text = "ELEGÍ 1 DE LOS 3 PEDIDOS DISPONIBLES"
		_mission_ref_label.text = "Presioná [1], [2] o [3] en el teclado o hacé click en la tarjeta"
		_mission_item_label.text = "Compará distancia, precio del producto y propina"
		_mission_payout_label.text = ""


func _process(delta: float) -> void:
	if _toast_remaining > 0.0:
		_toast_remaining = maxf(0.0, _toast_remaining - delta)
		_toast_panel.modulate.a = minf(1.0, _toast_remaining * 3.0)
		_toast_panel.visible = _toast_remaining > 0.0


func show_message(message: String, duration: float = 2.5) -> void:
	if not is_instance_valid(_toast_label):
		return
	_toast_label.text = message
	_toast_remaining = maxf(duration, 0.1)
	_toast_panel.modulate.a = 1.0
	_toast_panel.show()


func set_paused(paused: bool) -> void:
	if not is_instance_valid(_pause_overlay):
		return
	_pause_overlay.visible = paused
	if paused:
		_resume_button.grab_focus()


func _build_order_panel(screen: Control) -> void:
	var panel: PanelContainer = _panel(screen, Rect2(24.0, 24.0, 440.0, 182.0), Vector2.ZERO)
	panel.name = "OrderPanel"
	_order_panel = panel
	var rows: VBoxContainer = _rows(panel, 4)
	_mission_header_label = _label(rows, "TURNO: 10:00 · BILLETERA: $ 0 · ENTREGAS: 0", 11, CYAN)
	_mission_step_label = _label(rows, "RETIRAR EN LOCAL:", 12, ORANGE)
	_mission_target_label = _label(rows, "CARGANDO PEDIDO...", 18, PAPER)
	_mission_target_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mission_ref_label = _label(rows, "Buscando dirección en Ramos Mejía", 13, CYAN)
	_mission_item_label = _label(rows, "Guiate por los carteles de las calles", 12, MUTED)
	_mission_payout_label = _label(rows, "Tarifa: $ 0 · Propina: $ 0", 12, GREEN)
	var shortcuts: Label = _label(rows, "[M] Mapa   [TAB] Teletransporte   [N] Elegir pedidos", 11, Color(MUTED.r, MUTED.g, MUTED.b, 0.85))
	shortcuts.add_theme_constant_override("line_spacing", 0)


func _build_status_panel(screen: Control) -> void:
	var panel: PanelContainer = _panel(screen, Rect2(-328.0, 24.0, 304.0, 168.0), Vector2.RIGHT)
	panel.name = "StatusPanel"
	var rows: VBoxContainer = _rows(panel, 5)

	# Current street / bridge location at the top
	var loc_header: Label = _label(rows, "UBICACIÓN ACTUAL", 10, CYAN)
	loc_header.add_theme_color_override("font_color", CYAN)
	_best_label = _label(rows, "Larrea", 16, PAPER)
	_best_label.clip_text = true

	# Speedometer row
	var speed_row: HBoxContainer = HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 10)
	rows.add_child(speed_row)
	_speed_label = _label(speed_row, "000", 44, PAPER)
	var right_meta: VBoxContainer = VBoxContainer.new()
	right_meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_meta.alignment = BoxContainer.ALIGNMENT_CENTER
	speed_row.add_child(right_meta)
	_label(right_meta, "KM/H", 12, ORANGE)
	_time_label = _label(right_meta, "00:00.00", 13, MUTED)
	_lap_label = _label(right_meta, "0000 / 1648 m", 10, MUTED)
	_lap_label.visible = false

	_speed_bar = _bar(rows, ORANGE, 5.0)

	var boost_row: HBoxContainer = HBoxContainer.new()
	boost_row.add_theme_constant_override("separation", 10)
	rows.add_child(boost_row)
	_label(boost_row, "TURBO", 11, CYAN)
	_boost_bar = _bar(boost_row, CYAN, 5.0)
	_boost_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boost_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	_route_bar = _bar(rows, CYAN, 2.0)
	_route_bar.visible = false


func _build_map_overlay(screen: Control) -> void:
	_map_overlay = ColorRect.new()
	_map_overlay.name = "MapOverlay"
	_map_overlay.color = Color("131a21")
	_map_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_map_overlay.visible = false
	screen.add_child(_map_overlay)

	_map_canvas = FullMapCanvas.new()
	_map_canvas.name = "MapCanvas"
	_map_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_overlay.add_child(_map_canvas)

	# Top interactive toolbar inside map overlay
	var header_panel: PanelContainer = _panel(_map_overlay, Rect2(16.0, 14.0, 820.0, 58.0), Vector2.ZERO)
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	header_panel.add_child(hbox)
	var title_lbl: Label = _label(hbox, "PLANO DE CALLES · RAMOS MEJÍA (NORTE ↑)", 16, PAPER)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var btn_zoom_in: Button = _button(hbox, " + ")
	btn_zoom_in.custom_minimum_size = Vector2(36.0, 32.0)
	btn_zoom_in.tooltip_text = "Acercar [+] "
	btn_zoom_in.pressed.connect(func() -> void: if is_instance_valid(_map_canvas): _map_canvas.zoom_by(1.25))

	var btn_zoom_out: Button = _button(hbox, " - ")
	btn_zoom_out.custom_minimum_size = Vector2(36.0, 32.0)
	btn_zoom_out.tooltip_text = "Alejar [-]"
	btn_zoom_out.pressed.connect(func() -> void: if is_instance_valid(_map_canvas): _map_canvas.zoom_by(1.0 / 1.25))

	var btn_center: Button = _button(hbox, "MI UBICACIÓN [C]")
	btn_center.custom_minimum_size = Vector2(145.0, 32.0)
	btn_center.pressed.connect(func() -> void: if is_instance_valid(_map_canvas): _map_canvas.center_on_player())

	var btn_close: Button = _button(hbox, "VOLVER A MANEJAR [M]")
	btn_close.custom_minimum_size = Vector2(175.0, 32.0)
	btn_close.pressed.connect(func() -> void: set_map_open(false))


func _build_teleport_overlay(screen: Control) -> void:
	_teleport_overlay = ColorRect.new()
	_teleport_overlay.name = "TeleportOverlay"
	_teleport_overlay.color = Color(0.03, 0.06, 0.09, 0.90)
	_teleport_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_teleport_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_teleport_overlay.visible = false
	screen.add_child(_teleport_overlay)

	var modal: PanelContainer = _panel(_teleport_overlay, Rect2(-420.0, -280.0, 840.0, 560.0), Vector2(0.5, 0.5))
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	var rows: VBoxContainer = _rows(modal, 10)

	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	rows.add_child(top_row)
	var title: Label = _label(top_row, "TELETRANSPORTE · ELEGÍ UN LUGAR DE RAMOS MEJÍA", 20, PAPER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close_btn: Button = _button(top_row, "CERRAR [TAB]")
	close_btn.custom_minimum_size = Vector2(140.0, 36.0)
	close_btn.pressed.connect(func() -> void: set_teleport_open(false))

	# Filter search bar + Category buttons
	var filter_row: HBoxContainer = HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 8)
	rows.add_child(filter_row)

	_teleport_search = LineEdit.new()
	_teleport_search.placeholder_text = "Buscar puente, plaza, comercio, calle..."
	_teleport_search.custom_minimum_size = Vector2(240.0, 34.0)
	_teleport_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_teleport_search.text_changed.connect(func(_new_text: String) -> void: _rebuild_teleport_list())
	filter_row.add_child(_teleport_search)

	var categories: Array[String] = [
		"Todos",
		"Centro y Puntos Clave",
		"Puentes y Cruces Ferroviarios",
		"Edificios Emblemáticos",
		"Centro Comercial y Locales",
	]
	for cat: String in categories:
		var cat_btn: Button = Button.new()
		cat_btn.text = cat
		cat_btn.custom_minimum_size.y = 34.0
		cat_btn.add_theme_font_size_override("font_size", 12)
		cat_btn.pressed.connect(func() -> void:
			_teleport_active_category = cat
			_rebuild_teleport_list()
		)
		filter_row.add_child(cat_btn)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(780.0, 410.0)
	rows.add_child(scroll)

	_teleport_list_vbox = VBoxContainer.new()
	_teleport_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_teleport_list_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(_teleport_list_vbox)


func _rebuild_teleport_list() -> void:
	if not is_instance_valid(_teleport_list_vbox):
		return
	for child: Node in _teleport_list_vbox.get_children():
		child.queue_free()

	var query: String = _teleport_search.text.strip_edges().to_lower() if is_instance_valid(_teleport_search) else ""
	for item: Dictionary in _teleport_destinations:
		var cat: String = str(item.get("category", ""))
		if _teleport_active_category != "Todos" and cat != _teleport_active_category:
			continue
		var item_name: String = str(item.get("name", ""))
		var item_sub: String = str(item.get("subtitle", ""))
		if not query.is_empty():
			var hay: String = (item_name + " " + item_sub + " " + cat).to_lower()
			if not hay.contains(query):
				continue

		var btn: Button = Button.new()
		btn.custom_minimum_size.y = 42.0
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.text = "  [%s]   %s   —   %s" % [cat.to_upper(), item_name, item_sub]
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_color_override("font_color", PAPER)
		var st_norm: StyleBoxFlat = StyleBoxFlat.new()
		st_norm.bg_color = Color(0.11, 0.19, 0.26, 0.92)
		st_norm.border_color = Color(0.40, 0.58, 0.65, 0.35)
		st_norm.set_border_width_all(1)
		st_norm.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", st_norm)
		var st_hover: StyleBoxFlat = st_norm.duplicate() as StyleBoxFlat
		st_hover.bg_color = Color(0.18, 0.32, 0.42, 0.98)
		st_hover.border_color = ORANGE
		btn.add_theme_stylebox_override("hover", st_hover)
		var target_tf: Transform3D = item["transform"] as Transform3D
		btn.pressed.connect(func() -> void:
			set_teleport_open(false)
			teleport_requested.emit(target_tf, item_name, item_sub)
		)
		_teleport_list_vbox.add_child(btn)


func _build_toast(screen: Control) -> void:
	_toast_panel = _panel(screen, Rect2(-240.0, -35.0, 480.0, 70.0), Vector2(0.5, 0.22))
	_toast_label = _label(_toast_panel, "SALÍ A RODAR", 18, PAPER)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_panel.hide()


func _build_pause(screen: Control) -> void:
	_pause_overlay = ColorRect.new()
	_pause_overlay.name = "PauseOverlay"
	_pause_overlay.color = Color(0.025, 0.05, 0.075, 0.83)
	_pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	screen.add_child(_pause_overlay)
	var panel: PanelContainer = _panel(_pause_overlay, Rect2(-210.0, -195.0, 420.0, 390.0), Vector2(0.5, 0.5))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var rows: VBoxContainer = _rows(panel, 14)
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	var title: Label = _label(rows, "EN PAUSA", 34, PAPER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle: Label = _label(rows, "Ramos Mejía · Recorrido y Reparto", 14, MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_resume_button = _button(rows, "SEGUIR RODANDO")
	_resume_button.pressed.connect(func() -> void: resume_requested.emit())
	var switch_mode_btn: Button = _button(rows, "CAMBIAR MODO DE JUEGO")
	switch_mode_btn.pressed.connect(func() -> void:
		_pause_overlay.hide()
		switch_mode_requested.emit()
	)
	var restart_button: Button = _button(rows, "REINICIAR SESIÓN")
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	var hint: Label = _label(rows, "ESC para continuar", 12, MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_overlay.hide()


func _build_mode_selection_dialog(screen: Control) -> void:
	_mode_selection_overlay = ColorRect.new()
	_mode_selection_overlay.name = "ModeSelectionOverlay"
	_mode_selection_overlay.color = Color(0.02, 0.04, 0.07, 0.94)
	_mode_selection_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mode_selection_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_mode_selection_overlay.visible = false
	screen.add_child(_mode_selection_overlay)

	var modal: PanelContainer = _panel(_mode_selection_overlay, Rect2(-430.0, -260.0, 860.0, 520.0), Vector2(0.5, 0.5))
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	var rows: VBoxContainer = _rows(modal, 16)
	rows.alignment = BoxContainer.ALIGNMENT_CENTER

	var title: Label = _label(rows, "RAMOS MEJÍA: SELECCIÓN DE MODO", 26, PAPER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle: Label = _label(rows, "Elegí tu experiencia de juego para recorrer el barrio", 14, CYAN)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var cards_row: HBoxContainer = HBoxContainer.new()
	cards_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_row.add_theme_constant_override("separation", 20)
	rows.add_child(cards_row)

	# --- CARD 1: MODO DELIVERY ---
	var card1: PanelContainer = PanelContainer.new()
	card1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var c1_vbox: VBoxContainer = _rows(card1, 10)
	cards_row.add_child(card1)

	var c1_header: Label = _label(c1_vbox, "[1] MODO DELIVERY", 18, ORANGE)
	c1_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var c1_sub: Label = _label(c1_vbox, "Turno de 10 min · Misiones y propinas", 12, MUTED)
	c1_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var c1_desc: Label = _label(c1_vbox,
		"• Elegí tu punto de partida en el centro o plazas de Ramos.\n" +
		"• 3 opciones simultáneas de pedidos gastronómicos.\n" +
		"• Retirá en restaurantes y entregá a tiempo para ganar propinas.\n" +
		"• ¡Atención al tráfico! Chocar contra autos (en circulación o estacionados) descuenta plata de tu billetera según la gravedad del impacto.",
		12, PAPER
	)
	c1_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c1_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var btn1: Button = _button(c1_vbox, "ELEGIR MODO DELIVERY [1]")
	btn1.pressed.connect(func() -> void:
		close_mode_selection_dialog()
		game_mode_chosen.emit(1)
	)

	# --- CARD 2: MODO LIBRE / DEBUG ---
	var card2: PanelContainer = PanelContainer.new()
	card2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var c2_vbox: VBoxContainer = _rows(card2, 10)
	cards_row.add_child(card2)

	var c2_header: Label = _label(c2_vbox, "[2] MODO LIBRE / DEBUG", 18, CYAN)
	c2_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var c2_sub: Label = _label(c2_vbox, "Paseo libre · Teletransporte sin límites", 12, MUTED)
	c2_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var c2_desc: Label = _label(c2_vbox,
		"• Explorá todo el mapa de Ramos Mejía a tu propio ritmo.\n" +
		"• Menú completo de teletransporte rápido [TAB] a todas las esquinas y puentes.\n" +
		"• Mapa interactivo [M] orientado al Norte.\n" +
		"• Atajos rápidos a puntos clave y monumentos.\n" +
		"• Sin misiones obligatorias ni penalizaciones por choque.",
		12, PAPER
	)
	c2_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c2_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var btn2: Button = _button(c2_vbox, "ELEGIR MODO LIBRE [2]")
	btn2.pressed.connect(func() -> void:
		close_mode_selection_dialog()
		game_mode_chosen.emit(2)
	)

	var footer: Label = _label(rows, "Presioná [1] o [2] en el teclado o hacé click en el modo deseado.", 12, MUTED)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _build_start_location_dialog(screen: Control) -> void:
	_start_overlay = ColorRect.new()
	_start_overlay.name = "StartLocationOverlay"
	_start_overlay.color = Color(0.02, 0.04, 0.07, 0.92)
	_start_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_start_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_start_overlay.visible = false
	screen.add_child(_start_overlay)

	var modal: PanelContainer = _panel(_start_overlay, Rect2(-380.0, -260.0, 760.0, 520.0), Vector2(0.5, 0.5))
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	var rows: VBoxContainer = _rows(modal, 12)

	_label(rows, "TURNO NOCTURNO · RAMOS MEJÍA", 22, PAPER)
	_label(rows, "Elegí dónde arrancar la noche (Objetivo: juntar la mayor cantidad de plata en 10 minutos):", 13, CYAN)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(scroll)

	_start_buttons_vbox = VBoxContainer.new()
	_start_buttons_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start_buttons_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(_start_buttons_vbox)

	var hint: Label = _label(rows, "Presioná [1] a [6] en el teclado o hacé click en una ubicación para comenzar.", 12, MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _rebuild_start_buttons() -> void:
	if not is_instance_valid(_start_buttons_vbox):
		return
	for child: Node in _start_buttons_vbox.get_children():
		child.queue_free()

	for loc: Dictionary in _current_start_locations:
		var loc_id: int = int(loc.get("id", 1))
		var btn: Button = Button.new()
		btn.custom_minimum_size.y = 54.0
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		var btn_box: HBoxContainer = HBoxContainer.new()
		btn_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		btn_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn_box.add_theme_constant_override("separation", 14)
		btn.add_child(btn_box)

		var tag_lbl: Label = _label(btn_box, " [%d] " % loc_id, 14, INK)
		var tag_panel: PanelContainer = PanelContainer.new()
		tag_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tag_style: StyleBoxFlat = StyleBoxFlat.new()
		tag_style.bg_color = ORANGE
		tag_style.corner_radius_top_left = 3
		tag_style.corner_radius_top_right = 3
		tag_style.corner_radius_bottom_left = 3
		tag_style.corner_radius_bottom_right = 3
		tag_panel.add_theme_stylebox_override("panel", tag_style)
		btn_box.remove_child(tag_lbl)
		tag_panel.add_child(tag_lbl)
		btn_box.add_child(tag_panel)

		var text_col: VBoxContainer = VBoxContainer.new()
		text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_box.add_child(text_col)

		_label(text_col, str(loc.get("name", "")), 15, PAPER)
		_label(text_col, str(loc.get("desc", "")), 12, MUTED)

		btn.pressed.connect(func() -> void:
			close_start_location_dialog()
			start_location_chosen.emit(loc_id)
		)
		_start_buttons_vbox.add_child(btn)


func _build_order_selection_dialog(screen: Control) -> void:
	_order_overlay = ColorRect.new()
	_order_overlay.name = "OrderSelectionOverlay"
	_order_overlay.color = Color(0.02, 0.04, 0.07, 0.92)
	_order_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_order_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_order_overlay.visible = false
	screen.add_child(_order_overlay)

	var modal: PanelContainer = _panel(_order_overlay, Rect2(-540.0, -270.0, 1080.0, 540.0), Vector2(0.5, 0.5))
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	var rows: VBoxContainer = _rows(modal, 12)

	_label(rows, "NUEVOS PEDIDOS DISPONIBLES EN RAMOS MEJÍA", 22, PAPER)
	_label(rows, "Evaluá la distancia, el precio del producto y la propina. Elegí 1 de los 3 pedidos [Teclas 1, 2, 3]:", 13, CYAN)

	_order_cards_container = HBoxContainer.new()
	_order_cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_order_cards_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_order_cards_container.add_theme_constant_override("separation", 14)
	rows.add_child(_order_cards_container)

	var bottom_row: HBoxContainer = HBoxContainer.new()
	rows.add_child(bottom_row)
	var hint: Label = _label(bottom_row, "Presioná [1], [2] o [3] para aceptar el pedido correspondiente.", 12, MUTED)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _rebuild_order_cards() -> void:
	if not is_instance_valid(_order_cards_container):
		return
	for child: Node in _order_cards_container.get_children():
		child.queue_free()

	for offer: Dictionary in _current_order_offers:
		var idx: int = int(offer.get("index", 0))
		var card: PanelContainer = PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL

		var card_style: StyleBoxFlat = StyleBoxFlat.new()
		card_style.bg_color = Color(0.08, 0.14, 0.19, 0.95)
		card_style.border_color = Color(0.40, 0.65, 0.75, 0.45)
		card_style.set_border_width_all(1)
		card_style.set_corner_radius_all(6)
		card_style.content_margin_left = 14.0
		card_style.content_margin_right = 14.0
		card_style.content_margin_top = 12.0
		card_style.content_margin_bottom = 12.0
		card.add_theme_stylebox_override("panel", card_style)

		var crows: VBoxContainer = _rows(card, 6)

		# Top badge
		var badge_row: HBoxContainer = HBoxContainer.new()
		crows.add_child(badge_row)
		_label(badge_row, "PEDIDO #%d [TECLA %d]" % [idx + 1, idx + 1], 12, ORANGE)

		var loc: Dictionary = offer.get("locale", {})
		_label(crows, str(loc.get("name", "Local")), 17, PAPER)
		_label(crows, "%s (%s)" % [str(loc.get("address", "")), str(loc.get("between", ""))], 11, CYAN)

		_label(crows, "ÍTEM A TRANSPORTAR:", 10, MUTED)
		_label(crows, str(offer.get("order_item", "")), 13, PAPER)
		_label(crows, "Valor del producto: $ %d" % int(offer.get("product_price", 0)), 12, ORANGE)

		var dest: Dictionary = offer.get("dest_address", {})
		_label(crows, "ENTREGA:", 10, MUTED)
		_label(crows, str(dest.get("full_address", "Dirección")), 14, PAPER)
		_label(crows, str(dest.get("between", "")), 11, CYAN)

		var total_d: float = float(offer.get("total_dist", 0.0))
		var prep_t: float = float(offer.get("prep_time", 20.0))
		var par_t: float = float(offer.get("par_time", 60.0))
		_label(crows, "DISTANCIA TOTAL: %.1f km" % (total_d / 1000.0), 12, PAPER)
		_label(crows, "Cocina: %d s · Tiempo PAR: %02d:%02d" % [roundi(prep_t), floori(par_t / 60.0), int(par_t) % 60], 11, MUTED)

		# Payout highlight
		var payout_box: PanelContainer = PanelContainer.new()
		var pstyle: StyleBoxFlat = StyleBoxFlat.new()
		pstyle.bg_color = Color(0.12, 0.22, 0.16, 0.85)
		pstyle.border_color = GREEN
		pstyle.set_border_width_all(1)
		pstyle.set_corner_radius_all(4)
		pstyle.content_margin_left = 10.0
		pstyle.content_margin_right = 10.0
		pstyle.content_margin_top = 8.0
		pstyle.content_margin_bottom = 8.0
		payout_box.add_theme_stylebox_override("panel", pstyle)
		crows.add_child(payout_box)

		var prows: VBoxContainer = VBoxContainer.new()
		payout_box.add_child(prows)
		_label(prows, "PAGO ESTIMADO: $ %d" % int(offer.get("total_payout", 0)), 16, GREEN)
		_label(prows, "Tarifa $ %d + Propina máx $ %d" % [int(offer.get("base_fee", 0)), int(offer.get("max_tip", 0))], 11, PAPER)

		var btn: Button = _button(crows, "ACEPTAR PEDIDO [%d]" % (idx + 1))
		btn.pressed.connect(func() -> void:
			close_order_selection_dialog()
			order_offer_chosen.emit(idx)
		)

		_order_cards_container.add_child(card)


func _build_shift_summary_dialog(screen: Control) -> void:
	_summary_overlay = ColorRect.new()
	_summary_overlay.name = "ShiftSummaryOverlay"
	_summary_overlay.color = Color(0.02, 0.04, 0.07, 0.94)
	_summary_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_summary_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_summary_overlay.visible = false
	screen.add_child(_summary_overlay)

	var modal: PanelContainer = _panel(_summary_overlay, Rect2(-350.0, -210.0, 700.0, 420.0), Vector2(0.5, 0.5))
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	var rows: VBoxContainer = _rows(modal, 14)
	rows.alignment = BoxContainer.ALIGNMENT_CENTER

	var t1: Label = _label(rows, "¡FIN DE LA JORNADA NOCTURNA!", 26, PAPER)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t2: Label = _label(rows, "Completaste 10 minutos de repartos por las calles de Ramos Mejía.", 13, CYAN)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var stats_box: HBoxContainer = HBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 10)
	rows.add_child(stats_box)

	var mc: PanelContainer = PanelContainer.new()
	mc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mr: VBoxContainer = _rows(mc, 4)
	_label(mr, "TOTAL NETO", 11, CYAN)
	_summary_money_label = _label(mr, "$ 0", 20, GREEN)
	stats_box.add_child(mc)

	var dc: PanelContainer = PanelContainer.new()
	dc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var dr: VBoxContainer = _rows(dc, 4)
	_label(dr, "ENTREGAS", 11, CYAN)
	_summary_orders_label = _label(dr, "0 pedidos", 20, PAPER)
	stats_box.add_child(dc)

	var tc: PanelContainer = PanelContainer.new()
	tc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tr: VBoxContainer = _rows(tc, 4)
	_label(tr, "PROPINAS", 11, CYAN)
	_summary_tips_label = _label(tr, "$ 0", 20, ORANGE)
	stats_box.add_child(tc)

	var fc: PanelContainer = PanelContainer.new()
	fc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fr: VBoxContainer = _rows(fc, 4)
	_label(fr, "MULTAS CHOQUES", 11, CYAN)
	_summary_fines_label = _label(fr, "-$ 0", 20, Color("ff6352"))
	stats_box.add_child(fc)

	var restart_btn: Button = _button(rows, "INICIAR NUEVA NOCHE [R]")
	restart_btn.pressed.connect(func() -> void:
		close_shift_summary()
		shift_restart_requested.emit()
	)

	var hint: Label = _label(rows, "Presioná [R] o [ENTER] para volver a jugar.", 12, MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _panel(parent: Control, rectangle: Rect2, anchor: Vector2 = Vector2.ZERO) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	panel.anchor_left = anchor.x
	panel.anchor_right = anchor.x
	panel.anchor_top = anchor.y
	panel.anchor_bottom = anchor.y
	panel.offset_left = rectangle.position.x
	panel.offset_top = rectangle.position.y
	panel.offset_right = rectangle.end.x
	panel.offset_bottom = rectangle.end.y
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(INK.r, INK.g, INK.b, 0.90)
	style.border_color = Color(0.55, 0.69, 0.71, 0.22)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _rows(parent: Node, separation: int) -> VBoxContainer:
	var rows: VBoxContainer = VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", separation)
	parent.add_child(rows)
	return rows


func _label(parent: Node, caption: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = caption
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _bar(parent: Node, color: Color, height: float) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.custom_minimum_size.y = height
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 1.0
	bar.show_percentage = false
	var background: StyleBoxFlat = StyleBoxFlat.new()
	background.bg_color = Color(0.30, 0.41, 0.46, 0.40)
	bar.add_theme_stylebox_override("background", background)
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar


func _button(parent: Node, caption: String) -> Button:
	var button: Button = Button.new()
	button.text = caption
	button.custom_minimum_size.y = 46.0
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	var normal_style: StyleBoxFlat = StyleBoxFlat.new()
	normal_style.bg_color = ORANGE
	normal_style.corner_radius_top_left = 3
	normal_style.corner_radius_top_right = 3
	normal_style.corner_radius_bottom_left = 3
	normal_style.corner_radius_bottom_right = 3
	button.add_theme_stylebox_override("normal", normal_style)
	var hover_style: StyleBoxFlat = normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = PAPER
	button.add_theme_stylebox_override("hover", hover_style)
	var pressed_style: StyleBoxFlat = normal_style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = CYAN
	button.add_theme_stylebox_override("pressed", pressed_style)
	var focus_style: StyleBoxFlat = normal_style.duplicate() as StyleBoxFlat
	focus_style.bg_color = Color.TRANSPARENT
	focus_style.border_color = CYAN
	focus_style.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus_style)
	parent.add_child(button)
	return button


func _format_time(seconds: float) -> String:
	var centiseconds: int = floori(maxf(seconds, 0.0) * 100.0)
	var minutes: int = floori(float(centiseconds) / 6000.0)
	var whole_seconds: int = floori(float(centiseconds) / 100.0) % 60
	return "%02d:%02d.%02d" % [minutes, whole_seconds, centiseconds % 100]


class FullMapCanvas extends Control:
	## Full-screen North-oriented street map of Ramos Mejía & surroundings.
	## Shows ONLY the player's location and all street names; grays out the area outside Ramos Mejía.
	var ramos_boundary: PackedVector2Array = PackedVector2Array()
	var outside_mask_polygons: Array[PackedVector2Array] = []
	var inside_streets: Array[Dictionary] = []
	var extended_streets: Array[Dictionary] = []
	var railways: Array[PackedVector2Array] = []
	var extended_railways: Array[PackedVector2Array] = []
	var bridges: Array[Dictionary] = []
	var street_labels: Array[Dictionary] = []

	var player_pos: Vector2 = Vector2.ZERO
	var player_dir: Vector2 = Vector2(0.0, -1.0)
	var zoom: float = 0.36
	var camera_center: Vector2 = Vector2(-1150.0, 480.0)
	var _dragging: bool = false
	var _first_open: bool = true

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		clip_contents = true

	func setup_from_track(track_node: MotoTrack) -> void:
		var data: Dictionary = track_node.data
		ramos_boundary.clear()
		for pt: Array in data.get("ramos_boundary", []):
			ramos_boundary.append(Vector2(float(pt[0]), float(pt[1])))

		# Build exterior gray-out mask polygons by clipping West/East outer boxes against ramos_boundary
		outside_mask_polygons.clear()
		if ramos_boundary.size() >= 3:
			var split_x: float = -1100.0
			var west_box: PackedVector2Array = PackedVector2Array([
				Vector2(-6500.0, -3500.0),
				Vector2(split_x, -3500.0),
				Vector2(split_x, 5000.0),
				Vector2(-6500.0, 5000.0),
			])
			var east_box: PackedVector2Array = PackedVector2Array([
				Vector2(split_x, -3500.0),
				Vector2(4500.0, -3500.0),
				Vector2(4500.0, 5000.0),
				Vector2(split_x, 5000.0),
			])
			for piece: PackedVector2Array in Geometry2D.clip_polygons(west_box, ramos_boundary):
				if not Geometry2D.is_polygon_clockwise(piece):
					outside_mask_polygons.append(piece)
			for piece: PackedVector2Array in Geometry2D.clip_polygons(east_box, ramos_boundary):
				if not Geometry2D.is_polygon_clockwise(piece):
					outside_mask_polygons.append(piece)

		inside_streets.clear()
		for s: Dictionary in data.get("streets", []) + data.get("roads", []):
			var pts: PackedVector2Array = PackedVector2Array()
			for pt: Array in s.get("points", []):
				pts.append(Vector2(float(pt[0]), float(pt[1])))
			if pts.size() >= 2:
				var min_p: Vector2 = pts[0]
				var max_p: Vector2 = pts[0]
				for p: Vector2 in pts:
					min_p.x = minf(min_p.x, p.x); min_p.y = minf(min_p.y, p.y)
					max_p.x = maxf(max_p.x, p.x); max_p.y = maxf(max_p.y, p.y)
				var kind: String = str(s.get("kind", "primary"))
				var sname: String = str(s.get("name", "Avenida Rivadavia" if not s.has("kind") else ""))
				inside_streets.append({
					"points": pts,
					"name": sname,
					"major": kind in ["trunk", "primary", "secondary"] or sname.begins_with("Avenida"),
					"bbox": Rect2(min_p, max_p - min_p)
				})

		extended_streets.clear()
		for s: Dictionary in data.get("extended_streets", []):
			var pts: PackedVector2Array = PackedVector2Array()
			for pt: Array in s.get("points", []):
				pts.append(Vector2(float(pt[0]), float(pt[1])))
			if pts.size() >= 2:
				var min_p: Vector2 = pts[0]
				var max_p: Vector2 = pts[0]
				for p: Vector2 in pts:
					min_p.x = minf(min_p.x, p.x); min_p.y = minf(min_p.y, p.y)
					max_p.x = maxf(max_p.x, p.x); max_p.y = maxf(max_p.y, p.y)
				extended_streets.append({
					"points": pts,
					"name": str(s.get("name", "")),
					"major": str(s.get("kind", "")) in ["motorway", "trunk", "primary", "secondary"],
					"bbox": Rect2(min_p, max_p - min_p)
				})

		railways.clear()
		for r: Dictionary in data.get("railways", []):
			var pts: PackedVector2Array = PackedVector2Array()
			for pt: Array in r.get("points", []):
				pts.append(Vector2(float(pt[0]), float(pt[1])))
			if pts.size() >= 2:
				railways.append(pts)

		extended_railways.clear()
		for r: Variant in data.get("extended_railways", []):
			var raw_pts: Array = r["points"] if r is Dictionary else (r as Array)
			var pts: PackedVector2Array = PackedVector2Array()
			for pt: Array in raw_pts:
				pts.append(Vector2(float(pt[0]), float(pt[1])))
			if pts.size() >= 2:
				extended_railways.append(pts)

		bridges.clear()
		for b_item: Dictionary in data.get("bridges", []) + data.get("footbridges", []):
			var pts: PackedVector2Array = PackedVector2Array()
			for pt: Array in b_item.get("points_3d", []):
				pts.append(Vector2(float(pt[0]), float(pt[2])))
			if pts.size() >= 2:
				bridges.append({"name": str(b_item.get("name", "Puente")), "points": pts})

		_build_street_label_anchors()

	func _build_street_label_anchors() -> void:
		street_labels.clear()
		# Group segments by street name so every single named street in Ramos Mejía gets clean label placement
		var by_name: Dictionary = {}
		for s: Dictionary in inside_streets:
			var sname: String = str(s.get("name", "")).strip_edges()
			if sname.is_empty():
				continue
			if not by_name.has(sname):
				by_name[sname] = []
			by_name[sname].append(s)

		for sname: String in by_name.keys():
			var seg_list: Array = by_name[sname]
			var is_major: bool = false
			var candidates: Array[Dictionary] = []
			for s: Dictionary in seg_list:
				if bool(s.get("major", false)):
					is_major = true
				var pts: PackedVector2Array = s["points"]
				for i: int in range(pts.size() - 1):
					var a: Vector2 = pts[i]
					var b_pt: Vector2 = pts[i + 1]
					var length: float = a.distance_to(b_pt)
					if length < 18.0:
						continue
					var mid: Vector2 = (a + b_pt) * 0.5
					var d: Vector2 = (b_pt - a).normalized()
					# Keep text upright when oriented North
					if d.x < 0.0:
						d = -d
					candidates.append({
						"pos": mid,
						"angle": d.angle(),
						"len": length
					})
			if candidates.is_empty():
				continue
			candidates.sort_custom(func(u: Dictionary, v: Dictionary) -> bool: return float(u["len"]) > float(v["len"]))
			var placed: Array[Vector2] = []
			var min_spacing: float = 420.0 if is_major else 520.0
			for cand: Dictionary in candidates:
				var cpos: Vector2 = cand["pos"]
				var too_close: bool = false
				for prev: Vector2 in placed:
					if prev.distance_to(cpos) < min_spacing:
						too_close = true
						break
				if not too_close:
					placed.append(cpos)
					street_labels.append({
						"name": sname,
						"pos": cpos,
						"angle": float(cand["angle"]),
						"major": is_major,
						"outside": false
					})
					if placed.size() >= (4 if is_major else 2):
						break

		# Also add major extended street labels outside Ramos Mejía (grayed out)
		var ext_seen: Dictionary = {}
		for s: Dictionary in extended_streets:
			var sname: String = str(s.get("name", "")).strip_edges()
			if sname.is_empty() or not bool(s.get("major", false)) or ext_seen.has(sname):
				continue
			var pts: PackedVector2Array = s["points"]
			var mid_idx: int = pts.size() / 2
			if mid_idx > 0:
				var a: Vector2 = pts[mid_idx - 1]
				var b_pt: Vector2 = pts[mid_idx]
				if a.distance_to(b_pt) > 35.0:
					var d: Vector2 = (b_pt - a).normalized()
					if d.x < 0.0:
						d = -d
					ext_seen[sname] = true
					street_labels.append({
						"name": sname,
						"pos": (a + b_pt) * 0.5,
						"angle": d.angle(),
						"major": true,
						"outside": true
					})

	func set_player_state(pos_xz: Vector2, dir_xz: Vector2) -> void:
		player_pos = pos_xz
		if dir_xz.length_squared() > 0.001:
			player_dir = dir_xz.normalized()
		if is_visible_in_tree():
			queue_redraw()

	func center_on_player() -> void:
		camera_center = player_pos
		zoom = 0.65
		queue_redraw()

	func zoom_by(factor: float) -> void:
		_zoom_at(size * 0.5, factor)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event as InputEventMouseButton
			if mb.pressed:
				if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
					_zoom_at(mb.position, 1.22)
				elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					_zoom_at(mb.position, 1.0 / 1.22)
				elif mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
					_dragging = true
			else:
				if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
					_dragging = false
		elif event is InputEventMouseMotion and _dragging:
			var mm: InputEventMouseMotion = event as InputEventMouseMotion
			camera_center -= mm.relative / zoom
			queue_redraw()
		elif event is InputEventKey and event.pressed:
			var ke: InputEventKey = event as InputEventKey
			var pan_step: float = 65.0 / zoom
			if ke.physical_keycode == KEY_W or ke.physical_keycode == KEY_UP:
				camera_center.y -= pan_step
				queue_redraw()
			elif ke.physical_keycode == KEY_S or ke.physical_keycode == KEY_DOWN:
				camera_center.y += pan_step
				queue_redraw()
			elif ke.physical_keycode == KEY_A or ke.physical_keycode == KEY_LEFT:
				camera_center.x -= pan_step
				queue_redraw()
			elif ke.physical_keycode == KEY_D or ke.physical_keycode == KEY_RIGHT:
				camera_center.x += pan_step
				queue_redraw()
			elif ke.physical_keycode == KEY_C:
				center_on_player()
			elif ke.physical_keycode == KEY_EQUAL or ke.physical_keycode == KEY_KP_ADD:
				zoom_by(1.25)
			elif ke.physical_keycode == KEY_MINUS or ke.physical_keycode == KEY_KP_SUBTRACT:
				zoom_by(1.0 / 1.25)

	func _zoom_at(screen_pt: Vector2, factor: float) -> void:
		var world_before: Vector2 = _screen_to_world(screen_pt)
		zoom = clampf(zoom * factor, 0.16, 2.6)
		var world_after: Vector2 = _screen_to_world(screen_pt)
		camera_center += world_before - world_after
		queue_redraw()

	func _world_to_screen(w: Vector2) -> Vector2:
		return size * 0.5 + (w - camera_center) * zoom

	func _screen_to_world(s: Vector2) -> Vector2:
		return camera_center + (s - size * 0.5) / zoom

	func _draw() -> void:
		var view_rect: Rect2 = Rect2(Vector2.ZERO, size)
		var w_top_left: Vector2 = _screen_to_world(Vector2(-120.0, -120.0))
		var w_bot_right: Vector2 = _screen_to_world(size + Vector2(120.0, 120.0))
		var world_view_bounds: Rect2 = Rect2(
			Vector2(minf(w_top_left.x, w_bot_right.x), minf(w_top_left.y, w_bot_right.y)),
			Vector2(absf(w_bot_right.x - w_top_left.x), absf(w_bot_right.y - w_top_left.y))
		)

		# 1. Base background (grayed-out exterior tone)
		draw_rect(view_rect, Color("1a2026"), true)

		# 2. Active Ramos Mejía interior polygon in warm dark urban map tone
		if ramos_boundary.size() >= 3:
			var screen_boundary: PackedVector2Array = PackedVector2Array()
			for p: Vector2 in ramos_boundary:
				screen_boundary.append(_world_to_screen(p))
			draw_colored_polygon(screen_boundary, Color("122636"))

		# 3. Extended streets & railways outside Ramos Mejía (muted gray)
		for s: Dictionary in extended_streets:
			if s.has("bbox") and not world_view_bounds.intersects(s["bbox"]):
				continue
			var pts: PackedVector2Array = PackedVector2Array()
			for p: Vector2 in s["points"]:
				pts.append(_world_to_screen(p))
			var w: float = clampf((2.4 if bool(s["major"]) else 1.2) * sqrt(zoom * 2.5), 1.0, 5.0)
			draw_polyline(pts, Color("313a42") if bool(s["major"]) else Color("252c33"), w)

		for r: PackedVector2Array in extended_railways:
			var pts: PackedVector2Array = PackedVector2Array()
			for p: Vector2 in r:
				pts.append(_world_to_screen(p))
			draw_polyline(pts, Color("3b444c"), 2.0)

		# 4. Ramos Mejía streets, avenues, railways & bridges
		var minor_col: Color = Color("3c6278")
		var major_col: Color = Color("6aa1bc")
		for s: Dictionary in inside_streets:
			if s.has("bbox") and not world_view_bounds.intersects(s["bbox"]):
				continue
			if bool(s["major"]):
				continue
			var pts: PackedVector2Array = PackedVector2Array()
			for p: Vector2 in s["points"]:
				pts.append(_world_to_screen(p))
			draw_polyline(pts, minor_col, clampf(1.8 * sqrt(zoom * 2.4), 1.2, 6.0))

		for s: Dictionary in inside_streets:
			if s.has("bbox") and not world_view_bounds.intersects(s["bbox"]):
				continue
			if not bool(s["major"]):
				continue
			var pts: PackedVector2Array = PackedVector2Array()
			for p: Vector2 in s["points"]:
				pts.append(_world_to_screen(p))
			draw_polyline(pts, major_col, clampf(3.2 * sqrt(zoom * 2.4), 2.0, 9.5))

		for r: PackedVector2Array in railways:
			var pts: PackedVector2Array = PackedVector2Array()
			for p: Vector2 in r:
				pts.append(_world_to_screen(p))
			draw_polyline(pts, Color("d2a458"), clampf(2.4 * sqrt(zoom * 2.4), 1.6, 5.5))

		# 5. Gray-out overlay mask outside the official Ramos Mejía polygon + boundary stroke
		for piece: PackedVector2Array in outside_mask_polygons:
			var screen_piece: PackedVector2Array = PackedVector2Array()
			for p: Vector2 in piece:
				screen_piece.append(_world_to_screen(p))
			draw_colored_polygon(screen_piece, Color(0.10, 0.12, 0.14, 0.58))

		if ramos_boundary.size() >= 3:
			var border_pts: PackedVector2Array = PackedVector2Array()
			for p: Vector2 in ramos_boundary:
				border_pts.append(_world_to_screen(p))
			border_pts.append(border_pts[0])
			draw_polyline(border_pts, Color(0.45, 0.78, 0.82, 0.65), 2.2)

		# 5.1 Highlighted Bridges across the railway
		for b_info: Dictionary in bridges:
			var b_pts: PackedVector2Array = b_info["points"]
			var pts: PackedVector2Array = PackedVector2Array()
			for p: Vector2 in b_pts:
				pts.append(_world_to_screen(p))
			draw_polyline(pts, Color("8ce0e2"), clampf(4.0 * sqrt(zoom * 2.4), 2.5, 9.0))
			if zoom >= 0.26:
				var mid_screen: Vector2 = pts[int(pts.size() / 2)]
				var b_name: String = str(b_info["name"]).split("(")[0].strip_edges()
				draw_string(ThemeDB.fallback_font, mid_screen + Vector2(-50.0, -8.0), b_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color("e0f4f7"))

		# 6. All street names (and NO other markers/POIs)
		var font: Font = ThemeDB.fallback_font
		var drawn_boxes: Array[Rect2] = []
		for lbl: Dictionary in street_labels:
			var l_pos: Vector2 = lbl["pos"] as Vector2
			if not world_view_bounds.has_point(l_pos):
				continue
			var is_outside: bool = bool(lbl["outside"])
			var is_major: bool = bool(lbl["major"])
			var s_pos: Vector2 = _world_to_screen(l_pos)
			if not view_rect.grow(80.0).has_point(s_pos):
				continue
			var fsize: int = 12 if is_major else 10
			if zoom > 0.75:
				fsize += 2
			var text: String = str(lbl["name"])
			var approx_w: float = float(text.length()) * float(fsize) * 0.52
			var box: Rect2 = Rect2(s_pos - Vector2(approx_w * 0.5, 9.0), Vector2(approx_w, 18.0))
			var overlaps: bool = false
			if zoom < 0.85:
				for prev_b: Rect2 in drawn_boxes:
					if prev_b.intersects(box):
						overlaps = true
						break
			if overlaps and not is_major:
				continue
			drawn_boxes.append(box)

			var angle: float = float(lbl["angle"])
			var col: Color = Color("7b8792") if is_outside else (Color("fff5df") if is_major else Color("cbe4ef"))
			draw_set_transform(s_pos, angle, Vector2.ONE)
			draw_string_outline(font, Vector2(-approx_w * 0.5, 4.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, 3, Color(0.05, 0.09, 0.13, 0.92))
			draw_string(font, Vector2(-approx_w * 0.5, 4.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# 7. ONLY the player's location marker ("solo mi ubicación y los nombres de todas las calles")
		var p_screen: Vector2 = _world_to_screen(player_pos)
		draw_circle(p_screen, 13.0, Color(1.0, 0.60, 0.33, 0.28))
		var heading: Vector2 = player_dir.normalized()
		var side: Vector2 = Vector2(-heading.y, heading.x)
		var arrow: PackedVector2Array = PackedVector2Array([
			p_screen + heading * 12.0,
			p_screen - heading * 8.0 + side * 7.0,
			p_screen - heading * 4.0,
			p_screen - heading * 8.0 - side * 7.0,
		])
		draw_colored_polygon(arrow, Color("ff9854"))
		draw_polyline(PackedVector2Array([arrow[0], arrow[1], arrow[2], arrow[3], arrow[0]]), Color("101d29"), 2.0)
		draw_circle(p_screen, 3.2, Color("f4eee2"))

		# 8. North Compass Badge in top-right corner
		var comp_center: Vector2 = Vector2(size.x - 56.0, 56.0)
		draw_circle(comp_center, 28.0, Color(0.06, 0.11, 0.16, 0.92))
		draw_arc(comp_center, 28.0, 0.0, TAU, 32, Color("68d1d2"), 2.0)
		var n_tri: PackedVector2Array = PackedVector2Array([
			comp_center + Vector2(0.0, -20.0),
			comp_center + Vector2(6.0, 2.0),
			comp_center + Vector2(-6.0, 2.0),
		])
		draw_colored_polygon(n_tri, Color("ff9854"))
		draw_string(font, comp_center + Vector2(-5.0, 19.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f4eee2"))

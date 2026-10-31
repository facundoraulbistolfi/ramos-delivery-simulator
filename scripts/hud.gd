class_name MotoHUD
extends CanvasLayer
## Lightweight, resolution-independent interface for the free-ride prototype.

signal resume_requested
signal restart_requested

const INK: Color = Color("101d29")
const PAPER: Color = Color("f4eee2")
const MUTED: Color = Color("a7b6bc")
const ORANGE: Color = Color("ff9854")
const CYAN: Color = Color("68d1d2")

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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	var screen: Control = Control.new()
	screen.name = "Interface"
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)
	_build_brand(screen)
	_build_mission_panel(screen)
	_build_timing(screen)
	_build_controls(screen)
	_build_speedometer(screen)
	_build_toast(screen)
	_build_pause(screen)
	var credit: LinkButton = LinkButton.new()
	credit.text = "© OpenStreetMap contributors · ODbL"
	credit.uri = "https://www.openstreetmap.org/copyright"
	credit.position = Vector2(28.0, 126.0)
	credit.add_theme_font_size_override("font_size", 12)
	credit.add_theme_color_override("font_color", PAPER)
	screen.add_child(credit)
	update_route(0.0, 1.0, 0.0, 1647.63, 0.0, "Larrea")
	show_message("SALÍ A RODAR", 3.5)


func update_route(speed_kmh: float, boost_ratio: float, station: float, length_m: float, elapsed: float, crossing: String) -> void:
	_speed_label.text = "%03d" % roundi(absf(speed_kmh))
	_speed_bar.value = clampf(absf(speed_kmh) / 160.0, 0.0, 1.0)
	_boost_bar.value = boost_ratio
	_lap_label.text = "%04d / %04d METROS" % [roundi(station), roundi(length_m)]
	_time_label.text = _format_time(elapsed)
	_best_label.text = "CALLE: " + crossing
	_route_bar.value = station / length_m


func update_mission(state_data: Dictionary) -> void:
	if not is_instance_valid(_mission_target_label):
		return
	var st: int = int(state_data.get("state", 0))
	var completed: int = int(state_data.get("completed", 0))
	_mission_header_label.text = "REPARTO A OJO EN RAMOS · ENTREGAS: %d" % completed
	if st == 1:
		_mission_step_label.text = "[PASO 1/2] RETIRAR PEDIDO EN LOCAL:"
		_mission_step_label.add_theme_color_override("font_color", ORANGE)
		_mission_target_label.text = str(state_data.get("locale_name", "")).to_upper()
		_mission_ref_label.text = "%s (%s)" % [str(state_data.get("locale_address", "")), str(state_data.get("locale_between", ""))]
		_mission_item_label.text = "Pedido: %s  [M: Cambiar]" % str(state_data.get("order_item", ""))
	elif st == 2:
		_mission_step_label.text = "[PASO 2/2] LLEVAR A DIRECCIÓN:"
		_mission_step_label.add_theme_color_override("font_color", Color("28e070"))
		_mission_target_label.text = str(state_data.get("dest_address", "")).to_upper()
		_mission_ref_label.text = "%s · Ramos Mejía" % str(state_data.get("dest_between", ""))
		_mission_item_label.text = "Llevando: %s (%s)" % [str(state_data.get("order_item", "")), str(state_data.get("locale_name", ""))]


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


func _build_brand(screen: Control) -> void:
	var panel: PanelContainer = _panel(screen, Rect2(28.0, 28.0, 350.0, 90.0))
	var rows: VBoxContainer = _rows(panel, 1)
	var title: Label = _label(rows, "RAMOS MEJÍA", 28, PAPER)
	title.add_theme_constant_override("outline_size", 0)
	_label(rows, "LOCALIDAD COMPLETA · REPARTO & LIBRE", 12, ORANGE)


func _build_mission_panel(screen: Control) -> void:
	var panel: PanelContainer = _panel(screen, Rect2(28.0, 150.0, 440.0, 152.0))
	var rows: VBoxContainer = _rows(panel, 4)
	_mission_header_label = _label(rows, "REPARTO A OJO EN RAMOS · ENTREGAS: 0", 11, CYAN)
	_mission_step_label = _label(rows, "[PASO 1/2] RETIRAR PEDIDO EN LOCAL:", 12, ORANGE)
	_mission_target_label = _label(rows, "CARGANDO PEDIDO...", 20, PAPER)
	_mission_ref_label = _label(rows, "Buscando dirección en Ramos Mejía", 13, CYAN)
	_mission_item_label = _label(rows, "Guiate por los carteles de las calles (M: Nuevo pedido)", 11, MUTED)


func _build_timing(screen: Control) -> void:
	var panel: PanelContainer = _panel(screen, Rect2(-316.0, 28.0, 288.0, 150.0), Vector2.RIGHT)
	var rows: VBoxContainer = _rows(panel, 3)
	_lap_label = _label(rows, "0000 / 1648 METROS", 12, CYAN)
	_time_label = _label(rows, "00:00.00", 34, PAPER)
	_best_label = _label(rows, "Larrea", 12, MUTED)
	_route_bar = _bar(rows, CYAN, 4.0)


func _build_controls(screen: Control) -> void:
	var panel: PanelContainer = _panel(screen, Rect2(28.0, -174.0, 566.0, 146.0), Vector2.DOWN)
	var rows: VBoxContainer = _rows(panel, 7)
	_label(rows, "RECORRIDO LIBRE · ESCALA 1:1", 12, ORANGE)
	_label(rows, "W / ↑  Acelerar     S / ↓  Frenar     A / D / ← / →  Girar", 13, PAPER)
	_label(rows, "SHIFT  Turbo     ESPACIO  Derrape     R  Volver a Larrea", 13, PAPER)
	_label(rows, "C  Cámara     T  Ir a La Tanga     M  Nuevo Pedido     ESC  Pausa", 12, MUTED)
	_label(rows, "VISITAR:  1  San Juan de Dios     2  Coto     3  La Perla", 12, CYAN)


func _build_speedometer(screen: Control) -> void:
	var panel: PanelContainer = _panel(screen, Rect2(-330.0, -208.0, 302.0, 180.0), Vector2.ONE)
	var rows: VBoxContainer = _rows(panel, 3)
	_label(rows, "VELOCIDAD", 11, MUTED)
	var speed_row: HBoxContainer = HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 12)
	rows.add_child(speed_row)
	_speed_label = _label(speed_row, "000", 62, PAPER)
	var unit_label: Label = _label(speed_row, "KM/H", 13, MUTED)
	unit_label.size_flags_vertical = Control.SIZE_SHRINK_END
	_speed_bar = _bar(rows, ORANGE, 5.0)
	var boost_row: HBoxContainer = HBoxContainer.new()
	boost_row.add_theme_constant_override("separation", 12)
	rows.add_child(boost_row)
	_label(boost_row, "TURBO", 11, CYAN)
	_boost_bar = _bar(boost_row, CYAN, 5.0)
	_boost_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boost_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _build_toast(screen: Control) -> void:
	_toast_panel = _panel(screen, Rect2(-240.0, -35.0, 480.0, 70.0), Vector2(0.5, 0.30))
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
	var panel: PanelContainer = _panel(_pause_overlay, Rect2(-210.0, -170.0, 420.0, 340.0), Vector2(0.5, 0.5))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var rows: VBoxContainer = _rows(panel, 18)
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	var title: Label = _label(rows, "EN PAUSA", 36, PAPER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle: Label = _label(rows, "Rivadavia · Larrea a Necochea", 15, MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_resume_button = _button(rows, "SEGUIR RODANDO")
	_resume_button.pressed.connect(func() -> void: resume_requested.emit())
	var restart_button: Button = _button(rows, "REINICIAR SESIÓN")
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	var hint: Label = _label(rows, "ESC  para continuar", 12, MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_overlay.hide()


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
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 13.0
	style.content_margin_bottom = 13.0
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

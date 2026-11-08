extends Node3D
## Free ride around the neighborhood. M toggles street map; TAB opens teleport selector; N requests a new delivery order.
const MissionSystem = preload("res://scripts/mission_system.gd")
const TrafficManager = preload("res://scripts/traffic_manager.gd")

enum GameMode {
	NONE = 0,
	DELIVERY = 1,
	FREE_ROAM = 2,
}

var current_game_mode: int = GameMode.DELIVERY
var is_in_main_menu: bool = true
var elapsed: float = 0.0
var _started: bool = false
var _paused: bool = false
var _end_message_shown: bool = false
var mission_system: Node3D
var traffic_manager: Node3D
@onready var track: MotoTrack = $Track
@onready var bike: MotoBike = $Moto
@onready var hud: MotoHUD = $HUD
@onready var camera: MotoChaseCamera = $ChaseCamera

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_inputs()
	hud.setup_map_data(track)
	hud.overlay_state_changed.connect(_on_hud_overlay_state_changed)
	hud.teleport_requested.connect(_on_teleport_requested)
	_reset_session()
	mission_system = MissionSystem.new()
	mission_system.name = "MissionSystem"
	add_child(mission_system)
	mission_system.mission_updated.connect(hud.update_mission)
	mission_system.mission_notification.connect(hud.show_message)
	mission_system.start_location_dialog_requested.connect(hud.show_start_location_dialog)
	mission_system.order_selection_dialog_requested.connect(hud.show_order_selection_dialog)
	mission_system.shift_completed_summary.connect(hud.show_shift_summary)
	hud.start_location_chosen.connect(_on_start_location_chosen)
	hud.order_offer_chosen.connect(mission_system.select_order_offer)
	hud.shift_restart_requested.connect(_restart_night_shift)
	mission_system.setup(track, bike)
	traffic_manager = TrafficManager.new()
	traffic_manager.name = "TrafficManager"
	add_child(traffic_manager)
	traffic_manager.setup(track, bike)
	hud.resume_requested.connect(func() -> void: _set_paused(false))
	hud.restart_requested.connect(_restart_from_pause)
	hud.game_mode_chosen.connect(_on_game_mode_chosen)
	hud.switch_mode_requested.connect(_on_switch_mode_requested)
	hud.options_saved.connect(_apply_settings)
	hud.return_to_main_menu_requested.connect(_return_to_main_menu)
	hud.quit_game_requested.connect(func() -> void: get_tree().quit())
	bike.vehicle_crashed.connect(_on_bike_vehicle_crashed)
	bike.stunt_live_updated.connect(hud.update_stunt_live)
	bike.stunt_landed.connect(_on_bike_stunt_landed)
	bike.stunt_wiped_out.connect(_on_bike_stunt_wiped_out)

	var initial_settings: Dictionary = hud.load_settings()
	_apply_settings(initial_settings)

	var is_headless: bool = DisplayServer.get_name() == "headless"
	if is_headless:
		is_in_main_menu = false
		camera.cinematic_mode = false
		current_game_mode = GameMode.DELIVERY
		hud.set_delivery_mode_active(true)
		hud.set_gameplay_panels_visible(true)
	else:
		_return_to_main_menu()

func _physics_process(delta: float) -> void:
	if _paused: return
	var station: float = track.sample_route(bike.global_position).x
	bike.off_road = track.get_road_distance(bike.global_position)>0.25
	if absf(bike.speed)>0.5: _started=true
	if _started: elapsed+=delta
	if station>track.get_track_length()-18.0 and not _end_message_shown:
		_end_message_shown=true
		hud.show_message("NECOCHEA\nPodés seguir explorando el barrio",4.0)
	if bike.global_position.y < -10.0: _reset_session()
	hud.update_player_transform(bike.global_position, -bike.global_transform.basis.z)
	hud.update_route(bike.get_speed_kmh(),bike.boost,station,track.get_track_length(),elapsed,track.get_crossing_name(bike.global_position))

func _unhandled_input(event: InputEvent) -> void:
	if is_in_main_menu:
		return
	if event.is_action_pressed("pause"):
		if hud.is_map_open():
			hud.set_map_open(false)
		elif hud.is_teleport_open():
			hud.set_teleport_open(false)
		else:
			_set_paused(not _paused)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_map") and not _paused:
		hud.toggle_map()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("teleport_menu") and not _paused:
		if current_game_mode == GameMode.DELIVERY:
			hud.show_message("MODO DELIVERY ACTIVO\nTeletransporte deshabilitado en este modo competitivo.", 2.5)
		else:
			hud.toggle_teleport_menu()
		get_viewport().set_input_as_handled()
	elif hud.is_blocking_gameplay():
		return
	elif event.is_action_pressed("reset") and not _paused:
		if current_game_mode == GameMode.DELIVERY:
			_restart_night_shift()
		else:
			_reset_session()
	elif event.is_action_pressed("camera") and not _paused:
		camera.close_view=not camera.close_view
	elif event.is_action_pressed("landmark") and not _paused:
		if current_game_mode == GameMode.DELIVERY:
			hud.show_message("MODO DELIVERY ACTIVO\nAtajos deshabilitados durante el turno de reparto.", 2.5)
		else:
			bike.respawn(track.get_tanga_spawn_transform())
			camera.snap_to_target()
			hud.show_message("LA TANGA DE RAMOS\nRivadavia / Avenida de Mayo",3.0)
	elif event.is_action_pressed("visit_hospital") and not _paused:
		if current_game_mode != GameMode.DELIVERY:
			_visit_building("san_juan")
	elif event.is_action_pressed("visit_coto") and not _paused:
		if current_game_mode != GameMode.DELIVERY:
			_visit_building("coto")
	elif event.is_action_pressed("visit_perla") and not _paused:
		if current_game_mode != GameMode.DELIVERY:
			_visit_building("la_perla")
	elif event.is_action_pressed("new_mission") and not _paused and mission_system != null:
		if current_game_mode == GameMode.DELIVERY:
			mission_system.start_new_mission(true)
		else:
			hud.show_message("MODO LIBRE ACTIVO\nCambiá a Modo Delivery desde la pausa [ESC] para aceptar pedidos.", 3.5)

func _on_game_mode_chosen(mode: int) -> void:
	current_game_mode = mode
	is_in_main_menu = false
	camera.cinematic_mode = false
	camera.snap_to_target()
	hud.set_gameplay_panels_visible(true)
	bike.controls_enabled = true
	if mode == GameMode.DELIVERY:
		hud.set_delivery_mode_active(true)
		if mission_system != null:
			mission_system.start_delivery_mode()
	else:
		hud.set_delivery_mode_active(false)
		if mission_system != null:
			mission_system.set_free_roam_mode()
		hud.show_message("MODO LIBRE / DEBUG ACTIVADO\nExplorá Ramos Mejía sin límites · [TAB] Teletransporte · [M] Mapa", 4.5)

func _return_to_main_menu() -> void:
	_set_paused(false)
	is_in_main_menu = true
	camera.cinematic_mode = true
	bike.controls_enabled = false
	hud.close_all_modals()
	hud.set_gameplay_panels_visible(false)
	hud.show_mode_selection_dialog()

func _apply_settings(settings: Dictionary) -> void:
	# 1. Fullscreen
	var fullscreen: bool = bool(settings.get("fullscreen", false))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

	# 2. Dynamic sun shadows
	var shadows: bool = bool(settings.get("shadows", true))
	var sun: DirectionalLight3D = get_node_or_null("Sun") as DirectionalLight3D
	if sun != null:
		sun.shadow_enabled = shadows

	# 3. Traffic density
	var density_level: int = int(settings.get("traffic_density", 1))
	if traffic_manager != null and traffic_manager.has_method("set_traffic_density"):
		traffic_manager.set_traffic_density(density_level)

	# 4. Master audio volume
	var master_vol: float = float(settings.get("master_volume", 1.0))
	if AudioServer.get_bus_count() > 0:
		AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.001, master_vol)))

func _on_switch_mode_requested() -> void:
	_set_paused(false)
	hud.show_mode_selection_dialog()

func _on_bike_vehicle_crashed(impact_kmh: float, _collider: Object) -> void:
	if is_instance_valid(camera):
		camera.add_trauma(clampf(impact_kmh / 70.0, 0.25, 0.75))
	if current_game_mode == GameMode.DELIVERY and mission_system != null:
		mission_system.apply_crash_penalty(impact_kmh)

func _on_bike_stunt_landed(stunt_name: String, detail_text: String, aura_gained: int, combo_count: int) -> void:
	if mission_system != null:
		mission_system.add_aura(aura_gained, stunt_name)
	if is_instance_valid(camera):
		camera.add_trauma(0.18)
	if is_instance_valid(hud):
		hud.show_stunt_completed(stunt_name, detail_text, aura_gained, combo_count)

func _on_bike_stunt_wiped_out(reason: String, aura_penalty: int) -> void:
	var actual_lost: int = 0
	if mission_system != null:
		actual_lost = mission_system.lose_aura(aura_penalty, reason)
	if is_instance_valid(camera):
		camera.add_trauma(0.85)
	if is_instance_valid(hud):
		hud.show_stunt_wipeout(reason, actual_lost)

func _on_hud_overlay_state_changed(is_blocking_drive: bool) -> void:
	if is_in_main_menu:
		if is_instance_valid(bike):
			bike.controls_enabled = false
		return
	if is_instance_valid(bike):
		bike.controls_enabled = not is_blocking_drive

func _on_teleport_requested(target_transform: Transform3D, title: String, subtitle: String) -> void:
	bike.respawn(target_transform)
	camera.snap_to_target()
	hud.update_player_transform(bike.global_position, -bike.global_transform.basis.z)
	hud.show_message("TELETRANSPORTE: %s\n%s" % [title, subtitle], 3.5)

func _on_start_location_chosen(location_id: int) -> void:
	if mission_system != null:
		mission_system.choose_start_location(location_id)
	if camera != null:
		camera.snap_to_target()
	if hud != null and bike != null:
		hud.update_player_transform(bike.global_position, -bike.global_transform.basis.z)

func _restart_night_shift() -> void:
	_reset_session()
	if mission_system != null:
		mission_system.restart_night_shift()

func _visit_building(key: String) -> void:
	bike.respawn(track.get_building_spawn_transform(key))
	camera.snap_to_target()
	for site: Dictionary in track.data["recognizable_buildings"]:
		if str(site["key"])==key:
			hud.show_message(str(site["name"])+"\n"+str(site["address"]),3.5)

func _reset_session() -> void:
	bike.respawn(track.get_spawn_transform())
	camera.snap_to_target()
	elapsed=0.0
	_started=false
	_end_message_shown=false
	hud.update_player_transform(bike.global_position, -bike.global_transform.basis.z)
	hud.show_message("RAMOS MEJÍA\nRivadavia · Larrea → Necochea",4.0)

func _restart_from_pause() -> void:
	_set_paused(false)
	if current_game_mode == GameMode.DELIVERY:
		_restart_night_shift()
	else:
		_reset_session()

func _set_paused(value: bool) -> void:
	_paused=value
	get_tree().paused=value
	hud.set_paused(value)

func _setup_inputs() -> void:
	_bind("accelerate",[KEY_W,KEY_UP])
	_bind("brake",[KEY_S,KEY_DOWN])
	_bind("steer_left",[KEY_A,KEY_LEFT])
	_bind("steer_right",[KEY_D,KEY_RIGHT])
	_bind("boost",[KEY_SHIFT])
	_bind("drift",[KEY_SPACE])
	_bind("stunt_wheelie",[KEY_Q,KEY_CTRL,KEY_Z])
	_bind("stunt_stoppie",[KEY_E,KEY_X])
	_bind("reset",[KEY_R])
	_bind("camera",[KEY_C])
	_bind("pause",[KEY_ESCAPE])
	_bind("landmark",[KEY_T])
	_bind("visit_hospital",[KEY_1])
	_bind("visit_coto",[KEY_2])
	_bind("visit_perla",[KEY_3])
	_bind("toggle_map",[KEY_M])
	_bind("teleport_menu",[KEY_TAB])
	_bind("new_mission",[KEY_N])

func _bind(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action): InputMap.add_action(action)
	for key: int in keys:
		var input_event: InputEventKey = InputEventKey.new()
		input_event.physical_keycode=key
		if not InputMap.action_has_event(action,input_event): InputMap.action_add_event(action,input_event)


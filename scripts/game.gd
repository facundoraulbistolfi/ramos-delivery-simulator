extends Node3D
## Free ride around the neighborhood. R returns to Larrea; 1/2/3 visit landmarks.
const MissionSystem = preload("res://scripts/mission_system.gd")
var elapsed: float = 0.0
var _started: bool = false
var _paused: bool = false
var _end_message_shown: bool = false
var mission_system: Node3D
@onready var track: MotoTrack = $Track
@onready var bike: MotoBike = $Moto
@onready var hud: MotoHUD = $HUD
@onready var camera: MotoChaseCamera = $ChaseCamera

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_inputs()
	_reset_session()
	mission_system = MissionSystem.new()
	mission_system.name = "MissionSystem"
	add_child(mission_system)
	mission_system.mission_updated.connect(hud.update_mission)
	mission_system.mission_notification.connect(hud.show_message)
	mission_system.setup(track, bike)
	hud.resume_requested.connect(func() -> void: _set_paused(false))
	hud.restart_requested.connect(_restart_from_pause)

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
	hud.update_route(bike.get_speed_kmh(),bike.boost,station,track.get_track_length(),elapsed,track.get_crossing_name(bike.global_position))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_set_paused(not _paused)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("reset") and not _paused:
		_reset_session()
	elif event.is_action_pressed("camera") and not _paused:
		camera.close_view=not camera.close_view
	elif event.is_action_pressed("landmark") and not _paused:
		bike.respawn(track.get_tanga_spawn_transform())
		camera.snap_to_target()
		hud.show_message("LA TANGA DE RAMOS\nRivadavia / Avenida de Mayo",3.0)
	elif event.is_action_pressed("visit_hospital") and not _paused:
		_visit_building("san_juan")
	elif event.is_action_pressed("visit_coto") and not _paused:
		_visit_building("coto")
	elif event.is_action_pressed("visit_perla") and not _paused:
		_visit_building("la_perla")
	elif event.is_action_pressed("new_mission") and not _paused and mission_system != null:
		mission_system.start_new_mission(true)

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
	hud.show_message("RAMOS MEJÍA\nRivadavia · Larrea → Necochea",4.0)

func _restart_from_pause() -> void:
	_set_paused(false)
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
	_bind("reset",[KEY_R])
	_bind("camera",[KEY_C])
	_bind("pause",[KEY_ESCAPE])
	_bind("landmark",[KEY_T])
	_bind("visit_hospital",[KEY_1])
	_bind("visit_coto",[KEY_2])
	_bind("visit_perla",[KEY_3])
	_bind("new_mission",[KEY_M])

func _bind(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action): InputMap.add_action(action)
	for key: int in keys:
		var input_event: InputEventKey = InputEventKey.new()
		input_event.physical_keycode=key
		if not InputMap.action_has_event(action,input_event): InputMap.action_add_event(action,input_event)

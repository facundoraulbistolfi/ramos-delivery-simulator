class_name MotoChaseCamera
extends Camera3D

@export var target_path: NodePath
var close_view: bool = false
var _snap_next_frame: bool = true
var cinematic_mode: bool = false
var _cinematic_angle: float = 0.0
var _trauma: float = 0.0
var _shake_Clock: float = 0.0
const CINEMATIC_CENTER: Vector3 = Vector3(-1380.0, 1.5, 120.0)
const CINEMATIC_RADIUS: float = 45.0
const CINEMATIC_HEIGHT: float = 14.5
const CINEMATIC_ROTATION_SPEED: float = 0.08
@onready var target: MotoBike = get_node(target_path) as MotoBike


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	if cinematic_mode:
		_cinematic_angle += CINEMATIC_ROTATION_SPEED * delta
		var offset: Vector3 = Vector3(cos(_cinematic_angle) * CINEMATIC_RADIUS, CINEMATIC_HEIGHT, sin(_cinematic_angle) * CINEMATIC_RADIUS)
		global_position = CINEMATIC_CENTER + offset
		look_at(CINEMATIC_CENTER + Vector3.UP * 1.5, Vector3.UP)
		fov = 68.0
		return

	if not is_instance_valid(target):
		return

	var stunt_zoom_out: float = 0.0
	var stunt_fov_add: float = 0.0
	if target.is_airborne_stunt or not target.is_on_floor():
		stunt_zoom_out = 0.85
		stunt_fov_add = 4.5
	elif target.is_doing_wheelie or target.is_doing_stoppie:
		stunt_zoom_out = 0.45
		stunt_fov_add = 2.5

	var follow_distance: float = (4.6 if close_view else 7.4) + stunt_zoom_out
	var height: float = 2.4 if close_view else 3.7
	var desired_position: Vector3 = target.global_position + target.global_basis * Vector3(0.0, height, follow_distance)
	var aim: Vector3 = target.global_position + Vector3.UP * 1.15 - target.global_basis.z * 3.5
	# Keep the camera in front of nearby scenery and barriers.
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(aim, desired_position)
	ray.exclude = [target.get_rid()]
	var hit: Dictionary = target.get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		desired_position = (hit["position"] as Vector3) + (hit["normal"] as Vector3) * 0.4
	if _snap_next_frame:
		global_position = desired_position
		_snap_next_frame = false
	else:
		global_position = global_position.lerp(desired_position, 1.0 - exp(-5.5 * delta))

	if _trauma > 0.0:
		_shake_Clock += delta * 34.0
		var shake: float = _trauma * _trauma * 0.28
		var jitter: Vector3 = Vector3(sin(_shake_Clock * 1.7), cos(_shake_Clock * 2.3), 0.0) * shake
		aim += target.global_basis * jitter
		_trauma = maxf(0.0, _trauma - delta * 2.1)

	if global_position.distance_squared_to(aim) > 0.01:
		look_at(aim, Vector3.UP)
	fov = lerpf(fov, 72.0 + minf(target.get_speed_kmh() / 12.0, 13.0) + stunt_fov_add, 1.0 - exp(-3.0 * delta))


func snap_to_target() -> void:
	_snap_next_frame = true
	_trauma = 0.0

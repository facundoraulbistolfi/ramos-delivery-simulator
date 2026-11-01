class_name MotoChaseCamera
extends Camera3D

@export var target_path: NodePath
var close_view: bool = false
var _snap_next_frame: bool = true
@onready var target: MotoBike = get_node(target_path) as MotoBike


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var follow_distance: float = 4.6 if close_view else 7.4
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
	if global_position.distance_squared_to(aim) > 0.01:
		look_at(aim, Vector3.UP)
	fov = lerpf(fov, 72.0 + minf(target.get_speed_kmh() / 12.0, 13.0), 1.0 - exp(-3.0 * delta))


func snap_to_target() -> void:
	_snap_next_frame = true

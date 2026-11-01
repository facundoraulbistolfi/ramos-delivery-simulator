class_name MotoBike
extends CharacterBody3D
## Arcade controller. Forward is local -Z; the visual leans independently.

signal vehicle_crashed(impact_kmh: float, vehicle_collider: Object)

@export_group("Conducción")
@export var max_speed: float = 34.0
@export var acceleration: float = 13.0
@export var brake_force: float = 26.0
@export var steering_speed: float = 1.35
@export var gravity: float = 24.0

var speed: float = 0.0
var boost: float = 1.0
var off_road: bool = false
var controls_enabled: bool = true
var boosting: bool = false
var steering: float = 0.0
var _wheel_rotation: float = 0.0
var _vehicle_crash_cooldown: float = 0.0

@onready var visual: Node3D = $Visual
@onready var front_fork: Node3D = $Visual/FrontFork
@onready var front_wheel: Node3D = $Visual/FrontFork/FrontWheel
@onready var rear_wheel: Node3D = $Visual/RearWheel


func _ready() -> void:
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(52.0)


func _physics_process(delta: float) -> void:
	if _vehicle_crash_cooldown > 0.0:
		_vehicle_crash_cooldown = maxf(0.0, _vehicle_crash_cooldown - delta)
	var pre_slide_speed_kmh: float = get_speed_kmh()

	var throttle: float = Input.get_axis("brake", "accelerate") if controls_enabled else 0.0
	var steer_input: float = Input.get_axis("steer_right", "steer_left") if controls_enabled else 0.0
	var drifting: bool = controls_enabled and Input.is_action_pressed("drift") and absf(speed) > 7.0
	boosting = controls_enabled and Input.is_action_pressed("boost") and throttle > 0.0 and boost > 0.05 and not off_road
	steering = move_toward(steering, steer_input, delta * 4.5)
	if boosting:
		boost = maxf(0.0, boost - delta * 0.24)
	else:
		boost = minf(1.0, boost + delta * 0.11)
	var speed_limit: float = max_speed * (1.33 if boosting else 1.0)
	if off_road:
		speed_limit *= 0.46
	if throttle > 0.0:
		speed = move_toward(speed, speed_limit, acceleration * (1.6 if boosting else 1.0) * delta)
	elif throttle < 0.0:
		# Holding the brake at rest engages a slow reverse for recovery.
		speed = move_toward(speed, -6.0, (brake_force if speed > 0.0 else acceleration * 0.45) * delta)
	else:
		speed = move_toward(speed, 0.0, (4.5 if not off_road else 9.0) * delta)
	if absf(speed) > speed_limit:
		speed = move_toward(speed, speed_limit * signf(speed), delta * 12.0)
	if drifting:
		speed = move_toward(speed, 0.0, delta * 6.0)
	var turn_factor: float = clampf(absf(speed) / 9.0, 0.0, 1.0)
	var high_speed_reduction: float = lerpf(1.0, 0.58, clampf(absf(speed) / 45.0, 0.0, 1.0))
	rotate_y(steering * steering_speed * turn_factor * high_speed_reduction * signf(speed) * (1.55 if drifting else 1.0) * delta)
	var forward: Vector3 = -global_transform.basis.z
	var desired: Vector3 = forward * speed
	var grip: float = 3.5 if drifting else 13.0
	velocity.x = lerpf(velocity.x, desired.x, minf(1.0, grip * delta))
	velocity.z = lerpf(velocity.z, desired.z, minf(1.0, grip * delta))
	if is_on_floor():
		velocity.y = -0.2
	else:
		velocity.y -= gravity * delta
	move_and_slide()
	# Check vehicle collisions against parked cars and moving traffic
	if _vehicle_crash_cooldown <= 0.0 and pre_slide_speed_kmh >= 10.0:
		var col_count: int = get_slide_collision_count()
		for i: int in range(col_count):
			var col: KinematicCollision3D = get_slide_collision(i)
			var collider: Object = col.get_collider()
			if collider == null:
				continue
			var is_veh: bool = false
			if collider.has_meta("is_vehicle"):
				is_veh = bool(collider.get_meta("is_vehicle"))
			elif collider is CharacterBody3D and collider.get_script() != null and "traffic_vehicle" in collider.get_script().resource_path:
				is_veh = true
			if is_veh:
				_vehicle_crash_cooldown = 1.0
				speed = -speed * 0.25
				velocity.x *= 0.25
				velocity.z *= 0.25
				vehicle_crashed.emit(pre_slide_speed_kmh, collider)
				break

	# Remove stored speed when hitting a wall so the bike cannot keep pushing at full speed.
	if is_on_wall():
		var actual_forward_speed: float = Vector3(velocity.x, 0.0, velocity.z).dot(forward)
		speed = lerpf(speed, actual_forward_speed, 0.55)
	visual.rotation.z = lerp_angle(visual.rotation.z, steering * turn_factor * 0.40 * signf(speed), delta * 7.0)
	visual.rotation.x = lerp_angle(visual.rotation.x, -throttle * 0.035 * turn_factor, delta * 5.0)
	front_fork.rotation.y = steering * 0.28
	_wheel_rotation -= speed / 0.44 * delta
	front_wheel.rotation.x = _wheel_rotation
	rear_wheel.rotation.x = _wheel_rotation


func respawn(spawn_transform: Transform3D) -> void:
	global_transform = spawn_transform
	velocity = Vector3.ZERO
	speed = 0.0
	boost = 1.0
	steering = 0.0
	_vehicle_crash_cooldown = 0.6
	visual.rotation = Vector3.ZERO
	reset_physics_interpolation()


func get_speed_kmh() -> float:
	return Vector2(velocity.x, velocity.z).length() * 3.6

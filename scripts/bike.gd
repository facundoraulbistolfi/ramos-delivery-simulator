class_name MotoBike
extends CharacterBody3D
## Arcade motorcycle controller with GTA Vice City / San Andreas stunt physics.
## Forward is local -Z; Visual pivots on rear axle (wheelie), front axle (stoppie), or CoM (air flips).

signal vehicle_crashed(impact_kmh: float, vehicle_collider: Object)
signal stunt_live_updated(active: bool, stunt_title: String, stats_text: String, pending_aura: int, danger_ratio: float)
signal stunt_landed(stunt_name: String, detail_text: String, aura_gained: int, combo_count: int)
signal stunt_wiped_out(reason: String, aura_lost: int)

@export_group("Conducción")
@export var max_speed: float = 34.0
@export var acceleration: float = 13.0
@export var brake_force: float = 26.0
@export var steering_speed: float = 1.35
@export var gravity: float = 24.0

# Stunt thresholds & tuning
const WHEELIE_MIN_SPEED: float = 3.3
const WHEELIE_COUNT_ANGLE: float = deg_to_rad(14.0)
const WHEELIE_SWEET_ANGLE: float = deg_to_rad(35.0)
const WHEELIE_SPARK_ANGLE: float = deg_to_rad(60.0)
const WHEELIE_MAX_ANGLE: float = deg_to_rad(76.0)
const WHEELIE_MIN_TIME: float = 0.75
const WHEELIE_MIN_DIST: float = 6.5

const STOPPIE_MIN_SPEED: float = 5.2
const STOPPIE_HOLD_SPEED: float = 1.6
const STOPPIE_COUNT_ANGLE: float = deg_to_rad(13.0)
const STOPPIE_DANGER_ANGLE: float = deg_to_rad(45.0)
const STOPPIE_MAX_ANGLE: float = deg_to_rad(58.0)
const STOPPIE_MIN_TIME: float = 0.50
const STOPPIE_MIN_DIST: float = 3.8

const AIR_MIN_STUNT_TIME: float = 0.42
const AIR_MIN_STUNT_DIST: float = 6.0
const AIR_NOSE_CRASH_DEG: float = -50.0
const AIR_TAIL_CRASH_DEG: float = 68.0

const COMBO_WINDOW: float = 3.2
const WIPEOUT_DURATION: float = 1.55

const REAR_TIRE_PIVOT: Vector3 = Vector3(0.0, 0.0, 0.6864)
const FRONT_TIRE_PIVOT: Vector3 = Vector3(0.0, 0.0, -0.6864)
const AIR_COM_PIVOT: Vector3 = Vector3(0.0, 0.58, 0.0)

var speed: float = 0.0
var boost: float = 1.0
var off_road: bool = false
var controls_enabled: bool = true
var boosting: bool = false
var steering: float = 0.0
var _wheel_rotation: float = 0.0
var _front_wheel_rotation: float = 0.0
var _vehicle_crash_cooldown: float = 0.0

# Stunt & Wipeout state
var stunt_pitch: float = 0.0
var is_doing_wheelie: bool = false
var is_doing_stoppie: bool = false
var is_airborne_stunt: bool = false
var is_wiped_out: bool = false
var combo_count: int = 0
var combo_timer: float = 0.0

var _stunt_pitch_vel: float = 0.0
var _visual_roll: float = 0.0
var _active_pivot: Vector3 = Vector3.ZERO
var _visual_scale: float = 0.78

var _wheelie_time: float = 0.0
var _wheelie_dist: float = 0.0
var _wheelie_peak_deg: float = 0.0

var _stoppie_time: float = 0.0
var _stoppie_dist: float = 0.0
var _stoppie_peak_deg: float = 0.0

var _air_time: float = 0.0
var _air_start_xz: Vector2 = Vector2.ZERO
var _air_takeoff_y: float = 0.0
var _air_peak_y: float = 0.0
var _air_total_pitch: float = 0.0
var _air_total_yaw: float = 0.0
var _air_carry_aura: int = 0

var _wipeout_timer: float = 0.0
var _wipeout_side: float = 1.0
var _post_wipeout_grace: float = 0.0
var _live_banner_was_active: bool = false

var _rider_rest_pos: Vector3 = Vector3(0.0, 1.28, 0.26)
var _rider_rest_rot: Vector3 = Vector3(-0.38, 0.0, 0.0)
var _lleg_rest_pos: Vector3 = Vector3(-0.28, 0.88, 0.32)
var _lleg_rest_rot: Vector3 = Vector3(0.52, 0.0, -0.08)
var _rleg_rest_pos: Vector3 = Vector3(0.28, 0.88, 0.32)
var _rleg_rest_rot: Vector3 = Vector3(0.52, 0.0, 0.08)

var _sparks_root: Node3D
var _spark_meshes: Array[MeshInstance3D] = []
var _aura_light: OmniLight3D
var _spark_phase: float = 0.0

@onready var visual: Node3D = $Visual
@onready var front_fork: Node3D = $Visual/FrontFork
@onready var front_wheel: Node3D = $Visual/FrontFork/FrontWheel
@onready var rear_wheel: Node3D = $Visual/RearWheel
@onready var rider: Node3D = get_node_or_null("Visual/Rider") as Node3D
@onready var left_leg: MeshInstance3D = get_node_or_null("Visual/LeftLeg") as MeshInstance3D
@onready var right_leg: MeshInstance3D = get_node_or_null("Visual/RightLeg") as MeshInstance3D


func _ready() -> void:
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(52.0)
	if is_instance_valid(visual):
		_visual_scale = visual.scale.x
	if is_instance_valid(rider):
		_rider_rest_pos = rider.position
		_rider_rest_rot = rider.rotation
	if is_instance_valid(left_leg):
		_lleg_rest_pos = left_leg.position
		_lleg_rest_rot = left_leg.rotation
	if is_instance_valid(right_leg):
		_rleg_rest_pos = right_leg.position
		_rleg_rest_rot = right_leg.rotation
	_build_stunt_fx()


func _build_stunt_fx() -> void:
	if not is_instance_valid(visual):
		return
	_sparks_root = Node3D.new()
	_sparks_root.name = "StuntSparks"
	_sparks_root.position = Vector3(0.0, 0.08, 1.05)
	_sparks_root.visible = false
	visual.add_child(_sparks_root)

	var spark_mat: StandardMaterial3D = StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.albedo_color = Color(1.0, 0.76, 0.18, 1.0)

	for i: int in range(6):
		var sm: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.025, 0.025, 0.28)
		sm.mesh = box
		sm.material_override = spark_mat
		_sparks_root.add_child(sm)
		_spark_meshes.append(sm)

	_aura_light = OmniLight3D.new()
	_aura_light.name = "AuraGlow"
	_aura_light.position = Vector3(0.0, 0.35, 0.0)
	_aura_light.omni_range = 3.4
	_aura_light.light_energy = 0.0
	_aura_light.light_color = Color(1.0, 0.75, 0.18)
	_aura_light.shadow_enabled = false
	add_child(_aura_light)


func set_aura_visual_ratio(ratio: float) -> void:
	if not is_instance_valid(_aura_light):
		return
	var clamped: float = clampf(ratio, 0.0, 1.0)
	if clamped < 0.25:
		_aura_light.light_energy = 0.0
	elif clamped < 0.60:
		_aura_light.light_color = Color("ff9854")
		_aura_light.light_energy = lerpf(0.0, 0.85, (clamped - 0.25) / 0.35)
	elif clamped < 0.85:
		_aura_light.light_color = Color("d855ff")
		_aura_light.light_energy = lerpf(0.85, 1.25, (clamped - 0.60) / 0.25)
	else:
		_aura_light.light_color = Color("ffd700")
		_aura_light.light_energy = 1.45


func _physics_process(delta: float) -> void:
	if _vehicle_crash_cooldown > 0.0:
		_vehicle_crash_cooldown = maxf(0.0, _vehicle_crash_cooldown - delta)
	if _post_wipeout_grace > 0.0:
		_post_wipeout_grace = maxf(0.0, _post_wipeout_grace - delta)

	if is_wiped_out:
		_process_wipeout(delta)
		return

	var pre_slide_speed_kmh: float = get_speed_kmh()
	var was_on_floor: bool = is_on_floor()
	var prev_pos: Vector3 = global_position

	var throttle: float = Input.get_axis("brake", "accelerate") if controls_enabled else 0.0
	var steer_input: float = Input.get_axis("steer_right", "steer_left") if controls_enabled else 0.0
	var drifting: bool = controls_enabled and Input.is_action_pressed("drift") and absf(speed) > 7.0
	var wheelie_in: bool = controls_enabled and InputMap.has_action("stunt_wheelie") and Input.is_action_pressed("stunt_wheelie")
	var stoppie_in: bool = controls_enabled and InputMap.has_action("stunt_stoppie") and Input.is_action_pressed("stunt_stoppie")

	if combo_timer > 0.0 and not _is_in_any_active_stunt():
		combo_timer = maxf(0.0, combo_timer - delta)
		if combo_timer <= 0.0:
			combo_count = 0

	boosting = controls_enabled and Input.is_action_pressed("boost") and throttle > 0.0 and boost > 0.05 and not off_road
	steering = move_toward(steering, steer_input, delta * 4.5)
	if boosting:
		boost = maxf(0.0, boost - delta * 0.24)
	else:
		boost = minf(1.0, boost + delta * 0.11)

	var wheelie_speed_bonus: float = 1.08 if (is_doing_wheelie and stunt_pitch >= WHEELIE_SWEET_ANGLE) else 1.0
	var speed_limit: float = max_speed * (1.33 if boosting else 1.0) * wheelie_speed_bonus
	if off_road:
		speed_limit *= 0.46

	if was_on_floor and stoppie_in and speed > STOPPIE_HOLD_SPEED and not wheelie_in:
		# Front-brake rolling Stoppie deceleration (smooth glide on front wheel like GTA VC/SA)
		var stoppie_decel: float = 6.2 if throttle >= 0.0 else 9.4
		speed = move_toward(speed, 0.0, stoppie_decel * delta)
	elif throttle > 0.0:
		speed = move_toward(speed, speed_limit, acceleration * (1.6 if boosting else 1.0) * delta)
	elif throttle < 0.0:
		# Holding the brake at rest engages a slow reverse for recovery.
		speed = move_toward(speed, -6.0, (brake_force if speed > 0.0 else acceleration * 0.45) * delta)
	else:
		speed = move_toward(speed, 0.0, (4.5 if not off_road else 9.0) * delta)

	if absf(speed) > speed_limit:
		speed = move_toward(speed, speed_limit * signf(speed), delta * 12.0)
	if drifting and was_on_floor:
		speed = move_toward(speed, 0.0, delta * 6.0)

	var turn_factor: float = clampf(absf(speed) / 9.0, 0.0, 1.0)
	var high_speed_reduction: float = lerpf(1.0, 0.58, clampf(absf(speed) / 45.0, 0.0, 1.0))

	if was_on_floor:
		var stunt_steer_mod: float = 1.0
		if is_doing_wheelie:
			stunt_steer_mod = 0.68
		elif is_doing_stoppie:
			stunt_steer_mod = 0.55
		rotate_y(steering * steering_speed * turn_factor * high_speed_reduction * signf(speed) * (1.55 if drifting else 1.0) * stunt_steer_mod * delta)
	elif _air_time > 0.06:
		var air_spin_speed: float = 5.4 if (controls_enabled and Input.is_action_pressed("drift")) else 3.8
		var yaw_step: float = steer_input * air_spin_speed * delta
		rotate_y(yaw_step)
		_air_total_yaw += yaw_step

	var forward: Vector3 = -global_transform.basis.z
	var desired: Vector3 = forward * speed
	if was_on_floor:
		var grip: float = 3.5 if drifting else 13.0
		velocity.x = lerpf(velocity.x, desired.x, minf(1.0, grip * delta))
		velocity.z = lerpf(velocity.z, desired.z, minf(1.0, grip * delta))
	else:
		# Ballistic air momentum with light directional air control
		velocity.x = lerpf(velocity.x, desired.x, minf(1.0, 0.85 * delta))
		velocity.z = lerpf(velocity.z, desired.z, minf(1.0, 0.85 * delta))

	if was_on_floor:
		var fn: Vector3 = get_floor_normal()
		var hvel_len: float = Vector2(velocity.x, velocity.z).length()
		var slope_vy: float = (-velocity.x * fn.x - velocity.z * fn.z) / maxf(0.28, fn.y)
		if hvel_len > 7.5 and slope_vy > 1.75:
			floor_snap_length = 0.0
			velocity.y = slope_vy
		else:
			floor_snap_length = 0.45
			velocity.y = -0.2
	else:
		floor_snap_length = 0.0
		velocity.y -= gravity * delta

	move_and_slide()

	# Classic GTA PCJ-600 curb-pop when hitting a sidewalk curb fast in a Wheelie
	if was_on_floor and is_on_floor() and is_doing_wheelie and stunt_pitch > deg_to_rad(22.0) and pre_slide_speed_kmh > 48.0:
		var step_dy: float = global_position.y - prev_pos.y
		if step_dy > 0.09 and step_dy < 0.30 and get_floor_normal().y > 0.96:
			floor_snap_length = 0.0
			velocity.y = clampf(absf(speed) * 0.24, 4.2, 7.8)

	var horiz_step_dist: float = Vector2(global_position.x - prev_pos.x, global_position.z - prev_pos.z).length()
	_update_stunt_state(delta, was_on_floor, pre_slide_speed_kmh, horiz_step_dist, throttle, wheelie_in, stoppie_in)
	if is_wiped_out:
		return

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
				var crashed_during_stunt: bool = _is_in_any_active_stunt() and pre_slide_speed_kmh >= 16.0
				speed = -speed * 0.25
				velocity.x *= 0.25
				velocity.z *= 0.25
				vehicle_crashed.emit(pre_slide_speed_kmh, collider)
				if (crashed_during_stunt or pre_slide_speed_kmh >= 66.0) and _post_wipeout_grace <= 0.0:
					trigger_wipeout("¡CHOQUE EN PLENA ACROBACIA!")
					return
				break

	# Remove stored speed when hitting a wall; wipe out if slamming a wall mid-stunt.
	if is_on_wall():
		if _is_in_any_active_stunt() and pre_slide_speed_kmh >= 24.0 and _post_wipeout_grace <= 0.0:
			var wall_n: Vector3 = get_wall_normal()
			if absf(wall_n.dot(forward)) > 0.55:
				trigger_wipeout("¡IMPACTO CONTRA MURO EN PLENO TRUCO!")
				return
		var actual_forward_speed: float = Vector3(velocity.x, 0.0, velocity.z).dot(forward)
		speed = lerpf(speed, actual_forward_speed, 0.55)

	_update_visual_pose(delta, throttle, turn_factor)


func _update_stunt_state(
	delta: float,
	was_on_floor: bool,
	pre_slide_speed_kmh: float,
	horiz_step_dist: float,
	throttle: float,
	wheelie_in: bool,
	stoppie_in: bool
) -> void:
	var now_on_floor: bool = is_on_floor()

	# 1. Transition Ground -> Air
	if was_on_floor and not now_on_floor:
		_air_carry_aura = 0
		if _wheelie_time >= WHEELIE_MIN_TIME and _wheelie_dist >= WHEELIE_MIN_DIST:
			_air_carry_aura = _compute_wheelie_aura()
		elif _stoppie_time >= STOPPIE_MIN_TIME and _stoppie_dist >= STOPPIE_MIN_DIST:
			_air_carry_aura = _compute_stoppie_aura()
		_clear_ground_stunt_counters()
		is_airborne_stunt = false
		_air_time = 0.0
		_air_start_xz = Vector2(global_position.x, global_position.z)
		_air_takeoff_y = global_position.y
		_air_peak_y = global_position.y
		_air_total_pitch = 0.0
		_air_total_yaw = 0.0
		_stunt_pitch_vel = clampf(_stunt_pitch_vel, -2.5, 2.5)
		return

	# 2. Airborne flight & flips/spins
	if not now_on_floor:
		_air_time += delta
		_air_peak_y = maxf(_air_peak_y, global_position.y)
		if wheelie_in and not stoppie_in:
			_stunt_pitch_vel = move_toward(_stunt_pitch_vel, 5.5, 24.0 * delta)
		elif stoppie_in and not wheelie_in:
			_stunt_pitch_vel = move_toward(_stunt_pitch_vel, -5.5, 24.0 * delta)
		else:
			_stunt_pitch_vel = move_toward(_stunt_pitch_vel, 0.0, 9.5 * delta)

		var dp: float = _stunt_pitch_vel * delta
		stunt_pitch += dp
		_air_total_pitch += dp

		var air_dist: float = Vector2(global_position.x, global_position.z).distance_to(_air_start_xz)
		var flips: int = _count_flips(_air_total_pitch)
		var spins_180: int = int(floor((absf(rad_to_deg(_air_total_yaw)) + 35.0) / 180.0))
		if _air_time >= 0.25 and (air_dist >= 3.5 or flips > 0 or spins_180 > 0):
			is_airborne_stunt = true
			var wrapped_deg: float = rad_to_deg(wrapf(stunt_pitch, -PI, PI))
			var danger: float = 0.0
			if wrapped_deg < -32.0:
				danger = clampf((-wrapped_deg - 32.0) / 18.0, 0.0, 1.0)
			elif wrapped_deg > 48.0:
				danger = clampf((wrapped_deg - 48.0) / 20.0, 0.0, 1.0)
			var pending: int = _compute_air_aura(air_dist, _air_peak_y - _air_takeoff_y, flips, spins_180) + _air_carry_aura
			var air_title: String = _build_air_title(flips, _air_total_pitch, spins_180)
			var air_stats: String = "%.0f m · %.1f s" % [air_dist, _air_time]
			_emit_live_stunt(true, air_title, air_stats, pending, danger)
		return

	# 3. Transition Air -> Ground (Landing!)
	if not was_on_floor and now_on_floor:
		floor_snap_length = 0.45
		stunt_pitch = wrapf(stunt_pitch, -PI, PI)
		var land_deg: float = rad_to_deg(stunt_pitch)
		var air_dist: float = Vector2(global_position.x, global_position.z).distance_to(_air_start_xz)
		var height_gain: float = maxf(0.0, _air_peak_y - _air_takeoff_y)
		var flips: int = _count_flips(_air_total_pitch)
		var spins_180: int = int(floor((absf(rad_to_deg(_air_total_yaw)) + 35.0) / 180.0))

		if _air_time >= 0.36 and _post_wipeout_grace <= 0.0:
			var hvel2: Vector2 = Vector2(velocity.x, velocity.z)
			var fwd2: Vector2 = Vector2(-global_transform.basis.z.x, -global_transform.basis.z.z)
			var yaw_mismatch_deg: float = rad_to_deg(absf(fwd2.angle_to(hvel2))) if hvel2.length() > 3.0 else 0.0

			if land_deg < AIR_NOSE_CRASH_DEG:
				trigger_wipeout("¡CAÍDA DE TROMPA AL ATERRIZAR!")
				return
			elif land_deg > AIR_TAIL_CRASH_DEG:
				trigger_wipeout("¡ATERRIZAJE INVERTIDO FALLIDO!")
				return
			elif pre_slide_speed_kmh > 30.0 and yaw_mismatch_deg > 72.0 and yaw_mismatch_deg < 138.0:
				trigger_wipeout("¡ATERRIZAJE CRUZADO A ALTA VELOCIDAD!")
				return
			elif yaw_mismatch_deg >= 138.0 and hvel2.length() > 2.0:
				# Landed a clean 180° fakie!
				speed = -absf(speed) * 0.65

		if (_air_time >= AIR_MIN_STUNT_TIME and air_dist >= AIR_MIN_STUNT_DIST) or flips >= 1 or spins_180 >= 1:
			var base_air_aura: int = _compute_air_aura(air_dist, height_gain, flips, spins_180) + _air_carry_aura
			var stunt_title: String = _build_air_title(flips, _air_total_pitch, spins_180)
			var detail: String = "%.0f m · Altura %.1f m" % [air_dist, height_gain]
			if land_deg >= 16.0 and wheelie_in:
				detail += " · ¡A WILLY!"
			_complete_stunt(stunt_title, detail, base_air_aura)
		elif _air_carry_aura > 0:
			_complete_stunt("WILLY + SALTO", "Aterrizaje limpio", _air_carry_aura)

		_air_time = 0.0
		_air_carry_aura = 0
		is_airborne_stunt = false
		_stunt_pitch_vel = 0.0
		if not (land_deg >= 15.0 and wheelie_in):
			stunt_pitch = clampf(stunt_pitch * 0.35, -0.25, 0.35)

	# 4. On-Ground Wheelie & Stoppie Physics
	var can_stoppie: bool = speed > STOPPIE_MIN_SPEED or (is_doing_stoppie and speed > STOPPIE_HOLD_SPEED)
	if wheelie_in and not stoppie_in and speed > WHEELIE_MIN_SPEED and stunt_pitch >= -0.10:
		var target_w_vel: float = 1.45
		if stunt_pitch >= WHEELIE_SPARK_ANGLE:
			target_w_vel = 0.65 + (0.45 if boosting else 0.0) + (stunt_pitch - WHEELIE_SPARK_ANGLE) * 1.8
		elif stunt_pitch >= WHEELIE_SWEET_ANGLE:
			target_w_vel = 0.36 + (0.38 if boosting else 0.0) + clampf(throttle, 0.0, 1.0) * 0.08
		_stunt_pitch_vel = move_toward(_stunt_pitch_vel, target_w_vel, 11.5 * delta)
		stunt_pitch += _stunt_pitch_vel * delta

		if stunt_pitch >= WHEELIE_MAX_ANGLE and _post_wipeout_grace <= 0.0:
			trigger_wipeout("¡TE PASASTE DE ROSCA EN EL WILLY!")
			return
	elif stoppie_in and not wheelie_in and can_stoppie and stunt_pitch <= 0.10:
		var target_s_vel: float = -1.75
		if stunt_pitch <= -STOPPIE_DANGER_ANGLE:
			target_s_vel = -0.85 - (0.35 if throttle < 0.0 else 0.0) - (absf(stunt_pitch) - STOPPIE_DANGER_ANGLE) * 2.4
		elif stunt_pitch <= -deg_to_rad(30.0):
			target_s_vel = -0.56 - (0.35 if throttle < 0.0 else 0.0)
		_stunt_pitch_vel = move_toward(_stunt_pitch_vel, target_s_vel, 12.0 * delta)
		stunt_pitch += _stunt_pitch_vel * delta

		if stunt_pitch <= -STOPPIE_MAX_ANGLE and _post_wipeout_grace <= 0.0:
			trigger_wipeout("¡DE TROMPA POR ENCIMA DEL MANUBRIO!")
			return
	else:
		# Smoothly settle back onto both tires (tapping opposite stunt key helps bring it down faster)
		var counter_push: float = 0.0
		if stunt_pitch > 0.05 and stoppie_in:
			counter_push = -7.5
		elif stunt_pitch < -0.05 and wheelie_in:
			counter_push = 7.5
		_stunt_pitch_vel += (-stunt_pitch * 30.0 + counter_push) * delta
		_stunt_pitch_vel *= exp(-7.5 * delta)
		stunt_pitch += _stunt_pitch_vel * delta
		if absf(stunt_pitch) < 0.008 and absf(_stunt_pitch_vel) < 0.04:
			stunt_pitch = 0.0
			_stunt_pitch_vel = 0.0

	# Track active Wheelie metrics
	if stunt_pitch >= WHEELIE_COUNT_ANGLE and speed > 2.0:
		is_doing_wheelie = true
		is_doing_stoppie = false
		_wheelie_time += delta
		_wheelie_dist += horiz_step_dist
		var deg_now: float = rad_to_deg(stunt_pitch)
		_wheelie_peak_deg = maxf(_wheelie_peak_deg, deg_now)
		var danger: float = clampf((stunt_pitch - WHEELIE_SPARK_ANGLE) / (WHEELIE_MAX_ANGLE - WHEELIE_SPARK_ANGLE), 0.0, 1.0)
		var w_title: String = _get_wheelie_title(_wheelie_time)
		if danger > 0.25:
			w_title += " ¡AL LÍMITE!"
		var w_stats: String = "%.0f m · %.1f s · %.0f°" % [_wheelie_dist, _wheelie_time, deg_now]
		_emit_live_stunt(true, w_title, w_stats, _compute_wheelie_aura(), danger)
	elif stunt_pitch <= -STOPPIE_COUNT_ANGLE and speed > 1.5:
		is_doing_stoppie = true
		is_doing_wheelie = false
		_stoppie_time += delta
		_stoppie_dist += horiz_step_dist
		var deg_now: float = rad_to_deg(absf(stunt_pitch))
		_stoppie_peak_deg = maxf(_stoppie_peak_deg, deg_now)
		var danger: float = clampf((absf(stunt_pitch) - STOPPIE_DANGER_ANGLE) / (STOPPIE_MAX_ANGLE - STOPPIE_DANGER_ANGLE), 0.0, 1.0)
		var s_title: String = "GRAN INVERTIDO" if _stoppie_time >= 1.8 else "STOPPIE / INVERTIDO"
		if danger > 0.25:
			s_title += " ¡CUIDADO!"
		var s_stats: String = "%.0f m · %.1f s · %.0f°" % [_stoppie_dist, _stoppie_time, deg_now]
		_emit_live_stunt(true, s_title, s_stats, _compute_stoppie_aura(), danger)
	else:
		# Check if we just set down a valid Wheelie or Stoppie!
		if is_doing_wheelie:
			if _wheelie_time >= WHEELIE_MIN_TIME and _wheelie_dist >= WHEELIE_MIN_DIST:
				var aura_pts: int = _compute_wheelie_aura()
				var title: String = _get_wheelie_title(_wheelie_time)
				var detail: String = "%.0f m · %.1f s" % [_wheelie_dist, _wheelie_time]
				_complete_stunt(title, detail, aura_pts)
			_clear_ground_stunt_counters()
		elif is_doing_stoppie:
			if _stoppie_time >= STOPPIE_MIN_TIME and _stoppie_dist >= STOPPIE_MIN_DIST:
				var aura_pts: int = _compute_stoppie_aura()
				var title: String = "GRAN INVERTIDO" if _stoppie_time >= 1.8 else "STOPPIE / INVERTIDO"
				var detail: String = "%.0f m · %.1f s" % [_stoppie_dist, _stoppie_time]
				_complete_stunt(title, detail, aura_pts)
			_clear_ground_stunt_counters()
		_emit_live_stunt(false, "", "", 0, 0.0)


func _compute_wheelie_aura() -> int:
	if _wheelie_time < WHEELIE_MIN_TIME or _wheelie_dist < WHEELIE_MIN_DIST:
		return 0
	var sweet_bonus: float = 1.30 if _wheelie_peak_deg >= 42.0 else 1.0
	var spark_bonus: float = 40.0 if _wheelie_peak_deg >= 58.0 else 0.0
	var raw: float = (28.0 * _wheelie_time + 1.55 * _wheelie_dist) * sweet_bonus + spark_bonus
	return clampi(roundi(raw), 40, 480)


func _compute_stoppie_aura() -> int:
	if _stoppie_time < STOPPIE_MIN_TIME or _stoppie_dist < STOPPIE_MIN_DIST:
		return 0
	var deep_bonus: float = 1.35 if _stoppie_peak_deg >= 36.0 else 1.0
	var raw: float = (45.0 * _stoppie_time + 3.4 * _stoppie_dist) * deep_bonus + 20.0
	return clampi(roundi(raw), 55, 340)


func _compute_air_aura(dist_m: float, height_m: float, flips: int, spins_180: int) -> int:
	var pts: float = 35.0 + dist_m * 2.2 + maxf(0.0, height_m) * 18.0
	if flips >= 1:
		pts += float(flips) * 185.0
	if spins_180 >= 1:
		pts += float(spins_180) * 85.0
	if flips >= 1 and spins_180 >= 1:
		pts += 90.0 # Insane combo bonus!
	return clampi(roundi(pts), 60, 650)


func _count_flips(total_pitch_rad: float) -> int:
	return int(floor((absf(rad_to_deg(total_pitch_rad)) + 65.0) / 360.0))


func _get_wheelie_title(duration_s: float) -> String:
	if duration_s >= 5.5:
		return "WILLY TIRANDO CORTE ★"
	elif duration_s >= 2.8:
		return "SUPER WILLY"
	return "WILLY"


func _build_air_title(flips: int, total_pitch_rad: float, spins_180: int) -> String:
	var parts: Array[String] = []
	if flips >= 2:
		parts.append("DOBLE BACKFLIP" if total_pitch_rad > 0.0 else "DOBLE FRONTFLIP")
	elif flips == 1:
		parts.append("BACKFLIP" if total_pitch_rad > 0.0 else "FRONTFLIP")

	if spins_180 >= 2:
		parts.append("GIRO %d°" % (spins_180 * 180))
	elif spins_180 == 1:
		parts.append("GIRO 180°")

	if parts.is_empty():
		return "SALTO ACROBÁTICO"
	if parts.size() >= 2:
		return "INSANE: " + " + ".join(parts)
	return parts[0] + " ★"


func _complete_stunt(stunt_name: String, detail_text: String, base_aura: int) -> void:
	if combo_timer > 0.0:
		combo_count += 1
	else:
		combo_count = 1
	combo_timer = COMBO_WINDOW

	var combo_mult: float = minf(2.5, 1.0 + float(combo_count - 1) * 0.25)
	var total_gained: int = roundi(float(base_aura) * combo_mult)
	_emit_live_stunt(false, "", "", 0, 0.0)
	stunt_landed.emit(stunt_name, detail_text, total_gained, combo_count)


func trigger_wipeout(reason: String = "¡CAÍSTE DE LA MOTO!") -> void:
	if is_wiped_out:
		return
	is_wiped_out = true
	_wipeout_timer = WIPEOUT_DURATION
	_wipeout_side = -1.0 if steering < 0.0 else 1.0
	combo_count = 0
	combo_timer = 0.0
	var penalty: int = 165
	if _wheelie_time > 1.5 or _air_time > 0.5:
		penalty = 200
	_clear_ground_stunt_counters()
	_air_time = 0.0
	_air_carry_aura = 0
	is_airborne_stunt = false
	stunt_pitch = 0.0
	_stunt_pitch_vel = 0.0
	speed *= 0.35
	velocity.x *= 0.55
	velocity.z *= 0.55
	floor_snap_length = 0.45
	_emit_live_stunt(false, "", "", 0, 0.0)
	stunt_wiped_out.emit(reason, penalty)


func _process_wipeout(delta: float) -> void:
	_wipeout_timer = maxf(0.0, _wipeout_timer - delta)
	speed = move_toward(speed, 0.0, 18.0 * delta)
	velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 14.0 * delta)
	if is_on_floor():
		floor_snap_length = 0.45
		velocity.y = -0.2
	else:
		velocity.y -= gravity * delta
	move_and_slide()

	var progress: float = 1.0 - (_wipeout_timer / WIPEOUT_DURATION)
	if progress < 0.72:
		# Bike lays on its side sliding across asphalt; rider tumbles alongside
		var t_fall: float = clampf(progress / 0.25, 0.0, 1.0)
		var lay_roll: float = lerpf(0.0, _wipeout_side * 1.32, t_fall)
		var rot_b: Basis = Basis.from_euler(Vector3(0.0, sin(progress * 5.0) * 0.28, lay_roll))
		visual.basis = rot_b.scaled(Vector3.ONE * _visual_scale)
		visual.position = Vector3(0.0, 0.24 * t_fall, 0.0)
		if is_instance_valid(rider):
			rider.position = _rider_rest_pos + Vector3(_wipeout_side * 0.95 * t_fall, -0.55 * t_fall + sin(progress * PI) * 0.35, -0.65 * progress)
			rider.rotation = _rider_rest_rot + Vector3(-1.35 * t_fall, 0.4 * _wipeout_side, _wipeout_side * 1.15 * t_fall)
		_update_sparks(delta, get_speed_kmh() > 9.0)
	else:
		# Quick remount recovery in final 0.43s
		var t_rec: float = clampf((progress - 0.72) / 0.28, 0.0, 1.0)
		var lay_roll: float = lerpf(_wipeout_side * 1.32, 0.0, t_rec)
		var rot_b: Basis = Basis.from_euler(Vector3(0.0, 0.0, lay_roll))
		visual.basis = rot_b.scaled(Vector3.ONE * _visual_scale)
		visual.position = Vector3(0.0, 0.24 * (1.0 - t_rec), 0.0)
		if is_instance_valid(rider):
			rider.position = rider.position.lerp(_rider_rest_pos, minf(1.0, delta * 14.0))
			rider.rotation = rider.rotation.lerp(_rider_rest_rot, minf(1.0, delta * 14.0))
		_update_sparks(delta, false)

	if _wipeout_timer <= 0.0:
		is_wiped_out = false
		_post_wipeout_grace = 0.85
		_reset_visual_and_rider()


func _update_visual_pose(delta: float, throttle: float, turn_factor: float) -> void:
	var roll_limit: float = 0.22 if (is_doing_wheelie or is_doing_stoppie) else 0.40
	var target_roll: float = steering * turn_factor * roll_limit * signf(speed) if is_on_floor() else steering * 0.25
	_visual_roll = lerp_angle(_visual_roll, target_roll, delta * 7.0)

	var target_pivot: Vector3 = Vector3.ZERO
	if not is_on_floor():
		target_pivot = AIR_COM_PIVOT
	elif stunt_pitch > 0.02:
		target_pivot = REAR_TIRE_PIVOT
	elif stunt_pitch < -0.02:
		target_pivot = FRONT_TIRE_PIVOT
	_active_pivot = _active_pivot.lerp(target_pivot, minf(1.0, delta * 15.0))

	var micro_squat: float = -throttle * 0.035 * turn_factor if (is_on_floor() and absf(stunt_pitch) < 0.04) else 0.0
	var rot_basis: Basis = Basis.from_euler(Vector3(stunt_pitch + micro_squat, 0.0, _visual_roll))
	visual.basis = rot_basis.scaled(Vector3.ONE * _visual_scale)
	visual.position = _active_pivot - rot_basis * _active_pivot

	if is_instance_valid(rider):
		var rider_lean_x: float = _rider_rest_rot.x
		if is_doing_wheelie:
			rider_lean_x = _rider_rest_rot.x - clampf(stunt_pitch * 0.35, 0.0, 0.38)
		elif is_doing_stoppie:
			rider_lean_x = _rider_rest_rot.x + 0.24
		rider.position = _rider_rest_pos
		rider.rotation = Vector3(lerp_angle(rider.rotation.x, rider_lean_x, delta * 8.0), 0.0, -_visual_roll * 0.30)

	front_fork.rotation.y = steering * 0.28
	var rear_spin_speed: float = speed * (0.25 if is_doing_stoppie else 1.0)
	var front_spin_speed: float = speed * (0.35 if is_doing_wheelie else 1.0)
	_wheel_rotation -= rear_spin_speed / 0.44 * delta
	_front_wheel_rotation -= front_spin_speed / 0.44 * delta
	front_wheel.rotation.x = _front_wheel_rotation
	rear_wheel.rotation.x = _wheel_rotation

	var scraping_tail: bool = is_on_floor() and is_doing_wheelie and stunt_pitch >= WHEELIE_SPARK_ANGLE and absf(speed) > 4.0
	_update_sparks(delta, scraping_tail)


func _update_sparks(delta: float, active: bool) -> void:
	if not is_instance_valid(_sparks_root):
		return
	_sparks_root.visible = active
	if not active:
		return
	_spark_phase += delta * 38.0
	for i: int in range(_spark_meshes.size()):
		var sm: MeshInstance3D = _spark_meshes[i]
		var spread: float = float(i - 2.5) * 0.075
		var pulse: float = absf(sin(_spark_phase + float(i) * 1.3))
		sm.position = Vector3(spread, 0.02 + pulse * 0.08, 0.12 + pulse * 0.30)
		sm.rotation = Vector3(-0.35 - pulse * 0.45, spread * 1.8, 0.0)
		sm.scale = Vector3(1.0, 1.0, 0.55 + pulse * 0.95)


func _emit_live_stunt(active: bool, title: String, stats: String, pending_aura: int, danger: float) -> void:
	if not active and not _live_banner_was_active:
		return
	_live_banner_was_active = active
	stunt_live_updated.emit(active, title, stats, pending_aura, danger)


func _is_in_any_active_stunt() -> bool:
	return is_doing_wheelie or is_doing_stoppie or is_airborne_stunt or absf(stunt_pitch) > deg_to_rad(18.0)


func _clear_ground_stunt_counters() -> void:
	is_doing_wheelie = false
	is_doing_stoppie = false
	_wheelie_time = 0.0
	_wheelie_dist = 0.0
	_wheelie_peak_deg = 0.0
	_stoppie_time = 0.0
	_stoppie_dist = 0.0
	_stoppie_peak_deg = 0.0


func _reset_visual_and_rider() -> void:
	_visual_roll = 0.0
	_active_pivot = Vector3.ZERO
	stunt_pitch = 0.0
	_stunt_pitch_vel = 0.0
	if is_instance_valid(visual):
		visual.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * _visual_scale), Vector3.ZERO)
	if is_instance_valid(rider):
		rider.position = _rider_rest_pos
		rider.rotation = _rider_rest_rot
	if is_instance_valid(left_leg):
		left_leg.position = _lleg_rest_pos
		left_leg.rotation = _lleg_rest_rot
	if is_instance_valid(right_leg):
		right_leg.position = _rleg_rest_pos
		right_leg.rotation = _rleg_rest_rot
	_update_sparks(0.0, false)


func respawn(spawn_transform: Transform3D) -> void:
	global_transform = spawn_transform
	velocity = Vector3.ZERO
	speed = 0.0
	boost = 1.0
	steering = 0.0
	floor_snap_length = 0.45
	_vehicle_crash_cooldown = 0.6
	is_wiped_out = false
	_wipeout_timer = 0.0
	_post_wipeout_grace = 0.5
	is_airborne_stunt = false
	_air_time = 0.0
	_air_carry_aura = 0
	combo_count = 0
	combo_timer = 0.0
	_clear_ground_stunt_counters()
	_emit_live_stunt(false, "", "", 0, 0.0)
	_reset_visual_and_rider()
	reset_physics_interpolation()


func get_speed_kmh() -> float:
	return Vector2(velocity.x, velocity.z).length() * 3.6

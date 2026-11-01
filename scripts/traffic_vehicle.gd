class_name TrafficVehicle
extends CharacterBody3D

## Dynamic AI traffic vehicle circulating through Ramos Mejía streets.
## Follows lane waypoints, respects street directions, brakes for obstacles and player,
## and signals upcoming turns with amber blinkers from mid-block (90% of the time).

enum TurnSignal { NONE = 0, LEFT = 1, RIGHT = 2 }

var current_lane: Dictionary = {}
var waypoints: PackedVector3Array = PackedVector3Array()
var current_wp_idx: int = 0
var speed: float = 0.0
var cruise_speed: float = 10.0
var wheel_nodes: Array = []
var wheel_radius: float = 0.40
var manager: Node = null
var car_type: String = "sedan"

var active_turn_signal: int = TurnSignal.NONE
var planned_turn_signal: int = TurnSignal.NONE
var planned_next_lane: Dictionary = {}
var has_decided_turn: bool = false
var _blinker_timer: float = 0.0
var _turn_completion_timer: float = 0.0
var _in_turn_transition: bool = false

var _raycast: RayCast3D
var _spotlight: SpotLight3D
var _half_extents: Vector3 = Vector3(1.10, 0.75, 2.25)

# Indicator lights & meshes
var _light_left_blinker: OmniLight3D
var _light_right_blinker: OmniLight3D
var _left_indicators: Array[MeshInstance3D] = []
var _right_indicators: Array[MeshInstance3D] = []
var _amber_mat: StandardMaterial3D

func setup(p_car_type: String, p_color: Color, p_lane: Dictionary, p_waypoints: PackedVector3Array, p_wp_start: int, p_manager: Node, p_initial_speed: float = 8.0) -> void:
	car_type = p_car_type
	current_lane = p_lane
	waypoints = p_waypoints
	current_wp_idx = p_wp_start
	manager = p_manager
	cruise_speed = randf_range(8.5, 11.5)
	speed = p_initial_speed
	has_decided_turn = false
	active_turn_signal = TurnSignal.NONE
	planned_turn_signal = TurnSignal.NONE
	planned_next_lane = {}

	# 1. Collision shape & model dimensions
	var model_scale: Vector3 = Vector3.ONE
	var model_rot_y: float = PI
	var model_pos_y: float = 0.0

	if car_type == "suv":
		_half_extents = Vector3(1.25, 0.90, 2.50)
		wheel_radius = 0.44
		model_scale = Vector3(1.20, 1.20, 1.20)
		model_rot_y = PI
		model_pos_y = 0.025
	elif car_type == "compact":
		_half_extents = Vector3(1.10, 0.70, 2.00)
		wheel_radius = 0.38
		model_scale = Vector3(2.10, 2.10, 2.10)
		model_rot_y = 0.0
		model_pos_y = 0.540
	else: # sedan
		_half_extents = Vector3(1.10, 0.75, 2.25)
		wheel_radius = 0.40
		model_scale = Vector3(1.35, 1.35, 1.35)
		model_rot_y = PI
		model_pos_y = 0.038

	set_meta("is_vehicle", true)
	set_meta("vehicle_type", "traffic")

	var col: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = _half_extents * 2.0
	col.shape = box
	col.position = Vector3(0, _half_extents.y, 0)
	add_child(col)

	# 2. Visual Model
	var model_res_path: String = "res://assets/vehicles/car_" + car_type + ".glb"
	var model_scene = load(model_res_path)
	var model: Node3D = model_scene.instantiate() as Node3D
	model.name = "Model"
	model.scale = model_scale
	model.rotation.y = model_rot_y
	model.position.y = model_pos_y

	# Override body material color and configure night headlights/taillights
	var paint_mat: StandardMaterial3D = StandardMaterial3D.new()
	paint_mat.albedo_color = p_color
	paint_mat.roughness = 0.35
	paint_mat.metallic = 0.25

	var headlight_mat: StandardMaterial3D = StandardMaterial3D.new()
	headlight_mat.albedo_color = Color(1.0, 0.95, 0.8)
	headlight_mat.emission_enabled = true
	headlight_mat.emission = Color(1.0, 0.95, 0.8)
	headlight_mat.emission_energy_multiplier = 2.0

	var taillight_mat: StandardMaterial3D = StandardMaterial3D.new()
	taillight_mat.albedo_color = Color(0.9, 0.05, 0.05)
	taillight_mat.emission_enabled = true
	taillight_mat.emission = Color(0.9, 0.05, 0.05)
	taillight_mat.emission_energy_multiplier = 1.8

	wheel_nodes.clear()
	for child in model.get_children():
		if child.name.to_lower().contains("wheel"):
			wheel_nodes.append(child)
		if child is MeshInstance3D:
			for s: int in range(child.mesh.get_surface_count()):
				var orig_mat = child.mesh.surface_get_material(s)
				var mat_name: String = orig_mat.resource_name.to_lower() if orig_mat else ""
				if mat_name.contains("headlight"):
					child.set_surface_override_material(s, headlight_mat)
				elif mat_name.contains("tail"):
					child.set_surface_override_material(s, taillight_mat)
				elif s == 0 and (child.name.begins_with("NormalCar2_Cube") or child.name.begins_with("SUV_Cube") or child.name.begins_with("Body_Cube")):
					child.set_surface_override_material(0, paint_mat)

	add_child(model)

	# 3. Night Headlight Beam (SpotLight3D, no shadow for high performance)
	_spotlight = SpotLight3D.new()
	_spotlight.name = "Headlights"
	_spotlight.light_color = Color(1.0, 0.96, 0.88)
	_spotlight.light_energy = 1.6
	_spotlight.spot_range = 24.0
	_spotlight.spot_angle = 34.0
	_spotlight.spot_attenuation = 1.1
	_spotlight.shadow_enabled = false
	_spotlight.position = Vector3(0, 0.60, -_half_extents.z - 0.25)
	_spotlight.rotation_degrees = Vector3(-7, 0, 0)
	add_child(_spotlight)

	# 4. Night Taillight Glow (OmniLight3D)
	var taillight: OmniLight3D = OmniLight3D.new()
	taillight.name = "TaillightGlow"
	taillight.light_color = Color(1.0, 0.08, 0.08)
	taillight.light_energy = 0.9
	taillight.omni_range = 3.5
	taillight.shadow_enabled = false
	taillight.position = Vector3(0, 0.65, _half_extents.z + 0.25)
	add_child(taillight)

	# 5. Turn signals / blinkers (luces de giro)
	_amber_mat = StandardMaterial3D.new()
	_amber_mat.albedo_color = Color(1.0, 0.65, 0.05)
	_amber_mat.emission_enabled = true
	_amber_mat.emission = Color(1.0, 0.65, 0.05)
	_amber_mat.emission_energy_multiplier = 4.0

	var ind_mesh: SphereMesh = SphereMesh.new()
	ind_mesh.radius = 0.09
	ind_mesh.height = 0.18
	ind_mesh.radial_segments = 6
	ind_mesh.rings = 3
	ind_mesh.material = _amber_mat

	# Left indicators (front and rear)
	_left_indicators.clear()
	var fl_ind: MeshInstance3D = MeshInstance3D.new()
	fl_ind.mesh = ind_mesh
	fl_ind.position = Vector3(-_half_extents.x + 0.08, 0.62, -_half_extents.z + 0.08)
	fl_ind.visible = false
	add_child(fl_ind)
	_left_indicators.append(fl_ind)

	var rl_ind: MeshInstance3D = MeshInstance3D.new()
	rl_ind.mesh = ind_mesh
	rl_ind.position = Vector3(-_half_extents.x + 0.08, 0.68, _half_extents.z - 0.08)
	rl_ind.visible = false
	add_child(rl_ind)
	_left_indicators.append(rl_ind)

	_light_left_blinker = OmniLight3D.new()
	_light_left_blinker.light_color = Color(1.0, 0.65, 0.05)
	_light_left_blinker.light_energy = 1.3
	_light_left_blinker.omni_range = 4.2
	_light_left_blinker.shadow_enabled = false
	_light_left_blinker.visible = false
	_light_left_blinker.position = Vector3(-_half_extents.x - 0.1, 0.65, 0.0)
	add_child(_light_left_blinker)

	# Right indicators (front and rear)
	_right_indicators.clear()
	var fr_ind: MeshInstance3D = MeshInstance3D.new()
	fr_ind.mesh = ind_mesh
	fr_ind.position = Vector3(_half_extents.x - 0.08, 0.62, -_half_extents.z + 0.08)
	fr_ind.visible = false
	add_child(fr_ind)
	_right_indicators.append(fr_ind)

	var rr_ind: MeshInstance3D = MeshInstance3D.new()
	rr_ind.mesh = ind_mesh
	rr_ind.position = Vector3(_half_extents.x - 0.08, 0.68, _half_extents.z - 0.08)
	rr_ind.visible = false
	add_child(rr_ind)
	_right_indicators.append(rr_ind)

	_light_right_blinker = OmniLight3D.new()
	_light_right_blinker.light_color = Color(1.0, 0.65, 0.05)
	_light_right_blinker.light_energy = 1.3
	_light_right_blinker.omni_range = 4.2
	_light_right_blinker.shadow_enabled = false
	_light_right_blinker.visible = false
	_light_right_blinker.position = Vector3(_half_extents.x + 0.1, 0.65, 0.0)
	add_child(_light_right_blinker)

	# 6. Forward detection raycast for braking & traffic collision avoidance
	_raycast = RayCast3D.new()
	_raycast.name = "FrontRay"
	_raycast.position = Vector3(0, 0.60, -_half_extents.z)
	_raycast.target_position = Vector3(0, 0, -10.5)
	_raycast.collision_mask = 1
	_raycast.enabled = true
	add_child(_raycast)

func _physics_process(delta: float) -> void:
	if waypoints.is_empty():
		return

	# 1. Collision avoidance via front raycast
	var target_speed: float = cruise_speed
	if _raycast.is_colliding():
		var hit_pt: Vector3 = _raycast.get_collision_point()
		var d: float = global_position.distance_to(hit_pt)
		if d < 4.8:
			target_speed = 0.0 # Full stop / brake
		elif d < 10.0:
			target_speed = cruise_speed * clampf((d - 4.8) / 5.2, 0.1, 0.85)

	# 2. Smooth acceleration & braking
	if speed > target_speed:
		speed = move_toward(speed, target_speed, 14.0 * delta)
	else:
		speed = move_toward(speed, target_speed, 4.0 * delta)

	# 3. Check mid-block turn signaling (luces de giro desde mitad de cuadra)
	_update_turn_signaling_check()

	# 4. Waypoint navigation along lane
	if current_wp_idx < waypoints.size():
		var wp: Vector3 = waypoints[current_wp_idx]
		var to_wp: Vector3 = Vector3(wp.x - global_position.x, 0.0, wp.z - global_position.z)
		var dist_wp: float = to_wp.length()

		if dist_wp < 3.2:
			current_wp_idx += 1
			if current_wp_idx >= waypoints.size():
				# End of lane reached! Transition to connected outgoing street at intersection
				if manager != null and manager.has_method("get_next_lane"):
					var next_lane_info: Dictionary = manager.call("get_next_lane", self)
					if not next_lane_info.is_empty():
						current_lane = next_lane_info.get("lane", {})
						waypoints = next_lane_info.get("waypoints", PackedVector3Array())
						current_wp_idx = 0
						_in_turn_transition = true
						_turn_completion_timer = 0.0
					else:
						# No outgoing connection: recycle vehicle
						if manager.has_method("recycle_vehicle"):
							manager.call("recycle_vehicle", self)
						return
				else:
					queue_free()
					return

		# Steer smoothly towards current waypoint
		if to_wp.length_squared() > 0.01:
			var target_yaw: float = atan2(-to_wp.x, -to_wp.z)
			var steer_speed: float = 8.5 if _in_turn_transition else 6.5
			rotation.y = lerp_angle(rotation.y, target_yaw, clampf(steer_speed * delta, 0.0, 1.0))

	# 5. Manage turn signal duration and completion
	if _in_turn_transition:
		_turn_completion_timer += delta
		if _turn_completion_timer > 2.0:
			_in_turn_transition = false
			has_decided_turn = false
			active_turn_signal = TurnSignal.NONE
			planned_turn_signal = TurnSignal.NONE
			planned_next_lane = {}
			_set_blinker_active(TurnSignal.NONE, false)

	# 6. Animate pulsing blinkers
	if active_turn_signal != TurnSignal.NONE:
		_blinker_timer += delta
		var is_on: bool = fmod(_blinker_timer, 0.52) < 0.28
		_set_blinker_active(active_turn_signal, is_on)
	else:
		_set_blinker_active(TurnSignal.NONE, false)

	# 7. Movement along forward vector
	velocity = -global_basis.z * speed
	velocity.y = -0.4 # Maintain ground contact
	move_and_slide()

	# 8. Rotate wheels realistically according to vehicle speed
	if speed > 0.02 and not wheel_nodes.is_empty():
		var rot_step: float = (speed * delta) / wheel_radius
		# Sedan and SUV models are flipped 180° (PI) so forward is -Z
		var mult: float = -1.0 if car_type != "compact" else 1.0
		for w in wheel_nodes:
			w.rotate_x(rot_step * mult)

func _update_turn_signaling_check() -> void:
	if has_decided_turn or waypoints.is_empty() or manager == null:
		return

	# Calculate remaining distance to intersection
	var remaining_dist: float = 0.0
	if current_wp_idx < waypoints.size():
		remaining_dist += global_position.distance_to(waypoints[current_wp_idx])
		for i: int in range(current_wp_idx, waypoints.size() - 1):
			remaining_dist += waypoints[i].distance_to(waypoints[i + 1])

	# Trigger from mid-block (~45m from corner)
	if remaining_dist <= 45.0:
		has_decided_turn = true
		if manager.has_method("preview_next_lane"):
			planned_next_lane = manager.call("preview_next_lane", self)
			if not planned_next_lane.is_empty():
				var next_wps: PackedVector3Array = planned_next_lane.get("waypoints", PackedVector3Array())
				if next_wps.size() >= 2:
					var cur_fwd: Vector2 = Vector2(-global_basis.z.x, -global_basis.z.z).normalized()
					var next_fwd: Vector2 = Vector2(next_wps[1].x - next_wps[0].x, next_wps[1].z - next_wps[0].z).normalized()
					var angle: float = cur_fwd.angle_to(next_fwd)

					if angle > 0.35:
						planned_turn_signal = TurnSignal.RIGHT
					elif angle < -0.35:
						planned_turn_signal = TurnSignal.LEFT
					else:
						planned_turn_signal = TurnSignal.NONE

					# 90% of the time, signal with turn lights before turning!
					if planned_turn_signal != TurnSignal.NONE and randf() < 0.90:
						active_turn_signal = planned_turn_signal

func _set_blinker_active(signal_type: int, is_lit: bool) -> void:
	var left_lit: bool = is_lit and (signal_type == TurnSignal.LEFT)
	var right_lit: bool = is_lit and (signal_type == TurnSignal.RIGHT)

	if _light_left_blinker != null:
		_light_left_blinker.visible = left_lit
	for ind in _left_indicators:
		if is_instance_valid(ind):
			ind.visible = left_lit

	if _light_right_blinker != null:
		_light_right_blinker.visible = right_lit
	for ind in _right_indicators:
		if is_instance_valid(ind):
			ind.visible = right_lit

class_name TrafficManager
extends Node3D

## TrafficManager manages dynamic vehicle traffic throughout Ramos Mejía.
## Builds a directed street network honoring street directions (oneway and two-way lanes),
## and maintains a continuous bubble of circulating vehicles around the player,
## with higher traffic density in the downtown commercial core.

const VehicleScript = preload("res://scripts/traffic_vehicle.gd")

var track: MotoTrack
var bike: MotoBike
var lanes: Array = []
var lane_connections: Dictionary = {}
var active_vehicles: Array = []

var target_vehicle_count: int = 24
var density_factor: float = 1.0
var max_distance_from_player: float = 145.0
var min_spawn_distance: float = 45.0
var max_spawn_distance: float = 125.0

func set_traffic_density(level: int) -> void:
	match level:
		0: density_factor = 0.5
		1: density_factor = 1.0
		2: density_factor = 1.5
		_: density_factor = 1.0


var _spawn_timer: float = 0.0
var _car_types: Array = ["sedan", "sedan", "suv", "compact"]
var _car_colors: Array = [
	Color(0.82, 0.84, 0.86), # Silver
	Color(0.94, 0.94, 0.92), # White
	Color(0.25, 0.27, 0.29), # Dark Gray
	Color(0.08, 0.08, 0.08), # Black
	Color(0.12, 0.20, 0.42), # Navy Blue
	Color(0.62, 0.12, 0.14), # Deep Red
	Color(0.68, 0.62, 0.52), # Champagne
	Color(0.35, 0.48, 0.62)  # Light Blue
]

func clear_all_vehicles() -> void:
	for v in active_vehicles:
		if is_instance_valid(v):
			v.queue_free()
	active_vehicles.clear()

func setup(p_track: MotoTrack, p_bike: MotoBike) -> void:
	track = p_track
	bike = p_bike
	_build_lane_graph()
	_seed_initial_traffic()

func is_player_in_downtown(pos: Vector3) -> bool:
	# Downtown Ramos Mejía commercial & avenue zone:
	# Corridors along Av. de Mayo, Rivadavia, Belgrano, Rosales, Castelli, Alsina, Güemes
	return (pos.x >= -1650.0 and pos.x <= -350.0 and pos.z >= -150.0 and pos.z <= 550.0)

func _build_lane_graph() -> void:
	lanes.clear()
	lane_connections.clear()

	var streets: Array = track.data.get("streets", []) + track.data.get("roads", [])

	for s_idx: int in range(streets.size()):
		var s: Dictionary = streets[s_idx]
		var pts: Array = s.get("points", [])
		if pts.size() < 2 or s.get("bridge", false):
			continue

		var width: float = float(s.get("width", 10.0))
		var oneway: bool = bool(s.get("oneway", false))
		var street_name: String = str(s.get("name", "Calle"))

		if oneway:
			if width >= 13.0:
				# Multi-lane avenue: right and left lanes
				_add_lane(s_idx, street_name, pts, 1.8, true)
				_add_lane(s_idx, street_name, pts, -1.8, true)
			else:
				# Residential one-way: central driving lane clear of right-curb parking
				_add_lane(s_idx, street_name, pts, -0.5, true)
		else:
			# Two-way street: right side in forward direction, right side in reverse direction
			var offset: float = maxf(2.4, width * 0.25)
			_add_lane(s_idx, street_name, pts, offset, false)
			var rev_pts: Array = pts.duplicate()
			rev_pts.reverse()
			_add_lane(s_idx, street_name, rev_pts, offset, false)

	# Build intersection connectivity graph
	for i: int in range(lanes.size()):
		var l: Dictionary = lanes[i]
		var end_pt: Vector3 = l["end"]
		var connections: Array = []
		for j: int in range(lanes.size()):
			if i == j:
				continue
			var other: Dictionary = lanes[j]
			# Avoid immediate U-turn onto reverse lane of same street
			if other["street_idx"] == l["street_idx"]:
				continue
			if end_pt.distance_to(other["start"]) < 12.0:
				connections.append(j)
		lane_connections[l["id"]] = connections

func _add_lane(s_idx: int, street_name: String, raw_pts: Array, offset: float, oneway: bool) -> void:
	var wps: PackedVector3Array = PackedVector3Array()
	var total_len: float = 0.0

	for i: int in range(raw_pts.size() - 1):
		var p0: Array = raw_pts[i]
		var p1: Array = raw_pts[i + 1]
		var dx: float = float(p1[0]) - float(p0[0])
		var dz: float = float(p1[1]) - float(p0[1])
		var seg_len: float = sqrt(dx * dx + dz * dz)
		if seg_len < 0.01:
			continue
		var tx: float = dx / seg_len
		var tz: float = dz / seg_len
		var nx: float = -tz * offset
		var nz: float = tx * offset

		if i == 0:
			wps.append(Vector3(float(p0[0]) + nx, 0.0, float(p0[1]) + nz))
		var pt1: Vector3 = Vector3(float(p1[0]) + nx, 0.0, float(p1[1]) + nz)
		wps.append(pt1)
		total_len += seg_len

	if wps.size() < 2 or total_len < 10.0:
		return

	var lane_id: int = lanes.size()
	lanes.append({
		"id": lane_id,
		"street_idx": s_idx,
		"name": street_name,
		"oneway": oneway,
		"waypoints": wps,
		"start": wps[0],
		"end": wps[-1],
		"length": total_len
	})

func _seed_initial_traffic() -> void:
	if bike == null or lanes.is_empty():
		return
	var player_pos: Vector3 = bike.global_position
	var in_downtown: bool = is_player_in_downtown(player_pos)
	target_vehicle_count = roundi((38 if in_downtown else 24) * density_factor)

	var seeded: int = 0
	var attempts: int = 0
	while seeded < target_vehicle_count and attempts < 250:
		attempts += 1
		var lane_idx: int = randi() % lanes.size()
		var l: Dictionary = lanes[lane_idx]
		var mid_pt: Vector3 = l["waypoints"][l["waypoints"].size() / 2]
		var d: float = player_pos.distance_to(mid_pt)
		if d >= min_spawn_distance and d <= max_spawn_distance:
			if _spawn_vehicle_on_lane(l, randi() % (l["waypoints"].size() - 1)):
				seeded += 1

func _physics_process(delta: float) -> void:
	if bike == null:
		return

	var player_pos: Vector3 = bike.global_position
	var in_downtown: bool = is_player_in_downtown(player_pos)
	target_vehicle_count = roundi((38 if in_downtown else 24) * density_factor)

	# 1. Cull far vehicles outside active bubble
	var i: int = active_vehicles.size() - 1
	while i >= 0:
		var v: CharacterBody3D = active_vehicles[i] as CharacterBody3D
		if not is_instance_valid(v):
			active_vehicles.remove_at(i)
		elif v.global_position.distance_to(player_pos) > max_distance_from_player:
			v.queue_free()
			active_vehicles.remove_at(i)
		i -= 1

	# 2. Maintain active population
	_spawn_timer += delta
	var spawn_rate: float = 0.15 if in_downtown else 0.28
	if _spawn_timer >= spawn_rate and active_vehicles.size() < target_vehicle_count:
		_spawn_timer = 0.0
		_attempt_spawn_vehicle(player_pos)

func _attempt_spawn_vehicle(player_pos: Vector3) -> bool:
	if lanes.is_empty():
		return false

	var attempts: int = 0
	while attempts < 20:
		attempts += 1
		var lane_idx: int = randi() % lanes.size()
		var l: Dictionary = lanes[lane_idx]
		var start_pt: Vector3 = l["start"]
		var d: float = player_pos.distance_to(start_pt)
		if d >= min_spawn_distance and d <= max_spawn_distance:
			# Check distance from existing vehicles
			var too_close: bool = false
			for v in active_vehicles:
				if is_instance_valid(v) and v.global_position.distance_to(start_pt) < 13.0:
					too_close = true
					break
			if not too_close:
				return _spawn_vehicle_on_lane(l, 0)
	return false

func _spawn_vehicle_on_lane(lane: Dictionary, start_wp_idx: int) -> bool:
	var wps: PackedVector3Array = lane["waypoints"]
	if start_wp_idx >= wps.size() - 1:
		return false

	var p0: Vector3 = wps[start_wp_idx]
	var p1: Vector3 = wps[start_wp_idx + 1]
	var dir: Vector3 = (p1 - p0).normalized()
	if dir.length_squared() < 0.01:
		dir = Vector3(0, 0, -1)

	var v: CharacterBody3D = VehicleScript.new() as CharacterBody3D
	var c_type: String = _car_types[randi() % _car_types.size()]
	var c_color: Color = _car_colors[randi() % _car_colors.size()]
	var init_speed: float = randf_range(8.0, 11.5)

	v.position = p0 + Vector3(0, 0.02, 0)
	v.rotation.y = atan2(-dir.x, -dir.z)

	add_child(v)
	v.call("setup", c_type, c_color, lane, wps, start_wp_idx + 1, self, init_speed)
	active_vehicles.append(v)
	return true

func preview_next_lane(vehicle: CharacterBody3D) -> Dictionary:
	var cur_lane_val = vehicle.get("current_lane")
	if cur_lane_val == null or typeof(cur_lane_val) != TYPE_DICTIONARY:
		return {}
	var cur_id: int = int(cur_lane_val.get("id", -1))
	if lane_connections.has(cur_id):
		var conns: Array = lane_connections[cur_id]
		if not conns.is_empty():
			var next_id: int = conns[randi() % conns.size()]
			var next_lane: Dictionary = lanes[next_id]
			return {
				"lane": next_lane,
				"waypoints": next_lane["waypoints"]
			}
	return {}

func get_next_lane(vehicle: CharacterBody3D) -> Dictionary:
	var planned = vehicle.get("planned_next_lane")
	if planned != null and typeof(planned) == TYPE_DICTIONARY and not planned.is_empty():
		return planned
	return preview_next_lane(vehicle)

func recycle_vehicle(vehicle: CharacterBody3D) -> void:
	if active_vehicles.has(vehicle):
		active_vehicles.erase(vehicle)
	if is_instance_valid(vehicle):
		vehicle.queue_free()

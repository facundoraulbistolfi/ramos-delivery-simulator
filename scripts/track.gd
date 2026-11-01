class_name MotoTrack
extends Node3D
## Local metric OSM map: +X east, +Z south. Geometry is baked in the scene.
const DATA_PATH: String = "res://assets/maps/ramos_mejia.json"
const BASE_MAP_PATH: String = "res://assets/maps/ramos_mejia_base.json"
const CUSTOM_OVERLAYS_PATH: String = "res://assets/maps/custom_overlays.json"
var data: Dictionary = {}
var centerline: PackedVector3Array = PackedVector3Array()
var _distances: PackedFloat32Array = PackedFloat32Array()
var _length: float = 0.0
var _road_segments: Array = []
var _road_grid: Dictionary = {}
const GRID_SIZE: float = 120.0
var custom_buildings: Dictionary = {}
var user_decorations: Node3D = null

func _ready() -> void:
	load_map_data()
	_load_custom_decorations()
	_apply_building_overrides()
	_build_night_lights()
	_build_street_corner_signs()
	_build_parked_cars()

func load_map_data() -> void:
	if FileAccess.file_exists(BASE_MAP_PATH) and FileAccess.file_exists(CUSTOM_OVERLAYS_PATH):
		var base_str: String = FileAccess.get_file_as_string(BASE_MAP_PATH)
		var base_dict: Dictionary = JSON.parse_string(base_str) as Dictionary
		var overlay_str: String = FileAccess.get_file_as_string(CUSTOM_OVERLAYS_PATH)
		var overlay_dict: Dictionary = JSON.parse_string(overlay_str) as Dictionary
		data = base_dict.duplicate(true)
		for k: String in overlay_dict.keys():
			if k != "name" and k != "attribution":
				data[k] = overlay_dict[k]
	else:
		data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) as Dictionary
	centerline.clear()
	_distances.clear()
	_length = 0.0
	for point: Array in data["route"]["points"]:
		centerline.append(Vector3(float(point[0]),0.0,float(point[1])))
	_distances.append(0.0)
	for i: int in range(1,centerline.size()):
		_length += centerline[i-1].distance_to(centerline[i])
		_distances.append(_length)
	_road_segments.clear()
	_road_grid.clear()
	for road: Dictionary in data["roads"]+data.get("streets",[]):
		var points: Array=road["points"]
		for i: int in range(points.size()-1):
			var a: Vector2 = Vector2(float(points[i][0]),float(points[i][1]))
			var b: Vector2 = Vector2(float(points[i+1][0]),float(points[i+1][1]))
			if a.distance_squared_to(b) < 0.0001:
				continue
			var seg: Dictionary = {"a":a,"b":b,"width":float(road["width"]),"name":str(road.get("name","Avenida Rivadavia"))}
			_road_segments.append(seg)
			var x0: int = floori((minf(a.x, b.x) - 25.0) / GRID_SIZE)
			var x1: int = floori((maxf(a.x, b.x) + 25.0) / GRID_SIZE)
			var z0: int = floori((minf(a.y, b.y) - 25.0) / GRID_SIZE)
			var z1: int = floori((maxf(a.y, b.y) + 25.0) / GRID_SIZE)
			for gx: int in range(x0, x1 + 1):
				for gz: int in range(z0, z1 + 1):
					var cell: Vector2i = Vector2i(gx, gz)
					if not _road_grid.has(cell):
						_road_grid[cell] = []
					(_road_grid[cell] as Array).append(seg)
	for br: Dictionary in data.get("bridges", []) + data.get("footbridges", []):
		var pts3: Array = br.get("points_3d", [])
		var bw: float = float(br.get("width", 5.0))
		var bname: String = str(br.get("name", "Puente"))
		for i: int in range(pts3.size() - 1):
			var a: Vector2 = Vector2(float(pts3[i][0]), float(pts3[i][2]))
			var b: Vector2 = Vector2(float(pts3[i + 1][0]), float(pts3[i + 1][2]))
			if a.distance_squared_to(b) < 0.0001:
				continue
			var seg: Dictionary = {"a": a, "b": b, "width": bw, "name": bname}
			_road_segments.append(seg)
			var x0: int = floori((minf(a.x, b.x) - 25.0) / GRID_SIZE)
			var x1: int = floori((maxf(a.x, b.x) + 25.0) / GRID_SIZE)
			var z0: int = floori((minf(a.y, b.y) - 25.0) / GRID_SIZE)
			var z1: int = floori((maxf(a.y, b.y) + 25.0) / GRID_SIZE)
			for gx: int in range(x0, x1 + 1):
				for gz: int in range(z0, z1 + 1):
					var cell: Vector2i = Vector2i(gx, gz)
					if not _road_grid.has(cell):
						_road_grid[cell] = []
					(_road_grid[cell] as Array).append(seg)

func get_spawn_transform() -> Transform3D:
	var forward: Vector3 = (centerline[1]-centerline[0]).normalized()
	return Transform3D(Basis.looking_at(forward,Vector3.UP),centerline[0]+forward*9.0+Vector3.UP*0.05)

func get_track_length() -> float:
	return _length

func sample_route(world_position: Vector3) -> Vector2:
	var p: Vector3 = to_local(world_position)
	p.y = 0.0
	var closest: float = INF
	var station: float = 0.0
	for i: int in range(centerline.size()-1):
		var a: Vector3 = centerline[i]
		var v: Vector3 = centerline[i+1]-a
		var fraction: float = clampf((p-a).dot(v)/v.length_squared(),0.0,1.0)
		var distance: float = p.distance_to(a+v*fraction)
		if distance < closest:
			closest = distance
			station = _distances[i]+v.length()*fraction
	return Vector2(station,closest)

func get_track_progress(world_position: Vector3) -> float:
	return sample_route(world_position).x/_length

func get_track_distance(world_position: Vector3) -> float:
	return sample_route(world_position).y

func get_road_distance(world_position: Vector3) -> float:
	var p: Vector3 = to_local(world_position)
	var nearest: float = INF
	var flat: Vector2=Vector2(p.x,p.z)
	var cell: Vector2i = Vector2i(floori(flat.x / GRID_SIZE), floori(flat.y / GRID_SIZE))
	var candidates: Array = _road_grid.get(cell, _road_segments)
	for segment: Dictionary in candidates:
		var a: Vector2=segment["a"]
		var b: Vector2=segment["b"]
		var t: float=clampf((flat-a).dot(b-a)/(b-a).length_squared(),0.0,1.0)
		nearest=minf(nearest,flat.distance_to(a.lerp(b,t))-float(segment["width"])*0.5)
	return nearest

func get_crossing_name(world_position: Vector3) -> String:
	var p_flat: Vector2 = Vector2(world_position.x, world_position.z)
	for br: Dictionary in data.get("bridges", []) + data.get("footbridges", []):
		var pts3: Array = br.get("points_3d", [])
		for i: int in range(pts3.size() - 1):
			var a: Vector2 = Vector2(float(pts3[i][0]), float(pts3[i][2]))
			var b: Vector2 = Vector2(float(pts3[i + 1][0]), float(pts3[i + 1][2]))
			var t: float = clampf((p_flat - a).dot(b - a) / maxf(0.001, (b - a).length_squared()), 0.0, 1.0)
			var dist: float = p_flat.distance_to(a.lerp(b, t))
			if dist <= float(br.get("width", 6.0)) * 0.75:
				var min_y: float = minf(float(pts3[i][1]), float(pts3[i + 1][1]))
				var max_y: float = maxf(float(pts3[i][1]), float(pts3[i + 1][1]))
				if world_position.y >= min_y - 0.5 and world_position.y <= max_y + 4.0:
					return str(br.get("name", "Puente"))
	if get_track_distance(world_position)>18.0:
		var p: Vector2=Vector2(world_position.x,world_position.z)
		var nearest: float=INF
		var name: String="Entorno de Ramos Mejía"
		var cell: Vector2i = Vector2i(floori(p.x / GRID_SIZE), floori(p.y / GRID_SIZE))
		var candidates: Array = _road_grid.get(cell, _road_segments)
		for segment: Dictionary in candidates:
			var a: Vector2=segment["a"]
			var b: Vector2=segment["b"]
			var t: float=clampf((p-a).dot(b-a)/(b-a).length_squared(),0.0,1.0)
			var distance: float=p.distance_squared_to(a.lerp(b,t))
			if distance<nearest:
				nearest=distance
				name=str(segment["name"])
		return name
	var station: float = sample_route(world_position).x
	var current: String = "Larrea"
	for crossing: Dictionary in data["crossings"]:
		if float(crossing["station_m"]) <= station+12.0:
			current = str(crossing["name"])
	return current

func get_tanga_spawn_transform() -> Transform3D:
	var point: Array=data["tanga"]["points"][0]
	var plaza: Vector3=Vector3(float(point[0]),0,float(point[1]))
	var desired: Vector2=Vector2(plaza.x,plaza.z+38.0)
	var nearest: float=INF
	var origin: Vector3=Vector3.ZERO
	for segment: Dictionary in _road_segments:
		if segment["name"]!="Avenida de Mayo":continue
		var a: Vector2=segment["a"]
		var b: Vector2=segment["b"]
		var t: float=clampf((desired-a).dot(b-a)/(b-a).length_squared(),0.0,1.0)
		var candidate: Vector2=a.lerp(b,t)
		var distance: float=desired.distance_squared_to(candidate)
		if distance<nearest:
			nearest=distance
			origin=Vector3(candidate.x,0.05,candidate.y)
	var forward: Vector3=plaza-origin
	forward.y=0.0
	return Transform3D(Basis.looking_at(forward.normalized(),Vector3.UP),origin)

func get_building_spawn_transform(key: String) -> Transform3D:
	for site: Dictionary in data.get("recognizable_buildings",[]):
		if str(site["key"])!=key:continue
		var point: Array=site["visit"]
		var normal: Array=site["front"]["normal"]
		var forward: Vector3=Vector3(-float(normal[0]),0,-float(normal[1]))
		return Transform3D(Basis.looking_at(forward,Vector3.UP),Vector3(float(point[0]),0.05,float(point[1])))
	return get_spawn_transform()

func get_teleport_destinations() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	list.append({
		"name": "Av. Rivadavia y Larrea",
		"subtitle": "Inicio del Recorrido · Límite Este",
		"category": "Centro y Puntos Clave",
		"transform": get_spawn_transform()
	})
	list.append({
		"name": "La Tanga de Ramos Mejía",
		"subtitle": "Av. Rivadavia y Av. de Mayo",
		"category": "Centro y Puntos Clave",
		"transform": get_tanga_spawn_transform()
	})
	list.append({
		"name": "Estación Ramos Mejía (FF.CC. Sarmiento)",
		"subtitle": "Av. Rivadavia y Bolívar",
		"category": "Centro y Puntos Clave",
		"transform": Transform3D(Basis.looking_at(Vector3(-1, 0, 0), Vector3.UP), Vector3(-1345.0, 0.05, 86.0))
	})
	list.append({
		"name": "Av. de Mayo y Chacabuco",
		"subtitle": "Corredor Céntrico Sur · Banco Hipotecario",
		"category": "Centro y Puntos Clave",
		"transform": Transform3D(Basis.looking_at(Vector3(-0.2, 0, -0.98).normalized(), Vector3.UP), Vector3(-1385.0, 0.05, 695.0))
	})
	list.append({
		"name": "Plazoleta Gral. Manuel Belgrano",
		"subtitle": "Av. de Mayo y Belgrano · Estatua de Belgrano",
		"category": "Centro y Puntos Clave",
		"transform": Transform3D(Basis.looking_at(Vector3(0.707, 0, 0.707).normalized(), Vector3.UP), Vector3(-1196.0, 0.05, 334.0))
	})
	for br: Dictionary in data.get("bridges", []) + data.get("footbridges", []):
		var v: Array = br.get("visit", [0.0, 0.0])
		var vd: Array = br.get("visit_dir", [-1.0, 0.0])
		var fwd: Vector3 = Vector3(float(vd[0]), 0.0, float(vd[1])).normalized()
		list.append({
			"name": str(br.get("name", "Puente")),
			"subtitle": str(br.get("address", "Cruce Ferroviario")),
			"category": "Puentes y Cruces Ferroviarios",
			"transform": Transform3D(Basis.looking_at(fwd, Vector3.UP), Vector3(float(v[0]), 0.05, float(v[1])))
		})
	for rc: Dictionary in data.get("railway_crossings", []):
		if str(rc.get("kind", "")) != "vehicular" or not rc.has("visit"):
			continue
		var v: Array = rc["visit"]
		var vd: Array = rc.get("visit_dir", [0.0, -1.0])
		var fwd: Vector3 = Vector3(float(vd[0]), 0.0, float(vd[1])).normalized()
		list.append({
			"name": str(rc["name"]),
			"subtitle": "Cruce a Nivel FF.CC. Sarmiento",
			"category": "Puentes y Cruces Ferroviarios",
			"transform": Transform3D(Basis.looking_at(fwd, Vector3.UP), Vector3(float(v[0]), 0.05, float(v[1])))
		})
	for site: Dictionary in data.get("recognizable_buildings", []):
		list.append({
			"name": str(site["name"]),
			"subtitle": str(site["address"]),
			"category": "Edificios Emblemáticos",
			"transform": get_building_spawn_transform(str(site["key"]))
		})
	for fp: Dictionary in data.get("featured_places", []):
		var v: Array = fp["visit"]
		var nrm: Array = fp["front"]["normal"]
		var fwd: Vector3 = Vector3(-float(nrm[0]), 0.0, -float(nrm[1])).normalized()
		list.append({
			"name": str(fp["name"]),
			"subtitle": str(fp.get("address", "")),
			"category": "Centro Comercial y Locales",
			"transform": Transform3D(Basis.looking_at(fwd, Vector3.UP), Vector3(float(v[0]), 0.05, float(v[1])))
		})
	return list

func _load_custom_decorations() -> void:
	const DECO_PATH: String = "res://custom/decorations.tscn"
	if ResourceLoader.exists(DECO_PATH):
		var deco_scene: PackedScene = load(DECO_PATH) as PackedScene
		if deco_scene != null:
			user_decorations = deco_scene.instantiate() as Node3D
			user_decorations.name = "CustomDecorations"
			for child in user_decorations.get_children():
				if child.name.begins_with("ReferenceMap") or child.has_meta("is_editor_reference"):
					child.queue_free()
			add_child(user_decorations)

func _apply_building_overrides() -> void:
	var dir_access: DirAccess = DirAccess.open("res://custom/buildings")
	if dir_access == null:
		return
	dir_access.list_dir_begin()
	var file_name: String = dir_access.get_next()
	while file_name != "":
		if not dir_access.current_is_dir():
			var ext: String = file_name.get_extension().to_lower()
			if ext == "glb" or ext == "gltf" or ext == "tscn":
				var key: String = file_name.get_basename().to_lower()
				_override_single_building(key, "res://custom/buildings/" + file_name)
		file_name = dir_access.get_next()

func _override_single_building(key: String, file_path: String) -> void:
	var transform_to_use: Transform3D = _get_building_front_transform(key)
	if transform_to_use == Transform3D.IDENTITY:
		return
	
	var scene: PackedScene = load(file_path) as PackedScene
	if scene == null:
		return
	
	var instance: Node3D = scene.instantiate() as Node3D
	if instance == null:
		return
	
	instance.name = "CustomBuilding_" + key
	instance.transform = transform_to_use
	_ensure_smart_collision(instance)
	
	# Ocultar la fachada y cartel procedural previo si existía en el árbol
	var proc_facade: Node = find_child("Buildings_facade_" + key, true, false)
	if proc_facade != null and proc_facade is Node3D:
		(proc_facade as Node3D).visible = false
	var proc_sign: Node = find_child("Sign_" + key.validate_node_name(), true, false)
	if proc_sign != null and proc_sign is Node3D:
		(proc_sign as Node3D).visible = false
	
	custom_buildings[key] = instance
	add_child(instance)

func _get_building_front_transform(key: String) -> Transform3D:
	for site: Dictionary in data.get("recognizable_buildings", []):
		if str(site["key"]) == key:
			var a: Array = site["front"]["a"]
			var b_pt: Array = site["front"]["b"]
			var nrm: Array = site["front"]["normal"]
			var mid: Vector3 = Vector3((float(a[0]) + float(b_pt[0])) * 0.5, 0.05, (float(a[1]) + float(b_pt[1])) * 0.5)
			var n_vec: Vector3 = Vector3(float(nrm[0]), 0.0, float(nrm[1])).normalized()
			return Transform3D(Basis.looking_at(-n_vec, Vector3.UP), mid)
	for fp: Dictionary in data.get("featured_places", []):
		if str(fp["key"]) == key:
			var a: Array = fp["front"]["a"]
			var b_pt: Array = fp["front"]["b"]
			var nrm: Array = fp["front"]["normal"]
			var mid: Vector3 = Vector3((float(a[0]) + float(b_pt[0])) * 0.5, 0.05, (float(a[1]) + float(b_pt[1])) * 0.5)
			var n_vec: Vector3 = Vector3(float(nrm[0]), 0.0, float(nrm[1])).normalized()
			return Transform3D(Basis.looking_at(-n_vec, Vector3.UP), mid)
	return Transform3D.IDENTITY

func _ensure_smart_collision(node: Node3D) -> void:
	if _has_collision_shape(node):
		return
	var meshes: Array[MeshInstance3D] = []
	_find_meshes(node, meshes)
	if meshes.is_empty():
		return
	var static_body: StaticBody3D = StaticBody3D.new()
	static_body.name = "AutoCollision"
	node.add_child(static_body)
	for mesh_inst: MeshInstance3D in meshes:
		if mesh_inst.mesh != null:
			var cshape: CollisionShape3D = CollisionShape3D.new()
			var trimesh: ConcavePolygonShape3D = mesh_inst.mesh.create_trimesh_shape()
			trimesh.backface_collision = true
			cshape.shape = trimesh
			cshape.transform = mesh_inst.transform
			static_body.add_child(cshape)

func _has_collision_shape(node: Node) -> bool:
	if node is CollisionShape3D or node is CollisionPolygon3D:
		return true
	for child in node.get_children():
		if _has_collision_shape(child):
			return true
	return false

func _find_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		_find_meshes(child, result)

func get_locale_pickup_position(key: String, locale_dict: Dictionary = {}) -> Vector3:
	if custom_buildings.has(key):
		var inst: Node3D = custom_buildings[key]
		if is_instance_valid(inst):
			if inst.has_node("Pickup"):
				return (inst.get_node("Pickup") as Node3D).global_position
			elif inst.has_node("Entrada"):
				return (inst.get_node("Entrada") as Node3D).global_position
	if locale_dict.has("visit"):
		var v: Array = locale_dict["visit"]
		return Vector3(float(v[0]), 0.05, float(v[1]))
	return Vector3.ZERO

func _build_night_lights() -> void:
	var lights_root: Node3D = Node3D.new()
	lights_root.name = "NightLights"
	add_child(lights_root)
	
	# Streetlights along the avenue
	var sections: Array = data.get("sections", [])
	for i: int in range(5, sections.size() - 5, 8):
		var sec: Dictionary = sections[i]
		var sx: float = float(sec["x"])
		for side: float in [-1.0, 1.0]:
			var intervals: Array = sec.get("intervals", [])
			if intervals.is_empty():
				continue
			var edge_z: float = float(intervals[0][0] if side < 0 else intervals[-1][1])
			var lp: Vector3 = Vector3(sx, 6.8, edge_z + side * 3.8)
			var light: OmniLight3D = OmniLight3D.new()
			light.light_color = Color(1.0, 0.88, 0.65)
			light.light_energy = 2.4
			light.omni_range = 22.0
			light.omni_attenuation = 1.35
			light.distance_fade_enabled = true
			light.distance_fade_begin = 55.0
			light.distance_fade_length = 20.0
			light.shadow_enabled = false
			light.position = lp
			lights_root.add_child(light)

	# Intersections streetlights throughout Ramos Mejía neighborhoods
	var signs_data: Array = data.get("street_signs", [])
	for i: int in range(0, signs_data.size(), 2):
		var s: Dictionary = signs_data[i]
		var pos_arr: Array = s.get("pos", [0, 0])
		var lp: Vector3 = Vector3(float(pos_arr[0]), 6.2, float(pos_arr[1]))
		var light: OmniLight3D = OmniLight3D.new()
		light.light_color = Color(1.0, 0.88, 0.68)
		light.light_energy = 2.2
		light.omni_range = 22.0
		light.omni_attenuation = 1.3
		light.distance_fade_enabled = true
		light.distance_fade_begin = 50.0
		light.distance_fade_length = 20.0
		light.shadow_enabled = false
		light.position = lp
		lights_root.add_child(light)

	# Key storefront / landmark lighting
	for site: Dictionary in data.get("recognizable_buildings", []):
		var v: Array = site.get("visit", [0, 0])
		var sl: OmniLight3D = OmniLight3D.new()
		sl.light_color = Color(1.0, 0.94, 0.82)
		sl.light_energy = 2.6
		sl.omni_range = 25.0
		sl.distance_fade_enabled = true
		sl.distance_fade_begin = 65.0
		sl.distance_fade_length = 25.0
		sl.position = Vector3(float(v[0]), 3.5, float(v[1]))
		lights_root.add_child(sl)

	for fp: Dictionary in data.get("featured_places", []):
		var v: Array = fp.get("visit", [0, 0])
		var fl: OmniLight3D = OmniLight3D.new()
		fl.light_color = Color(1.0, 0.92, 0.78)
		fl.light_energy = 2.4
		fl.omni_range = 20.0
		fl.distance_fade_enabled = true
		fl.distance_fade_begin = 55.0
		fl.distance_fade_length = 20.0
		fl.shadow_enabled = false
		fl.position = Vector3(float(v[0]), 3.4, float(v[1]))
		lights_root.add_child(fl)

func _build_street_corner_signs() -> void:
	var signs_data: Array = data.get("street_signs", [])
	if signs_data.is_empty():
		return
	var signs_root: Node3D = Node3D.new()
	signs_root.name = "StreetCornerSigns"
	add_child(signs_root)

	var post_mat: StandardMaterial3D = StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.04, 0.18, 0.42) # Azul institucional La Matanza
	post_mat.roughness = 0.45
	post_mat.metallic = 0.55

	var plate_mat: StandardMaterial3D = StandardMaterial3D.new()
	plate_mat.albedo_color = Color(0.04, 0.16, 0.38)
	plate_mat.roughness = 0.35

	var post_mesh: CylinderMesh = CylinderMesh.new()
	post_mesh.material = post_mat
	post_mesh.top_radius = 0.04
	post_mesh.bottom_radius = 0.04
	post_mesh.height = 3.2
	post_mesh.radial_segments = 8

	var plate_mesh: BoxMesh = BoxMesh.new()
	plate_mesh.material = plate_mat
	plate_mesh.size = Vector3(1.05, 0.28, 0.02)

	for s: Dictionary in signs_data:
		var pos_arr: Array = s.get("pos", [0, 0])
		var p: Vector3 = Vector3(float(pos_arr[0]), 0.0, float(pos_arr[1]))

		var node: Node3D = Node3D.new()
		node.position = p
		signs_root.add_child(node)

		# 1. Post (3.2m tall)
		var post_inst: MeshInstance3D = MeshInstance3D.new()
		post_inst.mesh = post_mesh
		post_inst.position = Vector3(0, 1.6, 0)
		post_inst.visibility_range_end = 65.0
		node.add_child(post_inst)

		# 2. Cantilevered sign plates with double-sided legible text
		_create_sign_arm(node, plate_mesh, str(s.get("street1", "")), float(s.get("yaw1", 0.0)), bool(s.get("oneway1", false)), str(s.get("num1", "100 - 200")), 2.95)
		_create_sign_arm(node, plate_mesh, str(s.get("street2", "")), float(s.get("yaw2", 0.0)), bool(s.get("oneway2", false)), str(s.get("num2", "100 - 200")), 2.62)

func _create_sign_arm(parent: Node3D, plate_mesh: BoxMesh, street_name: String, yaw: float, oneway: bool, num_str: String, height: float) -> void:
	if street_name.is_empty():
		return
	var arm: Node3D = Node3D.new()
	arm.position = Vector3(0, height, 0)
	arm.rotation.y = yaw
	parent.add_child(arm)

	# Plate is cantilevered out along local X (+0.48m offset)
	var plate: MeshInstance3D = MeshInstance3D.new()
	plate.mesh = plate_mesh
	plate.position = Vector3(0.48, 0, 0)
	plate.visibility_range_end = 60.0
	arm.add_child(plate)

	var arrow: String = " ➡" if oneway else " ⬅ ➡"
	var text_content: String = "MUNICIPALIDAD DE LA MATANZA\n" + street_name + arrow + "\n" + num_str

	# Front face label (z = +0.013m)
	var lbl_front: Label3D = Label3D.new()
	lbl_front.text = text_content
	lbl_front.font_size = 22
	lbl_front.pixel_size = 0.0030
	lbl_front.outline_size = 4
	lbl_front.outline_modulate = Color(0.01, 0.05, 0.12, 1.0)
	lbl_front.modulate = Color(0.96, 0.98, 1.0, 1.0)
	lbl_front.shaded = false
	lbl_front.position = Vector3(0.48, 0, 0.013)
	lbl_front.visibility_range_end = 45.0
	arm.add_child(lbl_front)

	# Back face label (z = -0.013m, rotated PI so it reads naturally from the reverse side)
	var lbl_back: Label3D = Label3D.new()
	lbl_back.text = text_content
	lbl_back.font_size = 22
	lbl_back.pixel_size = 0.0030
	lbl_back.outline_size = 4
	lbl_back.outline_modulate = Color(0.01, 0.05, 0.12, 1.0)
	lbl_back.modulate = Color(0.96, 0.98, 1.0, 1.0)
	lbl_back.shaded = false
	lbl_back.position = Vector3(0.48, 0, -0.013)
	lbl_back.rotation.y = PI
	lbl_back.visibility_range_end = 45.0
	arm.add_child(lbl_back)

func _build_parked_cars() -> void:
	var cars_data: Array = data.get("parked_cars", [])
	if cars_data.is_empty():
		return
	var parked_root: Node3D = Node3D.new()
	parked_root.name = "ParkedCars"
	add_child(parked_root)

	var sedan_scene = load("res://assets/vehicles/car_sedan.glb")
	var suv_scene = load("res://assets/vehicles/car_suv.glb")
	var compact_scene = load("res://assets/vehicles/car_compact.glb")

	var paint_materials: Dictionary = {}

	for c: Dictionary in cars_data:
		var pos_arr: Array = c.get("pos", [0, 0])
		var p: Vector3 = Vector3(float(pos_arr[0]), 0.0, float(pos_arr[1]))
		var yaw: float = float(c.get("yaw", 0.0))
		var model_name: String = str(c.get("model", "sedan"))
		var color_arr: Array = c.get("color", [0.8, 0.8, 0.8])
		var color_key: String = "%s_%.2f_%.2f_%.2f" % [model_name, color_arr[0], color_arr[1], color_arr[2]]

		var node: Node3D = Node3D.new()
		node.position = Vector3(p.x, 0.04, p.z)
		node.rotation.y = yaw
		parked_root.add_child(node)

		var model_inst: Node3D
		var half_extents: Vector3
		if model_name == "suv":
			model_inst = suv_scene.instantiate() as Node3D
			model_inst.scale = Vector3(1.20, 1.20, 1.20)
			model_inst.rotation.y = PI
			model_inst.position.y = 0.025
			half_extents = Vector3(1.25, 0.90, 2.50)
		elif model_name == "compact":
			model_inst = compact_scene.instantiate() as Node3D
			model_inst.scale = Vector3(2.10, 2.10, 2.10)
			model_inst.rotation.y = 0.0
			model_inst.position.y = 0.540
			half_extents = Vector3(1.10, 0.70, 2.00)
		else:
			model_inst = sedan_scene.instantiate() as Node3D
			model_inst.scale = Vector3(1.35, 1.35, 1.35)
			model_inst.rotation.y = PI
			model_inst.position.y = 0.038
			half_extents = Vector3(1.10, 0.75, 2.25)

		for mesh_inst: MeshInstance3D in model_inst.find_children("", "MeshInstance3D", true, false):
			mesh_inst.visibility_range_end = 65.0
			mesh_inst.visibility_range_end_margin = 8.0
			mesh_inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			if mesh_inst.name.begins_with("NormalCar2_Cube") or mesh_inst.name.begins_with("SUV_Cube") or mesh_inst.name.begins_with("Body_Cube"):
				if not paint_materials.has(color_key):
					var mat: StandardMaterial3D = StandardMaterial3D.new()
					mat.albedo_color = Color(float(color_arr[0]), float(color_arr[1]), float(color_arr[2]))
					mat.roughness = 0.40
					mat.metallic = 0.25
					paint_materials[color_key] = mat
				mesh_inst.set_surface_override_material(0, paint_materials[color_key])

		node.add_child(model_inst)

		var body: StaticBody3D = StaticBody3D.new()
		body.set_meta("is_vehicle", true)
		body.set_meta("vehicle_type", "parked")
		var col: CollisionShape3D = CollisionShape3D.new()
		var box_shape: BoxShape3D = BoxShape3D.new()
		box_shape.size = half_extents * 2.0
		col.shape = box_shape
		col.position = Vector3(0, half_extents.y, 0)
		body.add_child(col)
		node.add_child(body)


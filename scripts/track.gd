class_name MotoTrack
extends Node3D
## Local metric OSM map: +X east, +Z south. Geometry is baked in the scene.
const DATA_PATH: String = "res://assets/maps/ramos_mejia.json"
var data: Dictionary = {}
var centerline: PackedVector3Array = PackedVector3Array()
var _distances: PackedFloat32Array = PackedFloat32Array()
var _length: float = 0.0
var _road_segments: Array = []

func _ready() -> void:
	load_map_data()

func load_map_data() -> void:
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
	for road: Dictionary in data["roads"]+data.get("streets",[]):
		var points: Array=road["points"]
		for i: int in range(points.size()-1):
			_road_segments.append({"a":Vector2(float(points[i][0]),float(points[i][1])),"b":Vector2(float(points[i+1][0]),float(points[i+1][1])),"width":float(road["width"]),"name":str(road.get("name","Avenida Rivadavia"))})

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
	for segment: Dictionary in _road_segments:
		var a: Vector2=segment["a"]
		var b: Vector2=segment["b"]
		var t: float=clampf((flat-a).dot(b-a)/(b-a).length_squared(),0.0,1.0)
		nearest=minf(nearest,flat.distance_to(a.lerp(b,t))-float(segment["width"])*0.5)
	return nearest

func get_crossing_name(world_position: Vector3) -> String:
	if get_track_distance(world_position)>18.0:
		var p: Vector2=Vector2(world_position.x,world_position.z)
		var nearest: float=INF
		var name: String="Entorno de Ramos Mejía"
		for segment: Dictionary in _road_segments:
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

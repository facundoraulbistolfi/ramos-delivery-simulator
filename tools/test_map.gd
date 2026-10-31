extends SceneTree
var failures: int = 0
var game: Node
var track: MotoTrack
var bike: MotoBike

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, text: String) -> void:
	print("PASS " if value else "FAIL ",text)
	if not value: failures+=1

func point_at(station: float) -> Vector3:
	for i: int in range(track.centerline.size()-1):
		if track._distances[i+1]>=station:
			var t: float = (station-track._distances[i])/(track._distances[i+1]-track._distances[i])
			return track.centerline[i].lerp(track.centerline[i+1],t)
	return track.centerline[-1]

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	track=game.get_node("Track") as MotoTrack
	bike=game.get_node("Moto") as MotoBike
	for frame: int in range(10): await physics_frame
	check(absf(track.get_track_length()-1647.630512)<0.03,"metric route length 1647.63 m")
	check(track.centerline[0].length()<0.01,"Larrea origin")
	check(track.centerline[-1].distance_to(Vector3(-1631.9398,0,125.2057))<0.02,"Necochea OSM endpoint")
	check(absf(bike.position.y)<0.03,"bike rests on ground")
	check(track.get_road_distance(bike.position)<0.0,"spawn is on avenue")
	check(track.get_child_count()>20,"baked geometry present")
	bike.max_speed=18.0
	Input.action_press("accelerate")
	var furthest: float = 0.0
	for frame: int in range(9000):
		var station: float = track.sample_route(bike.position).x
		furthest=maxf(furthest,station)
		if station>track.get_track_length()-14.0: break
		var target: Vector3 = point_at(minf(station+14.0,track.get_track_length()))
		var direction: Vector3 = target-bike.position
		direction.y=0.0
		var angle: float = (-bike.global_basis.z).signed_angle_to(direction.normalized(),Vector3.UP)
		Input.action_release("steer_left")
		Input.action_release("steer_right")
		Input.action_press("steer_left" if angle>0 else "steer_right",clampf(absf(angle)*3.0,0,1))
		await physics_frame
	Input.action_release("accelerate")
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	check(furthest>1630.0,"full avenue drivable; reached %.1f m"%furthest)
	check(int(track.data["coverage"]["south_block_rows"])==2,"two southern block rows")
	check(int(track.data["coverage"]["north_block_rows"])==1,"one block north beyond railway")
	check(track.data["streets"].size()>80,"expanded street network")
	check(track.data["buildings"].size()>150,"expanded mapped building coverage")
	check(track.data["tanga"]["plaza_points"].size()>=3,"Tanga plaza geometry")
	check(not track.has_node("AvenueOnlyBoundaries"),"invisible avenue barriers removed")
	var space: PhysicsDirectSpaceState3D=bike.get_world_3d().direct_space_state
	var density: Dictionary=track.data["block_density"]
	check(int(density["added_volumes"])>100 and float(density["unfilled_bike_clearance_m2"])<0.02,"private blocks have no bike-sized empty gaps")
	var interior_probes: int=0
	var missed_interiors: int=0
	for outline: Array in density["private_regions"]:
		var region: PackedVector2Array=PackedVector2Array()
		for point: Array in outline:region.append(Vector2(float(point[0]),float(point[1])))
		var triangles: PackedInt32Array=Geometry2D.triangulate_polygon(region)
		for i: int in range(0,triangles.size(),3):
			var p: Vector2=(region[triangles[i]]+region[triangles[i+1]]+region[triangles[i+2]])/3.0
			var query: PhysicsRayQueryParameters3D=PhysicsRayQueryParameters3D.create(Vector3(p.x,120,p.y),Vector3(p.x,0.3,p.y))
			query.exclude=[bike.get_rid()]
			var hit: Dictionary=space.intersect_ray(query)
			interior_probes+=1
			# Test a footprint smaller than the bike capsule, including shared-edge seams.
			if hit.is_empty():
				for offset: Vector2 in [Vector2(0.15,0),Vector2(-0.15,0),Vector2(0,0.15),Vector2(0,-0.15)]:
					query.from=Vector3(p.x+offset.x,120,p.y+offset.y)
					query.to=Vector3(p.x+offset.x,0.3,p.y+offset.y)
					hit=space.intersect_ray(query)
					if not hit.is_empty():break
			if hit.is_empty():missed_interiors+=1
	check(interior_probes>30 and missed_interiors==0,"block interior bike-clearance probes: %d tested, %d gaps"%[interior_probes,missed_interiors])
	var blocked_passages: int=0
	for passage: Dictionary in track.data["open_passages"]:
		var points: Array=passage["points"]
		for i: int in range(points.size()-1):
			var a: Vector3=Vector3(float(points[i][0]),1.0,float(points[i][1]))
			var c: Vector3=Vector3(float(points[i+1][0]),1.0,float(points[i+1][1]))
			if a.distance_to(c)<0.2:continue
			var query: PhysicsRayQueryParameters3D=PhysicsRayQueryParameters3D.create(a.lerp(c,0.1),a.lerp(c,0.9))
			query.exclude=[bike.get_rid()]
			var hit: Dictionary=space.intersect_ray(query)
			if not hit.is_empty() and str(hit["collider"].name).begins_with("Buildings_facade") and not str(hit["collider"].name).contains("property_wall"):
				blocked_passages+=1
	check(blocked_passages==0,"mapped outdoor passages remain unobstructed by infill")
	check(track.data["recognizable_buildings"].size()==3,"three recognizable architectural landmarks")
	for site: Dictionary in track.data["recognizable_buildings"]:
		var transform: Transform3D=track.get_building_spawn_transform(str(site["key"]))
		var point: PhysicsPointQueryParameters3D=PhysicsPointQueryParameters3D.new()
		point.position=transform.origin+Vector3.UP
		point.exclude=[bike.get_rid()]
		check(space.intersect_point(point).is_empty(),str(site["key"])+" visit position is outside solid buildings")
		var a: Array=site["front"]["a"]
		var c: Array=site["front"]["b"]
		var normal: Array=site["front"]["normal"]
		var middle: Vector3=Vector3((float(a[0])+float(c[0]))*0.5,1.5,(float(a[1])+float(c[1]))*0.5)
		var direction: Vector3=Vector3(float(normal[0]),0,float(normal[1]))
		var front_query: PhysicsRayQueryParameters3D=PhysicsRayQueryParameters3D.create(transform.origin+Vector3.UP*1.45,middle-direction)
		front_query.exclude=[bike.get_rid()]
		var front_hit: Dictionary=space.intersect_ray(front_query)
		check(not front_hit.is_empty() and str(front_hit["collider"].name)=="Buildings_facade_"+str(site["key"]),str(site["key"])+" recognizable shell has facade collision at its geographic footprint")
	var checked_buildings: int=0
	var missed_buildings: int=0
	for building: Dictionary in track.data["buildings"]+track.data["generated_buildings"]:
		var polygon: PackedVector2Array=PackedVector2Array()
		for point: Array in building["points"]:polygon.append(Vector2(float(point[0]),float(point[1])))
		var triangles: PackedInt32Array=Geometry2D.triangulate_polygon(polygon)
		if triangles.size()<3:continue
		# A large interior triangle avoids numerical noise in tiny clipped boundary ears.
		var best_triangle: int=0
		var best_area: float=0.0
		for i: int in range(0,triangles.size(),3):
			var area: float=absf((polygon[triangles[i+1]]-polygon[triangles[i]]).cross(polygon[triangles[i+2]]-polygon[triangles[i]]))
			if area>best_area:
				best_area=area
				best_triangle=i
		var inside: Vector2=(polygon[triangles[best_triangle]]+polygon[triangles[best_triangle+1]]+polygon[triangles[best_triangle+2]])/3.0
		var query: PhysicsRayQueryParameters3D=PhysicsRayQueryParameters3D.create(Vector3(inside.x,float(building["height"])+100.0,inside.y),Vector3(inside.x,0.2,inside.y))
		query.exclude=[bike.get_rid()]
		var hit: Dictionary=space.intersect_ray(query)
		checked_buildings+=1
		if hit.is_empty() or not str(hit["collider"].name).begins_with("Buildings_"):missed_buildings+=1
	check(checked_buildings>900 and missed_buildings==0,"all %d mapped and generic buildings have roof collision; misses=%d"%[checked_buildings,missed_buildings])
	var front: Dictionary=track.data["generated_buildings"][0]["front"]
	var a: Vector3=Vector3(float(front["a"][0]),0,float(front["a"][1]))
	var b: Vector3=Vector3(float(front["b"][0]),0,float(front["b"][1]))
	var toward: Vector3=Vector3(float(front["towards"][0]),0,float(front["towards"][1])).normalized()
	var start: Vector3=(a+b)*0.5+toward*2.0+Vector3.UP*0.02
	bike.respawn(Transform3D(Basis.looking_at(-toward,Vector3.UP),start))
	Input.action_press("accelerate")
	for frame: int in range(120):await physics_frame
	Input.action_release("accelerate")
	check((bike.position-(a+b)*0.5).dot(toward)>0.2,"bike cannot drive through building facade")
	bike.respawn(track.get_tanga_spawn_transform())
	check(track.get_road_distance(bike.position)<0,"T shortcut spawns on Avenida de Mayo")
	bike.respawn(Transform3D(Basis.IDENTITY,Vector3(100000,4,100000)))
	for frame: int in range(120):await physics_frame
	check(absf(bike.position.y)<0.03,"infinite floor prevents falling outside mapped area")
	game._reset_session()
	game._set_paused(true)
	var position_before: Vector3 = bike.position
	Input.action_press("accelerate")
	for frame: int in range(20): await physics_frame
	Input.action_release("accelerate")
	check(bike.position.distance_to(position_before)<0.001,"pause stops bike")
	game._set_paused(false)
	check(track.get_crossing_name(track.centerline[-1])=="Necochea","HUD identifies destination")
	print("MAP_QA failures=",failures)
	quit(failures)

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
	var tm_node: Node3D = game.get_node_or_null("TrafficManager") as Node3D
	if tm_node != null:
		tm_node.call("clear_all_vehicles")
		tm_node.process_mode = Node.PROCESS_MODE_DISABLED
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
	if tm_node != null:
		tm_node.process_mode = Node.PROCESS_MODE_INHERIT
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
	var region_idx: int=0
	for outline: Array in density["private_regions"]:
		region_idx+=1
		if density["private_regions"].size()>120 and region_idx%6!=0:continue
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
	var all_buildings: Array=track.data["buildings"]+track.data["generated_buildings"]
	var b_step: int=maxi(1,int(floor(float(all_buildings.size())/950.0)))
	for b_idx: int in range(0,all_buildings.size(),b_step):
		var building: Dictionary=all_buildings[b_idx]
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
	check(track.data.get("featured_places",[]).size()>=45,"expanded featured Ramos Mejía locales and downtown corridors present")
	check(track.data.get("detailed_plazas",[]).size()==4,"four detailed plazas present")
	check(track.has_node("SectorChunks") and track.get_node("SectorChunks").get_child_count()>20,"spatial sector chunking active for GPU optimization")
	check(track.data.get("bridges",[]).size()==3 and track.has_node("BridgeCollision"),"Díaz Vélez bridge and two U-bridges present with collision")
	check(track.data.get("footbridges",[]).size()==1,"pedestrian bridge Moreno-French present")
	check(track.data.get("railway_walls",[]).size()>10 and track.has_node("RailwayBarrierCollision"),"railway perimeter barriers active outside crossings")
	check(track.data.get("ramos_boundary",[]).size()>20 and track.data.get("extended_streets",[]).size()>50,"official Ramos Mejía boundary and extended streets present for map")
	# Verify elevated bridge deck collision on Díaz Vélez bridge and U-bridges
	for br: Dictionary in track.data.get("bridges",[]):
		var pts: Array = br["points_3d"]
		var mid_pt: Array = pts[pts.size() / 2]
		var b_ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			Vector3(float(mid_pt[0]), 25.0, float(mid_pt[2])),
			Vector3(float(mid_pt[0]), 0.5, float(mid_pt[2]))
		)
		b_ray.exclude = [bike.get_rid()]
		var b_hit: Dictionary = space.intersect_ray(b_ray)
		check(not b_hit.is_empty() and float(b_hit["position"].y) > 2.0, str(br["key"]) + " bridge has elevated driveable deck collision")
	# Verify HUD simplified panels, M map blocking controls, and TAB teleport destinations
	var hud: MotoHUD = game.get_node("HUD") as MotoHUD
	check(hud != null and hud.has_node("Interface/OrderPanel") and hud.has_node("Interface/StatusPanel"),"simplified two-panel HUD active")
	check(track.get_teleport_destinations().size() > 35,"TAB teleport selector destinations populated")
	if hud != null:
		hud.set_map_open(true)
		check(hud.is_map_open() and not bike.controls_enabled,"opening M map covers screen and disables driving controls")
		hud.set_map_open(false)
		check(not hud.is_map_open() and bike.controls_enabled,"closing M map restores driving controls")
	const MissionSystem = preload("res://scripts/mission_system.gd")
	var ms: Node3D = game.get("mission_system") as Node3D
	check(ms != null and int(ms.get("state")) == MissionSystem.State.PICKUP,"mission system starts in pickup state")
	if ms != null:
		var pickup_pos: Vector3 = ms.call("get_active_target_position")
		bike.respawn(Transform3D(Basis.IDENTITY, pickup_pos))
		for frame: int in range(6): await physics_frame
		check(int(ms.get("state")) == MissionSystem.State.DELIVER,"visiting locale picks up order and advances to delivery state")
		var deliver_pos: Vector3 = ms.call("get_active_target_position")
		bike.respawn(Transform3D(Basis.IDENTITY, deliver_pos))
		for frame: int in range(6): await physics_frame
		check(int(ms.get("completed_count")) >= 1,"visiting destination address completes delivery mission")
		check(int(ms.get("_addresses").size()) > 800, "citywide address pool indexed across entire 8 km² map")
		# Verify multi-drop delivery order (reparto combinado 2 casas)
		var offers: Array = ms.call("_generate_3_order_offers")
		check(offers.size() == 3, "generates 3 delivery tier offers")
		var combo_offer: Dictionary = offers[2]
		check(bool(combo_offer.get("is_multi_drop", false)) and (combo_offer.get("dest_addresses") as Array).size() == 2, "tier 2 offer is multi-drop with 2 destination stops")
		# Verify car collision penalty mechanic in delivery mode
		var money_before: int = int(ms.get("total_money"))
		var fines_before: int = int(ms.get("total_crash_fines"))
		var fine: int = ms.call("apply_crash_penalty", 32.0)
		check(fine > 0 and int(ms.get("total_money")) == money_before - fine, "crashing into car deducts money proportional to impact speed")
		check(int(ms.get("total_crash_fines")) == fines_before + fine, "crash penalty fines tracked in mission summary")
	# Verify startup mode selection dialog
	check(hud != null and hud.has_node("Interface/ModeSelectionOverlay"), "startup mode selection overlay (Free Roam vs Delivery) initialized")
	# Verify custom user decoration layer and Estatua de Belgrano
	check(track.user_decorations != null, "custom user decorations layer loaded")
	var belgrano_statue: Node = track.find_child("EstatuaManuelBelgrano", true, false)
	check(belgrano_statue != null, "Estatua de Belgrano instantiated in Plazoleta Belgrano")
	if belgrano_statue != null:
		var statue_ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			Vector3(-1191.4, 2.0, 330.0),
			Vector3(-1191.4, 2.0, 335.0)
		)
		statue_ray.exclude = [bike.get_rid()]
		var statue_hit: Dictionary = space.intersect_ray(statue_ray)
		check(not statue_hit.is_empty(), "Estatua de Belgrano has solid physical collision")
	# Verify night lighting, motorcycle headlight, and street corner signs
	check(bike.has_node("Visual/Headlight") and bike.get_node("Visual/Headlight") is SpotLight3D, "motorcycle night headlight beam present")
	check(track.has_node("NightLights") and track.get_node("NightLights").get_child_count() > 15, "night streetlights and building lights active")
	check(track.has_node("StreetCornerSigns") and track.get_node("StreetCornerSigns").get_child_count() > 100, "Argentine street corner direction signs installed")
	# Verify realistic curbside parked cars and moving traffic system
	check(track.has_node("ParkedCars") and track.get_node("ParkedCars").get_child_count() > 500, "parked cars populated along curbs in Ramos Mejía")
	var parked_root: Node3D = track.get_node_or_null("ParkedCars") as Node3D
	if parked_root != null and parked_root.get_child_count() > 0:
		var sample_car: Node3D = parked_root.get_child(0) as Node3D
		var car_pos: Vector3 = sample_car.global_position
		var car_ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			car_pos + Vector3(0, 10.0, 0),
			car_pos + Vector3(0, 0.2, 0)
		)
		car_ray.exclude = [bike.get_rid()]
		var car_hit: Dictionary = space.intersect_ray(car_ray)
		check(not car_hit.is_empty(), "parked cars have physical obstacle collision")
	var tm: Node3D = game.get_node_or_null("TrafficManager") as Node3D
	check(tm != null and int(tm.get("lanes").size()) > 500, "traffic manager initialized with directed street lanes graph")
	check(tm != null and int(tm.get("lanes_by_cell").size()) > 100, "traffic manager spatial hash grid active for citywide vehicle spawning")
	# Verify GTA-style motorcycle stunts, wipeout recovery, custom stunt ramps, and Aura score multiplier
	check(InputMap.has_action("stunt_wheelie") and InputMap.has_action("stunt_stoppie"), "stunt wheelie and stoppie input actions registered")
	check(hud != null and hud.find_child("AuraBar", true, false) != null and hud.find_child("StuntBanner", true, false) != null, "HUD Aura meter bar and StuntBanner initialized")
	check(track.find_child("RampaMayoNorte", true, false) != null and track.find_child("RampaMayoCentro", true, false) != null, "custom urban stunt ramps instantiated in CustomDecorations")
	if ms != null:
		if tm != null:
			tm.call("clear_all_vehicles")
			tm.process_mode = Node.PROCESS_MODE_DISABLED
		ms.call("_reset_aura_stats")
		bike.max_speed = 34.0
		bike.respawn(track.get_spawn_transform())
		for frame: int in range(6): await physics_frame
		# 1. Clean Wheelie -> increases Aura
		Input.action_press("accelerate")
		for frame: int in range(30): await physics_frame
		Input.action_press("stunt_wheelie")
		var saw_wheelie: bool = false
		for frame: int in range(72):
			var st_w: float = track.sample_route(bike.position).x
			var tgt_w: Vector3 = point_at(minf(st_w + 16.0, track.get_track_length()))
			var dir_w: Vector3 = tgt_w - bike.position
			dir_w.y = 0.0
			var ang_w: float = (-bike.global_basis.z).signed_angle_to(dir_w.normalized(), Vector3.UP)
			Input.action_release("steer_left")
			Input.action_release("steer_right")
			Input.action_press("steer_left" if ang_w > 0.0 else "steer_right", clampf(absf(ang_w) * 2.5, 0.0, 1.0))
			await physics_frame
			if bike.is_doing_wheelie and bike.stunt_pitch > 0.25:
				saw_wheelie = true
		Input.action_release("stunt_wheelie")
		Input.action_release("steer_left")
		Input.action_release("steer_right")
		for frame: int in range(38): await physics_frame
		Input.action_release("accelerate")
		var aura_after_wheelie: float = float(ms.get("aura"))
		check(saw_wheelie and aura_after_wheelie > 0.0 and int(ms.get("stunt_count")) >= 1, "performing clean wheelie increases Aura meter (aura=%.0f)" % aura_after_wheelie)

		# 2. Clean Stoppie -> increases Aura further
		bike.respawn(track.get_spawn_transform())
		for frame: int in range(4): await physics_frame
		Input.action_press("accelerate")
		for frame: int in range(45): await physics_frame
		Input.action_release("accelerate")
		Input.action_press("stunt_stoppie")
		var saw_stoppie: bool = false
		for frame: int in range(44):
			await physics_frame
			if bike.is_doing_stoppie and bike.stunt_pitch < -0.20:
				saw_stoppie = true
		Input.action_release("stunt_stoppie")
		for frame: int in range(38): await physics_frame
		var aura_after_stoppie: float = float(ms.get("aura"))
		check(saw_stoppie and aura_after_stoppie > aura_after_wheelie, "performing clean stoppie increases Aura meter (aura=%.0f)" % aura_after_stoppie)

		# 3. Over-rotating Wheelie -> triggers Wipeout (caída), deducts Aura, and recovers cleanly
		var aura_before_fall: float = maxf(aura_after_stoppie, 300.0)
		ms.set("aura", aura_before_fall)
		bike.respawn(track.get_spawn_transform())
		bike._post_wipeout_grace = 0.0
		for frame: int in range(4): await physics_frame
		Input.action_press("accelerate")
		Input.action_press("boost")
		for frame: int in range(24): await physics_frame
		Input.action_press("stunt_wheelie")
		var saw_wipeout: bool = false
		for frame: int in range(180):
			await physics_frame
			if bike.is_wiped_out:
				saw_wipeout = true
				break
		Input.action_release("stunt_wheelie")
		Input.action_release("boost")
		Input.action_release("accelerate")
		var aura_after_fall: float = float(ms.get("aura"))
		check(saw_wipeout and aura_after_fall < aura_before_fall and int(ms.get("wipeout_count")) >= 1, "failing stunt by over-rotating causes wipeout and loses Aura (%.0f -> %.0f)" % [aura_before_fall, aura_after_fall])
		for frame: int in range(110): await physics_frame
		check(not bike.is_wiped_out, "rider remounts and recovers cleanly after stunt wipeout")

		# 4. Final Score Aura Bonus Multiplier calculation
		ms.set("total_money", 10000)
		ms.set("aura", 500.0)
		var score_calc: Dictionary = ms.call("calculate_final_score")
		check(int(score_calc.get("aura_bonus", 0)) == 5000 and int(score_calc.get("final_score", 0)) == 15000, "Aura acts as bonus multiplier on final shift score (x1.50 -> 15000 pts)")
		if tm != null:
			tm.process_mode = Node.PROCESS_MODE_INHERIT
	print("MAP_QA failures=",failures)
	quit(failures)

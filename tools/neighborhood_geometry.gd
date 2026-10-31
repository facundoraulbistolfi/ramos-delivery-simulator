extends RefCounted
## Expanded city geometry with detailed architectural facades, roofs, storefronts, plazas, and streetscape.
var b: SceneTree
var data: Dictionary

func generate(builder: SceneTree) -> void:
	b = builder
	data = b.data
	for i: int in range(8):
		b.colors["facade%d" % i] = Color("eceae4")
	b.colors["landmark_stone"] = Color("e8e5dc")
	b.colors["pavers"] = Color("edeae2")
	var architecture: RefCounted = load("res://tools/recognizable_buildings.gd").new()
	architecture.prepare(b)

	# Fill split-carriageway medians and railway border strip cleanly without overlapping roads.
	var sections: Array = data["sections"]
	for i: int in range(sections.size() - 1):
		var sa: Dictionary = sections[i]
		var sb: Dictionary = sections[i + 1]
		var xa: float = float(sa["x"])
		var xb: float = float(sb["x"])
		var ia: Array = sa["intervals"]
		var ib: Array = sb["intervals"]
		var z_min_a: float = float(ia[0][0]) - 3.5
		var z_max_a: float = float(ia[-1][1]) + 3.5
		var z_min_b: float = float(ib[0][0]) - 3.5
		var z_max_b: float = float(ib[-1][1]) + 3.5
		b._quad(
			Vector3(xa, 0.008, z_min_a),
			Vector3(xb, 0.008, z_min_b),
			Vector3(xb, 0.008, z_max_b),
			Vector3(xa, 0.008, z_max_a),
			"walk"
		)

	for triangle: Array in data["pavement_triangles"]:
		_triangle(triangle, 0.015, "road")
	# Ensure long straight road segments dropped by unconstrained Delaunay triangulation are 100% paved.
	for road: Dictionary in data["roads"] + data["streets"]:
		var r_pts: Array = road["points"]
		var r_w: float = float(road["width"])
		for i: int in range(r_pts.size() - 1):
			b._strip(b._v(r_pts[i], 0.016), b._v(r_pts[i + 1], 0.016), r_w, "road")
	for triangle: Array in data["sidewalk_triangles"]:
		_triangle(triangle, 0.17, "walk")
	for pavement: Dictionary in data["pavement"]:
		var rings: Array = [pavement["outer"]]
		rings.append_array(pavement["holes"])
		for ring: Array in rings:
			for i: int in range(ring.size()):
				var a: Vector3 = b._v(ring[i])
				var c: Vector3 = b._v(ring[(i + 1) % ring.size()])
				b._quad(a, c, c + Vector3.UP * 0.17, a + Vector3.UP * 0.17, "curb")
	for road: Dictionary in data["roads"] + data["streets"]:
		_markings(road)
	for passage: Dictionary in data.get("open_passages", []):
		var points: Array = passage["points"]
		var p_width: float = float(passage["width"])
		for i: int in range(points.size() - 1):
			var pa: Vector3 = b._v(points[i], 0.0)
			var pb: Vector3 = b._v(points[i + 1], 0.0)
			var p_len: float = pa.distance_to(pb)
			var steps: int = maxi(1, ceili(p_len / 2.5))
			for s: int in range(steps):
				var s0: Vector3 = pa.lerp(pb, float(s) / float(steps))
				var s1: Vector3 = pa.lerp(pb, float(s + 1) / float(steps))
				var mid: Vector3 = (s0 + s1) * 0.5
				if b.map.get_road_distance(mid) > 0.15:
					b._strip(Vector3(s0.x, 0.175, s0.z), Vector3(s1.x, 0.175, s1.z), p_width, "pavers")
	for wall: Dictionary in data.get("property_walls", []):
		var points: Array = wall["points"]
		var height: float = float(wall["height"])
		for i: int in range(points.size() - 1):
			var a: Vector3 = b._v(points[i])
			var c: Vector3 = b._v(points[i + 1])
			var dist: float = a.distance_to(c)
			var yaw: float = -atan2((c - a).z, (c - a).x)
			b._box((a + c) * 0.5 + Vector3.UP * height * 0.5, Vector3(dist + 0.05, height, 0.18), "facade_property_wall", yaw)
			b._box((a + c) * 0.5 + Vector3.UP * (height + 0.04), Vector3(dist + 0.07, 0.08, 0.24), "trim_stone", yaw)

	for building: Dictionary in data["buildings"] + data["generated_buildings"]:
		var bid: int = int(building.get("generated_id", building["osm_id"]))
		var color_index: int = posmod(bid, 8)
		var role: String = str(building.get("recognizable", ""))
		var h: float = float(building["height"])
		b._polygon(building["points"], h, "facade_" + role if not role.is_empty() else "facade%d" % color_index)
		if role.is_empty() and h > 2.2:
			if str(building.get("type", "")) != "generic_block_infill":
				_building_roof_and_trim(building, bid)
				_front(building, bid)
			else:
				b._polygon(building["points"], 0.015, "roof_terrace", h)

	for landmark: Dictionary in data["landmarks"]:
		if landmark["type"] == "station":
			b._sign(b._v(landmark["point"], 6.8), "ESTACIÓN RAMOS MEJÍA\nLÍNEA SARMIENTO", PI * 0.5)
		elif landmark["type"] == "green":
			_green_park(landmark)
		elif landmark["type"] == "platform":
			b._polygon(landmark["points"], 0.65, "walk")

	_railways()
	_tanga()
	architecture.generate()
	var trees_list: Array = data.get("trees", [])
	for i: int in range(trees_list.size()):
		var tp: Vector3 = b._v(trees_list[i], 0.16)
		if not b._is_near_special_zone(tp) and b.map.get_road_distance(tp) > 1.0:
			b._tree(tp, 0.88 + float(i % 4) * 0.07)

	for crossing: Dictionary in data["crossings"]:
		var section: Dictionary = b._section_near(float(crossing["point"][0]))
		var p: Vector3 = b._v(crossing["point"], 0.04)
		var side: float = signf(float(crossing["direction"][1]))
		if side == 0.0:
			side = 1.0
		var edge: float = float(section["intervals"][0][0] if side < 0 else section["intervals"][-1][1])
		var sign_pos: Vector3 = Vector3(p.x + 5.0, 0.17, edge + side * 2.1)
		if absf(p.x - float(data["tanga"]["points"][0][0])) > 45.0 and b.map.get_road_distance(sign_pos) > 0.9:
			_traffic_light_and_sign(sign_pos, str(crossing["name"]), side)
		if str(crossing["name"]) in ["Larrea", "Necochea"]:
			continue
		for z: int in range(ceili(float(section["intervals"][0][0]) + 0.8), floori(float(section["intervals"][-1][1]) - 0.8)):
			b._box(Vector3(p.x - 5.0, 0.045, z), Vector3(2.6, 0.014, 0.44), "line")

	# Side-street plaques placed strictly outside road carriageways
	var named: Dictionary = {}
	for road: Dictionary in data["streets"]:
		var name: String = str(road["name"])
		if name.is_empty() or named.has(name):
			continue
		var points: Array = road["points"]
		var index: int = floori(float(points.size() - 1) * 0.5)
		var p: Vector3 = b._v(points[index], 3.0)
		var direction: Vector3 = (b._v(points[mini(index + 1, points.size() - 1)]) - b._v(points[maxi(index - 1, 0)])).normalized()
		var right: Vector3 = direction.cross(Vector3.UP)
		var candidate: Vector3 = p + right * (float(road["width"]) * 0.5 + 1.4)
		if absf(p.x - float(data["tanga"]["points"][0][0])) > 35.0 and b.map.get_road_distance(candidate) > 0.9:
			named[name] = true
			_street_sign(candidate, name, atan2(-right.x, -right.z))

func _building_roof_and_trim(building: Dictionary, bid: int) -> void:
	var pts: Array = building["points"]
	var h: float = float(building["height"])
	# Visual terracotta terrace roof surface slightly above collision cap
	b._polygon(pts, 0.015, "roof_terrace", h)
	# Perimeter parapet coping (muro de carga / albardilla)
	var center: Vector3 = Vector3.ZERO
	for i: int in range(pts.size()):
		var a: Vector3 = b._v(pts[i], h)
		var c: Vector3 = b._v(pts[(i + 1) % pts.size()], h)
		center += a
		var d: float = a.distance_to(c)
		if d < 1.2:
			continue
		var yaw: float = -atan2((c - a).z, (c - a).x)
		b._box((a + c) * 0.5 + Vector3.UP * 0.16, Vector3(d, 0.32, 0.22), "trim_stone", yaw)
	center /= float(pts.size())
	# Rooftop water tank / elevator machine room on multi-storey buildings
	if h >= 9.0 and pts.size() >= 4:
		var poly2d: PackedVector2Array = PackedVector2Array()
		for pt: Array in pts:
			poly2d.append(Vector2(float(pt[0]), float(pt[1])))
		if Geometry2D.is_point_in_polygon(Vector2(center.x, center.z), poly2d):
			b._box(Vector3(center.x, h + 1.1, center.z), Vector3(2.4, 2.2, 2.4), "trim_stone")
			b._box(Vector3(center.x, h + 2.6, center.z), Vector3(1.6, 1.3, 1.6), "silver_metal")

	# For tall buildings (4+ levels), add upper windows on secondary facades too
	if h >= 12.0:
		var poly2d: PackedVector2Array = PackedVector2Array()
		for pt: Array in pts:
			poly2d.append(Vector2(float(pt[0]), float(pt[1])))
		var levels: int = floori(h / 3.1)
		for i: int in range(pts.size()):
			var a2: Vector2 = poly2d[i]
			var c2: Vector2 = poly2d[(i + 1) % poly2d.size()]
			var len_edge: float = a2.distance_to(c2)
			if len_edge < 6.5:
				continue
			var tang2: Vector2 = (c2 - a2) / len_edge
			var norm2: Vector2 = Vector2(-tang2.y, tang2.x)
			if Geometry2D.is_point_in_polygon((a2 + c2) * 0.5 + norm2 * 0.15, poly2d):
				norm2 = -norm2
			var a3: Vector3 = Vector3(a2.x, 0.0, a2.y)
			var c3: Vector3 = Vector3(c2.x, 0.0, c2.y)
			var toward: Vector3 = Vector3(norm2.x, 0.0, norm2.y)
			var tangent: Vector3 = Vector3(tang2.x, 0.0, tang2.y)
			var cols: int = clampi(floori(len_edge / 3.8), 1, 14)
			for lv: int in range(1, levels):
				for col_i: int in range(cols):
					var w_center: Vector3 = a3.lerp(c3, (float(col_i) + 0.5) / float(cols)) + toward * 0.05 + Vector3.UP * (1.6 + float(lv) * 3.1)
					var half: Vector3 = tangent * minf(0.82, len_edge / float(cols) * 0.30)
					b._quad(w_center - half - Vector3.UP * 0.68, w_center + half - Vector3.UP * 0.68, w_center + half + Vector3.UP * 0.68, w_center - half + Vector3.UP * 0.68, "glass")

func _green_park(landmark: Dictionary) -> void:
	var pts: Array = landmark["points"]
	b._polygon(pts, 0.06, "grass")
	var poly2d: PackedVector2Array = PackedVector2Array()
	var center: Vector2 = Vector2.ZERO
	for i: int in range(pts.size()):
		var a: Vector3 = b._v(pts[i])
		var c: Vector3 = b._v(pts[(i + 1) % pts.size()])
		poly2d.append(Vector2(a.x, a.z))
		center += Vector2(a.x, a.z)
		var d: float = a.distance_to(c)
		if d > 0.5:
			b._box((a + c) * 0.5 + Vector3.UP * 0.06, Vector3(d, 0.12, 0.22), "curb", -atan2((c - a).z, (c - a).x))
	center /= float(maxi(1, pts.size()))
	if Geometry2D.is_point_in_polygon(center, poly2d) and pts.size() >= 4:
		var c3: Vector3 = Vector3(center.x, 0.06, center.y)
		if not b._is_near_special_zone(c3) and b.map.get_road_distance(c3) > 3.0:
			b._tree(c3, 1.1)

func _traffic_light_and_sign(position: Vector3, text: String, side: float) -> void:
	_street_sign(position + Vector3(0, 3.0, 0), text, PI * 0.5)
	# Cantilevered Argentine traffic light pole (semáforo con pescante)
	var pole_base: Vector3 = position + Vector3(-1.4, 0.0, 0.0)
	if b.map.get_road_distance(pole_base) < 0.8:
		return
	b._box(pole_base + Vector3(0, 2.75, 0), Vector3(0.14, 5.5, 0.14), "metal")
	b._box(pole_base + Vector3(0, 5.35, -side * 1.8), Vector3(0.10, 0.10, 3.6), "metal")
	# Vertical signal head on pole + overhead signal head on arm
	for head_pos: Vector3 in [pole_base + Vector3(-0.14, 3.6, 0), pole_base + Vector3(-0.12, 5.2, -side * 3.1)]:
		b._box(head_pos, Vector3(0.16, 0.86, 0.26), "metal")
		b._box(head_pos + Vector3(-0.09, 0.24, 0), Vector3(0.04, 0.16, 0.16), "traffic_red")
		b._box(head_pos + Vector3(-0.09, 0.0, 0), Vector3(0.04, 0.16, 0.16), "traffic_yellow")
		b._box(head_pos + Vector3(-0.09, -0.24, 0), Vector3(0.04, 0.16, 0.16), "traffic_green")

func _street_sign(position: Vector3, text: String, yaw: float) -> void:
	var label: Label3D = b._sign(position, text, yaw)
	label.font_size = 28
	label.pixel_size = 0.006
	label.outline_size = 2
	var width: float = maxf(1.25, float(text.length()) * 0.095)
	var offset: Vector3 = Basis(Vector3.UP, yaw) * Vector3(0, 0, -0.02)
	b._box(position + offset, Vector3(width, 0.28, 0.04), "blue", yaw)
	b._box(position + offset + Vector3(0, -0.11, 0), Vector3(width, 0.05, 0.045), "line", yaw)
	b._box(position - Vector3.UP * 1.5, Vector3(0.065, 3.0, 0.065), "metal")

func _triangle(triangle: Array, y: float, key: String) -> void:
	var surface: SurfaceTool = b._batch(key)
	var v0: Vector3 = b._v(triangle[0], y)
	var v1: Vector3 = b._v(triangle[1], y)
	var v2: Vector3 = b._v(triangle[2], y)
	if (v1 - v0).cross(v2 - v0).y < 0.0:
		var tmp: Vector3 = v1
		v1 = v2
		v2 = tmp
	for v: Vector3 in [v0, v1, v2]:
		surface.set_normal(Vector3.UP)
		surface.set_uv(Vector2(v.x, v.z) * 0.42)
		surface.add_vertex(v)

func _markings(road: Dictionary) -> void:
	var points: Array = road["points"]
	var width: float = float(road["width"])
	var lanes: int = int(road["lanes"])
	for i: int in range(points.size() - 1):
		var a: Vector3 = b._v(points[i], 0.032)
		var c: Vector3 = b._v(points[i + 1], 0.032)
		var direction: Vector3 = c - a
		var length: float = direction.length()
		if length < 0.01:
			continue
		var right: Vector3 = direction.normalized().cross(Vector3.UP)
		var driving_width: float = minf(width - 1.5, float(lanes) * 3.25)
		for lane: int in range(1, lanes):
			var offset: float = -driving_width * 0.5 + driving_width * float(lane) / float(lanes)
			if not bool(road["oneway"]) and lane * 2 == lanes:
				for extra: float in [-0.11, 0.11]:
					b._strip(a + right * (offset + extra), c + right * (offset + extra), 0.1, "yellow")
			else:
				var station: float = 0.0
				while station < length:
					b._strip(a.lerp(c, station / length) + right * offset, a.lerp(c, minf(station + 3.0, length) / length) + right * offset, 0.11, "line")
					station += 7.0

func _front(building: Dictionary, bid: int) -> void:
	if not building.has("front"):
		return
	var front: Dictionary = building["front"]
	if float(front["distance"]) > 55.0:
		return
	var a: Vector3 = b._v(front["a"])
	var c: Vector3 = b._v(front["b"])
	var toward: Vector3 = b._v(front["towards"]).normalized()
	var middle: Vector3 = (a + c) * 0.5 + toward * 0.035
	var length: float = a.distance_to(c)
	if length < 2.2:
		return
	var tangent: Vector3 = (c - a).normalized()
	var yaw: float = atan2(toward.x, toward.z)
	var h: float = float(building["height"])
	var total_levels: int = maxi(1, floori(h / 3.1))
	var count: int = clampi(floori(length / 3.4), 1, 25)

	# Ground-floor commercial storefront (locales comerciales) on avenue & street fronts
	var has_storefront: bool = float(front["distance"]) < 36.0 and length >= 4.2
	if has_storefront:
		var awning_keys: Array[String] = ["perla_green", "awning_red", "awning_blue", "awning_striped"]
		var aw_key: String = awning_keys[posmod(bid, 4)]
		# Ground floor large shop windows (vidrieras) + pilasters
		b._quad(
			a + tangent * 0.35 + toward * 0.045 + Vector3.UP * 0.25,
			c - tangent * 0.35 + toward * 0.045 + Vector3.UP * 0.25,
			c - tangent * 0.35 + toward * 0.045 + Vector3.UP * 2.55,
			a + tangent * 0.35 + toward * 0.045 + Vector3.UP * 2.55,
			"glass"
		)
		# Fascia sign band & cornice above storefront
		b._box(middle + toward * 0.08 + Vector3.UP * 2.85, Vector3(length - 0.2, 0.48, 0.14), aw_key, yaw)
		b._box(middle + toward * 0.10 + Vector3.UP * 3.18, Vector3(length, 0.16, 0.22), "trim_stone", yaw)
		# Sloped canvas shop awning on half of storefronts
		if posmod(bid, 2) == 0 and length >= 5.0:
			var aw_half: Vector3 = tangent * (length * 0.46)
			b._quad(
				middle - aw_half + toward * 0.05 + Vector3.UP * 2.82,
				middle + aw_half + toward * 0.05 + Vector3.UP * 2.82,
				middle + aw_half + toward * 0.85 + Vector3.UP * 2.42,
				middle - aw_half + toward * 0.85 + Vector3.UP * 2.42,
				aw_key
			)

	var start_level: int = 1 if has_storefront and total_levels > 1 else 0
	for level: int in range(start_level, total_levels):
		var y_center: float = 1.6 + float(level) * 3.1
		for column: int in range(count):
			var center: Vector3 = a.lerp(c, (float(column) + 0.5) / float(count)) + toward * 0.045 + Vector3.UP * y_center
			var w_half: float = minf(0.85, length / float(count) * 0.32)
			var half: Vector3 = tangent * w_half
			b._quad(center - half - Vector3.UP * 0.72, center + half - Vector3.UP * 0.72, center + half + Vector3.UP * 0.72, center - half + Vector3.UP * 0.72, "glass")
			# Window sill (alféizar)
			b._box(center + toward * 0.04 - Vector3.UP * 0.76, Vector3(w_half * 2.1, 0.08, 0.12), "trim_stone", yaw)
			# Projecting apartment balconies on taller residential buildings
			if h >= 9.0 and level >= 1 and (column + bid) % 2 == 0 and float(front["distance"]) < 32.0:
				b._box(center + toward * 0.36 - Vector3.UP * 0.78, Vector3(w_half * 2.3, 0.10, 0.72), "trim_stone", yaw)
				b._box(center + toward * 0.68 - Vector3.UP * 0.32, Vector3(w_half * 2.3, 0.82, 0.05), "glass", yaw)
				b._box(center + toward * 0.68 + Vector3.UP * 0.10, Vector3(w_half * 2.32, 0.05, 0.07), "metal", yaw)

	if not str(building["name"]).is_empty() and str(building["name"]).length() < 32 and float(front["distance"]) < 24.0:
		b._sign(middle + toward * 0.18 + Vector3.UP * 2.85, str(building["name"]), yaw)

func _railways() -> void:
	for railway: Dictionary in data["railways"]:
		var points: Array = railway["points"]
		for i: int in range(points.size() - 1):
			var a: Vector3 = b._v(points[i], 0.08)
			var c: Vector3 = b._v(points[i + 1], 0.08)
			b._strip(a, c, 3.4, "ballast")
			var right: Vector3 = (c - a).normalized().cross(Vector3.UP)
			for side: float in [-0.835, 0.835]:
				b._strip(a + right * side + Vector3.UP * 0.11, c + right * side + Vector3.UP * 0.11, 0.095, "rail")
			# Third rail (tercer riel electrificado del Sarmiento)
			b._strip(a + right * 1.25 + Vector3.UP * 0.16, c + right * 1.25 + Vector3.UP * 0.16, 0.11, "trunk")
			var length: float = a.distance_to(c)
			var station: float = 0.0
			var yaw: float = -atan2((c - a).z, (c - a).x)
			while station < length:
				b._box(a.lerp(c, station / length), Vector3(0.22, 0.11, 2.5), "trunk", yaw)
				station += 1.15

func _tanga() -> void:
	var tanga: Dictionary = data["tanga"]
	b._polygon(tanga["plaza_points"], 0.22, "pavers")
	b._polygon(tanga["points"], 0.26, "grass")
	# Perimeter stone curb around La Tanga plaza
	var p_pts: Array = tanga["plaza_points"]
	for i: int in range(p_pts.size()):
		var a: Vector3 = b._v(p_pts[i])
		var c: Vector3 = b._v(p_pts[(i + 1) % p_pts.size()])
		b._quad(a, c, c + Vector3.UP * 0.22, a + Vector3.UP * 0.22, "curb")

	var center: Vector3 = Vector3.ZERO
	for p: Array in tanga["points"]:
		center += b._v(p)
	center /= float(tanga["points"].size())

	# Raised stone monument base (keeps exact collision footprint) + coping cap & backing plate
	b._box(center + Vector3(0, 0.62, 0), Vector3(8.5, 0.82, 0.72), "landmark_stone")
	b._box(center + Vector3(0, 1.06, 0), Vector3(8.8, 0.10, 0.86), "trim_stone")
	b._box(center + Vector3(0, 1.58, 0.22), Vector3(8.4, 0.95, 0.14), "metal")
	# Ground LED uplight strip illuminating the welcome letters
	b._box(center + Vector3(0, 1.12, 0.36), Vector3(7.6, 0.05, 0.10), "lamp_glow")

	var letters: MeshInstance3D = MeshInstance3D.new()
	letters.name = "RamosMejiaWelcomeLetters"
	letters.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var text_mesh: TextMesh = TextMesh.new()
	text_mesh.text = "RAMOS MEJÍA"
	text_mesh.font_size = 86
	text_mesh.pixel_size = 0.0115
	text_mesh.depth = 0.18
	letters.mesh = text_mesh
	letters.position = center + Vector3(0, 1.62, 0.38)
	var letter_material: StandardMaterial3D = StandardMaterial3D.new()
	letter_material.albedo_color = Color("f5f7f8")
	letter_material.metallic = 0.55
	letter_material.roughness = 0.22
	letter_material.emission_enabled = true
	letter_material.emission = Color("dce6eb")
	letter_material.emission_energy_multiplier = 0.35
	letters.material_override = letter_material
	b.map.add_child(letters)

	# Flowerbeds in front of the monument
	for fx: float in [-3.0, -1.5, 0.0, 1.5, 3.0]:
		b._box(center + Vector3(fx, 0.34, 0.72), Vector3(0.95, 0.18, 0.45), "grass")
		b._box(center + Vector3(fx, 0.45, 0.72), Vector3(0.75, 0.10, 0.32), "flower_red" if int(absf(fx * 2.0)) % 2 == 0 else "flower_yellow")

	# Detailed park benches with backrests & cast-iron legs
	for side: float in [-1.0, 1.0]:
		var bp: Vector3 = center + Vector3(side * 4.2, 0.0, 1.45)
		b._box(bp + Vector3(0, 0.54, 0), Vector3(1.85, 0.08, 0.48), "trunk")
		b._box(bp + Vector3(0, 0.82, -0.20), Vector3(1.85, 0.42, 0.07), "trunk")
		for lx: float in [-0.75, 0.75]:
			b._box(bp + Vector3(lx, 0.38, 0), Vector3(0.10, 0.55, 0.46), "metal")

	# Twin-arm ornate boulevard streetlamps
	for offset: float in [-5.4, 5.4]:
		var lp: Vector3 = center + Vector3(offset, 0.0, 0.0)
		b._box(lp + Vector3(0, 0.45, 0), Vector3(0.28, 0.9, 0.28), "metal")
		b._box(lp + Vector3(0, 2.8, 0), Vector3(0.11, 5.2, 0.11), "metal")
		b._box(lp + Vector3(0, 5.25, 0), Vector3(1.3, 0.09, 0.09), "metal")
		for arm_x: float in [-0.58, 0.58]:
			b._box(lp + Vector3(arm_x, 5.42, 0), Vector3(0.28, 0.32, 0.28), "lamp_glow")

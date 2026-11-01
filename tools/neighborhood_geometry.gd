extends RefCounted
## Expanded city geometry with 3D bridges, footbridge, railway crossings/barriers, central commercial facades, and optimized batching.
var b: SceneTree
var data: Dictionary

func generate(builder: SceneTree) -> void:
	b = builder
	data = b.data
	for i: int in range(8):
		b.colors["facade%d" % i] = Color.WHITE
	b.colors["landmark_stone"] = Color.WHITE
	b.colors["pavers"] = Color.WHITE
	var architecture: RefCounted = load("res://tools/recognizable_buildings.gd").new()
	architecture.prepare(b)

	# Fill narrow split-carriageway medians cleanly with road asphalt
	var sections: Array = data["sections"]
	for i: int in range(sections.size() - 1):
		var sa: Dictionary = sections[i]
		var sb: Dictionary = sections[i + 1]
		var xa: float = float(sa["x"])
		var xb: float = float(sb["x"])
		var ia: Array = sa["intervals"]
		var ib: Array = sb["intervals"]
		if ia.size() >= 2 and ib.size() >= 2:
			var gap_a_min: float = float(ia[0][1])
			var gap_a_max: float = float(ia[1][0])
			var gap_b_min: float = float(ib[0][1])
			var gap_b_max: float = float(ib[1][0])
			if gap_a_max - gap_a_min <= 4.5 and gap_b_max - gap_b_min <= 4.5:
				b._quad(
					Vector3(xa, 0.016, gap_a_min),
					Vector3(xb, 0.016, gap_b_min),
					Vector3(xb, 0.016, gap_b_max),
					Vector3(xa, 0.016, gap_a_max),
					"road",
					0.25
				)

	# 1. Full continuous asphalt coverage of all roads, avenues and side streets
	for road: Dictionary in data["roads"] + data["streets"]:
		if bool(road.get("bridge", false)):
			continue
		var r_pts: Array = road["points"]
		var r_w: float = float(road["width"])
		for i: int in range(r_pts.size() - 1):
			var ra: Vector3 = b._v(r_pts[i], 0.016)
			var rb: Vector3 = b._v(r_pts[i + 1], 0.016)
			b._strip(ra, rb, r_w, "road", 0.25)
	# Full asphalt coverage of all intersections and junctions from polygon triangulation
	for triangle: Array in data["pavement_triangles"]:
		_triangle(triangle, 0.016, "road")

	# 2. Continuous sidewalk network along all streets with vertical curbs
	for road: Dictionary in data["roads"] + data["streets"]:
		if bool(road.get("bridge", false)):
			continue
		var r_pts: Array = road["points"]
		var r_w: float = float(road["width"])
		var half_w: float = r_w * 0.5
		var sw_w: float = 3.5
		for i: int in range(r_pts.size() - 1):
			var ra: Vector3 = b._v(r_pts[i])
			var rb: Vector3 = b._v(r_pts[i + 1])
			var seg_len: float = ra.distance_to(rb)
			if seg_len < 0.5:
				continue
			var dir: Vector3 = (rb - ra).normalized()
			var right: Vector3 = dir.cross(Vector3.UP)
			for side: float in [-1.0, 1.0]:
				var curb_pos0: Vector3 = ra + right * (side * half_w)
				var curb_pos1: Vector3 = rb + right * (side * half_w)
				var sw_pos0: Vector3 = ra + right * (side * (half_w + sw_w * 0.5))
				var sw_pos1: Vector3 = rb + right * (side * (half_w + sw_w * 0.5))
				
				# Pull segment endpoints back if entering intersecting street carriageway
				var p0: Vector3 = sw_pos0
				var p1: Vector3 = sw_pos1
				var c0: Vector3 = curb_pos0
				var c1: Vector3 = curb_pos1
				var pull_amt: float = minf(seg_len * 0.35, half_w + 1.2)
				if b.map.get_road_distance(p0) < 0.6:
					p0 += dir * pull_amt
					c0 += dir * pull_amt
				if b.map.get_road_distance(p1) < 0.6:
					p1 -= dir * pull_amt
					c1 -= dir * pull_amt
				
				var mid_test: Vector3 = (p0 + p1) * 0.5
				if p0.distance_to(p1) >= 1.2 and b.map.get_road_distance(mid_test) > 1.2 and b.map.get_road_distance(p0) > 0.0 and b.map.get_road_distance(p1) > 0.0:
					if side > 0.0:
						b._quad(
							Vector3(c0.x, 0.016, c0.z),
							Vector3(c1.x, 0.016, c1.z),
							Vector3(c1.x, 0.17, c1.z),
							Vector3(c0.x, 0.17, c0.z),
							"curb",
							0.40
						)
					else:
						b._quad(
							Vector3(c1.x, 0.016, c1.z),
							Vector3(c0.x, 0.016, c0.z),
							Vector3(c0.x, 0.17, c0.z),
							Vector3(c1.x, 0.17, c1.z),
							"curb",
							0.40
						)
					b._strip(Vector3(p0.x, 0.17, p0.z), Vector3(p1.x, 0.17, p1.z), sw_w, "walk", 0.50)

	# Additional sidewalk triangles for plazas and corners outside road carriageways
	for triangle: Array in data["sidewalk_triangles"]:
		var tri_mid: Vector3 = (b._v(triangle[0]) + b._v(triangle[1]) + b._v(triangle[2])) / 3.0
		if b.map.get_road_distance(tri_mid) > 0.3:
			_triangle(triangle, 0.17, "walk")
	for road: Dictionary in data["roads"] + data["streets"]:
		if not bool(road.get("bridge", false)):
			_markings(road)
	for passage: Dictionary in data.get("open_passages", []):
		var points: Array = passage["points"]
		var p_width: float = float(passage["width"])
		for i: int in range(points.size() - 1):
			var pa: Vector3 = b._v(points[i], 0.0)
			var pb: Vector3 = b._v(points[i + 1], 0.0)
			var p_len: float = pa.distance_to(pb)
			var steps: int = maxi(1, ceili(p_len / 4.0))
			for s: int in range(steps):
				var s0: Vector3 = pa.lerp(pb, float(s) / float(steps))
				var s1: Vector3 = pa.lerp(pb, float(s + 1) / float(steps))
				var mid: Vector3 = (s0 + s1) * 0.5
				if b.map.get_road_distance(mid) > 2.0:
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
		var b_type: String = str(building.get("type", ""))
		var is_party_wall: bool = b_type == "generic_party_wall" or h <= 1.85
		var facade_mat: String = "facade_property_wall" if is_party_wall else ("facade_" + role if not role.is_empty() else "facade%d" % color_index)
		b._polygon(building["points"], h, facade_mat)
		if role.is_empty() and h > 2.2 and not is_party_wall and b_type != "generic_block_infill":
			var is_central: bool = building.has("central_corridor")
			if is_central:
				_building_roof_and_trim(building, bid)
				var c_fronts: Array = building.get("central_fronts", [])
				if not c_fronts.is_empty():
					for cf: Dictionary in c_fronts:
						_central_corridor_front(building, cf, bid)
				elif building.has("front"):
					_central_corridor_front(building, building["front"], bid)
			else:
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
	_bridges()
	_footbridges()
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
		if name.is_empty() or named.has(name) or bool(road.get("bridge", false)):
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
	b._polygon(pts, 0.015, "roof_terrace", h)
	var center: Vector3 = Vector3.ZERO
	for i: int in range(pts.size()):
		var a: Vector3 = b._v(pts[i], h)
		var c: Vector3 = b._v(pts[(i + 1) % pts.size()], h)
		center += a
		var d: float = a.distance_to(c)
		if d < 1.5:
			continue
		var yaw: float = -atan2((c - a).z, (c - a).x)
		b._box((a + c) * 0.5 + Vector3.UP * 0.16, Vector3(d, 0.32, 0.22), "trim_stone", yaw)
	center /= float(pts.size())
	if h >= 9.5 and pts.size() >= 4 and posmod(bid, 2) == 0:
		var poly2d: PackedVector2Array = PackedVector2Array()
		for pt: Array in pts:
			poly2d.append(Vector2(float(pt[0]), float(pt[1])))
		if Geometry2D.is_point_in_polygon(Vector2(center.x, center.z), poly2d):
			b._box(Vector3(center.x, h + 1.1, center.z), Vector3(2.4, 2.2, 2.4), "trim_stone")
			b._box(Vector3(center.x, h + 2.5, center.z), Vector3(1.5, 1.2, 1.5), "silver_metal")

func _central_corridor_front(building: Dictionary, front: Dictionary, bid: int) -> void:
	var a: Vector3 = b._v(front["a"])
	var c: Vector3 = b._v(front["b"])
	var toward: Vector3 = Vector3(float(front["normal"][0]), 0.0, float(front["normal"][1])).normalized() if front.has("normal") else b._v(front["towards"]).normalized()
	var middle: Vector3 = (a + c) * 0.5 + toward * 0.04
	var length: float = a.distance_to(c)
	if length < 3.2:
		return
	var tangent: Vector3 = (c - a).normalized()
	var yaw: float = atan2(toward.x, toward.z)
	var h: float = float(building["height"])
	var total_levels: int = maxi(2, floori(h / 3.1))

	# Ground-floor prominent commercial gallery & double-height storefronts
	var fascia_palette: Array[String] = ["brand_dark", "coto_blue", "awning_red", "perla_green", "cafe_wood", " awning_blue".strip_edges()]
	var accent_palette: Array[String] = ["brand_gold", "shop_white", "coto_yellow", "cafe_cream", "lamp_glow", "silver_metal"]
	var f_col: String = fascia_palette[posmod(bid, fascia_palette.size())]
	var a_col: String = accent_palette[posmod(bid * 3, accent_palette.size())]

	# Storefront granite/stone surround pilasters & illuminated shop window
	b._box(a + tangent * 0.25 + toward * 0.06 + Vector3.UP * 1.65, Vector3(0.45, 3.3, 0.14), "trim_stone", yaw)
	b._box(c - tangent * 0.25 + toward * 0.06 + Vector3.UP * 1.65, Vector3(0.45, 3.3, 0.14), "trim_stone", yaw)
	b._quad(
		a + tangent * 0.42 + toward * 0.05 + Vector3.UP * 0.20,
		c - tangent * 0.42 + toward * 0.05 + Vector3.UP * 0.20,
		c - tangent * 0.42 + toward * 0.05 + Vector3.UP * 2.75,
		a + tangent * 0.42 + toward * 0.05 + Vector3.UP * 2.75,
		"glass"
	)
	# Warm interior storefront light strip
	b._box(middle + toward * 0.03 + Vector3.UP * 2.65, Vector3(length - 1.0, 0.10, 0.08), "lamp_glow", yaw)
	# Commercial fascia marquee + cornice
	b._box(middle + toward * 0.12 + Vector3.UP * 3.05, Vector3(length - 0.1, 0.68, 0.20), f_col, yaw)
	b._box(middle + toward * 0.16 + Vector3.UP * 3.45, Vector3(length + 0.1, 0.18, 0.28), "trim_stone", yaw)

	# Projecting sloped shop awning
	var aw_half: Vector3 = tangent * (length * 0.46)
	b._quad(
		middle - aw_half + toward * 0.08 + Vector3.UP * 2.82,
		middle + aw_half + toward * 0.08 + Vector3.UP * 2.82,
		middle + aw_half + toward * 0.55 + Vector3.UP * 2.45,
		middle - aw_half + toward * 0.55 + Vector3.UP * 2.45,
		f_col if f_col in ["perla_green", "awning_red", "awning_blue"] else "awning_striped"
	)

	# Characteristic downtown vertical projecting blade sign (Cartel Banderola)
	if length >= 5.5:
		var blade_pos: Vector3 = a.lerp(c, 0.22 if posmod(bid, 2) == 0 else 0.78) + toward * 0.38 + Vector3.UP * 4.25
		b._box(blade_pos, Vector3(0.14, 1.85, 0.55), f_col, yaw)
		b._box(blade_pos, Vector3(0.18, 1.65, 0.42), a_col, yaw)

	# Upper floors: classical belt moldings, French windows & continuous apartment balconies
	var count: int = clampi(floori(length / 3.2), 1, 18)
	for level: int in range(1, total_levels):
		var y_center: float = 1.7 + float(level) * 3.1
		# Horizontal floor cornice band
		b._box(middle + toward * 0.06 + Vector3.UP * (y_center - 1.35), Vector3(length, 0.14, 0.18), "trim_stone", yaw)
		# Continuous balcony slab & railing on alternate or main residential levels
		if level <= 4 and (level + bid) % 2 == 1 and length >= 5.0:
			b._box(middle + toward * 0.25 + Vector3.UP * (y_center - 0.82), Vector3(length * 0.86, 0.12, 0.48), "trim_stone", yaw)
			b._box(middle + toward * 0.48 + Vector3.UP * (y_center - 0.34), Vector3(length * 0.86, 0.84, 0.05), "glass" if posmod(bid, 2) == 0 else "metal", yaw)
			b._box(middle + toward * 0.48 + Vector3.UP * (y_center + 0.10), Vector3(length * 0.87, 0.06, 0.08), "silver_metal", yaw)
		for column: int in range(count):
			var center: Vector3 = a.lerp(c, (float(column) + 0.5) / float(count)) + toward * 0.05 + Vector3.UP * y_center
			var w_half: float = minf(0.88, length / float(count) * 0.34)
			var half: Vector3 = tangent * w_half
			var w_lit_idx: int = posmod(bid * 7 + level * 5 + column * 3, 10)
			var w_mat: String = "window_warm" if w_lit_idx < 4 else ("window_lit" if w_lit_idx < 6 else ("window_cool" if w_lit_idx < 7 else "glass"))
			b._quad(center - half - Vector3.UP * 0.82, center + half - Vector3.UP * 0.82, center + half + Vector3.UP * 0.82, center - half + Vector3.UP * 0.82, w_mat)
			b._box(center + toward * 0.05 + Vector3.UP * 0.88, Vector3(w_half * 2.15, 0.12, 0.14), "trim_stone", yaw)

	if not str(building.get("name", "")).is_empty() and str(building["name"]).length() < 32:
		b._sign(middle + toward * 0.24 + Vector3.UP * 3.08, str(building["name"]).to_upper(), yaw)

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
	var pole_base: Vector3 = position + Vector3(-1.4, 0.0, 0.0)
	if b.map.get_road_distance(pole_base) < 0.8:
		return
	b._box(pole_base + Vector3(0, 2.75, 0), Vector3(0.14, 5.5, 0.14), "metal")
	b._box(pole_base + Vector3(0, 5.35, -side * 1.8), Vector3(0.10, 0.10, 3.6), "metal")
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
	var surface: SurfaceTool = b._batch_at(key, b._v(triangle[0], y))
	var v0: Vector3 = b._v(triangle[0], y)
	var v1: Vector3 = b._v(triangle[1], y)
	var v2: Vector3 = b._v(triangle[2], y)
	if (v1 - v0).cross(v2 - v0).y < 0.0:
		var tmp: Vector3 = v1
		v1 = v2
		v2 = tmp
	var uv_scale: float = 0.25 if key == "road" else (0.50 if key == "walk" else 0.40)
	for v: Vector3 in [v0, v1, v2]:
		surface.set_normal(Vector3.UP)
		surface.set_uv(Vector2(v.x, v.z) * uv_scale)
		surface.add_vertex(v)

func _markings(road: Dictionary) -> void:
	var points: Array = road["points"]
	var width: float = float(road["width"])
	var lanes: int = int(road["lanes"])
	if width < 7.0:
		return
	if lanes < 2:
		lanes = 2
	for i: int in range(points.size() - 1):
		var a: Vector3 = b._v(points[i], 0.024)
		var c: Vector3 = b._v(points[i + 1], 0.024)
		var direction: Vector3 = c - a
		var length: float = direction.length()
		if length < 0.5:
			continue
		var right: Vector3 = direction.normalized().cross(Vector3.UP)
		var is_oneway: bool = bool(road.get("oneway", false))
		if not is_oneway:
			for extra: float in [-0.12, 0.12]:
				b._strip(a + right * extra, c + right * extra, 0.12, "yellow")
		else:
			var driving_width: float = width - 1.6
			for lane: int in range(1, lanes):
				var offset: float = -driving_width * 0.5 + driving_width * float(lane) / float(lanes)
				var station: float = 0.0
				while station < length:
					b._strip(a.lerp(c, station / length) + right * offset, a.lerp(c, minf(station + 3.0, length) / length) + right * offset, 0.14, "line")
					station += 7.5

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
	var count: int = clampi(floori(length / 3.6), 1, 20)

	var has_storefront: bool = float(front["distance"]) < 36.0 and length >= 4.2
	if has_storefront:
		var awning_keys: Array[String] = ["perla_green", "awning_red", "awning_blue", "awning_striped"]
		var aw_key: String = awning_keys[posmod(bid, 4)]
		b._quad(
			a + tangent * 0.35 + toward * 0.045 + Vector3.UP * 0.25,
			c - tangent * 0.35 + toward * 0.045 + Vector3.UP * 0.25,
			c - tangent * 0.35 + toward * 0.045 + Vector3.UP * 2.55,
			a + tangent * 0.35 + toward * 0.045 + Vector3.UP * 2.55,
			"glass"
		)
		b._box(middle + toward * 0.08 + Vector3.UP * 2.85, Vector3(length - 0.2, 0.48, 0.14), aw_key, yaw)
		b._box(middle + toward * 0.10 + Vector3.UP * 3.18, Vector3(length, 0.16, 0.22), "trim_stone", yaw)
		if posmod(bid, 2) == 0 and length >= 5.0:
			var aw_half: Vector3 = tangent * (length * 0.46)
			b._quad(
				middle - aw_half + toward * 0.05 + Vector3.UP * 2.82,
				middle + aw_half + toward * 0.05 + Vector3.UP * 2.82,
				middle + aw_half + toward * 0.45 + Vector3.UP * 2.45,
				middle - aw_half + toward * 0.45 + Vector3.UP * 2.45,
				aw_key
			)

	var start_level: int = 1 if has_storefront and total_levels > 1 else 0
	for level: int in range(start_level, total_levels):
		var y_center: float = 1.6 + float(level) * 3.1
		for column: int in range(count):
			var center: Vector3 = a.lerp(c, (float(column) + 0.5) / float(count)) + toward * 0.045 + Vector3.UP * y_center
			var w_half: float = minf(0.85, length / float(count) * 0.32)
			var half: Vector3 = tangent * w_half
			var w_lit_idx: int = posmod(bid * 7 + level * 5 + column * 3, 10)
			var w_mat: String = "window_warm" if w_lit_idx < 4 else ("window_lit" if w_lit_idx < 6 else ("window_cool" if w_lit_idx < 7 else "glass"))
			b._quad(center - half - Vector3.UP * 0.72, center + half - Vector3.UP * 0.72, center + half + Vector3.UP * 0.72, center - half + Vector3.UP * 0.72, w_mat)
			b._box(center + toward * 0.04 - Vector3.UP * 0.76, Vector3(w_half * 2.1, 0.08, 0.12), "trim_stone", yaw)
			if h >= 9.0 and level >= 1 and (column + bid) % 2 == 0 and float(front["distance"]) < 32.0:
				b._box(center + toward * 0.22 - Vector3.UP * 0.78, Vector3(w_half * 2.3, 0.10, 0.42), "trim_stone", yaw)
				b._box(center + toward * 0.42 - Vector3.UP * 0.32, Vector3(w_half * 2.3, 0.82, 0.05), "glass", yaw)

	if not str(building["name"]).is_empty() and str(building["name"]).length() < 32 and float(front["distance"]) < 24.0:
		b._sign(middle + toward * 0.18 + Vector3.UP * 2.85, str(building["name"]), yaw)

func _railways() -> void:
	var signal_counter: int = 0
	for railway: Dictionary in data["railways"]:
		var points: Array = railway["points"]
		for i: int in range(points.size() - 1):
			var a: Vector3 = b._v(points[i], 0.08)
			var c: Vector3 = b._v(points[i + 1], 0.08)
			b._strip(a, c, 4.4, "ballast", 0.35)
			var dir: Vector3 = (c - a).normalized()
			var right: Vector3 = dir.cross(Vector3.UP)
			var length: float = a.distance_to(c)
			# Continuous timber sleepers (durmientes de quebracho) along the track
			var station: float = 0.0
			var step: float = 0.80
			while station < length:
				var sl_p: Vector3 = a.lerp(c, station / length) + Vector3.UP * 0.045
				b._strip(sl_p - right * 1.35, sl_p + right * 1.35, 0.28, "trunk", 0.40)
				# Metal tie-plates under both rails
				for s_side: float in [-0.838, 0.838]:
					var plate_p: Vector3 = sl_p + right * s_side + Vector3.UP * 0.015
					b._strip(plate_p - right * 0.11, plate_p + right * 0.11, 0.24, "metal", 0.8)
				station += step
			# Running rails (rieles de acero con cabeza brillante de trocha ancha 1.676m)
			for side: float in [-0.838, 0.838]:
				b._strip(a + right * side + Vector3.UP * 0.085, c + right * side + Vector3.UP * 0.085, 0.11, "rail", 0.45)
			# Electrified third rail (Tercer Riel FF.CC. Sarmiento con cubierta de seguridad amarilla)
			b._strip(a + right * 1.32 + Vector3.UP * 0.13, c + right * 1.32 + Vector3.UP * 0.13, 0.16, "yellow", 0.35)
			b._strip(a + right * 1.32 + Vector3.UP * 0.065, c + right * 1.32 + Vector3.UP * 0.065, 0.12, "metal", 0.35)
			signal_counter += 1
			if length > 25.0 and signal_counter % 16 == 0:
				var sig_p: Vector3 = a.lerp(c, 0.5) + right * 2.35
				b._box(sig_p + Vector3.UP * 1.8, Vector3(0.12, 3.6, 0.12), "metal")
				b._box(sig_p + Vector3.UP * 3.3, Vector3(0.28, 0.78, 0.42), "metal")
				b._box(sig_p + Vector3(0, 3.48, 0), Vector3(0.32, 0.18, 0.18), "traffic_green" if signal_counter % 32 == 0 else "traffic_red")
				b._box(sig_p + Vector3(0, 3.12, 0), Vector3(0.32, 0.18, 0.18), "traffic_yellow")

	# Continuous collidable railway perimeter masonry walls & iron fences (openings ONLY at level/pedestrian crossings)
	for wall_pts: Array in data.get("railway_walls", []):
		for i: int in range(wall_pts.size() - 1):
			var wa: Vector3 = b._v(wall_pts[i], 0.0)
			var wb: Vector3 = b._v(wall_pts[i + 1], 0.0)
			var w_len: float = wa.distance_to(wb)
			if w_len < 0.3:
				continue
			var mid: Vector3 = (wa + wb) * 0.5
			var yaw: float = -atan2((wb - wa).z, (wb - wa).x)
			# Solid masonry base wall + top coping + iron security fence rail
			b._box(mid + Vector3.UP * 0.45, Vector3(w_len + 0.04, 0.90, 0.24), "facade_property_wall", yaw)
			b._box(mid + Vector3.UP * 0.94, Vector3(w_len + 0.06, 0.08, 0.28), "trim_stone", yaw)
			b._box(mid + Vector3.UP * 1.48, Vector3(w_len, 0.07, 0.07), "metal", yaw)
			b._box(mid + Vector3.UP * 1.95, Vector3(w_len, 0.08, 0.08), "metal", yaw)
			if w_len > 3.0:
				var posts: int = maxi(1, floori(w_len / 4.5))
				for pi: int in range(posts + 1):
					var pp: Vector3 = wa.lerp(wb, float(pi) / float(posts))
					b._box(pp + Vector3.UP * 1.45, Vector3(0.14, 1.10, 0.14), "metal")
			# Impenetrable physics barrier quad (height 2.4m)
			b._collision_quad(wa, wb, wb + Vector3.UP * 2.4, wa + Vector3.UP * 2.4, "RailwayBarrierCollision")

	# Detailed vehicular level crossings (Pasos a Nivel) & pedestrian chicanes (Laberintos Peatonales)
	for rc: Dictionary in data.get("railway_crossings", []):
		var ca: Vector3 = b._v(rc["a"], 0.0)
		var cb: Vector3 = b._v(rc["b"], 0.0)
		var c_mid: Vector3 = (ca + cb) * 0.5
		var c_dir: Vector3 = (cb - ca).normalized()
		var c_right: Vector3 = c_dir.cross(Vector3.UP).normalized()
		var c_len: float = ca.distance_to(cb)
		var c_w: float = float(rc.get("width", 8.0))
		var c_yaw: float = -atan2(c_dir.z, c_dir.x)
		var kind: String = str(rc.get("kind", "vehicular"))

		if kind == "vehicular":
			# Concrete/asphalt level crossing track slab + yellow warning stripes
			b._strip(ca + Vector3.UP * 0.12, cb + Vector3.UP * 0.12, c_w, "road")
			b._strip(ca - c_right * (c_w * 0.48) + Vector3.UP * 0.13, cb - c_right * (c_w * 0.48) + Vector3.UP * 0.13, 0.22, "yellow")
			b._strip(ca + c_right * (c_w * 0.48) + Vector3.UP * 0.13, cb + c_right * (c_w * 0.48) + Vector3.UP * 0.13, 0.22, "yellow")
			# Automatic barrier mechanisms, raised red-and-white booms & St. Andrew's Cross (Cruz de San Andrés) on both ends
			for end_idx: int in [0, 1]:
				var ep: Vector3 = ca if end_idx == 0 else cb
				var side_s: float = -1.0 if end_idx == 0 else 1.0
				var post_pos: Vector3 = ep + c_right * (c_w * 0.5 + 1.15) * side_s
				# Barrier pedestal + raised diagonal boom arm (allows bikes/cars through while clearly marking the crossing)
				b._box(post_pos + Vector3.UP * 0.65, Vector3(0.48, 1.30, 0.48), "yellow")
				var arm_base: Vector3 = post_pos + Vector3.UP * 1.25
				var arm_tip: Vector3 = arm_base - c_right * side_s * 3.2 + Vector3.UP * 3.4
				for seg_i: int in range(5):
					var s0: Vector3 = arm_base.lerp(arm_tip, float(seg_i) / 5.0)
					var s1: Vector3 = arm_base.lerp(arm_tip, float(seg_i + 1) / 5.0)
					b._box((s0 + s1) * 0.5, Vector3(0.14, s0.distance_to(s1), 0.14), "coto_red" if seg_i % 2 == 0 else "line")
				# Cruz de San Andrés + twin flashing red lights
				var sign_p: Vector3 = ep - c_right * (c_w * 0.5 + 1.15) * side_s
				b._box(sign_p + Vector3.UP * 1.65, Vector3(0.10, 3.3, 0.10), "metal")
				b._box(sign_p + Vector3.UP * 2.85, Vector3(0.95, 0.16, 0.08), "line", c_yaw + 0.65)
				b._box(sign_p + Vector3.UP * 2.85, Vector3(0.95, 0.16, 0.08), "line", c_yaw - 0.65)
				b._box(sign_p + Vector3(-0.22, 2.35, 0), Vector3(0.18, 0.18, 0.18), "traffic_red")
				b._box(sign_p + Vector3(0.22, 2.35, 0), Vector3(0.18, 0.18, 0.18), "traffic_red")
			# Crossing keeper's cabin (Garita del Guardabarrera) & sign
			var booth_p: Vector3 = ca + c_right * (c_w * 0.5 + 2.6) - c_dir * 1.5
			b._box(booth_p + Vector3.UP * 1.35, Vector3(2.1, 2.7, 2.1), "station_brick")
			b._box(booth_p + Vector3.UP * 2.82, Vector3(2.35, 0.25, 2.35), "roof_zinc")
			b._sign(c_mid + Vector3.UP * 4.4, str(rc["name"]).to_upper(), atan2(c_dir.x, c_dir.z))
		else:
			# Pedestrian crossing pathway + yellow & black steel chicanes (laberinto peatonal)
			b._strip(ca + Vector3.UP * 0.13, cb + Vector3.UP * 0.13, c_w, "pavers")
			for end_pt: Vector3 in [ca, cb]:
				for rail_s: float in [-1.0, 1.0]:
					var chicane_p: Vector3 = end_pt + c_right * (rail_s * (c_w * 0.36))
					b._box(chicane_p + Vector3.UP * 0.55, Vector3(1.1, 1.1, 0.10), "yellow", c_yaw)
					b._box(chicane_p + Vector3.UP * 1.05, Vector3(1.12, 0.12, 0.12), "metal", c_yaw)

func _bridges() -> void:
	for br: Dictionary in data.get("bridges", []):
		var pts3: Array = br["points_3d"]
		var w: float = float(br.get("width", 7.0))
		var style: String = str(br.get("style", "vehicular_concrete"))
		var is_u: bool = style == "modular_u_bridge"
		var deck_mat: String = "curb" if is_u else "road"
		var side_mat: String = "train_blue" if is_u else "trim_stone"

		# Subdivide long spans for smooth vertical ramp transitions
		var smooth_pts: Array[Vector3] = []
		for i: int in range(pts3.size() - 1):
			var p0: Vector3 = Vector3(float(pts3[i][0]), float(pts3[i][1]), float(pts3[i][2]))
			var p1: Vector3 = Vector3(float(pts3[i + 1][0]), float(pts3[i + 1][1]), float(pts3[i + 1][2]))
			var dist_2d: float = Vector2(p0.x, p0.z).distance_to(Vector2(p1.x, p1.z))
			var steps: int = maxi(1, ceili(dist_2d / 8.0))
			for s: int in range(steps):
				var t: float = float(s) / float(steps)
				smooth_pts.append(p0.lerp(p1, t))
		var last_p: Array = pts3[-1]
		smooth_pts.append(Vector3(float(last_p[0]), float(last_p[1]), float(last_p[2])))

		# Compute mitered left/right rails at each vertex so curved U-bridges have zero gaps!
		var left_pts: Array[Vector3] = []
		var right_pts: Array[Vector3] = []
		var rights: Array[Vector3] = []
		for i: int in range(smooth_pts.size()):
			var prev_p: Vector3 = smooth_pts[maxi(0, i - 1)]
			var next_p: Vector3 = smooth_pts[mini(smooth_pts.size() - 1, i + 1)]
			var dir_2d: Vector3 = Vector3(next_p.x - prev_p.x, 0.0, next_p.z - prev_p.z).normalized()
			if dir_2d.length_squared() < 0.001:
				dir_2d = Vector3.RIGHT
			var r_vec: Vector3 = dir_2d.cross(Vector3.UP).normalized()
			rights.append(r_vec)
			left_pts.append(smooth_pts[i] - r_vec * (w * 0.5))
			right_pts.append(smooth_pts[i] + r_vec * (w * 0.5))

		for i: int in range(smooth_pts.size() - 1):
			var a: Vector3 = smooth_pts[i]
			var c: Vector3 = smooth_pts[i + 1]
			var la: Vector3 = left_pts[i]
			var lc: Vector3 = left_pts[i + 1]
			var ra: Vector3 = right_pts[i]
			var rc_pt: Vector3 = right_pts[i + 1]
			var r_mid: Vector3 = (rights[i] + rights[i + 1]).normalized()

			# 1. Visual top road deck & underside structural girder
			b._quad(la, lc, rc_pt, ra, deck_mat)
			b._quad(ra - Vector3.UP * 0.45, rc_pt - Vector3.UP * 0.45, lc - Vector3.UP * 0.45, la - Vector3.UP * 0.45, "metal" if is_u else "trim_stone")
			# Center yellow line or lane edge markings
			if not is_u:
				b._quad(a - r_mid * 0.12 + Vector3.UP * 0.02, c - r_mid * 0.12 + Vector3.UP * 0.02, c + r_mid * 0.12 + Vector3.UP * 0.02, a + r_mid * 0.12 + Vector3.UP * 0.02, "yellow")
			else:
				b._quad(la + r_mid * 0.25 + Vector3.UP * 0.02, lc + r_mid * 0.25 + Vector3.UP * 0.02, lc + r_mid * 0.40 + Vector3.UP * 0.02, la + r_mid * 0.40 + Vector3.UP * 0.02, "yellow")
				b._quad(ra - r_mid * 0.40 + Vector3.UP * 0.02, rc_pt - r_mid * 0.40 + Vector3.UP * 0.02, rc_pt - r_mid * 0.25 + Vector3.UP * 0.02, ra - r_mid * 0.25 + Vector3.UP * 0.02, "yellow")

			# 2. Exact physics collision for the bridge deck & side guardrails
			var mid: Vector3 = (a + c) * 0.5
			b._collision_quad(la, lc, rc_pt, ra, "BridgeCollision")
			if mid.y >= 0.2:
				b._collision_quad(la, lc, lc + Vector3.UP * 1.15, la + Vector3.UP * 1.15, "BridgeCollision")
				b._collision_quad(rc_pt, ra, ra + Vector3.UP * 1.15, rc_pt + Vector3.UP * 1.15, "BridgeCollision")

			# 3. Visual side parapets / barriers & railings
			if mid.y >= 0.15:
				for side_idx: int in [0, 1]:
					var sa: Vector3 = la if side_idx == 0 else ra
					var sc: Vector3 = lc if side_idx == 0 else rc_pt
					# Outer & inner side walls of bridge parapet (from -0.45m fascia up to +0.85m guardrail)
					b._quad(sa - Vector3.UP * 0.45, sc - Vector3.UP * 0.45, sc + Vector3.UP * 0.85, sa + Vector3.UP * 0.85, side_mat)
					b._quad(sc - Vector3.UP * 0.45, sa - Vector3.UP * 0.45, sa + Vector3.UP * 0.85, sc + Vector3.UP * 0.85, side_mat)
					# Top metallic guardrail bar
					var g_mid: Vector3 = (sa + sc) * 0.5 + Vector3.UP * 0.98
					var g_yaw: float = -atan2((sc - sa).z, (sc - sa).x)
					b._box(g_mid, Vector3(sa.distance_to(sc) + 0.05, 0.12, 0.18), "silver_metal", g_yaw)

			# 4. Support piers and bridge streetlights on elevated segments
			if mid.y > 1.8 and i % 3 == 1:
				for p_side: float in [-0.36, 0.36]:
					var pier_pos: Vector3 = Vector3(mid.x, 0.0, mid.z) + r_mid * (w * p_side)
					if b.map.get_road_distance(pier_pos) > -0.5 or mid.y < 4.5:
						b._box(pier_pos + Vector3.UP * (mid.y - 0.25) * 0.5, Vector3(0.75, mid.y - 0.25, 0.75), "metal" if is_u else "trim_stone")
			if i % 4 == 0 and mid.y > 0.8:
				var lp: Vector3 = la + Vector3.UP * 0.85
				b._box(lp + Vector3.UP * 2.1, Vector3(0.11, 4.2, 0.11), "metal")
				b._box(lp + Vector3.UP * 4.2 + r_mid * 0.6, Vector3(0.32, 0.12, 0.55), "lamp_glow")

		# Bridge name signs
		var start_p: Vector3 = smooth_pts[0]
		var start_r: Vector3 = rights[0]
		if is_u:
			b._sign(smooth_pts[int(smooth_pts.size() / 2)] + Vector3.UP * 4.2, str(br["name"]).to_upper(), PI * 0.5)
		else:
			b._sign(start_p + start_r * (w * 0.5 + 1.5) + Vector3.UP * 3.8, "PUENTE DÍAZ VÉLEZ\nAV. REPÚBLICA", PI * 0.25)
			b._sign(smooth_pts[int(smooth_pts.size() / 2)] + Vector3.UP * 4.5, "PUENTE DÍAZ VÉLEZ", PI * 0.25)

func _footbridges() -> void:
	for fb: Dictionary in data.get("footbridges", []):
		var pts3: Array = fb["points_3d"]
		var w: float = float(fb.get("width", 3.2))
		var v_pts: Array[Vector3] = []
		for pt: Array in pts3:
			v_pts.append(Vector3(float(pt[0]), float(pt[1]), float(pt[2])))

		var left_pts: Array[Vector3] = []
		var right_pts: Array[Vector3] = []
		var rights: Array[Vector3] = []
		for i: int in range(v_pts.size()):
			var prev_p: Vector3 = v_pts[maxi(0, i - 1)]
			var next_p: Vector3 = v_pts[mini(v_pts.size() - 1, i + 1)]
			var dir_2d: Vector3 = Vector3(next_p.x - prev_p.x, 0.0, next_p.z - prev_p.z).normalized()
			if dir_2d.length_squared() < 0.001:
				dir_2d = Vector3.FORWARD
			var r_vec: Vector3 = dir_2d.cross(Vector3.UP).normalized()
			rights.append(r_vec)
			left_pts.append(v_pts[i] - r_vec * (w * 0.5))
			right_pts.append(v_pts[i] + r_vec * (w * 0.5))

		for i: int in range(v_pts.size() - 1):
			var a: Vector3 = v_pts[i]
			var c: Vector3 = v_pts[i + 1]
			var la: Vector3 = left_pts[i]
			var lc: Vector3 = left_pts[i + 1]
			var ra: Vector3 = right_pts[i]
			var rc_pt: Vector3 = right_pts[i + 1]
			var seg_len: float = a.distance_to(c)
			var yaw: float = -atan2((c - a).z, (c - a).x)
			var mid: Vector3 = (a + c) * 0.5

			# Concrete footbridge floor & underside beam
			b._quad(la, lc, rc_pt, ra, "walk")
			b._quad(ra - Vector3.UP * 0.28, rc_pt - Vector3.UP * 0.28, lc - Vector3.UP * 0.28, la - Vector3.UP * 0.28, "trim_stone")
			b._collision_quad(la, lc, rc_pt, ra, "BridgeCollision")
			b._collision_quad(la, lc, lc + Vector3.UP * 1.3, la + Vector3.UP * 1.3, "BridgeCollision")
			b._collision_quad(rc_pt, ra, ra + Vector3.UP * 1.3, rc_pt + Vector3.UP * 1.3, "BridgeCollision")

			# Side protective walls / railings
			for side_idx: int in [0, 1]:
				var sa: Vector3 = la if side_idx == 0 else ra
				var sc: Vector3 = lc if side_idx == 0 else rc_pt
				b._quad(sa - Vector3.UP * 0.28, sc - Vector3.UP * 0.28, sc + Vector3.UP * 1.15, sa + Vector3.UP * 1.15, "coto_blue")
				b._quad(sc - Vector3.UP * 0.28, sa - Vector3.UP * 0.28, sa + Vector3.UP * 1.15, sc + Vector3.UP * 1.15, "coto_blue")
				# Upper protective cage bars on elevated span
				if a.y >= 4.5 and c.y >= 4.5:
					var smid: Vector3 = (sa + sc) * 0.5
					b._box(smid + Vector3.UP * 1.85, Vector3(seg_len, 0.08, 0.08), "silver_metal", yaw)
					b._box(smid + Vector3.UP * 2.45, Vector3(seg_len, 0.10, 0.10), "metal", yaw)
					var posts: int = maxi(1, floori(seg_len / 2.5))
					for pi: int in range(posts + 1):
						var pp: Vector3 = sa.lerp(sc, float(pi) / float(posts))
						b._box(pp + Vector3.UP * 1.8, Vector3(0.08, 1.4, 0.08), "metal")

			# Covered zinc roof & ceiling lights on elevated span (Puente Pepino Tuccio is roofed)
			if a.y >= 4.5 and c.y >= 4.5:
				b._quad(la + Vector3.UP * 2.55, lc + Vector3.UP * 2.55, rc_pt + Vector3.UP * 2.55, ra + Vector3.UP * 2.55, "roof_zinc")
				b._quad(ra + Vector3.UP * 2.52, rc_pt + Vector3.UP * 2.52, lc + Vector3.UP * 2.52, la + Vector3.UP * 2.52, "roof_zinc")
				b._box(mid + Vector3.UP * 2.46, Vector3(seg_len * 0.7, 0.06, 0.25), "lamp_glow", yaw)

			# Support column at vertex
			if a.y >= 1.2:
				b._box(Vector3(a.x, a.y * 0.5, a.z), Vector3(0.55, a.y, 0.55), "trim_stone")

		b._sign(v_pts[4] + Vector3.UP * 3.3, "PUENTE PEATONAL PEPINO TUCCIO\nRIVADAVIA Y MORENO ↔ FRENCH Y ARDOINO", 0.0)
		b._sign(v_pts[-2] + Vector3.UP * 3.2, "PUENTE PEATONAL\nMORENO ↔ FRENCH", 0.0)
		b._sign(v_pts[1] + Vector3.UP * 3.2, "PUENTE PEATONAL\nFRENCH ↔ MORENO", PI)

func _tanga() -> void:
	var tanga: Dictionary = data["tanga"]
	b._polygon(tanga["plaza_points"], 0.22, "pavers")
	b._polygon(tanga["points"], 0.26, "grass")
	var p_pts: Array = tanga["plaza_points"]
	for i: int in range(p_pts.size()):
		var a: Vector3 = b._v(p_pts[i])
		var c: Vector3 = b._v(p_pts[(i + 1) % p_pts.size()])
		b._quad(a, c, c + Vector3.UP * 0.22, a + Vector3.UP * 0.22, "curb")

	var center: Vector3 = Vector3.ZERO
	for p: Array in tanga["points"]:
		center += b._v(p)
	center /= float(tanga["points"].size())

	b._box(center + Vector3(0, 0.62, 0), Vector3(8.5, 0.82, 0.72), "landmark_stone")
	b._box(center + Vector3(0, 1.06, 0), Vector3(8.8, 0.10, 0.86), "trim_stone")
	b._box(center + Vector3(0, 1.58, 0.22), Vector3(8.4, 0.95, 0.14), "metal")
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

	for fx: float in [-3.0, -1.5, 0.0, 1.5, 3.0]:
		b._box(center + Vector3(fx, 0.34, 0.72), Vector3(0.95, 0.18, 0.45), "grass")
		b._box(center + Vector3(fx, 0.45, 0.72), Vector3(0.75, 0.10, 0.32), "flower_red" if int(absf(fx * 2.0)) % 2 == 0 else "flower_yellow")

	for side: float in [-1.0, 1.0]:
		var bp: Vector3 = center + Vector3(side * 4.2, 0.0, 1.45)
		b._box(bp + Vector3(0, 0.54, 0), Vector3(1.85, 0.08, 0.48), "trunk")
		b._box(bp + Vector3(0, 0.82, -0.20), Vector3(1.85, 0.42, 0.07), "trunk")
		for lx: float in [-0.75, 0.75]:
			b._box(bp + Vector3(lx, 0.38, 0), Vector3(0.10, 0.55, 0.46), "metal")

	for offset: float in [-5.4, 5.4]:
		var lp: Vector3 = center + Vector3(offset, 0.0, 0.0)
		b._box(lp + Vector3(0, 2.8, 0), Vector3(0.11, 5.2, 0.11), "metal")
		b._box(lp + Vector3(0, 5.25, 0), Vector3(1.3, 0.09, 0.09), "metal")
		for arm_x: float in [-0.58, 0.58]:
			b._box(lp + Vector3(arm_x, 5.42, 0), Vector3(0.28, 0.32, 0.28), "lamp_glow")

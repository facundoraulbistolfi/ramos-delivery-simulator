extends RefCounted
## Detailed mesh architecture for San Juan de Dios, Coto, La Perla, and Estación Ramos Mejía.
var b: SceneTree
var sites: Dictionary = {}
var buildings: Dictionary = {}

func prepare(builder: SceneTree) -> void:
	b = builder
	for site: Dictionary in b.data["recognizable_buildings"]:
		sites[site["key"]] = site
	for building: Dictionary in b.data["buildings"]:
		buildings[int(building["osm_id"])] = building
	var palette: Dictionary = {
		"facade_san_juan": Color("e8e6de"),
		"facade_coto": Color("e6e4d8"),
		"facade_la_perla": Color("ece4d5"),
		"hospital_glass": Color.WHITE,
		"hospital_blue": Color("224b73"),
		"hospital_drive": Color("484e52"),
		"hospital_hedge": Color("527848"),
		"hospital_red": Color("d42622"),
		"coto_red": Color("df1b20"),
		"coto_blue": Color("1b3f6b"),
		"coto_yellow": Color("f0c424"),
		"shop_white": Color("e8e5dc"),
		"perla_green": Color.WHITE,
		"perla_glass": Color.WHITE,
		"cafe_wood": Color("6e4a35"),
		"cafe_cream": Color("f2e4be"),
		"palm_leaf": Color.WHITE,
		"palm_trunk": Color.WHITE,
		"brand_dark": Color("1a1d21"),
		"brand_gold": Color("e5b842"),
		"brand_pink": Color("e87a90"),
		"brand_orange": Color("e86a24"),
		"brand_purple": Color("7a288a"),
		"bronze_statue": Color("5c4d3c")
	}
	for key: String in palette:
		b.colors[key] = palette[key]

func generate() -> void:
	_hospital()
	_coto()
	_perla()
	_estacion_sarmiento()
	_featured_places()
	_detailed_plazas()
	_el_muro_de_ramos()

func _frame(front: Dictionary) -> Transform3D:
	var a: Vector3 = b._v(front["a"])
	var c: Vector3 = b._v(front["b"])
	var normal: Vector3 = b._v(front["normal"]).normalized()
	return Transform3D(Basis(Vector3.UP.cross(normal), Vector3.UP, normal), (a + c) * 0.5)

func _box(frame: Transform3D, center: Vector3, size: Vector3, key: String) -> void:
	b._box(frame * center, size, key, atan2(frame.basis.z.x, frame.basis.z.z))

func _text(frame: Transform3D, position: Vector3, caption: String, height: float, key: String, serif: bool = false, emissive: bool = false) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = "Sign_" + caption.validate_node_name()
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visibility_range_end = 165.0
	instance.visibility_range_end_margin = 15.0
	instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	var mesh: TextMesh = TextMesh.new()
	mesh.text = caption
	mesh.font_size = 100
	mesh.pixel_size = height / 100.0
	mesh.depth = 0.055
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Georgia"] if serif else ["Arial"])
	font.font_weight = 700
	mesh.font = font
	instance.mesh = mesh
	instance.transform = Transform3D(frame.basis, frame * position)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = b.colors[key]
	material.roughness = 0.35
	if emissive:
		material.emission_enabled = true
		material.emission = b.colors[key]
		material.emission_energy_multiplier = 0.35
	instance.material_override = material
	b.map.add_child(instance)

func _edges(building: Dictionary) -> Array:
	var points: Array = building["points"]
	var polygon: PackedVector2Array = PackedVector2Array()
	for p: Array in points:
		polygon.append(Vector2(float(p[0]), float(p[1])))
	var result: Array = []
	for i: int in range(points.size()):
		var a: Vector2 = polygon[i]
		var c: Vector2 = polygon[(i + 1) % polygon.size()]
		var tangent: Vector2 = (c - a).normalized()
		var normal: Vector2 = Vector2(-tangent.y, tangent.x)
		if Geometry2D.is_point_in_polygon((a + c) * 0.5 + normal * 0.1, polygon):
			normal = -normal
		result.append({"a": [a.x, a.y], "b": [c.x, c.y], "normal": [normal.x, normal.y], "width": a.distance_to(c)})
	return result

func _hospital() -> void:
	var site: Dictionary = sites["san_juan"]
	b._polygon(site["campus_points"], 0.03, "grass")
	for id_value: float in site["building_ids"]:
		var building: Dictionary = buildings[int(id_value)]
		var h: float = float(building["height"])
		for edge: Dictionary in _edges(building):
			var width: float = float(edge["width"])
			if width < 4.0:
				continue
			var frame: Transform3D = _frame(edge)
			# Roof parapet coping band
			_box(frame, Vector3(0, h + 0.15, 0.05), Vector3(width + 0.15, 0.30, 0.22), "shop_white")
			var level: float = 1.9
			while level < h - 0.5:
				_box(frame, Vector3(0, level, 0.05), Vector3(width - 0.65, 1.22, 0.07), "hospital_glass")
				_box(frame, Vector3(0, level - 0.64, 0.09), Vector3(width - 0.55, 0.08, 0.12), "trim_stone")
				for x: int in range(1, floori(width / 1.7)):
					_box(frame, Vector3(-width * 0.5 + float(x) * 1.7, level, 0.10), Vector3(0.08, 1.26, 0.07), "shop_white")
				level += 3.1

	# Fifth-storey stepped-back architectural core + mechanical roof housing
	b._box(Vector3(-496.5, 14.45, -118.0), Vector3(18.4, 4.2, 14.4), "facade_san_juan")
	b._box(Vector3(-496.5, 16.65, -118.0), Vector3(18.8, 0.25, 14.8), "shop_white")
	b._box(Vector3(-496.5, 17.5, -119.5), Vector3(6.5, 1.6, 5.5), "trim_stone")
	for x: float in [-503.0, -499.5, -496.0, -492.5, -489.0]:
		b._box(Vector3(x, 14.55, -110.75), Vector3(1.85, 1.35, 0.09), "hospital_glass")

	var entry: Transform3D = _frame(site["front"])
	var width: float = float(site["front"]["width"])
	# Ground floor Guardia glazing & entrance doors
	_box(entry, Vector3(0, 1.65, 0.14), Vector3(width - 0.8, 2.85, 0.12), "hospital_glass")
	# Projecting Guardia canopy with white fascia, blue trim, and recessed ceiling lights
	_box(entry, Vector3(0, 3.28, 1.25), Vector3(width + 2.4, 0.42, 3.0), "shop_white")
	_box(entry, Vector3(0, 3.05, 2.72), Vector3(width + 2.45, 0.08, 0.10), "hospital_blue")
	for lx: float in [-width * 0.35, 0.0, width * 0.35]:
		_box(entry, Vector3(lx, 3.04, 1.35), Vector3(0.55, 0.04, 0.55), "lamp_glow")
		_cylinder(entry * Vector3(lx * 1.35, 1.55, 2.45), 0.12, 3.1, "silver_metal")

	# Guardia sign & illuminated medical cross
	_box(entry, Vector3(0.4, 3.85, 2.66), Vector3(6.2, 0.95, 0.10), "shop_white")
	_text(entry, Vector3(1.0, 3.85, 2.73), "GUARDIA", 0.82, "hospital_blue", false, true)
	_box(entry, Vector3(-2.1, 3.85, 2.73), Vector3(0.76, 0.24, 0.12), "hospital_red")
	_box(entry, Vector3(-2.1, 3.85, 2.73), Vector3(0.24, 0.76, 0.12), "hospital_red")

	# Upper institutional lettering on clean backing band (no double shadow)
	_box(entry, Vector3(0, 8.65, 0.10), Vector3(width - 0.4, 2.1, 0.08), "shop_white")
	_text(entry, Vector3(0, 9.15, 0.17), "HOSPITAL SAN JUAN DE DIOS", 0.60, "hospital_blue")
	_text(entry, Vector3(0, 8.12, 0.17), "CASA HOSPITAL", 0.36, "hospital_blue")

	# Forecourt driveway, parking bays & pedestrian crosswalk
	b._box(Vector3(-579, 0.04, -75), Vector3(42, 0.05, 19), "hospital_drive")
	for x: int in range(-596, -562, 3):
		b._box(Vector3(x, 0.075, -76), Vector3(0.11, 0.015, 5.0), "line")
	for zp: float in [-79.5, -77.5, -75.5, -73.5]:
		b._box(Vector3(-559.5, 0.075, zp), Vector3(1.8, 0.015, 0.45), "line")

	for position: Vector3 in [Vector3(-540, 0, -72), Vector3(-516, 0, -73), Vector3(-478, 0, -74)]:
		_palm(position)

	# Low stone planter curbs + trimmed hedges & red flowerbeds (matching reference photo)
	for position: Vector3 in [Vector3(-573, 0.0, -65.7), Vector3(-550, 0.0, -66.0)]:
		b._box(position + Vector3(0, 0.16, 0), Vector3(13.4, 0.32, 1.75), "landmark_stone")
		b._box(position + Vector3(0, 0.44, 0), Vector3(12.8, 0.36, 1.35), "hospital_hedge")
		for fx: float in [-4.5, -1.5, 1.5, 4.5]:
			b._box(position + Vector3(fx, 0.65, 0), Vector3(0.55, 0.14, 0.55), "flower_red")

	var marker: Transform3D = Transform3D(Basis.IDENTITY, Vector3(-521, 0, -67))
	_box(marker, Vector3(0, 0.85, 0), Vector3(4.2, 1.7, 0.52), "landmark_stone")
	_box(marker, Vector3(0, 1.75, 0), Vector3(4.5, 0.12, 0.64), "trim_stone")
	_box(marker, Vector3(0, 1.0, 0.27), Vector3(3.6, 0.85, 0.06), "shop_white")
	_text(marker, Vector3(0, 1.0, 0.32), "SAN JUAN DE DIOS", 0.29, "hospital_blue")

func _coto() -> void:
	var site: Dictionary = sites["coto"]
	for front: Dictionary in [site["front"], site["side"]]:
		var frame: Transform3D = _frame(front)
		var width: float = float(front["width"])
		# Tall corporate white & red supermarket fascia
		_box(frame, Vector3(0, 4.95, 0.10), Vector3(width + 0.1, 1.95, 0.16), "shop_white")
		_box(frame, Vector3(0, 5.98, 0.16), Vector3(width + 0.2, 0.24, 0.24), "coto_red")
		_box(frame, Vector3(0, 3.88, 0.18), Vector3(width + 0.2, 0.44, 0.26), "coto_blue")
		_box(frame, Vector3(0, 3.58, 0.20), Vector3(width + 0.2, 0.12, 0.28), "coto_yellow")
		# Illuminated interior ceiling visible through ground-floor storefront glass
		_box(frame, Vector3(0, 2.85, 0.02), Vector3(width - 1.2, 0.12, 0.06), "lamp_glow")
		_box(frame, Vector3(0, 1.80, 0.07), Vector3(width - 0.5, 3.05, 0.10), "glass")
		_text(frame, Vector3(-width * 0.18, 4.98, 0.22), "COTO", 1.75, "coto_red", false, true)
		_text(frame, Vector3(width * 0.15, 4.72, 0.22), "Yo te conozco", 0.46, "coto_red")
		for x: int in range(1, floori(width / 3.0)):
			_box(frame, Vector3(-width * 0.5 + float(x) * 3.0, 1.85, 0.16), Vector3(0.14, 3.15, 0.16), "silver_metal")
		_box(frame, Vector3(0, 6.32, -0.18), Vector3(width + 0.4, 0.30, 0.85), "shop_white")

	# Main Rivadavia entrance portal (matching Coto reference photo)
	var main: Transform3D = _frame(site["front"])
	_box(main, Vector3(-18, 1.65, 0.24), Vector3(6.2, 3.2, 0.20), "silver_metal")
	_box(main, Vector3(-18, 2.95, 0.36), Vector3(5.8, 0.55, 0.22), "coto_blue")
	_box(main, Vector3(-18, 1.40, 0.34), Vector3(4.8, 2.55, 0.12), "glass")
	_text(main, Vector3(-18, 2.96, 0.49), "COTO · ENTRADA", 0.36, "coto_yellow", false, true)

	var side_frame: Transform3D = _frame(site["side"])
	_box(side_frame, Vector3(7.5, 2.98, 0.28), Vector3(5.2, 0.52, 0.16), "coto_red")
	_text(side_frame, Vector3(7.5, 2.98, 0.38), "ESTACIONAMIENTO", 0.34, "shop_white", false, true)

	for p: Vector3 in [Vector3(-1145, 6.85, 64), Vector3(-1128, 6.85, 64)]:
		b._box(p, Vector3(5.2, 1.4, 3.4), "silver_metal")
		b._box(p + Vector3(0, 0.75, 0), Vector3(4.4, 0.15, 2.6), "metal")

func _perla() -> void:
	var site: Dictionary = sites["la_perla"]
	for front: Dictionary in site["fronts"]:
		var frame: Transform3D = _frame(front)
		var width: float = float(front["width"])
		# Ground floor pizzeria & cafe glazing + warm interior lighting + black & white counter band
		_box(frame, Vector3(0, 2.65, 0.02), Vector3(width - 0.6, 0.10, 0.05), "lamp_glow")
		_box(frame, Vector3(0, 0.65, 0.03), Vector3(width - 0.5, 0.85, 0.06), "shop_white")
		_box(frame, Vector3(0, 1.55, 0.07), Vector3(width - 0.2, 2.70, 0.12), "perla_glass")
		for x: int in range(0, maxi(2, floori(width / 1.8)) + 1):
			var px: float = clampf(-width * 0.5 + float(x) * 1.8, -width * 0.5 + 0.08, width * 0.5 - 0.08)
			_box(frame, Vector3(px, 1.55, 0.15), Vector3(0.11, 2.75, 0.14), "perla_green")

		# Sloping green canvas awning + valance & cream piping
		b._quad(
			frame * Vector3(-width * 0.5, 3.55, -0.04),
			frame * Vector3(width * 0.5, 3.55, -0.04),
			frame * Vector3(width * 0.5, 3.05, 1.32),
			frame * Vector3(-width * 0.5, 3.05, 1.32),
			"perla_green"
		)
		_box(frame, Vector3(0, 2.92, 1.32), Vector3(width + 0.06, 0.42, 0.12), "perla_green")
		_box(frame, Vector3(0, 2.70, 1.34), Vector3(width + 0.08, 0.07, 0.14), "cafe_cream")
		_text(frame, Vector3(0, 2.96, 1.40), "LA PERLA", 0.50 if width < 7.0 else 0.68, "cafe_cream", true, true)

		# Classical horizontal belt cornice & roof cornice
		_box(frame, Vector3(0, 3.72, 0.10), Vector3(width + 0.25, 0.22, 0.35), "trim_stone")
		_box(frame, Vector3(0, 6.32, 0.12), Vector3(width + 0.35, 0.30, 0.58), "trim_stone")

		# Upper floor French windows with wrought-iron balconies
		var win_positions: Array = [0.0] if width < 6.5 else [-width * 0.26, width * 0.26]
		for wx: float in win_positions:
			_box(frame, Vector3(wx, 4.95, 0.06), Vector3(1.48, 1.55, 0.10), "glass")
			_box(frame, Vector3(wx, 4.12, 0.22), Vector3(1.72, 0.12, 0.42), "trim_stone")
			_box(frame, Vector3(wx, 4.52, 0.38), Vector3(1.66, 0.68, 0.05), "metal")

		if width > 8.0:
			# Wooden sidewalk dining deck (deck gastronómico) + tables & umbrellas
			_box(frame, Vector3(0, 0.19, 1.92), Vector3(width * 0.76, 0.06, 1.55), "cafe_wood")
			for x: float in [-width * 0.25, width * 0.25]:
				_table(frame * Vector3(x, 0.04, 1.92), frame.basis, true)

func _table(position: Vector3, orientation: Basis, with_umbrella: bool = false) -> void:
	_cylinder(position + Vector3.UP * 0.76, 0.48, 0.07, "cafe_wood")
	_cylinder(position + Vector3.UP * 0.38, 0.055, 0.74, "metal")
	if with_umbrella:
		_cylinder(position + Vector3.UP * 1.45, 0.035, 1.4, "metal")
		_cylinder(position + Vector3.UP * 2.15, 1.05, 0.18, "perla_green")
	for side: float in [-1.0, 1.0]:
		var chair: Vector3 = position + orientation.x * side * 0.74
		b._box(chair + Vector3.UP * 0.44, Vector3(0.38, 0.08, 0.38), "cafe_wood")
		b._box(chair + orientation.x * side * 0.14 + Vector3.UP * 0.72, Vector3(0.09, 0.46, 0.38), "cafe_wood", atan2(orientation.z.x, orientation.z.z))
		for x: float in [-0.13, 0.13]:
			for z: float in [-0.13, 0.13]:
				b._box(chair + orientation * Vector3(x, 0.21, z), Vector3(0.04, 0.42, 0.04), "metal")

func _estacion_sarmiento() -> void:
	# Build Estación Ramos Mejía architecture & Tren Sarmiento on the mapped station/platform corridor
	var track_dir: Vector3 = Vector3(-0.996, 0.0, 0.088).normalized()
	var track_right: Vector3 = track_dir.cross(Vector3.UP).normalized()
	var station_basis: Basis = Basis(-track_dir, Vector3.UP, track_right)
	var station_center: Vector3 = Vector3(-1350.3, 0.65, 54.8)
	var st_frame: Transform3D = Transform3D(station_basis, station_center)

	# Historic Victorian brick station building on central platform
	_box(st_frame, Vector3(0, 2.2, 0), Vector3(26.0, 4.4, 6.2), "station_brick")
	_box(st_frame, Vector3(0, 4.5, 0), Vector3(26.6, 0.28, 6.6), "trim_stone")
	_box(st_frame, Vector3(0, 5.1, 0), Vector3(27.2, 0.95, 7.2), "roof_zinc")
	_box(st_frame, Vector3(0, 5.75, 0), Vector3(10.0, 0.75, 6.8), "station_brick")
	_box(st_frame, Vector3(0, 6.25, 0), Vector3(10.6, 0.35, 7.4), "roof_zinc")

	# Windows, doors & station canopies along both sides of the station building
	for side_z: float in [-1.0, 1.0]:
		_box(st_frame, Vector3(0, 3.35, side_z * 4.2), Vector3(38.0, 0.18, 2.6), "roof_zinc")
		_box(st_frame, Vector3(0, 3.18, side_z * 4.2), Vector3(37.0, 0.06, 0.4), "lamp_glow")
		for wx: float in [-10.0, -6.5, -3.0, 0.0, 3.0, 6.5, 10.0]:
			_box(st_frame, Vector3(wx, 1.85, side_z * 3.12), Vector3(1.5, 2.4, 0.10), "glass")
			_box(st_frame, Vector3(wx, 3.12, side_z * 3.14), Vector3(1.68, 0.18, 0.14), "trim_stone")
		for cx: float in [-16.0, -8.0, 8.0, 16.0]:
			_box(st_frame, Vector3(cx, 1.65, side_z * 4.8), Vector3(0.16, 3.3, 0.16), "metal")
		# Station nameboards ("RAMOS MEJÍA")
		var sign_f: Transform3D = Transform3D(station_basis if side_z > 0 else station_basis.rotated(Vector3.UP, PI), st_frame * Vector3(-14.0, 2.2, side_z * 4.6))
		_box(sign_f, Vector3(0, 0, 0), Vector3(3.4, 0.72, 0.10), "coto_blue")
		_box(sign_f, Vector3(0, -0.28, 0.02), Vector3(3.4, 0.12, 0.11), "train_blue")
		_text(sign_f, Vector3(0, 0.05, 0.07), "RAMOS MEJÍA", 0.32, "shop_white", false, true)

	# Yellow safety edge strips along mapped platforms
	for landmark: Dictionary in b.data["landmarks"]:
		if landmark["type"] != "platform":
			continue
		var pts: Array = landmark["points"]
		for i: int in range(pts.size()):
			var a: Vector3 = b._v(pts[i], 0.665)
			var c: Vector3 = b._v(pts[(i + 1) % pts.size()], 0.665)
			if a.distance_to(c) > 4.0:
				b._strip(a, c, 0.22, "yellow")

	# Tren Eléctrico Línea Sarmiento (3-car EMU formation alongside northern platform)
	var train_origin: Vector3 = station_center + track_right * -6.4 + Vector3(0, -0.42, 0)
	var tr_frame: Transform3D = Transform3D(station_basis, train_origin)
	for car_idx: int in range(-1, 2):
		var cx: float = float(car_idx) * 21.2
		# Lower bogies & chassis
		_box(tr_frame, Vector3(cx - 6.8, 0.45, 0), Vector3(3.2, 0.65, 2.6), "metal")
		_box(tr_frame, Vector3(cx + 6.8, 0.45, 0), Vector3(3.2, 0.65, 2.6), "metal")
		# Car body: white upper & celeste-blue lower band
		_box(tr_frame, Vector3(cx, 1.35, 0), Vector3(20.2, 1.15, 2.95), "train_blue")
		_box(tr_frame, Vector3(cx, 2.55, 0), Vector3(20.2, 1.35, 2.95), "train_white")
		_box(tr_frame, Vector3(cx, 3.32, 0), Vector3(19.8, 0.25, 2.65), "silver_metal")
		# Continuous tinted window band & doors on both sides
		for sz: float in [-1.49, 1.49]:
			_box(tr_frame, Vector3(cx, 2.42, sz), Vector3(18.6, 0.82, 0.05), "glass")
			for dx: float in [-6.2, 0.0, 6.2]:
				_box(tr_frame, Vector3(cx + dx, 1.85, sz * 1.01), Vector3(1.35, 2.05, 0.06), "silver_metal")
				_box(tr_frame, Vector3(cx + dx, 2.25, sz * 1.02), Vector3(1.05, 0.95, 0.06), "glass")
		# Roof AC unit & pantograph on middle car
		_box(tr_frame, Vector3(cx, 3.55, 0), Vector3(4.5, 0.28, 1.8), "silver_metal")
		if car_idx == 0:
			_box(tr_frame, Vector3(cx, 3.95, 0), Vector3(2.2, 0.55, 1.6), "metal")
	# Train front/rear windshields & LED headlights
	for end_sign: float in [-1.0, 1.0]:
		var ex: float = end_sign * 31.4
		_box(tr_frame, Vector3(ex, 2.45, 0), Vector3(0.12, 0.95, 2.35), "glass")
		_box(tr_frame, Vector3(ex, 1.35, -0.95), Vector3(0.14, 0.24, 0.36), "lamp_glow")
		_box(tr_frame, Vector3(ex, 1.35, 0.95), Vector3(0.14, 0.24, 0.36), "lamp_glow")

func _cylinder(center: Vector3, radius: float, height: float, key: String) -> void:
	var surface: SurfaceTool = b._batch(key)
	for i: int in range(12):
		var a: Vector3 = Vector3(cos(TAU * float(i) / 12.0) * radius, 0, sin(TAU * float(i) / 12.0) * radius)
		var c: Vector3 = Vector3(cos(TAU * float(i + 1) / 12.0) * radius, 0, sin(TAU * float(i + 1) / 12.0) * radius)
		b._quad(center + a - Vector3.UP * height * 0.5, center + c - Vector3.UP * height * 0.5, center + c + Vector3.UP * height * 0.5, center + a + Vector3.UP * height * 0.5, key)
		for p: Vector3 in [center + Vector3.UP * height * 0.5, center + a + Vector3.UP * height * 0.5, center + c + Vector3.UP * height * 0.5]:
			surface.set_normal(Vector3.UP)
			surface.set_uv(Vector2(p.x, p.z) * 0.5)
			surface.add_vertex(p)

func _palm(position: Vector3) -> void:
	# Segmented, slightly curved Washingtonia/Pindó palm trunk + lush arching fronds
	var segments: int = 7
	var seg_h: float = 1.05
	var top: Vector3 = position
	for s: int in range(segments):
		var r: float = lerpf(0.30, 0.19, float(s) / float(segments))
		var curve_x: float = sin(float(s) * 0.35) * 0.18
		var seg_center: Vector3 = position + Vector3(curve_x, (float(s) + 0.5) * seg_h, 0.0)
		_cylinder(seg_center, r, seg_h + 0.05, "palm_trunk")
		top = position + Vector3(curve_x, float(s + 1) * seg_h, 0.0)
	_cylinder(top, 0.26, 0.45, "palm_leaf")
	for i: int in range(14):
		var angle: float = TAU * float(i) / 14.0
		var tier: float = 0.35 if i % 2 == 0 else -0.15
		var direction: Vector3 = Vector3(cos(angle), 0, sin(angle))
		var side: Vector3 = direction.cross(Vector3.UP) * 0.42
		var mid1: Vector3 = top + direction * 1.45 + Vector3.UP * (0.95 + tier)
		var mid2: Vector3 = top + direction * 2.65 + Vector3.UP * (0.25 + tier)
		var end: Vector3 = top + direction * 3.65 - Vector3.UP * (1.15 - tier * 0.5)
		b._quad(top, mid1 - side, mid2 + side * 0.7, mid1 + side, "palm_leaf")
		b._quad(mid1 - side * 0.8, end, mid2 + side * 0.5, mid1 + side * 0.8, "palm_leaf")

func _featured_places() -> void:
	for place: Dictionary in b.data.get("featured_places", []):
		var front: Dictionary = place["front"]
		var frame: Transform3D = _frame(front)
		var width: float = clampf(float(front["width"]), 6.0, 14.0)
		var style: String = str(place.get("style", "bistro_wood"))
		var sign_txt: String = str(place.get("sign", place["name"]))
		var sub_txt: String = str(place.get("sub", ""))
		var addr_txt: String = str(place.get("address", ""))

		var main_col: String = "brand_dark"
		var accent_col: String = "brand_gold"
		var text_col: String = "shop_white"
		var emissive_sign: bool = true

		match style:
			"pizzeria_modern":
				main_col = "brand_dark"
				accent_col = "station_brick"
				text_col = "brand_gold"
			"gelato_red":
				main_col = "cafe_cream"
				accent_col = "coto_red"
				text_col = "shop_white"
			"bistro_wood":
				main_col = "cafe_wood"
				accent_col = "brand_dark"
				text_col = "cafe_cream"
			"gelato_luxury":
				main_col = "brand_dark"
				accent_col = "brand_gold"
				text_col = "lamp_glow"
			"burger_arcade":
				main_col = "brand_dark"
				accent_col = "traffic_red"
				text_col = "coto_yellow"
			"burger_boutique":
				main_col = "cafe_cream"
				accent_col = "perla_green"
				text_col = "cafe_wood"
			"burger_craft":
				main_col = "brand_dark"
				accent_col = "coto_yellow"
				text_col = "lamp_glow"
			"pharmacy_green":
				main_col = "shop_white"
				accent_col = "traffic_green"
				text_col = "shop_white"
			"pharmacy_blue":
				main_col = "shop_white"
				accent_col = "coto_blue"
				text_col = "shop_white"
			"gym_modern":
				main_col = "brand_dark"
				accent_col = "coto_yellow"
				text_col = "coto_yellow"
			"club_fire", "fire_station":
				main_col = "coto_red"
				accent_col = "shop_white"
				text_col = "shop_white"
			"patisserie_warm":
				main_col = "cafe_wood"
				accent_col = "perla_green"
				text_col = "cafe_cream"
			"patisserie_pink":
				main_col = "shop_white"
				accent_col = "brand_pink"
				text_col = "shop_white"
			"sushi_samurai", "sushi_otaku":
				main_col = "brand_dark"
				accent_col = "coto_red"
				text_col = "lamp_glow"
			"trattoria_italiana", "pasta_italiana":
				main_col = "cafe_cream"
				accent_col = "perla_green"
				text_col = "shop_white"
			"candy_wholesale":
				main_col = "coto_blue"
				accent_col = "coto_yellow"
				text_col = "coto_red"
			"climbing_gym":
				main_col = "brand_dark"
				accent_col = "brand_orange"
				text_col = "shop_white"
			"neoclassical_hall":
				main_col = "trim_stone"
				accent_col = "shop_white"
				text_col = "bronze_statue"
				emissive_sign = false
			"care_center":
				main_col = "shop_white"
				accent_col = "train_blue"
				text_col = "shop_white"
			"disco_vinicius", "disco_mata":
				main_col = "brand_dark"
				accent_col = "brand_purple" if style == "disco_vinicius" else "coto_red"
				text_col = "lamp_glow"
			"electronics_store":
				main_col = "shop_white"
				accent_col = "brand_purple"
				text_col = "shop_white"
			"shopping_gallery":
				main_col = "brand_dark"
				accent_col = "brand_gold"
				text_col = "cafe_cream"
			"fast_food_green":
				main_col = "traffic_green"
				accent_col = "coto_yellow"
				text_col = "coto_yellow"
			"sports_store":
				main_col = "coto_blue"
				accent_col = "brand_orange"
				text_col = "shop_white"
			"cafe_bonafide":
				main_col = "coto_red"
				accent_col = "cafe_wood"
				text_col = "shop_white"
			"neoclassical_clinic":
				main_col = "trim_stone"
				accent_col = "hospital_blue"
				text_col = "shop_white"
			"burger_mostaza":
				main_col = "coto_red"
				accent_col = "coto_yellow"
				text_col = "coto_yellow"
			"burger_wendys":
				main_col = "shop_white"
				accent_col = "coto_red"
				text_col = "shop_white"
			"bank_bbva":
				main_col = "coto_blue"
				accent_col = "train_blue"
				text_col = "shop_white"
			"bank_galicia":
				main_col = "shop_white"
				accent_col = "brand_orange"
				text_col = "shop_white"
			"bank_icbc", "bank_patagonia":
				main_col = "shop_white"
				accent_col = "coto_red" if style == "bank_icbc" else "coto_blue"
				text_col = "shop_white"
			"bank_hipotecario":
				main_col = "shop_white"
				accent_col = "brand_orange"
				text_col = "shop_white"
			"historic_school":
				main_col = "trim_stone"
				accent_col = "coto_blue"
				text_col = "shop_white"
				emissive_sign = false
			"bistro_milanesa":
				main_col = "brand_dark"
				accent_col = "brand_gold"
				text_col = "coto_yellow"
			"toy_store":
				main_col = "coto_yellow"
				accent_col = "coto_red"
				text_col = "shop_white"
			"cafe_starbucks":
				main_col = "cafe_wood"
				accent_col = "perla_green"
				text_col = "shop_white"
			"bodegon_farola":
				main_col = "cafe_cream"
				accent_col = "coto_red"
				text_col = "shop_white"
			"police_station":
				main_col = "shop_white"
				accent_col = "coto_blue"
				text_col = "shop_white"

		# Ground-floor architectural cladding panel & side pilasters
		_box(frame, Vector3(0, 2.25, 0.08), Vector3(width, 4.5, 0.10), main_col)
		_box(frame, Vector3(-width * 0.48, 2.25, 0.15), Vector3(0.38, 4.5, 0.18), accent_col)
		_box(frame, Vector3(width * 0.48, 2.25, 0.15), Vector3(0.38, 4.5, 0.18), accent_col)

		# Storefront glazing & warm interior illumination (except closed nightclubs)
		if not style.begins_with("disco_"):
			_box(frame, Vector3(0, 1.55, 0.14), Vector3(width - 1.1, 2.55, 0.08), "glass")
			_box(frame, Vector3(0, 2.68, 0.12), Vector3(width - 1.4, 0.10, 0.08), "lamp_glow")
		else:
			# Nightclub double acoustic doors + vertical neon LED tubes
			_box(frame, Vector3(0, 1.35, 0.16), Vector3(2.8, 2.5, 0.12), "metal")
			for nx: float in [-width * 0.36, -width * 0.22, width * 0.22, width * 0.36]:
				_box(frame, Vector3(nx, 2.2, 0.18), Vector3(0.12, 3.8, 0.12), "traffic_red" if style == "disco_mata" else "train_blue")
				_box(frame, Vector3(nx + 0.18, 2.2, 0.18), Vector3(0.08, 3.4, 0.10), "lamp_glow")

		# Prominent upper fascia / marquee box & 3D brand lettering
		var fascia_col: String = accent_col if main_col == "shop_white" or main_col == "cafe_cream" else main_col
		_box(frame, Vector3(0, 3.65, 0.22), Vector3(width + 0.2, 1.15, 0.24), fascia_col)
		_box(frame, Vector3(0, 4.26, 0.26), Vector3(width + 0.3, 0.14, 0.30), accent_col)
		_box(frame, Vector3(0, 3.04, 0.26), Vector3(width + 0.3, 0.10, 0.28), "lamp_glow" if emissive_sign else "trim_stone")

		var sign_h: float = clampf(width * 0.068, 0.38, 0.62)
		if sign_txt.length() > 14:
			sign_h = clampf(width / float(sign_txt.length()) * 1.15, 0.30, 0.50)
		_text(frame, Vector3(0, 3.78, 0.36), sign_txt, sign_h, text_col, style in ["neoclassical_hall", "trattoria_italiana", "pasta_italiana"], emissive_sign)
		if not sub_txt.is_empty():
			_text(frame, Vector3(0, 3.28, 0.36), sub_txt, 0.22, "cafe_cream" if fascia_col != "cafe_cream" else "brand_dark", false, false)

		# Street address plaque on right pilaster
		if not addr_txt.is_empty():
			_box(frame, Vector3(width * 0.36, 2.88, 0.24), Vector3(2.2, 0.28, 0.06), "blue")
			_text(frame, Vector3(width * 0.36, 2.88, 0.29), addr_txt.to_upper(), 0.13, "shop_white")

		# Style-specific 3D architectural ornaments & street-side props
		if style in ["pharmacy_green", "pharmacy_blue"]:
			# Projecting 3D illuminated green pharmacy cross perpendicular to facade
			var cross_c: Vector3 = Vector3(-width * 0.42, 3.45, 0.78)
			_box(frame, cross_c, Vector3(0.14, 0.88, 0.88), "traffic_green")
			_box(frame, cross_c, Vector3(0.18, 0.82, 0.28), "lamp_glow")
			_box(frame, cross_c, Vector3(0.18, 0.28, 0.82), "lamp_glow")
		elif style in ["burger_arcade", "burger_boutique", "burger_craft", "burger_mostaza", "burger_wendys"]:
			# Sculpted 3D Burger emblem above the entrance
			var bc: Vector3 = frame * Vector3(-width * 0.35, 3.65, 0.52)
			_cylinder(bc + Vector3.UP * 0.20, 0.38, 0.16, "brand_gold")
			_cylinder(bc + Vector3.UP * 0.06, 0.40, 0.06, "traffic_green")
			_cylinder(bc, 0.41, 0.10, "cafe_wood")
			_cylinder(bc - Vector3.UP * 0.06, 0.42, 0.04, "coto_yellow")
			_cylinder(bc - Vector3.UP * 0.15, 0.38, 0.12, "brand_gold")
			if style == "burger_craft":
				# Warm craft beer festoon lights under canopy
				_box(frame, Vector3(0, 2.85, 0.65), Vector3(width - 0.4, 0.08, 1.1), "brand_dark")
				for lx: float in [-width * 0.35, -width * 0.18, 0.0, width * 0.18, width * 0.35]:
					_box(frame, Vector3(lx, 2.76, 0.95), Vector3(0.12, 0.12, 0.12), "lamp_glow")
		elif style in ["gelato_red", "gelato_luxury"]:
			# 3D sculpted Gelato Cone by the entrance
			var gc: Vector3 = frame * Vector3(-width * 0.38, 1.15, 0.55)
			_cylinder(gc, 0.22, 0.75, "brand_gold")
			_cylinder(gc + Vector3.UP * 0.48, 0.28, 0.32, "flower_red" if style == "gelato_red" else "cafe_cream")
			_cylinder(gc + Vector3.UP * 0.72, 0.22, 0.26, "cafe_cream" if style == "gelato_red" else "brand_gold")
		elif style in ["sushi_samurai", "sushi_otaku"]:
			# Japanese Torii red lintel & glowing hanging paper lanterns (chochin)
			_box(frame, Vector3(0, 2.95, 0.48), Vector3(width + 0.5, 0.18, 0.36), "coto_red")
			_box(frame, Vector3(0, 2.78, 0.42), Vector3(width + 0.1, 0.12, 0.24), "brand_dark")
			for lx: float in [-width * 0.32, -width * 0.12, width * 0.12, width * 0.32]:
				_cylinder(frame * Vector3(lx, 2.42, 0.52), 0.18, 0.42, "traffic_red")
				_cylinder(frame * Vector3(lx, 2.42, 0.52), 0.14, 0.46, "lamp_glow")
		elif style in ["trattoria_italiana", "pasta_italiana", "pizzeria_modern", "bistro_wood", "patisserie_warm", "patisserie_pink", "cafe_bonafide", "cafe_starbucks", "bodegon_farola", "bistro_milanesa"]:
			# Sloped canvas awning + outdoor cafe tables on sidewalk
			var aw_col: String = accent_col
			b._quad(
				frame * Vector3(-width * 0.46, 3.02, 0.18),
				frame * Vector3(width * 0.46, 3.02, 0.18),
				frame * Vector3(width * 0.46, 2.62, 1.25),
				frame * Vector3(-width * 0.46, 2.62, 1.25),
				aw_col
			)
			if style in ["trattoria_italiana", "pasta_italiana"]:
				# Italian tricolor ribbon on fascia
				_box(frame, Vector3(-width * 0.3, 3.02, 0.32), Vector3(width * 0.3, 0.10, 0.08), "perla_green")
				_box(frame, Vector3(0.0, 3.02, 0.32), Vector3(width * 0.3, 0.10, 0.08), "shop_white")
				_box(frame, Vector3(width * 0.3, 3.02, 0.32), Vector3(width * 0.3, 0.10, 0.08), "coto_red")
			for tx: float in [-width * 0.24, width * 0.24]:
				var tpos: Vector3 = frame * Vector3(tx, 0.04, 1.55)
				if b.map.get_road_distance(tpos) > 1.1:
					_table(tpos, frame.basis, true)
		elif style in ["neoclassical_hall", "neoclassical_clinic", "historic_school"]:
			# Monumental neoclassical pilasters & triangular pediment
			for cx: float in [-width * 0.42, -width * 0.16, width * 0.16, width * 0.42]:
				_box(frame, Vector3(cx, 3.1, 0.22), Vector3(0.46, 6.0, 0.28), "shop_white")
				_box(frame, Vector3(cx, 6.15, 0.26), Vector3(0.62, 0.24, 0.36), "trim_stone")
			# Triangular pediment crown
			_box(frame, Vector3(0, 6.45, 0.24), Vector3(width + 0.4, 0.35, 0.42), "trim_stone")
			_box(frame, Vector3(0, 6.95, 0.22), Vector3(width * 0.65, 0.65, 0.34), "shop_white")
			_box(frame, Vector3(0, 7.45, 0.22), Vector3(width * 0.32, 0.45, 0.30), "trim_stone")
		elif style.begins_with("bank_"):
			# Bank security glass portal, metallic columns & 24hs ATM bay
			for cx: float in [-width * 0.28, width * 0.28]:
				_box(frame, Vector3(cx, 2.25, 0.22), Vector3(0.32, 4.4, 0.24), "silver_metal")
			_box(frame, Vector3(-width * 0.38, 2.15, 0.24), Vector3(1.1, 0.42, 0.08), accent_col)
			_text(frame, Vector3(-width * 0.38, 2.15, 0.30), "24HS", 0.20, "shop_white", false, true)
		elif style == "police_station":
			# Police blue beacon lamps & institutional shield panel
			_box(frame, Vector3(-width * 0.35, 3.05, 0.35), Vector3(0.28, 0.28, 0.28), "train_blue")
			_box(frame, Vector3(width * 0.35, 3.05, 0.35), Vector3(0.28, 0.28, 0.28), "train_blue")
			_box(frame, Vector3(0, 5.1, 0.20), Vector3(1.4, 1.5, 0.14), "coto_blue")
		elif style == "climbing_gym":
			# Exterior boulder/climbing wall panel with colorful climbing holds
			_box(frame, Vector3(0, 5.2, 0.16), Vector3(width * 0.85, 3.2, 0.14), "trim_stone")
			var hold_cols: Array[String] = ["coto_red", "coto_yellow", "train_blue", "traffic_green", "brand_orange"]
			for hi: int in range(18):
				var hx: float = -width * 0.35 + float(hi % 6) * (width * 0.14)
				var hy: float = 4.0 + float(hi / 6) * 0.95 + float(hi % 2) * 0.28
				_box(frame, Vector3(hx, hy, 0.26), Vector3(0.22, 0.18, 0.14), hold_cols[hi % hold_cols.size()])
		elif style == "fire_station":
			# Fire station bay shutter + parked red Autobomba (fire truck cab)
			_box(frame, Vector3(-width * 0.2, 1.75, 0.16), Vector3(3.4, 3.2, 0.10), "silver_metal")
			_box(frame, Vector3(0, 6.5, 0.15), Vector3(1.2, 2.4, 1.2), "coto_red")
			_cylinder(frame * Vector3(0, 7.9, 0.15), 0.45, 0.5, "silver_metal")
			var truck_pos: Vector3 = frame * Vector3(-width * 0.2, 0.0, 1.25)
			if b.map.get_road_distance(truck_pos) > 1.0:
				_box(frame, Vector3(-width * 0.2, 1.15, 0.95), Vector3(2.3, 1.9, 1.8), "coto_red")
				_box(frame, Vector3(-width * 0.2, 1.45, 1.86), Vector3(2.0, 0.75, 0.08), "glass")
				_box(frame, Vector3(-width * 0.2, 0.45, 1.88), Vector3(2.35, 0.28, 0.14), "silver_metal")
				_box(frame, Vector3(-width * 0.2 - 0.6, 2.18, 1.65), Vector3(0.32, 0.16, 0.22), "traffic_red")
				_box(frame, Vector3(-width * 0.2 + 0.6, 2.18, 1.65), Vector3(0.32, 0.16, 0.22), "train_blue")

func _detailed_plazas() -> void:
	for plaza: Dictionary in b.data.get("detailed_plazas", []):
		var pname: String = str(plaza["name"])
		var c_arr: Array = plaza["center"]
		var center: Vector3 = Vector3(float(c_arr[0]), 0.06, float(c_arr[1]))
		var pts: Array = plaza.get("points", [])

		# Ensure green base for Plazoleta Belgrano only if vertices do not intrude into roadway
		if pname == "Plazoleta General Manuel Belgrano" and pts.size() >= 3:
			var pts_ok: bool = true
			for pt in pts:
				if b.map.get_road_distance(b._v(pt)) < 0.2:
					pts_ok = false
					break
			if pts_ok:
				b._polygon(pts, 0.06, "grass")

		# Central circular/octagonal cobblestone agora + radial walkways
		_cylinder(center + Vector3.UP * 0.04, 6.8, 0.08, "pavers")
		_cylinder(center + Vector3.UP * 0.09, 7.0, 0.04, "curb")
		for angle_deg: float in [0.0, 90.0, 180.0, 270.0]:
			var dir: Vector3 = Vector3(cos(deg_to_rad(angle_deg)), 0, sin(deg_to_rad(angle_deg)))
			var p_end: Vector3 = center + dir * 16.0
			if b.map.get_road_distance(p_end) > 2.5:
				b._strip(center + Vector3.UP * 0.04, p_end + Vector3.UP * 0.04, 2.4, "pavers")

		# Park benches & twin-arm ornate boulevard streetlamps around the central agora
		for i: int in range(4):
			var ang: float = TAU * float(i) / 4.0 + PI * 0.25
			var dir: Vector3 = Vector3(cos(ang), 0, sin(ang))
			var bp: Vector3 = center + dir * 5.2
			var yaw: float = atan2(-dir.x, -dir.z)
			b._box(bp + Vector3(0, 0.48, 0), Vector3(1.8, 0.08, 0.48), "cafe_wood", yaw)
			b._box(bp + Vector3(0, 0.76, 0) - dir * 0.20, Vector3(1.8, 0.42, 0.08), "cafe_wood", yaw)
			var lp: Vector3 = center + dir * 6.4
			b._box(lp + Vector3(0, 2.6, 0), Vector3(0.12, 5.2, 0.12), "metal")
			b._box(lp + Vector3(0, 5.1, 0), Vector3(1.2, 0.09, 0.09), "metal", yaw)
			b._box(lp + Vector3(0, 5.25, 0), Vector3(0.32, 0.32, 0.32), "lamp_glow")

		# Monument & signature features per plaza
		var m_frame: Transform3D = Transform3D(Basis.IDENTITY, center)
		if pname == "Plaza Domingo Faustino Sarmiento":
			# Stepped stone pedestal + bronze bust of Sarmiento + playground
			_box(m_frame, Vector3(0, 0.45, 0), Vector3(3.2, 0.8, 3.2), "trim_stone")
			_box(m_frame, Vector3(0, 1.55, 0), Vector3(1.4, 1.6, 1.4), "shop_white")
			_cylinder(center + Vector3(0, 2.65, 0), 0.42, 0.65, "bronze_statue")
			_cylinder(center + Vector3(0, 3.18, 0), 0.28, 0.45, "bronze_statue")
			_box(m_frame, Vector3(0, 1.55, 0.74), Vector3(2.8, 0.55, 0.08), "coto_blue")
			_text(m_frame, Vector3(0, 1.55, 0.80), "PLAZA D. F. SARMIENTO", 0.24, "shop_white", true, true)
			_playground(center + Vector3(11.0, 0, -6.0))
		elif pname == "Plazoleta General Manuel Belgrano":
			# Stepped marble pedestal + equestrian/standing statue of Belgrano + tall Argentine Flagpole
			var m_pt: Array = plaza.get("monument_point", c_arr)
			var b_center: Vector3 = Vector3(float(m_pt[0]), 0.06, float(m_pt[1]))
			var bf: Transform3D = Transform3D(Basis.IDENTITY, b_center)
			_box(bf, Vector3(0, 0.55, 0), Vector3(3.8, 1.0, 3.8), "trim_stone")
			_box(bf, Vector3(0, 1.85, 0), Vector3(1.8, 1.8, 1.8), "shop_white")
			_box(bf, Vector3(0, 3.25, 0), Vector3(0.85, 1.2, 0.85), "bronze_statue")
			_cylinder(b_center + Vector3(0, 4.1, 0), 0.28, 0.55, "bronze_statue")
			# Tall 13m Flagpole with Argentine Flag (celeste, blanca y Sol de Mayo)
			_cylinder(b_center + Vector3(2.8, 6.5, -1.5), 0.09, 13.0, "silver_metal")
			_box(bf, Vector3(4.1, 11.8, -1.5), Vector3(2.6, 0.45, 0.06), "train_blue")
			_box(bf, Vector3(4.1, 11.35, -1.5), Vector3(2.6, 0.45, 0.06), "shop_white")
			_box(bf, Vector3(4.1, 10.9, -1.5), Vector3(2.6, 0.45, 0.06), "train_blue")
			_box(bf, Vector3(4.1, 11.35, -1.5), Vector3(0.28, 0.28, 0.09), "coto_yellow")
			_box(bf, Vector3(0, 1.75, 0.96), Vector3(3.6, 0.62, 0.08), "coto_blue")
			_text(bf, Vector3(0, 1.75, 1.02), "MONUMENTO A GRAL. BELGRANO", 0.22, "shop_white", true, true)
		elif pname == "Plaza Bartolomé Mitre":
			# Central monumental fountain/obelisk + wooden cultural pergola + playground
			_cylinder(center + Vector3(0, 0.35, 0), 3.6, 0.6, "trim_stone")
			_cylinder(center + Vector3(0, 0.55, 0), 3.1, 0.25, "train_blue")
			_box(m_frame, Vector3(0, 2.2, 0), Vector3(1.5, 3.2, 1.5), "shop_white")
			_cylinder(center + Vector3(0, 4.2, 0), 0.45, 0.95, "bronze_statue")
			_box(m_frame, Vector3(0, 1.8, 0.82), Vector3(3.2, 0.58, 0.08), "coto_blue")
			_text(m_frame, Vector3(0, 1.8, 0.88), "PLAZA BARTOLOMÉ MITRE", 0.24, "shop_white", true, true)
			# Wooden pergola
			for px: float in [-4.5, -1.5, 1.5, 4.5]:
				b._box(center + Vector3(px, 1.6, -9.5), Vector3(0.22, 3.2, 0.22), "cafe_wood")
				b._box(center + Vector3(px, 1.6, -12.5), Vector3(0.22, 3.2, 0.22), "cafe_wood")
			b._box(center + Vector3(0, 3.25, -11.0), Vector3(10.2, 0.18, 3.6), "cafe_wood")
			_playground(center + Vector3(11.0, 0, 8.0))
		elif pname == "Plaza Bomberitos":
			# Monumento al Bombero Voluntario at (-167.5, 1386.0) + tribute bell + playground
			var bom_center: Vector3 = Vector3(-167.5, 0.06, 1386.0)
			if bom_center.distance_to(center) > 65.0:
				bom_center = center
			var bmf: Transform3D = Transform3D(Basis.IDENTITY, bom_center)
			_box(bmf, Vector3(0, 0.55, 0), Vector3(3.6, 1.0, 2.4), "station_brick")
			_box(bmf, Vector3(0, 1.85, 0), Vector3(2.2, 1.8, 1.2), "trim_stone")
			_cylinder(bom_center + Vector3(0, 3.15, 0), 0.45, 0.85, "coto_red")
			_cylinder(bom_center + Vector3(0, 3.65, 0), 0.35, 0.35, "brand_gold")
			_box(bmf, Vector3(0, 1.65, 0.65), Vector3(3.4, 0.65, 0.08), "coto_red")
			_text(bmf, Vector3(0, 1.78, 0.71), "PLAZA BOMBERITOS", 0.26, "shop_white", false, true)
			_text(bmf, Vector3(0, 1.48, 0.71), "MONUMENTO AL BOMBERO VOLUNTARIO", 0.16, "coto_yellow", false, true)
			_playground(center + Vector3(-8.0, 0, -8.0))

func _playground(pos: Vector3) -> void:
	if b.map.get_road_distance(pos) < 3.0:
		return
	# Colorful children's playground pad: slide tower, swing frame & seesaw
	_cylinder(pos + Vector3.UP * 0.03, 4.2, 0.05, "earth")
	b._box(pos + Vector3(-1.5, 1.2, 0), Vector3(1.4, 2.4, 1.4), "coto_blue")
	b._box(pos + Vector3(-1.5, 2.55, 0), Vector3(1.7, 0.25, 1.7), "coto_red")
	b._box(pos + Vector3(-0.2, 0.85, 0), Vector3(1.8, 0.12, 0.55), "coto_yellow", 0.3)
	b._box(pos + Vector3(1.8, 2.1, 0), Vector3(2.6, 0.12, 0.12), "traffic_red")
	for sx: float in [0.6, 3.0]:
		b._box(pos + Vector3(sx, 1.05, 0), Vector3(0.10, 2.1, 0.8), "coto_blue")

func _el_muro_de_ramos() -> void:
	# Artistic street-art mural wall ("El Muro de Ramos") along the Sarmiento railway corridor
	var sections: Array = b.data["sections"]
	var mural_palette: Array[String] = ["train_blue", "shop_white", "coto_yellow", "coto_red", "traffic_green", "brand_orange", "brand_purple"]
	var panel_idx: int = 0
	for i: int in range(60, mini(170, sections.size() - 4), 4):
		var a: Dictionary = sections[i]
		var b_sec: Dictionary = sections[i + 4]
		var pa: Vector3 = Vector3(float(a["x"]), 0.0, float(a["intervals"][0][0]) - 3.75)
		var pb: Vector3 = Vector3(float(b_sec["x"]), 0.0, float(b_sec["intervals"][0][0]) - 3.75)
		var mid: Vector3 = (pa + pb) * 0.5
		if b.map.get_road_distance(mid) < 1.5:
			continue
		var dist: float = pa.distance_to(pb)
		var yaw: float = -atan2((pb - pa).z, (pb - pa).x)
		# Backing masonry wall + colorful mural panels + top coping & uplight
		b._box(mid + Vector3.UP * 1.45, Vector3(dist + 0.05, 2.9, 0.28), "trim_stone", yaw)
		b._box(mid + Vector3.UP * 2.95, Vector3(dist + 0.12, 0.14, 0.36), "shop_white", yaw)
		var col_a: String = mural_palette[panel_idx % mural_palette.size()]
		var col_b: String = mural_palette[(panel_idx + 2) % mural_palette.size()]
		b._box(mid + Vector3(0, 1.45, 0.16), Vector3(dist * 0.92, 2.3, 0.04), col_a, yaw)
		b._box(mid + Vector3(0, 1.45, 0.18), Vector3(dist * 0.45, 1.3, 0.04), col_b, yaw)
		if panel_idx % 3 == 0:
			b._box(mid + Vector3(0, 2.82, 0.28), Vector3(1.2, 0.06, 0.14), "lamp_glow", yaw)
		if panel_idx == 12:
			var m_frame: Transform3D = Transform3D(Basis(Vector3.UP, yaw), mid + Vector3(0, 1.55, 0.22))
			_box(m_frame, Vector3(0, 0, 0), Vector3(dist * 0.9, 1.1, 0.06), "brand_dark")
			_text(m_frame, Vector3(0, 0.15, 0.05), "EL MURO DE RAMOS MEJÍA", 0.42, "coto_yellow", false, true)
			_text(m_frame, Vector3(0, -0.32, 0.05), "ARTE URBANO · FERROCARRIL SARMIENTO", 0.20, "shop_white", false, true)
		panel_idx += 1

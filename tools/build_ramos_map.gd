extends SceneTree
## Bake an editor-visible metre-scale map. Meshes are batched by material with PBR textures & UVs.
const ProceduralTextures = preload("res://tools/procedural_textures.gd")

var map: Node3D
var data: Dictionary
var batches: Dictionary = {}
var tex_lib: Dictionary = {}
var colors: Dictionary = {
	"road": Color("ffffff"),
	"line": Color("f2efe4"),
	"yellow": Color("e8b938"),
	"walk": Color("e2dfd8"),
	"curb": Color("dedbd2"),
	"earth": Color("e6e8e2"),
	"grass": Color("f0f5ec"),
	"rail": Color("ffffff"),
	"ballast": Color("ffffff"),
	"trunk": Color("ffffff"),
	"leaf": Color("ffffff"),
	"leaf_light": Color("b8d8a0"),
	"metal": Color("3a4347"),
	"silver_metal": Color("c2c9cc"),
	"glass": Color("ffffff"),
	"red": Color("c84638"),
	"blue": Color("2a5c8a"),
	"facade_property_wall": Color("edeae2"),
	"roof_terrace": Color("f2ece6"),
	"roof_zinc": Color("ffffff"),
	"station_brick": Color("ffffff"),
	"awning_striped": Color("f2eee4"),
	"awning_red": Color("8f2424"),
	"awning_blue": Color("1f3f66"),
	"trim_stone": Color("d4cec0"),
	"lamp_glow": Color("fff4d2"),
	"traffic_red": Color("ff2a1f"),
	"traffic_yellow": Color("ffbe1a"),
	"traffic_green": Color("1fd655"),
	"train_blue": Color("2478b5"),
	"train_white": Color("edf0f2"),
	"flower_red": Color("d9383a"),
	"flower_yellow": Color("ebbd34")
}

func _initialize() -> void:
	build.call_deferred()

func build() -> void:
	tex_lib = ProceduralTextures.ensure_textures(false)
	map = load("res://scripts/track.gd").new()
	map.name = "RamosMejia"
	root.add_child(map)
	data = map.data
	map.load_map_data()
	var sections: Array = data["sections"]
	var end_x: float = float(sections[-1]["x"])
	_box(Vector3(end_x * 0.5, -0.16, 50.0), Vector3(20000.0, 0.3, 20000.0), "earth")
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "GroundCollision"
	map.add_child(body)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: WorldBoundaryShape3D = WorldBoundaryShape3D.new()
	shape.plane = Plane(Vector3.UP, 0.0)
	collision.shape = shape
	body.add_child(collision)
	var neighborhood: RefCounted = load("res://tools/neighborhood_geometry.gd").new()
	neighborhood.generate(self)
	_furniture(sections)
	for key: String in batches:
		var st: SurfaceTool = batches[key] as SurfaceTool
		st.generate_tangents()
		var mesh_node: MeshInstance3D = MeshInstance3D.new()
		mesh_node.name = key.capitalize().replace(" ", "")
		mesh_node.mesh = st.commit()
		mesh_node.material_override = _make_material(key)
		map.add_child(mesh_node)
		if key.begins_with("facade") or key == "landmark_stone":
			var solid: StaticBody3D = StaticBody3D.new()
			solid.name = "Buildings_" + key
			map.add_child(solid)
			var building_collision: CollisionShape3D = CollisionShape3D.new()
			var building_shape: ConcavePolygonShape3D = mesh_node.mesh.create_trimesh_shape()
			building_shape.backface_collision = true
			building_collision.shape = building_shape
			solid.add_child(building_collision)
	_own(map)
	var packed: PackedScene = PackedScene.new()
	packed.pack(map)
	var result: Error = ResourceSaver.save(packed, "res://scenes/ramos_mejia.tscn")
	print("MAP_BAKED length=", map.get_track_length(), "m batches=", batches.size(), " save=", result)
	quit(result)

func _make_material(key: String) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = colors.get(key, Color.WHITE)
	material.roughness = 0.90
	material.metallic_specular = 0.14
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

	var tex_key: String = key
	if key == "leaf_light" or key == "hospital_hedge":
		tex_key = "leaf" if key == "leaf_light" else "grass"
	elif key in ["awning_red", "awning_blue"]:
		tex_key = "perla_green"
	elif key == "trim_stone":
		tex_key = "curb"

	if tex_lib.has(tex_key):
		var pair: Dictionary = tex_lib[tex_key]
		material.albedo_texture = pair["albedo"]
		material.normal_enabled = true
		material.normal_texture = pair["normal"]
		material.normal_scale = 0.36
		if key == "hospital_hedge":
			material.albedo_color = Color("7aa36f")
		elif key in ["awning_red", "awning_blue"]:
			material.albedo_texture = tex_lib["curb"]["albedo"]

	if key in ["glass", "hospital_glass", "perla_glass"]:
		material.metallic = 0.55
		material.metallic_specular = 0.65
		material.roughness = 0.14
		material.normal_scale = 0.25
	elif key in ["metal", "rail", "silver_metal"]:
		material.metallic = 0.78
		material.metallic_specular = 0.6
		material.roughness = 0.28
	elif key in ["coto_red", "coto_blue", "coto_yellow", "train_blue", "train_white", "red", "blue"]:
		material.metallic = 0.20
		material.metallic_specular = 0.35
		material.roughness = 0.38
	elif key in ["lamp_glow", "traffic_red", "traffic_yellow", "traffic_green"]:
		material.emission_enabled = true
		material.emission = colors[key]
		material.emission_energy_multiplier = 2.0
		material.roughness = 0.2

	return material

func _own(parent: Node) -> void:
	for child: Node in parent.get_children():
		child.owner = map
		_own(child)

func _batch(key: String) -> SurfaceTool:
	if not batches.has(key):
		var surface: SurfaceTool = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		batches[key] = surface
	return batches[key] as SurfaceTool

func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, key: String, uv_scale: float = 0.38) -> void:
	var surface: SurfaceTool = _batch(key)
	var normal: Vector3 = (b - a).cross(c - a).normalized()
	if normal.length_squared() < 0.001:
		normal = Vector3.UP
	elif absf(normal.y) > 0.9:
		normal = Vector3.UP
	var u_len: float = maxf(0.1, a.distance_to(b) * uv_scale)
	var v_len: float = maxf(0.1, a.distance_to(d) * uv_scale)
	if key in ["glass", "hospital_glass", "perla_glass"]:
		u_len = maxf(1.0, roundf(a.distance_to(b) / 1.8))
		v_len = maxf(1.0, roundf(a.distance_to(d) / 2.2))
	var uvs: Array[Vector2] = [
		Vector2(0.0, v_len),
		Vector2(u_len, 0.0),
		Vector2(u_len, v_len),
		Vector2(0.0, v_len),
		Vector2(0.0, 0.0),
		Vector2(u_len, 0.0)
	]
	var verts: Array[Vector3] = [a, c, b, a, d, c]
	for i: int in range(6):
		surface.set_normal(normal)
		surface.set_uv(uvs[i])
		surface.add_vertex(verts[i])

func _box(center: Vector3, size: Vector3, key: String, yaw: float = 0.0) -> void:
	var basis: Basis = Basis(Vector3.UP, yaw)
	var p: Array[Vector3] = []
	for x: float in [-0.5, 0.5]:
		for y: float in [-0.5, 0.5]:
			for z: float in [-0.5, 0.5]:
				p.append(center + basis * (Vector3(x, y, z) * size))
	for face: Array in [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]:
		_quad(p[face[0]], p[face[1]], p[face[2]], p[face[3]], key)

func _strip(a: Vector3, b: Vector3, width: float, key: String) -> void:
	var right: Vector3 = (b - a).normalized().cross(Vector3.UP) * width * 0.5
	_quad(a - right, b - right, b + right, a + right, key, 0.35)

func _v(p: Array, y: float = 0.0) -> Vector3:
	return Vector3(float(p[0]), y, float(p[1]))

func _polygon(points: Array, height: float, key: String, base_y: float = 0.0) -> void:
	var flat: PackedVector2Array = PackedVector2Array()
	for p: Array in points:
		flat.append(Vector2(float(p[0]), float(p[1])))
	var indices: PackedInt32Array = Geometry2D.triangulate_polygon(flat)
	var surface: SurfaceTool = _batch(key)
	for index: int in indices:
		surface.set_normal(Vector3.UP)
		surface.set_uv(flat[index] * 0.35)
		surface.add_vertex(Vector3(flat[index].x, base_y + height, flat[index].y))
	if height > 0.08:
		for i: int in range(points.size()):
			var a: Vector3 = _v(points[i], base_y)
			var b: Vector3 = _v(points[(i + 1) % points.size()], base_y)
			_quad(a, b, b + Vector3.UP * height, a + Vector3.UP * height, key)

func _section_near(x: float) -> Dictionary:
	var sections: Array = data["sections"]
	var fraction: float = clampf(x / float(sections[-1]["x"]), 0, 1)
	return sections[roundi(fraction * float(sections.size() - 1))]

func _is_near_special_zone(p: Vector3) -> bool:
	var tanga_pt: Array = data["tanga"]["points"][0]
	if Vector2(p.x, p.z).distance_to(Vector2(float(tanga_pt[0]), float(tanga_pt[1]))) < 34.0:
		return true
	for site: Dictionary in data.get("recognizable_buildings", []):
		var visit: Array = site["visit"]
		if Vector2(p.x, p.z).distance_to(Vector2(float(visit[0]), float(visit[1]))) < 38.0:
			return true
		var a: Array = site["front"]["a"]
		var b_pt: Array = site["front"]["b"]
		var mid: Vector2 = Vector2((float(a[0]) + float(b_pt[0])) * 0.5, (float(a[1]) + float(b_pt[1])) * 0.5)
		if Vector2(p.x, p.z).distance_to(mid) < 36.0:
			return true
	return false

func _tree(p: Vector3, scale_factor: float = 1.0) -> void:
	# Tree planter pit on sidewalk
	_box(p + Vector3(0, 0.04, 0), Vector3(1.1, 0.08, 1.1) * scale_factor, "curb")
	_box(p + Vector3(0, 0.06, 0), Vector3(0.85, 0.09, 0.85) * scale_factor, "earth")
	# Trunk + primary branches
	_box(p + Vector3(0, 1.65 * scale_factor, 0), Vector3(0.34, 3.3, 0.34) * scale_factor, "trunk")
	_box(p + Vector3(-0.35, 3.1, 0.15) * scale_factor, Vector3(0.18, 1.4, 0.18) * scale_factor, "trunk", 0.4)
	_box(p + Vector3(0.35, 3.2, -0.15) * scale_factor, Vector3(0.18, 1.4, 0.18) * scale_factor, "trunk", -0.4)
	# Multi-sphere organic canopy
	var blobs: Array = [
		[Vector3(0.0, 4.5, 0.0), 1.85, 3.1, "leaf"],
		[Vector3(-0.95, 4.1, 0.55), 1.35, 2.3, "leaf"],
		[Vector3(0.95, 4.2, -0.45), 1.4, 2.4, "leaf_light"],
		[Vector3(0.25, 5.3, 0.35), 1.3, 2.1, "leaf_light"],
		[Vector3(-0.4, 4.3, -0.8), 1.25, 2.1, "leaf"]
	]
	for blob: Array in blobs:
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = float(blob[1]) * scale_factor
		sphere.height = float(blob[2]) * scale_factor
		sphere.radial_segments = 10
		sphere.rings = 6
		_batch(str(blob[3])).append_from(sphere, 0, Transform3D(Basis.IDENTITY, p + (blob[0] as Vector3) * scale_factor))

func _streetlight(p: Vector3, side: float) -> void:
	_box(p + Vector3(0, 0.35, 0), Vector3(0.26, 0.7, 0.26), "metal")
	_box(p + Vector3(0, 4.2, 0), Vector3(0.13, 7.8, 0.13), "metal")
	_box(p + Vector3(0, 7.95, -side * 1.15), Vector3(0.11, 0.11, 2.3), "metal")
	_box(p + Vector3(0, 7.98, -side * 2.15), Vector3(0.38, 0.12, 0.82), "silver_metal")
	_box(p + Vector3(0, 7.90, -side * 2.15), Vector3(0.30, 0.05, 0.68), "lamp_glow")

func _bus_shelter(p: Vector3, side: float) -> void:
	# Detailed Argentine Colectivo shelter facing the street
	var face_z: float = -side
	_box(p + Vector3(0, 2.28, 0), Vector3(4.4, 0.12, 1.85), "metal")
	_box(p + Vector3(0, 2.35, face_z * 0.85), Vector3(4.44, 0.14, 0.16), "blue")
	# Back glass panel & frame
	_box(p + Vector3(0, 1.15, -face_z * 0.78), Vector3(4.1, 1.95, 0.05), "glass")
	_box(p + Vector3(-1.35, 1.15, 0), Vector3(0.05, 1.95, 1.5), "glass")
	for x_off: float in [-2.05, 0.0, 2.05]:
		_box(p + Vector3(x_off, 1.14, -face_z * 0.78), Vector3(0.09, 2.28, 0.09), "metal")
	# Bench + backrest
	_box(p + Vector3(0.3, 0.52, -face_z * 0.45), Vector3(2.6, 0.07, 0.46), "silver_metal")
	_box(p + Vector3(0.3, 0.26, -face_z * 0.45), Vector3(2.2, 0.5, 0.08), "metal")
	# Bus stop route totem pole
	var post_p: Vector3 = p + Vector3(-2.65, 0, face_z * 0.55)
	_box(post_p + Vector3(0, 1.35, 0), Vector3(0.07, 2.7, 0.07), "metal")
	_box(post_p + Vector3(0, 2.35, 0), Vector3(0.42, 0.68, 0.06), "blue")
	_box(post_p + Vector3(0, 1.82, 0), Vector3(0.40, 0.28, 0.07), "line")
	# Trash bin
	_box(post_p + Vector3(0.32, 0.55, 0), Vector3(0.28, 0.65, 0.28), "metal")

func _furniture(sections: Array) -> void:
	for i: int in range(5, sections.size() - 5, 11):
		var section: Dictionary = sections[i]
		for side: float in [-1.0, 1.0]:
			var edge: float = float(section["intervals"][0][0] if side < 0 else section["intervals"][-1][1])
			var p: Vector3 = Vector3(float(section["x"]), 0.16, edge + side * 1.85)
			var crossing_near: bool = false
			for crossing: Dictionary in data["crossings"]:
				if absf(p.x - float(crossing["point"][0])) < 12.0:
					crossing_near = true
			if crossing_near or _is_near_special_zone(p):
				continue
			if map.get_road_distance(p) < 0.8:
				continue
			var tree_scale: float = 0.92 + float((i * 7 + int(side + 2.0)) % 4) * 0.08
			_tree(p, tree_scale)
			var light_p: Vector3 = p + Vector3(4.2, 0, 0)
			if not _is_near_special_zone(light_p) and map.get_road_distance(light_p) > 0.8:
				_streetlight(light_p, side)
			if i % 33 == 5 and side > 0:
				var bus_p: Vector3 = p + Vector3(-5.2, 0, 0.2)
				if not _is_near_special_zone(bus_p) and map.get_road_distance(bus_p) > 1.1:
					_bus_shelter(bus_p, side)

	# Upgraded Sarmiento Railway perimeter fence north of the footpath
	for i: int in range(0, sections.size() - 1, 3):
		var a: Dictionary = sections[i]
		var b_sec: Dictionary = sections[mini(i + 3, sections.size() - 1)]
		var p: Vector3 = Vector3(float(a["x"]), 0, float(a["intervals"][0][0]) - 3.9)
		var q: Vector3 = Vector3(float(b_sec["x"]), 0, float(b_sec["intervals"][0][0]) - 3.9)
		if map.get_road_distance((p + q) * 0.5) < 1.2:
			continue
		var dist: float = p.distance_to(q)
		var yaw: float = -atan2((q - p).z, (q - p).x)
		# Low concrete masonry plinth + iron fence posts & rails
		_box((p + q) * 0.5 + Vector3.UP * 0.20, Vector3(dist + 0.05, 0.40, 0.22), "curb", yaw)
		_box(p + Vector3.UP * 0.95, Vector3(0.14, 1.9, 0.14), "metal")
		for height: float in [0.55, 1.15, 1.72]:
			_box((p + q) * 0.5 + Vector3.UP * height, Vector3(dist, 0.06, 0.06), "metal", yaw)

func _sign(position: Vector3, text: String, yaw: float) -> Label3D:
	var label: Label3D = Label3D.new()
	label.name = "StreetSign"
	label.text = text
	label.position = position
	label.rotation.y = yaw
	label.font_size = 40
	label.pixel_size = 0.015
	label.modulate = Color("f4f3eb")
	label.outline_modulate = Color("192830")
	label.outline_size = 12
	label.double_sided = true
	map.add_child(label)
	return label

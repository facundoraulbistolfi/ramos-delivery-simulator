extends SceneTree
## Bake an editor-visible metre-scale map. Meshes are spatially chunked and indexed for fast rendering on older GPUs.
const ProceduralTextures = preload("res://tools/procedural_textures.gd")

const CHUNK_SIZE: float = 420.0

var map: Node3D
var data: Dictionary
var batches: Dictionary = {}
var chunk_batches: Dictionary = {}
var collision_batches: Dictionary = {}
var material_cache: Dictionary = {}
var tex_lib: Dictionary = {}
var _canopy_mesh_main: SphereMesh
var _canopy_mesh_sub: SphereMesh

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
	"flower_yellow": Color("ebbd34"),
	"boundary_wall": Color(0.20, 0.75, 0.98, 0.35),
	"window_warm": Color("ffd996"),
	"window_lit": Color("ffebba"),
	"window_cool": Color("d0e6ff")
}

const NO_SHADOW_KEYS: Dictionary = {
	"road": true, "walk": true, "pavers": true, "curb": true, "earth": true,
	"grass": true, "ballast": true, "rail": true, "line": true, "yellow": true,
	"roof_terrace": true, "hospital_drive": true, "glass": true,
	"hospital_glass": true, "perla_glass": true, "lamp_glow": true,
	"window_warm": true, "window_lit": true, "window_cool": true,
	"traffic_red": true, "traffic_yellow": true, "traffic_green": true,
	"flower_red": true, "flower_yellow": true, "trim_stone": true,
	"awning_striped": true, "awning_red": true, "awning_blue": true, "perla_green": true,
	"boundary_wall": true
}

const DETAIL_RANGE_KEYS: Dictionary = {
	"line": 210.0, "yellow": 210.0, "curb": 230.0, "rail": 220.0,
	"glass": 260.0, "hospital_glass": 280.0, "perla_glass": 260.0,
	"trim_stone": 240.0, "metal": 260.0, "silver_metal": 260.0,
	"awning_striped": 230.0, "awning_red": 230.0, "awning_blue": 230.0, "perla_green": 240.0,
	"lamp_glow": 240.0, "traffic_red": 220.0, "traffic_yellow": 220.0, "traffic_green": 220.0,
	"flower_red": 160.0, "flower_yellow": 160.0, "cafe_wood": 220.0, "cafe_cream": 220.0,
	"leaf": 300.0, "leaf_light": 300.0, "trunk": 280.0, "palm_leaf": 300.0, "palm_trunk": 300.0
}

func _initialize() -> void:
	build.call_deferred()

func build() -> void:
	_init_tree_meshes()
	tex_lib = ProceduralTextures.ensure_textures(true)
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
	_build_boundary_barrier()

	# 1. Commit global structural/collision batches (facade*, landmark_stone, earth)
	for key: String in batches:
		var st: SurfaceTool = batches[key] as SurfaceTool
		st.index()
		var mesh_node: MeshInstance3D = MeshInstance3D.new()
		mesh_node.name = key.capitalize().replace(" ", "")
		mesh_node.mesh = st.commit()
		mesh_node.material_override = _get_material(key)
		if NO_SHADOW_KEYS.has(key):
			mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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

	# 2. Commit spatially chunked batches for fast frustum & distance culling
	var chunks_root: Node3D = Node3D.new()
	chunks_root.name = "SectorChunks"
	map.add_child(chunks_root)
	for chunk_id: String in chunk_batches:
		var entry: Dictionary = chunk_batches[chunk_id]
		var key: String = str(entry["key"])
		var st: SurfaceTool = entry["st"] as SurfaceTool
		st.index()
		var mesh_node: MeshInstance3D = MeshInstance3D.new()
		mesh_node.name = chunk_id
		mesh_node.mesh = st.commit()
		mesh_node.material_override = _get_material(key)
		if NO_SHADOW_KEYS.has(key):
			mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if DETAIL_RANGE_KEYS.has(key):
			mesh_node.visibility_range_end = float(DETAIL_RANGE_KEYS[key])
		chunks_root.add_child(mesh_node)

	# 3. Commit dedicated physics collision batches (bridges, footbridges, railway barriers)
	for col_key: String in collision_batches:
		var st: SurfaceTool = collision_batches[col_key] as SurfaceTool
		var col_mesh: ArrayMesh = st.commit()
		if col_mesh.get_surface_count() == 0:
			continue
		var solid: StaticBody3D = StaticBody3D.new()
		solid.name = col_key
		map.add_child(solid)
		var cshape: CollisionShape3D = CollisionShape3D.new()
		var trimesh: ConcavePolygonShape3D = col_mesh.create_trimesh_shape()
		trimesh.backface_collision = true
		cshape.shape = trimesh
		solid.add_child(cshape)

	_own(map)
	var packed: PackedScene = PackedScene.new()
	packed.pack(map)
	var result: Error = ResourceSaver.save(packed, "res://scenes/ramos_mejia.tscn")
	print("MAP_BAKED length=", map.get_track_length(), "m global_batches=", batches.size(), " chunk_batches=", chunk_batches.size(), " save=", result)
	quit(result)

func _build_boundary_barrier() -> void:
	var boundary_pts: Array = data.get("ramos_boundary", [])
	if boundary_pts.size() < 3:
		return
	var wall_st: SurfaceTool = batches.get("boundary_wall") as SurfaceTool
	if wall_st == null:
		wall_st = SurfaceTool.new()
		wall_st.begin(Mesh.PRIMITIVE_TRIANGLES)
		batches["boundary_wall"] = wall_st
	
	var col_st: SurfaceTool = collision_batches.get("BoundaryBarrierCollision") as SurfaceTool
	if col_st == null:
		col_st = SurfaceTool.new()
		col_st.begin(Mesh.PRIMITIVE_TRIANGLES)
		collision_batches["BoundaryBarrierCollision"] = col_st
	
	var wall_h: float = 6.0
	for i: int in range(boundary_pts.size()):
		var p0: Array = boundary_pts[i]
		var p1: Array = boundary_pts[(i + 1) % boundary_pts.size()]
		var v0: Vector3 = Vector3(float(p0[0]), 0.0, float(p0[1]))
		var v1: Vector3 = Vector3(float(p1[0]), 0.0, float(p1[1]))
		var v0_top: Vector3 = Vector3(float(p0[0]), wall_h, float(p0[1]))
		var v1_top: Vector3 = Vector3(float(p1[0]), wall_h, float(p1[1]))
		
		# Quads - front side
		wall_st.set_normal(Vector3.UP)
		wall_st.set_uv(Vector2(0, 0))
		wall_st.add_vertex(v0)
		wall_st.set_uv(Vector2(1, 0))
		wall_st.add_vertex(v1)
		wall_st.set_uv(Vector2(1, 1))
		wall_st.add_vertex(v1_top)
		
		wall_st.set_uv(Vector2(0, 0))
		wall_st.add_vertex(v0)
		wall_st.set_uv(Vector2(1, 1))
		wall_st.add_vertex(v1_top)
		wall_st.set_uv(Vector2(0, 1))
		wall_st.add_vertex(v0_top)

		# Quads - reverse side
		wall_st.set_uv(Vector2(1, 0))
		wall_st.add_vertex(v1)
		wall_st.set_uv(Vector2(0, 0))
		wall_st.add_vertex(v0)
		wall_st.set_uv(Vector2(0, 1))
		wall_st.add_vertex(v0_top)
		
		wall_st.set_uv(Vector2(1, 0))
		wall_st.add_vertex(v1)
		wall_st.set_uv(Vector2(0, 1))
		wall_st.add_vertex(v0_top)
		wall_st.set_uv(Vector2(1, 1))
		wall_st.add_vertex(v1_top)
		
		# Solid collision
		col_st.add_vertex(v0)
		col_st.add_vertex(v1)
		col_st.add_vertex(v1_top)
		col_st.add_vertex(v0)
		col_st.add_vertex(v1_top)
		col_st.add_vertex(v0_top)
		col_st.add_vertex(v1)
		col_st.add_vertex(v0)
		col_st.add_vertex(v0_top)
		col_st.add_vertex(v1)
		col_st.add_vertex(v0_top)
		col_st.add_vertex(v1_top)

func _init_tree_meshes() -> void:
	_canopy_mesh_main = SphereMesh.new()
	_canopy_mesh_main.radius = 1.95
	_canopy_mesh_main.height = 3.1
	_canopy_mesh_main.radial_segments = 6
	_canopy_mesh_main.rings = 3
	_canopy_mesh_sub = SphereMesh.new()
	_canopy_mesh_sub.radius = 1.45
	_canopy_mesh_sub.height = 2.3
	_canopy_mesh_sub.radial_segments = 5
	_canopy_mesh_sub.rings = 2

func _get_material(key: String) -> StandardMaterial3D:
	if not material_cache.has(key):
		material_cache[key] = _make_material(key)
	return material_cache[key] as StandardMaterial3D

func _make_material(key: String) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = colors.get(key, Color.WHITE)
	material.roughness = 0.85
	material.metallic_specular = 0.20
	# Prevent transparent/invisible walls or houses regardless of winding
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
		if pair.has("normal") and pair["normal"] != null:
			material.normal_enabled = true
			material.normal_texture = pair["normal"]
			material.normal_scale = 1.0
		if key == "hospital_hedge":
			material.albedo_color = Color("7aa36f")
		elif key in ["awning_red", "awning_blue"]:
			material.albedo_texture = tex_lib["curb"]["albedo"]

	match key:
		"boundary_wall":
			material.albedo_color = Color(0.20, 0.75, 0.98, 0.35)
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			material.roughness = 0.12
			material.emission_enabled = true
			material.emission = Color(0.12, 0.45, 0.70)
			material.emission_energy_multiplier = 0.75
		"road":
			material.albedo_color = Color.WHITE
			material.roughness = 0.85
			material.metallic = 0.02
			material.normal_scale = 0.65
		"walk":
			material.albedo_color = Color.WHITE
			material.roughness = 0.82
			material.metallic = 0.01
			material.normal_scale = 0.85
		"pavers":
			material.albedo_color = Color.WHITE
			material.roughness = 0.82
			material.normal_scale = 1.65
		"ballast":
			material.albedo_color = Color.WHITE
			material.roughness = 0.90
			material.normal_scale = 1.90
		"rail":
			material.albedo_color = Color.WHITE
			material.metallic = 0.88
			material.metallic_specular = 0.65
			material.roughness = 0.20
			material.normal_scale = 1.0
		"trunk":
			material.albedo_color = Color.WHITE
			material.roughness = 0.88
			material.normal_scale = 1.40
		"curb":
			material.albedo_color = Color.WHITE
			material.roughness = 0.84
			material.normal_scale = 1.30
		"station_brick", "facade3":
			material.albedo_color = Color.WHITE
			material.roughness = 0.86
			material.normal_scale = 1.50
		"roof_terrace":
			material.albedo_color = Color.WHITE
			material.roughness = 0.80
			material.normal_scale = 1.45
		"roof_zinc":
			material.albedo_color = Color.WHITE
			material.metallic = 0.60
			material.metallic_specular = 0.45
			material.roughness = 0.35
			material.normal_scale = 1.35
		"facade0", "facade1", "facade2", "facade4", "facade5", "facade6", "facade7", "facade_property_wall", "facade_san_juan", "facade_coto", "facade_la_perla", "landmark_stone":
			material.albedo_color = Color.WHITE
			material.roughness = 0.85
			material.normal_scale = 1.25
		"glass", "hospital_glass", "perla_glass":
			material.metallic = 0.45
			material.metallic_specular = 0.55
			material.roughness = 0.16
			material.normal_scale = 0.60
		"metal", "silver_metal":
			material.metallic = 0.70
			material.metallic_specular = 0.52
			material.roughness = 0.30
		"lamp_glow", "traffic_red", "traffic_yellow", "traffic_green":
			material.emission_enabled = true
			material.emission = colors.get(key, Color.WHITE)
			material.emission_energy_multiplier = 3.6
			material.roughness = 0.20
		"window_warm", "window_lit", "window_cool":
			material.albedo_color = colors.get(key, Color("ffebba"))
			material.emission_enabled = true
			material.emission = colors.get(key, Color("ffebba"))
			material.emission_energy_multiplier = 2.6
			material.roughness = 0.22

	return material

func _own(parent: Node) -> void:
	for child: Node in parent.get_children():
		child.owner = map
		_own(child)

func _is_global_key(key: String) -> bool:
	return key.begins_with("facade") or key == "landmark_stone" or key == "earth"

func _batch(key: String) -> SurfaceTool:
	if not batches.has(key):
		var surface: SurfaceTool = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		batches[key] = surface
	return batches[key] as SurfaceTool

func _batch_at(key: String, pos: Vector3) -> SurfaceTool:
	if _is_global_key(key):
		return _batch(key)
	var cx: int = floori(pos.x / CHUNK_SIZE)
	var cz: int = floori(pos.z / CHUNK_SIZE)
	var chunk_id: String = "%s_%d_%d" % [key, cx, cz]
	if not chunk_batches.has(chunk_id):
		var surface: SurfaceTool = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		chunk_batches[chunk_id] = {"key": key, "st": surface}
	return chunk_batches[chunk_id]["st"] as SurfaceTool

func _collision_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col_key: String) -> void:
	if not collision_batches.has(col_key):
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		collision_batches[col_key] = st
	var surface: SurfaceTool = collision_batches[col_key] as SurfaceTool
	for v: Vector3 in [a, b, c, a, c, d]:
		surface.add_vertex(v)

func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, key: String, uv_scale: float = 0.38) -> void:
	var surface: SurfaceTool = _batch_at(key, (a + c) * 0.5)
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
		Vector2(0.0, 0.0),
		Vector2(u_len, 0.0),
		Vector2(u_len, v_len),
		Vector2(0.0, 0.0),
		Vector2(u_len, v_len),
		Vector2(0.0, v_len)
	]
	var verts: Array[Vector3] = [a, b, c, a, c, d]
	var use_world_uv: bool = (normal == Vector3.UP) and key in ["road", "walk", "curb", "earth", "pavers", "ballast", "grass", "roof_terrace"]
	for i: int in range(6):
		surface.set_normal(normal)
		if use_world_uv:
			surface.set_uv(Vector2(verts[i].x, verts[i].z) * uv_scale)
		else:
			surface.set_uv(uvs[i])
		surface.add_vertex(verts[i])

func _box(center: Vector3, size: Vector3, key: String, yaw: float = 0.0) -> void:
	var basis: Basis = Basis(Vector3.UP, yaw)
	var p: Array[Vector3] = []
	for x: float in [-0.5, 0.5]:
		for y: float in [-0.5, 0.5]:
			for z: float in [-0.5, 0.5]:
				p.append(center + basis * (Vector3(x, y, z) * size))
	# Skip bottom face [0, 4, 5, 1] when the box rests on or near the ground
	var faces: Array = [[0, 1, 3, 2], [4, 6, 7, 5], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]
	if center.y - size.y * 0.5 > 0.25:
		faces.append([0, 4, 5, 1])
	for face: Array in faces:
		_quad(p[face[0]], p[face[1]], p[face[2]], p[face[3]], key)

func _strip(a: Vector3, b: Vector3, width: float, key: String, uv_scale: float = 0.35) -> void:
	var right: Vector3 = (b - a).normalized().cross(Vector3.UP) * width * 0.5
	_quad(a - right, b - right, b + right, a + right, key, uv_scale)

func _v(p: Array, y: float = 0.0) -> Vector3:
	return Vector3(float(p[0]), y, float(p[1]))

func _polygon(points: Array, height: float, key: String, base_y: float = 0.0) -> void:
	var flat: PackedVector2Array = PackedVector2Array()
	for p: Array in points:
		flat.append(Vector2(float(p[0]), float(p[1])))
	var indices: PackedInt32Array = Geometry2D.triangulate_polygon(flat)
	if indices.is_empty():
		return
	var surface: SurfaceTool = _batch_at(key, Vector3(flat[0].x, base_y, flat[0].y))
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
	# Optimized low-poly tree: trunk + 2 low-poly canopy volumes (~60 tris instead of 660 tris)
	_box(p + Vector3(0, 1.65 * scale_factor, 0), Vector3(0.32, 3.3, 0.32) * scale_factor, "trunk")
	var basis_main: Basis = Basis.from_scale(Vector3.ONE * scale_factor)
	_batch_at("leaf", p).append_from(_canopy_mesh_main, 0, Transform3D(basis_main, p + Vector3(0.0, 4.4, 0.0) * scale_factor))
	_batch_at("leaf_light", p).append_from(_canopy_mesh_sub, 0, Transform3D(basis_main, p + Vector3(0.55, 5.0, 0.30) * scale_factor))

func _streetlight(p: Vector3, side: float) -> void:
	_box(p + Vector3(0, 4.2, 0), Vector3(0.13, 7.8, 0.13), "metal")
	_box(p + Vector3(0, 7.95, -side * 1.15), Vector3(0.11, 0.11, 2.3), "metal")
	_box(p + Vector3(0, 7.90, -side * 2.15), Vector3(0.32, 0.08, 0.72), "lamp_glow")

func _bus_shelter(p: Vector3, side: float) -> void:
	var face_z: float = -side
	_box(p + Vector3(0, 2.28, 0), Vector3(4.4, 0.12, 1.85), "metal")
	_box(p + Vector3(0, 2.35, face_z * 0.85), Vector3(4.44, 0.14, 0.16), "blue")
	_box(p + Vector3(0, 1.15, -face_z * 0.78), Vector3(4.1, 1.95, 0.05), "glass")
	for x_off: float in [-2.05, 2.05]:
		_box(p + Vector3(x_off, 1.14, -face_z * 0.78), Vector3(0.09, 2.28, 0.09), "metal")
	_box(p + Vector3(0.3, 0.52, -face_z * 0.45), Vector3(2.6, 0.07, 0.46), "silver_metal")
	var post_p: Vector3 = p + Vector3(-2.65, 0, face_z * 0.55)
	_box(post_p + Vector3(0, 1.35, 0), Vector3(0.07, 2.7, 0.07), "metal")
	_box(post_p + Vector3(0, 2.35, 0), Vector3(0.42, 0.68, 0.06), "blue")

func _furniture(sections: Array) -> void:
	for i: int in range(5, sections.size() - 5, 14):
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
			if i % 42 == 5 and side > 0:
				var bus_p: Vector3 = p + Vector3(-5.2, 0, 0.2)
				if not _is_near_special_zone(bus_p) and map.get_road_distance(bus_p) > 1.1:
					_bus_shelter(bus_p, side)

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
	label.visibility_range_end = 115.0
	map.add_child(label)
	return label

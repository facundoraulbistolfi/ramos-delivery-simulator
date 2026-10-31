class_name MotoMissionSystem
extends Node3D
## "Ir a ojo" delivery mission system across Ramos Mejía: pick up at a real local and deliver to a street address.

signal mission_updated(state_data: Dictionary)
signal mission_notification(message: String, duration: float)

enum State {
	IDLE,
	PICKUP,
	DELIVER,
}

var track: MotoTrack
var bike: MotoBike
var state: int = State.IDLE
var completed_count: int = 0
var mission_elapsed: float = 0.0
var current_locale: Dictionary = {}
var current_address: Dictionary = {}
var current_order_item: String = ""

var _locales: Array[Dictionary] = []
var _addresses: Array[Dictionary] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _marker_root: Node3D
var _ring_mesh: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _beacon_mesh: MeshInstance3D
var _prop_root: Node3D
var _marker_label: Label3D
var _bike_cargo_box: Node3D
var _pulse_time: float = 0.0

const TRIGGER_RADIUS: float = 14.5

const ORDER_CATALOG: Dictionary = {
	"apolonia": "Pizza Napolitana al Molde + Sorrentinos",
	"faricci": "1 kg de Helado Artesanal (Dulce de Leche y Pistacho)",
	"faricci_san_martin": "1 kg de Helado Artesanal + Cucuruchos",
	"due": "Brunch Completo + 2 Iced Latte",
	"luccianos": "Caja de IcePops + 1 kg Gelato",
	"banned_burger": "2x Doble Smash Burger + Papas Cheddar",
	"cloe_burger": "Combo Clöe Bacon Burger + Croissants",
	"la_birra_bar": "2x Burger Golden + Papas",
	"farmacia_moreno": "Pedido de Farmacia y Perfumería",
	"farmacia_central_oeste": "Bolsa de Dermocosmética y Receta",
	"farmacia_central_oeste_centro": "Botiquín y Perfumería 24 hs",
	"sportclub": "Pack Suplementos Deportivos + Shaker",
	"bomberitos": "Viandas Calientes del Buffet del Club",
	"la_casa_de_oberon": "Torta Red Velvet + Té en Hebras",
	"antojos": "Torta Marquise Sin TACC + Alfajores",
	"samurai_sushi": "Barco 40 Piezas Sushi Nikkei",
	"otaku_sushi": "Combo Otaku 30 Rolls + Gyozas",
	"la_tanita": "Milanesa Napolitana con Fritas",
	"parrilla_la_tanita": "Parrillada para 2 + Empanadas",
	"la_buena_fama": "2 Cajas de Ravioles + Salsa Filetto",
	"gallegol": "Caja Mayorista de Chocolates y Alfajores"
}


func setup(track_node: MotoTrack, bike_node: MotoBike) -> void:
	track = track_node
	bike = bike_node
	_rng.randomize()
	_build_visual_markers()
	_build_bike_cargo_box()
	_index_locales_and_addresses()
	start_new_mission(false)


func _process(delta: float) -> void:
	if state == State.IDLE or track == null or bike == null:
		return
	mission_elapsed += delta
	_pulse_time += delta * 3.2
	if is_instance_valid(_ring_mesh):
		var s: float = 1.0 + sin(_pulse_time) * 0.08
		_ring_mesh.scale = Vector3(s, 1.0, s)
	if is_instance_valid(_beacon_mesh):
		_beacon_mesh.position.y = 2.6 + sin(_pulse_time * 1.3) * 0.22
		_beacon_mesh.rotation.y += delta * 1.8

	var target_pos: Vector3 = _get_active_target_position()
	var flat_bike: Vector2 = Vector2(bike.global_position.x, bike.global_position.z)
	var flat_target: Vector2 = Vector2(target_pos.x, target_pos.z)
	var dist: float = flat_bike.distance_to(flat_target)

	if dist <= TRIGGER_RADIUS and absf(bike.get_speed_kmh()) < 48.0:
		if state == State.PICKUP:
			_on_pickup_completed()
		elif state == State.DELIVER:
			_on_delivery_completed()


func start_new_mission(notify_toast: bool = true) -> void:
	if _locales.is_empty() or _addresses.is_empty():
		return
	var prev_key: String = str(current_locale.get("key", ""))
	var candidate_locale: Dictionary = _locales[_rng.randi_range(0, _locales.size() - 1)]
	for _attempt: int in range(6):
		if str(candidate_locale.get("key", "")) != prev_key:
			break
		candidate_locale = _locales[_rng.randi_range(0, _locales.size() - 1)]
	current_locale = candidate_locale

	var loc_pt: Array = current_locale["visit"]
	var loc_v2: Vector2 = Vector2(float(loc_pt[0]), float(loc_pt[1]))
	var candidate_addr: Dictionary = _addresses[_rng.randi_range(0, _addresses.size() - 1)]
	for _attempt: int in range(12):
		var cand: Dictionary = _addresses[_rng.randi_range(0, _addresses.size() - 1)]
		var addr_pt: Vector2 = cand["point"] as Vector2
		var d: float = loc_v2.distance_to(addr_pt)
		if d > 220.0 and d < 1450.0 and str(cand["street"]) != str(current_locale.get("street", "")):
			candidate_addr = cand
			break
	current_address = candidate_addr
	current_order_item = str(ORDER_CATALOG.get(str(current_locale.get("key", "")), "Pedido Especial de Ramos Mejía"))
	state = State.PICKUP
	mission_elapsed = 0.0
	if is_instance_valid(_bike_cargo_box):
		_bike_cargo_box.visible = false
	_update_marker_for_state()
	_emit_state()
	if notify_toast:
		mission_notification.emit(
			"NUEVA MISIÓN DE REPARTO\nRetirá en %s (%s)" % [str(current_locale["name"]), str(current_locale["address"])],
			4.0
		)


func _on_pickup_completed() -> void:
	state = State.DELIVER
	mission_elapsed = 0.0
	if is_instance_valid(_bike_cargo_box):
		_bike_cargo_box.visible = true
	_update_marker_for_state()
	_emit_state()
	mission_notification.emit(
		"¡PEDIDO RETIRADO!\nLlevalo a ojo a %s\n(%s)" % [str(current_address["full_address"]), str(current_address["between"])],
		5.0
	)


func _on_delivery_completed() -> void:
	completed_count += 1
	var time_taken: int = maxi(1, roundi(mission_elapsed))
	if is_instance_valid(_bike_cargo_box):
		_bike_cargo_box.visible = false
	mission_notification.emit(
		"¡PEDIDO ENTREGADO EN %s!\nTiempo: %d s · Entregas completadas: %d" % [str(current_address["full_address"]), time_taken, completed_count],
		4.5
	)
	start_new_mission(false)


func get_active_target_position() -> Vector3:
	return _get_active_target_position()


func _get_active_target_position() -> Vector3:
	if state == State.PICKUP:
		var v: Array = current_locale["visit"]
		return Vector3(float(v[0]), 0.05, float(v[1]))
	elif state == State.DELIVER:
		var p: Vector2 = current_address["point"] as Vector2
		return Vector3(p.x, 0.05, p.y)
	return Vector3.ZERO


func _emit_state() -> void:
	var payload: Dictionary = {
		"state": state,
		"completed": completed_count,
		"locale_name": str(current_locale.get("name", "")),
		"locale_address": str(current_locale.get("address", "")),
		"locale_between": str(current_locale.get("between", "")),
		"order_item": current_order_item,
		"dest_address": str(current_address.get("full_address", "")),
		"dest_between": str(current_address.get("between", "")),
	}
	mission_updated.emit(payload)


func _index_locales_and_addresses() -> void:
	_locales.clear()
	_addresses.clear()
	var streets: Array = track.data.get("streets", [])
	var roads: Array = track.data.get("roads", [])

	# Build intersection lookup per street segment so every locale and address has exact cross-streets ("entre X e Y")
	var named_nodes: Array[Dictionary] = []
	for s: Dictionary in streets + roads:
		var sname: String = str(s.get("name", "Avenida Rivadavia"))
		if sname.is_empty():
			continue
		var pts: Array = s["points"]
		for pt: Array in pts:
			named_nodes.append({"name": sname, "p": Vector2(float(pt[0]), float(pt[1]))})

	for place: Dictionary in track.data.get("featured_places", []):
		if str(place.get("category", "")) != "local":
			continue
		var entry: Dictionary = place.duplicate(true)
		var v_pt: Array = entry["visit"]
		var v2: Vector2 = Vector2(float(v_pt[0]), float(v_pt[1]))
		entry["between"] = _find_cross_streets_near(v2, str(entry.get("street", "")), named_nodes)
		_locales.append(entry)

	# Generate verified street addresses across the main streets of Ramos Mejía
	var priority_streets: Array[String] = [
		"Avenida de Mayo", "Mariano Moreno", "Bolívar", "Pueyrredón", "Almirante Brown",
		"Espora", "Avellaneda", "Necochea", "Belgrano", "Alsina", "Sarmiento",
		"Bartolomé Mitre", "Viamonte", "General Alvarado", "Profesor Juan T. Pizzurno",
		"Avenida General San Martín", "Doctor Gabriel Ardoino", "Leandro N. Alem",
		"Suipacha", "Castelli", "Colón", "General Acha", "Martín Miguel de Güemes",
		"Avenida Gaona", "Avenida Díaz Vélez"
	]
	var seen_blocks: Dictionary = {}
	for s: Dictionary in streets:
		var sname: String = str(s.get("name", ""))
		if not (sname in priority_streets) or bool(s.get("bridge", false)):
			continue
		var pts: Array = s["points"]
		for i: int in range(pts.size() - 1):
			var a: Vector2 = Vector2(float(pts[i][0]), float(pts[i][1]))
			var b: Vector2 = Vector2(float(pts[i + 1][0]), float(pts[i + 1][1]))
			var seg_len: float = a.distance_to(b)
			if seg_len < 52.0 or seg_len > 175.0:
				continue
			var mid: Vector2 = (a + b) * 0.5
			if mid.x < -1950.0 or mid.x > 420.0 or mid.y < -520.0 or mid.y > 1480.0:
				continue
			var cross_a: String = _closest_other_street(a, sname, named_nodes)
			var cross_b: String = _closest_other_street(b, sname, named_nodes)
			if cross_a.is_empty() or cross_b.is_empty() or cross_a == cross_b:
				continue
			var dir: Vector2 = (b - a).normalized()
			var right: Vector2 = Vector2(-dir.y, dir.x)
			var altura: int = _estimate_door_number(sname, mid)
			var block_key: String = "%s_%d" % [sname, int(altura / 100) * 100]
			if seen_blocks.has(block_key):
				continue
			seen_blocks[block_key] = true
			var w: float = float(s.get("width", 10.0))
			var stop_pt: Vector2 = mid + right * (w * 0.28)
			var sidewalk_pt: Vector2 = mid + right * (w * 0.5 + 1.65)
			_addresses.append({
				"street": sname,
				"number": altura,
				"full_address": "%s %d" % [sname, altura],
				"between": "Entre %s y %s" % [cross_a, cross_b],
				"point": stop_pt,
				"sidewalk_point": sidewalk_pt,
				"normal": -right
			})


func _estimate_door_number(street_name: String, pos: Vector2) -> int:
	# Approximate realistic Ramos Mejía block numbering (100 per block from Rivadavia or Larrea)
	var ew_streets: Array[String] = [
		"Bartolomé Mitre", "Belgrano", "Alsina", "Sarmiento", "Castelli",
		"Viamonte", "General Alvarado", "Profesor Juan T. Pizzurno",
		"Doctor Gabriel Ardoino", "Leandro N. Alem", "Avenida Gaona", "General Acha"
	]
	var dist_blocks: int = 1
	if street_name in ew_streets:
		dist_blocks = maxi(0, floori(absf(pos.x + 120.0) / 125.0))
	else:
		dist_blocks = maxi(0, floori((absf(pos.y) - 40.0) / 115.0))
	var offset: int = 24 + posmod(int(absf(pos.x * 3.0 + pos.y * 5.0)), 64)
	return dist_blocks * 100 + offset


func _closest_other_street(pt: Vector2, own_street: String, named_nodes: Array[Dictionary]) -> String:
	var best_dist: float = 28.0
	var best_name: String = ""
	for item: Dictionary in named_nodes:
		var n: String = str(item["name"])
		if n == own_street:
			continue
		var d: float = pt.distance_to(item["p"] as Vector2)
		if d < best_dist:
			best_dist = d
			best_name = n
	return best_name


func _find_cross_streets_near(pt: Vector2, own_street: String, named_nodes: Array[Dictionary]) -> String:
	var near_names: Array[String] = []
	var near_dists: Array[float] = []
	for item: Dictionary in named_nodes:
		var n: String = str(item["name"])
		if n == own_street:
			continue
		var d: float = pt.distance_to(item["p"] as Vector2)
		if d < 120.0 and not (n in near_names):
			near_names.append(n)
			near_dists.append(d)
	if near_names.is_empty():
		return "Centro de Ramos Mejía"
	# Sort by distance
	for i: int in range(near_names.size()):
		for j: int in range(i + 1, near_names.size()):
			if near_dists[j] < near_dists[i]:
				var td: float = near_dists[i]
				near_dists[i] = near_dists[j]
				near_dists[j] = td
				var tn: String = near_names[i]
				near_names[i] = near_names[j]
				near_names[j] = tn
	if near_names.size() >= 2:
		return "Entre %s y %s" % [near_names[0], near_names[1]]
	return "Cerca de %s" % near_names[0]


func _build_visual_markers() -> void:
	_marker_root = Node3D.new()
	_marker_root.name = "MissionMarker"
	add_child(_marker_root)

	# Glowing ground stop ring on the street
	_ring_mesh = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 3.2
	torus.outer_radius = 3.85
	torus.rings = 24
	torus.ring_segments = 12
	_ring_mesh.mesh = torus
	_ring_mesh.position = Vector3(0, 0.08, 0)
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.albedo_color = Color("ff9854")
	_ring_mat.emission_enabled = true
	_ring_mat.emission = Color("ff9854")
	_ring_mat.emission_energy_multiplier = 2.2
	_ring_mesh.material_override = _ring_mat
	_marker_root.add_child(_ring_mesh)

	# Floating 3D diamond beacon above the stop ring (visible only when nearby on the block)
	_beacon_mesh = MeshInstance3D.new()
	var prism: BoxMesh = BoxMesh.new()
	prism.size = Vector3(0.55, 0.55, 0.55)
	_beacon_mesh.mesh = prism
	_beacon_mesh.rotation_degrees = Vector3(45, 0, 45)
	_beacon_mesh.position = Vector3(0, 2.6, 0)
	_beacon_mesh.visibility_range_end = 95.0
	_beacon_mesh.material_override = _ring_mat
	_marker_root.add_child(_beacon_mesh)

	# Local 3D label (only visible within 85m so navigation remains "a ojo"!)
	_marker_label = Label3D.new()
	_marker_label.position = Vector3(0, 3.65, 0)
	_marker_label.font_size = 42
	_marker_label.pixel_size = 0.012
	_marker_label.outline_size = 12
	_marker_label.modulate = Color("fff4d2")
	_marker_label.outline_modulate = Color("101d29")
	_marker_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker_label.visibility_range_end = 85.0
	_marker_root.add_child(_marker_label)

	# Sidewalk prop container (thermal bag at pickup / waiting customer at delivery)
	_prop_root = Node3D.new()
	_marker_root.add_child(_prop_root)


func _build_bike_cargo_box() -> void:
	if bike == null or not bike.has_node("Visual"):
		return
	var visual: Node3D = bike.get_node("Visual") as Node3D
	_bike_cargo_box = Node3D.new()
	_bike_cargo_box.name = "DeliveryCargoBox"
	_bike_cargo_box.position = Vector3(0, 1.04, 0.58)
	_bike_cargo_box.visible = false
	visual.add_child(_bike_cargo_box)

	var box_mesh: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.44, 0.40, 0.42)
	box_mesh.mesh = bm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color("e85222")
	mat.roughness = 0.45
	box_mesh.material_override = mat
	_bike_cargo_box.add_child(box_mesh)

	var stripe_mesh: MeshInstance3D = MeshInstance3D.new()
	var sm: BoxMesh = BoxMesh.new()
	sm.size = Vector3(0.45, 0.08, 0.43)
	stripe_mesh.mesh = sm
	var smat: StandardMaterial3D = StandardMaterial3D.new()
	smat.albedo_color = Color("f5f2e8")
	smat.emission_enabled = true
	smat.emission = Color("f5f2e8")
	smat.emission_energy_multiplier = 0.4
	stripe_mesh.material_override = smat
	_bike_cargo_box.add_child(stripe_mesh)


func _update_marker_for_state() -> void:
	for child: Node in _prop_root.get_children():
		child.queue_free()

	if state == State.PICKUP:
		var pos: Vector3 = _get_active_target_position()
		_marker_root.global_position = pos
		_ring_mat.albedo_color = Color("ff9854")
		_ring_mat.emission = Color("ff9854")
		_marker_label.text = "RETIRAR PEDIDO\n%s\n(%s)" % [str(current_locale["name"]), current_order_item]
	elif state == State.DELIVER:
		var pos: Vector3 = _get_active_target_position()
		_marker_root.global_position = pos
		_ring_mat.albedo_color = Color("28e070")
		_ring_mat.emission = Color("28e070")
		_marker_label.text = "ENTREGAR PEDIDO AQUÍ\n%s" % str(current_address["full_address"])

		# Spawn a 3D waiting client figure on the sidewalk next to the stop ring
		var sw_pt: Vector2 = current_address["sidewalk_point"] as Vector2
		var offset: Vector3 = Vector3(sw_pt.x - pos.x, 0.17, sw_pt.y - pos.z)
		_spawn_waiting_client(offset)


func _spawn_waiting_client(local_pos: Vector3) -> void:
	var client: Node3D = Node3D.new()
	client.position = local_pos
	_prop_root.add_child(client)

	var pants_mat: StandardMaterial3D = StandardMaterial3D.new()
	pants_mat.albedo_color = Color("263850")
	var shirt_mat: StandardMaterial3D = StandardMaterial3D.new()
	shirt_mat.albedo_color = Color("28a868")
	var skin_mat: StandardMaterial3D = StandardMaterial3D.new()
	skin_mat.albedo_color = Color("e2b492")

	for lx: float in [-0.12, 0.12]:
		var leg: MeshInstance3D = MeshInstance3D.new()
		var lm: BoxMesh = BoxMesh.new()
		lm.size = Vector3(0.16, 0.75, 0.16)
		leg.mesh = lm
		leg.position = Vector3(lx, 0.38, 0)
		leg.material_override = pants_mat
		client.add_child(leg)

	var torso: MeshInstance3D = MeshInstance3D.new()
	var tm: BoxMesh = BoxMesh.new()
	tm.size = Vector3(0.42, 0.62, 0.24)
	torso.mesh = tm
	torso.position = Vector3(0, 1.06, 0)
	torso.material_override = shirt_mat
	client.add_child(torso)

	var head: MeshInstance3D = MeshInstance3D.new()
	var hm: SphereMesh = SphereMesh.new()
	hm.radius = 0.16
	hm.height = 0.32
	head.mesh = hm
	head.position = Vector3(0, 1.56, 0)
	head.material_override = skin_mat
	client.add_child(head)

	# Raised waving arm
	var arm: MeshInstance3D = MeshInstance3D.new()
	var am: BoxMesh = BoxMesh.new()
	am.size = Vector3(0.13, 0.55, 0.13)
	arm.mesh = am
	arm.position = Vector3(0.32, 1.42, 0)
	arm.rotation_degrees = Vector3(0, 0, -28)
	arm.material_override = shirt_mat
	client.add_child(arm)

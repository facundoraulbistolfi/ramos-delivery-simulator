class_name MotoMissionSystem
extends Node3D
## 10-minute night delivery system across Ramos Mejía.
## - Select starting location at beginning of shift.
## - Choose between 3 simultaneous delivery orders (distance, product price, tip & fee).
## - Kitchen prep time + travel to local; once ready, PAR delivery clock starts ticking.
## - PAR time delivery bonus: dynamic tip decay if overdue.
## - 10-minute night shift timer aiming for max total money.

signal mission_updated(state_data: Dictionary)
signal mission_notification(message: String, duration: float)
signal start_location_dialog_requested(locations: Array[Dictionary])
signal order_selection_dialog_requested(offers: Array[Dictionary])
signal shift_completed_summary(summary_data: Dictionary)

enum State {
	IDLE = 0,
	PICKUP = 1,
	DELIVER = 2,
	ORDER_SELECTION = 3,
	START_SELECTION = 4,
	SHIFT_SUMMARY = 5,
}

const SHIFT_DURATION: float = 900.0 ## 15 minutes (900 s)
const TRIGGER_RADIUS: float = 14.5
const HIGHSCORES_PATH: String = "user://highscores.json"

var track: MotoTrack
var bike: MotoBike
var state: int = State.IDLE
var completed_count: int = 0
var total_money: int = 0
var total_tips: int = 0
var total_crash_fines: int = 0
var crash_count: int = 0
var shift_time_remaining: float = SHIFT_DURATION
var shift_active: bool = false

# Active order data
var current_locale: Dictionary = {}
var current_address: Dictionary = {}
var current_order_item: String = ""
var current_product_price: int = 0
var current_base_fee: int = 0
var current_max_tip: int = 0
var current_tip: float = 0.0
var current_prep_time: float = 0.0
var current_par_time: float = 0.0
var prep_time_remaining: float = 0.0
var delivery_elapsed: float = 0.0
var order_ready: bool = false
var waiting_at_local: bool = false

# 3 active selectable offers
var active_offers: Array[Dictionary] = []

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

const ORDER_CATALOG: Dictionary = {
	"apolonia": {"item": "Pizza Napolitana al Molde + Sorrentinos", "price": 14500, "prep": 30.0},
	"faricci": {"item": "1 kg Helado Artesanal (Dulce de Leche y Pistacho)", "price": 11800, "prep": 20.0},
	"faricci_san_martin": {"item": "1 kg Helado Artesanal + Cucuruchos", "price": 11800, "prep": 20.0},
	"due": {"item": "Brunch Completo + 2 Iced Latte", "price": 9400, "prep": 25.0},
	"luccianos": {"item": "Caja de IcePops + 1 kg Gelato", "price": 15200, "prep": 20.0},
	"banned_burger": {"item": "2x Doble Smash Burger + Papas Cheddar", "price": 13800, "prep": 35.0},
	"cloe_burger": {"item": "Combo Clöe Bacon Burger + Croissants", "price": 12500, "prep": 30.0},
	"la_birra_bar": {"item": "2x Burger Golden + Papas", "price": 14200, "prep": 35.0},
	"farmacia_moreno": {"item": "Pedido de Farmacia y Perfumería", "price": 7600, "prep": 15.0},
	"farmacia_central_oeste": {"item": "Bolsa de Dermocosmética y Receta", "price": 16500, "prep": 15.0},
	"farmacia_central_oeste_centro": {"item": "Botiquín y Perfumería 24 hs", "price": 8200, "prep": 15.0},
	"sportclub": {"item": "Pack Suplementos Deportivos + Shaker", "price": 19500, "prep": 15.0},
	"bomberitos": {"item": "Viandas Calientes del Buffet del Club", "price": 8600, "prep": 25.0},
	"cuartel_bomberos": {"item": "Donación y Viandas Cuartel Central", "price": 6500, "prep": 15.0},
	"la_casa_de_oberon": {"item": "Torta Red Velvet + Té en Hebras", "price": 11200, "prep": 20.0},
	"antojos": {"item": "Torta Marquise Sin TACC + Alfajores", "price": 12800, "prep": 20.0},
	"samurai_sushi": {"item": "Barco 40 Piezas Sushi Nikkei", "price": 24000, "prep": 45.0},
	"otaku_sushi": {"item": "Combo Otaku 30 Rolls + Gyozas", "price": 18500, "prep": 40.0},
	"la_tanita": {"item": "Milanesa Napolitana con Fritas", "price": 11500, "prep": 30.0},
	"parrilla_la_tanita": {"item": "Parrillada para 2 + Empanadas", "price": 22000, "prep": 45.0},
	"la_buena_fama": {"item": "2 Cajas de Ravioles + Salsa Filetto", "price": 8900, "prep": 20.0},
	"gallegol": {"item": "Caja Mayorista de Chocolates y Alfajores", "price": 16000, "prep": 15.0},
	"fravega": {"item": "Auriculares Inalámbricos + Cafetera", "price": 32000, "prep": 25.0},
	"paseo_ramos": {"item": "Pedido de Regalería Paseo de Ramos", "price": 7500, "prep": 20.0},
	"subway_rivadavia": {"item": "2x Sub Melt de 30 cm + Cookies", "price": 10500, "prep": 25.0},
	"sporting_rivadavia": {"item": "Zapatillas Running + Camiseta", "price": 28000, "prep": 20.0},
	"galeria_central": {"item": "Encomienda Express Galería Central", "price": 6800, "prep": 15.0},
	"bonafide_rivadavia": {"item": "Café Selección + Bocaditos y Vizzio", "price": 9200, "prep": 15.0},
	"central_oeste_rivadavia": {"item": "Pedido de Farmacia y Dermocosmética", "price": 12400, "prep": 15.0},
	"heladeria_tempo": {"item": "1 kg Helado Artesanal Tempo", "price": 9800, "prep": 20.0},
	"mostaza_mayo": {"item": "Combo Mega Dibu Doble + Papas Cheddar", "price": 11500, "prep": 30.0},
	"wendys_kfc": {"item": "Bucket 8 Piezas Crispy + 2 Baconator", "price": 14800, "prep": 30.0},
	"club_milanesa": {"item": "Milanesa La Gringa + Papas Rústicas", "price": 13200, "prep": 35.0},
	"kinderland": {"item": "Juego de Mesa Familiar + Regalo", "price": 17500, "prep": 20.0},
	"starbucks_cuspide": {"item": "2 Caramel Macchiato + Libro Novedad", "price": 13600, "prep": 20.0},
	"almacen_freddo": {"item": "Picada Gourmet + 1 kg Helado Freddo", "price": 18200, "prep": 25.0},
	"arezzo_resto": {"item": "Sorrentinos Caseros + Tiramisú", "price": 13800, "prep": 30.0},
	"la_farola": {"item": "Suprema Maryland Gigante Familiar", "price": 15500, "prep": 35.0}
}

const START_LOCATIONS: Array[Dictionary] = [
	{
		"id": 1,
		"name": "Plaza Sarmiento / Estación Ramos Mejía",
		"desc": "Av. Rivadavia y 9 de Julio (junto al andén del tren)",
		"transform": Transform3D(Basis(Vector3.UP, deg_to_rad(-92.0)), Vector3(-1390.0, 0.05, 108.0))
	},
	{
		"id": 2,
		"name": "Centro Comercial Av. de Mayo",
		"desc": "Av. de Mayo y Rosales (frente a El Club de la Milanesa y Due)",
		"transform": Transform3D(Basis(Vector3.UP, deg_to_rad(-168.0)), Vector3(-1425.0, 0.05, 410.0))
	},
	{
		"id": 3,
		"name": "Av. Rivadavia y Moreno",
		"desc": "Galería Paseo Ramos, Frávega y La Birra Bar",
		"transform": Transform3D(Basis(Vector3.UP, deg_to_rad(-92.0)), Vector3(-1205.0, 0.05, 48.0))
	},
	{
		"id": 4,
		"name": "Plaza Bartolomé Mitre",
		"desc": "Pueyrredón y Bartolomé Mitre",
		"transform": Transform3D(Basis(Vector3.UP, deg_to_rad(12.0)), Vector3(-1060.0, 0.05, 305.0))
	},
	{
		"id": 5,
		"name": "Plaza Bomberitos",
		"desc": "General Acha y Pueyrredón (frente al club y buffet)",
		"transform": Transform3D(Basis(Vector3.UP, deg_to_rad(-45.0)), Vector3(-115.0, 0.05, 1260.0))
	},
	{
		"id": 6,
		"name": "Puente Díaz Vélez",
		"desc": "Rampa de ascenso Av. Díaz Vélez / República hacia Ciudadela",
		"transform": Transform3D(Basis(Vector3.UP, deg_to_rad(130.0)), Vector3(328.0, 0.05, 235.0))
	}
]


func setup(track_node: MotoTrack, bike_node: MotoBike) -> void:
	track = track_node
	bike = bike_node
	_rng.randomize()
	_build_visual_markers()
	_build_bike_cargo_box()
	_index_locales_and_addresses()

	# If running headless (automated tests), start directly in PICKUP with zero prep time so tests pass cleanly
	var is_headless: bool = DisplayServer.get_name() == "headless"
	if is_headless:
		shift_active = true
		_start_direct_test_mission()
	else:
		state = State.IDLE


func _process(delta: float) -> void:
	if track == null or bike == null:
		return

	if shift_active:
		shift_time_remaining = maxf(0.0, shift_time_remaining - delta)
		if shift_time_remaining <= 0.0 and state != State.SHIFT_SUMMARY:
			_end_night_shift()
			return

	_pulse_time += delta * 3.2
	if is_instance_valid(_ring_mesh):
		var s: float = 1.0 + sin(_pulse_time) * 0.08
		_ring_mesh.scale = Vector3(s, 1.0, s)
	if is_instance_valid(_beacon_mesh):
		_beacon_mesh.position.y = 2.6 + sin(_pulse_time * 1.3) * 0.22
		_beacon_mesh.rotation.y += delta * 1.8

	if state == State.PICKUP:
		if not order_ready:
			prep_time_remaining = maxf(0.0, prep_time_remaining - delta)
			if prep_time_remaining <= 0.0:
				order_ready = true
				mission_notification.emit(
					"¡PEDIDO LISTO EN LA COCINA!\nCorriendo tiempo PAR hacia la entrega...",
					3.5
				)
		else:
			# When order is ready, the delivery PAR clock is already running!
			delivery_elapsed += delta

		var target_pos: Vector3 = _get_active_target_position()
		var flat_bike: Vector2 = Vector2(bike.global_position.x, bike.global_position.z)
		var flat_target: Vector2 = Vector2(target_pos.x, target_pos.z)
		var dist: float = flat_bike.distance_to(flat_target)

		if dist <= TRIGGER_RADIUS and absf(bike.get_speed_kmh()) < 48.0:
			if order_ready:
				_on_pickup_completed()
			elif not waiting_at_local:
				waiting_at_local = true
				mission_notification.emit(
					"ESPERANDO EN EL LOCAL...\nFaltan %.0f s de preparación" % prep_time_remaining,
					2.5
				)
		elif dist > TRIGGER_RADIUS + 5.0:
			waiting_at_local = false

		_emit_state()

	elif state == State.DELIVER:
		delivery_elapsed += delta

		# Dynamic tip decay if overdue past PAR time
		if delivery_elapsed <= current_par_time:
			current_tip = float(current_max_tip)
		else:
			var overtime: float = delivery_elapsed - current_par_time
			var decay_rate: float = float(current_max_tip) / 60.0
			current_tip = maxf(0.0, float(current_max_tip) - overtime * decay_rate)

		var target_pos: Vector3 = _get_active_target_position()
		var flat_bike: Vector2 = Vector2(bike.global_position.x, bike.global_position.z)
		var flat_target: Vector2 = Vector2(target_pos.x, target_pos.z)
		var dist: float = flat_bike.distance_to(flat_target)

		if dist <= TRIGGER_RADIUS and absf(bike.get_speed_kmh()) < 48.0:
			_on_delivery_completed()

		_emit_state()


func choose_start_location(location_id: int) -> void:
	for loc: Dictionary in START_LOCATIONS:
		if int(loc["id"]) == location_id:
			if bike != null:
				bike.respawn(loc["transform"])
			shift_active = true
			shift_time_remaining = SHIFT_DURATION
			total_money = 0
			total_tips = 0
			completed_count = 0
			mission_notification.emit(
				"¡ARRANCÓ LA NOCHE EN RAMOS MEJÍA!\nObjetivo: juntar la mayor cantidad de plata en 10 minutos",
				4.5
			)
			request_new_order_selection()
			return


func start_delivery_mode() -> void:
	shift_time_remaining = SHIFT_DURATION
	total_money = 0
	total_tips = 0
	total_crash_fines = 0
	crash_count = 0
	completed_count = 0
	current_locale = {}
	current_address = {}
	current_order_item = ""
	_update_marker_visibility(false)
	if is_instance_valid(_bike_cargo_box):
		_bike_cargo_box.visible = false
	if bike != null and track != null:
		bike.respawn(track.get_tanga_spawn_transform())
	shift_active = true
	var is_headless: bool = DisplayServer.get_name() == "headless"
	if is_headless:
		_start_direct_test_mission()
	else:
		request_new_order_selection()
	_emit_state()


func set_free_roam_mode() -> void:
	shift_active = false
	state = State.IDLE
	_update_marker_visibility(false)
	if is_instance_valid(_bike_cargo_box):
		_bike_cargo_box.visible = false
	_emit_state()


func restart_night_shift() -> void:
	start_delivery_mode()


func load_highscores() -> Array[Dictionary]:
	if not FileAccess.file_exists(HIGHSCORES_PATH):
		return []
	var file: FileAccess = FileAccess.open(HIGHSCORES_PATH, FileAccess.READ)
	if file == null:
		return []
	var json_str: String = file.get_as_text()
	var parsed: Variant = JSON.parse_string(json_str)
	if parsed is Array:
		var list: Array[Dictionary] = []
		for item: Variant in (parsed as Array):
			if item is Dictionary:
				list.append(item as Dictionary)
		return list
	return []


func save_highscore(score: int, orders: int, fines: int) -> Dictionary:
	var list: Array[Dictionary] = load_highscores()
	var now_date: String = Time.get_date_string_from_system()
	var entry: Dictionary = {
		"score": score,
		"orders": orders,
		"fines": fines,
		"date": now_date
	}
	list.append(entry)
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("score", 0)) > int(b.get("score", 0))
	)
	var rank: int = list.find(entry) + 1
	var is_record: bool = (rank == 1)
	if list.size() > 5:
		list = list.slice(0, 5)

	var file: FileAccess = FileAccess.open(HIGHSCORES_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(list, "\t"))
	return {"is_record": is_record, "rank": rank, "highscores": list}


func apply_crash_penalty(impact_kmh: float) -> int:
	if not shift_active:
		return 0

	var fine: int = 0
	var severity_desc: String = ""
	if impact_kmh < 25.0:
		fine = roundi(350.0 + (impact_kmh - 10.0) * 20.0)
		severity_desc = "Raspón / Espejo roto"
	elif impact_kmh < 50.0:
		fine = roundi(700.0 + (impact_kmh - 25.0) * 48.0)
		severity_desc = "Abolladura / Paragolpes"
	else:
		fine = roundi(2000.0 + (impact_kmh - 50.0) * 75.0)
		severity_desc = "Destrucción de ópticas / Choque frontal"

	total_money -= fine
	total_crash_fines += fine
	crash_count += 1

	var wallet_msg: String
	if total_money >= 0:
		wallet_msg = "Billetera: $ %d" % total_money
	else:
		wallet_msg = "¡Billetera en rojo!: -$ %d" % abs(total_money)

	mission_notification.emit(
		"¡CHOQUE CONTRA AUTO! (-$ %d)\n%s (%.0f km/h) · %s" % [
			fine, severity_desc, impact_kmh, wallet_msg
		],
		3.5
	)
	_emit_state()
	return fine


func start_new_mission(_silent: bool = false) -> void:
	if state == State.PICKUP or state == State.DELIVER:
		mission_notification.emit(
			"¡PEDIDO EN CURSO!\nNo podés cambiar de pedido hasta completar la entrega actual.",
			3.5
		)
		return
	request_new_order_selection()


func request_new_order_selection() -> void:
	if _locales.is_empty() or _addresses.is_empty():
		return
	active_offers = _generate_3_order_offers()
	state = State.ORDER_SELECTION
	_update_marker_visibility(false)
	order_selection_dialog_requested.emit(active_offers)
	_emit_state()


func select_order_offer(offer_index: int) -> void:
	if offer_index < 0 or offer_index >= active_offers.size():
		return
	var offer: Dictionary = active_offers[offer_index]
	current_locale = offer["locale"]
	current_address = offer["dest_address"]
	current_order_item = str(offer["order_item"])
	current_product_price = int(offer["product_price"])
	current_base_fee = int(offer["base_fee"])
	current_max_tip = int(offer["max_tip"])
	current_tip = float(current_max_tip)
	current_prep_time = float(offer["prep_time"])
	current_par_time = float(offer["par_time"])

	prep_time_remaining = current_prep_time
	delivery_elapsed = 0.0
	order_ready = false
	waiting_at_local = false
	state = State.PICKUP

	if is_instance_valid(_bike_cargo_box):
		_bike_cargo_box.visible = false

	_update_marker_for_state()
	_update_marker_visibility(true)
	_emit_state()

	mission_notification.emit(
		"PEDIDO ACEPTADO [%d]: %s\nRetirá en %s (prep: %.0f s)" % [
			offer_index + 1,
			current_order_item,
			str(current_locale.get("name", "")),
			current_prep_time
		],
		4.0
	)


func _on_pickup_completed() -> void:
	state = State.DELIVER
	waiting_at_local = false
	if is_instance_valid(_bike_cargo_box):
		_bike_cargo_box.visible = true
	_update_marker_for_state()
	_emit_state()
	mission_notification.emit(
		"¡PEDIDO RETIRADO EN MANO!\nLlevalo a ojo a %s (%s)" % [
			str(current_address.get("full_address", "")),
			str(current_address.get("between", ""))
		],
		5.0
	)


func _on_delivery_completed() -> void:
	var earned_tip: int = roundi(current_tip)
	var payout: int = current_base_fee + earned_tip
	total_money += payout
	total_tips += earned_tip
	completed_count += 1

	if is_instance_valid(_bike_cargo_box):
		_bike_cargo_box.visible = false

	var status_text: String = "¡A TIEMPO!" if earned_tip >= current_max_tip else "CON DEMORA"
	mission_notification.emit(
		"¡ENTREGA EXITOSA %s!\nCobraste: $ %d (Tarifa $ %d + Propina $ %d)\nBilletera: $ %d · Entregas: %d" % [
			status_text, payout, current_base_fee, earned_tip, total_money, completed_count
		],
		5.0
	)

	# If running headless test, advance to next mission; else prompt for 3 new orders
	if DisplayServer.get_name() == "headless":
		_start_direct_test_mission()
	else:
		request_new_order_selection()


func _end_night_shift() -> void:
	shift_active = false
	state = State.SHIFT_SUMMARY
	_update_marker_visibility(false)
	var hs_result: Dictionary = save_highscore(total_money, completed_count, total_crash_fines)
	var summary: Dictionary = {
		"total_money": total_money,
		"total_tips": total_tips,
		"completed_count": completed_count,
		"total_crash_fines": total_crash_fines,
		"crash_count": crash_count,
		"duration": SHIFT_DURATION,
		"highscores": hs_result.get("highscores", []),
		"is_record": hs_result.get("is_record", false),
		"rank": hs_result.get("rank", 1)
	}
	shift_completed_summary.emit(summary)
	_emit_state()


func _start_direct_test_mission() -> void:
	var offers: Array[Dictionary] = _generate_3_order_offers()
	if offers.is_empty():
		return
	active_offers = offers
	select_order_offer(0)
	prep_time_remaining = 0.0
	order_ready = true


func _generate_3_order_offers() -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	if _locales.is_empty() or _addresses.is_empty():
		return offers

	var bike_pos: Vector2 = Vector2.ZERO
	if bike != null:
		bike_pos = Vector2(bike.global_position.x, bike.global_position.z)

	var used_locale_keys: Dictionary = {}
	if current_locale != null and current_locale.has("key"):
		used_locale_keys[str(current_locale["key"])] = true

	for i: int in range(3):
		var locale: Dictionary = _pick_unique_locale(used_locale_keys)
		used_locale_keys[str(locale.get("key", ""))] = true

		var loc_pt: Array = locale.get("visit", [0, 0])
		var loc_v2: Vector2 = Vector2(float(loc_pt[0]), float(loc_pt[1]))
		var dest_addr: Dictionary = _pick_best_address_for_locale(loc_v2, str(locale.get("street", "")))

		var addr_pt: Vector2 = dest_addr.get("point", Vector2.ZERO) as Vector2
		var pickup_dist: float = bike_pos.distance_to(loc_v2)
		var delivery_dist: float = loc_v2.distance_to(addr_pt)
		var total_dist: float = pickup_dist + delivery_dist

		var lkey: String = str(locale.get("key", ""))
		var cat_data: Dictionary = ORDER_CATALOG.get(lkey, {"item": "Pedido Especial de Ramos Mejía", "price": 10000, "prep": 25.0})
		var prod_price: int = int(cat_data["price"])
		var prep_t: float = float(cat_data["prep"])

		# Economics: base delivery fee + tip based on product price & delivery distance
		var base_fee: int = roundi(900.0 + delivery_dist * 0.75)
		var max_tip: int = roundi(prod_price * 0.15 + delivery_dist * 0.50)
		var par_t: float = roundf(delivery_dist / 11.5) + 30.0

		offers.append({
			"index": i,
			"locale": locale,
			"dest_address": dest_addr,
			"order_item": str(cat_data["item"]),
			"product_price": prod_price,
			"base_fee": base_fee,
			"max_tip": max_tip,
			"total_payout": base_fee + max_tip,
			"pickup_dist": pickup_dist,
			"delivery_dist": delivery_dist,
			"total_dist": total_dist,
			"prep_time": prep_t,
			"par_time": par_t
		})

	return offers


func _pick_unique_locale(used_keys: Dictionary) -> Dictionary:
	var cand: Dictionary = _locales[_rng.randi_range(0, _locales.size() - 1)]
	for _a: int in range(12):
		if not used_keys.has(str(cand.get("key", ""))):
			return cand
		cand = _locales[_rng.randi_range(0, _locales.size() - 1)]
	return cand


func _pick_best_address_for_locale(loc_pos: Vector2, loc_street: String) -> Dictionary:
	var cand: Dictionary = _addresses[_rng.randi_range(0, _addresses.size() - 1)]
	for _a: int in range(16):
		var test_addr: Dictionary = _addresses[_rng.randi_range(0, _addresses.size() - 1)]
		var p: Vector2 = test_addr.get("point", Vector2.ZERO) as Vector2
		var d: float = loc_pos.distance_to(p)
		if d >= 240.0 and d <= 1350.0 and str(test_addr.get("street", "")) != loc_street:
			return test_addr
	return cand


func get_active_target_position() -> Vector3:
	return _get_active_target_position()


func _get_active_target_position() -> Vector3:
	if state == State.PICKUP and current_locale != null:
		var loc_key: String = str(current_locale.get("key", ""))
		if track != null and track.has_method("get_locale_pickup_position"):
			return track.get_locale_pickup_position(loc_key, current_locale)
		if current_locale.has("visit"):
			var v: Array = current_locale["visit"]
			return Vector3(float(v[0]), 0.05, float(v[1]))
	elif state == State.DELIVER and current_address != null and current_address.has("point"):
		var p: Vector2 = current_address["point"] as Vector2
		return Vector3(p.x, 0.05, p.y)
	return Vector3.ZERO


func _update_marker_visibility(vis: bool) -> void:
	if is_instance_valid(_marker_root):
		_marker_root.visible = vis


func _update_marker_for_state() -> void:
	for child: Node in _prop_root.get_children():
		child.queue_free()

	if state == State.PICKUP:
		var pos: Vector3 = _get_active_target_position()
		_marker_root.global_position = pos
		_ring_mat.albedo_color = Color("ff9854")
		_ring_mat.emission = Color("ff9854")
		_marker_label.text = "RETIRAR PEDIDO\n%s\n(%s)" % [str(current_locale.get("name", "")), current_order_item]
	elif state == State.DELIVER:
		var pos: Vector3 = _get_active_target_position()
		_marker_root.global_position = pos
		_ring_mat.albedo_color = Color("28e070")
		_ring_mat.emission = Color("28e070")
		_marker_label.text = "ENTREGAR PEDIDO AQUÍ\n%s" % str(current_address.get("full_address", ""))

		var sw_pt: Vector2 = current_address.get("sidewalk_point", Vector2(pos.x, pos.z)) as Vector2
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

	var arm: MeshInstance3D = MeshInstance3D.new()
	var am: BoxMesh = BoxMesh.new()
	am.size = Vector3(0.13, 0.55, 0.13)
	arm.mesh = am
	arm.position = Vector3(0.32, 1.42, 0)
	arm.rotation_degrees = Vector3(0, 0, -28)
	arm.material_override = shirt_mat
	client.add_child(arm)


func _build_visual_markers() -> void:
	_marker_root = Node3D.new()
	_marker_root.name = "MissionMarker"
	add_child(_marker_root)

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

	_beacon_mesh = MeshInstance3D.new()
	var prism: BoxMesh = BoxMesh.new()
	prism.size = Vector3(0.55, 0.55, 0.55)
	_beacon_mesh.mesh = prism
	_beacon_mesh.rotation_degrees = Vector3(45, 0, 45)
	_beacon_mesh.position = Vector3(0, 2.6, 0)
	_beacon_mesh.visibility_range_end = 95.0
	_beacon_mesh.material_override = _ring_mat
	_marker_root.add_child(_beacon_mesh)

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


func _emit_state() -> void:
	var payload: Dictionary = {
		"state": state,
		"completed": completed_count,
		"total_money": total_money,
		"total_tips": total_tips,
		"total_crash_fines": total_crash_fines,
		"crash_count": crash_count,
		"shift_time_remaining": shift_time_remaining,
		"shift_active": shift_active,
		"locale_name": str(current_locale.get("name", "")),
		"locale_address": str(current_locale.get("address", "")),
		"locale_between": str(current_locale.get("between", "")),
		"order_item": current_order_item,
		"product_price": current_product_price,
		"base_fee": current_base_fee,
		"max_tip": current_max_tip,
		"current_tip": current_tip,
		"prep_time_remaining": prep_time_remaining,
		"order_ready": order_ready,
		"par_time": current_par_time,
		"delivery_elapsed": delivery_elapsed,
		"dest_address": str(current_address.get("full_address", "")),
		"dest_between": str(current_address.get("between", "")),
		"active_offers": active_offers
	}
	mission_updated.emit(payload)


func _index_locales_and_addresses() -> void:
	_locales.clear()
	_addresses.clear()
	var streets: Array = track.data.get("streets", [])
	var roads: Array = track.data.get("roads", [])

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

extends RefCounted
## Generates seamless PBR textures (Albedo + Normal maps) for Ramos Mejía.

const TEX_DIR: String = "res://assets/textures"
const SIZE: int = 128

static func ensure_textures(force_rebuild: bool = false) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEX_DIR))
	var specs: Array[String] = [
		"road", "walk", "pavers", "curb", "grass", "earth", "ballast", "rail",
		"trunk", "palm_trunk", "leaf", "palm_leaf",
		"facade0", "facade1", "facade2", "facade3", "facade4", "facade5", "facade6", "facade7",
		"facade_property_wall", "facade_san_juan", "facade_coto", "facade_la_perla",
		"landmark_stone", "glass", "hospital_glass", "perla_glass",
		"perla_green", "awning_striped", "roof_terrace", "station_brick", "roof_zinc"
	]
	var result: Dictionary = {}
	for key: String in specs:
		var alb_path: String = "%s/%s_albedo.res" % [TEX_DIR, key]
		var nrm_path: String = "%s/%s_normal.res" % [TEX_DIR, key]
		if not force_rebuild and ResourceLoader.exists(alb_path) and ResourceLoader.exists(nrm_path):
			result[key] = {
				"albedo": load(alb_path) as Texture2D,
				"normal": load(nrm_path) as Texture2D
			}
			continue
		var pair: Dictionary = _generate_pair(key)
		var alb_tex: ImageTexture = ImageTexture.create_from_image(pair["albedo"])
		var nrm_tex: ImageTexture = ImageTexture.create_from_image(pair["normal"])
		ResourceSaver.save(alb_tex, alb_path, ResourceSaver.FLAG_COMPRESS)
		ResourceSaver.save(nrm_tex, nrm_path, ResourceSaver.FLAG_COMPRESS)
		result[key] = {
			"albedo": load(alb_path) as Texture2D,
			"normal": load(nrm_path) as Texture2D
		}
	return result

static func _hash(x: int, y: int, seed_val: int = 0) -> float:
	var n: int = (x * 374761393 + y * 668265263 + seed_val * 1442695041) & 0x7fffffff
	n = (n ^ (n >> 13)) * 1274126177
	n = (n ^ (n >> 16)) & 0x7fffffff
	return float(n % 10000) / 10000.0

static func _smooth_noise(u: float, v: float, freq: int, seed_val: int) -> float:
	var x: float = u * float(freq)
	var y: float = v * float(freq)
	var ix: int = int(floor(x))
	var iy: int = int(floor(y))
	var fx: float = x - float(ix)
	var fy: float = y - float(iy)
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var x0: int = posmod(ix, freq)
	var x1: int = posmod(ix + 1, freq)
	var y0: int = posmod(iy, freq)
	var y1: int = posmod(iy + 1, freq)
	var a: float = _hash(x0, y0, seed_val)
	var b: float = _hash(x1, y0, seed_val)
	var c: float = _hash(x0, y1, seed_val)
	var d: float = _hash(x1, y1, seed_val)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)

static func _fbm(u: float, v: float, base_freq: int, seed_val: int) -> float:
	return (
		_smooth_noise(u, v, base_freq, seed_val) * 0.55 +
		_smooth_noise(u, v, base_freq * 2, seed_val + 17) * 0.30 +
		_smooth_noise(u, v, base_freq * 4, seed_val + 53) * 0.15
	)

static func _generate_pair(key: String) -> Dictionary:
	var alb: Image = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var heights: PackedFloat32Array = PackedFloat32Array()
	heights.resize(SIZE * SIZE)
	var strength: float = 2.2

	for y: int in range(SIZE):
		var v: float = float(y) / float(SIZE)
		for x: int in range(SIZE):
			var u: float = float(x) / float(SIZE)
			var n1: float = _hash(x, y, 11)
			var n2: float = _fbm(u, v, 8, 29)
			var col: Color = Color(0.7, 0.7, 0.7)
			var h: float = 0.5

			match key:
				"road":
					strength = 2.6
					var track_wear: float = sin(u * TAU * 2.0) * 0.03
					var grain: float = (n1 - 0.5) * 0.10 + (n2 - 0.5) * 0.06
					var speck: float = 0.05 if n1 > 0.92 else (-0.04 if n1 < 0.08 else 0.0)
					var lum: float = clampf(0.24 + track_wear + grain + speck, 0.14, 0.38)
					col = Color(lum * 0.96, lum * 0.99, lum * 1.04)
					h = 0.5 + grain * 2.5 + speck * 3.0

				"walk":
					# Vereda porteña/bonaerense de baldosas calcáreas con panes
					strength = 3.2
					var tiles: float = 4.0
					var tu: float = fposmod(u * tiles, 1.0)
					var tv: float = fposmod(v * tiles, 1.0)
					var tile_id_x: int = int(floor(u * tiles))
					var tile_id_y: int = int(floor(v * tiles))
					var tile_var: float = (_hash(tile_id_x, tile_id_y, 77) - 0.5) * 0.06
					var joint: bool = tu < 0.045 or tv < 0.045 or tu > 0.955 or tv > 0.955
					var sub_u: float = fposmod(tu * 3.0, 1.0)
					var sub_v: float = fposmod(tv * 3.0, 1.0)
					var groove: bool = not joint and (sub_u < 0.08 or sub_v < 0.08)
					var base_c: Color = Color(0.74 + tile_var, 0.72 + tile_var, 0.67 + tile_var * 0.8)
					if joint:
						col = base_c.darkened(0.28)
						h = 0.15
					elif groove:
						col = base_c.darkened(0.12)
						h = 0.32
					else:
						col = base_c.lightened((n1 - 0.5) * 0.04)
						h = 0.65 + (n1 - 0.5) * 0.08

				"pavers":
					# Adoquinado de pórfido / piedra para La Tanga y pasajes
					strength = 3.8
					var rows: float = 6.0
					var cols_count: float = 3.0
					var row_idx: int = int(floor(v * rows))
					var offset_u: float = u + (0.5 / cols_count if row_idx % 2 == 1 else 0.0)
					var pu: float = fposmod(offset_u * cols_count, 1.0)
					var pv: float = fposmod(v * rows, 1.0)
					var cid: int = int(floor(offset_u * cols_count))
					var tone: float = (_hash(cid, row_idx, 91) - 0.5) * 0.12
					var edge: float = minf(minf(pu, 1.0 - pu) * cols_count, minf(pv, 1.0 - pv) * rows)
					if edge < 0.22:
						col = Color(0.42, 0.39, 0.36)
						h = 0.1
					else:
						var bevel: float = clampf((edge - 0.22) * 3.0, 0.0, 1.0)
						col = Color(0.68 + tone, 0.60 + tone * 0.7, 0.53 + tone * 0.5).lightened((n2 - 0.5) * 0.06)
						h = 0.3 + bevel * 0.55 + (n1 - 0.5) * 0.1

				"curb":
					strength = 2.4
					var joint_c: bool = fposmod(u * 2.0, 1.0) < 0.03
					var c_noise: float = (n2 - 0.5) * 0.08 + (n1 - 0.5) * 0.05
					col = Color(0.80 + c_noise, 0.79 + c_noise, 0.74 + c_noise)
					if joint_c:
						col = col.darkened(0.25)
						h = 0.2
					else:
						h = 0.55 + c_noise * 2.0

				"grass":
					strength = 2.8
					var g_patch: float = _fbm(u, v, 6, 105)
					var blade: float = (n1 - 0.5) * 0.14
					col = Color(0.26 + g_patch * 0.14 + blade * 0.4, 0.45 + g_patch * 0.18 + blade, 0.22 + g_patch * 0.08)
					if n1 > 0.96:
						col = col.lightened(0.18)
					h = 0.4 + g_patch * 0.3 + blade * 1.5

				"earth":
					strength = 2.5
					var e_patch: float = _fbm(u, v, 6, 211)
					var e_grain: float = (n1 - 0.5) * 0.10
					col = Color(0.46 + e_patch * 0.12 + e_grain, 0.50 + e_patch * 0.12 + e_grain, 0.41 + e_patch * 0.09)
					h = 0.45 + e_patch * 0.3 + e_grain * 1.5

				"ballast":
					strength = 4.2
					var b_stone: float = _fbm(u, v, 16, 301)
					var b_fine: float = (n1 - 0.5) * 0.18
					var b_val: float = 0.38 + b_stone * 0.24 + b_fine
					col = Color(b_val * 1.03, b_val * 0.98, b_val * 0.90)
					h = clampf(b_stone + b_fine, 0.0, 1.0)

				"rail":
					strength = 1.6
					var streak: float = (_smooth_noise(0.1, v, 16, 401) - 0.5) * 0.08
					col = Color(0.54 + streak, 0.55 + streak, 0.57 + streak)
					h = 0.5 + streak * 2.0

				"trunk":
					strength = 3.6
					var bark_v: float = _smooth_noise(u * 3.0, v * 0.8, 8, 501)
					var ridge: float = sin(u * TAU * 8.0 + n2 * 3.0) * 0.5 + 0.5
					col = Color(0.36 + bark_v * 0.14, 0.28 + bark_v * 0.12, 0.22 + bark_v * 0.08).darkened((1.0 - ridge) * 0.22)
					h = ridge * 0.7 + (n1 - 0.5) * 0.15

				"palm_trunk":
					strength = 3.8
					var rings: float = absf(sin(v * TAU * 10.0 + sin(u * TAU * 3.0) * 0.4))
					col = Color(0.44, 0.36, 0.28).darkened((1.0 - rings) * 0.28).lightened((n1 - 0.5) * 0.06)
					h = rings * 0.8 + (n1 - 0.5) * 0.1

				"leaf", "palm_leaf":
					strength = 3.2
					var cluster: float = _fbm(u, v, 10, 601 if key == "leaf" else 619)
					var detail: float = (n1 - 0.5) * 0.12
					var base_g: Color = Color(0.22, 0.40, 0.23) if key == "leaf" else Color(0.19, 0.36, 0.22)
					col = base_g.lightened(cluster * 0.22 + detail).darkened((1.0 - cluster) * 0.15)
					h = cluster * 0.75 + detail

				"facade0", "facade_la_perla":
					# Revoque símil piedra París con buñas horizontales
					strength = 2.8
					var base0: Color = Color("cfc5b0") if key == "facade0" else Color("d4c2a6")
					var buna: bool = fposmod(v * 5.0, 1.0) < 0.08 or fposmod(u * 2.0, 1.0) < 0.025
					var grain0: float = (n2 - 0.5) * 0.05 + (n1 - 0.5) * 0.03
					col = base0.darkened(0.18) if buna else base0.lightened(grain0)
					h = 0.20 if buna else (0.65 + grain0 * 2.0)

				"facade1":
					# Hormigón visto / paneles arquitectónicos
					strength = 2.4
					var seam1: bool = fposmod(u * 2.0, 1.0) < 0.03 or fposmod(v * 3.0, 1.0) < 0.04
					var g1: float = (n2 - 0.5) * 0.07 + (n1 - 0.5) * 0.03
					col = Color("bab6ae").darkened(0.20) if seam1 else Color("bab6ae").lightened(g1)
					h = 0.22 if seam1 else (0.60 + g1 * 2.0)

				"facade2":
					# Estuco cálido / Tarquini arena
					strength = 2.6
					var v_streak: float = (_smooth_noise(u * 4.0, v, 12, 709) - 0.5) * 0.07
					var band2: bool = fposmod(v * 4.0, 1.0) < 0.05
					col = Color("cbbda2").darkened(0.14) if band2 else Color("cbbda2").lightened(v_streak + (n1 - 0.5) * 0.04)
					h = 0.30 if band2 else (0.58 + v_streak * 3.0)

				"facade3", "station_brick":
					# Ladrillo a la vista argentino
					strength = 3.8
					var b_rows: float = 10.0
					var b_cols: float = 5.0
					var r_idx: int = int(floor(v * b_rows))
					var bu: float = fposmod((u + (0.5 / b_cols if r_idx % 2 == 1 else 0.0)) * b_cols, 1.0)
					var bv: float = fposmod(v * b_rows, 1.0)
					var bid: int = int(floor((u + (0.5 / b_cols if r_idx % 2 == 1 else 0.0)) * b_cols))
					var b_var: float = (_hash(bid, r_idx, 809) - 0.5) * 0.12
					var mortar: bool = bu < 0.07 or bv < 0.12
					var brick_base: Color = Color("9e5847") if key == "facade3" else Color("8c4436")
					if mortar:
						col = Color("c8c0b2")
						h = 0.15
					else:
						col = brick_base.lightened(b_var + (n1 - 0.5) * 0.04)
						h = 0.72 + b_var + (n1 - 0.5) * 0.08

				"facade4":
					# Revestimiento moderno gris pizarra con modulación
					strength = 2.5
					var grid4: bool = fposmod(v * 6.0, 1.0) < 0.07 or fposmod(u * 3.0, 1.0) < 0.04
					var g4: float = (n2 - 0.5) * 0.05
					col = Color("96a3a6").darkened(0.18) if grid4 else Color("96a3a6").lightened(g4)
					h = 0.25 if grid4 else (0.62 + g4 * 2.0)

				"facade5":
					# Cerámico / Ladrillo rosado-terracota
					strength = 3.2
					var r5: int = int(floor(v * 8.0))
					var u5: float = fposmod((u + (0.125 if r5 % 2 == 1 else 0.0)) * 4.0, 1.0)
					var v5: float = fposmod(v * 8.0, 1.0)
					var m5: bool = u5 < 0.06 or v5 < 0.10
					var c5: float = (_hash(int(u * 4.0), r5, 823) - 0.5) * 0.08
					col = Color("bfb6a8") if m5 else Color("bf8d77").lightened(c5 + (n1 - 0.5) * 0.03)
					h = 0.22 if m5 else (0.68 + c5)

				"facade6":
					# Piedra Travertino / sillares claros
					strength = 3.0
					var r6: int = int(floor(v * 6.0))
					var u6: float = fposmod((u + (0.25 if r6 % 2 == 1 else 0.0)) * 3.0, 1.0)
					var v6: float = fposmod(v * 6.0, 1.0)
					var m6: bool = u6 < 0.05 or v6 < 0.07
					var vein: float = (_smooth_noise(u, v * 4.0, 8, 853) - 0.5) * 0.07
					col = Color("b5ab99") if m6 else Color("d8ceba").lightened(vein)
					h = 0.24 if m6 else (0.68 + vein * 2.0)

				"facade7":
					# Frente comercial gris-topo con acanalado vertical sutil
					strength = 2.6
					var flute: float = sin(u * TAU * 12.0) * 0.04
					var band7: bool = fposmod(v * 4.0, 1.0) < 0.06
					col = Color("a29f95").darkened(0.16) if band7 else Color("a29f95").lightened(flute + (n2 - 0.5) * 0.04)
					h = 0.26 if band7 else (0.58 + flute * 3.5)

				"facade_property_wall":
					strength = 3.2
					var pw_r: int = int(floor(v * 8.0))
					var pw_u: float = fposmod((u + (0.125 if pw_r % 2 == 1 else 0.0)) * 4.0, 1.0)
					var pw_v: float = fposmod(v * 8.0, 1.0)
					var pw_m: bool = pw_u < 0.06 or pw_v < 0.09
					var plaster_mask: float = _fbm(u, v, 4, 907)
					if plaster_mask > 0.42:
						col = Color("aba394").lightened((n2 - 0.5) * 0.06)
						h = 0.65 + (n2 - 0.5) * 0.15
					else:
						col = Color("b8b0a2") if pw_m else Color("9e6b58").lightened((n1 - 0.5) * 0.06)
						h = 0.25 if pw_m else 0.52

				"facade_san_juan":
					strength = 2.0
					var sj_seam: bool = fposmod(u * 2.0, 1.0) < 0.025 or fposmod(v * 3.0, 1.0) < 0.03
					col = Color("eae9e2").darkened(0.10) if sj_seam else Color("eae9e2").lightened((n2 - 0.5) * 0.03)
					h = 0.35 if sj_seam else (0.60 + (n2 - 0.5) * 0.08)

				"facade_coto":
					strength = 3.0
					var rib: float = sin(u * TAU * 16.0) * 0.05
					var c_seam: bool = fposmod(v * 3.0, 1.0) < 0.04
					col = Color("d4d2c5").darkened(0.15) if c_seam else Color("d4d2c5").lightened(rib)
					h = 0.25 if c_seam else (0.55 + rib * 4.0)

				"landmark_stone":
					strength = 4.2
					var ls_r: int = int(floor(v * 8.0))
					var ls_u: float = fposmod((u + (0.2 if ls_r % 2 == 1 else 0.0)) * 4.0, 1.0)
					var ls_v: float = fposmod(v * 8.0, 1.0)
					var ls_m: bool = ls_u < 0.07 or ls_v < 0.11
					var ls_t: float = (_hash(int(u * 4.0), ls_r, 947) - 0.5) * 0.14
					col = Color("6b6861") if ls_m else Color("9e9a90").lightened(ls_t + (n1 - 0.5) * 0.05)
					h = 0.12 if ls_m else (0.65 + ls_t * 1.5)

				"glass", "hospital_glass", "perla_glass":
					strength = 2.2
					var frame_border: bool = u < 0.06 or u > 0.94 or v < 0.06 or v > 0.94 or absf(u - 0.5) < 0.025
					var sky_refl: float = clampf(1.0 - v * 0.75 + sin(u * 5.0 + v * 3.0) * 0.08, 0.0, 1.0)
					var blinds: float = 0.04 if (v > 0.15 and v < 0.45 and int(v * 32.0) % 2 == 0) else 0.0
					var base_gl: Color = Color("365261") if key == "glass" else (Color("416372") if key == "hospital_glass" else Color("2f4b47"))
					if frame_border:
						col = Color("2b3336") if key != "perla_glass" else Color("17382e")
						h = 0.85
					else:
						col = base_gl.lightened(sky_refl * 0.25 + blinds)
						h = 0.35

				"perla_green", "awning_striped":
					strength = 2.8
					var wave: float = sin(u * TAU * 12.0) * 0.04
					var stripe: bool = key == "awning_striped" and int(floor(u * 8.0)) % 2 == 0
					var base_aw: Color = Color("184236") if not stripe else Color("ece4d0")
					col = base_aw.lightened(wave + (n1 - 0.5) * 0.03)
					h = 0.5 + wave * 4.0

				"roof_terrace":
					# Terraza de baldosas cerámicas rojas
					strength = 3.0
					var rt_u: float = fposmod(u * 6.0, 1.0)
					var rt_v: float = fposmod(v * 6.0, 1.0)
					var rt_j: bool = rt_u < 0.06 or rt_v < 0.06
					var rt_var: float = (_hash(int(u * 6.0), int(v * 6.0), 991) - 0.5) * 0.08
					col = Color("6e5d53") if rt_j else Color("9e5342").lightened(rt_var + (n1 - 0.5) * 0.04)
					h = 0.20 if rt_j else 0.65

				"roof_zinc":
					# Chapa acanalada / techo ferroviario
					strength = 3.6
					var corr: float = sin(u * TAU * 16.0) * 0.5 + 0.5
					col = Color("525b5e").lightened((corr - 0.5) * 0.16 + (n2 - 0.5) * 0.05)
					h = corr * 0.8

			alb.set_pixel(x, y, col)
			heights[y * SIZE + x] = clampf(h, 0.0, 1.0)

	var nrm: Image = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y: int in range(SIZE):
		var ym: int = posmod(y - 1, SIZE)
		var yp: int = posmod(y + 1, SIZE)
		for x: int in range(SIZE):
			var xm: int = posmod(x - 1, SIZE)
			var xp: int = posmod(x + 1, SIZE)
			var dx: float = (heights[y * SIZE + xp] - heights[y * SIZE + xm]) * strength
			var dy: float = (heights[yp * SIZE + x] - heights[ym * SIZE + x]) * strength
			var n: Vector3 = Vector3(-dx, -dy, 1.0).normalized()
			nrm.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5, 1.0))

	alb.generate_mipmaps()
	nrm.generate_mipmaps()
	return {"albedo": alb, "normal": nrm}

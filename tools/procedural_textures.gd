extends RefCounted
## Generates high-fidelity seamless PBR textures (Albedo + Normal maps) for Ramos Mejía.
## Specialized for authentic Argentine urban asphalt, calcáreo sidewalks, and railway tracks.

const TEX_DIR: String = "res://assets/textures"
const SIZE: int = 256

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
		_smooth_noise(u, v, base_freq, seed_val) * 0.52 +
		_smooth_noise(u, v, base_freq * 2, seed_val + 17) * 0.28 +
		_smooth_noise(u, v, base_freq * 4, seed_val + 53) * 0.14 +
		_smooth_noise(u, v, base_freq * 8, seed_val + 97) * 0.06
	)

static func _generate_pair(key: String) -> Dictionary:
	var alb: Image = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var heights: PackedFloat32Array = PackedFloat32Array()
	heights.resize(SIZE * SIZE)
	var strength: float = 2.6

	for y: int in range(SIZE):
		var v: float = float(y) / float(SIZE)
		for x: int in range(SIZE):
			var u: float = float(x) / float(SIZE)
			var n1: float = _hash(x, y, 11)
			var n2: float = _fbm(u, v, 8, 29)
			var n3: float = _fbm(u, v, 16, 73)
			var col: Color = Color(0.7, 0.7, 0.7)
			var h: float = 0.5

			match key:
				"road":
					# Authentic Argentine urban asphalt: dark bitumen binder with basalt aggregate, quartz specks & subtle wear
					strength = 3.2
					var base_lum: float = 0.165
					var aggregate: float = (n1 - 0.5) * 0.08 + (n2 - 0.5) * 0.04
					# Fine gravel stone specks (dark basalt & light granite flecks)
					var speck: float = 0.0
					if n1 > 0.94:
						speck = 0.09
					elif n1 < 0.06:
						speck = -0.06
					# Subtle longitudinal traffic wear sheen
					var tire_wear: float = sin(u * TAU * 2.0) * 0.015
					var lum: float = clampf(base_lum + aggregate + speck + tire_wear, 0.10, 0.32)
					# Natural cool-gray asphalt with mineral tone
					col = Color(lum * 0.98, lum * 1.0, lum * 1.03)
					# Asphalt micro-cracks
					var crack_u: float = absf(sin(u * TAU * 3.0 + n2 * 2.0) * cos(v * TAU * 3.0 + n3 * 2.0))
					if crack_u < 0.018:
						col = Color(0.08, 0.08, 0.09)
						h = 0.15
					else:
						h = 0.5 + aggregate * 3.0 + speck * 4.0

				"walk":
					# Vereda tradicional de baldosas calcáreas argentinas (cuadrícula de 4x4 baldosones)
					# con juntas de colocación / pastina profundas y definidas
					strength = 4.2
					var tiles: float = 4.0
					var tu: float = fposmod(u * tiles, 1.0)
					var tv: float = fposmod(v * tiles, 1.0)
					var tile_id_x: int = int(floor(u * tiles))
					var tile_id_y: int = int(floor(v * tiles))
					# Tonal variation per tile (some slightly warmer, some cooler gray)
					var tile_var: float = (_hash(tile_id_x, tile_id_y, 77) - 0.5) * 0.08
					var joint_w: float = 0.048
					var is_joint: bool = tu < joint_w or tv < joint_w or tu > (1.0 - joint_w) or tv > (1.0 - joint_w)
					# Interior decorative pattern: 2x2 sub-panes within each baldosa
					var sub_u: float = fposmod(tu * 2.0, 1.0)
					var sub_v: float = fposmod(tv * 2.0, 1.0)
					var is_groove: bool = not is_joint and (sub_u < 0.055 or sub_v < 0.055)
					# Base calcáreo cement color
					var base_c: Color = Color(0.72 + tile_var, 0.70 + tile_var, 0.65 + tile_var * 0.7)
					if is_joint:
						# Deep dark pastina / cement joint
						col = Color(0.24, 0.23, 0.22)
						h = 0.08
					elif is_groove:
						col = base_c.darkened(0.22)
						h = 0.32
					else:
						# Fine non-slip porous calcáreo grain
						var grain: float = (n1 - 0.5) * 0.05 + (n3 - 0.5) * 0.03
						col = base_c.lightened(grain)
						h = 0.70 + grain * 1.5

				"pavers":
					# Adoquinado de pórfido / granito tradicional con trabas
					strength = 4.5
					var rows: float = 6.0
					var cols_count: float = 3.0
					var row_idx: int = int(floor(v * rows))
					var offset_u: float = u + (0.5 / cols_count if row_idx % 2 == 1 else 0.0)
					var pu: float = fposmod(offset_u * cols_count, 1.0)
					var pv: float = fposmod(v * rows, 1.0)
					var cid: int = int(floor(offset_u * cols_count))
					var tone: float = (_hash(cid, row_idx, 91) - 0.5) * 0.14
					var edge: float = minf(minf(pu, 1.0 - pu) * cols_count, minf(pv, 1.0 - pv) * rows)
					if edge < 0.20:
						# Dark sand / mortar between cobblestones
						col = Color(0.22, 0.20, 0.18)
						h = 0.06
					else:
						var bevel: float = clampf((edge - 0.20) * 3.5, 0.0, 1.0)
						col = Color(0.62 + tone, 0.54 + tone * 0.8, 0.48 + tone * 0.6).lightened((n2 - 0.5) * 0.06)
						h = 0.25 + bevel * 0.65 + (n1 - 0.5) * 0.12

				"curb":
					# Cordón de granito martelinado con junta de dilatación
					strength = 3.0
					var joint_c: bool = fposmod(u * 2.0, 1.0) < 0.035
					var granite_speck: float = (n1 - 0.5) * 0.10 + (n2 - 0.5) * 0.05
					col = Color(0.76 + granite_speck, 0.75 + granite_speck, 0.71 + granite_speck)
					if joint_c:
						col = Color(0.25, 0.25, 0.24)
						h = 0.15
					else:
						h = 0.60 + granite_speck * 2.0

				"ballast":
					# Balasto de vía férrea: piedra partida triturada con óxido de freno del FF.CC. Sarmiento
					strength = 5.0
					var b_stone: float = _fbm(u, v, 24, 301)
					var b_fine: float = (n1 - 0.5) * 0.22
					# Blend of dark basalt stone and reddish-brown brake dust
					var rust: float = clampf(_smooth_noise(u * 2.0, v * 2.0, 6, 411) * 0.4, 0.0, 0.35)
					var val: float = 0.26 + b_stone * 0.30 + b_fine
					col = Color(val * 1.15 + rust * 0.28, val * 0.95 + rust * 0.12, val * 0.85)
					h = clampf(b_stone * 0.85 + b_fine * 1.5, 0.0, 1.0)

				"rail":
					# Riel de acero: cabeza pulida brillante y flancos oscuros oxidados
					strength = 2.4
					var edge_dist: float = absf(u - 0.5) * 2.0
					if edge_dist < 0.70:
						# Running head: highly polished bright steel with longitudinal streaks
						var streak: float = (_smooth_noise(0.2, v, 24, 401) - 0.5) * 0.06
						col = Color(0.78 + streak, 0.80 + streak, 0.84 + streak)
						h = 0.85 + streak
					else:
						# Flanks: dark oxidized rusted steel
						var rust_side: float = (n1 - 0.5) * 0.08
						col = Color(0.32 + rust_side, 0.25 + rust_side * 0.8, 0.20 + rust_side * 0.6)
						h = 0.35 + rust_side

				"trunk":
					# Durmientes de madera tratada con creosota y placas de fijación
					strength = 4.2
					var bark_v: float = _smooth_noise(u * 4.0, v * 1.2, 10, 501)
					var ridge: float = sin(u * TAU * 12.0 + n2 * 4.0) * 0.5 + 0.5
					# Deep dark creosote wood
					col = Color(0.24 + bark_v * 0.08, 0.18 + bark_v * 0.06, 0.14 + bark_v * 0.04).darkened((1.0 - ridge) * 0.25)
					# Steel tie-plate zone under rails
					if absf(u - 0.25) < 0.12 or absf(u - 0.75) < 0.12:
						col = Color(0.20, 0.22, 0.24).lightened((n1 - 0.5) * 0.05)
						h = 0.75 + (n1 - 0.5) * 0.1
					else:
						h = ridge * 0.65 + (n1 - 0.5) * 0.15

				"grass":
					strength = 3.2
					var g_patch: float = _fbm(u, v, 8, 105)
					var blade: float = (n1 - 0.5) * 0.12
					col = Color(0.24 + g_patch * 0.12 + blade * 0.3, 0.44 + g_patch * 0.16 + blade, 0.20 + g_patch * 0.08)
					h = 0.45 + g_patch * 0.3 + blade * 1.5

				"earth":
					strength = 3.0
					var e_patch: float = _fbm(u, v, 8, 211)
					var e_grain: float = (n1 - 0.5) * 0.12
					col = Color(0.42 + e_patch * 0.10 + e_grain, 0.44 + e_patch * 0.10 + e_grain, 0.36 + e_patch * 0.08)
					h = 0.45 + e_patch * 0.35 + e_grain * 1.5

				"palm_trunk":
					strength = 4.0
					var rings: float = absf(sin(v * TAU * 12.0 + sin(u * TAU * 3.0) * 0.4))
					col = Color(0.42, 0.34, 0.26).darkened((1.0 - rings) * 0.25).lightened((n1 - 0.5) * 0.05)
					h = rings * 0.8 + (n1 - 0.5) * 0.1

				"leaf", "palm_leaf":
					strength = 3.2
					var cluster: float = _fbm(u, v, 12, 601 if key == "leaf" else 619)
					var base_g: Color = Color(0.20, 0.38, 0.22) if key == "leaf" else Color(0.18, 0.35, 0.20)
					col = base_g.lightened(cluster * 0.24).darkened((1.0 - cluster) * 0.16)
					h = cluster * 0.80

				"facade0", "facade_la_perla":
					# Símil piedra París con buñas horizontales
					strength = 3.2
					var base0: Color = Color("cfc5b0") if key == "facade0" else Color("d8cbb2")
					var buna: bool = fposmod(v * 5.0, 1.0) < 0.07 or fposmod(u * 2.0, 1.0) < 0.025
					var grain0: float = (n2 - 0.5) * 0.06 + (n1 - 0.5) * 0.03
					col = base0.darkened(0.22) if buna else base0.lightened(grain0)
					h = 0.18 if buna else (0.65 + grain0 * 2.0)

				"facade1":
					# Hormigón visto arquitectónico con juntas de encofrado
					strength = 2.8
					var seam1: bool = fposmod(u * 2.0, 1.0) < 0.03 or fposmod(v * 3.0, 1.0) < 0.04
					var g1: float = (n2 - 0.5) * 0.07 + (n1 - 0.5) * 0.03
					col = Color("b4b0a8").darkened(0.22) if seam1 else Color("b4b0a8").lightened(g1)
					h = 0.20 if seam1 else (0.62 + g1 * 2.0)

				"facade2":
					# Tarquini texturado cálido / revoque plástico
					strength = 3.2
					var t_tex: float = _fbm(u, v, 20, 709)
					var band2: bool = fposmod(v * 4.0, 1.0) < 0.05
					var base2: Color = Color("cfc0a5")
					col = base2.darkened(0.18) if band2 else base2.lightened((t_tex - 0.5) * 0.12)
					h = 0.25 if band2 else (0.60 + (t_tex - 0.5) * 3.0)

				"facade3", "station_brick":
					# Ladrillo a la vista argentino (Stretcher bond)
					strength = 4.5
					var b_rows: float = 12.0
					var b_cols: float = 6.0
					var r_idx: int = int(floor(v * b_rows))
					var bu: float = fposmod((u + (0.5 / b_cols if r_idx % 2 == 1 else 0.0)) * b_cols, 1.0)
					var bv: float = fposmod(v * b_rows, 1.0)
					var bid: int = int(floor((u + (0.5 / b_cols if r_idx % 2 == 1 else 0.0)) * b_cols))
					var b_var: float = (_hash(bid, r_idx, 809) - 0.5) * 0.14
					var mortar: bool = bu < 0.065 or bv < 0.12
					var brick_base: Color = Color("9c4e3e") if key == "facade3" else Color("8a3e30")
					if mortar:
						col = Color("d4ccbe")
						h = 0.12
					else:
						col = brick_base.lightened(b_var + (n1 - 0.5) * 0.05)
						h = 0.75 + b_var * 0.5

				"facade4":
					# Revestimiento moderno gris pizarra modulado
					strength = 3.0
					var grid4: bool = fposmod(v * 6.0, 1.0) < 0.06 or fposmod(u * 3.0, 1.0) < 0.035
					var g4: float = (n2 - 0.5) * 0.06
					col = Color("8c989c").darkened(0.20) if grid4 else Color("8c989c").lightened(g4)
					h = 0.22 if grid4 else (0.62 + g4 * 2.0)

				"facade5":
					# Cerámico / ladrillo terracota rosado
					strength = 3.5
					var r5: int = int(floor(v * 8.0))
					var u5: float = fposmod((u + (0.125 if r5 % 2 == 1 else 0.0)) * 4.0, 1.0)
					var v5: float = fposmod(v * 8.0, 1.0)
					var m5: bool = u5 < 0.06 or v5 < 0.10
					var c5: float = (_hash(int(u * 4.0), r5, 823) - 0.5) * 0.10
					col = Color("c2b8a8") if m5 else Color("c48f7a").lightened(c5)
					h = 0.20 if m5 else (0.70 + c5)

				"facade6":
					# Travertino / sillares marmolados claros con vetas
					strength = 3.2
					var r6: int = int(floor(v * 6.0))
					var u6: float = fposmod((u + (0.25 if r6 % 2 == 1 else 0.0)) * 3.0, 1.0)
					var v6: float = fposmod(v * 6.0, 1.0)
					var m6: bool = u6 < 0.045 or v6 < 0.065
					var vein: float = (_smooth_noise(u, v * 4.0, 8, 853) - 0.5) * 0.08
					col = Color("b0a694") if m6 else Color("dcd2be").lightened(vein)
					h = 0.22 if m6 else (0.68 + vein * 2.5)

				"facade7":
					# Frente contemporáneo grafito / topo
					strength = 3.0
					var flute: float = sin(u * TAU * 12.0) * 0.04
					var band7: bool = fposmod(v * 4.0, 1.0) < 0.06
					col = Color("9c988e").darkened(0.18) if band7 else Color("9c988e").lightened(flute + (n2 - 0.5) * 0.04)
					h = 0.24 if band7 else (0.60 + flute * 3.5)

				"facade_property_wall":
					# Muro medianero con sectores de ladrillo visto y revoque
					strength = 3.6
					var pw_r: int = int(floor(v * 8.0))
					var pw_u: float = fposmod((u + (0.125 if pw_r % 2 == 1 else 0.0)) * 4.0, 1.0)
					var pw_v: float = fposmod(v * 8.0, 1.0)
					var pw_m: bool = pw_u < 0.06 or pw_v < 0.09
					var plaster_mask: float = _fbm(u, v, 4, 907)
					if plaster_mask > 0.40:
						col = Color("aba394").lightened((n2 - 0.5) * 0.06)
						h = 0.68 + (n2 - 0.5) * 0.15
					else:
						col = Color("b4aca0") if pw_m else Color("a06552").lightened((n1 - 0.5) * 0.06)
						h = 0.22 if pw_m else 0.55

				"facade_san_juan":
					strength = 2.4
					var sj_seam: bool = fposmod(u * 2.0, 1.0) < 0.025 or fposmod(v * 3.0, 1.0) < 0.03
					col = Color("eae9e2").darkened(0.12) if sj_seam else Color("eae9e2").lightened((n2 - 0.5) * 0.03)
					h = 0.30 if sj_seam else (0.62 + (n2 - 0.5) * 0.08)

				"facade_coto":
					strength = 3.4
					var rib: float = sin(u * TAU * 16.0) * 0.05
					var c_seam: bool = fposmod(v * 3.0, 1.0) < 0.04
					col = Color("d4d2c5").darkened(0.16) if c_seam else Color("d4d2c5").lightened(rib)
					h = 0.24 if c_seam else (0.58 + rib * 4.0)

				"landmark_stone":
					strength = 4.5
					var ls_r: int = int(floor(v * 8.0))
					var ls_u: float = fposmod((u + (0.2 if ls_r % 2 == 1 else 0.0)) * 4.0, 1.0)
					var ls_v: float = fposmod(v * 8.0, 1.0)
					var ls_m: bool = ls_u < 0.07 or ls_v < 0.11
					var ls_t: float = (_hash(int(u * 4.0), ls_r, 947) - 0.5) * 0.14
					col = Color(0.28, 0.27, 0.25) if ls_m else Color("9e9a90").lightened(ls_t + (n1 - 0.5) * 0.05)
					h = 0.10 if ls_m else (0.68 + ls_t * 1.5)

				"glass", "hospital_glass", "perla_glass":
					strength = 2.5
					var frame_border: bool = u < 0.05 or u > 0.95 or v < 0.05 or v > 0.95 or absf(u - 0.5) < 0.025
					var sky_refl: float = clampf(1.0 - v * 0.70 + sin(u * 4.0 + v * 3.0) * 0.08, 0.0, 1.0)
					var blinds: float = 0.04 if (v > 0.15 and v < 0.45 and int(v * 32.0) % 2 == 0) else 0.0
					var base_gl: Color = Color("2e4856") if key == "glass" else (Color("365868") if key == "hospital_glass" else Color("284540"))
					if frame_border:
						col = Color("202528") if key != "perla_glass" else Color("142f26")
						h = 0.85
					else:
						col = base_gl.lightened(sky_refl * 0.28 + blinds)
						h = 0.35

				"perla_green", "awning_striped":
					strength = 3.2
					var wave: float = sin(u * TAU * 12.0) * 0.04
					var stripe: bool = key == "awning_striped" and int(floor(u * 8.0)) % 2 == 0
					var base_aw: Color = Color("184236") if not stripe else Color("ece4d0")
					col = base_aw.lightened(wave + (n1 - 0.5) * 0.03)
					h = 0.5 + wave * 4.0

				"roof_terrace":
					# Baldozas rojas de azotea
					strength = 3.6
					var rt_u: float = fposmod(u * 6.0, 1.0)
					var rt_v: float = fposmod(v * 6.0, 1.0)
					var rt_j: bool = rt_u < 0.055 or rt_v < 0.055
					var rt_var: float = (_hash(int(u * 6.0), int(v * 6.0), 991) - 0.5) * 0.08
					col = Color("5e4c42") if rt_j else Color("9e4e3c").lightened(rt_var + (n1 - 0.5) * 0.04)
					h = 0.18 if rt_j else 0.68

				"roof_zinc":
					# Chapa acanalada galvanizada
					strength = 4.0
					var corr: float = sin(u * TAU * 16.0) * 0.5 + 0.5
					col = Color("566064").lightened((corr - 0.5) * 0.18 + (n2 - 0.5) * 0.05)
					h = corr * 0.85

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

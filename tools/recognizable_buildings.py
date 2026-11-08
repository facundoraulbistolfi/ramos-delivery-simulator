"""Bind architectural variants and featured Ramos Mejía locales, plazas, and landmarks to OSM footprints."""
import math
from shapely.geometry import Polygon, Point, LineString
from shapely.ops import unary_union, nearest_points


def _front_dict(a, b, polygon):
    middle = Point((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
    dx, dy = b[0] - a[0], b[1] - a[1]
    length = max(0.01, (dx * dx + dy * dy) ** 0.5)
    normal = [-dy / length, dx / length]
    if polygon is not None and polygon.contains(Point(middle.x + normal[0] * 0.2, middle.y + normal[1] * 0.2)):
        normal = [-v for v in normal]
    return {
        'a': [round(a[0], 2), round(a[1], 2)],
        'b': [round(b[0], 2), round(b[1], 2)],
        'normal': [round(normal[0], 4), round(normal[1], 4)],
        'width': round(length, 2),
        'visit': [round(middle.x + normal[0] * 12, 2), round(middle.y + normal[1] * 12, 2)],
    }


def annotate(data, ways, pts):
    source = {w['id']: w for w in ways}
    campus = Polygon([pts[n] for n in source[222084507]['nodes']])
    by_id = {int(b['osm_id']): b for b in data['buildings']}
    hospital_ids = []
    for w in ways:
        if not w['tags'].get('building') or len(w['nodes']) < 4 or w['nodes'][0] != w['nodes'][-1]:
            continue
        p = [pts[n] for n in w['nodes']]
        if not campus.covers(Polygon(p).representative_point()):
            continue
        hospital_ids.append(w['id'])
        if w['id'] not in by_id:
            building = {
                'osm_id': w['id'],
                'points': p[:-1],
                'height': 6.2,
                'source_height': 6.2,
                'height_source': 'assumed_2_levels',
                'name': w['tags'].get('name', ''),
                'type': w['tags']['building'],
            }
            data['buildings'].append(building)
            by_id[w['id']] = building
        by_id[w['id']]['recognizable'] = 'san_juan'
    main = by_id[636863311]
    main.update(height=12.4, height_source='visual_estimate_four_levels_plus_rooftop_core', name='Hospital San Juan de Dios')
    coto = by_id[27233077]
    coto['recognizable'] = 'coto'
    perla = by_id[475920381]
    perla.update(recognizable='la_perla', name='La Perla', source_name='')

    hp = main['points']
    hospital_front = _front_dict(hp[12], hp[13], Polygon(hp))
    coto_front = _front_dict(coto['points'][0], coto['points'][1], Polygon(coto['points']))
    coto_side = _front_dict(coto['points'][3], coto['points'][0], Polygon(coto['points']))
    perla_fronts = [_front_dict(perla['points'][i], perla['points'][i + 1], Polygon(perla['points'])) for i in [0, 1, 2]]
    data['recognizable_buildings'] = [
        {
            'key': 'san_juan',
            'name': 'Casa Hospital San Juan de Dios',
            'address': 'Dr. Gabriel Ardoino 714',
            'osm_site_id': 222084507,
            'building_ids': hospital_ids,
            'main_building_id': 636863311,
            'campus_points': list(campus.exterior.coords)[:-1],
            'front': hospital_front,
            'visit': hospital_front['visit'],
            'sources': [
                'https://hospitalsanjuandedios.org.ar/nuestras-sedes/',
                'https://hospitalsanjuandedios.org.ar/wp-content/uploads/2024/08/fachada-atardecer-1024x683.jpg',
            ],
            'accuracy': 'OSM footprints; simplified photographic facade and estimated heights',
        },
        {
            'key': 'coto',
            'name': 'Coto Ramos Mejía',
            'address': 'Av. Rivadavia 13810 / Pueyrredón',
            'building_ids': [27233077],
            'main_building_id': 27233077,
            'front': coto_front,
            'side': coto_side,
            'visit': coto_front['visit'],
            'sources': [
                'https://www.coto.com.ar/mapassucursales/sucursales/ListadoSucursales.aspx',
                'https://elcactus.com.ar/2020/04/clausuraron-el-coto-de-ramos-mejia-por-graves-fallas-de-higiene-y-bromatologia/',
            ],
            'accuracy': 'OSM footprint and branch identity; simplified brand facade',
        },
        {
            'key': 'la_perla',
            'name': 'La Perla',
            'address': 'Av. Rivadavia 14102 / Av. de Mayo',
            'osm_poi_id': 3527161632,
            'building_ids': [475920381],
            'main_building_id': 475920381,
            'front': perla_fronts[0],
            'fronts': perla_fronts,
            'visit': perla_fronts[0]['visit'],
            'sources': [
                'https://es.restaurantguru.com/La-Perla-Ramos-Mejia',
                'https://www.vivieloeste.com.ar/noticias/2023/03/06/57223-haedo-la-perla-vuelve-a-abrir-sus-puertas',
            ],
            'accuracy': 'OSM host building and restaurant POI; simplified glazing and green awnings',
        },
    ]
    return campus


FEATURED_SPECS = [
    # 18 Locales comerciales y gastronómicos
    {'key': 'apolonia', 'name': 'Apolonia Pizza & Pasta', 'sign': 'APOLONIA', 'sub': 'PIZZA & PASTA', 'category': 'local', 'style': 'pizzeria_modern', 'address': 'Espora 261', 'street': 'Espora', 'side': 'north', 'point': [-1504.1, 511.8], 'osm_id': 12119232701},
    {'key': 'faricci', 'name': 'Heladería Faricci', 'sign': 'FARICCI', 'sub': 'HELADOS ARTESANALES', 'category': 'local', 'style': 'gelato_red', 'address': 'Rosales 398 esq. Necochea', 'street': 'Rosales', 'side': 'south', 'point': [-1583.1, 444.0], 'osm_id': 3867477389},
    {'key': 'faricci_san_martin', 'name': 'Heladería Faricci San Martín', 'sign': 'FARICCI', 'sub': 'HELADERÍA & CAFÉ', 'category': 'local', 'style': 'gelato_red', 'address': 'Av. Gral. San Martín 702', 'street': 'Avenida General San Martín', 'side': 'south', 'point': [-883.7, 696.4], 'osm_id': 4708533217},
    {'key': 'due', 'name': 'Due Café & Restó', 'sign': 'DUE', 'sub': 'CAFÉ · BISTRÓ · RESTÓ', 'category': 'local', 'style': 'bistro_wood', 'address': 'Av. de Mayo 382', 'street': 'Avenida de Mayo', 'side': 'east', 'point': [-1410.0, 454.4], 'osm_id': 3526517378},
    {'key': 'luccianos', 'name': "Lucciano's Ramos Mejía", 'sign': "LUCCIANO'S", 'sub': 'IL MAESTRO DEL GELATO', 'category': 'local', 'style': 'gelato_luxury', 'address': 'Necochea 322', 'street': 'Necochea', 'side': 'east', 'point': [-1578.0, 355.0], 'osm_id': 0},
    {'key': 'banned_burger', 'name': 'Banned Burger Joint', 'sign': 'BANNED BURGER', 'sub': 'SMASH BURGERS & ARCADE', 'category': 'local', 'style': 'burger_arcade', 'address': 'Avellaneda 374', 'street': 'Avellaneda', 'side': 'south', 'point': [-1710.0, 412.0], 'osm_id': 0},
    {'key': 'cloe_burger', 'name': 'Clöe Burger & Bakehouse', 'sign': 'CLÖE BURGER', 'sub': 'BURGERS & BAKEHOUSE', 'category': 'local', 'style': 'burger_boutique', 'address': 'Bolívar 501 esq. Castelli', 'street': 'Bolívar', 'side': 'east', 'point': [-1240.0, 572.8], 'osm_id': 0},
    {'key': 'la_birra_bar', 'name': 'La Birra Bar', 'sign': 'LA BIRRA BAR', 'sub': 'BURGERS & CRAFT BEER', 'category': 'local', 'style': 'burger_craft', 'address': 'Mariano Moreno 239', 'street': 'Mariano Moreno', 'side': 'west', 'point': [-1215.0, 208.0], 'osm_id': 0},
    {'key': 'farmacia_moreno', 'name': 'Farmacia Moreno', 'sign': 'FARMACIA MORENO', 'sub': 'SALUD & PERFUMERÍA', 'category': 'local', 'style': 'pharmacy_green', 'address': 'Mariano Moreno 90', 'street': 'Mariano Moreno', 'side': 'east', 'point': [-1207.9, 151.6], 'osm_id': 4696097130},
    {'key': 'farmacia_central_oeste', 'name': 'Farmacia Central Oeste', 'sign': 'CENTRAL OESTE', 'sub': 'FARMACIA & PERFUMERÍA', 'category': 'local', 'style': 'pharmacy_blue', 'address': 'Av. de Mayo 899 esq. Alvarado', 'street': 'Avenida de Mayo', 'side': 'west', 'point': [-1350.2, 988.1], 'osm_id': 477565291, 'building_id': 477565291},
    {'key': 'farmacia_central_oeste_centro', 'name': 'Farmacia Central Oeste Centro', 'sign': 'CENTRAL OESTE', 'sub': 'FARMACIA 24 HS', 'category': 'local', 'style': 'pharmacy_blue', 'address': 'Av. de Mayo 448', 'street': 'Avenida de Mayo', 'side': 'east', 'point': [-1405.0, 529.1], 'osm_id': 4708773491},
    {'key': 'sportclub', 'name': 'SportClub Ramos Mejía', 'sign': 'SPORTCLUB', 'sub': 'GIMNASIO & FITNESS', 'category': 'local', 'style': 'gym_modern', 'address': 'Av. de Mayo 342', 'street': 'Avenida de Mayo', 'side': 'east', 'point': [-1407.0, 437.0], 'osm_id': 13970771201},
    {'key': 'bomberitos', 'name': 'Club Bomberitos', 'sign': 'CLUB BOMBERITOS', 'sub': 'BOMBEROS VOLUNTARIOS', 'category': 'local', 'style': 'club_fire', 'address': 'Gral. Acha y Pueyrredón', 'street': 'General Acha', 'side': 'north', 'point': [-79.3, 1285.7], 'osm_id': 586639856},
    {'key': 'cuartel_bomberos', 'name': 'Cuartel Central Bomberos Voluntarios', 'sign': 'BOMBEROS VOLUNTARIOS', 'sub': 'CUARTEL CENTRAL · SUIPACHA 110', 'category': 'institution', 'style': 'fire_station', 'address': 'Suipacha 110', 'street': 'Suipacha', 'side': 'north', 'point': [-1107.2, 767.6], 'osm_id': 342175629, 'building_id': 342175629},
    {'key': 'la_casa_de_oberon', 'name': 'La Casa de Oberón', 'sign': 'LA CASA DE OBERÓN', 'sub': 'CAFÉ · TORTAS · BRUNCH', 'category': 'local', 'style': 'patisserie_warm', 'address': 'Av. de Mayo 945', 'street': 'Avenida de Mayo', 'side': 'west', 'point': [-1320.0, 1048.2], 'osm_id': 4710253209},
    {'key': 'antojos', 'name': 'Antojos Patisserie', 'sign': 'ANTOJOS', 'sub': 'PATISSERIE & GLUTEN FREE', 'category': 'local', 'style': 'patisserie_pink', 'address': 'Mariano Moreno 607', 'street': 'Mariano Moreno', 'side': 'west', 'point': [-1101.0, 660.0], 'osm_id': 0},
    {'key': 'samurai_sushi', 'name': 'Samurai Sushi', 'sign': 'SAMURAI SUSHI', 'sub': 'SUSHI & NIKKEI BAR', 'category': 'local', 'style': 'sushi_samurai', 'address': 'Avellaneda 415', 'street': 'Avellaneda', 'side': 'north', 'point': [-1719.8, 436.7], 'osm_id': 9135836071},
    {'key': 'otaku_sushi', 'name': 'Otaku Sushi', 'sign': 'OTAKU SUSHI', 'sub': 'JAPANESE FOOD & ROLLS', 'category': 'local', 'style': 'sushi_otaku', 'address': 'Espora 249', 'street': 'Espora', 'side': 'north', 'point': [-1486.0, 509.0], 'osm_id': 0},
    {'key': 'la_tanita', 'name': 'La Tanita Café & Restó', 'sign': 'LA TANITA', 'sub': 'CAFÉ · MINUTAS · RESTÓ', 'category': 'local', 'style': 'trattoria_italiana', 'address': 'Sarmiento y Pueyrredón', 'street': 'Sarmiento', 'side': 'south', 'point': [-1043.6, 284.5], 'osm_id': 4693013571},
    {'key': 'parrilla_la_tanita', 'name': 'Parrilla La Tanita', 'sign': 'PARRILLA LA TANITA', 'sub': 'CARNES A LAS BRASAS', 'category': 'local', 'style': 'trattoria_italiana', 'address': 'Av. Gaona 2195', 'street': 'Avenida Gaona', 'side': 'north', 'point': [-1098.2, -232.9], 'osm_id': 575973745, 'building_id': 575973745},
    {'key': 'la_buena_fama', 'name': 'La Buena Fama Pastas', 'sign': 'LA BUENA FAMA', 'sub': 'FÁBRICA DE PASTAS FRESCAS', 'category': 'local', 'style': 'pasta_italiana', 'address': 'Av. Gral. San Martín 940', 'street': 'Avenida General San Martín', 'side': 'south', 'point': [-471.6, 1117.9], 'osm_id': 4708682476},
    {'key': 'gallegol', 'name': 'Gallegol Golosinas', 'sign': 'GALLEGOL', 'sub': 'MAYORISTA DE GOLOSINAS', 'category': 'local', 'style': 'candy_wholesale', 'address': 'Mariano Moreno 298 esq. Belgrano', 'street': 'Mariano Moreno', 'side': 'west', 'point': [-1212.0, 185.0], 'osm_id': 0},
    # Lugares, instituciones y boliches
    {'key': 'el_muro_escalada', 'name': 'El Muro de Ramos (Escalada)', 'sign': 'EL MURO DE RAMOS', 'sub': 'ESCALADA & PALESTRA', 'category': 'institution', 'style': 'climbing_gym', 'address': 'Viamonte 160', 'street': 'Viamonte', 'side': 'west', 'point': [-902.0, 572.0], 'osm_id': 0},
    {'key': 'socorros_mutuos', 'name': 'Sociedad de Socorros Mutuos', 'sign': 'SOCORROS MUTUOS', 'sub': 'FUNDADA EN RAMOS MEJÍA', 'category': 'institution', 'style': 'neoclassical_hall', 'address': 'Av. Gral. San Martín 327', 'street': 'Avenida General San Martín', 'side': 'north', 'point': [-1027.5, 548.6], 'osm_id': 477522470, 'building_id': 477522470},
    {'key': 'cavidi', 'name': 'Centro de Día CAVIDI', 'sign': 'CENTRO DE DÍA CAVIDI', 'sub': 'INTEGRACIÓN & SALUD', 'category': 'institution', 'style': 'care_center', 'address': 'Viamonte 479', 'street': 'Viamonte', 'side': 'east', 'point': [-910.0, 590.0], 'osm_id': 0},
    {'key': 'vinicius', 'name': 'Vinicius Disco', 'sign': 'VINICIUS', 'sub': 'DISCO & NIGHTCLUB', 'category': 'nightclub', 'style': 'disco_vinicius', 'address': 'Av. Rivadavia 14174', 'street': 'Avenida Rivadavia', 'side': 'south', 'point': [-1563.5, 140.5], 'osm_id': 475920378, 'building_id': 475920378},
    {'key': 'mata_club', 'name': 'Mata Club', 'sign': 'MATA CLUB', 'sub': 'RAMOS MEJÍA NIGHTLIFE', 'category': 'nightclub', 'style': 'disco_mata', 'address': 'Av. Rivadavia 13636', 'street': 'Avenida Rivadavia', 'side': 'south', 'point': [-880.2, 28.1], 'osm_id': 475938772, 'building_id': 475938772},
    # Corredor céntrico Av. Rivadavia (de Pueyrredón a Av. de Mayo, lado Sur)
    {'key': 'fravega', 'name': 'Frávega Ramos Mejía', 'sign': 'FRÁVEGA', 'sub': 'ELECTRODOMÉSTICOS & TECNOLOGÍA', 'category': 'local', 'style': 'electronics_store', 'address': 'Av. Rivadavia 13840', 'street': 'Avenida Rivadavia', 'side': 'south', 'point': [-1167.5, 52.3], 'osm_id': 4696097166},
    {'key': 'paseo_ramos', 'name': 'Galería Paseo Ramos', 'sign': 'PASEO RAMOS', 'sub': 'GALERÍA COMERCIAL · LOCALES', 'category': 'local', 'style': 'shopping_gallery', 'address': 'Av. Rivadavia 13874', 'street': 'Avenida Rivadavia', 'side': 'south', 'point': [-1192.8, 58.0], 'osm_id': 4696097161},
    {'key': 'subway_rivadavia', 'name': 'Subway & Arni Sport', 'sign': 'SUBWAY', 'sub': 'SANDWICHES & CAFÉ', 'category': 'local', 'style': 'fast_food_green', 'address': 'Av. Rivadavia 13902 esq. Moreno', 'street': 'Avenida Rivadavia', 'side': 'south', 'point': [-1219.2, 59.5], 'osm_id': 3090020915},
    {'key': 'sporting_rivadavia', 'name': 'Sporting Deportes', 'sign': 'SPORTING', 'sub': 'INDUMENTARIA DEPORTIVA', 'category': 'local', 'style': 'sports_store', 'address': 'Av. Rivadavia 13950', 'street': 'Avenida Rivadavia', 'side': 'south', 'point': [-1291.2, 84.4], 'osm_id': 12498709199},
    {'key': 'galeria_central', 'name': 'Galería Central', 'sign': 'GALERÍA CENTRAL', 'sub': 'PASEO DE COMPRAS · RAMOS MEJÍA', 'category': 'local', 'style': 'shopping_gallery', 'address': 'Av. Rivadavia 13970', 'street': 'Avenida Rivadavia', 'side': 'south', 'point': [-1305.0, 85.0], 'osm_id': 12498646999},
    {'key': 'bonafide_rivadavia', 'name': 'Bonafide Café & Chocolates', 'sign': 'BONAFIDE', 'sub': 'CAFÉ · CHOCOLATES · BOMBONES', 'category': 'local', 'style': 'cafe_bonafide', 'address': 'Av. Rivadavia 14020 esq. Bolívar', 'street': 'Avenida Rivadavia', 'side': 'south', 'point': [-1332.8, 91.8], 'osm_id': 12498686576},
    {'key': 'central_oeste_rivadavia', 'name': 'Farmacia Central Oeste Rivadavia', 'sign': 'CENTRAL OESTE', 'sub': 'FARMACIA & PERFUMERÍA', 'category': 'local', 'style': 'pharmacy_blue', 'address': 'Av. Rivadavia 14040', 'street': 'Avenida Rivadavia', 'side': 'south', 'point': [-1367.8, 102.4], 'osm_id': 3767500946},
    {'key': 'heladeria_tempo', 'name': 'Heladería Tempo', 'sign': 'TEMPO', 'sub': 'HELADOS & CAFETERÍA', 'category': 'local', 'style': 'gelato_red', 'address': 'Av. Rivadavia 14080', 'street': 'Avenida Rivadavia', 'side': 'south', 'point': [-1421.6, 110.7], 'osm_id': 4444065334},
    # Corredor céntrico Av. de Mayo (de Rivadavia a Chacabuco)
    {'key': 'casa_de_auxilio', 'name': 'Casa de Auxilio de Ramos Mejía', 'sign': 'CASA DE AUXILIO', 'sub': 'SALUD & ESPECIALIDADES MÉDICAS · 1919', 'category': 'institution', 'style': 'neoclassical_clinic', 'address': 'Av. de Mayo 54', 'street': 'Avenida de Mayo', 'side': 'east', 'point': [-1445.7, 159.0], 'osm_id': 586881132, 'building_id': 586881132},
    {'key': 'mostaza_mayo', 'name': 'Mostaza Ramos Mejía', 'sign': 'MOSTAZA', 'sub': 'HAMBURGUESAS EN SERIO', 'category': 'local', 'style': 'burger_mostaza', 'address': 'Belgrano 86 esq. Av. de Mayo', 'street': 'Belgrano', 'side': 'south', 'point': [-1435.0, 204.0], 'osm_id': 12528272636},
    {'key': 'banco_bbva', 'name': 'Banco BBVA', 'sign': 'BBVA', 'sub': 'BANCA & CAJEROS AUTOMÁTICOS 24 HS', 'category': 'institution', 'style': 'bank_bbva', 'address': 'Av. de Mayo 149', 'street': 'Avenida de Mayo', 'side': 'west', 'point': [-1489.1, 259.8], 'osm_id': 1254511859, 'building_id': 1254511859},
    {'key': 'wendys_kfc', 'name': "Wendy's & KFC", 'sign': "WENDY'S · KFC", 'sub': 'BURGER & FRIED CHICKEN', 'category': 'local', 'style': 'burger_wendys', 'address': 'Av. de Mayo 165', 'street': 'Avenida de Mayo', 'side': 'west', 'point': [-1474.7, 270.1], 'osm_id': 5360245022},
    {'key': 'banco_galicia', 'name': 'Banco Galicia', 'sign': 'GALICIA', 'sub': 'SUCURSAL RAMOS MEJÍA · CAJEROS', 'category': 'institution', 'style': 'bank_galicia', 'address': 'Av. de Mayo 173 esq. Alsina', 'street': 'Avenida de Mayo', 'side': 'west', 'point': [-1489.3, 279.9], 'osm_id': 731229261, 'building_id': 731229261},
    {'key': 'banco_icbc', 'name': 'Banco ICBC & Supervielle', 'sign': 'ICBC · SUPERVIELLE', 'sub': 'CENTRO FINANCIERO AV. DE MAYO', 'category': 'institution', 'style': 'bank_icbc', 'address': 'Av. de Mayo 241', 'street': 'Avenida de Mayo', 'side': 'west', 'point': [-1458.6, 357.3], 'osm_id': 7679792252},
    {'key': 'banco_patagonia', 'name': 'Banco Patagonia', 'sign': 'BANCO PATAGONIA', 'sub': 'ATENCIÓN EMPRESAS & PERSONAS', 'category': 'institution', 'style': 'bank_patagonia', 'address': 'Av. de Mayo 261', 'street': 'Avenida de Mayo', 'side': 'west', 'point': [-1457.4, 364.6], 'osm_id': 7679792251},
    {'key': 'escuela_san_martin', 'name': 'Escuela Nº 4 José de San Martín', 'sign': 'ESCUELA Nº 4 GRAL. SAN MARTÍN', 'sub': 'EDUCACIÓN PÚBLICA · AV. DE MAYO', 'category': 'institution', 'style': 'historic_school', 'address': 'Av. de Mayo 250', 'street': 'Avenida de Mayo', 'side': 'east', 'point': [-1410.0, 351.9], 'osm_id': 599458543},
    {'key': 'club_milanesa', 'name': 'El Club de la Milanesa', 'sign': 'CLUB DE LA MILANESA', 'sub': 'MILANESAS & CERVEZA ARTESANAL', 'category': 'local', 'style': 'bistro_milanesa', 'address': 'Av. de Mayo 310 esq. Rosales', 'street': 'Avenida de Mayo', 'side': 'east', 'point': [-1415.0, 395.0], 'osm_id': 3527153642},
    {'key': 'kinderland', 'name': 'Kinderland Juguetería', 'sign': 'KINDERLAND', 'sub': 'EL MUNDO DEL JUGUETE EN RAMOS', 'category': 'local', 'style': 'toy_store', 'address': 'Av. de Mayo 315', 'street': 'Avenida de Mayo', 'side': 'west', 'point': [-1444.8, 424.8], 'osm_id': 3526517381},
    {'key': 'starbucks_cuspide', 'name': 'Starbucks & Cúspide Libros', 'sign': 'STARBUCKS · CÚSPIDE', 'sub': 'COFFEE & LIBRERÍA', 'category': 'local', 'style': 'cafe_starbucks', 'address': 'Av. de Mayo 427 esq. Espora', 'street': 'Avenida de Mayo', 'side': 'west', 'point': [-1429.8, 516.1], 'osm_id': 3526746695},
    {'key': 'almacen_freddo', 'name': 'Almacén de Pizzas & Freddo', 'sign': 'FREDDO · ALMACÉN DE PIZZAS', 'sub': 'HELADOS & PIZZAS GOURMET', 'category': 'local', 'style': 'pizzeria_modern', 'address': 'Av. de Mayo 470', 'street': 'Avenida de Mayo', 'side': 'east', 'point': [-1380.0, 566.2], 'osm_id': 477546190},
    {'key': 'arezzo_resto', 'name': 'Arezzo Café & Restó', 'sign': 'AREZZO', 'sub': 'RESTAURANTE · CAFÉ · TRATTORIA', 'category': 'local', 'style': 'trattoria_italiana', 'address': 'Av. de Mayo 490', 'street': 'Avenida de Mayo', 'side': 'east', 'point': [-1374.0, 579.8], 'osm_id': 477708158, 'building_id': 477708158},
    {'key': 'la_farola', 'name': 'La Farola de Ramos Mejía', 'sign': 'LA FAROLA EXPRESS', 'sub': 'CLÁSICO BODEGÓN & MINUTAS', 'category': 'local', 'style': 'bodegon_farola', 'address': 'Av. de Mayo 545', 'street': 'Avenida de Mayo', 'side': 'west', 'point': [-1415.6, 627.8], 'osm_id': 477554897, 'building_id': 477554897},
    {'key': 'comisaria_ramos', 'name': 'Comisaría 2ª de Ramos Mejía', 'sign': 'COMISARÍA 2ª RAMOS MEJÍA', 'sub': 'POLICÍA · SEGURIDAD', 'category': 'institution', 'style': 'police_station', 'address': 'Av. de Mayo 549', 'street': 'Avenida de Mayo', 'side': 'west', 'point': [-1428.7, 650.9], 'osm_id': 822486436, 'building_id': 822486436},
    {'key': 'banco_hipotecario', 'name': 'Banco Hipotecario', 'sign': 'BANCO HIPOTECARIO', 'sub': 'SUCURSAL AV. DE MAYO Y CHACABUCO', 'category': 'institution', 'style': 'bank_hipotecario', 'address': 'Av. de Mayo 599 esq. Chacabuco', 'street': 'Avenida de Mayo', 'side': 'west', 'point': [-1411.3, 690.9], 'osm_id': 477554906, 'building_id': 477554906},
]


def annotate_featured_places(data, ways, pts):
    all_buildings = data['buildings'] + data['generated_buildings']
    by_osm = {int(b.get('osm_id', 0)): b for b in data['buildings'] if int(b.get('osm_id', 0)) != 0}
    b_polys = [(b, Polygon(b['points'])) for b in all_buildings]

    by_street = {}
    for r in data.get('roads', []) + data.get('streets', []):
        name = r.get('name', '') or 'Avenida Rivadavia'
        if len(r['points']) >= 2:
            by_street.setdefault(name, []).append(LineString(r['points']))
    if 'route' in data and len(data['route']['points']) >= 2:
        by_street.setdefault('Avenida Rivadavia', []).append(LineString(data['route']['points']))
    street_unions = {k: unary_union(v) for k, v in by_street.items()}
    all_streets = unary_union(list(street_unions.values()))

    featured = []
    for spec in FEATURED_SPECS:
        target = Point(spec['point'][0], spec['point'][1])
        street_geom = street_unions.get(spec['street'], all_streets)

        host = by_osm.get(int(spec.get('building_id', 0)))
        if host is not None:
            host_poly = Polygon(host['points'])
        else:
            req_side = spec.get('side', '')
            candidates = []
            if req_side:
                for b, poly in b_polys:
                    if poly.distance(target) > 55.0:
                        continue
                    c = poly.centroid
                    st_pt = nearest_points(c, street_geom)[1]
                    if req_side == 'west' and c.x < st_pt.x - 1.0:
                        candidates.append((b, poly))
                    elif req_side == 'east' and c.x > st_pt.x + 1.0:
                        candidates.append((b, poly))
                    elif req_side == 'north' and c.y < st_pt.y - 1.0:
                        candidates.append((b, poly))
                    elif req_side == 'south' and c.y > st_pt.y + 1.0:
                        candidates.append((b, poly))
            if candidates:
                host, host_poly = min(candidates, key=lambda item: item[1].distance(target))
            else:
                host, host_poly = min(b_polys, key=lambda item: item[1].distance(target))

        coords = list(host_poly.exterior.coords)
        best_edge = None
        for a, b in zip(coords, coords[1:]):
            seg = LineString([a, b])
            if seg.length < 2.5:
                continue
            mid = Point((a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5)
            st_pt = nearest_points(mid, street_geom)[1]
            dist_street = mid.distance(st_pt)
            dist_target = mid.distance(target)
            dx, dy = b[0] - a[0], b[1] - a[1]
            length = max(0.01, (dx * dx + dy * dy) ** 0.5)
            normal = [-dy / length, dx / length]
            if host_poly.contains(Point(mid.x + normal[0] * 0.2, mid.y + normal[1] * 0.2)):
                normal = [-normal[0], -normal[1]]
            to_st_x, to_st_y = st_pt.x - mid.x, st_pt.y - mid.y
            dot = normal[0] * to_st_x + normal[1] * to_st_y
            if dot <= 0:
                continue
            score = dist_street * 2.5 + dist_target
            if best_edge is None or score < best_edge[0]:
                best_edge = (score, a, b, seg)

        if best_edge is None:
            best_edge = (999, coords[0], coords[1], LineString([coords[0], coords[1]]))

        _, ea, eb, seg = best_edge
        # If the host edge is wider than 13m (e.g. a large block parcel), slice a 11m storefront centered near target
        if seg.length > 13.5:
            center_s = max(5.5, min(seg.length - 5.5, seg.project(target)))
            p0 = seg.interpolate(center_s - 5.5)
            p1 = seg.interpolate(center_s + 5.5)
            ea, eb = (p0.x, p0.y), (p1.x, p1.y)

        front = _front_dict(ea, eb, host_poly)
        mid = Point((front['a'][0] + front['b'][0]) * 0.5, (front['a'][1] + front['b'][1]) * 0.5)
        street_pt = nearest_points(mid, street_geom)[1]
        front['visit'] = [round(street_pt.x, 2), round(street_pt.y, 2)]

        entry = dict(spec)
        entry['height'] = float(host.get('height', 6.4))
        entry['front'] = front
        entry['visit'] = front['visit']
        featured.append(entry)

    data['featured_places'] = featured

    data['featured_places'] = featured

    # Detailed plazas metadata (Sarmiento, Belgrano, Mitre, Bomberitos)
    plazas = []
    for lm in data['landmarks']:
        if lm.get('type') != 'green':
            continue
        lname = lm.get('name', '')
        if lname in ['Plaza Domingo Faustino Sarmiento', 'Plaza Bartolomé Mitre', 'Plaza Bomberitos']:
            poly = Polygon(lm['points'])
            c = poly.representative_point()
            plazas.append({
                'name': lname,
                'osm_id': lm.get('osm_id', 0),
                'center': [round(c.x, 2), round(c.y, 2)],
                'points': lm['points'][:-1] if lm['points'][0] == lm['points'][-1] else lm['points'],
            })
    # Also add Plazoleta General Manuel Belgrano (OSM way 429407286 & monument node 4285621772 at [-1191.4, 334.1])
    w_belgrano = next((w for w in ways if w['id'] == 429407286), None)
    belgrano_pts = [pts[n] for n in w_belgrano['nodes'] if n in pts] if w_belgrano else [[-1210.7, 321.2], [-1185.0, 328.0], [-1192.0, 342.0]]
    plazas.append({
        'name': 'Plazoleta General Manuel Belgrano',
        'osm_id': 429407286,
        'center': [-1191.4, 334.1],
        'monument_point': [-1191.4, 334.1],
        'points': belgrano_pts[:-1] if len(belgrano_pts) > 3 and belgrano_pts[0] == belgrano_pts[-1] else belgrano_pts,
    })
    data['detailed_plazas'] = plazas
    _annotate_central_corridors(data, street_unions)
    return featured


def _annotate_central_corridors(data, street_unions):
    """Enhance all buildings along Av. de Mayo (Rivadavia to Chacabuco) and Av. Rivadavia (Pueyrredón to Av. de Mayo)."""
    from shapely.geometry import box as sbox
    mayo_geom = street_unions.get('Avenida de Mayo', LineString()).intersection(sbox(-1560, 90, -1330, 730))
    riv_geom = street_unions.get('Avenida Rivadavia', LineString()).intersection(sbox(-1540, -10, -1050, 145))
    if mayo_geom.is_empty or riv_geom.is_empty:
        return

    all_buildings = data['buildings'] + data['generated_buildings']
    for idx, b in enumerate(all_buildings):
        if b.get('type') == 'roof':
            continue
        poly = Polygon(b['points'])
        if poly.area < 12.0:
            continue
        d_mayo = poly.distance(mayo_geom)
        d_riv = poly.distance(riv_geom)
        if d_mayo > 26.0 and d_riv > 28.0:
            continue

        corridor = 'av_de_mayo' if d_mayo <= d_riv else 'rivadavia_centro'
        target_geom = mayo_geom if corridor == 'av_de_mayo' else riv_geom
        b['central_corridor'] = corridor

        # Upgrade low generic heights along the central commercial avenues (keep recognizable buildings untouched)
        if not b.get('recognizable') and float(b.get('height', 6.2)) < 9.2:
            bid_seed = int(b.get('osm_id', 0)) + int(b.get('generated_id', idx)) * 7
            levels = 3 + (bid_seed % 4)  # 3 to 6 levels (9.6m to 19.2m) in downtown Ramos
            b['height'] = round(levels * 3.2, 2)

        coords = list(poly.exterior.coords)
        c_fronts = []
        for a, c in zip(coords, coords[1:]):
            seg_len = math.dist(a, c)
            if seg_len < 3.6:
                continue
            mid = Point((a[0] + c[0]) * 0.5, (a[1] + c[1]) * 0.5)
            near_pt = nearest_points(mid, target_geom)[1]
            dist = mid.distance(near_pt)
            if dist > 27.0:
                continue
            fdict = _front_dict(a, c, poly)
            to_street = [near_pt.x - mid.x, near_pt.y - mid.y]
            dot = fdict['normal'][0] * to_street[0] + fdict['normal'][1] * to_street[1]
            if dot <= 0.0:
                continue
            fdict['distance'] = round(dist, 2)
            fdict['towards'] = [round(to_street[0], 2), round(to_street[1], 2)]
            c_fronts.append(fdict)

        if c_fronts:
            b['central_fronts'] = c_fronts
            if 'front' not in b:
                best_f = min(c_fronts, key=lambda item: item['distance'])
                b['front'] = {
                    'distance': best_f['distance'],
                    'a': best_f['a'],
                    'b': best_f['b'],
                    'towards': best_f['towards'],
                }

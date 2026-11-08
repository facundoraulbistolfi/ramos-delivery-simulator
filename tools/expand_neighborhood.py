"""Select real street-bounded blocks; requires shapely 2.x only for rebuilding."""
import sys
import math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'.tools/gis_libs'))
import shapely
from shapely.geometry import Point,LineString,Polygon,box
from shapely.ops import unary_union,polygonize,triangulate,nearest_points
from recognizable_buildings import annotate,annotate_featured_places
from block_density import plan_blocks,fill_blocks,simple_polygons

ROAD_TYPES={'primary','secondary','tertiary','residential','unclassified','living_street','primary_link','secondary_link','tertiary_link','service'}

def clean_street_name(name):
    if 'Gaona' in name:return 'Avenida Gaona'
    if 'Puente Díaz Vélez' in name:return 'Puente Díaz Vélez'
    if 'Díaz Vélez' in name:return 'Avenida Díaz Vélez'
    if 'República' in name:return 'Avenida República'
    if 'Rivadavia' in name and name!='Segunda Rivadavia':return 'Avenida Rivadavia'
    return name

def width_for(tags):
    if 'width' in tags:
        try:return float(tags['width'].split()[0]),'OSM width'
        except ValueError:pass
    lanes=int(tags.get('lanes','2').split(';')[0])
    name=tags.get('name','')
    hwy=tags.get('highway','')
    if 'Rivadavia' in name:
        return (8.5 if tags.get('oneway')=='yes' else (18.0 if lanes>=4 else 13.0)),'estimated lanes + kerb space'
    if name=='Avenida de Mayo':
        return (15.0 if tags.get('parking:left:orientation')=='diagonal' else (18.0 if lanes>=4 else 13.0)),'estimated lanes + parking'
    if hwy=='service':return 5.0,'estimated service road'
    if hwy in ['primary', 'primary_link']:
        return (16.0 if lanes>=4 else 13.0),'primary carriageway'
    if hwy in ['secondary', 'secondary_link']:
        return (11.5 if lanes>=3 else 10.0),'secondary carriageway'
    if hwy in ['tertiary', 'tertiary_link']:
        return (10.0 if lanes>=3 else 9.0),'tertiary carriageway'
    return (8.5 if lanes<=2 else max(8.5, lanes*3.0 + 2.5)),'residential carriageway'

def triangulate_polygon_2d(pts):
    if len(pts) < 3: return []
    if len(pts) == 3: return [pts]
    poly = [list(p) for p in pts]
    area2 = sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1] for i in range(len(poly)))
    if area2 < 0: poly.reverse()
    def is_convex(p0, p1, p2):
        return (p1[0] - p0[0]) * (p2[1] - p0[1]) - (p1[1] - p0[1]) * (p2[0] - p0[0]) > 1e-7
    def pt_in_tri(p, a, b, c):
        def sign(p1, p2, p3):
            return (p1[0] - p3[0]) * (p2[1] - p3[1]) - (p2[0] - p3[0]) * (p1[1] - p3[1])
        d1 = sign(p, a, b)
        d2 = sign(p, b, c)
        d3 = sign(p, c, a)
        return not (((d1 < -1e-6) or (d2 < -1e-6) or (d3 < -1e-6)) and ((d1 > 1e-6) or (d2 > 1e-6) or (d3 > 1e-6)))
    tris = []
    n = len(poly)
    indices = list(range(n))
    limit = n * n * 2
    steps = 0
    while len(indices) > 2 and steps < limit:
        steps += 1
        ear_found = False
        m = len(indices)
        for i in range(m):
            prev_i = indices[(i - 1 + m) % m]
            curr_i = indices[i]
            next_i = indices[(i + 1) % m]
            p0, p1, p2 = poly[prev_i], poly[curr_i], poly[next_i]
            if not is_convex(p0, p1, p2): continue
            inside = False
            for j in range(m):
                if j in ((i - 1 + m) % m, i, (i + 1) % m): continue
                if pt_in_tri(poly[indices[j]], p0, p1, p2):
                    inside = True; break
            if not inside:
                tris.append([p0, p1, p2])
                indices.pop(i)
                ear_found = True; break
        if not ear_found:
            p0, p1, p2 = poly[indices[0]], poly[indices[1]], poly[indices[2]]
            tris.append([p0, p1, p2])
            indices.pop(1)
    return tris

def parts(geometry):
    if geometry.is_empty:return []
    if geometry.geom_type in ['Polygon','LineString']:return [geometry]
    return [p for g in getattr(geometry,'geoms',[]) for p in parts(g)]

def expand(data,ways,pts):
    route=LineString(data['route']['points'])
    xmin,xmax=route.bounds[0],route.bounds[2]
    rail=[];street_ways=[];lines=[]
    for w in ways:
        t=w['tags'];p=[pts[i] for i in w['nodes'] if i in pts]
        if len(p)<2:continue
        if t.get('railway')=='rail':rail.append(LineString(p))
        if t.get('highway') not in ROAD_TYPES or t.get('access')=='private':continue
        if t.get('highway')=='service':continue
        line=LineString(p)
        if line.length<1:continue
        street_ways.append((w,line));lines.append(line)
    # Complete street faces, not an arbitrary 200 m strip. Tiny traffic islands do not count as blocks.
    all_faces=list(polygonize(unary_union(lines)))
    faces=[p for p in all_faces if 500<p.area<120000]
    wmap={w['id']:[pts[n] for n in w['nodes'] if n in pts] for w in ways}
    bways=[w for w in data.get('ramos_boundary_ways',[]) if w in wmap and len(wmap[w])>=2]
    chain=[LineString(wmap[w]) for w in bways]
    if 48799394 in wmap and 1259582401 in wmap and 129477783 in wmap:
        chain.append(LineString([wmap[48799394][0],wmap[1259582401][-1]]))
        chain.append(LineString([wmap[1259582401][0],wmap[129477783][0]]))
    ramos_locality=unary_union(list(polygonize(unary_union(chain)))) if chain else Polygon()
    # 7-street bounding polygon: Díaz Vélez (and República to Gaona), Gaona, Güemes,
    # Av. de Mayo, General Alvarado, Viamonte, and Profesor Juan T. Pizzurno.
    polygon_7_streets=Polygon([
        (305.4, 240.4),
        (283.0, 221.0),
        (197.5, 143.6),
        (-139.3, -155.0),
        (-270.9, -274.2),
        (-490.5, -472.9),
        (-1092.2, -256.0),
        (-1360.8, -229.9),
        (-1471.9, -209.4),
        (-1548.0, -196.1),
        (-1499.0, 55.3),
        (-1505.4, 105.4),
        (-1482.7, 130.1),
        (-1448.3, 303.1),
        (-1392.7, 601.4),
        (-1321.0, 996.6),
        (-937.4, 623.7),
        (-869.9, 695.5),
        (-676.4, 517.2),
        (-377.2, 238.4),
        (-294.2, 235.6),
        (-130.4, 238.8),
        (305.4, 240.4),
    ])
    clip=box(-3850,-1350,1950,3150)
    south=[];north=[]
    def route_z(x):
        near=route.interpolate(route.project(Point(x,0)))
        # The longitudinal avenue is almost east/west; vertical intersection is exact.
        intersection=route.intersection(LineString([(x,-2000),(x,2000)]))
        if intersection.geom_type=='Point':return intersection.y
        return near.y
    # Southern first row touches the avenue; second row shares a street edge with the first.
    for p in faces:
        if p.area<=900 or p.area>=90000:continue
        c=p.representative_point()
        if not xmin-80<c.x<xmax+80:continue
        z=route_z(c.x)
        if c.y>z+6 and p.distance(route)<22 and c.y<z+260:south.append(p)
    second=[]
    for p in faces:
        if p.area<=900 or p.area>=90000:continue
        c=p.representative_point()
        if not xmin-80<c.x<xmax+80 or c.y<route_z(c.x)+20:continue
        if any(p.equals(q) for q in south):continue
        if any(p.boundary.intersection(q.boundary).length>10 for q in south):second.append(p)
    # First block on the north side of the parallel street behind the railway.
    northern_edges=[line for w,line in street_ways if w['tags'].get('loc_name')=='Segunda Rivadavia' or w['tags'].get('name') in ['Doctor Gabriel Ardoino','Leandro N. Alem']]
    north_edge=unary_union(northern_edges)
    for p in faces:
        if p.area<=900 or p.area>=90000:continue
        c=p.representative_point()
        if not xmin-80<c.x<xmax+80:continue
        if c.y<route_z(c.x)-20 and p.distance(north_edge)<1.0:north.append(p)
    poly_buf=unary_union([polygon_7_streets.buffer(8.0),ramos_locality.buffer(12.0)])
    shapely.prepare(poly_buf)
    poly_faces=[p for p in faces if poly_buf.covers(p.representative_point())]
    selected=list(south+second+north)
    sel_union=unary_union(selected)
    shapely.prepare(sel_union)
    for p in poly_faces:
        if not sel_union.covers(p.representative_point()):
            selected.append(p)
    # 5-block extension in all directions around Ramos Mejía (~550m buffer)
    extended_locality = ramos_locality.buffer(550.0) if not ramos_locality.is_empty else polygon_7_streets.buffer(550.0)
    shapely.prepare(extended_locality)
    extended_faces = [p for p in faces if extended_locality.covers(p.representative_point()) and 500 < p.area < 120000]
    for p in extended_faces:
        if not sel_union.covers(p.representative_point()):
            selected.append(p)
    assert south and second and north and poly_faces,('missing block rows',len(south),len(second),len(north),len(poly_faces))
    area=unary_union(selected+[polygon_7_streets.buffer(16),ramos_locality.buffer(16),extended_locality,route.buffer(30),north_edge.intersection(clip).buffer(12)]).intersection(clip).buffer(9)
    shapely.prepare(area)
    # Official Ramos Mejía boundary polygon and transparent perimeter barrier wall
    data['ramos_boundary']=[[round(x,1),round(y,1)] for x,y in list(ramos_locality.exterior.coords)[:-1]] if not ramos_locality.is_empty else []
    b_pts = data['ramos_boundary']
    data['boundary_wall'] = [[b_pts[i], b_pts[(i + 1) % len(b_pts)]] for i in range(len(b_pts))] if len(b_pts) >= 3 else []
    ext_clip=box(-4500,-1700,2350,3500)
    ext_outside=ext_clip.difference(area.buffer(-2.0))
    shapely.prepare(ext_outside)
    ext_streets=[]
    for w,line in street_ways:
        if not ext_outside.intersects(line):continue
        t=w['tags']
        width,_=width_for(t)
        for part in parts(line.intersection(ext_outside)):
            if part.geom_type!='LineString' or part.length<5:continue
            simp=part.simplify(0.6,preserve_topology=False)
            ext_streets.append({'name':clean_street_name(t.get('name','')),'width':round(width,1),'points':[[round(x,1),round(y,1)] for x,y in simp.coords]})
    data['extended_streets']=ext_streets
    ext_railways=[]
    for line in rail:
        for part in parts(line.intersection(ext_clip)):
            if part.geom_type=='LineString' and part.length>3:
                simp=part.simplify(0.6,preserve_topology=False)
                ext_railways.append([[round(x,1),round(y,1)] for x,y in simp.coords])
    data['extended_railways']=ext_railways
    data['coverage']={'south_block_rows':2,'north_block_rows':1,'north_reference':'full locality of Ramos Mejía (OSM relation 1748197)','locality':'Ramos Mejía','boundary_streets':['Avenida Díaz Vélez','Avenida República','Avenida Gaona','Blas Parera','Avenida Rivadavia','Fray Cayetano Rodríguez','Avenida Don Bosco','Avenida Eva Perón','Martín Miguel de Güemes','Avenida de Mayo','General Alvarado','Viamonte','Profesor Juan T. Pizzurno'],'block_counts':{'south_first':len(south),'south_second':len(second),'north':len(north),'locality_blocks':len(poly_faces),'total':len(selected)},'polygons':[list(p.exterior.coords)[:-1] for p in parts(area) if p.geom_type=='Polygon'],'bounds':list(area.bounds)}
    ELEVATED_BRIDGE_WAY_IDS={26509721,223940155,223940157,1125195767,1125195768,1147413225,1147413227,1147413228,1217461277,1185295822}
    streets=[]
    riv_corridor=box(xmin+0.5,-250,xmax-0.5,250)
    for w,line in street_ways:
        is_riv=w['tags'].get('highway')=='primary' and 'Rivadavia' in w['tags'].get('name','')
        geom=line.difference(riv_corridor) if is_riv else line
        width,source=width_for(w['tags'])
        for part in parts(geom.intersection(area)):
            if part.geom_type!='LineString' or part.length<2:continue
            t=w['tags']
            is_br=t.get('bridge')=='yes' or (w['id'] in ELEVATED_BRIDGE_WAY_IDS)
            streets.append({'osm_id':w['id'],'name':clean_street_name(t.get('name','')),'points':list(part.coords),'width':width,'width_source':source,'lanes':int(t.get('lanes','2').split(';')[0]),'oneway':t.get('oneway')=='yes','bridge':is_br,'layer':int(t.get('layer','1' if is_br else '0'))})
    data['streets']=streets
    data['bridges']=[
        {
            'key':'diaz_velez',
            'name':'Puente Díaz Vélez - República',
            'address':'Av. Díaz Vélez y Av. Rivadavia ↔ Av. República',
            'style':'vehicular_concrete',
            'width':9.6,
            'visit':[283.0,221.0],
            'visit_dir':[-0.74,-0.67],
            'points_3d':[
                [283.02,0.02,221.02],
                [240.23,3.10,182.31],
                [197.45,6.20,143.60],
                [113.26,6.45,68.94],
                [29.08,6.65,-5.71],
                [-55.11,6.45,-80.37],
                [-139.29,6.20,-155.02],
                [-167.51,3.10,-180.05],
                [-195.72,0.02,-205.09],
            ]
        },
        {
            'key':'u_bridge_east',
            'name':'Puente en U Papa Francisco (Mano a Ardoino)',
            'address':'Av. Rivadavia e/ Necochea y Alvear ↔ Gabriel Ardoino',
            'style':'modular_u_bridge',
            'width':5.6,
            'visit':[-1576.7,104.6],
            'visit_dir':[-0.98,-0.19],
            'points_3d':[
                [-1576.67,0.05,104.62],
                [-1631.88,2.75,115.47],
                [-1687.09,5.40,126.32],
                [-1691.56,5.40,126.14],
                [-1695.82,5.40,123.54],
                [-1698.06,5.40,119.92],
                [-1699.01,5.40,114.44],
                [-1698.70,5.40,109.96],
                [-1697.23,5.40,106.65],
                [-1695.06,5.40,104.09],
                [-1689.20,5.40,101.41],
                [-1626.09,2.75,89.04],
                [-1562.98,0.05,76.67],
            ]
        },
        {
            'key':'u_bridge_west',
            'name':'Puente en U Papa Francisco (Mano a Rivadavia)',
            'address':'Leandro N. Alem e/ Necochea y Alvear ↔ Av. Rivadavia',
            'style':'modular_u_bridge',
            'width':5.6,
            'visit':[-1872.2,135.4],
            'visit_dir':[0.98,-0.19],
            'points_3d':[
                [-1872.21,0.05,135.44],
                [-1803.62,2.75,121.62],
                [-1735.03,5.40,107.79],
                [-1731.43,5.40,108.01],
                [-1728.52,5.40,108.98],
                [-1724.42,5.40,112.32],
                [-1722.37,5.40,115.89],
                [-1721.24,5.40,119.87],
                [-1721.46,5.40,125.04],
                [-1723.29,5.40,129.79],
                [-1724.56,5.40,132.06],
                [-1727.27,5.40,134.35],
                [-1792.74,2.75,147.38],
                [-1858.20,0.05,160.40],
            ]
        }
    ]
    data['footbridges']=[
        {
            'key':'moreno_french',
            'name':'Puente Peatonal Pepino Tuccio (Moreno - French)',
            'address':'Mariano Moreno y Av. Rivadavia ↔ French y Ardoino',
            'width':3.2,
            'visit':[-1267.3,73.0],
            'visit_dir':[0.35,-0.94],
            'points_3d':[
                [-1234.63,0.05,-18.83],
                [-1232.02,5.50,-2.30],
                [-1229.44,5.50,13.39],
                [-1242.52,5.50,30.01],
                [-1262.10,5.50,34.36],
                [-1259.13,5.50,50.33],
                [-1255.57,5.50,70.08],
                [-1267.26,0.05,72.97],
            ]
        }
    ]
    buildings=[];landmarks=[];railways=[]
    for w in ways:
        t=w['tags'];p=[pts[i] for i in w['nodes'] if i in pts]
        if len(p)<2:continue
        line=LineString(p)
        if not area.intersects(line) and not (len(p)>3 and p[0]==p[-1] and Polygon(p).intersects(area)):continue
        if 'building' in t and len(p)>3 and p[0]==p[-1]:
            try:height=float(t.get('height',str(float(t.get('building:levels','2'))*3.1)))
            except ValueError:height=6.2
            source_height=height
            if height<=0:height=3.1
            poly=Polygon(p).buffer(0)
            for sp in simple_polygons(poly):
                if sp.area<2.0 or not area.intersects(sp):continue
                buildings.append({'osm_id':w['id'],'points':list(sp.exterior.coords)[:-1],'height':height,'source_height':source_height,'height_source':('assumed_minimum_invalid_OSM' if source_height<=0 else ('OSM' if 'height' in t or 'building:levels' in t else 'assumed_2_levels')),'name':t.get('name',''),'type':t['building']})
        if t.get('railway')=='rail':
            for segment in parts(line.intersection(area.buffer(12))):
                if segment.geom_type=='LineString':railways.append({'osm_id':w['id'],'points':list(segment.coords)})
        kind='platform' if t.get('railway')=='platform' else ('green' if t.get('leisure') in ['park','garden'] or t.get('landuse') in ['grass','village_green'] else None)
        if kind and len(p)>3 and p[0]==p[-1]:landmarks.append({'osm_id':w['id'],'name':t.get('name',''),'points':p,'type':kind})
    data['buildings']=buildings
    hospital_campus=annotate(data,ways,pts)
    data['railways']=railways
    data['landmarks']=[p for p in data['landmarks'] if p['type']=='station']+landmarks
    data['trees']=[p for p in data.get('trees',[]) if area.covers(Point(p))]
    # Retain the mapped small triangular island at the mouth of Av. de Mayo.
    tanga=next(w for w in ways if w['id']==595185877)
    data['tanga']={'name':'La Tanga de Ramos Mejía','osm_green_id':595185877,'points':[pts[i] for i in tanga['nodes'][:-1]],'reference':'https://deramosdigital.com.ar/2021/11/01/robaron-la-palabra-localidad-del-nuevo-cartel-de-bienvenida-a-ramos-mejia/','width_note':'road widths include parking/kerb allowance; estimates, not a field survey'}
    green=Polygon(data['tanga']['points'])
    plaza_face=next((p for p in all_faces if p.covers(green.representative_point())),None)
    plaza=plaza_face.buffer(-4.0) if plaza_face is not None and plaza_face.area<1800 else green.buffer(1.5,join_style=2)
    if plaza.is_empty:plaza=green
    data['tanga']['plaza_points']=list(plaza.exterior.coords)[:-1]
    print('TANGA green',round(green.area,1),'face',round(plaza_face.area,1) if plaza_face is not None else None,'plaza',round(plaza.area,1))
    # Ground surfaces are unions: intersections have no narrow seams or artificial blockages.
    road_polygons=unary_union([LineString(r['points']).buffer(r['width']/2,cap_style=2,join_style=2) for r in data['roads']+streets if not r.get('bridge')])
    data['pavement']=[{'outer':list(p.exterior.coords)[:-1],'holes':[list(r.coords)[:-1] for r in p.interiors]} for p in parts(road_polygons) if p.geom_type=='Polygon']
    # Strictly clip all green spaces and parks outside road carriageways with curb buffer so grass never crosses streets
    clean_landmarks = []
    road_curb_clip = road_polygons.buffer(0.35, join_style=2)
    for lm in data['landmarks']:
        if lm.get('type') == 'green':
            try:
                g_diff = Polygon(lm['points']).difference(road_curb_clip)
                for sp in simple_polygons(g_diff):
                    if sp.area >= 6.0:
                        clean_landmarks.append({'osm_id': lm.get('osm_id', 0), 'name': lm.get('name', ''), 'points': [[round(x, 2), round(y, 2)] for x, y in sp.exterior.coords][:-1], 'type': 'green'})
            except Exception:
                clean_landmarks.append(lm)
        else:
            clean_landmarks.append(lm)
    data['landmarks'] = clean_landmarks
    density_plan=plan_blocks(data,ways,pts,selected,area,road_polygons,hospital_campus,plaza)

    # LAYER 2 & 3: Blocks (Cuadras), Veredas (Sidewalks) & Curbs
    blocks = []
    sidewalk_polygons = []
    curb_lines = []
    rail_corridor = unary_union([LineString(r['points']).buffer(8.0, cap_style=2, join_style=2) for r in data['railways']])

    for face in selected:
        block_clean = face.difference(road_polygons).difference(rail_corridor)
        for cp in parts(block_clean):
            if cp.geom_type != 'Polygon' or cp.area < 25.0:
                continue

            # Contact curb line against road carriageway
            c_boundary = cp.boundary.intersection(road_polygons.buffer(0.35, join_style=2))
            for cline in parts(c_boundary):
                if cline.geom_type == 'LineString' and cline.length > 0.8:
                    simp = cline.simplify(0.2, preserve_topology=False)
                    curb_lines.append([[round(x, 2), round(y, 2)] for x, y in simp.coords])

            # Sidewalk width: 3.5m on avenue corridor, 3.2m elsewhere, adapted for small islands
            sw = 3.5 if cp.distance(route) < 30.0 else 3.2
            if cp.area < 450.0:
                sw = max(1.8, min(sw, math.sqrt(cp.area) * 0.16))

            mun_poly = cp.buffer(-sw, join_style=2)
            if mun_poly.is_empty or mun_poly.area < 25.0:
                for sp in simple_polygons(cp):
                    if sp.area >= 2.0:
                        sidewalk_polygons.append([[round(x, 2), round(y, 2)] for x, y in sp.exterior.coords][:-1])
            else:
                sidewalk_ring = cp.difference(mun_poly)
                for sp in simple_polygons(sidewalk_ring):
                    if sp.area >= 2.0:
                        sidewalk_polygons.append([[round(x, 2), round(y, 2)] for x, y in sp.exterior.coords][:-1])

            mun_parts = [p for p in parts(mun_poly) if p.geom_type == 'Polygon' and p.area >= 10.0]
            mun_coords = [list(mp.exterior.coords)[:-1] for mp in mun_parts]
            blocks.append({
                'id': len(blocks),
                'curb_points': [[round(x, 2), round(y, 2)] for x, y in cp.exterior.coords][:-1],
                'municipal_points': [[round(x, 2), round(y, 2)] for x, y in mun_coords[0]] if mun_coords else [],
                'all_municipal_parts': [[[round(x, 2), round(y, 2)] for x, y in c] for c in mun_coords],
                'area': round(cp.area, 1)
            })

    data['blocks'] = blocks
    data['sidewalk_polygons'] = sidewalk_polygons
    data['curb_lines'] = curb_lines

    # Exact ear-clipped sidewalk triangles (no Delaunay spilling into intersections)
    sidewalk_triangles = []
    for poly_pts in sidewalk_polygons:
        for tri in triangulate_polygon_2d(poly_pts):
            sidewalk_triangles.append([[round(x, 2), round(y, 2)] for x, y in tri])
    data['sidewalk_triangles'] = sidewalk_triangles

    # Road pavement triangles
    p_buf = road_polygons.buffer(0.02)
    shapely.prepare(road_polygons)
    shapely.prepare(p_buf)
    data['pavement_triangles'] = [list(t.exterior.coords)[:-1] for p in parts(road_polygons) if p.geom_type == 'Polygon' for t in triangulate(p) if road_polygons.covers(t.representative_point()) and p_buf.covers(t)]

    # Clip mapped OSM buildings strictly to municipal interior (private blocks)
    clean_buildings = []
    for b in data['buildings']:
        osm_id = int(b.get('osm_id', 0))
        rec = str(b.get('recognizable', ''))
        poly = Polygon(b['points']).buffer(0)
        if rec != '' or osm_id in [636863311, 27233077, 475920381] or hospital_campus.intersects(poly):
            diff = poly.difference(road_polygons.buffer(0.2, join_style=2))
            if not diff.is_empty and diff.area >= 10.0:
                p_largest = max(parts(diff), key=lambda g: g.area)
                b['points'] = [[round(x, 2), round(y, 2)] for x, y in p_largest.exterior.coords][:-1]
                clean_buildings.append(b)
        else:
            b_clean = poly.intersection(density_plan['private'].buffer(0.05, join_style=2))
            if not b_clean.is_empty and b_clean.area >= 12.0:
                for sp in simple_polygons(b_clean):
                    if sp.area >= 12.0:
                        b_copy = dict(b)
                        b_copy['points'] = [[round(x, 2), round(y, 2)] for x, y in sp.exterior.coords][:-1]
                        clean_buildings.append(b_copy)
    data['buildings'] = clean_buildings
    buildings = clean_buildings

    occupied=[Polygon(b['points']).buffer(1.5,join_style=2) for b in buildings]
    occupied.append(density_plan['reserved'])
    occupied.append(hospital_campus)
    occupied += [Polygon(l['points']).buffer(1,join_style=2) for l in landmarks if l['type']=='green']
    occupied += [line.buffer(9,cap_style=2,join_style=2) for line in rail]
    occupied += [road_polygons.buffer(3.4,join_style=2),plaza.buffer(1,join_style=2)]
    unavailable=unary_union(occupied)
    shapely.prepare(unavailable)

    # Procedural Lot and House Generation for all non-plaza blocks
    lots = []
    houses = []
    generated_fronts = []
    mapped_buildings_union = unary_union([Polygon(b['points']) for b in buildings])
    shapely.prepare(mapped_buildings_union)

    for block_id, b_int in enumerate(simple_polygons(density_plan['private'])):
        if b_int.area < 120:
            continue
        coords = list(b_int.exterior.coords)
        for i in range(len(coords) - 1):
            a, b = coords[i], coords[i + 1]
            dx, dy = b[0] - a[0], b[1] - a[1]
            L = math.hypot(dx, dy)
            if L < 14.0:
                continue
            mid_seg = Point((a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5)
            in_ramos = ramos_locality.covers(mid_seg)
            w_tgt = 24.0 if in_ramos else 34.0
            n = max(1, round(L / w_tgt))
            w = L / n
            ux, uy = dx / L, dy / L
            nx, ny = -uy, ux
            test_pt = Point((a[0] + b[0]) / 2 + nx * 2.0, (a[1] + b[1]) / 2 + ny * 2.0)
            if not b_int.covers(test_pt):
                nx, ny = -nx, -ny
            d = min(26.0, max(14.0, math.sqrt(b_int.area) * 0.28))
            for k in range(n):
                f0 = (a[0] + ux * (k * w), a[1] + uy * (k * w))
                f1 = (a[0] + ux * ((k + 1) * w), a[1] + uy * ((k + 1) * w))
                b1 = (f1[0] + nx * d, f1[1] + ny * d)
                b0 = (f0[0] + nx * d, f0[1] + ny * d)
                cand = Polygon([f0, f1, b1, b0])
                poly = cand.intersection(b_int).buffer(0)
                polys_to_add = [p for p in getattr(poly, 'geoms', [poly]) if p.geom_type == 'Polygon' and p.area >= 38.0 and p.is_valid]
                for sub_poly in polys_to_add:
                    if mapped_buildings_union.intersection(sub_poly).area > 10.0:
                        continue
                    lot_id = len(lots)
                    lot_pts = [[round(x, 2), round(y, 2)] for x, y in sub_poly.exterior.coords][:-1]
                    lots.append({
                        "id": lot_id,
                        "block_id": block_id,
                        "points": lot_pts,
                        "area": round(sub_poly.area, 1)
                    })
                    # House footprints occupy the lot with party walls (casas entre medianeras típicas de Ramos)
                    h_pts = lot_pts
                    mid_x = sum(p[0] for p in h_pts) / len(h_pts)
                    mid_y = sum(p[1] for p in h_pts) / len(h_pts)
                    is_avenue = abs(mid_y) < 32.0 or abs(mid_x + 1380.0) < 30.0
                    h_height = 12.0 + (lot_id % 3) * 3.2 if is_avenue else 3.4 + (lot_id % 3) * 3.1
                    c_idx = (lot_id * 7 + block_id * 11) % 8
                    r_type = "terrace" if h_height > 8.0 else ("tiles" if lot_id % 2 == 0 else "terrace")
                    front_dict = {
                        "distance": 3.5,
                        "a": [round(f0[0], 2), round(f0[1], 2)],
                        "b": [round(f1[0], 2), round(f1[1], 2)],
                        "towards": [round(-nx * 5.0, 2), round(-ny * 5.0, 2)]
                    }
                    house_entry = {
                        "osm_id": 0,
                        "generated_id": len(houses),
                        "lot_id": lot_id,
                        "block_id": block_id,
                        "points": h_pts,
                        "height": round(h_height, 1),
                        "color_idx": c_idx,
                        "roof_type": r_type,
                        "type": "generic_house",
                        "height_source": "procedural house layer",
                        "name": "",
                        "front": front_dict
                    }
                    houses.append(house_entry)
                    generated_fronts.append(front_dict)

    data['lots'] = lots
    data['houses'] = houses
    data['generated_buildings'] = list(houses)
    fill_blocks(data, density_plan)
    tree_forbidden=unary_union([
        road_polygons.buffer(1.25),
        density_plan['private'].buffer(0.8),
        unary_union([Polygon(b['points']).buffer(0.9) for b in buildings + data['generated_buildings']]),
        unary_union([line.buffer(8.5) for line in rail]),
        plaza.buffer(6.0),
    ])
    shapely.prepare(tree_forbidden)
    kept_trees=[p for p in data.get('trees',[]) if area.covers(Point(p)) and not tree_forbidden.covers(Point(p))]
    tree_grid={}
    for t in kept_trees:
        tree_grid.setdefault((int(t[0]//28),int(t[1]//28)),[]).append(t)
    for road in streets:
        if road.get('bridge'):continue
        line=LineString(road['points'])
        if line.length<50:continue
        for dist_s in range(22,int(line.length)-18,58):
            p=line.interpolate(dist_s);a=line.interpolate(max(0,dist_s-1));b=line.interpolate(min(line.length,dist_s+1))
            dx,dy=b.x-a.x,b.y-a.y;length=math.hypot(dx,dy)
            if length<.01:continue
            ux,uy=dx/length,dy/length
            for side in [-1,1]:
                nx,ny=-uy*side,ux*side
                offset=road['width']/2+1.85
                cand=Point(p.x+nx*offset,p.y+ny*offset)
                if not area.covers(cand) or tree_forbidden.covers(cand):continue
                tx,tz=int(cand.x//28),int(cand.y//28)
                t_near=[ q for kx in (tx-1,tx,tx+1) for kz in (tz-1,tz,tz+1) for q in tree_grid.get((kx,kz),[]) ]
                if any(math.hypot(cand.x-t[0],cand.y-t[1])<24.0 for t in t_near):continue
                pt_arr=[round(cand.x,2),round(cand.y,2)]
                kept_trees.append(pt_arr)
                tree_grid.setdefault((tx,tz),[]).append(pt_arr)
    data['trees']=kept_trees
    street_axis=unary_union([LineString(r['points']) for r in data['roads']+streets])
    for building in buildings:
        polygon=Polygon(building['points']);vertices=list(polygon.exterior.coords)
        best=None
        for a,b in zip(vertices,vertices[1:]):
            middle=Point((a[0]+b[0])/2,(a[1]+b[1])/2)
            near=nearest_points(middle,street_axis)[1];distance=middle.distance(near)
            if math.dist(a,b)<3 or distance<1:continue
            if best is None or distance<best[0]:best=(distance,a,b,(near.x-middle.x,near.y-middle.y))
        if best:building['front']={'distance':best[0],'a':best[1],'b':best[2],'towards':best[3]}
    annotate_featured_places(data,ways,pts)
    _build_railway_barriers_and_crossings(data,road_polygons)
    print('NEIGHBORHOOD',data['coverage']['block_counts'],'streets',len(streets),'buildings',len(buildings),'generic',len(data['generated_buildings']),'featured',len(data.get('featured_places',[])),'trees',len(kept_trees))
    return data


def _build_railway_barriers_and_crossings(data,road_polygons):
    """Define exact level crossings, pedestrian crossings, and continuous railway perimeter barriers."""
    level_crossings=[
        {'key':'pan_colombres','name':'Paso a Nivel Colombres','kind':'vehicular','center':[-341.6,-33.0],'a':[-341.4,-45.5],'b':[-341.8,-20.5],'width':10.5,'visit':[-341.9,-12.0],'visit_dir':[0.0,-1.0]},
        {'key':'pan_carlos_calvo','name':'Paso a Nivel Carlos Calvo','kind':'vehicular','center':[-691.4,-36.4],'a':[-691.4,-46.0],'b':[-691.5,-26.8],'width':10.5,'visit':[-691.5,-17.0],'visit_dir':[0.0,-1.0]},
        {'key':'pan_monteagudo','name':'Paso a Nivel Monteagudo','kind':'vehicular','center':[-1056.2,-4.9],'a':[-1057.2,-14.5],'b':[-1055.2,4.5],'width':10.5,'visit':[-1054.5,13.5],'visit_dir':[-0.12,-0.99]},
        {'key':'pan_pastor_obligado','name':'Paso a Nivel Pastor Obligado','kind':'vehicular','center':[-2169.8,205.2],'a':[-2171.5,195.0],'b':[-2168.0,215.5],'width':10.5,'visit':[-2166.5,224.0],'visit_dir':[-0.17,-0.98]},
        {'key':'pan_medrano','name':'Paso a Nivel Medrano','kind':'vehicular','center':[-2569.6,281.5],'a':[-2571.8,269.0],'b':[-2567.3,294.0],'width':10.5,'visit':[-2565.5,303.0],'visit_dir':[-0.18,-0.98]},
    ]
    ped_crossings=[
        {'key':'peatonal_diaz_velez','name':'Cruce Peatonal Díaz Vélez','kind':'pedestrian','center':[-17.4,-22.4],'a':[-17.5,-36.0],'b':[-17.3,-8.0],'width':3.2},
        {'key':'peatonal_pueyrredon','name':'Cruce Peatonal Pueyrredón','kind':'pedestrian','center':[-796.1,-31.8],'a':[-796.6,-41.5],'b':[-795.7,-21.5],'width':3.2},
        {'key':'peatonal_estacion','name':'Cruce Peatonal Estación / Güemes','kind':'pedestrian','center':[-1495.8,77.3],'a':[-1496.9,66.0],'b':[-1494.7,88.5],'width':3.6},
        {'key':'peatonal_necochea','name':'Cruce Peatonal Necochea','kind':'pedestrian','center':[-1628.2,101.8],'a':[-1629.8,91.5],'b':[-1626.6,112.0],'width':3.4},
        {'key':'peatonal_alvear','name':'Cruce Peatonal Alvear','kind':'pedestrian','center':[-1901.5,155.5],'a':[-1903.2,145.5],'b':[-1899.8,165.5],'width':3.4},
        {'key':'peatonal_rivas','name':'Cruce Peatonal Gral. Rivas','kind':'pedestrian','center':[-2707.1,307.7],'a':[-2709.3,295.0],'b':[-2704.9,320.5],'width':3.2},
    ]
    data['railway_crossings']=level_crossings+ped_crossings
    rails=[LineString(r['points']) for r in data['railways']]
    platforms=[Polygon(p['points']).buffer(0.8,join_style=2) for p in data['landmarks'] if p['type']=='platform']
    corridor=unary_union([r.buffer(5.2,cap_style=2,join_style=2) for r in rails]+platforms).simplify(0.2,preserve_topology=True)
    openings=[road_polygons.buffer(0.9,join_style=2)]
    for c in level_crossings+ped_crossings:
        openings.append(LineString([c['a'],c['b']]).buffer(c['width']*0.5+0.8,cap_style=2,join_style=2))
    walls=corridor.boundary.difference(unary_union(openings))
    wall_lines=[]
    for seg in parts(walls):
        if seg.geom_type=='LineString' and seg.length>1.2:
            simp=seg.simplify(0.25,preserve_topology=False)
            wall_lines.append([[round(x,2),round(y,2)] for x,y in simp.coords])
    data['railway_walls']=wall_lines

    # Argentine street corner signposts (one corner per intersection)
    print("Generating street corner signposts...")
    data['street_signs'] = _generate_street_signs(data, road_polygons)

    # Realistic curbside parked cars (following street orientation & curbs)
    print("Generating parked cars along street curbs...")
    data['parked_cars'] = _generate_parked_cars(data)


def _generate_street_signs(data, road_polygons=None):
    from shapely.geometry import shape, Point, LineString
    from collections import defaultdict
    boundary = shape({'type': 'Polygon', 'coordinates': [data['ramos_boundary']]}) if data.get('ramos_boundary') else None
    streets_by_name = defaultdict(list)
    for s in data['streets']:
        name = s.get('name')
        if name and len(s['points']) >= 2:
            streets_by_name[name].append((LineString(s['points']), s))
    
    names = list(streets_by_name.keys())
    raw_intersections = []
    for i in range(len(names)):
        for j in range(i + 1, len(names)):
            n1, n2 = names[i], names[j]
            for l1, s1 in streets_by_name[n1]:
                for l2, s2 in streets_by_name[n2]:
                    if l1.intersects(l2):
                        inter = l1.intersection(l2)
                        pts = []
                        if inter.geom_type == 'Point': pts = [inter]
                        elif inter.geom_type == 'MultiPoint': pts = list(inter.geoms)
                        for pt in pts:
                            if boundary is None or boundary.contains(pt):
                                coords1 = list(l1.coords)
                                best_seg1 = None; best_dist1 = 999999
                                for k in range(len(coords1) - 1):
                                    seg = LineString([coords1[k], coords1[k+1]])
                                    dist = seg.distance(pt)
                                    if dist < best_dist1:
                                        best_dist1 = dist
                                        best_seg1 = (coords1[k], coords1[k+1])
                                coords2 = list(l2.coords)
                                best_seg2 = None; best_dist2 = 999999
                                for k in range(len(coords2) - 1):
                                    seg = LineString([coords2[k], coords2[k+1]])
                                    dist = seg.distance(pt)
                                    if dist < best_dist2:
                                        best_dist2 = dist
                                        best_seg2 = (coords2[k], coords2[k+1])
                                if best_seg1 and best_seg2:
                                    dx1 = best_seg1[1][0] - best_seg1[0][0]
                                    dz1 = best_seg1[1][1] - best_seg1[0][1]
                                    dx2 = best_seg2[1][0] - best_seg2[0][0]
                                    dz2 = best_seg2[1][1] - best_seg2[0][1]
                                    raw_intersections.append({
                                        'x': pt.x, 'z': pt.y,
                                        'name1': n1, 'oneway1': s1.get('oneway', False), 'width1': s1.get('width', 10.0),
                                        'dir1': [dx1, dz1],
                                        'name2': n2, 'oneway2': s2.get('oneway', False), 'width2': s2.get('width', 10.0),
                                        'dir2': [dx2, dz2]
                                    })
    
    # Cluster within 22m so strictly ONE signpost per intersection
    signs = []
    for item in raw_intersections:
        p = Point(item['x'], item['z'])
        found = False
        for s in signs:
            if Point(s['pos'][0], s['pos'][1]).distance(p) < 22.0:
                found = True
                break
        if not found:
            d1 = [item['dir1'][0], item['dir1'][1]]
            len1 = math.hypot(d1[0], d1[1]) or 1.0
            u1 = [d1[0]/len1, d1[1]/len1]
            n1 = [-u1[1], u1[0]]
            
            d2 = [item['dir2'][0], item['dir2'][1]]
            len2 = math.hypot(d2[0], d2[1]) or 1.0
            u2 = [d2[0]/len2, d2[1]/len2]
            n2 = [-u2[1], u2[0]]
            
            w1 = item['width1'] * 0.5 + 1.8
            w2 = item['width2'] * 0.5 + 1.8
            
            # Select sidewalk corner quadrant outside roadway
            best_cx = item['x'] + n1[0] * w1 + n2[0] * w2
            best_cz = item['z'] + n1[1] * w1 + n2[1] * w2
            if road_polygons is not None:
                found_corner = False
                for s1 in [1.0, -1.0]:
                    for s2 in [1.0, -1.0]:
                        cx = item['x'] + (n1[0] * w1 * s1) + (n2[0] * w2 * s2)
                        cz = item['z'] + (n1[1] * w1 * s1) + (n2[1] * w2 * s2)
                        cpt = Point(cx, cz)
                        if not road_polygons.contains(cpt):
                            dist_r = road_polygons.distance(cpt)
                            if 0.5 <= dist_r <= 3.2:
                                best_cx, best_cz = cx, cz
                                found_corner = True
                                break
                    if found_corner:
                        break

            yaw1 = math.atan2(-u1[1], u1[0])
            yaw2 = math.atan2(-u2[1], u2[0])
            
            dist_from_origin = math.hypot(item['x'], item['z'])
            block_num = int(round(dist_from_origin / 110.0)) * 100 + 100
            
            signs.append({
                'pos': [round(best_cx, 2), round(best_cz, 2)],
                'street1': item['name1'],
                'yaw1': round(yaw1, 4),
                'oneway1': item['oneway1'],
                'num1': f"{block_num} - {block_num + 100}",
                'street2': item['name2'],
                'yaw2': round(yaw2, 4),
                'oneway2': item['oneway2'],
                'num2': f"{block_num} - {block_num + 100}"
            })
    return signs


def _generate_parked_cars(data):
    """Generate realistic parked cars along residential and commercial street curbs in Ramos Mejía.
    Cars park parallel along curbs, leaving the center driving lane clear for moving traffic.
    Avoids intersections, railway crossings, bridges, and driveways."""
    import random
    random.seed(54321)

    railway_crossings = data.get('railway_crossings', [])
    rx_pts = [r['center'] for r in railway_crossings if 'center' in r]

    route_line = LineString(data['route']['points'])

    bridges = data.get('bridges', [])
    bridge_pts = []
    for b in bridges:
        for p in b.get('points_3d', []):
            bridge_pts.append((p[0], p[2]))

    models = ['sedan', 'suv', 'compact']
    colors = [
        [0.82, 0.84, 0.86], # Silver / Gris plata
        [0.94, 0.94, 0.92], # White / Blanco
        [0.26, 0.28, 0.30], # Dark Grey / Gris oscuro
        [0.10, 0.10, 0.10], # Black / Negro
        [0.12, 0.20, 0.42], # Navy Blue / Azul marino
        [0.62, 0.12, 0.14], # Deep Red / Rojo
        [0.68, 0.62, 0.52], # Champagne
        [0.45, 0.50, 0.56], # Light Blue / Celeste
    ]

    parked = []
    streets = data.get('streets', []) + data.get('roads', [])

    for s in streets:
        pts = s.get('points', [])
        if len(pts) < 2 or s.get('bridge', False):
            continue
        width = float(s.get('width', 10.0))
        oneway = bool(s.get('oneway', False))

        for i in range(len(pts) - 1):
            p0 = pts[i]
            p1 = pts[i+1]

            # Limit to core downtown Ramos Mejía where player navigates and delivers orders
            if not (-2000 <= p0[0] <= 320 and -480 <= p0[1] <= 620):
                continue

            dx = p1[0] - p0[0]
            dz = p1[1] - p0[1]
            seg_len = math.hypot(dx, dz)
            if seg_len < 22.0:
                continue

            tx = dx / seg_len
            tz = dz / seg_len
            # Right-side normal in local 2D (X east, Z south)
            nx = -tz
            nz = tx

            yaw_fwd = math.atan2(-tx, -tz)
            yaw_rev = math.atan2(tx, tz)

            offset = max(2.6, (width * 0.5) - 1.25)

            # Determine parking curb sides:
            # On oneway streets: park on right curb; if wide (>= 12m), also park on left curb facing forward.
            # On two-way streets: park on right curb facing forward; if wide (>= 11m), also on left curb facing backward.
            sides = []
            if oneway:
                sides.append((offset, yaw_fwd))
                if width >= 12.0:
                    sides.append((-offset, yaw_fwd))
            else:
                sides.append((offset, yaw_fwd))
                if width >= 11.0:
                    sides.append((-offset, yaw_rev))

            for side_offset, side_yaw in sides:
                s_curr = 10.0 # Clear distance from intersection corner
                while s_curr < seg_len - 10.0:
                    # 30% random gap for garage entrances, driveways, pedestrian ramps
                    if random.random() > 0.30:
                        px = p0[0] + tx * s_curr + nx * side_offset
                        pz = p0[1] + tz * s_curr + nz * side_offset

                        too_close = False
                        for rx in rx_pts:
                            if math.hypot(px - rx[0], pz - rx[1]) < 22.0:
                                too_close = True
                                break
                        if not too_close:
                            for bp in bridge_pts:
                                if math.hypot(px - bp[0], pz - bp[1]) < 18.0:
                                    too_close = True
                                    break
                        if not too_close:
                            if route_line.distance(Point(px, pz)) < 7.5:
                                too_close = True
                        if not too_close:
                            m_idx = random.randint(0, len(models) - 1)
                            c_idx = random.randint(0, len(colors) - 1)
                            parked.append({
                                'pos': [round(px, 2), round(pz, 2)],
                                'yaw': round(side_yaw, 4),
                                'model': models[m_idx],
                                'color': colors[c_idx]
                            })
                    s_curr += random.uniform(7.5, 9.2)

    return parked

"""Select real street-bounded blocks; requires shapely 2.x only for rebuilding."""
import sys
import math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'.tools/gis_libs'))
from shapely.geometry import Point,LineString,Polygon,box
from shapely.ops import unary_union,polygonize,triangulate,nearest_points
from recognizable_buildings import annotate
from block_density import plan_blocks,fill_blocks

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
    if 'Rivadavia' in name:
        return (8.5 if tags.get('oneway')=='yes' else (18.0 if lanes>=4 else 13.0)),'estimated lanes + kerb space'
    if name=='Avenida de Mayo':
        return (15.0 if tags.get('parking:left:orientation')=='diagonal' else (18.0 if lanes>=4 else 13.0)),'estimated lanes + parking'
    if tags.get('highway')=='service':return 5.0,'estimated service road'
    return max(9.0,lanes*3.25+4.0),'estimated lanes + parking'

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
    faces=[p for p in all_faces if 500<p.area<95000]
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
    clip=box(min(xmin-60,-1680),-700,360,1060)
    south=[];north=[]
    def route_z(x):
        near=route.interpolate(route.project(Point(x,0)))
        # The longitudinal avenue is almost east/west; vertical intersection is exact.
        intersection=route.intersection(LineString([(x,-2000),(x,2000)]))
        if intersection.geom_type=='Point':return intersection.y
        return near.y
    # Southern first row touches the avenue; second row shares a street edge with the first.
    for p in faces:
        if p.area<=900:continue
        c=p.representative_point()
        if not xmin-80<c.x<xmax+80:continue
        z=route_z(c.x)
        if c.y>z+6 and p.distance(route)<22 and c.y<z+260:south.append(p)
    second=[]
    for p in faces:
        if p.area<=900:continue
        c=p.representative_point()
        if not xmin-80<c.x<xmax+80 or c.y<route_z(c.x)+20:continue
        if any(p.equals(q) for q in south):continue
        if any(p.boundary.intersection(q.boundary).length>10 for q in south):second.append(p)
    # First block on the north side of the parallel street behind the railway.
    northern_edges=[line for w,line in street_ways if w['tags'].get('loc_name')=='Segunda Rivadavia' or w['tags'].get('name') in ['Doctor Gabriel Ardoino','Leandro N. Alem']]
    north_edge=unary_union(northern_edges)
    for p in faces:
        if p.area<=900:continue
        c=p.representative_point()
        if not xmin-80<c.x<xmax+80:continue
        if c.y<route_z(c.x)-20 and p.distance(north_edge)<1.0:north.append(p)
    poly_buf=polygon_7_streets.buffer(8.0)
    poly_faces=[p for p in faces if poly_buf.covers(p.representative_point())]
    selected=list(south+second+north)
    for p in poly_faces:
        if not any(p.equals(q) for q in selected):
            selected.append(p)
    assert south and second and north and poly_faces,('missing block rows',len(south),len(second),len(north),len(poly_faces))
    area=unary_union(selected+[polygon_7_streets.buffer(16),route.buffer(30),north_edge.intersection(clip).buffer(12)]).intersection(clip).buffer(9)
    # Extend corners to include complete buildings on the boundary of the selected blocks.
    data['coverage']={'south_block_rows':2,'north_block_rows':1,'north_reference':'parallel street north of Sarmiento railway + 7-street polygon','boundary_streets':['Avenida Díaz Vélez','Avenida Gaona','Martín Miguel de Güemes','Avenida de Mayo','General Alvarado','Viamonte','Profesor Juan T. Pizzurno'],'block_counts':{'south_first':len(south),'south_second':len(second),'north':len(north),'polygon_7_streets':len(poly_faces),'total':len(selected)},'polygons':[list(p.exterior.coords)[:-1] for p in parts(area) if p.geom_type=='Polygon'],'bounds':list(area.bounds)}
    streets=[]
    riv_corridor=box(xmin+0.5,-250,xmax-0.5,250)
    for w,line in street_ways:
        is_riv=w['tags'].get('highway')=='primary' and 'Rivadavia' in w['tags'].get('name','')
        geom=line.difference(riv_corridor) if is_riv else line
        width,source=width_for(w['tags'])
        for part in parts(geom.intersection(area)):
            if part.geom_type!='LineString' or part.length<2:continue
            t=w['tags']
            streets.append({'osm_id':w['id'],'name':clean_street_name(t.get('name','')),'points':list(part.coords),'width':width,'width_source':source,'lanes':int(t.get('lanes','2').split(';')[0]),'oneway':t.get('oneway')=='yes','bridge':t.get('bridge')=='yes','layer':int(t.get('layer','0'))})
    data['streets']=streets
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
            buildings.append({'osm_id':w['id'],'points':p[:-1],'height':height,'source_height':source_height,'height_source':('assumed_minimum_invalid_OSM' if source_height<=0 else ('OSM' if 'height' in t or 'building:levels' in t else 'assumed_2_levels')),'name':t.get('name',''),'type':t['building']})
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
    road_polygons=unary_union([LineString(r['points']).buffer(r['width']/2,cap_style=2,join_style=2) for r in data['roads']+streets])
    data['pavement']=[{'outer':list(p.exterior.coords)[:-1],'holes':[list(r.coords)[:-1] for r in p.interiors]} for p in parts(road_polygons) if p.geom_type=='Polygon']
    for key,geometry in [('pavement_triangles',road_polygons),('sidewalk_triangles',road_polygons.buffer(3.5,join_style=2).difference(road_polygons))]:
        seg=geometry.segmentize(8.0)
        data[key]=[list(t.exterior.coords)[:-1] for p in parts(seg) if p.geom_type=='Polygon' for t in triangulate(p) if p.covers(t.representative_point()) and p.buffer(0.02).covers(t)]
    density_plan=plan_blocks(data,ways,pts,selected,area,road_polygons,hospital_campus,plaza)
    occupied=[Polygon(b['points']).buffer(1.5) for b in buildings]
    occupied.append(density_plan['reserved'])
    occupied.append(hospital_campus)
    occupied += [Polygon(l['points']).buffer(1) for l in landmarks if l['type']=='green']
    occupied += [line.buffer(9) for line in rail]
    occupied += [road_polygons.buffer(3.4),plaza.buffer(1)]
    unavailable=unary_union(occupied)
    generated=[]
    for road in data['roads']+streets:
        if road.get('bridge'):continue
        line=LineString(road['points'])
        for station in range(10,int(line.length)-5,12):
            p=line.interpolate(station);a=line.interpolate(max(0,station-1));b=line.interpolate(min(line.length,station+1))
            dx,dy=b.x-a.x,b.y-a.y;length=math.hypot(dx,dy)
            if length<.01:continue
            ux,uy=dx/length,dy/length
            for side in [-1,1]:
                nx,ny=-uy*side,ux*side
                offset=road['width']/2+3.7
                base=(p.x+nx*offset,p.y+ny*offset)
                polygon=Polygon([(base[0]+ux*t+nx*d,base[1]+uy*t+ny*d) for t,d in [(-4.5,0),(4.5,0),(4.5,16),(-4.5,16)]])
                if not area.covers(polygon) or unavailable.intersects(polygon) or any(polygon.intersects(q) for q in generated):continue
                generated.append(polygon)
    data['generated_buildings']=[{'osm_id':0,'generated_id':i,'points':list(p.exterior.coords)[:-1],'height':3.2*(1+i%3),'height_source':'generic infill','name':'','type':'generic_frontage'} for i,p in enumerate(generated)]
    frontage_buildings=list(data['generated_buildings'])
    fill_blocks(data,density_plan)
    tree_forbidden=unary_union([
        road_polygons.buffer(1.25),
        density_plan['private'].buffer(0.8),
        unary_union([Polygon(b['points']).buffer(0.9) for b in buildings+frontage_buildings]),
        unary_union([line.buffer(8.5) for line in rail]),
        plaza.buffer(6.0),
    ])
    kept_trees=[p for p in data.get('trees',[]) if area.covers(Point(p)) and not tree_forbidden.covers(Point(p))]
    for road in streets:
        if road.get('bridge'):continue
        line=LineString(road['points'])
        if line.length<40:continue
        for dist_s in range(18,int(line.length)-14,32):
            p=line.interpolate(dist_s);a=line.interpolate(max(0,dist_s-1));b=line.interpolate(min(line.length,dist_s+1))
            dx,dy=b.x-a.x,b.y-a.y;length=math.hypot(dx,dy)
            if length<.01:continue
            ux,uy=dx/length,dy/length
            for side in [-1,1]:
                nx,ny=-uy*side,ux*side
                offset=road['width']/2+1.85
                cand=Point(p.x+nx*offset,p.y+ny*offset)
                if not area.covers(cand) or tree_forbidden.covers(cand):continue
                if any(math.hypot(cand.x-t[0],cand.y-t[1])<14.0 for t in kept_trees):continue
                kept_trees.append([round(cand.x,2),round(cand.y,2)])
    data['trees']=kept_trees
    street_axis=unary_union([LineString(r['points']) for r in data['roads']+streets])
    for building in buildings+frontage_buildings:
        polygon=Polygon(building['points']);vertices=list(polygon.exterior.coords)
        best=None
        for a,b in zip(vertices,vertices[1:]):
            middle=Point((a[0]+b[0])/2,(a[1]+b[1])/2)
            near=nearest_points(middle,street_axis)[1];distance=middle.distance(near)
            if math.dist(a,b)<3 or distance<1:continue
            if best is None or distance<best[0]:best=(distance,a,b,(near.x-middle.x,near.y-middle.y))
        if best:building['front']={'distance':best[0],'a':best[1],'b':best[2],'towards':best[3]}
    print('NEIGHBORHOOD',data['coverage']['block_counts'],'streets',len(streets),'buildings',len(buildings),'generic',len(data['generated_buildings']))
    return data

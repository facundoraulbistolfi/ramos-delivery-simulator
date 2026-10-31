"""Close private urban blocks with visible, solid infill; retain mapped public openings."""
import math
from shapely.geometry import Polygon,LineString,Point,box
from shapely.ops import unary_union,split

def parts(geometry):
    if geometry.is_empty:return []
    if geometry.geom_type in ['Polygon','LineString']:return [geometry]
    return [p for g in getattr(geometry,'geoms',[]) for p in parts(g)]

def simple_polygons(geometry):
    """Split holes into simple outlines supported by Godot's polygon triangulator."""
    pending=[p for p in parts(geometry) if p.geom_type=='Polygon']
    result=[]
    while pending:
        polygon=pending.pop()
        if polygon.area<0.005:continue
        if not polygon.interiors:
            result.append(polygon);continue
        hole=Polygon(polygon.interiors[0]).representative_point()
        xmin,ymin,xmax,ymax=polygon.bounds
        cut=LineString([(xmin-1,hole.y),(xmax+1,hole.y)])
        pieces=[p for p in parts(split(polygon,cut)) if p.geom_type=='Polygon']
        if len(pieces)<2:
            cut=LineString([(hole.x,ymin-1),(hole.x,ymax+1)])
            pieces=[p for p in parts(split(polygon,cut)) if p.geom_type=='Polygon']
        if len(pieces)<2:raise ValueError('Could not split a block polygon with holes')
        pending.extend(pieces)
    return result

def plan_blocks(data,ways,pts,selected,area,road_polygons,hospital_campus,plaza):
    source={w['id']:w for w in ways}
    mapped_buildings=unary_union([Polygon(b['points']) for b in data['buildings']])
    passages=[]
    for w in ways:
        tags=w['tags'];kind=tags.get('highway')
        if kind not in ['footway','path','pedestrian','service','steps']:continue
        if tags.get('access') in ['no','private'] or tags.get('foot')=='no':continue
        if tags.get('bridge')=='yes' or tags.get('tunnel')=='yes' or tags.get('layer','0')!='0':continue
        if kind=='service' and tags.get('service') in ['parking_aisle','driveway']:continue
        points=[pts[i] for i in w['nodes'] if i in pts]
        if len(points)<2:continue
        width=4.0 if kind in ['pedestrian','service'] else 3.0
        line=LineString(points).intersection(area).difference(mapped_buildings.buffer(.05))
        for segment in parts(line):
            if segment.geom_type!='LineString' or segment.length<1:continue
            # Indoor galleries and tunnels are not invented as outdoor alleys.
            opening=segment.buffer(width/2,cap_style=2,join_style=2).difference(mapped_buildings)
            if opening.is_empty:continue
            passages.append({'osm_id':w['id'],'name':tags.get('name',''),'kind':kind,'width':width,'points':list(segment.coords),'area':opening})
    greens=[];private_gardens=[]
    for landmark in data['landmarks']:
        if landmark['type']!='green':continue
        polygon=Polygon(landmark['points']).buffer(0)
        greens.append(polygon)
        tags=source.get(int(landmark.get('osm_id',0)),{}).get('tags',{})
        if tags.get('access') in ['no','private']:private_gardens.append(polygon)
    railway=unary_union([LineString(r['points']).buffer(16) for r in data['railways']])
    platforms=[Polygon(p['points']).buffer(4) for p in data['landmarks'] if p['type']=='platform']
    # Shopfront sidewalks and hospital access must not become thin new buildings.
    forecourts=[]
    for site in data['recognizable_buildings']:
        fronts=site.get('fronts',[site['front']])
        if 'side' in site:fronts=fronts+[site['side']]
        for front in fronts:
            a,c=front['a'],front['b'];nx,nz=front['normal']
            forecourts.append(Polygon([a,c,(c[0]+nx*12.5,c[1]+nz*12.5),(a[0]+nx*12.5,a[1]+nz*12.5)]))
    public_open=unary_union(greens+[p['area'] for p in passages]+[railway,plaza.buffer(.5)]+platforms+forecourts)
    reserved=unary_union([public_open,hospital_campus])
    # Street-edge faces are clipped back to the real road widths and sidewalks.
    interiors=unary_union(selected).intersection(area).difference(road_polygons.buffer(3.5,join_style=2))
    private=interiors.difference(reserved).buffer(0)
    # Hospital gardens stay visible and accessible through the main gate; perimeter walls stop shortcuts.
    property_walls=[]
    hospital=next(s for s in data['recognizable_buildings'] if s['key']=='san_juan')
    a,c=hospital['front']['a'],hospital['front']['b']
    middle=((a[0]+c[0])/2,(a[1]+c[1])/2);normal=hospital['front']['normal']
    gate=LineString([(middle[0]-normal[0]*3,middle[1]-normal[1]*3),(middle[0]+normal[0]*22,middle[1]+normal[1]*22)]).buffer(6,cap_style=2)
    mapped_gates=unary_union([p['area'].buffer(.2) for p in passages]+[gate])
    for index,polygon in enumerate([hospital_campus]+private_gardens):
        boundary=polygon.boundary.difference(mapped_gates) if index==0 else polygon.boundary
        for line in parts(boundary):
            if line.geom_type=='LineString' and line.length>.1:
                property_walls.append({'points':list(line.coords),'height':1.8,'kind':'hospital_perimeter' if index==0 else 'private_garden'})
    data['open_passages']=[{k:v for k,v in p.items() if k!='area'} for p in passages]
    data['property_walls']=property_walls
    data['block_density']={'method':'continuous visible infill in private block interiors','private_regions':[list(p.exterior.coords)[:-1] for p in simple_polygons(private)],'private_area_m2':private.area,'public_open_regions':[list(p.exterior.coords)[:-1] for p in simple_polygons(public_open.intersection(area))],'preserved_passages':len(passages)}
    return {'reserved':reserved,'private':private}

def fill_blocks(data,plan):
    current=[Polygon(b['points']) for b in data['buildings']+data['generated_buildings']]
    occupied=unary_union(current)
    # A few centimetres of separation avoid coplanar faces, while remaining far below bike clearance.
    remaining=plan['private'].difference(occupied.buffer(.025,join_style=2))
    xmin,zmin,xmax,zmax=remaining.bounds
    start_id=len(data['generated_buildings'])
    additions=[]
    for ix in range(math.floor(xmin/18),math.ceil(xmax/18)):
        for iz in range(math.floor(zmin/22),math.ceil(zmax/22)):
            cell=box(ix*18,iz*22,(ix+1)*18,(iz+1)*22)
            if not remaining.intersects(cell):continue
            for polygon in simple_polygons(remaining.intersection(cell)):
                # Edge slivers become low solid party walls rather than implausible narrow houses.
                height=1.8 if polygon.area<3 else 3.2*(1+(ix*7+iz*11)%3)
                additions.append({'osm_id':0,'generated_id':start_id+len(additions),'points':list(polygon.exterior.coords)[:-1],'height':height,'height_source':'generic block infill','name':'','type':'generic_block_infill'})
    data['generated_buildings'].extend(additions)
    solid=unary_union(current+[Polygon(b['points']) for b in additions])
    # Configuration space for a bike slightly narrower than the actual 0.84 m capsule.
    clearance=plan['private'].difference(solid.buffer(.15,join_style=2))
    data['block_density'].update(added_volumes=len(additions),unfilled_bike_clearance_m2=clearance.area,solid_coverage_m2=plan['private'].intersection(solid).area)
    assert clearance.area<.02,('private block openings remain',clearance.area)
    assert all(Polygon(b['points']).intersection(plan['reserved']).area<1e-6 for b in additions)
    print('BLOCK_DENSITY',len(additions),'new volumes;',len(data['open_passages']),'mapped openings preserved; uncovered clearance',round(clearance.area,6),'m2')

"""Extract a reproducible, metre-scale OSM map. See tools/requirements-map.txt.

Input: .tools/maps/area.osm, downloaded from the URL in the output metadata.
Output is an ODbL derivative database; see assets/maps/SOURCES.md.
"""
import heapq
import gzip
import json
import math
from pathlib import Path
import xml.etree.ElementTree as ET
from expand_neighborhood import expand, width_for

ROOT = Path(__file__).resolve().parents[1]
SOURCE_URL = 'https://api.openstreetmap.org/api/0.6/map?bbox=-58.596,-34.655,-58.537,-34.632'
LAT, LON = -34.6399621, -58.549505
R = 6371008.8


def project(lat, lon):
    return [(lon-LON)*math.pi/180*R*math.cos(LAT*math.pi/180),
            -(lat-LAT)*math.pi/180*R]


def main():
    downloaded = ROOT/'.tools/maps/area.osm'
    source = downloaded if downloaded.exists() else gzip.open(ROOT/'assets/maps/source.osm.gz','rb')
    tree = ET.parse(source).getroot()
    nodes = {int(e.attrib['id']): e for e in tree.findall('node')}
    geo = {i: [float(e.attrib['lat']), float(e.attrib['lon'])] for i, e in nodes.items()}
    pts = {i: project(*p) for i, p in geo.items()}
    ways = []
    for e in tree.findall('way'):
        ways.append({'id': int(e.attrib['id']), 'tags': {t.attrib['k']: t.attrib['v'] for t in e.findall('tag')},
                     'nodes': [int(n.attrib['ref']) for n in e.findall('nd')]})
    ramos_rel = next((r for r in tree.findall('relation') if r.attrib.get('id') == '1748197'), None)
    ramos_boundary_ways = [int(m.attrib['ref']) for m in ramos_rel.findall('member') if m.attrib.get('type') == 'way'] if ramos_rel is not None else []
    riv = [w for w in ways if w['tags'].get('highway') == 'primary' and 'Rivadavia' in w['tags'].get('name','')]
    rnodes = {i for w in riv for i in w['nodes']}
    endpoints = {}
    for name in ['Larrea', 'Necochea']:
        common = {i for w in ways if w['tags'].get('name') == name for i in w['nodes'] if i in rnodes}
        assert common, name
        # Larrea's north carriageway is the start, travelling west towards Necochea.
        endpoints[name] = max(common, key=lambda i: geo[i][0]) if name == 'Larrea' else min(common)
    start, end = [endpoints[n] for n in ['Larrea', 'Necochea']]
    graph = {}
    for w in riv:
        for a,b in zip(w['nodes'], w['nodes'][1:]):
            d=math.dist(pts[a],pts[b])
            graph.setdefault(a,[]).append((b,d))
            graph.setdefault(b,[]).append((a,d))
    dist, prev, queue = {start:0}, {}, [(0,start)]
    while queue:
        d,a=heapq.heappop(queue)
        if d != dist[a]: continue
        if a == end: break
        for b,cost in graph[a]:
            if d+cost < dist.get(b, math.inf):
                dist[b],prev[b]=d+cost,a
                heapq.heappush(queue,(d+cost,b))
    route=[end]
    while route[-1]!=start: route.append(prev[route[-1]])
    route.reverse()
    line=[pts[i] for i in route]
    xmin,xmax=pts[end][0],pts[start][0]

    def nearest(p):
        best=(math.inf,0)
        cumulative=0
        for a,b in zip(line,line[1:]):
            v=[b[0]-a[0],b[1]-a[1]]; length=math.hypot(*v)
            t=max(0,min(1,sum((p[j]-a[j])*v[j] for j in range(2))/length**2))
            delta=math.dist(p,[a[j]+t*v[j] for j in range(2)])
            if delta<best[0]: best=delta,cumulative+t*length
            cumulative+=length
        return best

    roads=[]
    for w in riv:
        p=[pts[i] for i in w['nodes']]
        if max(v[0] for v in p)<xmin-1 or min(v[0] for v in p)>xmax+1: continue
        lanes=int(w['tags'].get('lanes','2'))
        width,width_source=width_for(w['tags'])
        if w['tags'].get('oneway')=='yes' and sum(v[0] for v in p)/len(p)<-1150:
            width=12.0
            width_source='estimated station approach with kerb/parking space'
        clipped=[]
        for a,b in zip(p,p[1:]):
            if abs(b[0]-a[0])<.001: continue
            ts=sorted([max(0,min(1,(edge-a[0])/(b[0]-a[0]))) for edge in [xmin,xmax]])
            lo,hi=ts
            if hi-lo<.00001: continue
            q=[[a[j]+t*(b[j]-a[j]) for j in range(2)] for t in [lo,hi]]
            if not clipped or math.dist(clipped[-1],q[0])>.001: clipped.append(q[0])
            clipped.append(q[1])
        if len(clipped)>1:
            roads.append({'osm_id':w['id'],'points':clipped,'width':width,'lanes':lanes,'oneway':w['tags'].get('oneway')=='yes','surface':w['tags'].get('surface','unknown'),'width_source':width_source})

    # Sample cross-sections of the union of both carriageways, keeping genuine median gaps.
    sections=[]
    count=math.ceil((xmax-xmin)/3)
    for k in range(count+1):
        x=xmax+(xmin-xmax)*k/count
        intervals=[]
        for road in roads:
            for a,b in zip(road['points'],road['points'][1:]):
                if min(a[0],b[0])-.001<=x<=max(a[0],b[0])+.001 and abs(b[0]-a[0])>.001:
                    t=(x-a[0])/(b[0]-a[0]); z=a[1]+(b[1]-a[1])*t
                    factor=math.dist(a,b)/abs(b[0]-a[0])
                    half=road['width']/2*factor
                    intervals.append([z-half,z+half])
        merged=[]
        for a,b in sorted(intervals):
            if merged and a<=merged[-1][1]+.35: merged[-1][1]=max(b,merged[-1][1])
            else: merged.append([a,b])
        assert merged, ('uncovered road',x)
        sections.append({'x':x,'intervals':merged})

    crosses=[]; seen=set()
    for w in ways:
        tags=w['tags']; name=tags.get('name','')
        if tags.get('highway') not in ['residential','primary','secondary','tertiary','unclassified','living_street','secondary_link','tertiary_link'] or not name or 'Rivadavia' in name: continue
        common=set(w['nodes']) & rnodes
        for i in common:
            d,s=nearest(pts[i])
            if not xmin-1<=pts[i][0]<=xmax+1 or (name,round(s/25)) in seen: continue
            others=[pts[n] for n in w['nodes'] if math.dist(pts[n],pts[i])>15]
            if not others: continue
            seen.add((name,round(s/25)))
            q=min(others,key=lambda p:math.dist(p,pts[i])); v=[q[j]-pts[i][j] for j in range(2)]; length=math.hypot(*v)
            crosses.append({'name':name,'osm_id':w['id'],'point':pts[i],'direction':[a/length for a in v],'station_m':s,'width':9 if tags.get('highway')=='residential' else 14})
    crosses.sort(key=lambda c:c['station_m'])
    buildings=[]; railways=[]; landmarks=[]; vegetation=[]
    for w in ways:
        t=w['tags']; p=[pts[i] for i in w['nodes'] if i in pts]
        if not p: continue
        mid=[sum(a[j] for a in p)/len(p) for j in range(2)]
        if not xmin-100<mid[0]<xmax+100 or nearest(mid)[0]>110: continue
        if 'building' in t and len(p)>=4 and w['nodes'][0]==w['nodes'][-1]:
            try: height=float(t.get('height',str(float(t.get('building:levels','2'))*3.1)))
            except ValueError: height=6.2
            buildings.append({'osm_id':w['id'],'points':p[:-1],'height':height,'height_source':'OSM' if 'height' in t or 'building:levels' in t else 'assumed_2_levels','name':t.get('name',''),'type':t['building']})
        if t.get('railway')=='rail': railways.append({'osm_id':w['id'],'points':p})
        if t.get('railway')=='platform': landmarks.append({'name':t.get('name','Anden Sarmiento'),'points':p,'type':'platform'})
        if t.get('landuse') in ['grass','village_green'] or t.get('leisure') in ['park','garden']:
            landmarks.append({'name':t.get('name',''),'points':p,'type':'green'})
    for i,e in nodes.items():
        p=pts[i]
        t={a.attrib['k']:a.attrib['v'] for a in e.findall('tag')}
        if t.get('natural')=='tree': vegetation.append(p)
        if not xmin<p[0]<xmax or nearest(p)[0]>85: continue
        if t.get('railway')=='station': landmarks.append({'name':t.get('name','Estacion'),'point':p,'type':'station'})
    data={'name':'Ramos Mejia - Avenida Rivadavia','attribution':'© OpenStreetMap contributors · ODbL 1.0','source_url':SOURCE_URL,'retrieved':'2026-10-30',
          'projection':{'type':'local_equirectangular','origin_lat':LAT,'origin_lon':LON,'earth_radius_m':R,'axes':'X east, Y up, Z south','units':'metres'},
          'endpoints':{n:{'osm_node_id':i,'lat_lon':geo[i],'point':pts[i]} for n,i in endpoints.items()},
          'route':{'points':line,'osm_node_ids':route,'length_m':dist[end]},'roads':roads,'sections':sections,'crossings':crosses,'buildings':buildings,'railways':railways,'landmarks':landmarks,'trees':vegetation,'ramos_boundary_ways':ramos_boundary_ways}
    data=expand(data,ways,pts)
    out=ROOT/'assets/maps/ramos_mejia.json'
    out.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({'length_m':dist[end],'avenue_ways':len(roads),'side_streets':len(data['streets']),'mapped_buildings':len(data['buildings']),'generated_buildings':len(data['generated_buildings']),'railways':len(data['railways'])},ensure_ascii=True,indent=2))


if __name__=='__main__': main()

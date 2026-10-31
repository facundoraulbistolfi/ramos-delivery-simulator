"""Geometric regressions: no bike-sized holes in private blocks; public openings stay open."""
import json
import sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'.tools/gis_libs'))
from shapely.geometry import Polygon,LineString
from shapely.ops import unary_union

data=json.loads((ROOT/'assets/maps/ramos_mejia.json').read_text(encoding='utf8'))
density=data['block_density']
private=unary_union([Polygon(p) for p in density['private_regions']])
public=unary_union([Polygon(p) for p in density['public_open_regions']])
buildings=[Polygon(b['points']) for b in data['buildings']+data['generated_buildings']]
solid=unary_union(buildings)
uncovered=private.difference(solid.buffer(.15,join_style=2))
assert uncovered.area<.02,('bike-sized gaps in private blocks',uncovered.area)
new=[Polygon(b['points']) for b in data['generated_buildings'] if b['type']=='generic_block_infill']
new_solid=unary_union(new)
generic_solid=unary_union([Polygon(b['points']) for b in data['generated_buildings']])
assert len(new)>100,'dense infill missing'
assert new_solid.intersection(public).area<.001,'infill obstructs a plaza or mapped passage'
original=unary_union([Polygon(b['points']) for b in data['buildings']])
for passage in data['open_passages']:
    line=LineString(passage['points'])
    assert generic_solid.intersection(line.buffer(.15,cap_style=2)).area<.001,('alley obstructed',passage['osm_id'])
for name in ['Plaza Domingo Faustino Sarmiento','Plaza Bartolomé Mitre','Paseo Recreativo María Elena Walsh']:
    park=next(p for p in data['landmarks'] if p['name']==name)
    polygon=Polygon(park['points'])
    assert new_solid.intersection(polygon).area<.001,('park filled',name)
assert not private.is_empty and data['property_walls'],'private property boundaries missing'
print('DENSITY_QA_OK: private blocks sealed,',len(new),'new solid volumes,',len(data['open_passages']),'open passages, plazas preserved')

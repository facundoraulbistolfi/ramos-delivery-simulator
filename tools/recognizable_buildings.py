"""Bind architectural variants to existing OSM footprints, before generic infill."""
from shapely.geometry import Polygon,Point

def annotate(data,ways,pts):
    source={w['id']:w for w in ways}
    campus=Polygon([pts[n] for n in source[222084507]['nodes']])
    by_id={int(b['osm_id']):b for b in data['buildings']}
    hospital_ids=[]
    for w in ways:
        if not w['tags'].get('building') or len(w['nodes'])<4 or w['nodes'][0]!=w['nodes'][-1]:continue
        p=[pts[n] for n in w['nodes']]
        if not campus.covers(Polygon(p).representative_point()):continue
        hospital_ids.append(w['id'])
        if w['id'] not in by_id:
            building={'osm_id':w['id'],'points':p[:-1],'height':6.2,'source_height':6.2,'height_source':'assumed_2_levels','name':w['tags'].get('name',''),'type':w['tags']['building']}
            data['buildings'].append(building);by_id[w['id']]=building
        by_id[w['id']]['recognizable']='san_juan'
    main=by_id[636863311]
    main.update(height=12.4,height_source='visual_estimate_four_levels_plus_rooftop_core',name='Hospital San Juan de Dios')
    coto=by_id[27233077]
    coto['recognizable']='coto'
    perla=by_id[475920381]
    perla.update(recognizable='la_perla',name='La Perla',source_name='')

    def front(a,b,polygon):
        middle=Point((a[0]+b[0])/2,(a[1]+b[1])/2)
        dx,dy=b[0]-a[0],b[1]-a[1]
        length=(dx*dx+dy*dy)**.5
        normal=[-dy/length,dx/length]
        if polygon.contains(Point(middle.x+normal[0]*.2,middle.y+normal[1]*.2)):
            normal=[-v for v in normal]
        return {'a':a,'b':b,'normal':normal,'width':length,'visit':[middle.x+normal[0]*12,middle.y+normal[1]*12]}

    hp=main['points']
    hospital_front=front(hp[12],hp[13],Polygon(hp))
    coto_front=front(coto['points'][0],coto['points'][1],Polygon(coto['points']))
    coto_side=front(coto['points'][1],coto['points'][2],Polygon(coto['points']))
    perla_fronts=[front(perla['points'][i],perla['points'][i+1],Polygon(perla['points'])) for i in [0,1,2]]
    data['recognizable_buildings']=[
        {'key':'san_juan','name':'Casa Hospital San Juan de Dios','address':'Dr. Gabriel Ardoino 714','osm_site_id':222084507,'building_ids':hospital_ids,'main_building_id':636863311,'campus_points':list(campus.exterior.coords)[:-1],'front':hospital_front,'visit':hospital_front['visit'],'sources':['https://hospitalsanjuandedios.org.ar/nuestras-sedes/','https://hospitalsanjuandedios.org.ar/wp-content/uploads/2024/08/fachada-atardecer-1024x683.jpg'],'accuracy':'OSM footprints; simplified photographic facade and estimated heights'},
        {'key':'coto','name':'Coto Ramos Mejía','address':'Av. Rivadavia 13810 / Pueyrredón','building_ids':[27233077],'main_building_id':27233077,'front':coto_front,'side':coto_side,'visit':coto_front['visit'],'sources':['https://www.coto.com.ar/mapassucursales/sucursales/ListadoSucursales.aspx','https://elcactus.com.ar/2020/04/clausuraron-el-coto-de-ramos-mejia-por-graves-fallas-de-higiene-y-bromatologia/'],'accuracy':'OSM footprint and branch identity; simplified brand facade'},
        {'key':'la_perla','name':'La Perla','address':'Av. Rivadavia 14102 / Av. de Mayo','osm_poi_id':3527161632,'building_ids':[475920381],'main_building_id':475920381,'front':perla_fronts[0],'fronts':perla_fronts,'visit':perla_fronts[0]['visit'],'sources':['https://es.restaurantguru.com/La-Perla-Ramos-Mejia','https://www.vivieloeste.com.ar/noticias/2023/03/06/57223-haedo-la-perla-vuelve-a-abrir-sus-puertas'],'accuracy':'OSM host building and restaurant POI; simplified glazing and green awnings'}
    ]
    return campus

# Datos del mapa: Avenida Rivadavia, Ramos Mejía

© OpenStreetMap contributors. Base de datos original y base derivada bajo [Open Database License 1.0](https://opendatacommons.org/licenses/odbl/1-0/). [Atribución y derechos](https://www.openstreetmap.org/copyright).

Descarga: 30 de octubre de 2026. [Extracto de la API oficial](https://api.openstreetmap.org/api/0.6/map?bbox=-58.596,-34.655,-58.537,-34.632). Se conserva una copia comprimida de la respuesta en `source.osm.gz`. No se usaron imágenes o datos de Google Maps.

## Extremos y proyección

| Extremo | Nodo OSM | Latitud | Longitud |
| --- | --- | --- | --- |
| Rivadavia / Larrea, calzada norte | 3833679611 | -34.6399621 | -58.5495050 |
| Rivadavia / Necochea | 305083398 | -34.6410881 | -58.5673434 |

Ruta continua por vías OSM `highway=primary` con nombre Rivadavia, entre esos nodos. Longitud de referencia: **1647,63 m**, calculada sobre la polilínea, sin reducir ni estirar la escala. En el juego hay dos manos donde OSM cartografía dos calzadas y una calzada compartida donde así está mapeada.

Proyección equirectangular local sobre esfera de radio 6.371.008,8 m, origen en Larrea. X positivo al este, Z positivo al sur; Y vertical. La orientación geográfica y las coordenadas fuente se conservan en `ramos_mejia.json`. La precisión geométrica está limitada por la cartografía original, no por la cantidad de decimales mostrados.

## Qué es geográfico y qué es aproximado

- **Geográfico:** ejes de ambas calzadas, cambios de dirección, cruces, red de 199 tramos de calles, vías, andenes, espacios verdes y huellas de 320 edificios. Cada elemento conserva su ID OSM cuando corresponde.
- **Extensión:** se poligoniza la red vial completa dentro del polígono delimitado por **Av. Díaz Vélez (y su continuación Av. República hasta Gaona), Av. Gaona, Martín Miguel de Güemes, Av. de Mayo, General Alvarado, Viamonte y Profesor Juan T. Pizzurno**, además de las filas del corredor de Av. Rivadavia hasta Necochea. Se incluyen **100 caras de manzana/corredor en total** (94 dentro del polígono de las 7 calles más los bordes hasta Necochea: 14 de primera fila sur, 13 de segunda fila sur y 18 del frente norte sobre Ardoino/Alem). La geometría y los límites se guardan en `coverage`.
- **Ancho de calzada:** se usa `width` de OSM si existe. Si falta: Rivadavia separada 8,5 m por mano; frente a estación 12 m; dos sentidos 13 m para dos carriles y 18 m para cuatro. Av. de Mayo 13 m, 15 m con estacionamiento diagonal y 18 m con cuatro carriles. Calles locales: al menos 9 m, o carriles × 3,25 m + 4 m de espacio lateral. `width_source` identifica la estimación. Estas medidas corrigen el subdimensionado anterior por contar solo carriles de circulación; **no son mediciones catastrales ni en campo**.
- **Alturas:** `height` o `building:levels × 3,1 m` si están disponibles; en ausencia de ambos, dos niveles de 3,1 m. `height_source` diferencia los casos.
- **Altura inválida:** una huella comercial tenía altura calculada cero por sus etiquetas de OSM. Se usa un mínimo de 3,1 m para conservar su volumen y colisión, manteniendo el valor original en `source_height` y registrando la sustitución en `height_source`.
- **Relleno:** se agregan huellas genéricas de fachada y volúmenes continuos en los interiores privados de las manzanas, evitando huellas originales, plazas, vías, veredas, pasos exteriores cartografiados, accesos a los tres edificios reconocibles y el predio hospitalario. `generated_buildings` está separado de `buildings`; las nuevas construcciones no se presentan como edificios reales relevados.
- **Aproximado:** fachadas, materiales, pasos peatonales, árboles, refugios y luces. No representan un relevamiento de cada frente o señal.
- **Terreno:** plano, sin levantamiento altimétrico. Las vías y las calles fuera del tramo son contexto visual.
- **Circulación:** libre por el entorno, sin cierres invisibles sobre la avenida. Todas las envolventes de edificios y el basamento del cartel tienen colisión; el suelo físico es un plano infinito. Puentes y cruces ferroviarios están simplificados sin elevación, semáforos ni tráfico.

## La Tanga

Se identifica con el triángulo en **Rivadavia y Avenida de Mayo**, según la [referencia local de De Ramos Digital](https://deramosdigital.com.ar/2021/11/01/robaron-la-palabra-localidad-del-nuevo-cartel-de-bienvenida-a-ramos-mejia/) y la [fotografía del cartel en RamosMejia.com](https://www.ramosmejia.com/ramos-mejia-instalaron-un-cartel-de-bienvenida-a-la-localidad/). Las referencias son de 2021 y no certifican el estado actual de cada elemento.

El cantero procede del polígono OSM **595185877**, de unos 35 m². La plazoleta se deriva de la cara de calles que lo contiene: unos 741 m² entre ejes, reducida por el espacio de las calzadas para el solado aproximado. El basamento, las letras 3D, los bancos y luminarias son una interpretación de esas referencias; no una restitución fotogramétrica. No se restituye el antiguo arco caído en 2015.

El juego funciona sin red. `tools/prepare_ramos_map.py` reproduce la base derivada desde la copia original; `tools/build_ramos_map.gd` genera los volúmenes y la escena. La atribución está disponible en pantalla mediante un enlace a OpenStreetMap.

## Tres edificios reconocibles

Se utilizan mallas originales, letras 3D y materiales lisos. Las fotografías se consultaron como referencia visual y **no se distribuyen como texturas**. No hay interiores visitables. Las alturas y detalles de fachada son interpretaciones simplificadas, no un levantamiento arquitectónico. `recognizable_buildings` conserva identificadores, frentes, puntos de visita y referencias; las anotaciones sobreviven a la regeneración del mapa.

| Modelo | Georreferencia | Rasgos modelados | Referencias |
| --- | --- | --- | --- |
| Casa Hospital San Juan de Dios | Predio OSM 222084507; edificio principal 636863311, Ardoino 714 | Huellas del conjunto hospitalario, alas blancas, bandas vidriadas, núcleo elevado, marquesina de guardia, cruz, palmeras, jardines y estacionamiento | [Sede oficial](https://hospitalsanjuandedios.org.ar/nuestras-sedes/), [fotografía de la fachada oficial](https://hospitalsanjuandedios.org.ar/wp-content/uploads/2024/08/fachada-atardecer-1024x683.jpg) |
| Coto Ramos Mejía | Edificio OSM 27233077, Rivadavia 13810 / Pueyrredón | Rótulos rojos, franja azul/amarilla, vidrieras, entrada y fachada lateral; huella original de unos 49 × 37 m | [Listado oficial de sucursales, sucursal 51](https://www.coto.com.ar/mapassucursales/sucursales/ListadoSucursales.aspx), [referencia local de la entrada en 2020](https://elcactus.com.ar/2020/04/clausuraron-el-coto-de-ramos-mejia-por-graves-fallas-de-higiene-y-bromatologia/) |
| La Perla | POI OSM 3527161632 dentro del edificio 475920381, Rivadavia 14102 / Av. de Mayo | Ochava y huella existentes, vidrieras, toldos verdes, letras claras, mesas y sillas exteriores | [Referencia de dirección y galería de fotos](https://es.restaurantguru.com/La-Perla-Ramos-Mejia), [referencia local de la sucursal](https://www.vivieloeste.com.ar/noticias/2023/03/06/57223-haedo-la-perla-vuelve-a-abrir-sus-puertas) |

El núcleo principal del hospital se modela con alas de cuatro niveles y un cuerpo retirado de quinto nivel, inspirado en las fotos oficiales y en la [descripción institucional de cinco plantas](https://www.chcsa.org/Presencia/Centro/236/hospital-san-juan-de-dios-ramos-mejia). Sus alturas se marcan como estimación visual y no como datos de OSM. Coto y La Perla conservan la altura inicial aproximada del volumen del mapa. Los 11 rellenos genéricos que antes ocupaban espacios libres del predio del hospital se retiraron.

## Densificación y pasos entre manzanas

`tools/block_density.py` completa las superficies privadas que quedaban vacías dentro de las caras de manzana, descontando calzadas y 3,5 m de vereda. El relleno se divide en parcelas de hasta 18 × 22 m, con alturas variadas; los recortes estrechos se representan como medianeras bajas. Cada volumen visible usa la misma colisión de malla que los demás edificios. No se colocan barreras invisibles en las calles.

Se reservan los senderos, calles peatonales y pasos de servicio exteriores de OSM que no están marcados como privados o prohibidos. No se convierten las galerías interiores, túneles ni pasarelas elevadas en callejones a nivel del suelo. Los tramos reservados se conservan en `open_passages` y se dibujan con pavimento claro. Las plazas Sarmiento, Mitre, las plazoletas y el paseo María Elena Walsh permanecen libres de relleno.

Los jardines privados y el perímetro del hospital tienen medianeras visibles de 1,8 m; se abren los accesos del hospital y los pasos cartografiados que cruzan su límite. Estos cerramientos son una interpretación de juego para delimitar los predios, no un relevamiento de cada muro real.

`block_density` registra el área privada, los volúmenes añadidos y la cobertura. La comprobación geométrica busca huecos a una holgura de 15 cm, inferior al radio de 42 cm de la moto. Se toleran separaciones de 2,5 cm entre volúmenes para evitar caras superpuestas; no permiten el paso de la moto. Las pruebas en Godot verifican colisiones de cubiertas, fachadas, centros de manzana y pasos conservados.

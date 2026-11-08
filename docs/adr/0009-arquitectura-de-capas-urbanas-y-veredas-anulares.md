# ADR-0009: Arquitectura de Capas Urbanas, Veredas Anulares y Contención de Manzanas

- **Estado:** Aceptado
- **Fecha:** 2026-11-01
- **Autores / Decisores:** Usuario / Agente Antigravity

---

## 1. Contexto y Problemática
En versiones anteriores del pipeline GIS, los datos de OpenStreetMap (líneas centrales de calle y polígonos de edificios digitalizados con desfases de perspectiva satelital) se procesaban de forma independiente sin una jerarquía de contención topológica:
1. Las calles se ensanchaban de manera uniforme generando calzadas excesivas que invadían las manzanas.
2. Las veredas se generaban dibujando tiras rectangulares (`_strip`) a lo largo de cada tramo de calle y rellenando esquinas con triangulación Delaunay no restringida, provocando que las veredas se montaran sobre el asfalto en esquinas, diagonales y bocacalles.
3. Los edificios mapeados de OSM se renderizaban con sus huellas crudas, sobresaliendo de las manzanas y pisando las veredas y la calzada.
4. No existía una separación estricta en capas disjuntas (`Layer_Vias`, `Layer_Calles`, `Layer_Veredas`, `Layer_Lotes`, `Layer_Edificios`, `Layer_Mobiliario`), lo que dificultaba aislar problemas visuales y de colisión.

---

## 2. Decisión Tomada
Se implementó una **Partición Booleana Estricta por Capas Topológicamente Disjuntas**:

1. **Jerarquía Geométrica Descendente:**
   - **Capa 0 y 1 (Vías y Calles):** Las calzadas toman anchos normalizados según su jerarquía real en OSM (Avenidas: 13-18 m; secundarias: 10-12 m; residenciales: 8.5 m; pasajes/servicio: 5 m). Su unión booleana (`road_polygons`) y el corredor ferroviario definen el **Vacío Vial y Ferroviario** a cota `Y = 0.016 m`.
   - **Capa 2 (Cuadras / Manzanas):** Cada manzana nace como el complemento booleano exacto fuera de las calzadas y el ferrocarril (`face - road_polygons - rail_corridor`). Su borde exterior es el **Borde de Cordón**.
   - **Capa 3 (Veredas y Cordones):** En cada manzana, el perímetro de cordón se desfasa hacia el interior según el ancho de vereda (3.2 m estándar, 3.5 m en avenidas), generando la **Línea Municipal** con ochavas automáticas de esquina. La vereda es exclusivamente el **anillo cerrado `curb_polygon - municipal_polygon`**. Se eliminaron las tiras rectas por tramo y la triangulación Delaunay; las veredas se triangulan mediante *Ear-Clipping* poligonal estricto. El cordón vertical (`Y = 0.016` a `0.17`) se genera exactamente a lo largo de las líneas de contacto entre manzana y calzada (`curb_lines`).
   - **Capa 4 y 5 (Lotes y Edificios):** El interior de la Línea Municipal constituye el espacio privado edificable (`density_plan['private']`). Todos los edificios genéricos de OSM se recortan estrictamente dentro de la Línea Municipal, impidiendo que sobresalgan a la vereda. Los edificios reconocibles (San Juan de Dios, Coto, La Perla) conservan su ubicación característica protegidos por el retiro de frente. Los lotes catastrales y casas procedimentales se generan dentro de esta delimitación.
   - **Capa 6 (Mobiliario):** Árboles, carteles nomencladores y semáforos se anclan en la franja de vereda, y los autos estacionados en la calzada contra el cordón.

2. **Organización en la Escena de Godot:**
   - Se crearon contenedores explícitos `Layer_Vias`, `Layer_Calles`, `Layer_Veredas`, `Layer_Lotes`, `Layer_Edificios` y `Layer_Mobiliario` en `scenes/ramos_mejia.tscn`.
   - Se mantuvo la raíz de particionamiento espacial `SectorChunks` para culling de GPU y rendimiento a 60 FPS estables.

---

## 3. Archivos y Subsistemas Afectados
- `tools/expand_neighborhood.py`: Anchos jerárquicos de calle, extracción de `blocks`, `sidewalk_polygons`, `curb_lines`, ear-clipping `triangulate_polygon_2d`, y recorte de edificios OSM a la Línea Municipal.
- `tools/prepare_ramos_map.py`: Inclusión de `blocks`, `sidewalk_polygons` y `curb_lines` en las claves maestras del mapa base (`ramos_mejia_base.json` y `ramos_mejia.json`).
- `tools/neighborhood_geometry.gd`: Reemplazo del trazado por tiras superpuestas por renderizado directo de `sidewalk_polygons` y extrusión de `curb_lines`.
- `tools/build_ramos_map.gd`: Creación de la jerarquía de nodos `Layer_*` en la escena horneada.

---

## 4. Consecuencias y Trade-offs

### Positivas
- **0 superposiciones de vereda en calle:** Geométricamente imposible por construcción booleana (`sidewalk ∩ road = ∅`).
- **0 invasiones de edificios a la vereda:** Todos los polígonos genéricos de OSM quedan confinados dentro de la Línea Municipal.
- **Esquinas y ochavas limpias:** Cordones curvados y ochavas de ~4 m continuas sin costuras rotas.
- **Mantenimiento del rendimiento:** Triangulación limpia sin caras coplanares ni triángulos parásitos; framerate alto sostenido en renderer `Compatibility`.

### Negativas / Limitaciones Aceptadas
- La regeneración completa del mapa requiere ejecutar `prepare_ramos_map.py` (~25 s) y `build_ramos_map.gd` (~15 s), respetando el flujo de dos fases del proyecto.

---

## 5. Validación y Pruebas Automatizadas
- `tools/test_density.py`:
  - `DENSITY_QA_OK: private blocks sealed, 2492 new solid volumes, 240 open passages, plazas preserved` (0 huecos en manzanas, aserción `< 0.02 m²` cumplida).
- `tools/test_map.gd` (Godot Headless):
  - `metric route length 1647.63 m` (PASS)
  - `full avenue drivable; reached 1633.6 m` (PASS)
  - `private blocks have no bike-sized empty gaps` (PASS)
  - `block interior bike-clearance probes: 708 tested, 0 gaps` (PASS)
  - `all 1010 mapped and generic buildings have roof collision; misses=0` (PASS)
  - `MAP_QA failures=0` (PASS total en físicas, HUD, misiones y mapa).

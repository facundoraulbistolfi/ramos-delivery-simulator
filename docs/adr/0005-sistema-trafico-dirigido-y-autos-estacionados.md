# ADR-0005: Sistema de Tráfico Vehicular Dirigido y Autos Estacionados a los Cordones

- **Estado:** Aceptado
- **Fecha:** 2026-11-01
- **Autores / Decisores:** Usuario / Agente Antigravity

---

## 1. Contexto y Problemática
Una ciudad nocturna desierta no transmitía la atmósfera urbana del conurbano bonaerense. Se requería:
1. Tráfico vehicular en movimiento que respete el sentido real de circulación de las calles de Ramos Mejía (mano única o doble mano según OSM).
2. Autos estacionados a los cordones dejando despejado el centro de la calzada para el flujo del tránsito.
3. Señalización realista: que los autos pongan la luz de giro (guiño) antes de doblar en una esquina.
4. Modelos 3D realistas en escala 1:1 sin penetrar el suelo.

---

## 2. Decisión Tomada
1. **Autos Estacionados Procedurales (`scripts/track.gd` y `tools/expand_neighborhood.py`):**
   - Distribución de más de 500 vehículos a lo largo de los cordones de las calles secundarias.
   - Restricción de seguridad: no se generan autos estacionados en la traza principal de Avenida Rivadavia a menos de 7,5 metros del eje para preservar el flujo de alta velocidad.
   - **Corrección de origen de modelos:** Se compensó el centroide del modelo `car_compact.glb` (`Y = 0.540 m`) y sedanes/SUVs para que las 4 ruedas apoyen exactamente a nivel del pavimento (`Y = 0.04 m`).
2. **Grafo de Carriles de Tráfico (`scripts/traffic_manager.gd`):**
   - Extrae más de 500 segmentos de carriles orientados a partir de los atributos `oneway` y jerarquía de OSM.
   - Mantiene una flota activa de hasta 38 vehículos en el sector céntrico mediante un pool de spawn/despawn por distancia a la moto.
3. **Comportamiento de los Vehículos IA (`scripts/traffic_vehicle.gd`):**
   - Seguimiento suave de waypoints.
   - Sensor frontal mediante `RayCast3D` para frenar automáticamente ante peatones, la moto u otros autos detenidos.
   - **Luces de giro (guiños ámbar):** Al aproximarse a unos 45 metros de una esquina donde el vehículo tiene planeado doblar, activa con 90% de probabilidad un destello rítmico a 1,8 Hz en las ópticas ámbar correspondientes (izquierda o derecha).
   - Faros delanteros (`SpotLight3D` cálido) y luces de posición rojas traseras para ambientación nocturna.

---

## 3. Archivos y Subsistemas Afectados
- `scripts/traffic_manager.gd`: Gestor del grafo de calles y ciclo de vida de los autos.
- `scripts/traffic_vehicle.gd`: Controlador `CharacterBody3D`, IA de navegación, luces y colisión.
- `scripts/track.gd`: Instanciación de autos estacionados y metadata física.
- `assets/vehicles/`: Modelos 3D optimizados `car_sedan.glb`, `car_suv.glb`, `car_compact.glb`.

---

## 4. Consecuencias y Trade-offs

### Positivas
- Inmersión urbana inmediata: calles con vida, tráfico que dobla señalizando con guiño y autos a los costados como en las fotos reales de Ramos Mejía.
- Rendimiento sobresaliente: `shadow_enabled = false` en las luces de autos y culling de distancia a 65 m aseguran 60 FPS estables.

### Negativas / Limitaciones Aceptadas
- La IA sigue rutas basadas en carriles fijos; no realiza sobrepasos agresivos por la banquina.

---

## 5. Validación y Pruebas Automatizadas
- `tools/test_map.gd`:
  - `check(track.get_node("ParkedCars").get_child_count() > 500, "parked cars populated along curbs")`
  - `check(not car_hit.is_empty(), "parked cars have physical obstacle collision")`
  - `check(tm != null and int(tm.get("lanes").size()) > 500, "traffic manager initialized with directed street lanes graph")`

# ADR-0010: Tráfico Barrial Continuo mediante Grilla Espacial y Repartos Combinados Multiparada

- **Estado:** Aceptado
- **Fecha:** 2026-11-01
- **Autores / Decisores:** Usuario / Agente Antigravity
- **Hito:** Sprint `alpha-0.0.2`

---

## 1. Contexto y Problemática

Durante las pruebas de juego en mundo abierto se detectaron tres limitaciones fundamentales en la jugabilidad:
1. **Despoblación repentina del tráfico vehicular al salir del centro:**  
   En el centro comercial de Ramos Mejía los autos circulaban correctamente, pero en cuanto el jugador se adentraba en los barrios residenciales, las calles quedaban desiertas. El método previo de generación seleccionaba carriles aleatoriamente de un array global de más de 1.500 carriles y sólo intentaba instanciar si el inicio del carril (`l["start"]`) caía a menos de 125 metros del jugador. Dado el tamaño del mapa (8,11 km²), la probabilidad de que un carril al azar cumpliera esa condición era inferior al 0,6%, resultando en un 88,6% de intentos fallidos por tick y dejando vacías las arterias periféricas.
2. **Repartos concentrados en el centro comercial:**  
   El catálogo de destinos de entrega estaba restringido a 25 calles céntricas preseleccionadas y un bounding box artificial en torno a las vías, desaprovechando el 85% de la superficie urbana de Ramos Mejía.
3. **Mecánica de delivery lineal de una sola parada:**  
   El jugador sólo podía realizar entregas punto a punto simples, limitando la estrategia de ruta y el incentivo para recorrer distancias mayores a cambio de mayores ingresos.

---

## 2. Decisión Tomada

1. **Grilla Espacial Hash para Carriles de Tráfico (`scripts/traffic_manager.gd`):**
   - Se indexan los carriles en celdas espaciales 2D de $120\times 120\text{ m}$ (`lanes_by_cell: Dictionary[Vector2i, Array[int]]`).
   - El spawn consulta exclusivamente las celdas adyacentes al jugador (`_get_nearby_lane_indices(pos, radius)`), eliminando el 100% del descarte aleatorio.
   - Si el carril atraviesa el radio de spawn, se calcula un punto válido a lo largo del segmento dentro del rango de distancia $[35, 150]\text{ m}$, evitando saturar únicamente las esquinas de inicio.
   - Se asegura una población mínima de vehículos constante en barrios residenciales (objetivo base escalado dinámicamente) y mayor densidad en avenidas céntricas.
2. **Indexación Urbana Integral de 1.232 Direcciones Reales (`scripts/mission_system.gd`):**
   - Se eliminaron las restricciones de lista blanca de calles y cajas de recorte.
   - Se indexan todas las calles no ferroviarias y transitables del mapa de Ramos Mejía, cubriendo desde Don Bosco y Villegas al sur ($Y \approx 2.450\text{ m}$), hasta Palomar y Caseros al norte ($Y \approx -1.010\text{ m}$), y Haedo al oeste ($X \approx -3.675\text{ m}$).
   - Cada dirección incluye su zona geográfica formal calculada dinámicamente: *Ramos Centro, Ramos Norte, Ramos Norte Oeste, Ramos Sur, Ramos Sur Este, Ramos Sur Oeste*.
3. **Sistema de Repartos Combinados Multiparada (2 Casas):**
   - El generador de 3 ofertas presenta tres niveles diferenciados:
     - **Opción 1:** Pedido Exprés / Cercano ($280\text{ a }750\text{ m}$, $\$1.800\text{ a }\$2.600$).
     - **Opción 2:** Larga Distancia / Cruce de Vías ($1.000\text{ a }2.400\text{ m}$, $\$3.400\text{ a }\$5.500$).
     - **Opción 3 (Reparto Combinado):** Dos casas en distintos barrios con bono combo del $+35\%$ ($\$6.500\text{ a }\$11.500+$).
   - Manejo de estado con cobro parcial ($40\%$ al entregar la primera casa, $60\%$ restante con bono al completar la segunda).
   - Indicador visual en HUD y en el mundo 3D (`ENTREGA 1 DE 2`, `ENTREGA 2 DE 2`, dirección de la próxima parada y tarjeta dorada en el menú de selección).

---

## 3. Consecuencias

### Positivas
- Tráfico automotor vivo, fluido y continuo en cualquier calle de la ciudad sin sobrecargar la CPU (tiempo de búsqueda $O(1)$ amortizado en la grilla espacial).
- El jugador utiliza la totalidad de los 8,11 km² reales de Ramos Mejía, fomentando la exploración barrial.
- Mayor variedad estratégica de misiones y recompensas económicas acordes al esfuerzo de viaje.

### Neutras / A Considerar
- Los repartos combinados exigen mayor atención a la orientación por nombres de calles y cruces de vías del FF.CC. Sarmiento mediante puentes o pasos habilitados.

---

## 4. Validación Técnica

- `tools/test_map.gd`:
  - `PASS citywide address pool indexed across entire 8 km² map` (1.232 direcciones generadas).
  - `PASS generates 3 delivery tier offers`.
  - `PASS tier 2 offer is multi-drop with 2 destination stops`.
  - `PASS traffic manager spatial hash grid active for citywide vehicle spawning`.
  - `MAP_QA failures=0`.
- `tools/test_density.py`:
  - `DENSITY_QA_OK: private blocks sealed, 2492 new solid volumes, 240 open passages, plazas preserved`.

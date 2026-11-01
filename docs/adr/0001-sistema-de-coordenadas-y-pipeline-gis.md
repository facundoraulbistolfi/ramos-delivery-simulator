# ADR-0001: Sistema de Coordenadas y Pipeline GIS para Ramos Mejía

- **Estado:** Aceptado
- **Fecha:** 2026-10-30
- **Autores / Decisores:** Usuario / Agente Antigravity

---

## 1. Contexto y Problemática
Para recrear la localidad de Ramos Mejía con fidelidad urbana real (8,11 km², límite administrativo OSM `relation 1748197`), se requería un sistema riguroso para traducir datos cartográficos de OpenStreetMap (latitud/longitud en grados) a un espacio de juego 3D interactivo en Godot, sin deformaciones de escala ni desalineación con la física.

---

## 2. Decisión Tomada
1. **Convención métrica 1:1:** Se definió que **1 unidad en Godot equivale a exactamente 1 metro real**.
2. **Origen de coordenadas:** El punto `(0, 0, 0)` se fijó en la intersección de **Avenida Rivadavia y Larrea**.
3. **Orientación de ejes:**
   - Eje **Y**: Altura vertical (+Y hacia el cielo, -Y hacia el suelo).
   - Eje **X / Z**: Plano horizontal donde -Z es el avance hacia el Oeste sobre Rivadavia y los rumbos coinciden con la proyección cartográfica local.
4. **Pipeline en dos fases:**
   - **Fase pre-proceso (Python):** `tools/prepare_ramos_map.py`, `tools/expand_neighborhood.py` y `tools/block_density.py` procesan los nodos y vías de OSM, cierran las manzanas mediante triangulación con relleno macizo (`block_density.py`), calculan ochavas y cruces, y exportan un archivo estructurado `assets/maps/ramos_mejia.json`.
   - **Fase de ejecución (Godot GDScript):** `scripts/track.gd` lee el JSON e instancia los meshes optimizados mediante `SurfaceTool`, asignando colisiones estáticas y particionamiento espacial (`SectorChunks`).

---

## 3. Archivos y Subsistemas Afectados
- `tools/prepare_ramos_map.py`: Extracción y filtrado de datos OSM.
- `tools/expand_neighborhood.py`: Expansión de calles secundarias y cruces.
- `tools/block_density.py`: Infill volumétrico de centros de manzana para evitar huecos.
- `assets/maps/ramos_mejia.json`: Archivo maestro generado.
- `scripts/track.gd`: Generador de malla y colisiones en tiempo de carga.

---

## 4. Consecuencias y Trade-offs

### Positivas
- Precisión métrica absoluta: anchos de calle reales (10 a 16 m), veredas transitables y distancias de cuadra exactas.
- No hay cálculos pesados de geometría geográfica en runtime; el JSON carga en segundos.
- 0 huecos en interiores de manzana (`DENSITY_QA_OK: 2425 solid volumes`).

### Negativas / Limitaciones Aceptadas
- `assets/maps/ramos_mejia.json` es un archivo generado de gran tamaño (~23 MB) y no debe editarse a mano; cualquier ajuste estructural requiere regenerarlo con Python.

---

## 5. Validación y Pruebas Automatizadas
- `tools/test_map.gd`:
  - `check(absf(track.get_track_length()-1647.630512)<0.03, "metric route length 1647.63 m")`
  - `check(track.centerline[0].length()<0.01, "Larrea origin")`
- `tools/test_density.py`:
  - Verifica que no existan huecos transitables mayores al tamaño de una moto en centros privados de manzana.

# AGENTS.md · Directivas de Ingeniería para Agentes de IA

> **Propósito de este documento:**  
> Este repositorio está diseñado con una arquitectura **Agent-First**. El objetivo es eliminar el *vibe coding* no estructurado: cualquier agente de IA que trabaje en esta base de código debe operar con rigor de ingeniería, comprender la arquitectura del juego, saber con exactitud **qué tocar**, respetar las restricciones físicas y de rendimiento, y dejar asentadas todas las decisiones de diseño mediante **Architecture Decision Records (ADR)** y el **Roadmap**.

---

## 1. Identidad y Visión del Proyecto

- **Juego:** Simulación de manejo en moto 3D en mundo abierto y misiones de delivery nocturno ambientadas en la localidad real de **Ramos Mejía, La Matanza, Buenos Aires, Argentina**.
- **Escala geográfica:** **8,11 km²** reales basados en OpenStreetMap (`relation 1748197`), **577 manzanas urbanas cerradas**, red ferroviaria del FF.CC. Sarmiento con puentes vehiculares/peatonales y pasos a nivel cerrados, y comercios e instituciones emblemáticas.
- **Motor:** **Godot 4.4+** (utiliza actualmente `Godot_v4.7.2-stable_win64_console.exe` en `.tools/`).
- **Renderizador:** `Compatibility` (diseñado para correr con alto framerate en PCs modestas sin GPU dedicada).
- **Convención métrica estricta:** **1 unidad en Godot = 1 metro real**. Escala 1:1 en motos, autos, anchos de calzada, veredas y edificios.

---

## 2. Los Dos Modos de Juego Principales

El juego arranca presentando un diálogo inicial de selección (`scripts/hud.gd` y `scripts/game.gd`):

1. **Modo Delivery (Turno Nocturno):**
   - Turno cronometrado de 10 minutos.
   - Selección de punto de partida y 3 opciones de pedidos simultáneos.
   - Tiempos de preparación en cocina y bonificación por tiempo PAR hacia la entrega.
   - **Economía con penalización física:** Chocar autos estacionados o tráfico descuenta dinero de la billetera según la gravedad del impacto ($10\text{ a }>50\text{ km/h}$).
2. **Modo Libre / Debug:**
   - Paseo sin límite de tiempo ni misiones obligatorias.
   - Acceso inmediato al **Selector de Teletransporte (`[TAB]`)** con 39 destinos, **Plano de Calles (`[M]`)**, atajos a edificios emblemáticos (`[1]`, `[2]`, `[3]`, `[T]`), sin multas ni deducciones.
   - Se puede alternar entre modos en cualquier momento pausando con **`[ESC]`** $\rightarrow$ *Cambiar Modo de Juego*.

---

## 3. Mapa de Dominios: «¿Qué archivo tocar según lo que quieras cambiar?»

| Dominio / Funcionalidad | Archivos Clave | Responsabilidad y Consideraciones |
| :--- | :--- | :--- |
| **Pipeline GIS & Generación del Mapa** | `tools/prepare_ramos_map.py`<br>`tools/expand_neighborhood.py`<br>`tools/block_density.py`<br>`assets/maps/ramos_mejia.json` | Descarga/procesa geometrías OSM, computa volúmenes macizos de manzana, calcula cruces de calles y genera el JSON maestro. **No editar el JSON a mano**, regenerar mediante scripts de Python. |
| **Escena del Mundo & Carga de Geometría** | `scripts/track.gd`<br>`scenes/ramos_mejia.tscn`<br>`scenes/ramos_mejia_base.tscn` | Instancia las mallas de asfalto, veredas, edificios genéricos, carteles nomencladores, autos estacionados y luces nocturnas agrupadas en chunks espaciales optimizados (`SectorChunks`). |
| **Manejo, Física y Colisión de la Moto** | `scripts/bike.gd`<br>`scenes/bike.tscn`<br>`scripts/chase_camera.gd` | Controlador arcade `CharacterBody3D`. Detecta velocidad de colisión previa a `move_and_slide()`, emite `vehicle_crashed` ante autos y aplica rebote físico y cooldown de 1.0 s. |
| **Tráfico Dinámico y Vehículos IA** | `scripts/traffic_manager.gd`<br>`scripts/traffic_vehicle.gd`<br>`assets/vehicles/*.glb` | Genera vehículos circulando en el sentido de las calles, con cálculo de luces de giro ámbar 45 m antes de la esquina (90% probabilidad), luces nocturnas y detección de obstáculos por raycast. |
| **Misiones, Delivery y Economía** | `scripts/mission_system.gd` | Maneja el turno de 10 minutos, catálogo gastronómico, 3 ofertas dinámicas, cálculo de tarifa/propina PAR, estado de entrega y deducción de multas por choque (`apply_crash_penalty`). |
| **HUD, Interfaz, Mapa y Diálogos** | `scripts/hud.gd` | Interfaz en dos paneles (`OrderPanel` y `StatusPanel`), plano de calles pantalla completa `[M]`, teletransporte `[TAB]`, modal de selección de modo, ofertas de pedidos y resumen final de jornada. |
| **Assets Personalizados y Overlays** | `custom/`<br>`scenes/custom_overlays.tscn`<br>`assets/maps/custom_overlays.json` | **Capa desacoplada:** Todo asset 3D propio, estatua, monumento o decoración que agregue el usuario o el agente debe colocarse aquí para que la regeneración del mapa OSM no la pise jamás. |
| **Pruebas Automatizadas (QA)** | `tools/test_map.gd`<br>`tools/test_density.py` | Suite headless de Godot y script Python para validar que la moto sea manejable, no haya huecos en manzanas, los puentes funcionen y el HUD responda. |

---

## 4. Protocolo Obligatorio para Agentes de IA

Cualquier agente que tome una tarea en este repositorio **debe cumplir este flujo sin excepción**:

### Paso 1: Exploración y Consulta de ADRs
- Antes de proponer cambios, leer los ADRs relevantes en `docs/adr/`.
- No asumir lógica oculta; revisar los scripts GDScript asociados y sus tests en `tools/`.

### Paso 2: Planificación Previa
- Explicar qué archivos se van a modificar, qué métodos nuevos se incorporan y cómo se mantendrán las garantías de rendimiento y compatibilidad.

### Paso 3: Implementación Limpia
- Escribir GDScript 2.0 idiomático (Godot 4), con tipado estático (`: float`, `: Vector3`, `-> void`).
- Respetar el aislamiento: los assets creados a mano van a `custom/` o `assets/imported/`, no a las carpetas temporales ni al root.

### Paso 4: Test Gate Obligatorio (0 Fallos)
Antes de declarar una tarea como finalizada, el agente **debe ejecutar y verificar**:

```powershell
# 1. Test de integración y físicas en Godot Headless
.tools\Godot_v4.7.2-stable_win64_console.exe --headless --script tools/test_map.gd

# 2. Test de densidad de manzanas y huecos en Python
C:\Users\facun\AppData\Local\Programs\Python\Python39\python.exe tools/test_density.py
```

- Si `MAP_QA failures > 0` o `test_density.py` falla, la tarea **está incompleta**. El agente debe diagnosticar y corregir el error antes de responder al usuario.

### Paso 5: Registro de Decisiones (ADR)
- Si el cambio altera la arquitectura, agrega un subsistema nuevo o cambia una regla de juego fundamental:
  1. Crear un nuevo archivo en `docs/adr/NNNN-titulo-en-kebab-case.md` siguiendo la plantilla `docs/adr/template.md`.
  2. Documentar: Contexto, Decisión, Consecuencias (positivas y negativas) y Validación técnica.

### Paso 6: Actualización del Roadmap
- Actualizar `docs/roadmap.md` marcando los ítems completados o agregando las nuevas tareas identificadas.

---

## 5. Reglas de Seguridad y Anti-Regresión ("Never Do")

1. **Nunca romper el modo headless de los tests:**
   - Al agregar diálogos modales o menús interactivos al inicio, verificar siempre `if DisplayServer.get_name() == "headless":` para que las pruebas automatizadas arranquen directamente sin bloquearse por inputs de pantalla.
2. **Nunca editar a mano `assets/maps/ramos_mejia.json`:**
   - Cualquier cambio en la red vial o manzanas debe hacerse a través del pipeline en `tools/*.py`.
3. **Cuidado estricto con los orígenes (`Y = 0`) de modelos 3D:**
   - Muchos modelos `.glb` tienen el pivote en el centro geométrico o flotando. Siempre verificar los extremos de las ruedas y la caja de colisión para que los autos o motos no queden hundidos en el asfalto.
4. **Respetar la transitabilidad de Avenida Rivadavia:**
   - La traza principal de Rivadavia es el eje de pruebas autónomas de `test_map.gd`. Nunca generar autos estacionados ni postes que intersecten la línea central de Rivadavia a menos de 7,5 metros de distancia.
5. **No saturar la GPU:**
   - Mantener materiales simples sin texturas 4K pesadas.
   - Usar `visibility_range_end` para LOD y culling en props densos (árboles, autos, carteles).
   - Sombras dinámicas únicamente en la luz del sol; las luces puntuales nocturnas (`OmniLight3D`, `SpotLight3D`) deben tener `shadow_enabled = false` para garantizar 60 FPS estables.

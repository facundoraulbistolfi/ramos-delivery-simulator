# Reglas de Ingeniería Agent-First para Antigravity en Ramos Mejía 3D

Este repositorio opera bajo una metodología de ingeniería estricta **Agent-First**.
Cualquier agente de IA que interactúe en este espacio de trabajo debe cumplir rigurosamente con las directivas especificadas en `AGENTS.md`.

---

## 1. Directivas Obligatorias de Trabajo

1. **Consulta Previa:**
   - Antes de realizar modificaciones complejas, consultar `AGENTS.md` y los registros de decisiones en `docs/adr/` para entender la arquitectura vigente y evitar regresiones.
2. **Prohibido el "Vibe Coding":**
   - No implementar código a tientas o basado en conjeturas. Formular un plan claro explicando los componentes a modificar y las garantías de rendimiento a preservar.
3. **Test Gate Obligatorio (0 Fallos):**
   - Ninguna tarea se considera completa sin antes ejecutar y verificar que pasen con 0 fallos las dos suites de prueba automatizadas:
     - **Godot QA:** `.tools\Godot_v4.7.2-stable_win64_console.exe --headless --script tools/test_map.gd`
     - **Densidad de Manzanas:** `C:\Users\facun\AppData\Local\Programs\Python\Python39\python.exe tools/test_density.py`
4. **Registro de Decisiones Arquitectónicas (ADR):**
   - Ante la creación de un nuevo subsistema, cambio de convención técnica o modificación de reglas fundamentales de juego, redactar obligatoriamente un nuevo Architecture Decision Record en `docs/adr/NNNN-nombre.md` basado en `docs/adr/template.md`.
5. **Actualización del Roadmap:**
   - Mantener al día `docs/roadmap.md`, marcando las tareas completadas y documentando nuevos ítems surgidos.

---

## 2. Guardarraíles Técnicos Críticos ("Never Do")

- **Compatibilidad Headless:** Toda interfaz o diálogo inicial (`hud.gd`, `game.gd`) debe detectar si el entorno es `DisplayServer.get_name() == "headless"` para omitir bloqueos modales y permitir que los tests de integración ejecuten sin intervención manual.
- **Pipeline GIS vs. Capa Custom:** Nunca editar a mano `assets/maps/ramos_mejia.json`. Todo asset 3D propio o decoración personalizada debe colocarse en `custom/` o en `scenes/custom_overlays.tscn` para no perderse en las regeneraciones de mapas.
- **Escala Métrica 1:1:** 1 unidad = 1 metro. Respetar las dimensiones reales de vehículos y calles. Verificar siempre el pivote Y de modelos importados (`.glb`) para que no queden enterrados en el asfalto.
- **Transitabilidad de Rivadavia:** No generar obstáculos a menos de 7,5 metros del eje de Avenida Rivadavia.

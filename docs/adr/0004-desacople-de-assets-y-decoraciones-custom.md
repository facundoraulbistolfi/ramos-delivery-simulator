# ADR-0004: Desacople de Assets Personalizados y Capa de Overlays

- **Estado:** Aceptado
- **Fecha:** 2026-10-31
- **Autores / Decisores:** Usuario / Agente Antigravity

---

## 1. Contexto y Problemática
El usuario necesitaba poder agregar assets 3D personalizados (monumentos como la Estatua de Manuel Belgrano, carteles especiales, árboles o edificios propios) en paralelo al desarrollo, pero sin el riesgo de que una regeneración del mapa base por parte de los scripts de Python sobrescribiera o borrara sus modificaciones manuales.

---

## 2. Decisión Tomada
1. **Aislamiento en capas:**
   - **Capa Base Procedural:** Generada por el pipeline GIS en `scenes/ramos_mejia_base.tscn` y `assets/maps/ramos_mejia_base.json`.
   - **Capa de Overlays y Custom:** Ubicada en `custom/`, `scenes/custom_overlays.tscn` y `assets/maps/custom_overlays.json`.
2. **Carga no destructiva en runtime (`scripts/track.gd`):**
   - Al iniciar el mapa, `track.gd` carga primero la capa base procedural y luego busca si existe `scenes/custom_overlays.tscn`.
   - Si la escena custom está presente, la instancia como hijo en el árbol de escena y combina sus puntos de colisión e interés con la base.
   - De esta manera, el usuario o los agentes pueden regenerar el mapa GIS cuantas veces sea necesario sin perder jamás una escultura o detalle personalizado.
3. **Caso de prueba de referencia:**
   - Se instanció la **Estatua del General Manuel Belgrano** con mástil y colisiones sólidas en la Plazoleta Belgrano (`scenes/estatua_belgrano.tscn`).

---

## 3. Archivos y Subsistemas Afectados
- `custom/`: Directorio reservado exclusivamente para modelos `.glb`, `.obj`, texturas o escenas hechas a mano.
- `scenes/custom_overlays.tscn`: Escena modular que agrupa los nodos decorativos personalizados.
- `scripts/track.gd`: Lógica de vinculación y carga diferida de overlays.
- `tools/build_ramos_map.gd`: Compatibilidad para exportar tanto mapas base como mapas compuestos.

---

## 4. Consecuencias y Trade-offs

### Positivas
- Total libertad para que el usuario o artistas 3D agreguen modelos sin tocar el código de Python.
- Los scripts de generación no tocan la carpeta `custom/`.
- Fácil de compartir en Git o aislar en caso de necesitar una prueba limpia del mapa base.

### Negativas / Limitaciones Aceptadas
- Los objetos colocados en la capa custom deben coordinar sus coordenadas globales con el sistema métrico del mapa base para no quedar flotando ni superpuestos con edificios existentes.

---

## 5. Validación y Pruebas Automatizadas
- `tools/test_map.gd`:
  - `check(track.user_decorations != null, "custom user decorations layer loaded")`
  - `check(belgrano_statue != null, "Estatua de Belgrano instantiated in Plazoleta Belgrano")`
  - `check(not statue_hit.is_empty(), "Estatua de Belgrano has solid physical collision")`

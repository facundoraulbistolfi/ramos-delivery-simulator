# ADR-NNNN: [Título Descriptivo de la Decisión]

- **Estado:** [Propuesto | Aceptado | Reemplazado por ADR-XXXX | Obsoleto]
- **Fecha:** YYYY-MM-DD
- **Autores / Decisores:** [Usuario / Agente Antigravity]

---

## 1. Contexto y Problemática
Describe la situación que motivó esta decisión técnica.  
- ¿Qué necesidad de juego o requerimiento del usuario surgió?
- ¿Cuáles eran las restricciones técnicas, de rendimiento o de simulación?
- ¿Qué alternativas se evaluaron y por qué fueron descartadas?

---

## 2. Decisión Tomada
Describe de manera clara y directa la solución técnica adoptada.  
- ¿Cómo se estructuró la solución?
- ¿Cuáles son las reglas de negocio o físicas aplicadas?
- ¿Por qué esta solución es la más adecuada para la arquitectura del proyecto?

---

## 3. Archivos y Subsistemas Afectados
Lista de módulos y rutas modificadas o creadas:
- `scripts/ejemplo.gd`: Descripción breve del cambio.
- `scenes/ejemplo.tscn`: Modificaciones en el árbol de nodos.

---

## 4. Consecuencias y Trade-offs

### Positivas
- Beneficio 1 (ej: optimización de framerate, mayor fidelidad).
- Beneficio 2 (ej: facilidad de testeo automatizado).

### Negativas / Limitaciones Aceptadas
- Restricción 1 (ej: requiere no colocar objetos a menos de 7.5m de la ruta).
- Restricción 2 (ej: en modo headless se desactiva el modal interactivo).

---

## 5. Validación y Pruebas Automatizadas
Cómo se comprueba que esta decisión se mantiene sana a lo largo del tiempo:
- Comando de prueba ejecutado (ej: `tools/test_map.gd`).
- Aserciones verificadas (ej: `MAP_QA failures=0`).

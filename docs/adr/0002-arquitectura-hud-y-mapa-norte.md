# ADR-0002: Arquitectura del HUD en Dos Paneles y Plano de Calles Orientado al Norte

- **Estado:** Aceptado
- **Fecha:** 2026-10-31
- **Autores / Decisores:** Usuario / Agente Antigravity

---

## 1. Contexto y Problemática
El HUD original presentaba elementos de juego de carreras (vueltas, mejores tiempos, barras que ocupaban el centro de la pantalla). El usuario solicitó reorganizar la interfaz para que sea limpia: la información del pedido de delivery por un lado, la velocidad y estado de la moto por el otro, y un mapa completo para consultar las calles sin flechas de GPS invasivas ("navegación a ojo").

---

## 2. Decisión Tomada
1. **Separación en dos paneles flotantes:**
   - **Panel Izquierdo (`OrderPanel`):** Estado del turno nocturno, tiempo restante, billetera, entregas, nombre del local de retiro o dirección de entrega con entrecalles, precio del ítem y tarifa/propina.
   - **Panel Derecho (`StatusPanel`):** Velocidad actual en KM/H, barra de aceleración, nivel de turbo y nombre de la calle/cruce actual en tiempo real.
2. **Plano de Calles a Pantalla Completa (`[M]`):**
   - Canvas vectorial dibujado con `FullMapCanvas` que cubre toda la pantalla.
   - Orientado estrictamente al **Norte** cartográfico.
   - Muestra todas las calles con sus nombres, vías del tren, plazas y límites de Ramos Mejía (las zonas aledañas aparecen en gris apagado).
   - Muestra únicamente la posición y orientación del jugador mediante un cursor.
   - **Bloqueo de conducción:** Mientras el plano está abierto, la moto no responde al acelerador ni volante para simular al repartidor deteniéndose en la vereda a mirar el mapa.
3. **Selector de Teletransporte (`[TAB]`):**
   - Menú con buscador y filtros por categoría (Comercios, Puentes, Plazas, Avenidas, Instituciones) con 39 puntos clave.

---

## 3. Archivos y Subsistemas Afectados
- `scripts/hud.gd`: Implementación completa de `OrderPanel`, `StatusPanel`, `_map_overlay`, `_teleport_overlay` y señal `overlay_state_changed`.
- `scripts/game.gd`: Conexión de inputs `toggle_map` (`M`) y `teleport_menu` (`TAB`), y bloqueo de controles de la moto vía `hud.is_blocking_gameplay()`.

---

## 4. Consecuencias y Trade-offs

### Positivas
- Vista de conducción libre de elementos intrusivos en el centro de la pantalla.
- Fomenta la navegación urbana orgánica guiada por la señalética de las calles.
- El jugador puede consultar el mapa completo con un solo toque y pausar la marcha de forma natural.

### Negativas / Limitaciones Aceptadas
- El plano de calles desactiva los controles de conducción, lo que puede sorprender a jugadores que esperaban un minimapa estilo radar activo.

---

## 5. Validación y Pruebas Automatizadas
- `tools/test_map.gd`:
  - `check(hud.has_node("Interface/OrderPanel") and hud.has_node("Interface/StatusPanel"), "simplified two-panel HUD active")`
  - `check(hud.is_map_open() and not bike.controls_enabled, "opening M map covers screen and disables driving controls")`
  - `check(not hud.is_map_open() and bike.controls_enabled, "closing M map restores driving controls")`

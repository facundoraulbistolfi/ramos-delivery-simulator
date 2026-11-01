# ADR-0006: Selección Inicial de Modo de Juego y Sistema de Multas por Choque

- **Estado:** Aceptado
- **Fecha:** 2026-11-01
- **Autores / Decisores:** Usuario / Agente Antigravity

---

## 1. Contexto y Problemática
El usuario solicitó que al iniciar el juego se pudiera elegir explícitamente entre:
1. **Modo Libre**: con teletransporte [TAB], mapa [M], atajos de debug y sin apuros de delivery.
2. **Modo Delivery**: con misiones, turno de 10 minutos y juego formal.

Asimismo, se solicitó que en el Modo Delivery **chocar contra autos descuente plata de la billetera** en función de la gravedad y velocidad del impacto, incentivando un manejo prudente entre el tráfico.

---

## 2. Decisión Tomada
1. **Modal de Selección al Iniciar (`scripts/hud.gd`):**
   - Presenta dos tarjetas claras: `[1] MODO DELIVERY` y `[2] MODO LIBRE / DEBUG`.
   - Se puede elegir con teclado (`1`, `2`, `Enter`) o haciendo clic.
   - Si se ejecuta en modo headless (`DisplayServer.get_name() == "headless"`), se selecciona automáticamente el Modo Delivery para que las suites de prueba de QA corran sin requerir interacción manual.
2. **Alternancia Dinámica desde Pausa:**
   - En cualquier momento se puede pausar con `[ESC]` y presionar "CAMBIAR MODO DE JUEGO" para pasar de Libre a Delivery o viceversa sin reiniciar la sesión.
3. **Detección Física de Choque (`scripts/bike.gd`):**
   - Tras el `move_and_slide()` de la moto, se evalúan las colisiones de deslizamiento contra cuerpos con metadata `is_vehicle` o de clase `TrafficVehicle`.
   - Umbral mínimo: impactos a menos de $10\text{ km/h}$ se ignoran para no castigar maniobras lentas de estacionamiento.
   - Amortiguación e inercia: el choque invierte y amortigua la velocidad de la moto (`speed = -speed * 0.25`) y activa un cooldown de 1.0 s para evitar descuentos repetitivos por roce continuo.
4. **Escala de Multas y Deducción de Dinero (`scripts/mission_system.gd`):**
   - **Leve ($10\text{ a }25\text{ km/h}$):** Raspón de chapa / espejo roto $\rightarrow$ $-\$350\text{ a }-\$650$.
   - **Moderado ($25\text{ a }50\text{ km/h}$):** Abolladura de puerta / paragolpes roto $\rightarrow$ $-\$700\text{ a }-\$1.950$.
   - **Grave ($>50\text{ km/h}$):** Destrucción de ópticas / choque frontal $\rightarrow$ $-\$2.000\text{ a }-\$5.000+$.
   - Se descuenta inmediatamente de `total_money`, se registra en `total_crash_fines` y `crash_count`, y se notifica con un toast en pantalla. Si la billetera queda en negativo, el HUD resalta en rojo: `BILLETERA: -$ X (EN ROJO)`.
   - El resumen final de la jornada nocturna desglosa el impacto neto y la cantidad de choques sufridos.

---

## 3. Archivos y Subsistemas Afectados
- `scripts/bike.gd`: Detección en `_physics_process()`, señal `vehicle_crashed(impact_kmh, collider)`.
- `scripts/mission_system.gd`: Método `apply_crash_penalty(impact_kmh)`, contabilidad de multas y resumen de jornada.
- `scripts/hud.gd`: `_build_mode_selection_dialog()`, `set_delivery_mode_active()`, atajos de teclado y reporte de multas en el modal de resumen.
- `scripts/game.gd`: Gestión de `current_game_mode` (`DELIVERY` vs `FREE_ROAM`) y coordinación de señales.
- `scripts/track.gd` y `scripts/traffic_vehicle.gd`: Asignación de metadata física `is_vehicle = true`.

---

## 4. Consecuencias y Trade-offs

### Positivas
- Clara separación de perfiles de jugador: disfrute contemplativo del barrio vs desafío contrarreloj con consecuencias económicas.
- Sensación física real al chocar: el rebote y el costo monetario transforman las calles transitadas en un desafío de destreza.
- Cero fricción en tests automatizados gracias al bypass headless condicional.

### Negativas / Limitaciones Aceptadas
- En caso de choques repetidos a alta velocidad, el jugador puede terminar la jornada con la billetera en saldo deudor ("en rojo").

---

## 5. Validación y Pruebas Automatizadas
- `tools/test_map.gd`:
  - `check(hud.has_node("Interface/ModeSelectionOverlay"), "startup mode selection overlay initialized")`
  - `check(fine > 0 and int(ms.get("total_money")) == money_before - fine, "crashing into car deducts money proportional to impact speed")`
  - `check(int(ms.get("total_crash_fines")) == fines_before + fine, "crash penalty fines tracked in mission summary")`

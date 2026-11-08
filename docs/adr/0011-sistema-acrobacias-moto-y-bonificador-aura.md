# ADR-0011: Sistema de Acrobacias en Moto Estilo GTA, Medidor de Aura y Multiplicador de Puntaje Final

- **Estado:** Aceptado
- **Fecha:** 2026-11-07
- **Autores / Decisores:** Usuario / Agente Antigravity
- **Hito:** Sprint `alpha-0.0.2`

---

## 1. Contexto y Problemática
Con el objetivo de incrementar el dinamismo arcade y la diversión en la conducción urbana por Ramos Mejía, el usuario solicitó incorporar un sistema de trucos y piruetas en motocicleta inspirado en *GTA: Vice City* y *GTA: San Andreas*.

Los requerimientos centrales definidos fueron:
1. Poder realizar trucos clásicos de moto tanto en asfalto como en el aire (Willy / Wheelie, Stoppie / Invertido, Saltos Acrobáticos, Backflips, Frontflips y Giros 180°/360°).
2. Recompensar las acrobacias aterrizadas limpiamente aumentando un **Medidor de Aura**.
3. Castigar la pérdida de equilibrio, los malos aterrizajes o los choques en plena pirueta provocando una **caída de la moto (wipeout)** y descontando puntos del Medidor de Aura.
4. Utilizar el nivel de Aura al finalizar el turno nocturno como un **bonificador multiplicador del Puntaje Final**.

Las restricciones de ingeniería exigían mantener intacta la estabilidad de `CharacterBody3D` en conducción estándar sobre calles planas, evitar el hundimiento de neumáticos en `Y = 0` durante rotaciones de cabeceo, no interferir con el grafo de tráfico IA (`TrafficManager`) y preservar 0 fallos en los tests headless (`tools/test_map.gd` y `tools/test_density.py`).

---

## 2. Decisión Tomada

1. **Física de Acrobacias y Pivotes Reales (`scripts/bike.gd`):**
   - Se incorporaron las acciones `stunt_wheelie` (`[Q]`, `[CTRL]`, `[Z]`) y `stunt_stoppie` (`[E]`, `[X]`).
   - **Willy (Wheelie):** En asfalto por encima de `12 km/h`, aplicar inclinación trasera eleva el frente pivotando matemáticamente sobre el parche de contacto del neumático trasero (`Vector3(0, 0, 0.6864)`), evitando que la rueda se hunda bajo `Y = 0`. Entre `35°` y `60°` se ubica la zona óptima (+8% velocidad punta y mayor tasa de Aura); entre `60°` y `75°` el colín raspa chispas sobre el asfalto advirtiendo peligro; alcanzar `76°` provoca caída hacia atrás (*loop-out*).
   - **Stoppie / Invertido:** En velocidad (`>20 km/h`), inclinar hacia adelante aplica freno delantero progresivo pivotando sobre el neumático delantero (`Vector3(0, 0, -0.6864)`). Superar `-58°` proyecta al piloto por encima del manubrio.
   - **Despegue en Rampas, Puentes y Acrobacias Aéreas:** Cuando la moto asciende pendientes o rampas con velocidad vertical `slope_vy > 1.75 m/s`, se anula temporalmente `floor_snap_length` transfiriendo el impulso vertical a `velocity.y`. En el aire, la malla rota respecto al centro de masa (`Vector3(0, 0.58, 0)`), permitiendo **Backflips**, **Frontflips** y **Giros de 180°/360°**, además de cadenas de **Combo** (ventana de `3.2 s`, hasta `x2.5`).
   - **Caída y Recuperación (`Wipeout`):** Pasarse del ángulo límite, aterrizar invertido/cruzado o chocar contra vehículos/muros durante un truco dispara una secuencia física de `1.55 s` donde la moto derrapa de costado con chispas, el repartidor rueda y vuelve a montar automáticamente, descontando Aura.

2. **Rampas Acrobáticas Desacopladas (`custom/props/rampa_acrobatica.tscn` y `custom/decorations.tscn`):**
   - Siguiendo el [ADR-0004](0004-desacople-de-assets-y-decoraciones-custom.md), se creó el prop modular `rampa_acrobatica.tscn` (pendiente suave de `18.1°` al ras del pavimento, balizado luminoso sin sombras dinámicas y LOD a `190 m`).
   - Su `StaticBody3D` utiliza `collision_layer = 2` mientras `Moto` emplea `collision_mask = 3` y `TrafficVehicle` mantiene `collision_mask = 1`. Esto permite a la moto despegar físicamente en puntos clave (Av. de Mayo Norte/Centro/Sur, Plaza Mitre y Plaza Bomberitos) sin obstruir jamás al tránsito IA ni la traza de Av. Rivadavia.

3. **Medidor de Aura y Multiplicador de Puntaje Final (`scripts/mission_system.gd` y `scripts/hud.gd`):**
   - El **Medidor de Aura** escala de `0` a `1000` a través de 5 rangos: *Sin Aura*, *Piloto Callejero*, *Puro Corte*, *Rey de Ramos* y *Leyenda ★ Max Aura* (acompañado de un resplandor sutil bajo el chasis sin sombras).
   - Al concluir el turno de 15 minutos, el Aura actúa como multiplicador directo de `x1.00` a `x2.00` (`+0%` a `+100%`) sobre la recaudación neta positiva:
     $$\text{Puntaje Final} = \text{Billetera Neta} + \operatorname{round}\!\left(\max(0, \text{Billetera Neta}) \cdot \frac{\text{Aura}}{1000}\right)$$
   - De este modo, el jugador debe combinar entregas eficientes con manejo acrobático sin descuidar los pedidos ni sufrir caídas antes del cierre del turno. El `Puntaje Final` y el multiplicador alcanzado se persisten en `user://highscores.json`.

---

## 3. Archivos y Subsistemas Afectados
- `scripts/bike.gd` y `scenes/bike.tscn`: Física de Willy, Stoppie, vuelo en rampas, flips, combos, wipeout, chispas procedurales y pivotes exactos de ruedas.
- `scripts/chase_camera.gd`: Encuadre dinámico en acrobacias y sacudida de cámara (`add_trauma`) en impactos y caídas.
- `scripts/mission_system.gd`: Contabilidad de Aura (`add_aura`, `lose_aura`), rangos, `calculate_final_score()` y persistencia en Highscores.
- `scripts/hud.gd`: Barra `AuraBar` en `StatusPanel`, banner inferior en vivo `StuntBanner` con indicador de riesgo de ángulo, actualización del Manual del Repartidor y desglose de `Puntaje Final` en `ShiftSummaryOverlay`.
- `scripts/game.gd`: Mapeo de acciones de trucos y orquestación de señales entre moto, cámara, misiones y HUD.
- `custom/props/rampa_acrobatica.tscn` y `custom/decorations.tscn`: Rampas urbanas de salto en capa custom desacoplada.
- `tools/test_map.gd`: Pruebas headless automatizadas de Willy, Stoppie, caída por sobre-rotación, recuperación y cálculo de bono final de Aura.

---

## 4. Consecuencias y Trade-offs

### Positivas
- Transforma cada traslado entre local y cliente en una oportunidad activa de riesgo/recompensa al estilo arcade clásico de *GTA: Vice City / San Andreas*.
- Cero impacto en el tráfico automotor gracias al aislamiento por capas de colisión (`collision_layer = 2`).
- Rendimiento intacto en `Compatibility`: chispas *unshaded* ligeras y luces sin sombras proyectadas (`shadow_enabled = false`).

### Negativas / Limitaciones Aceptadas
- El multiplicador de Aura sólo bonifica saldos netos positivos de billetera (`total_money > 0`), evitando que un jugador sin entregas o con saldo deudor en rojo obtenga puntaje positivo únicamente haciendo piruetas en el lugar.

---

## 5. Validación y Pruebas Automatizadas
- `.tools\Godot_v4.7.2-stable_win64_console.exe --headless --script tools/test_map.gd` $\rightarrow$ `MAP_QA failures=0`.
- `python tools/test_density.py` $\rightarrow$ `DENSITY_QA_OK`.

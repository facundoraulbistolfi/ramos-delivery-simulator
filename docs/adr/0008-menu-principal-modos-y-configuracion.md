# ADR-0008: Menú Principal, Manual de Delivery, Turno de 15 Minutos, Podio de Récords y Menú de Opciones

- **Estado:** Aceptado
- **Fecha:** 2026-11-01
- **Autores / Decisores:** Usuario / Agente Antigravity
- **Hito:** Sprint `alpha-0.0.2`

---

## 1. Contexto y Problemática

Para la versión `alpha-0.0.2`, el usuario definió una estructura formal para la experiencia del jugador:
1. **Pantalla inicial con fondo animado del barrio:** Título "Delivery Simulator", versión del juego (`alpha-0.0.2`) y 3 opciones principales (Modo Delivery, Modo Libre y Opciones), además de salida del juego.
2. **Modo Delivery (Juego Competitivo):**
   - Modal instructivo tipo "Readme / Manual" previo al inicio, detallando las reglas: 15 minutos contrarreloj, propinas según tiempo PAR, multas económicas por colisión y prohibición de teletransporte.
   - Punto de inicio fijo obligatorio en **«La Tanga de Ramos»** (Rivadavia y Av. de Mayo).
   - Bloqueo estricto del menú de teletransporte (`[TAB]`) y atajos a monumentos (`[1]`, `[2]`, `[3]`, `[T]`).
   - Imposibilidad de cancelar o cambiar el pedido una vez elegido hasta no completar la entrega.
   - Al finalizar el turno: resumen con podio histórico de los 5 mejores puntajes (**Highscores**) persistido en disco.
3. **Modo Libre / Debug:**
   - Exploración ilimitada sin cronómetro de turno, teletransporte completo (`[TAB]`), plano de calles (`[M]`), atajos directos y pedidos opcionales a demanda (`[N]`).
4. **Menú de Opciones:**
   - Ajustes configurables y persistentes: Modo Pantalla Completa, Sombras Dinámicas (on/off, permitiendo eliminar el titileo visual en placas de video integradas), selector de Densidad de Tráfico automotor (Baja, Normal, Alta) y niveles de Volumen (Master, SFX, Ambiente).

---

## 2. Decisión Tomada

1. **Cámara Cinemática Orbital (`scripts/chase_camera.gd`):**
   - Se añadió la propiedad `cinematic_mode: bool`.
   - Cuando está activa, la cámara realiza una órbita panorámica suave en 360 grados sobre el corazón comercial y luminoso de Ramos Mejía (a $14,5\text{ m}$ de altura y radio de $45\text{ m}$ respecto a la intersección de Av. de Mayo y Rivadavia), permitiendo ver el tránsito vehicular nocturno de fondo mientras el menú principal está abierto.
2. **Sistema de Misiones, Turno de 15 Minutos y Highscores (`scripts/mission_system.gd`):**
   - Duración de turno: `const SHIFT_DURATION: float = 900.0` (15 minutos exactos).
   - En `start_delivery_mode()`: la moto aparece automáticamente en `track.get_tanga_spawn_transform()`, se resetean las estadísticas y se despliegan las 3 ofertas de locales gastronómicos.
   - En `start_new_mission()`: si hay un pedido activo (`State.PICKUP` o `State.DELIVER`), se bloquea el cambio y se notifica al jugador en pantalla.
   - Persistencia de récords en `user://highscores.json`: al terminar el turno, se ordenan los puntajes netos de forma descendente, se actualiza el Top 5 con fecha, cantidad de entregas y multas, y se identifica si se logró un nuevo récord histórico.
3. **Interfaz de Menú Principal, Manual de Reglas y Opciones (`scripts/hud.gd`):**
   - **Menú Principal (`_mode_selection_overlay`):** Fondo translúcido que permite apreciar la vista 3D urbana animada, título en tipografía destacada, badge de versión `alpha-0.0.2` y tres tarjetas seleccionables por clic o teclado (`[1]`, `[2]`, `[3]`, `[ESC]`). Mantiene el nombre de nodo `ModeSelectionOverlay` para compatibilidad absoluta con la suite headless de QA.
   - **Manual del Repartidor (`_briefing_overlay`):** Explica claramente las mecánicas de propinas, penalizaciones y restricciones antes de iniciar el turno.
   - **Panel de Opciones (`_options_overlay`):** Controles interactivos para pantalla completa, sombras dinámicas de sol/faros, densidad de tráfico y deslizadores de volumen con guardado en `user://settings.json`.
   - **Podio de Récords en Resumen (`ShiftSummaryOverlay`):** Renderiza la tabla histórica del Top 5 y destaca en dorado si el jugador obtuvo el primer puesto.
   - **Menú de Pausa:** Opciones contextuales según el modo (en Delivery: Continuar, Reiniciar Turno, Opciones y Volver al Menú Principal).
4. **Control de Flujo y Orquestación (`scripts/game.gd`):**
   - Al iniciar en modo interactivo, arranca en el Menú Principal con cámara cinemática y controles de conducción desactivados.
   - Si se ejecuta en modo headless (`DisplayServer.get_name() == "headless"`), se omite el menú e inicia de forma inmediata en Modo Delivery para no frenar los tests automatizados.
   - Aplica los ajustes de configuración al subsistema de ventana, a la luz solar (`$Sun.shadow_enabled`), a la densidad de `TrafficManager` y al bus de audio de Godot.
   - Filtra inputs para que en Modo Delivery queden estrictamente desactivados el menú de teletransporte (`[TAB]`) y las teclas rápidas de teletransportación a edificios.

---

## 3. Archivos y Subsistemas Afectados

- `scripts/chase_camera.gd`: Modo orbital cinemático con rotación continua.
- `scripts/mission_system.gd`: Turno de 900 s (15 min), bloqueo de órdenes en curso y persistencia Top 5 en `user://highscores.json`.
- `scripts/traffic_manager.gd`: Método `set_traffic_density(level)` para modular la cantidad de vehículos IA (Baja ~12, Normal ~24, Alta ~36).
- `scripts/hud.gd`: Menú Principal `alpha-0.0.2`, modal de manual de reparto, ventana de opciones, lista de récords y persistencia de configuración en `user://settings.json`.
- `scripts/game.gd`: Estado del menú principal, aplicación de settings y restricciones de navegación según modo.

---

## 4. Consecuencias y Beneficios

### Positivas
- **Inmersión inicial:** El jugador ingresa a un menú profesional con paneo nocturno en 360° sobre Ramos Mejía y tráfico circulando.
- **Competitividad y rejugabilidad:** El turno de 15 minutos, el spawn fijo en La Tanga, la prohibición del teletransporte y la tabla de récords persistente dotan al Modo Delivery de un ciclo de juego arcade completo.
- **Accesibilidad gráfica:** La opción de desactivar sombras soluciona el problema de titileo en PCs con placas de video modestas y permite ajustar la densidad vehicular según la CPU/GPU disponible.
- **Robustez de testing:** Las pruebas automatizadas `tools/test_map.gd` y `tools/test_density.py` siguen ejecutándose al 100% sin bloqueos.

---

## 5. Validación Técnica
- **Godot Headless Integration Test:** `.tools\Godot_v4.7.2-stable_win64_console.exe --headless --script tools/test_map.gd` $\rightarrow$ **0 fallos** (`MAP_QA failures=0`).
- **Python Density Test:** `python tools/test_density.py` $\rightarrow$ **0 fallos** (`DENSITY_QA_OK`).

# Roadmap del Proyecto · Ramos Mejía 3D

Este documento es la **bitácora viva** de planificación y seguimiento de tareas para agentes de IA y desarrolladores.  
Cada agente que tome o finalice una tarea debe actualizar el estado correspondiente aquí.

---

## 📌 Hito Actual: Sprint `alpha-0.0.2` (En Desarrollo)

- **Rama activa:** `feat/alpha-0.0.2`
- **Estado general:** En curso. Incorporando nuevas características y mejoras según prioridades del usuario.
- **Versión base cerrada:** [`alpha-0.0.1`](https://github.com/facundoraulbistolfi/ramos-delivery-simulator/releases/tag/alpha-0.0.1) *(Release publicada y descargable).*

---

## 🚀 Tareas del Sprint `alpha-0.0.2` (En Curso)

- [x] **Arquitectura de Capas Urbanas, Veredas Anulares y Contención de Manzanas:**
  - Partición booleana estricta: `Layer_Vias`, `Layer_Calles`, `Layer_Veredas`, `Layer_Lotes`, `Layer_Edificios`, `Layer_Mobiliario`.
  - Eliminación definitiva de veredas que suben al asfalto mediante anillos cerrados por manzana triangulados por ear-clipping estricto y cordones extruidos en la frontera real de calzada.
  - Recorte de edificios OSM desfasados para confinarlos dentro de la Línea Municipal con ochavas en esquinas, respetando retiros de frente en edificios reconocibles.
  - Normalización de anchos viales según jerarquía real de Ramos Mejía (Avenidas 13-18m, secundarias 10-12m, residenciales 8.5m).
  - *Referencia:* [ADR-0009: Arquitectura de Capas Urbanas, Veredas Anulares y Contención de Manzanas](adr/0009-arquitectura-de-capas-urbanas-y-veredas-anulares.md).
- [x] **Ajustes de Precisión Catastral, Fachadas Emblemáticas y Ruedas de Tráfico:**
  - Corrección de fachada de Coto Ramos Mejía: frente principal con marquesina y acceso peatonal sobre Av. Rivadavia (`normal: Z < 0`) y lateral con cartelería y estacionamiento sobre Pueyrredón (`normal: X < 0`).
  - Corrección física de ruedas en vehículos de tráfico (`traffic_vehicle.gd`): supresión de rotación local en mallas importadas que comparten pivote en el centro del chasis, eliminando la órbita aérea de las ruedas.
  - Reubicación catastral de locales gastronómicos e instituciones:
    - *El Muro de Ramos*: Viamonte 160 (entre San Martín y Pueyrredón, vereda oeste).
    - *Mostaza*: Belgrano 86 esq. Av. de Mayo (sobre Belgrano, vereda sur de números pares).
    - *Gallegol*: Mariano Moreno 298 esq. Belgrano (vereda oeste, una esquina antes hacia Rivadavia).
    - *Clöe Burger*: Bolívar 501 esq. Castelli (vereda este).
- [x] **Tráfico Barrial Continuo y Población Continua en Toda la Ciudad (`traffic_manager.gd`):**
  - Implementación de Grilla Espacial Hash 2D ($120\text{ m}$ por celda) para carriles de tránsito, eliminando la tasa del 88% de fallo de spawn.
  - Población continua de vehículos en barrios residenciales (objetivo de 30 vehículos) y mayor concentración en centro/avenidas (44 vehículos).
  - Generación de autos a lo largo de segmentos dentro de la ventana de visibilidad $[35, 150]\text{ m}$ respecto a la moto.
  - *Referencia:* [ADR-0010: Tráfico Barrial Continuo mediante Grilla Espacial y Repartos Combinados Multiparada](adr/0010-trafico-barrial-grilla-espacial-y-repartos-combinados.md).
- [x] **Cobertura de Pedidos en Todo el Mapa de Ramos Mejía (1.232 Direcciones Reales):**
  - Eliminación de la lista blanca de 25 calles y de los límites artificiales del centro, indexando las 818 calles transitables de la localidad.
  - Zonificación geográfica en cada entrega (*Ramos Centro, Ramos Norte, Ramos Sur, Ramos Oeste, Ramos Este*).
  - *Referencia:* [ADR-0010: Tráfico Barrial Continuo mediante Grilla Espacial y Repartos Combinados Multiparada](adr/0010-trafico-barrial-grilla-espacial-y-repartos-combinados.md).
- [x] **Sistema de Repartos Combinados Multiparada (2 Casas / Multi-Drop):**
  - Generador dinámico de 3 tiers de pedidos: Exprés/Cercano ($280-750\text{ m}$), Larga Distancia ($1.000-2.400\text{ m}$) y Reparto Combinado (2 Casas, $+35\%$ bono combo, $\$6.500-\$11.500+$).
  - Flujo de doble parada con pago parcial intermedio ($40\%$ al entregar la primera casa, $60\%$ restante con combo al completar la segunda).
  - Interfaz dedicada en tarjetas de pedido (borde y tipografía dorada) y seguimiento en HUD (`ENTREGA 1 DE 2`, aviso de próxima parada y cliente esperando en vereda).
  - *Referencia:* [ADR-0010: Tráfico Barrial Continuo mediante Grilla Espacial y Repartos Combinados Multiparada](adr/0010-trafico-barrial-grilla-espacial-y-repartos-combinados.md).
- [x] **Menú Principal Inicial con Fondo 3D Animado (`alpha-0.0.2`):**
  - Cámara cinemática orbital (`MotoChaseCamera.cinematic_mode`) con giro panorámico continuo de 360° sobre el centro iluminado de Ramos Mejía (La Tanga / Av. de Mayo) con tráfico en movimiento.
  - Presentación estilizada de "DELIVERY SIMULATOR", versión `alpha-0.0.2` y tres opciones directas: Modo Delivery, Modo Libre y Opciones (`[1]`, `[2]`, `[3]`, `[ESC]`).
  - *Referencia:* [ADR-0008: Menú Principal, Manual de Delivery, Turno de 15 Minutos, Podio de Récords y Opciones](adr/0008-menu-principal-modos-y-configuracion.md).
- [x] **Modo Delivery Arcade & Turno de 15 Minutos:**
  - Manual de instrucciones previo al inicio ("Manual del Repartidor") detallando reglas y penalizaciones.
  - Spawn fijo y obligatorio en «La Tanga de Ramos» (Rivadavia y Av. de Mayo).
  - Turno cronometrado de 15 minutos exactos (`900.0 s`).
  - Bloqueo estricto de teletransporte (`[TAB]`) y atajos rápidos a edificios.
  - Bloqueo de cancelación/cambio de orden una vez aceptado un pedido.
  - Podio histórico de los 5 mejores puntajes (Highscores) guardado en disco (`user://highscores.json`).
  - *Referencia:* [ADR-0008: Menú Principal, Manual de Delivery, Turno de 15 Minutos, Podio de Récords y Opciones](adr/0008-menu-principal-modos-y-configuracion.md).
- [x] **Menú de Opciones y Configuración Persistente:**
  - Pantalla completa toggleable (`DisplayServer.window_set_mode`).
  - Sombras dinámicas activables/desactivables (soluciona titileos y optimiza rendimiento en GPUs integradas).
  - Selector de densidad de tráfico (Baja ~12, Normal ~24, Alta ~36 autos).
  - Controles de volumen con sliders: Maestro, Efectos (SFX) y Ambiente.
  - Guardado y carga automática en `user://settings.json`.
  - *Referencia:* [ADR-0008: Menú Principal, Manual de Delivery, Turno de 15 Minutos, Podio de Récords y Opciones](adr/0008-menu-principal-modos-y-configuracion.md).
- [x] **Sistema de Acrobacias en Moto Estilo GTA, Medidor de Aura y Multiplicador de Puntaje Final:**
  - Física arcade de trucos inspirada en *GTA: Vice City* y *San Andreas*: **Willy** (`[Q]`/`[CTRL]`), **Stoppie / Invertido** (`[E]`/`[X]`), **Saltos Acrobáticos**, **Backflips**, **Frontflips**, **Giros 180°/360°** y cadenas de **Combo**.
  - Pivotes matemáticos exactos en el contacto de cada rueda (`Y = 0`), chispas de roce al límite del ángulo y secuencia física de **caída (wipeout)** con recuperación automática al pasarse de rosca, aterrizar mal o chocar en plena pirueta.
  - 5 rampas acrobáticas urbanas (`custom/props/rampa_acrobatica.tscn`) en capa custom desacoplada con aislamiento de colisión para no bloquear el tráfico IA.
  - **Medidor de Aura (`0–1000`)** con 5 rangos callejeros en HUD, banner de acrobacias en tiempo real y multiplicador de **Puntaje Final** de `x1.00` a `x2.00` (`+100%`) registrado en el podio de récords.
  - *Referencia:* [ADR-0011: Sistema de Acrobacias en Moto Estilo GTA, Medidor de Aura y Multiplicador de Puntaje Final](adr/0011-sistema-acrobacias-moto-y-bonificador-aura.md).

---

## 📌 Próximas Tareas del Backlog para Continuar el Sprint:
1. **Audio y SFX:** Motor de la moto según aceleración/velocidad, bocina, choques y ambiente urbano.
2. **Peatones en Veredas:** Transeúntes caminando por veredas comerciales y cruces peatonales.
3. **Clima Dinámico:** Alternancia nocturna con lluvia, charcos y reflejos en asfalto.
4. **Motos & Personalización:** Modelos adicionales de moto o casco.

---

## ✅ Funcionalidades Completadas y Validadas (Base alpha-0.0.1)

- [x] **Pipeline GIS de Ramos Mejía (8,11 km², 577 manzanas):**
  - Malla vial OSM completa, vías del FF.CC. Sarmiento, puentes vehiculares (Díaz Vélez, Papa Francisco) y peatonal (Pepino Tuccio).
  - Cruces a nivel cerrados con laberintos peatonales y barreras ferroviarias.
  - *Referencia:* [ADR-0001: Sistema de Coordenadas y Pipeline GIS](adr/0001-sistema-de-coordenadas-y-pipeline-gis.md).
- [x] **HUD Desacoplado & Plano de Calles Orientado al Norte:**
  - Panel izquierdo de órdenes (`OrderPanel`) y panel derecho de estado (`StatusPanel`).
  - Plano vectorial interactivo a pantalla completa (`[M]`) con bloqueo de controles de manejo.
  - Selector de teletransporte rápido (`[TAB]`) a 39 puntos clave.
  - *Referencia:* [ADR-0002: Arquitectura del HUD y Plano de Calles](adr/0002-arquitectura-hud-y-mapa-norte.md).
- [x] **Economía de Delivery y Misiones («Ir a Ojo»):**
  - Turno nocturno de 10 minutos con catálogo de más de 30 locales gastronómicos reales.
  - Elección entre 3 pedidos simultáneos, tiempos de cocina y bonificación de propinas por tiempo PAR.
  - Caja térmica 3D montada en la moto y clientes esperando en vereda.
  - *Referencia:* [ADR-0003: Sistema de Misiones de Reparto](adr/0003-sistema-misiones-reparto-y-economia.md).
- [x] **Capa de Assets Personalizados y Overlays:**
  - Desacople entre mapa base procedural y capa custom para evitar pérdidas al regenerar el mapa.
  - Inclusión de la Estatua de Manuel Belgrano con colisiones físicas en Plazoleta Belgrano.
  - *Referencia:* [ADR-0004: Desacople de Assets y Overlays](adr/0004-desacople-de-assets-y-decoraciones-custom.md).
- [x] **Ambientación Nocturna & Carteles Nomencladores:**
  - Luminarias de calle y luces cálidas en comercios.
  - Carteles nomencladores azules de esquina estilo La Matanza (postes dobles con flechas y alturas).
  - Faros delanteros (`SpotLight3D`) de la moto iluminando el asfalto.
- [x] **Tráfico Vehicular Dirigido & Autos Estacionados:**
  - Más de 500 autos estacionados a los cordones respetando el gálibo de circulación.
  - Flota de vehículos IA circulando según la mano de las calles, con sensores de frenado.
  - Luces de giro (guiños ámbar) activadas con 90% de probabilidad 45 m antes de las esquinas.
  - *Referencia:* [ADR-0005: Sistema de Tráfico Dirigido y Autos Estacionados](adr/0005-sistema-trafico-dirigido-y-autos-estacionados.md).
- [x] **Selector de Modo Inicial & Penalización por Choques:**
  - Diálogo al inicio con teclado (`[1]`/`[2]`): Modo Delivery vs Modo Libre / Debug.
  - En Modo Delivery: choques contra autos descuentan plata según la velocidad de impacto (leves: $350-$650, moderados: $700-$1950, graves: >$2000).
  - Resumen de jornada con reporte de multas y alternancia en caliente desde menú de pausa (`[ESC]`).
  - *Referencia:* [ADR-0006: Selección Inicial de Modo y Multas por Choque](adr/0006-seleccion-modo-juego-y-penalizacion-choques.md).
- [x] **Arquitectura "Agent-First" y Documentación Formal:**
  - Creación de `AGENTS.md`, `docs/adr/` (ADR-0001 a 0006 + plantilla), regla `.gemini/rules/agent_rules.md` y este roadmap.
- [x] **Sistema de Versionado y Generador de Builds (`alpha-0.0.1`):**
  - Script automatizado `tools/build_release.ps1` con Test Gate, compilación de PCK y generación de ZIP autónomo.
  - Preset de exportación `export_presets.cfg` y workflow `.github/workflows/release.yml`.
  - Primera versión distribuible `alpha-0.0.1` generada en `builds/`.
  - *Referencia:* [ADR-0007: Sistema de Versionado Semántico y Pipeline de Builds](adr/0007-sistema-de-versionado-y-builds.md).

---

## 🎯 Próximas Tareas Prioritarias (En Backlog)

1. **Audio y Ambientación Sonora:**
   - [ ] Sonido de motor de la moto con modulación de pitch según RPM/velocidad.
   - [ ] Efectos de sonido (SFX): aceleración, frenado, choque metálico contra autos, bocina y caja térmica.
   - [ ] Ambiente nocturno de fondo: murmullo urbano, viento y cruce de tren en pasos a nivel.
2. **Peatones en Veredas y Cruces:**
   - [ ] Sistema de transeúntes caminando por las veredas en zonas comerciales (Av. de Mayo y Rivadavia).
   - [ ] Cruce de peatones por las sendas peatonales con respuesta de frenado del tráfico.
3. **Clima Dinámico / Lluvia:**
   - [ ] Alternancia entre noche despejada y lluvia nocturna con asfalto reflectante y pérdida de agarre en neumáticos.
4. **Personalización del Repartidor y la Moto:**
   - [ ] Selección de modelo de moto (110cc urbana vs 150cc clásica).
   - [ ] Colores de moto y casco.

---

## 📋 Instrucciones para los Agentes
1. Al comenzar una tarea, mover el ítem a la sección "En Curso".
2. Al finalizar la tarea y pasar los tests (`test_map.gd` y `test_density.py` con 0 errores):
   - Marcar el ítem como completado `[x]`.
   - Si introdujiste un cambio arquitectónico nuevo, redactar el `ADR-NNNN` correspondiente y vincularlo en este archivo.

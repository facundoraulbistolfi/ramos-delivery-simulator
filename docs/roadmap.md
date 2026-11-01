# Roadmap del Proyecto · Ramos Mejía 3D

Este documento es la **bitácora viva** de planificación y seguimiento de tareas para agentes de IA y desarrolladores.  
Cada agente que tome o finalice una tarea debe actualizar el estado correspondiente aquí.

---

## 📌 Hito Actual: Sprint `alpha-0.0.2` (En Desarrollo)

- **Rama activa:** `feat/alpha-0.0.2`
- **Estado general:** En curso. Incorporando nuevas características y mejoras según prioridades del usuario.
- **Versión base cerrada:** [`alpha-0.0.1`](https://github.com/facundoraulbistolfi/ramos-delivery-simulator/releases/tag/alpha-0.0.1) *(Release publicada y descargable).*

---

## 🚀 Tareas del Sprint `alpha-0.0.2` (En Curso / Selección de Alcance)

A definir según requerimientos del usuario en este ciclo. Ideas prioritarias del backlog:
1. **Audio y SFX:** Motor de la moto según aceleración/velocidad, bocina, choques y ambiente nocturno.
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

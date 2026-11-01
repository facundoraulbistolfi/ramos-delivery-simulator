# ADR-0003: Sistema de Misiones de Reparto («Ir a Ojo») y Economía de Turno Nocturno

- **Estado:** Aceptado
- **Fecha:** 2026-10-31
- **Autores / Decisores:** Usuario / Agente Antigravity

---

## 1. Contexto y Problemática
El juego requería una dinámica central atractiva que aprovechara la escala completa de Ramos Mejía. Se buscó simular la experiencia de un repartidor nocturno de aplicaciones (tipo PedidosYa / Rappi), pero preservando una premisa fundamental: **«Navegación a ojo»**, es decir, sin líneas fluorescentes en el piso ni flechas que te lleven solo; el jugador debe leer las alturas de las calles y guiarse por las referencias urbanas.

---

## 2. Decisión Tomada
1. **Turno de 10 minutos (600 segundos):**
   - El objetivo es maximizar el dinero recaudado en la billetera antes de que termine la jornada.
2. **Selección de inicio de turno:**
   - El jugador elige entre 6 puntos estratégicos (Plaza Sarmiento, Av. de Mayo, Av. Rivadavia y Moreno, Plaza Mitre, Plaza Bomberitos, Puente Díaz Vélez).
3. **Ofertas simultáneas (3 pedidos a elección):**
   - Cada ciclo presenta 3 pedidos generados dinámicamente con locales reales (La Farola, Wendy's, El Club de la Milanesa, Heladerías, Farmacias, etc.).
   - Se indican distancia estimada, producto a transportar, valor en pesos, tarifa base y propina máxima.
4. **Mecánica de preparación en cocina y Tiempo PAR:**
   - Mientras el local cocina el pedido (prep time), el repartidor viaja al restaurante. Si llega antes de que esté listo, espera en la puerta.
   - Una vez listo en cocina, comienza a correr el **Tiempo PAR** hacia la dirección del cliente.
   - Si entrega antes del tiempo PAR, cobra el 100% de la propina estimada. Si se demora, la propina decae proporcionalmente por segundo de retraso.
5. **Caja térmica 3D y clientes en vereda:**
   - Al retirar en el restaurante, aparece una caja térmica (`DeliveryCargoBox`) montada en la parrilla trasera de la moto.
   - En el punto de entrega, se genera un modelo 3D de cliente saludando en la vereda junto al anillo de parada.

---

## 3. Archivos y Subsistemas Afectados
- `scripts/mission_system.gd`: Lógica completa de estados (`PICKUP`, `DELIVER`, `ORDER_SELECTION`, `START_SELECTION`, `SHIFT_SUMMARY`), catálogo de locales y direcciones calculadas a partir de la red vial OSM.
- `scripts/hud.gd`: Diálogos modales interactivos para selección de punto de inicio, selección de pedido entre 3 opciones y resumen final con desglose económico.
- `scenes/bike.tscn`: Sub-nodo de caja térmica en el modelo visual de la moto.

---

## 4. Consecuencias y Trade-offs

### Positivas
- Ciclo de juego variado y rejugable con más de 30 locales gastronómicos y cientos de combinaciones de direcciones reales.
- El tiempo PAR y la propina variable generan tensión y recompensa por conocer el mapa y no chocar.
- Resumen económico al finalizar los 10 minutos con métricas claras de desempeño.

### Negativas / Limitaciones Aceptadas
- En modo headless (tests automatizados), la espera de preparación en cocina se fuerza a 0 segundos para que las aserciones de prueba ejecuten de forma instantánea.

---

## 5. Validación y Pruebas Automatizadas
- `tools/test_map.gd`:
  - `check(int(ms.get("state")) == MissionSystem.State.PICKUP, "mission system starts in pickup state")`
  - `check(int(ms.get("state")) == MissionSystem.State.DELIVER, "visiting locale picks up order and advances to delivery state")`
  - `check(int(ms.get("completed_count")) >= 1, "visiting destination address completes delivery mission")`

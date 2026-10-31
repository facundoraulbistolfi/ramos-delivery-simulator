# Ramos Mejía · Motos 3D

Mapa de **Ramos Mejía**, con eje en **Avenida Rivadavia (entre Larrea y Necochea)** y cobertura completa del **polígono de 7 calles** conformado por **Díaz Vélez (y República hasta Gaona), Av. Gaona, Güemes, Av. de Mayo, Alvarado, Viamonte y Juan T. Pizzurno**. **Godot 4.4 o superior**, GDScript y renderizador Compatibility. Escala: **1 unidad = 1 metro**.

## Abrir y jugar

En esta maquina, hace doble clic en **Abrir editor.cmd** para abrir el proyecto con la copia local de Godot 4, o en **Jugar.cmd** para jugar directamente. Godot 3.3.4 no puede abrir este proyecto.

1. Abrí Godot 4, elegí **Importar** y seleccioná `project.godot`.
2. Presioná **F6** para ejecutar la escena abierta o **F5** para ejecutar el proyecto completo.

En esta máquina también podés usar la copia portátil local de Godot:

```powershell
powershell -ExecutionPolicy Bypass -File .\run.ps1
powershell -ExecutionPolicy Bypass -File .\run.ps1 -Editor
```

La copia del motor en `.tools/` queda fuera de Git. No hay dependencias, plugins ni assets que descargar para el juego.

## Controles

| Tecla | Acción |
| --- | --- |
| W / ↑ | Acelerar |
| S / ↓ | Frenar; mantener detenido para marcha atrás |
| A, D / ←, → | Girar |
| Shift | Turbo; se recarga al soltar |
| Espacio | Derrape |
| R | Volver a Larrea y reiniciar el recorrido |
| C | Alternar distancia de la cámara |
| T | Ir a Avenida de Mayo, frente a La Tanga |
| 1 | Visitar Casa Hospital San Juan de Dios |
| 2 | Visitar Coto de Rivadavia y Pueyrredón |
| 3 | Visitar La Perla de Rivadavia y Avenida de Mayo |
| Esc | Pausar / continuar |

## Incluye

- Moto y piloto de geometría simple, ruedas animadas e inclinación al girar.
- Control arcade con gravedad, colisiones, turbo, derrape y penalización de velocidad fuera del asfalto.
- Cámara de seguimiento con dos distancias y prevención de obstáculos.
- Tramo de unos **1.648 metros**, con las curvas, calzadas separadas, cruces y distancias de OpenStreetMap.
- Red ampliada de **199 tramos de calles**, 100 manzanas urbanas completas en el polígono **Díaz Vélez – Gaona – Güemes – Av. de Mayo – Alvarado – Viamonte – Juan T. Pizzurno** (más el corredor de Rivadavia hasta Necochea), vías y andenes del Sarmiento y espacios verdes.
- **320 edificios con huellas de OSM** y **5.903 volúmenes genéricos** de frentes e interiores de manzana, con 125 pasajes públicos preservados. Los volúmenes cierran los huecos privados y tienen colisión; no representan edificios individualmente relevados.
- Tres edificios reconocibles con arquitectura propia: San Juan de Dios (conjunto blanco, bandas de ventanas, guardia, palmeras y jardines), Coto (cartelería roja, vidrieras, entrada y frente lateral sobre Pueyrredón) y La Perla (ochava vidriada, toldos verdes, letras y mesas exteriores). Las variantes conservan las huellas de los edificios, con alturas y detalles aproximados.
- Veredas, señalización, pasos peatonales, locales genéricos, árboles, luminarias y refugios de colectivos.
- Circulación libre: se retiraron los límites invisibles y los cierres laterales. Todos los edificios, incluidos los de relleno, tienen colisión. Un plano físico infinito evita caídas fuera del área modelada.
- Manzanas privadas continuas: se completan los centros y los huecos entre construcciones con casas, volúmenes y medianeras visibles. Se conservan los pasajes exteriores cartografiados, las plazas, las veredas y los accesos a los edificios reconocibles. El predio del hospital conserva sus jardines y tiene cerramiento perimetral con entradas.
- La Tanga: plazoleta triangular frente a Av. de Mayo y Rivadavia, cantero de OSM, basamento, letras corpóreas de bienvenida, bancos y luminarias. T permite visitarla directamente.
- Calzadas más amplias que contemplan espacio junto al cordón y estacionamiento: Rivadavia separada de 8,5 m por mano, frente a la estación de 12 m, calzada compartida de 13–18 m; Av. de Mayo hasta 15–18 m. Son estimaciones de modelado, no mediciones en campo.
- HUD con metros recorridos, calle actual, cronómetro, velocímetro, turbo y pausa.
- El mapa está guardado como escena y se ve directamente en el editor.

La fidelidad de esta versión está en la **planta y la escala**. Las manzanas se seleccionan a partir de las caras cerradas del trazado de calles, no simplemente contando 100 m por cuadra. Los anchos sin medición incluyen una estimación de carriles y estacionamiento; las fachadas, la ubicación del mobiliario y parte de las alturas son aproximaciones. El terreno es plano. No incluye tráfico, peatones ni reproducción fotográfica de los comercios. Fuentes, licencia y límites de precisión en `assets/maps/SOURCES.md`.

## Estructura

```text
project.godot              Configuración y escena de inicio
scenes/main.tscn           Mundo, iluminación, pista, cámara e interfaz
scenes/ramos_mejia.tscn    Mapa persistente y visible en el editor
scenes/bike.tscn           Moto y piloto editables
scripts/bike.gd            Física y parámetros de conducción
scripts/track.gd           Consulta de calzadas, distancias y cruces
scripts/chase_camera.gd    Cámara de seguimiento
scripts/game.gd            Entradas, recorrido libre y reinicio
scripts/hud.gd             Interfaz y pausa
assets/icon.svg            Ícono del proyecto
assets/maps/              Datos métricos, fuente OSM y atribución
tools/prepare_ramos_map.py Extracción geográfica reproducible
tools/build_ramos_map.gd   Generador de la escena persistente
tools/expand_neighborhood.py Selección de manzanas y relleno de frentes
tools/neighborhood_geometry.gd Calles ampliadas, edificios y La Tanga
tools/recognizable_buildings.py Vinculación de los tres edificios con OSM
tools/recognizable_buildings.gd Fachadas y arquitectura de los tres edificios
tools/block_density.py     Cierre de huecos y reserva de plazas y pasajes
tools/test_map.gd          Pruebas de escala, recorrido y límites
tools/test_density.py      Pruebas geométricas de cierre de manzanas
```

Para ajustar la conducción, seleccioná `Moto` y modificá las propiedades exportadas del script. Para editar el entorno, abrí `scenes/ramos_mejia.tscn`. La geometría está agrupada por material para reducir las llamadas de dibujo.

Para regenerar el mapa con los mismos datos, instalá primero las dependencias de geometría (solo se necesitan para reconstruir datos; el juego no las necesita). En esta máquina ya están en `.tools/gis_libs`.

```powershell
python -m pip install --target .tools/gis_libs -r tools/requirements-map.txt
```

Luego se puede reconstruir sin conexión:

```powershell
python tools/prepare_ramos_map.py
.tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tools/build_ramos_map.gd
python tools/test_density.py
.tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . --fixed-fps 60 --script tools/test_map.gd
```

Es un punto de partida de conducción arcade: la moto usa `CharacterBody3D` y una inclinación visual, sin simulación física de equilibrio o suspensión.

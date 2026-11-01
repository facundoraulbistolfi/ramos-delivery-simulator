# 🏙️ Guía de Assets Personalizados y Nivel Modular de Ramos Mejía

Bienvenido a la carpeta de assets personalizados. Todo lo que crees o modifiques dentro de `res://custom/` es **100% independiente de los scripts procedurales**: podés trabajar en Blender y en Godot a la par sin riesgo de que ningún script sobreescriba tu trabajo.

---

## 📁 Estructura de Carpetas

```text
res://custom/
├── buildings/         <- Modelos 3D (.glb, .gltf, .tscn) que reemplazan edificios/locales
├── props/             <- Modelos sueltos de mobiliario urbano, monumentos y vegetación
├── decorations.tscn   <- Escena de nivel visual donde colocás y ordenás props con el mouse
└── README.md          <- Esta guía de referencia
```

---

## 🎨 1. Cómo decorar la ciudad visualmente (Props, Bancos, Farolas, Estatuas)

1. En Godot, hacé doble clic en [custom/decorations.tscn](file:///c:/Users/facun/game_maps/custom/decorations.tscn).
2. Vas a ver la ciudad entera y las plazas cargadas en 3D bajo tus pies como referencia visual (el nodo `ReferenceMap_SoloEditor` está bloqueado para que no lo muevas por error).
3. Creá o importá tus modelos en `res://custom/props/` (por ejemplo: `res://custom/props/estatua_belgrano.tscn`).
4. Arrastrá tu prop desde el panel de archivos de Godot directamente a la vereda o plaza en el viewport 3D.
5. Usá las herramientas clásicas de Godot para posicionarlo:
   - **W**: Mover (gizmo de flechas)
   - **E**: Rotar
   - **R**: Escalar
6. Guardá con **Ctrl + S**.
7. ¡Listo! Al presionar **F5** (o ejecutar [Jugar.cmd](file:///c:/Users/facun/game_maps/Jugar.cmd)), tus objetos aparecerán exactamente donde los pusiste.

> [!NOTE]
> El mapa de referencia (`ReferenceMap_SoloEditor`) solo existe en el Editor de Godot. Al iniciar el juego real se auto-elimina instantáneamente para no consumir memoria ni duplicar geometría.

---

## 🏬 2. Cómo reemplazar un Local Comercial o Edificio Emblemático (Auto-Override)

Si modelás una pizzería, hamburguesería o un supermercado en Blender:

1. Exportalo como `.glb` (o `.gltf` / `.tscn`).
2. Guardalo en `res://custom/buildings/` con el nombre clave del edificio.
   * *Ejemplo*: `coto.glb`, `la_perla.glb`, `apolonia.tscn`, `due.glb`, etc.
3. El juego automáticamente:
   - Detecta el archivo al arrancar.
   - Oculta la fachada y cartel procedural anterior.
   - Enchufa tu modelo en el frente de la vereda con la rotación y orientación de la calle exacta.

### 🛡️ Colisiones Automáticas Inteligentes
- Si tu modelo 3D ya tiene colisiones creadas en Blender o Godot (`StaticBody3D` o sufijo `-col`), las respeta.
- Si es un modelo visual simple (un `.glb` recién exportado sin colisiones), el juego le genera una colisión sólida automática para que la moto no lo atraviese.

### 📍 Punto de Retiro de Delivery (`Pickup` / `Entrada`)
Si querés que el marcador de pedidos de delivery aparezca justo en la puerta de tu local:
- Agregá un `Node3D` hijo adentro de tu modelo llamado **`Pickup`** o **`Entrada`** ubicado en el umbral de la puerta.
- El sistema de misiones detectará ese nodo y colocará el aro luminoso y cartel del pedido exactamente en ese punto.
- Si no agregás ese nodo, el marcador se ubica automáticamente en la vereda frente al local.

---

## 🏷️ Lista de Claves de Edificios y Locales

### Edificios Emblemáticos
| Clave del Archivo | Nombre Real | Ubicación |
| :--- | :--- | :--- |
| `coto.glb` | Supermercado COTO | Av. Rivadavia y Av. de Mayo |
| `la_perla.glb` | Confitería La Perla | Av. Rivadavia y Av. de Mayo |
| `san_juan.glb` | Hospital San Juan de Dios | Av. de Mayo e Iannone |
| `estacion_ramos.glb`| Estación Ramos Mejía | Andén FF.CC. Sarmiento / Rivadavia |

### Locales Gastronómicos y Comerciales
| Clave del Archivo | Local | Especialidad / Dirección |
| :--- | :--- | :--- |
| `apolonia.glb` | Apolonia Pizza & Pasta | Espora 261 |
| `due.glb` | Due Café & Brunch | Av. de Mayo 298 |
| `faricci.glb` | Heladería Faricci | Rosales y Av. de Mayo |
| `faricci_san_martin.glb` | Faricci San Martín | Av. San Martín 150 |
| `luccianos.glb` | Lucciano's Il Maestro del Gelato | Av. de Mayo 335 |
| `banned_burger.glb` | Banned Burger | Necochea y Rivadavia |
| `cloe_burger.glb` | Clöe Burger & Bakery | Rosales 120 |
| `la_birra_bar.glb` | La Birra Bar | Av. Rivadavia 14100 |
| `club_milanesa.glb` | El Club de la Milanesa | Av. de Mayo 390 |
| `mostaza_mayo.glb` | Mostaza | Av. de Mayo 115 |
| `wendys_kfc.glb` | Wendy's & KFC | Av. de Mayo 220 |
| `starbucks_cuspide.glb` | Starbucks & Cúspide Libros | Av. de Mayo 260 |
| `la_farola.glb` | La Farola Express | Rosales 210 |
| `la_tanita.glb` | La Tanita Trattoria | Güemes y Espora |
| `parrilla_la_tanita.glb` | Parrilla La Tanita | Av. de Mayo 450 |
| `la_buena_fama.glb` | Fábrica de Pastas La Buena Fama | Espora 180 |
| `samurai_sushi.glb` | Samurai Sushi Nikkei | Rosales 145 |
| `otaku_sushi.glb` | Otaku Sushi | Av. de Mayo 520 |
| `arezzo_resto.glb` | Arezzo Ristorante | Alsina 130 |
| `almacen_freddo.glb` | Almacén de Pizzas & Freddo | Av. de Mayo 380 |
| `heladeria_tempo.glb` | Heladería Tempo | Av. Rivadavia 14250 |
| `subway_rivadavia.glb` | Subway Rivadavia | Av. Rivadavia 14150 |
| `bonafide_rivadavia.glb` | Bonafide | Av. Rivadavia 14180 |
| `fravega.glb` | Frávega Ramos Mejía | Av. Rivadavia 14050 |
| `sporting_rivadavia.glb` | Sporting Deportes | Av. Rivadavia 14200 |
| `paseo_ramos.glb` | Galería Paseo Ramos | Av. Rivadavia 14080 |
| `galeria_central.glb` | Galería Central | Av. Rivadavia 14120 |
| `central_oeste_rivadavia.glb` | Central Oeste Rivadavia | Av. Rivadavia 14300 |
| `farmacia_central_oeste.glb` | Farmacia Central Oeste | Av. de Mayo 310 |
| `farmacia_central_oeste_centro.glb` | Central Oeste 24 hs | Belgrano y Av. de Mayo |
| `farmacia_moreno.glb` | Farmacia Moreno | Moreno y Rivadavia |
| `sportclub.glb` | SportClub Ramos Mejía | Av. de Mayo 650 |
| `bomberitos.glb` | Buffet Club Bomberitos | Gral. Acha y Pueyrredón |
| `cuartel_bomberos.glb` | Cuartel Central de Bomberos | Suipacha y Moreno |
| `la_casa_de_oberon.glb` | La Casa de Oberón Casa de Té | Rosales 280 |
| `antojos.glb` | Pastelería Antojos Sin TACC | Alsina 210 |
| `gallegol.glb` | Golosinas Gallegol | Rosales 90 |
| `kinderland.glb` | Jugueterías Kinderland | Av. de Mayo 410 |

---

## 🗿 3. Ejemplo Listo: Estatua del General Manuel Belgrano

Ya se encuentra modelada e instalada la **Estatua del General Manuel Belgrano**:
- Archivo fuente: [custom/props/estatua_belgrano.tscn](file:///c:/Users/facun/game_maps/custom/props/estatua_belgrano.tscn)
- Ubicación: **Plazoleta General Manuel Belgrano** (Av. de Mayo y Belgrano / Pueyrredón).
- Cuenta con base de piedra escalonada, pedestal clásico, placa conmemorativa en relieve y busto en bronce con colisión física trimesh.
- Podés viajar directamente hasta ella presionando **TAB** en el juego y seleccionando *"Plazoleta Gral. Manuel Belgrano"*.

# ADR-0007: Sistema de Versionado Semántico y Pipeline de Builds

- **Estado:** Aceptado
- **Fecha:** 2026-11-01
- **Autores / Decisores:** Usuario / Agente Antigravity

---

## 1. Contexto y Problemática
A medida que el proyecto evoluciona y se orienta a una arquitectura Agent-First, se requiere un mecanismo estandarizado para:
1. Publicar versiones identificables y reproducibles (empezando por `alpha-0.0.1`).
2. Permitir que cualquier usuario o tester descargue y juegue el ejecutable directamente sin instalar el motor Godot, Python o librerías GIS.
3. Asegurar que ningún release se genere sin antes haber superado el Test Gate obligatorio (`test_map.gd` y `test_density.py`).
4. Automatizar la creación de GitHub Releases con ejecutables empaquetados.

---

## 2. Decisión Tomada
1. **Convención de Versionado:**
   - Formato semántico: `alpha-X.Y.Z` para la etapa temprana de desarrollo (`alpha-0.0.1` como versión fundacional).
   - Constante `GAME_VERSION = "alpha-0.0.1"` en `scripts/hud.gd` para reflejar la versión en pantalla, y `config/version="0.0.1-alpha"` en `project.godot`.
2. **Preset Oficial de Exportación (`export_presets.cfg`):**
   - Configuración oficial "Windows Desktop" exportando `RamosDeliverySimulator.pck` y vinculando el ejecutable `RamosDeliverySimulator.exe`.
3. **Pipeline Automatizado Local (`tools/build_release.ps1`):**
   - Ejecuta primero las suites de prueba en modo headless. Si hay fallos, aborta inmediatamente.
   - Empaqueta el PCK, copia el runner nativo de Windows, genera el script lanzador `Jugar Ramos Delivery.bat` y comprime todo en `builds/RamosDeliverySimulator-[Version]-windows.zip`.
4. **Publicación en GitHub (`.github/workflows/release.yml`):**
   - Workflow de GitHub Actions que responde al empuje de tags (`alpha-*` o `v*`) y publica automáticamente la Release con notas de cambios e instrucciones de descarga.

---

## 3. Archivos y Subsistemas Afectados
- `export_presets.cfg`: Preset de exportación de Godot 4.
- `tools/build_release.ps1`: Script PowerShell de automatización de builds.
- `.github/workflows/release.yml`: Acción de GitHub para publicación continua.
- `project.godot`: Declaración formal de versión y nombre del producto.
- `scripts/hud.gd`: Constante `GAME_VERSION` e indicador visual en interfaz.
- `.gitignore`: Asegura que `builds/` quede excluido de Git para no inflar el repositorio con binarios compilados.

---

## 4. Consecuencias y Trade-offs

### Positivas
- Generación de ejecutables 100% autónomos en un solo comando (`.\tools\build_release.ps1 -Version "alpha-0.0.1"`).
- Imposible generar un release con regresiones físicas o de mapa gracias al Test Gate previo.
- Distribución limpia a través de GitHub Releases y archivos `.zip`.

### Negativas / Limitaciones Aceptadas
- La exportación inicial del PCK de 8,11 km² toma alrededor de 45 segundos y genera un ZIP de ~144 MB debido a las geometrías de las 577 manzanas.

---

## 5. Validación y Pruebas Automatizadas
- `tools/build_release.ps1 -Version "alpha-0.0.1"`:
  - `MAP_QA failures=0`
  - `DENSITY_QA_OK`
  - Creación exitosa de `builds/RamosDeliverySimulator-alpha-0.0.1-windows.zip` (144,55 MB).
  - Verificación del ejecutable standalone `RamosDeliverySimulator.exe --headless --quit-after 10` con código de salida 0.

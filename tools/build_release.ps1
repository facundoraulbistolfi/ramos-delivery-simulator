# Generador de Releases para Ramos Delivery Simulator
param(
    [string]$Version = "alpha-0.0.1",
    [switch]$SkipTests,
    [switch]$CreateTag
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ("   RAMOS DELIVERY SIMULATOR - RELEASE {0}" -f $Version) -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Localizar binarios de Godot y Python
$godotConsole = Join-Path $projectRoot ".tools\Godot_v4.7.2-stable_win64_console.exe"
$godotRunner = Join-Path $projectRoot ".tools\Godot_v4.7.2-stable_win64.exe"
$pythonExe = "C:\Users\facun\AppData\Local\Programs\Python\Python39\python.exe"
if (-not (Test-Path $pythonExe)) {
    $pythonCmd = Get-Command python, py -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($pythonCmd) { $pythonExe = $pythonCmd.Source }
}

if (-not (Test-Path $godotConsole) -or -not (Test-Path $godotRunner)) {
    throw "No se encontraron los ejecutables de Godot en .tools/."
}

# 2. Test Gate Obligatorio
if (-not $SkipTests) {
    Write-Host "`n[1/4] Ejecutando Test Gate obligatorio..." -ForegroundColor Yellow
    
    Write-Host " -> Test 1: Simulacion y fisicas de mapa (test_map.gd)..." -ForegroundColor Gray
    & $godotConsole --headless --script tools/test_map.gd
    if ($LASTEXITCODE -ne 0) {
        throw ("FALLO test_map.gd con codigo de salida: {0}" -f $LASTEXITCODE)
    }

    if (Test-Path $pythonExe) {
        Write-Host " -> Test 2: Integridad de manzanas (test_density.py)..." -ForegroundColor Gray
        & $pythonExe tools/test_density.py
        if ($LASTEXITCODE -ne 0) {
            throw ("FALLO test_density.py con codigo de salida: {0}" -f $LASTEXITCODE)
        }
    }
    Write-Host " -> Test Gate superado con 0 fallos." -ForegroundColor Green
} else {
    Write-Host "`n[1/4] Test Gate omitido por parametro -SkipTests." -ForegroundColor Magenta
}

# 3. Preparar directorios de build
Write-Host "`n[2/4] Preparando entorno de compilacion..." -ForegroundColor Yellow
$buildsDir = Join-Path $projectRoot "builds"
$windowsDir = Join-Path $buildsDir "windows"

if (Test-Path $windowsDir) {
    Remove-Item -Path $windowsDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $windowsDir | Out-Null

# 4. Exportar paquete PCK y vincular runner ejecutable
Write-Host "`n[3/4] Exportando PCK compilado con Godot Headless..." -ForegroundColor Yellow
$pckOutput = Join-Path $windowsDir "RamosDeliverySimulator.pck"
& $godotConsole --headless --export-pack "Windows Desktop" $pckOutput
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $pckOutput)) {
    throw "Error al exportar el archivo PCK con Godot."
}

Write-Host " -> Vinculando ejecutable de Windows (RamosDeliverySimulator.exe)..." -ForegroundColor Gray
$exeOutput = Join-Path $windowsDir "RamosDeliverySimulator.exe"
Copy-Item -Path $godotRunner -Destination $exeOutput -Force

# Acceso directo / lanzador
$launcherContent = "@echo off`r`nstart """" ""%~dp0RamosDeliverySimulator.exe"""
Set-Content -Path (Join-Path $windowsDir "Jugar Ramos Delivery.bat") -Value $launcherContent -Encoding ASCII

# Archivo LEEME
$infoContent = "Ramos Delivery Simulator - $Version`r`nDesarrollado para Windows x86_64`r`nGodot Engine 4.7.2 - Render Compatibility`r`n`r`nPara jugar, hace doble clic en 'RamosDeliverySimulator.exe' o en 'Jugar Ramos Delivery.bat'."
Set-Content -Path (Join-Path $windowsDir "LEEME.txt") -Value $infoContent -Encoding ASCII

# 5. Generar archivo comprimido ZIP
Write-Host "`n[4/4] Creando archivo distribuible comprimido (.zip)..." -ForegroundColor Yellow
$zipOutput = Join-Path $buildsDir ("RamosDeliverySimulator-{0}-windows.zip" -f $Version)
if (Test-Path $zipOutput) {
    Remove-Item $zipOutput -Force
}

Compress-Archive -Path "$windowsDir\*" -DestinationPath $zipOutput -CompressionLevel Optimal

$zipSizeMb = [math]::Round((Get-Item $zipOutput).Length / 1MB, 2)
Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host ("   RELEASE {0} GENERADO CON EXITO!" -f $Version) -ForegroundColor Green
Write-Host ("   Archivo: {0} ({1} MB)" -f $zipOutput, $zipSizeMb) -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green

# 6. Crear tag en Git si se solicito
if ($CreateTag) {
    Write-Host "`nCreando tag en Git: $Version..." -ForegroundColor Cyan
    git tag -a $Version -m ("Release {0}" -f $Version)
    Write-Host "Para subir el tag a GitHub ejecuta:" -ForegroundColor Yellow
    Write-Host ("  git push origin {0}" -f $Version) -ForegroundColor White
}

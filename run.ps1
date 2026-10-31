param([switch]$Editor)

$ErrorActionPreference = 'Stop'
$projectDirectory = $PSScriptRoot
$portableGodot = Get-ChildItem -LiteralPath (Join-Path $projectDirectory '.tools') -Filter 'Godot_v4*win64.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
$godotCommand = Get-Command godot4, godot -ErrorAction SilentlyContinue | Select-Object -First 1

if ($portableGodot) {
    $executable = $portableGodot.FullName
} elseif ($godotCommand) {
    $executable = $godotCommand.Source
} else {
    throw 'No se encontró Godot 4. Importá project.godot en Godot 4.4 o superior: https://godotengine.org/download/windows/'
}

$godotVersion = (Get-Item -LiteralPath $executable).VersionInfo.ProductVersion
$versionMatch = [regex]::Match([string]$godotVersion, '^4\.(\d+)')
if (-not $versionMatch.Success -or [int]$versionMatch.Groups[1].Value -lt 4) {
    throw ('Este proyecto necesita Godot 4.4 o superior. Se encontro: {0}' -f $godotVersion)
}

$godotArguments = @('--path', ('"{0}"' -f $projectDirectory))
if ($Editor) { $godotArguments += '--editor' }
# The game/editor is an interactive window and must be visible.
Start-Process -FilePath $executable -ArgumentList $godotArguments -WindowStyle Normal

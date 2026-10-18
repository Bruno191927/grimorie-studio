# Script automatizado para compilar Grimoire Studio y generar el instalador Setup.exe
param (
    [switch]$SkipFlutterBuild
)

$ErrorActionPreference = "Stop"
# Ubicar la raíz del proyecto (4 niveles arriba desde .agent/skills/build-windows-executable/scripts)
$ProjectRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.Parent.FullName
Set-Location $ProjectRoot

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   Grimoire Studio - Generador de Instalador Windows     " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Compilar Flutter en modo Release
if (-not $SkipFlutterBuild) {
    Write-Host "`n[1/3] Compilando binarios de Flutter (Release x64)..." -ForegroundColor Yellow
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Error en la compilación de Flutter."
        exit $LASTEXITCODE
    }
} else {
    Write-Host "`n[1/3] Omitiendo compilación de Flutter (usando binarios existentes)..." -ForegroundColor Gray
}

# 2. Localizar o descargar compilador NSIS (makensis.exe)
Write-Host "`n[2/3] Localizando compilador NSIS (makensis.exe)..." -ForegroundColor Yellow
$makensis = $null
$possiblePaths = @(
    "makensis",
    "C:\Program Files (x86)\NSIS\makensis.exe",
    "C:\Program Files\NSIS\makensis.exe",
    "$env:TEMP\nsis\nsis-3.10\makensis.exe",
    "$env:TEMP\nsis\nsis-3.13\makensis.exe"
)

foreach ($p in $possiblePaths) {
    if (Get-Command $p -ErrorAction SilentlyContinue) {
        $makensis = (Get-Command $p).Source
        break
    } elseif (Test-Path $p) {
        $makensis = $p
        break
    }
}

if (-not $makensis) {
    Write-Host "makensis no encontrado en el sistema. Descargando versión portable de NSIS..." -ForegroundColor Cyan
    $nsisZip = "$env:TEMP\nsis.zip"
    curl.exe -L "https://sourceforge.net/projects/nsis/files/NSIS%203/3.10/nsis-3.10.zip/download" -o $nsisZip
    Expand-Archive -Path $nsisZip -DestinationPath "$env:TEMP\nsis" -Force
    $makensis = "$env:TEMP\nsis\nsis-3.10\makensis.exe"
}

Write-Host "Compilador NSIS listo: $makensis" -ForegroundColor Green

# 3. Compilar instalador con NSIS
Write-Host "`n[3/3] Generando Grimoire_Studio_Setup.exe con NSIS..." -ForegroundColor Yellow
$nsiScript = Join-Path $ProjectRoot "grimoire_installer.nsi"
& $makensis $nsiScript

if ($LASTEXITCODE -ne 0) {
    Write-Error "Error durante la compilación de NSIS."
    exit $LASTEXITCODE
}

$outputExe = Join-Path $ProjectRoot "build\windows\x64\runner\Release\Grimoire_Studio_Setup.exe"
if (Test-Path $outputExe) {
    $sizeMb = [math]::Round(((Get-Item $outputExe).Length / 1MB), 2)
    Write-Host "`n==========================================================" -ForegroundColor Green
    Write-Host "   ¡Instalador generado con éxito!                        " -ForegroundColor Green
    Write-Host "   Archivo: $outputExe ($sizeMb MB)                       " -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green
} else {
    Write-Error "No se encontró el ejecutable de salida: $outputExe"
}

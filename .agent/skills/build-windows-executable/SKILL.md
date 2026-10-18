---
name: build-windows-executable
description: Compila y genera ejecutables e instaladores independientes para Windows (Setup.exe con NSIS y MSIX) para Grimoire Studio.
---

# Guía de Compilación de Ejecutables e Instaladores Windows

Este skill define el procedimiento estándar para compilar y empaquetar **Grimoire Studio** en Windows de 64 bits, tanto como ejecutable autónomo, instalador tradicional (`Setup.exe` vía NSIS) o paquete `MSIX`.

---

## 1. Opciones de Distribución en Windows

| Tipo | Archivo resultante | Ventajas | Casos de uso |
| :--- | :--- | :--- | :--- |
| **Instalador NSIS (Recomendado)** | `Grimoire_Studio_Setup.exe` | **Sin errores de certificado**, no requiere permisos de admin, instala con doble clic en 1 archivo, crea iconos en Escritorio y Menú Inicio. | Distribución general a usuarios, itch.io, GitHub Releases. |
| **Carpeta Portable (Zip)** | `Release.zip` (contiene `grimoire_studio.exe` + DLLs) | No requiere instalación ni permisos. | Uso directo en pendrive o pruebas rápidas. |
| **Paquete MSIX** | `grimoire_studio.msix` | Formato oficial UWP/AppX de Microsoft con sandbox y desinstalación nativa. | Publicación en la **Microsoft Store** (en local requiere instalar `GrimoireStudio.cer`). |

---

## 2. Generación Automatizada del Instalador (`Setup.exe` vía NSIS)

Para compilar Flutter y empaquetar el instalador en un solo comando:

```powershell
powershell -ExecutionPolicy Bypass -File ".agent/skills/build-windows-executable/scripts/build_installer.ps1"
```

Si los binarios de Flutter ya fueron compilados previamente y solo se desea regenerar el instalador `.exe`:

```powershell
powershell -ExecutionPolicy Bypass -File ".agent/skills/build-windows-executable/scripts/build_installer.ps1" -SkipFlutterBuild
```

### Ubicación del Instalador Generado
```text
build\windows\x64\runner\Release\Grimoire_Studio_Setup.exe
```

---

## 3. Procedimiento Manual Paso a Paso (NSIS)

### Paso 1: Compilar Flutter en modo Release
```powershell
flutter build windows --release
```
Esto genera la carpeta con el ejecutable y sus librerías en:
`build\windows\x64\runner\Release\` (`grimoire_studio.exe`, `flutter_windows.dll`, `pdfium.dll`, `printing_plugin.dll`, y la carpeta `data/`).

### Paso 2: Compilar el script NSIS
El script de configuración del instalador reside en la raíz: [`grimoire_installer.nsi`](file:///c:/Proyectos%20Personales/New/Grimoire%20Studio/grimoire_installer.nsi).

Ejecuta el compilador de NSIS (`makensis.exe`):
```powershell
& "$env:TEMP\nsis\nsis-3.10\makensis.exe" grimoire_installer.nsi
```
*(Si NSIS está instalado en el sistema, también se puede usar `makensis grimoire_installer.nsi` o hacer clic derecho sobre el archivo `.nsi` > "Compile NSIS Script").*

---

## 4. Configuración del Script `grimoire_installer.nsi`

El archivo `grimoire_installer.nsi` está preconfigurado con:
- **`RequestExecutionLevel user`**: Instala en `$LOCALAPPDATA\GrimoireStudio`, permitiendo instalación en 1 clic **sin solicitar elevación de Administrador (UAC)** ni permisos de sistema.
- **Accesos directos**: Crea accesos directos con el icono oficial en el **Escritorio** y en el **Menú Inicio**.
- **Asociación de Archivos**: Registra la extensión `.grimoire` para abrir paquetes de cartas automáticamente.
- **Desinstalador limpio**: Genera `uninstall.exe` y lo registra en *Configuración > Aplicaciones instaladas*.

---

## 5. Procedimiento Alternativo: Paquete MSIX

Para empaquetar como `.msix`:

```powershell
dart run msix:create
```

### Solución al error de certificado (`0x800B010A`) en local
Si al abrir el `.msix` Windows indica que no se pudo comprobar el certificado de publicador:
```powershell
certutil -user -addstore -f "TrustedPeople" "build\windows\x64\runner\Release\GrimoireStudio.cer"
```
*(O ejecutar el script de conveniencia `build\windows\x64\runner\Release\instalar_certificado.bat`).*

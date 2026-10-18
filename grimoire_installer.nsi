!include "MUI2.nsh"
!include "FileFunc.nsh"

; Definiciones Generales
Name "Grimoire Studio"
OutFile "build\windows\x64\runner\Release\Grimoire_Studio_Setup.exe"
InstallDir "$LOCALAPPDATA\GrimoireStudio"
InstallDirRegKey HKCU "Software\GrimoireStudio" "Install_Dir"
RequestExecutionLevel user

; Interfaz Grafica Moderna MUI2
!define MUI_ABORTWARNING
!define MUI_ICON "windows\runner\resources\app_icon.ico"
!define MUI_UNICON "windows\runner\resources\app_icon.ico"

; Paginas del Asistente de Instalacion
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN "$INSTDIR\grimoire_studio.exe"
!define MUI_FINISHPAGE_RUN_TEXT "Ejecutar Grimoire Studio al finalizar"
!insertmacro MUI_PAGE_FINISH

; Paginas del Asistente de Desinstalacion
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

; Idioma
!insertmacro MUI_LANGUAGE "Spanish"

; Seccion de Instalacion Principal
Section "Grimoire Studio" SecMain
  SetOutPath "$INSTDIR"
  
  ; Copiar ejecutables y dependencias
  File "build\windows\x64\runner\Release\grimoire_studio.exe"
  File "build\windows\x64\runner\Release\flutter_windows.dll"
  File "build\windows\x64\runner\Release\pdfium.dll"
  File "build\windows\x64\runner\Release\printing_plugin.dll"
  
  ; Copiar carpeta de recursos data
  SetOutPath "$INSTDIR\data"
  File /r "build\windows\x64\runner\Release\data\*.*"
  
  SetOutPath "$INSTDIR"
  
  ; Generar desinstalador oficial
  WriteUninstaller "$INSTDIR\uninstall.exe"
  
  ; Crear Accesos Directos
  CreateShortcut "$DESKTOP\Grimoire Studio.lnk" "$INSTDIR\grimoire_studio.exe" "" "$INSTDIR\grimoire_studio.exe" 0
  CreateDirectory "$SMPROGRAMS\Grimoire Studio"
  CreateShortcut "$SMPROGRAMS\Grimoire Studio\Grimoire Studio.lnk" "$INSTDIR\grimoire_studio.exe" "" "$INSTDIR\grimoire_studio.exe" 0
  CreateShortcut "$SMPROGRAMS\Grimoire Studio\Desinstalar Grimoire Studio.lnk" "$INSTDIR\uninstall.exe"
  
  ; Registrar Desinstalador en Windows (Configuracion > Aplicaciones Instaladas)
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\GrimoireStudio" "DisplayName" "Grimoire Studio"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\GrimoireStudio" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\GrimoireStudio" "DisplayIcon" '"$INSTDIR\grimoire_studio.exe",0'
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\GrimoireStudio" "Publisher" "Grimoire Studio"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\GrimoireStudio" "DisplayVersion" "1.0.0"
  
  ; Asociacion de extension de paquete de cartas (.grimoire)
  WriteRegStr HKCU "Software\Classes\.grimoire" "" "GrimoireStudio.Package"
  WriteRegStr HKCU "Software\Classes\GrimoireStudio.Package" "" "Paquete de Cartas Grimoire Studio"
  WriteRegStr HKCU "Software\Classes\GrimoireStudio.Package\DefaultIcon" "" '"$INSTDIR\grimoire_studio.exe",0'
  WriteRegStr HKCU "Software\Classes\GrimoireStudio.Package\shell\open\command" "" '"$INSTDIR\grimoire_studio.exe" "%1"'
SectionEnd

; Seccion de Desinstalacion
Section "Uninstall"
  Delete "$DESKTOP\Grimoire Studio.lnk"
  Delete "$SMPROGRAMS\Grimoire Studio\Grimoire Studio.lnk"
  Delete "$SMPROGRAMS\Grimoire Studio\Desinstalar Grimoire Studio.lnk"
  RMDir "$SMPROGRAMS\Grimoire Studio"
  
  RMDir /r "$INSTDIR"
  
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\GrimoireStudio"
  DeleteRegKey HKCU "Software\Classes\.grimoire"
  DeleteRegKey HKCU "Software\Classes\GrimoireStudio.Package"
  DeleteRegKey HKCU "Software\GrimoireStudio"
SectionEnd

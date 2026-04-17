# --- run_sidequest.ps1 -------------------------------------------------------
$FLUTTER_BIN = "C:\Users\DASK\Desktop\Flutter\flutter\bin\flutter.bat"
$ADB_EXE     = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$DEVICE_ID   = "RZCY51A3NXF"   # deine Device-ID (von flutter doctor)

$ErrorActionPreference = "Stop"
function Say($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }

Set-Location -Path $PSScriptRoot
if (-not (Test-Path ".\pubspec.yaml")) { Write-Error "Script muss im Projektordner liegen."; }

if (-not (Test-Path $FLUTTER_BIN)) { Write-Error "Flutter nicht gefunden: $FLUTTER_BIN"; }

Say "flutter clean"
& $FLUTTER_BIN clean

Say "flutter pub get"
& $FLUTTER_BIN pub get

if (Test-Path $ADB_EXE) {
  Say "Entferne alte App (falls vorhanden)…"
  & $ADB_EXE uninstall com.example.sidequest_app | Out-Host
}

Say "Starte auf Gerät $DEVICE_ID …"
& $FLUTTER_BIN run -d $DEVICE_ID -t lib/main.dart
# -----------------------------------------------------------------------------

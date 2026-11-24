# ============================================================
#  Celebria - Compilar (sin publicar)
#  Uso: .\build.ps1
#
#  REGLAS:
#   - el APK lleva la version en el nombre: CelebriaV<version>.apk
#   - cada compilacion borra todo lo viejo; solo queda lo ultimo
#  Resultado: C:\Celebria\build\apk\CelebriaV<version>.apk
#  (tambien en flutter\build\app\outputs\flutter-apk\)
#  Para publicar en GitHub usa release.ps1.
# ============================================================
$ErrorActionPreference = "Stop"
$env:PATH = "C:\Users\D0nGibaFok\flutter\3.41.7\bin;" + $env:PATH
Set-Location "C:\Celebria"

$match = Select-String -Path "flutter\lib\core\constants.dart" -Pattern "appVersion\s*=\s*'([^']+)'" | Select-Object -First 1
if (-not $match) { Write-Error "No se encontro appVersion en flutter\lib\core\constants.dart."; exit 1 }
$Version = $match.Matches[0].Groups[1].Value
$ApkName = "CelebriaV$Version.apk"
Write-Host ""
Write-Host "=== Celebria - Compilando v$Version ===" -ForegroundColor Cyan

$flutterApkDir = "flutter\build\app\outputs\flutter-apk"
$out = "build\apk\$ApkName"
# Borrar ANTES de compilar el APK de esta misma version: si la compilacion
# falla, no puede quedar un APK viejo que parezca el nuevo.
Remove-Item "$flutterApkDir\app-release.apk*", "$flutterApkDir\$ApkName", $out -ErrorAction SilentlyContinue

Push-Location "flutter"
$ErrorActionPreference = "Continue"
$log = flutter build apk --release --no-version-check --suppress-analytics 2>&1 | ForEach-Object { "$_" }
$code = $LASTEXITCODE
$ErrorActionPreference = "Stop"
Pop-Location
$log | Where-Object { $_ -match "Built|Versioned APK|Removed old build" } | ForEach-Object { Write-Host "  $_" }

if ($code -ne 0 -or -not (Test-Path $out)) {
    Write-Host ""
    Write-Host "Fallo la compilacion (codigo $code):" -ForegroundColor Red
    $log | Select-Object -Last 25 | ForEach-Object { Write-Host "  $_" }
    exit 1
}

# app-release.apk lo recrea Flutter despues de Gradle; aqui ya se puede borrar.
Remove-Item "$flutterApkDir\app-release.apk*" -ErrorAction SilentlyContinue
Remove-Item "$flutterApkDir\app-debug.apk*" -ErrorAction SilentlyContinue
Get-ChildItem "build\apk", $flutterApkDir -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne $ApkName } | Remove-Item -Force

$sizeMB = [math]::Round((Get-Item $out).Length / 1MB, 1)
Write-Host ""
Write-Host "OK - $out ($sizeMB MB)" -ForegroundColor Green
Write-Host "Solo queda la ultima version:" -ForegroundColor DarkGray
Get-ChildItem "build\apk", $flutterApkDir -File | ForEach-Object { Write-Host "   $($_.FullName)" }

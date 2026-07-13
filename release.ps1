# ============================================================
#  Celebria - Script de Release
#  Uso: .\release.ps1 -Version "2.0.0" -Notes "descripcion"
# ============================================================
param(
    [Parameter(Mandatory=$true)]  [string]$Version,
    [Parameter(Mandatory=$true)]  [string]$Notes
)

$ErrorActionPreference = "Continue"   # git warnings no deben abortar el script
$env:PATH = "C:\Users\D0nGibaFok\flutter\3.41.7\bin;" + $env:PATH
Set-Location "C:\Celebria"

# -- 0. Leer credencial de GitHub ---------------------------------------------
Add-Type @'
using System; using System.Runtime.InteropServices;
public class GhCred {
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
    public struct CREDENTIAL {
        public uint Flags; public uint Type; public string TargetName; public string Comment;
        public long LastWritten; public uint CredentialBlobSize; public IntPtr CredentialBlob;
        public uint Persist; public uint AttributeCount; public IntPtr Attributes;
        public string TargetAlias; public string UserName;
    }
    [DllImport("advapi32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    public static extern bool CredRead(string t, uint tp, uint f, out IntPtr p);
    [DllImport("advapi32.dll")] public static extern void CredFree(IntPtr p);
    public static string[] Get(string t) {
        IntPtr p; if (!CredRead(t,1,0,out p)) return null;
        var c=Marshal.PtrToStructure<CREDENTIAL>(p);
        var pw=Marshal.PtrToStringUni(c.CredentialBlob,(int)c.CredentialBlobSize/2);
        CredFree(p); return new string[]{c.UserName,pw};
    }
}
'@

$cred = [GhCred]::Get("git:https://github.com")
if (-not $cred) { Write-Error "No se encontro credencial de GitHub."; exit 1 }
$TOKEN = $cred[1]
$HDRS  = @{ Authorization = "token $TOKEN"; Accept = "application/vnd.github+json" }
$REPO  = "pedroespinal/Celebria"
$TAG   = "v$Version"
$APK   = "C:\Celebria\build\apk\Celebria-$Version.apk"

Write-Host ""
Write-Host "=== Celebria Release $TAG ===" -ForegroundColor Cyan

# -- REGLA: la version siempre debe incrementar respecto a la actual ----------
function ConvertTo-VersionParts([string]$v) {
    return ($v -split '\.') | ForEach-Object { [int]$_ }
}
$currentMatch = Select-String -Path "flutter\lib\core\constants.dart" -Pattern "appVersion\s*=\s*'([^']+)'" | Select-Object -First 1
if (-not $currentMatch) { Write-Error "No se encontro appVersion en flutter\lib\core\constants.dart."; exit 1 }
$currentVersion = $currentMatch.Matches[0].Groups[1].Value
$curParts = ConvertTo-VersionParts $currentVersion
$newParts = ConvertTo-VersionParts $Version
$isNewer = $false
for ($i = 0; $i -lt 3; $i++) {
    $c = if ($i -lt $curParts.Length) { $curParts[$i] } else { 0 }
    $n = if ($i -lt $newParts.Length) { $newParts[$i] } else { 0 }
    if ($n -gt $c) { $isNewer = $true; break }
    if ($n -lt $c) { break }
}
if (-not $isNewer) {
    Write-Error "La version '$Version' no es mayor que la version actual ($currentVersion). Cada release debe incrementar la version."
    exit 1
}
Write-Host "      Version: $currentVersion -> $Version (OK, incrementa)" -ForegroundColor DarkGray

# -- 1. Actualizar appVersion en constants.dart -------------------------------
Write-Host ""
Write-Host "[1/5] Actualizando appVersion a $Version..."
$constPath = "flutter\lib\core\constants.dart"
$content = Get-Content $constPath -Raw -Encoding UTF8
$updated = $content -replace "appVersion\s*=\s*'[^']+'", ("appVersion = '" + $Version + "'")
[System.IO.File]::WriteAllText("$PWD\$constPath", $updated, [System.Text.Encoding]::UTF8)
Write-Host "      OK"

# -- 1.5. Actualizar version en pubspec.yaml (versionName+versionCode) -------
$pubspecPath = "flutter\pubspec.yaml"
$pubspecContent = Get-Content $pubspecPath -Raw -Encoding UTF8
# versionCode derivado: "2.0.1" -> 20001  |  "2.10.0" -> 21000
$vParts = $Version.Split('.') | ForEach-Object { [int]$_ }
$buildNumber = ($vParts[0] * 10000) + ($vParts[1] * 100) + $vParts[2]
$pubspecUpdated = $pubspecContent -replace 'version:\s*[\d\.\+]+', "version: $Version+$buildNumber"
[System.IO.File]::WriteAllText("$PWD\$pubspecPath", $pubspecUpdated, [System.Text.Encoding]::UTF8)
Write-Host "      pubspec.yaml -> $Version+$buildNumber"

# -- 1.6. Actualizar version.json ---------------------------------------------
Write-Host ""
Write-Host "[1.6/6] Actualizando version.json..."
$vjPath = "$PWD\version.json"
$vjCurrent = Get-Content $vjPath -Raw -Encoding UTF8 | ConvertFrom-Json
$vjNew = [ordered]@{
    latest       = $Version
    minimum      = $vjCurrent.minimum   # se edita manualmente cuando se quiere forzar
    download_url = "https://github.com/pedroespinal/Celebria/releases/download/$TAG/Celebria-$TAG.apk"
}
[System.IO.File]::WriteAllText($vjPath,
    ($vjNew | ConvertTo-Json -Compress),
    [System.Text.Encoding]::UTF8)
Write-Host "      OK  (minimum=$($vjCurrent.minimum))"

# -- 2. Compilar APK -----------------------------------------------------------
Write-Host ""
Write-Host "[2/6] Compilando APK (flutter build apk --release)..."

# Borrar el APK anterior antes de compilar. Si no se borra, un build fallido
# reutiliza el APK viejo silenciosamente y se sube una version anterior
# disfrazada con el numero nuevo.
$flutterApk = "flutter\build\app\outputs\flutter-apk\app-release.apk"
Remove-Item $flutterApk -ErrorAction SilentlyContinue

Push-Location "flutter"
$pubGetOut = flutter pub get 2>&1
$buildOut  = flutter build apk --release --no-version-check --suppress-analytics 2>&1
Pop-Location

if (-not (Test-Path $flutterApk)) {
    Write-Host ""
    Write-Error "Fallo la compilacion Flutter."
    Write-Host "--- flutter pub get output ---" -ForegroundColor Red
    $pubGetOut | Write-Host
    Write-Host "--- flutter build apk output ---" -ForegroundColor Red
    $buildOut  | Write-Host
    exit 1
}
New-Item -ItemType Directory -Force "build\apk" | Out-Null
Copy-Item $flutterApk $APK -Force
$sizeMB = [math]::Round((Get-Item $APK).Length / 1MB, 1)
Write-Host "      OK - $sizeMB MB"

# REGLA: build\apk siempre debe contener solo el APK mas reciente (sin reguero
# de versiones viejas). Borra cualquier Celebria-*.apk* que no sea el actual.
Get-ChildItem "build\apk" -Filter "Celebria-*.apk*" -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne (Split-Path $APK -Leaf) } |
    Remove-Item -Force
Write-Host "      build\apk limpiado - solo queda Celebria-$Version.apk"

# -- 3. Commit y tag en git ---------------------------------------------------
Write-Host ""
Write-Host "[3/6] Commit y tag git..."
git add flutter version.json assets/icon.png release.ps1 make_icon.py *>&1 | Out-Null
git commit -m "Celebria $TAG - $Notes" *>&1 | Out-Null
git tag $TAG *>&1 | Out-Null
git push origin main --tags *>&1 | Out-Null
Write-Host "      OK - commit + tag $TAG pusheados"

# -- 4. Crear release en GitHub -----------------------------------------------
Write-Host ""
Write-Host "[4/6] Creando release en GitHub..."

$installGuide = @"
## Novedades / What's new
$Notes

---

## Instalacion por primera vez / First-time install

> **Android no permite instalar apps fuera de la Play Store por defecto — es normal y seguro seguir estos pasos.**

1. Descarga el archivo **Celebria-$TAG.apk** (boton verde arriba 👆)
2. Cuando Chrome termine de descargar, toca **Abrir**
3. Si Android muestra *"No se permite instalar de esta fuente"*:
   - Toca **Configuracion** en ese aviso
   - Activa **Permitir de esta fuente**
   - Regresa y toca **INSTALAR**
4. Si aparece un aviso de Play Protect, toca **Instalar de todas formas**
5. Toca **ABRIR** — listo!

---

## Actualizar desde una version anterior / Updating

1. Abre Celebria — el aviso de actualizacion aparece automaticamente
2. Toca **Descargar** en el aviso
3. Sigue los mismos pasos de instalacion de arriba (tus contactos NO se borran)

---

## Requisitos / Requirements
- Android 7.0 o superior
- ~30 MB de espacio libre
- Sin cuenta requerida — funciona completamente sin internet (excepto para actualizaciones)
"@

$bodyObj = @{
    tag_name         = $TAG
    target_commitish = "main"
    name             = "Celebria $TAG"
    body             = $installGuide
    draft            = $false
    prerelease       = $false
}
$bodyBytes = [System.Text.Encoding]::UTF8.GetBytes(($bodyObj | ConvertTo-Json -Compress))

$rel = $null
try {
    $resp = Invoke-WebRequest -Uri "https://api.github.com/repos/$REPO/releases" `
        -Method POST -Headers $HDRS -Body $bodyBytes -ContentType "application/json; charset=utf-8" `
        -UseBasicParsing
    $rel = $resp.Content | ConvertFrom-Json
    Write-Host "      OK - $($rel.html_url)"
} catch {
    $resp2 = Invoke-WebRequest -Uri "https://api.github.com/repos/$REPO/releases/tags/$TAG" `
        -Method GET -Headers $HDRS -UseBasicParsing
    $rel = $resp2.Content | ConvertFrom-Json
    Write-Host "      Release ya existia - $($rel.html_url)"
}

# -- 5. Subir APK -------------------------------------------------------------
Write-Host ""
Write-Host "[5/6] Subiendo APK ($sizeMB MB) a GitHub..."
$uploadUrl = "https://uploads.github.com/repos/$REPO/releases/$($rel.id)/assets?name=Celebria-$TAG.apk"
$apkBytes  = [System.IO.File]::ReadAllBytes($APK)
$assetResp = Invoke-WebRequest -Uri $uploadUrl -Method POST -Headers $HDRS `
    -Body $apkBytes -ContentType "application/vnd.android.package-archive" `
    -UseBasicParsing
$asset = $assetResp.Content | ConvertFrom-Json
Write-Host "      OK"

# -- 6. Resumen ---------------------------------------------------------------
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host " Release publicado exitosamente!" -ForegroundColor Green
Write-Host " Release : $($rel.html_url)" -ForegroundColor Green
Write-Host " APK     : $($asset.browser_download_url)" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "version.json actual:" -ForegroundColor Cyan
Get-Content "$PWD\version.json" | Write-Host
Write-Host ""
Write-Host "Para forzar actualizacion: edita version.json en GitHub y cambia" -ForegroundColor Yellow
Write-Host "  minimum a la version actual ($TAG) y haz push." -ForegroundColor Yellow
Write-Host ""

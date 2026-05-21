# ============================================================
#  Celebria - Script de Release
#  Uso: .\release.ps1 -Version "1.0.1" -Notes "descripcion"
#  Usa -SkipTest para saltar la prueba local (ej: cambios menores)
# ============================================================
param(
    [Parameter(Mandatory=$true)]  [string]$Version,
    [Parameter(Mandatory=$true)]  [string]$Notes,
    [switch]$SkipTest
)

$ErrorActionPreference = "Continue"   # git warnings no deben abortar el script
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

# -- 0. Prueba local antes de compilar ----------------------------------------
if (-not $SkipTest) {
    Write-Host ""
    Write-Host "[0/6] Prueba local..." -ForegroundColor Yellow
    Write-Host "      Abriendo la app en modo escritorio."
    Write-Host "      Prueba todo lo que necesites y cierra la ventana al terminar."
    Write-Host ""
    $env:PYTHONIOENCODING = "utf-8"
    $env:PYTHONUTF8       = "1"
    python main.py
    Write-Host ""
    $ok = Read-Host "      Todo bien? Continuar con compile y release? (S/N)"
    if ($ok -ne "S" -and $ok -ne "s") {
        Write-Host ""
        Write-Host "  Release cancelado. Corrige lo necesario y vuelve a intentar." -ForegroundColor Red
        Write-Host ""
        exit 0
    }
} else {
    Write-Host "      (prueba omitida con -SkipTest)" -ForegroundColor DarkGray
}

# -- 1. Actualizar APP_VERSION en main.py -------------------------------------
Write-Host ""
Write-Host "[1/5] Actualizando APP_VERSION a $Version..."
$content = Get-Content "main.py" -Raw -Encoding UTF8
$updated = $content -replace 'APP_VERSION\s*=\s*"[^"]+"', ('APP_VERSION = "' + $Version + '"')
if ($content -eq $updated) {
    Write-Host "      (version ya estaba actualizada)"
} else {
    [System.IO.File]::WriteAllText("$PWD\main.py", $updated, [System.Text.Encoding]::UTF8)
    Write-Host "      OK"
}

# -- 1.5. Actualizar version.json --------------------------------------------
Write-Host ""
Write-Host "[1.5/6] Actualizando version.json..."
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

# -- 2. Compilar APK ----------------------------------------------------------
Write-Host ""
Write-Host "[2/5] Compilando APK..."
$env:PYTHONIOENCODING = "utf-8"
$env:PYTHONUTF8 = "1"
$env:NO_COLOR = "1"
chcp 65001 | Out-Null
flet build apk --artifact "Celebria-$Version" 2>&1 | Out-Null
if (-not (Test-Path $APK)) { Write-Error "Fallo la compilacion - APK no encontrado."; exit 1 }
$sizeMB = [math]::Round((Get-Item $APK).Length / 1MB, 1)
Write-Host "      OK - $sizeMB MB"

# -- 3. Commit y tag en git ---------------------------------------------------
Write-Host ""
Write-Host "[3/6] Commit y tag git..."
git add main.py version.json assets/icon.png *>&1 | Out-Null
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
- Android 5.0 o superior
- ~70 MB de espacio libre
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

# ============================================================
#  Celebria - Script de Release
#  Uso: .\release.ps1 -Version "1.0.1" -Notes "descripcion"
# ============================================================
param(
    [Parameter(Mandatory=$true)]  [string]$Version,
    [Parameter(Mandatory=$true)]  [string]$Notes
)

$ErrorActionPreference = "Stop"
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
$APK   = "C:\Celebria\build\apk\Celebria.apk"

Write-Host ""
Write-Host "=== Celebria Release $TAG ===" -ForegroundColor Cyan

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

# -- 2. Compilar APK ----------------------------------------------------------
Write-Host ""
Write-Host "[2/5] Compilando APK..."
$env:PYTHONIOENCODING = "utf-8"
$env:PYTHONUTF8 = "1"
$env:NO_COLOR = "1"
chcp 65001 | Out-Null
flet build apk 2>&1 | Out-Null
if (-not (Test-Path $APK)) { Write-Error "Fallo la compilacion - APK no encontrado."; exit 1 }
$sizeMB = [math]::Round((Get-Item $APK).Length / 1MB, 1)
Write-Host "      OK - $sizeMB MB"

# -- 3. Commit y tag en git ---------------------------------------------------
Write-Host ""
Write-Host "[3/5] Commit y tag git..."
git add main.py 2>&1 | Out-Null
git commit -m "Celebria $TAG - $Notes" 2>&1 | Out-Null
git tag $TAG 2>&1 | Out-Null
git push origin main --tags 2>&1 | Out-Null
Write-Host "      OK - commit + tag $TAG pusheados"

# -- 4. Crear release en GitHub -----------------------------------------------
Write-Host ""
Write-Host "[4/5] Creando release en GitHub..."
$bodyObj = @{
    tag_name         = $TAG
    target_commitish = "main"
    name             = "Celebria $TAG"
    body             = $Notes
    draft            = $false
    prerelease       = $false
}
$bodyJson = $bodyObj | ConvertTo-Json -Compress

$rel = $null
try {
    $resp = Invoke-WebRequest -Uri "https://api.github.com/repos/$REPO/releases" `
        -Method POST -Headers $HDRS -Body $bodyJson -ContentType "application/json" `
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
Write-Host "[5/5] Subiendo APK ($sizeMB MB) a GitHub..."
$uploadUrl = "https://uploads.github.com/repos/$REPO/releases/$($rel.id)/assets?name=Celebria-$TAG.apk"
$apkBytes  = [System.IO.File]::ReadAllBytes($APK)
$assetResp = Invoke-WebRequest -Uri $uploadUrl -Method POST -Headers $HDRS `
    -Body $apkBytes -ContentType "application/vnd.android.package-archive" `
    -UseBasicParsing
$asset = $assetResp.Content | ConvertFrom-Json
Write-Host "      OK"

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host " Release publicado exitosamente!" -ForegroundColor Green
Write-Host " Release : $($rel.html_url)" -ForegroundColor Green
Write-Host " APK     : $($asset.browser_download_url)" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# ============================================================
#  Celebria - Script de prueba local (modo escritorio)
#  Uso: .\test.ps1
#  Corre la app en Windows para probar antes de compilar.
#  Limitaciones conocidas en desktop:
#    - Audio no disponible (flet_audio es mobile)
#    - WhatsApp url= no aplica en escritorio
#    - Todo lo demas funciona igual que en Android
# ============================================================

Set-Location "C:\Celebria"

$env:PYTHONIOENCODING = "utf-8"
$env:PYTHONUTF8       = "1"

Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  Celebria - Prueba local             " -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Abriendo la app en modo escritorio..." -ForegroundColor Yellow
Write-Host "  Cierra la ventana cuando termines." -ForegroundColor Yellow
Write-Host ""

python main.py

Write-Host ""
Write-Host "  App cerrada." -ForegroundColor Green
Write-Host ""

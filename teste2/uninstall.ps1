# muda de pasta para executar o script
cd $env:TEMP

# Caminho da pasta que foi criada nos Downloads
$downloadsDir = Join-Path $env:USERPROFILE "Downloads\inventario"

# Remove apenas a pasta física dos Downloads se ela existir
if (Test-Path $downloadsDir) {
    Remove-Item -Path $downloadsDir -Recurse -Force
    Write-Host "`nInventario coletado e enviado para o TI, obrigado." -ForegroundColor Green
    Start-Sleep -Seconds 5
} else {
    Write-Host "`nA pasta especificada não foi encontrada nos Downloads." -ForegroundColor Yellow
}
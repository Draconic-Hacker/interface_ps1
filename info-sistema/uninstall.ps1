# muda de pasta para executar o script
cd C:\relatorioInventario

# Caminho da pasta que foi criada na Raiz
$scriptsDir = $scriptsDir = "C:\relatorioScripts"

# Remove apenas a pasta física da Raiz se ela existir
if (Test-Path $scriptsDir) {
    Remove-Item -Path $scriptsDir -Recurse -Force
    cls
    Write-Host "`nInventario coletado e enviado para o TI, obrigado." -ForegroundColor Green
	Start-Sleep -Seconds 3
} else {
    cls
    Write-Host "`nA pasta especificada não foi encontrada." -ForegroundColor Yellow
	Start-Sleep -Seconds 3
}
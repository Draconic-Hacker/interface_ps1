# Caminhos (Supondo que estão na AppData)
$basePath    = $env:APPDATA "browser-files"
$dllPath     = Join-Path $basePath "dependences\Microsoft.Web.WebView2.WinForms.dll"

# DEBUG: Isso vai te mostrar na tela se o arquivo realmente esta la antes de tentar carregar
if (-not (Test-Path $dllPath)) {
    [System.Windows.Forms.MessageBox]::Show("ERRO: DLL nao encontrada em: $dllPath")
    exit
}

Add-Type -Path $dllPath
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing


# Cria a Janela Principal (o "container")
$form = New-Object System.Windows.Forms.Form
$form.Text = "Browser Interface"
$form.Size = New-Object System.Drawing.Size(900, 700)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog" # Impede o usuario de redimensionar e quebrar o layout


# Criando o WebView2
$webView = New-Object Microsoft.Web.WebView2.WinForms.WebView2
$webView.Dock = [System.Windows.Forms.DockStyle]::Fill

# IMPORTANTE: Inicialização assíncrona
$form.Add_Load({
    $webView.EnsureCoreWebView2Async($null)
})

# AREA DE TESTE DE VISUALIZACAO
$webView.add_CoreWebView2InitializationCompleted({
    $webView.CoreWebView2.NavigateToString("<h1>Funcionou!</h1><p>O WebView2 está rodando da AppData.</p>")
})

# O seu HTML e CSS (O "Visual")
# $htmlContent = @"
# <!DOCTYPE html>
# <html>
# <head>
#     <style>
#         body { font-family: 'Segoe UI', sans-serif; background: #1e1e1e; color: white; display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; margin: 0; }
#         h1 { color: #0078d4; }
#         .btn { background: #0078d4; border: none; color: white; padding: 10px 20px; cursor: pointer; border-radius: 5px; transition: 0.3s; }
#         .btn:hover { background: #005a9e; }
#         #status { margin-top: 20px; color: #107c10; font-weight: bold; }
#     </style>
# </head>
# <body>
#     <h1>Projeto Browser-Files</h1>
#     <p>Interface moderna com HTML e CSS</p>
#     <button class="btn" onclick="window.chrome.webview.postMessage('listar')">Testar Comunicacao</button>
#     <div id="status"></div>

#     <script>
#         // Ouve mensagens vindas do PowerShell
#         window.chrome.webview.addEventListener('message', event => {
#             document.getElementById('status').innerText = event.data;
#         });
#     </script>
# </body>
# </html>
# "@

# # Logica de inicializacao e comunicacao
# $form.Add_Load({
#     $webView.EnsureCoreWebView2Async($null)
# })

# # Evento: O que acontece quando o WebView2 termina de carregar?
# $webView.add_CoreWebView2InitializationCompleted({
#     $webView.CoreWebView2.NavigateToString($htmlContent)
# })

# # Evento: Receber clique do botao HTML no PowerShell
# $webView.add_WebMessageReceived({
#     param($sender, $args)
#     $mensagem = $args.TryGetWebMessageAsString()
    
#     if ($mensagem -eq "listar") {
#         # O PowerShell processa algo e manda de volta para o HTML
#         $data = Get-Date -Format "HH:mm:ss"
#         $webView.CoreWebView2.PostWebMessageAsString("Botao clicado as $data ! O PowerShell respondeu.")
#     }
# })

# Adiciona o navegador na janela e exibe
$form.Controls.Add($webView)
$form.ShowDialog()

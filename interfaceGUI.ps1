# Caminhos (Supondo que estão na AppData)
$installDir    = Join-Path $env:APPDATA "browser-files"
$dllPath     = Join-Path $installDir "dependences\Microsoft.Web.WebView2.WinForms.dll"

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

# AREA DE TESTE DE VISUALIZACAO

# O seu HTML e CSS (O "Visual")
$htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: 'Segoe UI', sans-serif; background: #1e1e1e; color: white; display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; margin: 0; }
        h1 { color: #0078d4; }
        .btn { background: #0078d4; border: none; color: white; padding: 10px 20px; cursor: pointer; border-radius: 5px; transition: 0.3s; }
        .btn:hover { background: #005a9e; }
        #status { margin-top: 20px; color: #107c10; font-weight: bold; }
    </style>
</head>
<body>
    <h1>Projeto Browser-Files</h1>
    <p>Interface moderna com HTML e CSS</p>
    <button class="btn" onclick="window.chrome.webview.postMessage('listar')">Testar Comunicacao</button>
    <div id="status"></div>
     <script>
        // Ouve mensagens vindas do PowerShell
        window.chrome.webview.addEventListener('message', event => {
            document.getElementById('status').innerText = event.data;
        });
    </script>
</body>
</html>
"@

# Cria o objeto visual
$webView = New-Object Microsoft.Web.WebView2.WinForms.WebView2
$webView.Dock = [System.Windows.Forms.DockStyle]::Fill

# EVENTO: Comunicacao (O clique do botao)
$webView.add_WebMessageReceived({
    param($sender, $args)
    $msg = $args.TryGetWebMessageAsString()
    if ($msg -eq "listar") {
        # O PowerShell processa algo e manda de volta para o HTML
        $data = Get-Date -Format "HH:mm:ss"
        $webView.CoreWebView2.PostWebMessageAsString("PowerShell diz: Acoes executadas as $data")
    }
})

# O evento de sucesso (so adicionado o log de erro real)
$webView.add_CoreWebView2InitializationCompleted({
    param($sender, $args)
    if ($args.IsSuccess) {
        $webView.CoreWebView2.NavigateToString($htmlContent)
    } else {
        # Isso vai nos mostrar o CODIGO real do erro se falhar de novo
        $exception = $args.InitializationException
        [System.Windows.Forms.MessageBox]::Show("Falha: $($exception.Message)")
    }
})

# Define onde o navegador vai guardar o cache/dados
$userDataFolder = Join-Path $installDir "WebView2_Data"
if (!(Test-Path $userDataFolder)) { New-Item -ItemType Directory -Path $userDataFolder }

# Cria o ambiente configurado
$envOptions = [Microsoft.Web.WebView2.Core.CoreWebView2Environment]::CreateAsync($null, $userDataFolder)

# Dispara a inicializacao usando essas opcoes
$form.Add_Load({
    # Esperamos o resultado da criacao do ambiente antes de iniciar o WebView
    $webView.EnsureCoreWebView2Async($envOptions.Result)
})

# Adiciona o navegador na janela e exibe
$form.Controls.Add($webView)
$form.ShowDialog()

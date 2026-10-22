<#
    Info-Sistema.ps1
    Inventario rapido de hardware e sistema.

    Uso remoto:
        iex ((New-Object System.Net.WebClient).DownloadString('URL_RAW_DO_SCRIPT'))

    Uso local:
        powershell -ExecutionPolicy Bypass -File .\Info-Sistema.ps1
#>

# Garante acentuacao correta no console
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

#region ---------- Funcoes auxiliares ----------

function Get-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $id).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

function ConvertTo-GB {
    param([double]$Bytes, [int]$Casas = 0)
    [math]::Round($Bytes / 1GB, $Casas)
}

function Write-Titulo {
    param([string]$Texto)
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor DarkCyan
    Write-Host "  $Texto" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor DarkCyan
}

function Pausar {
    Write-Host ""
    Write-Host "Pressione ENTER para voltar ao menu..." -ForegroundColor DarkGray
    [void](Read-Host)
}

#endregion

#region ---------- Coletores ----------

function Get-InfoResumo {
    $cs  = Get-CimInstance Win32_ComputerSystem
    $bio = Get-CimInstance Win32_Bios
    $cpu = Get-CimInstance Win32_Processor
    $gpu = Get-CimInstance Win32_VideoController
    $ram = Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum
    $csp = Get-CimInstance Win32_ComputerSystemProduct

    # MTM (Machine Type-Model) e MO (SKU / Machine Option) sao campos gravados
    # na BIOS pelo fabricante. Costumam existir em Lenovo e Dell; em placas
    # genericas ou outros fabricantes ficam em branco.
    $mtm = if ($csp.Version)    { $csp.Version }    else { "N/D" }
    $mo  = if ($csp.SKUNumber)  { $csp.SKUNumber }  else { "N/D" }

    [PSCustomObject]@{
        "Marca"    = $cs.Manufacturer
        "Modelo"   = $cs.Model
        "MTM"      = $mtm
        "MO"       = $mo
        "S/N"      = $bio.SerialNumber
        "CPU"      = ($cpu.Name -join " | ")
        "GPU"      = ($gpu.Name -join " | ")
        "RAM (GB)" = ConvertTo-GB $ram.Sum
        "Discos"   = (Get-InfoDiscosTexto) -join " | "
    }
}

function Get-InfoDiscosTexto {
    try {
        Get-PhysicalDisk -ErrorAction Stop | ForEach-Object {
            "$($_.MediaType): $($_.FriendlyName) ($(ConvertTo-GB $_.Size) GB)"
        }
    }
    catch {
        # Fallback para maquinas sem o modulo Storage ou sem privilegio elevado
        Get-CimInstance Win32_DiskDrive | ForEach-Object {
            "$($_.InterfaceType): $($_.Model) ($(ConvertTo-GB $_.Size) GB)"
        }
    }
}

function Get-InfoSO {
    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem

    [PSCustomObject]@{
        "Sistema"       = $os.Caption
        "Versao"        = $os.Version
        "Build"         = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue).DisplayVersion
        "Arquitetura"   = $os.OSArchitecture
        "Instalado em"  = $os.InstallDate
        "Ultimo boot"   = $os.LastBootUpTime
        "Uptime"        = "{0:dd\d\ hh\h\ mm\m}" -f ((Get-Date) - $os.LastBootUpTime)
        "Nome da maq."  = $env:COMPUTERNAME
        "Dominio/Grupo" = $cs.Domain
        "Usuario atual" = "$env:USERDOMAIN\$env:USERNAME"
        "PowerShell"    = $PSVersionTable.PSVersion.ToString()
    }
}

function Get-TipoMemoria {
    param([int]$Codigo)

    # Tabela SMBIOSMemoryType (padrao DMTF). Cobre os codigos mais comuns;
    # os demais caem no "Desconhecido (codigo N)".
    switch ($Codigo) {
        20 { "DDR" }
        21 { "DDR2" }
        24 { "DDR3" }
        26 { "DDR4" }
        34 { "DDR5" }
        default { "Desconhecido (codigo $Codigo)" }
    }
}

function Get-InfoMemoria {
    Get-CimInstance Win32_PhysicalMemory | ForEach-Object {
        [PSCustomObject]@{
            "Slot"       = $_.DeviceLocator
            "Tipo"       = Get-TipoMemoria $_.SMBIOSMemoryType
            "Capac.(GB)" = ConvertTo-GB $_.Capacity
            "Vel.(MHz)"  = $_.Speed
            "Fabricante" = $_.Manufacturer
            "Part Num."  = ($_.PartNumber).Trim()
            "S/N"        = ($_.SerialNumber).Trim()
        }
    }
}

function Get-InfoVolumes {
    Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
        $totalGB = ConvertTo-GB $_.Size 2
        $livreGB = ConvertTo-GB $_.FreeSpace 2

        $pctLivre = 0
        if ($_.Size -gt 0) { $pctLivre = [math]::Round(($_.FreeSpace / $_.Size) * 100, 1) }

        [PSCustomObject]@{
            "Unidade"     = $_.DeviceID
            "Rotulo"      = $_.VolumeName
            "Sistema Arq" = $_.FileSystem
            "Total (GB)"  = $totalGB
            "Livre (GB)"  = $livreGB
            "% Livre"     = $pctLivre
        }
    }
}

function Get-InfoRede {
    Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True" | ForEach-Object {
        [PSCustomObject]@{
            "Adaptador" = $_.Description
            "MAC"       = $_.MACAddress
            "IPv4"      = (($_.IPAddress | Where-Object { $_ -notmatch ":" }) -join ", ")
            "Mascara"   = ($_.IPSubnet | Select-Object -First 1)
            "Gateway"   = ($_.DefaultIPGateway -join ", ")
            "DNS"       = ($_.DNSServerSearchOrder -join ", ")
            "DHCP"      = $_.DHCPEnabled
        }
    }
}

function Get-InfoBiosPlaca {
    $bio = Get-CimInstance Win32_Bios
    $mb  = Get-CimInstance Win32_BaseBoard

    # PowerShell 5.1 nao aceita try/catch como expressao de atribuicao.
    # Por isso tudo e calculado antes de montar o PSCustomObject.
    $tpm = $null
    try {
        $tpm = Get-CimInstance -Namespace "root\cimv2\security\microsofttpm" `
                               -ClassName Win32_Tpm -ErrorAction Stop
    }
    catch { $tpm = $null }

    $secureBoot = "N/D"
    try { $secureBoot = [string](Confirm-SecureBootUEFI -ErrorAction Stop) }
    catch { $secureBoot = "N/D (BIOS legado ou requer admin)" }

    $modoBoot = "N/D"
    if ($env:firmware_type) { $modoBoot = $env:firmware_type }

    $tpmInfo = "Nao detectado / requer admin"
    if ($tpm) { $tpmInfo = "Sim - spec $($tpm.SpecVersion)" }

    [PSCustomObject]@{
        "BIOS"          = $bio.Name
        "Versao BIOS"   = $bio.SMBIOSBIOSVersion
        "Data BIOS"     = $bio.ReleaseDate
        "S/N Chassi"    = $bio.SerialNumber
        "Placa-mae"     = "$($mb.Manufacturer) $($mb.Product)"
        "S/N Placa-mae" = $mb.SerialNumber
        "Modo Boot"     = $modoBoot
        "Secure Boot"   = $secureBoot
        "TPM presente"  = $tpmInfo
    }
}

#endregion

#region ---------- Exportacao ----------

function Select-PastaDestino {
    # Abre o popup do Windows para escolher a pasta. Retorna o caminho ou $null se cancelar.
    $pasta = $null
    $dono  = $null
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop

        # Janela "dona" invisivel e TopMost: garante que o popup apareca na frente do terminal
        $dono = New-Object System.Windows.Forms.Form
        $dono.TopMost       = $true
        $dono.ShowInTaskbar = $false
        $dono.StartPosition = "CenterScreen"

        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description         = "Selecione a pasta onde o relatorio sera salvo"
        $dlg.ShowNewFolderButton = $true
        $dlg.SelectedPath        = [Environment]::GetFolderPath("Desktop")

        $res = $dlg.ShowDialog($dono)
        if ($res -eq [System.Windows.Forms.DialogResult]::OK) {
            $pasta = $dlg.SelectedPath
        }
    }
    catch {
        # Sem interface grafica (ex.: Server Core / sessao remota restrita): pede o caminho por texto
        Write-Host "  Nao foi possivel abrir a janela de selecao." -ForegroundColor Yellow
        $digitado = Read-Host "  Digite o caminho da pasta (ENTER para cancelar)"
        if ($digitado) { $pasta = $digitado.Trim('"') }
    }
    finally {
        if ($dono) { $dono.Dispose() }
    }
    return $pasta
}

function Export-Relatorio {
    param([Parameter(Mandatory)][string]$Pasta)

    if (-not (Test-Path -LiteralPath $Pasta -PathType Container)) {
        Write-Host ""
        Write-Host "  Pasta nao encontrada: $Pasta" -ForegroundColor Red
        return
    }

    $destino = Join-Path $Pasta `
                         ("Inventario_{0}_{1:yyyy-MM-dd_HHmm}.txt" -f $env:COMPUTERNAME, (Get-Date))

    $conteudo = @()
    $conteudo += "RELATORIO DE INVENTARIO - $env:COMPUTERNAME"
    $conteudo += "Gerado em: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
    $conteudo += ""
    $conteudo += "--- RESUMO ---";            $conteudo += (Get-InfoResumo     | Format-List   | Out-String)
    $conteudo += "--- SISTEMA OPERACIONAL ---"; $conteudo += (Get-InfoSO       | Format-List   | Out-String)
    $conteudo += "--- BIOS / PLACA-MAE ---";  $conteudo += (Get-InfoBiosPlaca  | Format-List   | Out-String)
    $conteudo += "--- MEMORIA ---";           $conteudo += (Get-InfoMemoria    | Format-Table -AutoSize | Out-String)
    $conteudo += "--- VOLUMES ---";           $conteudo += (Get-InfoVolumes    | Format-Table -AutoSize | Out-String)
    $conteudo += "--- REDE ---";              $conteudo += (Get-InfoRede       | Format-List   | Out-String)

    try {
        $conteudo | Out-File -LiteralPath $destino -Encoding UTF8 -ErrorAction Stop
        Write-Host ""
        Write-Host "  Relatorio salvo em:" -ForegroundColor Green
        Write-Host "  $destino" -ForegroundColor White
    }
    catch {
        Write-Host ""
        Write-Host "  Falha ao salvar o relatorio em: $Pasta" -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)" -ForegroundColor DarkRed
        Write-Host "  Dica: escolha outra pasta (sem restricao de gravacao)." -ForegroundColor Yellow
    }
}

#region ---------- Inventario personalizado (prototipo) ----------

function Get-CatalogoInventario {
    # Coleta tudo uma vez e monta o catalogo de secoes:
    #   Tipo "campos" : objeto plano (Nome = Valor); o usuario marca campo a campo
    #   Tipo "tabela" : varias linhas (slots, volumes, adaptadores); marca o bloco inteiro
    $catalogo = New-Object System.Collections.ArrayList

    $planas = @(
        [PSCustomObject]@{ Titulo = "Resumo";                 Dados = (Get-InfoResumo) },
        [PSCustomObject]@{ Titulo = "Sistema operacional";    Dados = (Get-InfoSO) },
        [PSCustomObject]@{ Titulo = "BIOS / Placa-mae / TPM"; Dados = (Get-InfoBiosPlaca) }
    )

    foreach ($p in $planas) {
        $campos = New-Object System.Collections.ArrayList
        foreach ($prop in $p.Dados.PSObject.Properties) {
            $valor = $prop.Value
            if ($valor -is [datetime]) { $valor = $valor.ToString("dd/MM/yyyy HH:mm") }
            [void]$campos.Add([PSCustomObject]@{
                Nome    = $prop.Name
                Valor   = [string]$valor
                Marcado = $true
            })
        }
        [void]$catalogo.Add([PSCustomObject]@{
            Tipo = "campos"; Titulo = $p.Titulo; Formato = "lista"
            Campos = $campos; Dados = $null; Marcado = $true
        })
    }

    $tabelas = @(
        [PSCustomObject]@{ Titulo = "Memoria RAM (por slot)";  Formato = "tabela"; Dados = @(Get-InfoMemoria) },
        [PSCustomObject]@{ Titulo = "Volumes de disco";        Formato = "tabela"; Dados = @(Get-InfoVolumes) },
        [PSCustomObject]@{ Titulo = "Rede";                    Formato = "lista";  Dados = @(Get-InfoRede) }
    )

    foreach ($t in $tabelas) {
        [void]$catalogo.Add([PSCustomObject]@{
            Tipo = "tabela"; Titulo = $t.Titulo; Formato = $t.Formato
            Campos = $null; Dados = $t.Dados; Marcado = $true
        })
    }

    # A virgula impede o PowerShell de "desenrolar" o ArrayList ao retornar
    return ,$catalogo
}

function Get-TotalMarcado {
    param($Catalogo)
    $total = 0
    foreach ($s in $Catalogo) {
        if ($s.Tipo -eq "campos") {
            $total += @($s.Campos | Where-Object { $_.Marcado }).Count
        }
        elseif ($s.Marcado) {
            $total += 1
        }
    }
    return $total
}

function Set-MarcacaoGeral {
    param($Catalogo, [bool]$Valor)
    foreach ($s in $Catalogo) {
        if ($s.Tipo -eq "campos") {
            foreach ($c in $s.Campos) { $c.Marcado = $Valor }
        }
        else { $s.Marcado = $Valor }
    }
}

function Set-MarcacaoIdentificacao {
    # Atalho: so os dados de identificacao da maquina (patrimonio / chamado)
    param($Catalogo)
    $nomes = @("Marca", "Modelo", "MTM", "MO", "S/N")
    foreach ($s in $Catalogo) {
        if ($s.Tipo -eq "campos") {
            foreach ($c in $s.Campos) {
                $c.Marcado = (($s.Titulo -eq "Resumo") -and ($nomes -contains $c.Nome))
            }
        }
        else { $s.Marcado = $false }
    }
}

function Show-SelecaoCampos {
    param($Secao)
    $voltar = $false
    do {
        Clear-Host
        Write-Titulo ("CAMPOS - " + $Secao.Titulo.ToUpper())
        Write-Host ""
        for ($i = 0; $i -lt $Secao.Campos.Count; $i++) {
            $c = $Secao.Campos[$i]
            $box = "[ ]"
            $cor = "DarkGray"
            if ($c.Marcado) { $box = "[x]"; $cor = "White" }

            $v = $c.Valor
            if ($v.Length -gt 45) { $v = $v.Substring(0, 42) + "..." }

            Write-Host ("   {0,2}) {1} {2} : {3}" -f ($i + 1), $box, $c.Nome.PadRight(15), $v) -ForegroundColor $cor
        }
        Write-Host ""
        Write-Host "   Digite o(s) numero(s) para marcar/desmarcar (ex: 1,3,5)"
        Write-Host "   [A] Marcar todos   [L] Limpar todos   [ENTER] Voltar" -ForegroundColor DarkGray
        Write-Host ""

        $entrada = (Read-Host "   Opcao").Trim()

        if ($entrada -eq "" -or $entrada -eq "0" -or $entrada -eq "V") {
            $voltar = $true
        }
        elseif ($entrada -eq "A") {
            foreach ($c in $Secao.Campos) { $c.Marcado = $true }
        }
        elseif ($entrada -eq "L") {
            foreach ($c in $Secao.Campos) { $c.Marcado = $false }
        }
        else {
            foreach ($tok in ($entrada -split "[,; ]+")) {
                $n = 0
                if ([int]::TryParse($tok, [ref]$n) -and $n -ge 1 -and $n -le $Secao.Campos.Count) {
                    $item = $Secao.Campos[$n - 1]
                    $item.Marcado = (-not $item.Marcado)
                }
            }
        }
    } while (-not $voltar)
}

function Show-SelecaoInventario {
    # Retorna $true se o usuario confirmou a geracao, $false se cancelou
    param($Catalogo)

    $resultado = $false
    $fim = $false

    do {
        Clear-Host
        Write-Titulo "INVENTARIO PERSONALIZADO - O QUE ENTRA NO RELATORIO"
        Write-Host ""

        for ($i = 0; $i -lt $Catalogo.Count; $i++) {
            $s = $Catalogo[$i]

            if ($s.Tipo -eq "campos") {
                $qtd  = @($s.Campos | Where-Object { $_.Marcado }).Count
                $info = "{0}/{1} campos  >" -f $qtd, $s.Campos.Count
                $box  = "( )"
                if ($qtd -eq $s.Campos.Count) { $box = "(x)" }
                elseif ($qtd -gt 0)           { $box = "(~)" }
            }
            else {
                $info = "{0} item(ns)" -f $s.Dados.Count
                $box  = "( )"
                if ($s.Marcado) { $box = "(x)" }
            }

            $cor = "DarkGray"
            if ($box -ne "( )") { $cor = "White" }

            Write-Host ("   [{0}] {1} {2} {3}" -f ($i + 1), $box, $s.Titulo.PadRight(26), $info) -ForegroundColor $cor
        }

        $total = Get-TotalMarcado -Catalogo $Catalogo
        Write-Host ""
        Write-Host ("   Itens selecionados: {0}" -f $total) -ForegroundColor Cyan
        Write-Host ""
        Write-Host "   [numero] Abrir secao (campos) ou marcar/desmarcar (blocos)"
        Write-Host "   [A] Marcar tudo   [L] Limpar tudo   [B] So identificacao (marca, modelo, MTM, MO, S/N)"
        Write-Host "   [G] Gerar relatorio   [0] Cancelar" -ForegroundColor DarkGray
        Write-Host ""

        $entrada = (Read-Host "   Opcao").Trim()

        if ($entrada -eq "0") {
            $resultado = $false
            $fim = $true
        }
        elseif ($entrada -eq "G") {
            if ($total -eq 0) {
                Write-Host "  Selecione pelo menos um item." -ForegroundColor Yellow
                Start-Sleep -Seconds 1
            }
            else {
                $resultado = $true
                $fim = $true
            }
        }
        elseif ($entrada -eq "A") { Set-MarcacaoGeral -Catalogo $Catalogo -Valor $true }
        elseif ($entrada -eq "L") { Set-MarcacaoGeral -Catalogo $Catalogo -Valor $false }
        elseif ($entrada -eq "B") { Set-MarcacaoIdentificacao -Catalogo $Catalogo }
        else {
            $n = 0
            if ([int]::TryParse($entrada, [ref]$n) -and $n -ge 1 -and $n -le $Catalogo.Count) {
                $sec = $Catalogo[$n - 1]
                if ($sec.Tipo -eq "campos") { Show-SelecaoCampos -Secao $sec }
                else { $sec.Marcado = (-not $sec.Marcado) }
            }
            else {
                Write-Host "  Opcao invalida." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    } while (-not $fim)

    return $resultado
}

function Read-PastaDestino {
    # Pergunta onde salvar. Retorna o caminho da pasta ou $null se cancelar.
    Write-Host ""
    Write-Host "   Onde salvar o relatorio?"
    Write-Host "   [1] Area de Trabalho"
    Write-Host "   [2] Selecionar local (abre janela)"
    Write-Host "   [0] Cancelar" -ForegroundColor DarkGray
    Write-Host ""

    $r = (Read-Host "   Escolha uma opcao").Trim()
    switch ($r) {
        "1" { return [Environment]::GetFolderPath("Desktop") }
        "2" {
            Write-Host "  Abrindo janela de selecao..." -ForegroundColor DarkGray
            return (Select-PastaDestino)
        }
        default { return $null }
    }
}

function Export-RelatorioPersonalizado {
    param(
        [Parameter(Mandatory)][string]$Pasta,
        [Parameter(Mandatory)]$Catalogo
    )

    if (-not (Test-Path -LiteralPath $Pasta -PathType Container)) {
        Write-Host ""
        Write-Host "  Pasta nao encontrada: $Pasta" -ForegroundColor Red
        return
    }

    $destino = Join-Path $Pasta `
        ("Inventario_Personalizado_{0}_{1:yyyy-MM-dd_HHmm}.txt" -f $env:COMPUTERNAME, (Get-Date))

    $linhas = New-Object System.Collections.ArrayList
    [void]$linhas.Add("RELATORIO DE INVENTARIO (PERSONALIZADO) - $env:COMPUTERNAME")
    [void]$linhas.Add("Gerado em: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')")
    [void]$linhas.Add("")

    foreach ($s in $Catalogo) {
        if ($s.Tipo -eq "campos") {
            $sel = @($s.Campos | Where-Object { $_.Marcado })
            if ($sel.Count -eq 0) { continue }

            [void]$linhas.Add("--- " + $s.Titulo.ToUpper() + " ---")
            $largura = 0
            foreach ($c in $sel) { if ($c.Nome.Length -gt $largura) { $largura = $c.Nome.Length } }
            foreach ($c in $sel) {
                [void]$linhas.Add(("{0} : {1}" -f $c.Nome.PadRight($largura), $c.Valor))
            }
            [void]$linhas.Add("")
        }
        elseif ($s.Marcado) {
            [void]$linhas.Add("--- " + $s.Titulo.ToUpper() + " ---")
            if ($s.Dados.Count -eq 0) {
                [void]$linhas.Add("(sem dados)")
            }
            elseif ($s.Formato -eq "lista") {
                [void]$linhas.Add(($s.Dados | Format-List | Out-String -Width 250).TrimEnd())
            }
            else {
                [void]$linhas.Add(($s.Dados | Format-Table -AutoSize | Out-String -Width 250).TrimEnd())
            }
            [void]$linhas.Add("")
        }
    }

    try {
        $linhas | Out-File -LiteralPath $destino -Encoding UTF8 -ErrorAction Stop
        Write-Host ""
        Write-Host "  Relatorio salvo em:" -ForegroundColor Green
        Write-Host "  $destino" -ForegroundColor White
    }
    catch {
        Write-Host ""
        Write-Host "  Falha ao salvar o relatorio em: $Pasta" -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)" -ForegroundColor DarkRed
        Write-Host "  Dica: escolha outra pasta (sem restricao de gravacao)." -ForegroundColor Yellow
    }
}

function Invoke-InventarioPersonalizado {
    Write-Titulo "INVENTARIO PERSONALIZADO"
    Write-Host ""
    Write-Host "  Coletando informacoes desta maquina..." -ForegroundColor DarkGray

    $catalogo = Get-CatalogoInventario

    $confirmou = Show-SelecaoInventario -Catalogo $catalogo
    if (-not $confirmou) {
        Write-Host ""
        Write-Host "  Operacao cancelada." -ForegroundColor Yellow
        return
    }

    $pasta = Read-PastaDestino
    if (-not $pasta) {
        Write-Host ""
        Write-Host "  Operacao cancelada." -ForegroundColor Yellow
        return
    }

    Export-RelatorioPersonalizado -Pasta $pasta -Catalogo $catalogo
}

#endregion

function Show-SubMenuExportar {
    $voltar = $false
    do {
        Clear-Host
        Write-Titulo "BAIXAR RELATORIO"
        Write-Host ""
        Write-Host "   [1] Inventario completo -> Area de Trabalho"
        Write-Host "   [2] Inventario completo -> selecionar local (abre janela)"
        Write-Host "   [3] Inventario personalizado (escolher o que entra no relatorio)"
        Write-Host ""
        Write-Host "   [0] Voltar ao menu principal" -ForegroundColor DarkGray
        Write-Host ""

        $sub = Read-Host "   Escolha uma opcao"

        switch ($sub) {
            "1" {
                Export-Relatorio -Pasta ([Environment]::GetFolderPath("Desktop"))
                Pausar
                $voltar = $true
            }
            "2" {
                Write-Host ""
                Write-Host "  Abrindo janela de selecao..." -ForegroundColor DarkGray
                $pasta = Select-PastaDestino
                if ($pasta) {
                    Export-Relatorio -Pasta $pasta
                }
                else {
                    Write-Host ""
                    Write-Host "  Nenhuma pasta selecionada. Operacao cancelada." -ForegroundColor Yellow
                }
                Pausar
                $voltar = $true
            }
            "3" {
                Invoke-InventarioPersonalizado
                Pausar
                $voltar = $true
            }
            "0" { $voltar = $true }
            default {
                Write-Host "  Opcao invalida." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    } while (-not $voltar)
}

#endregion

#region ---------- Menu ----------

function Show-Menu {
    Clear-Host
    $admin = if (Get-Admin) { "ADMIN" } else { "USUARIO COMUM" }
    $cor   = if (Get-Admin) { "Green" } else { "Yellow" }

    Write-Host ""
    Write-Host "  +--------------------------------------------------------+" -ForegroundColor DarkCyan
    Write-Host "  |            INVENTARIO DE MAQUINA - $($env:COMPUTERNAME.PadRight(20))|" -ForegroundColor Cyan
    Write-Host "  +--------------------------------------------------------+" -ForegroundColor DarkCyan
    Write-Host "   Contexto: " -NoNewline; Write-Host $admin -ForegroundColor $cor
    Write-Host ""
    Write-Host "   [1] Resumo geral (marca, modelo, S/N, CPU, GPU, RAM, discos)"
    Write-Host "   [2] Sistema operacional"
    Write-Host "   [3] BIOS / Placa-mae / TPM"
    Write-Host "   [4] Memoria RAM (por slot)"
    Write-Host "   [5] Discos fisicos e volumes"
    Write-Host "   [6] Rede (IP, MAC, gateway, DNS)"
    Write-Host "   [7] TUDO na tela"
    Write-Host "   [8] Baixar relatorio (Area de Trabalho ou local a escolher)"
    Write-Host ""
    Write-Host "   [0] Sair" -ForegroundColor DarkGray
    Write-Host ""
}

do {
    Show-Menu
    $opcao = Read-Host "   Escolha uma opcao"

    switch ($opcao) {
        "1" {
            Write-Titulo "RESUMO GERAL"
            Get-InfoResumo | Format-List
            Pausar
        }
        "2" {
            Write-Titulo "SISTEMA OPERACIONAL"
            Get-InfoSO | Format-List
            Pausar
        }
        "3" {
            Write-Titulo "BIOS / PLACA-MAE / TPM"
            Get-InfoBiosPlaca | Format-List
            Pausar
        }
        "4" {
            Write-Titulo "MEMORIA RAM"
            Get-InfoMemoria | Format-Table -AutoSize
            $total = (Get-CimInstance Win32_PhysicalMemory | Measure-Object Capacity -Sum).Sum
            Write-Host "  Total instalado: $(ConvertTo-GB $total) GB" -ForegroundColor Green
            Pausar
        }
        "5" {
            Write-Titulo "DISCOS FISICOS"
            Get-InfoDiscosTexto | ForEach-Object { Write-Host "  - $_" }
            Write-Titulo "VOLUMES"
            Get-InfoVolumes | Format-Table -AutoSize
            Pausar
        }
        "6" {
            Write-Titulo "REDE"
            Get-InfoRede | Format-List
            Pausar
        }
        "7" {
            Write-Titulo "RESUMO GERAL";          Get-InfoResumo    | Format-List
            Write-Titulo "SISTEMA OPERACIONAL";   Get-InfoSO        | Format-List
            Write-Titulo "BIOS / PLACA-MAE";      Get-InfoBiosPlaca | Format-List
            Write-Titulo "MEMORIA RAM";           Get-InfoMemoria   | Format-Table -AutoSize
            Write-Titulo "VOLUMES";               Get-InfoVolumes   | Format-Table -AutoSize
            Write-Titulo "REDE";                  Get-InfoRede      | Format-List
            Pausar
        }
        "8" {
            Show-SubMenuExportar
        }
        "0" {
            Write-Host ""
            Write-Host "  Encerrando..." -ForegroundColor DarkGray
            Start-Sleep -Milliseconds 800
            exit
        }
        default {
            Write-Host "  Opcao invalida." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
} while ($opcao -ne "0")

#endregion

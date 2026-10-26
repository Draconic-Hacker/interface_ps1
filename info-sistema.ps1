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

# Versao do script (mesmo numero do CHANGELOG e da tag vX.Y.Z).
# Aparece no menu e nos relatorios gerados.
$ScriptVersao = "1.1.0"

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

# ---------- AnyDesk ----------

function Read-AnyDeskId {
    # Le o ad.anynet.id de um system.conf. Retorna o ID ou $null.
    param([string]$Caminho)

    if (-not (Test-Path -LiteralPath $Caminho)) { return $null }

    $linha = $null
    try {
        $linha = Get-Content -LiteralPath $Caminho -ErrorAction Stop |
                 Select-String -Pattern '^\s*ad\.anynet\.id\s*=' |
                 Select-Object -First 1
    }
    catch { return $null }

    if (-not $linha) { return $null }
    return ($linha.Line -split "=", 2)[1].Trim()
}

function Get-InfoAnyDesk {
    # Instalado : %ProgramData%\AnyDesk\system.conf
    # Portable  : %APPDATA%\AnyDesk\system.conf (perfil de quem esta rodando o script)
    $instalado = Read-AnyDeskId -Caminho (Join-Path $env:ProgramData "AnyDesk\system.conf")
    $portable  = Read-AnyDeskId -Caminho (Join-Path $env:APPDATA     "AnyDesk\system.conf")

    if (-not $instalado) { $instalado = "Nao encontrado" }
    if (-not $portable)  { $portable  = "Nao encontrado" }

    [PSCustomObject]@{
        "AnyDesk instalado" = $instalado
        "AnyDesk portable"  = $portable
    }
}

# ---------- Usuarios ----------

function Get-AdminsLocais {
    # Retorna os membros do grupo Administradores local (MAQUINA\usuario, DOMINIO\usuario...).
    # O grupo e localizado pelo SID S-1-5-32-544, porque o NOME muda com o idioma do Windows
    # (Administrators / Administradores).
    $nomes = New-Object System.Collections.ArrayList

    $nomeGrupo = $null
    try {
        $sid = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-544")
        $nomeGrupo = ($sid.Translate([System.Security.Principal.NTAccount]).Value -split "\\")[-1]
    }
    catch { $nomeGrupo = $null }

    if (-not $nomeGrupo) { return }

    try {
        foreach ($m in (Get-LocalGroupMember -Group $nomeGrupo -ErrorAction Stop)) {
            [void]$nomes.Add([string]$m.Name)
        }
    }
    catch {
        # Fallback: Get-LocalGroupMember falha com contas Azure AD / SIDs orfaos.
        # 'net localgroup' lista os membros entre a linha de tracos e a mensagem final (localizada).
        $nomes.Clear()
        $saida  = & net.exe localgroup $nomeGrupo 2>$null
        $linhas = @($saida | ForEach-Object { ("" + $_).Trim() })

        $ini = -1
        for ($i = 0; $i -lt $linhas.Count; $i++) {
            if ($linhas[$i] -match '^-{5,}$') { $ini = $i; break }
        }
        if ($ini -ge 0) {
            $fim = $linhas.Count - 1
            while ($fim -gt $ini -and $linhas[$fim] -eq "") { $fim-- }
            for ($i = $ini + 1; $i -lt $fim; $i++) {
                if ($linhas[$i]) { [void]$nomes.Add($linhas[$i]) }
            }
        }
    }

    return $nomes
}

function Get-InfoUsuarios {
    $prefixo      = "$env:COMPUTERNAME\"
    $adminsLocais = @{}
    $externos     = New-Object System.Collections.ArrayList

    foreach ($n in @(Get-AdminsLocais)) {
        if ($n.StartsWith($prefixo, [StringComparison]::OrdinalIgnoreCase)) {
            $adminsLocais[$n.Substring($prefixo.Length).ToLower()] = $true
        }
        elseif ($n.Contains("\")) {
            [void]$externos.Add($n)
        }
        else {
            $adminsLocais[$n.ToLower()] = $true
        }
    }

    $locais = @()
    try { $locais = @(Get-LocalUser -ErrorAction Stop) }
    catch { $locais = @() }

    $linhas = New-Object System.Collections.ArrayList

    foreach ($u in $locais) {
        $tipo = "Comum"
        if ($adminsLocais.ContainsKey($u.Name.ToLower())) { $tipo = "Administrador" }

        $ativo = "Nao"
        if ($u.Enabled) { $ativo = "Sim" }

        $logon = "Nunca"
        if ($u.LastLogon) { $logon = $u.LastLogon.ToString("dd/MM/yyyy HH:mm") }

        [void]$linhas.Add([PSCustomObject]@{
            "Usuario"      = $u.Name
            "Tipo"         = $tipo
            "Ativo"        = $ativo
            "Origem"       = "Local"
            "Ultimo logon" = $logon
        })
    }

    # Contas/grupos de dominio ou Azure AD que tambem sao administradores desta maquina
    foreach ($n in $externos) {
        [void]$linhas.Add([PSCustomObject]@{
            "Usuario"      = $n
            "Tipo"         = "Administrador"
            "Ativo"        = "N/D"
            "Origem"       = "Dominio / Azure AD"
            "Ultimo logon" = "N/D"
        })
    }

    return $linhas
}

function Get-ResumoUsuarios {
    param($Usuarios)
    $u      = @($Usuarios)
    $ativos = @($u | Where-Object { $_.Ativo -eq "Sim" }).Count
    $adms   = @($u | Where-Object { $_.Tipo -eq "Administrador" }).Count
    return ("Total: {0} | Ativos: {1} | Administradores: {2}" -f $u.Count, $ativos, $adms)
}

function Show-InfoUsuarios {
    $u = @(Get-InfoUsuarios)
    if ($u.Count -eq 0) {
        Write-Host "  Nao foi possivel listar os usuarios desta maquina." -ForegroundColor Yellow
        return
    }
    $u | Format-Table -AutoSize
    Write-Host ("  " + (Get-ResumoUsuarios -Usuarios $u)) -ForegroundColor Green
}

# ---------- Aplicativos instalados ----------

function Get-InfoApps {
    # Fonte 1: Registro (HKLM 64-bit, HKLM 32-bit, HKCU) -> programas tradicionais
    # Fonte 2: Get-AppxPackage -> apps da Microsoft Store (UWP) do usuario atual
    # Nao usa Win32_Product (so MSI, lento e dispara reconfiguracao de pacotes) nem winget (texto, nem sempre instalado).
    $lista  = New-Object System.Collections.ArrayList
    $vistos = @{}

    $chaves = @(
        [PSCustomObject]@{ Caminho = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*";             Origem = "Win32 (64-bit)" },
        [PSCustomObject]@{ Caminho = "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"; Origem = "Win32 (32-bit)" },
        [PSCustomObject]@{ Caminho = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*";             Origem = "Usuario atual" }
    )

    foreach ($k in $chaves) {
        $itens = Get-ItemProperty -Path $k.Caminho -ErrorAction SilentlyContinue
        foreach ($item in $itens) {
            if (-not $item.DisplayName)       { continue }
            if ($item.SystemComponent -eq 1)  { continue }   # componentes ocultos
            if ($item.ParentKeyName)          { continue }   # atualizacoes/patches

            $id = ("{0}|{1}" -f $item.DisplayName, $item.DisplayVersion).ToLower()
            if ($vistos.ContainsKey($id)) { continue }
            $vistos[$id] = $true

            $data = ""
            $bruto = [string]$item.InstallDate
            if ($bruto -match '^\d{8}$') {
                $data = "{0}/{1}/{2}" -f $bruto.Substring(6, 2), $bruto.Substring(4, 2), $bruto.Substring(0, 4)
            }

            [void]$lista.Add([PSCustomObject]@{
                "Nome"         = $item.DisplayName
                "Versao"       = [string]$item.DisplayVersion
                "Fabricante"   = [string]$item.Publisher
                "Instalado em" = $data
                "Origem"       = $k.Origem
            })
        }
    }

    $pacotes = @()
    try {
        $pacotes = @(Get-AppxPackage -ErrorAction Stop |
            Where-Object { -not $_.IsFramework -and -not $_.IsResourcePackage -and $_.SignatureKind -ne "System" })
    }
    catch { $pacotes = @() }

    foreach ($p in $pacotes) {
        $fab = ""
        if ($p.Publisher -match 'CN=([^,]+)') { $fab = $Matches[1] }

        [void]$lista.Add([PSCustomObject]@{
            "Nome"         = $p.Name
            "Versao"       = [string]$p.Version
            "Fabricante"   = $fab
            "Instalado em" = ""
            "Origem"       = "Store (UWP)"
        })
    }

    return ($lista | Sort-Object Nome)
}

function Get-ResumoApps {
    param($Apps)
    $a     = @($Apps)
    $store = @($a | Where-Object { $_.Origem -like "Store*" }).Count
    return ("Total: {0} | Tradicionais (Win32): {1} | Apps modernos (Store/Windows): {2}" -f $a.Count, ($a.Count - $store), $store)
}

function Show-InfoAppsLista {
    # Lista completa de uma vez (usada na opcao "TUDO na tela")
    $apps = @(Get-InfoApps)
    $apps | Format-Table -AutoSize
    Write-Host ("  " + (Get-ResumoApps -Apps $apps)) -ForegroundColor Green
}

function Show-EscolhaColunas {
    # Tela para ligar/desligar colunas opcionais da lista de aplicativos
    param($Colunas)

    $voltar = $false
    do {
        Clear-Host
        Write-Titulo "COLUNAS DA LISTA DE APLICATIVOS"
        Write-Host ""
        Write-Host "   Nome e Versao sempre aparecem." -ForegroundColor DarkGray
        Write-Host ""
        for ($i = 0; $i -lt $Colunas.Count; $i++) {
            $box = "[ ]"
            if ($Colunas[$i].Ativa) { $box = "[x]" }
            Write-Host ("   {0}) {1} {2}" -f ($i + 1), $box, $Colunas[$i].Nome)
        }
        Write-Host ""
        Write-Host "   Digite o(s) numero(s) para marcar/desmarcar (ex: 1,3)   [ENTER] Voltar" -ForegroundColor DarkGray
        Write-Host ""

        $entrada = (Read-Host "   Opcao").Trim()

        if ($entrada -eq "") {
            $voltar = $true
        }
        else {
            foreach ($tok in ($entrada -split "[,; ]+")) {
                $n = 0
                if ([int]::TryParse($tok, [ref]$n) -and $n -ge 1 -and $n -le $Colunas.Count) {
                    $Colunas[$n - 1].Ativa = (-not $Colunas[$n - 1].Ativa)
                }
            }
        }
    } while (-not $voltar)
}

function Show-InfoApps {
    # Lista paginada de aplicativos, com busca por nome e colunas opcionais
    param([int]$ItensPorPagina = 10)

    $apps = @(Get-InfoApps)
    if ($apps.Count -eq 0) {
        Write-Host "  Nenhum aplicativo encontrado." -ForegroundColor Yellow
        return
    }

    $colunas = New-Object System.Collections.ArrayList
    foreach ($nomeCol in @("Fabricante", "Instalado em", "Origem")) {
        [void]$colunas.Add([PSCustomObject]@{ Nome = $nomeCol; Ativa = $false })
    }

    $busca  = ""
    $pagina = 1
    $sair   = $false

    do {
        # Aplica a busca (comparacao literal, sem curingas)
        $visiveis = $apps
        if ($busca -ne "") {
            $visiveis = @($apps | Where-Object {
                $_.Nome.IndexOf($busca, [StringComparison]::OrdinalIgnoreCase) -ge 0
            })
        }

        $total   = $visiveis.Count
        $paginas = [int][Math]::Ceiling([double]$total / $ItensPorPagina)
        if ($paginas -lt 1)        { $paginas = 1 }
        if ($pagina -gt $paginas)  { $pagina = $paginas }
        if ($pagina -lt 1)         { $pagina = 1 }

        # Colunas: Nome e Versao fixas + as opcionais marcadas
        $props = @("Nome", "Versao")
        foreach ($c in $colunas) {
            if ($c.Ativa) { $props += $c.Nome }
        }

        Clear-Host
        Write-Titulo ("APLICATIVOS INSTALADOS - Pagina {0} de {1}" -f $pagina, $paginas)

        $info = "Total: $total"
        if ($busca -ne "") { $info += " (busca: '$busca' | geral: $($apps.Count))" }
        Write-Host ("  " + $info) -ForegroundColor DarkGray
        Write-Host ""

        if ($total -eq 0) {
            Write-Host "  Nenhum aplicativo corresponde a busca." -ForegroundColor Yellow
        }
        else {
            $ini = ($pagina - 1) * $ItensPorPagina
            $visiveis |
                Select-Object -Skip $ini -First $ItensPorPagina |
                Select-Object -Property $props |
                Format-Table -AutoSize -Wrap
        }

        Write-Host ""
        Write-Host "   [P] Anterior   [G] Ir para pagina   [Q] Sair" -ForegroundColor Yellow
        Write-Host ("   [C] Colunas   [B] Buscar por nome   [T] Itens por pagina (atual: {0})" -f $ItensPorPagina) -ForegroundColor Yellow
        Write-Host "   (ENTER = proxima pagina)" -ForegroundColor DarkGray
        Write-Host ""

        $op = (Read-Host "   Opcao").Trim()

        if ($op -eq "") {
            if ($pagina -lt $paginas) { $pagina++ }
        }
        elseif ($op -eq "P") {
            if ($pagina -gt 1) { $pagina-- }
        }
        elseif ($op -eq "G") {
            $alvo = 0
            $txt  = Read-Host "   Numero da pagina (1 a $paginas)"
            if ([int]::TryParse($txt, [ref]$alvo) -and $alvo -ge 1 -and $alvo -le $paginas) {
                $pagina = $alvo
            }
            else {
                Write-Host "  Pagina invalida." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
        elseif ($op -eq "C") {
            Show-EscolhaColunas -Colunas $colunas
        }
        elseif ($op -eq "B") {
            $busca  = (Read-Host "   Texto a buscar no nome (ENTER limpa a busca)").Trim()
            $pagina = 1
        }
        elseif ($op -eq "T") {
            $qtd = 0
            $txt = Read-Host "   Itens por pagina (5 a 50)"
            if ([int]::TryParse($txt, [ref]$qtd) -and $qtd -ge 5 -and $qtd -le 50) {
                $ItensPorPagina = $qtd
                $pagina = 1
            }
            else {
                Write-Host "  Valor invalido." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
        elseif ($op -eq "Q" -or $op -eq "0") {
            $sair = $true
        }
    } while (-not $sair)

    Clear-Host
    Write-Host ("  " + (Get-ResumoApps -Apps $apps)) -ForegroundColor Green
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
    $conteudo += "Versao do script: $ScriptVersao"
    $conteudo += ""
    $conteudo += "--- RESUMO ---";            $conteudo += (Get-InfoResumo     | Format-List   | Out-String)
    $conteudo += "--- SISTEMA OPERACIONAL ---"; $conteudo += (Get-InfoSO       | Format-List   | Out-String)
    $conteudo += "--- BIOS / PLACA-MAE ---";  $conteudo += (Get-InfoBiosPlaca  | Format-List   | Out-String)
    $conteudo += "--- MEMORIA ---";           $conteudo += (Get-InfoMemoria    | Format-Table -AutoSize | Out-String)
    $conteudo += "--- VOLUMES ---";           $conteudo += (Get-InfoVolumes    | Format-Table -AutoSize | Out-String)
    $conteudo += "--- REDE ---";              $conteudo += (Get-InfoRede       | Format-List   | Out-String)
    $conteudo += "--- ACESSO REMOTO (ANYDESK) ---"; $conteudo += (Get-InfoAnyDesk | Format-List | Out-String)

    $usuariosRel = @(Get-InfoUsuarios)
    $conteudo += "--- USUARIOS ---"
    $conteudo += ([string]($usuariosRel | Format-Table -AutoSize | Out-String -Width 250)).TrimEnd()
    $conteudo += (Get-ResumoUsuarios -Usuarios $usuariosRel)
    $conteudo += ""

    $appsRel = @(Get-InfoApps)
    $conteudo += "--- APLICATIVOS INSTALADOS ---"
    $conteudo += ([string]($appsRel | Format-Table -AutoSize | Out-String -Width 250)).TrimEnd()
    $conteudo += (Get-ResumoApps -Apps $appsRel)

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

#region ---------- Formato do relatorio e exportacao CSV ----------

function Read-FormatoRelatorio {
    # Pergunta o formato do relatorio. Retorna "txt", "csv" ou $null (cancelou).
    # ENTER = txt. O formato .json ainda nao esta disponivel ("em breve").
    while ($true) {
        Clear-Host
        Write-Titulo "FORMATO DO RELATORIO"
        Write-Host ""
        Write-Host "   [1] .txt   texto para ler (padrao)"
        Write-Host "   [2] .csv   planilha: uma tabela unica, abre no Excel"
        Write-Host "   [3] .json  em breve" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "   [0] Cancelar        (ENTER = .txt)" -ForegroundColor DarkGray
        Write-Host ""

        $r = (Read-Host "   Escolha uma opcao").Trim()

        if ($r -eq "" -or $r -eq "1") { return "txt" }
        elseif ($r -eq "2")           { return "csv" }
        elseif ($r -eq "0")           { return $null }
        elseif ($r -eq "3") {
            Write-Host "  O formato .json estara disponivel em breve." -ForegroundColor Yellow
            Start-Sleep -Seconds 1
        }
        else {
            Write-Host "  Opcao invalida." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}

function ConvertTo-TextoCsv {
    # Converte um valor em texto para o CSV.
    # - numeros decimais usam a cultura atual (virgula no pt-BR), igual ao relatorio .txt
    # - valores que comecam com = + - @ ganham um apostrofo na frente: evita que o Excel
    #   execute o conteudo como formula (ex.: nome de aplicativo malicioso no Registro)
    param($Valor)

    if ($null -eq $Valor) { return "" }

    $texto = ""
    if ($Valor -is [double] -or $Valor -is [single] -or $Valor -is [decimal]) {
        $texto = $Valor.ToString()
    }
    else {
        $texto = [string]$Valor
    }

    if ($texto -match '^[=+\-@]') { $texto = "'" + $texto }
    return $texto
}

function New-LinhaCsv {
    param($Maquina, $Data, $Secao, $Item, $Campo, $Valor)

    [PSCustomObject]@{
        "Maquina"    = $Maquina
        "DataColeta" = $Data
        "Secao"      = $Secao
        "Item"       = (ConvertTo-TextoCsv $Item)
        "Campo"      = $Campo
        "Valor"      = (ConvertTo-TextoCsv $Valor)
    }
}

function ConvertTo-LinhasCsvLongo {
    # Formato longo: uma linha por informacao.
    #   Maquina ; DataColeta ; Secao ; Item ; Campo ; Valor
    # - Secoes de campos soltos (Resumo, SO...): Item vazio, um Campo por linha.
    # - Secoes de tabela (memoria, usuarios, aplicativos...): Item = identificador da linha
    #   (slot, usuario, nome do aplicativo...) e um Campo por coluna.
    param([Parameter(Mandatory)]$Catalogo)

    $maquina = $env:COMPUTERNAME
    $data    = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $linhas  = New-Object System.Collections.ArrayList

    # Metadado: versao do script que gerou o arquivo
    [void]$linhas.Add((New-LinhaCsv -Maquina $maquina -Data $data -Secao "Relatorio" -Item "" -Campo "Versao do script" -Valor $ScriptVersao))

    foreach ($s in $Catalogo) {
        if ($s.Tipo -eq "campos") {
            foreach ($c in $s.Campos) {
                if (-not $c.Marcado) { continue }
                [void]$linhas.Add((New-LinhaCsv -Maquina $maquina -Data $data -Secao $s.Titulo -Item "" -Campo $c.Nome -Valor $c.Valor))
            }
        }
        elseif ($s.Marcado) {
            foreach ($registro in @($s.Dados)) {
                $props = @($registro.PSObject.Properties)
                if ($props.Count -eq 0) { continue }

                # Coluna usada como "Item": a chave da secao (ou a primeira coluna, se nao existir)
                $nomeChave = $props[0].Name
                foreach ($p in $props) {
                    if ($p.Name -eq $s.Chave) { $nomeChave = $s.Chave }
                }
                $valorChave = $registro.PSObject.Properties[$nomeChave].Value

                foreach ($p in $props) {
                    if ($p.Name -eq $nomeChave) { continue }
                    [void]$linhas.Add((New-LinhaCsv -Maquina $maquina -Data $data -Secao $s.Titulo -Item $valorChave -Campo $p.Name -Valor $p.Value))
                }
            }
        }
    }

    return $linhas
}

function Export-RelatorioCsv {
    param(
        [Parameter(Mandatory)][string]$Pasta,
        [Parameter(Mandatory)]$Catalogo,
        [string]$Prefixo = "Inventario"
    )

    if (-not (Test-Path -LiteralPath $Pasta -PathType Container)) {
        Write-Host ""
        Write-Host "  Pasta nao encontrada: $Pasta" -ForegroundColor Red
        return
    }

    $destino = Join-Path $Pasta `
                         ("{0}_{1}_{2:yyyy-MM-dd_HHmm}.csv" -f $Prefixo, $env:COMPUTERNAME, (Get-Date))

    $linhas = @(ConvertTo-LinhasCsvLongo -Catalogo $Catalogo)

    try {
        # ';' e o separador padrao do Excel em portugues.
        # -Encoding UTF8 no Windows PowerShell 5.1 grava com BOM, que o Excel precisa para abrir os acentos certo.
        $linhas | Export-Csv -LiteralPath $destino -Delimiter ";" -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
        Write-Host ""
        Write-Host "  Relatorio salvo em:" -ForegroundColor Green
        Write-Host "  $destino" -ForegroundColor White
        Write-Host ("  Linhas gravadas: {0}" -f $linhas.Count) -ForegroundColor DarkGray
    }
    catch {
        Write-Host ""
        Write-Host "  Falha ao salvar o relatorio em: $Pasta" -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)" -ForegroundColor DarkRed
        Write-Host "  Dica: escolha outra pasta (sem restricao de gravacao)." -ForegroundColor Yellow
    }
}

function Export-RelatorioCompleto {
    # Inventario completo no formato escolhido ("txt" ou "csv")
    param(
        [Parameter(Mandatory)][string]$Pasta,
        [Parameter(Mandatory)][string]$Formato
    )

    if ($Formato -eq "csv") {
        Write-Host ""
        Write-Host "  Coletando informacoes desta maquina (a lista de aplicativos pode levar alguns segundos)..." -ForegroundColor DarkGray
        $catalogo = Get-CatalogoInventario
        Export-RelatorioCsv -Pasta $Pasta -Catalogo $catalogo -Prefixo "Inventario"
    }
    else {
        Export-Relatorio -Pasta $Pasta
    }
}

#endregion

#region ---------- Inventario personalizado (prototipo) ----------

function Get-CatalogoInventario {
    # Coleta tudo uma vez e monta o catalogo de secoes:
    #   Tipo "campos" : objeto plano (Nome = Valor); o usuario marca campo a campo
    #   Tipo "tabela" : varias linhas (slots, volumes, adaptadores); marca o bloco inteiro
    $catalogo = New-Object System.Collections.ArrayList

    $planas = @(
        [PSCustomObject]@{ Titulo = "Resumo";                 Dados = (Get-InfoResumo) },
        [PSCustomObject]@{ Titulo = "Sistema operacional";    Dados = (Get-InfoSO) },
        [PSCustomObject]@{ Titulo = "BIOS / Placa-mae / TPM"; Dados = (Get-InfoBiosPlaca) },
        [PSCustomObject]@{ Titulo = "Acesso remoto (AnyDesk)"; Dados = (Get-InfoAnyDesk) }
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

    $usuarios = @(Get-InfoUsuarios)
    $apps     = @(Get-InfoApps)

    $tabelas = @(
        [PSCustomObject]@{ Titulo = "Memoria RAM (por slot)";  Formato = "tabela"; Chave = "Slot";      Dados = @(Get-InfoMemoria) },
        [PSCustomObject]@{ Titulo = "Volumes de disco";        Formato = "tabela"; Chave = "Unidade";   Dados = @(Get-InfoVolumes) },
        [PSCustomObject]@{ Titulo = "Rede";                    Formato = "lista";  Chave = "Adaptador"; Dados = @(Get-InfoRede) },
        [PSCustomObject]@{ Titulo = "Usuarios da maquina"; Formato = "tabela"; Chave = "Usuario"; Dados = $usuarios; Rodape = (Get-ResumoUsuarios -Usuarios $usuarios) },
        [PSCustomObject]@{ Titulo = "Aplicativos instalados"; Formato = "tabela"; Chave = "Nome"; Dados = $apps; Rodape = (Get-ResumoApps -Apps $apps) }
    )

    foreach ($t in $tabelas) {
        [void]$catalogo.Add([PSCustomObject]@{
            Tipo = "tabela"; Titulo = $t.Titulo; Formato = $t.Formato
            Campos = $null; Dados = $t.Dados; Marcado = $true; Rodape = $t.Rodape; Chave = $t.Chave
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
    $mapa = @{
        "Resumo"                  = @("Marca", "Modelo", "MTM", "MO", "S/N")
        "Acesso remoto (AnyDesk)" = @("AnyDesk instalado", "AnyDesk portable")
    }
    foreach ($s in $Catalogo) {
        if ($s.Tipo -eq "campos") {
            foreach ($c in $s.Campos) {
                $nomes = @()
                if ($mapa.ContainsKey($s.Titulo)) { $nomes = $mapa[$s.Titulo] }
                $c.Marcado = ($nomes -contains $c.Nome)
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
        Write-Host "   [A] Marcar tudo   [L] Limpar tudo   [B] So identificacao (marca, modelo, MTM, MO, S/N, AnyDesk)"
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
    [void]$linhas.Add("Versao do script: $ScriptVersao")
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
            if ($s.Rodape) { [void]$linhas.Add([string]$s.Rodape) }
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
    param([string]$Formato = "txt")

    Write-Titulo "INVENTARIO PERSONALIZADO"
    Write-Host ""
    Write-Host "  Coletando informacoes desta maquina (a lista de aplicativos pode levar alguns segundos)..." -ForegroundColor DarkGray

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

    if ($Formato -eq "csv") {
        Export-RelatorioCsv -Pasta $pasta -Catalogo $catalogo -Prefixo "Inventario_Personalizado"
    }
    else {
        Export-RelatorioPersonalizado -Pasta $pasta -Catalogo $catalogo
    }
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
                # Se cancelar na pergunta de formato, volta para este submenu
                $formato = Read-FormatoRelatorio
                if ($formato) {
                    Export-RelatorioCompleto -Pasta ([Environment]::GetFolderPath("Desktop")) -Formato $formato
                    Pausar
                    $voltar = $true
                }
            }
            "2" {
                $formato = Read-FormatoRelatorio
                if ($formato) {
                    Write-Host ""
                    Write-Host "  Abrindo janela de selecao..." -ForegroundColor DarkGray
                    $pasta = Select-PastaDestino
                    if ($pasta) {
                        Export-RelatorioCompleto -Pasta $pasta -Formato $formato
                    }
                    else {
                        Write-Host ""
                        Write-Host "  Nenhuma pasta selecionada. Operacao cancelada." -ForegroundColor Yellow
                    }
                    Pausar
                    $voltar = $true
                }
            }
            "3" {
                $formato = Read-FormatoRelatorio
                if ($formato) {
                    Invoke-InventarioPersonalizado -Formato $formato
                    Pausar
                    $voltar = $true
                }
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
    Write-Host ("   Versao:   v{0}" -f $ScriptVersao) -ForegroundColor DarkGray
    Write-Host "   Contexto: " -NoNewline; Write-Host $admin -ForegroundColor $cor
    Write-Host ""
    Write-Host "   [1] Resumo geral (marca, modelo, S/N, CPU, GPU, RAM, discos)"
    Write-Host "   [2] Sistema operacional"
    Write-Host "   [3] BIOS / Placa-mae / TPM"
    Write-Host "   [4] Memoria RAM (por slot)"
    Write-Host "   [5] Discos fisicos e volumes"
    Write-Host "   [6] Rede (IP, MAC, gateway, DNS)"
    Write-Host "   [7] Usuarios da maquina (local / administrador)"
    Write-Host "   [8] Aplicativos instalados (lista paginada)"
    Write-Host "   [9] AnyDesk (codigo de acesso)"
    Write-Host "   [10] TUDO na tela"
    Write-Host "   [11] Baixar relatorio (Area de Trabalho ou local a escolher)"
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
            Write-Titulo "USUARIOS DA MAQUINA"
            Show-InfoUsuarios
            Pausar
        }
        "8" {
            Write-Titulo "APLICATIVOS INSTALADOS"
            Write-Host "  Coletando (pode levar alguns segundos)..." -ForegroundColor DarkGray
            Show-InfoApps
            Pausar
        }
        "9" {
            Write-Titulo "ANYDESK"
            Get-InfoAnyDesk | Format-List
            Pausar
        }
        "10" {
            Write-Titulo "RESUMO GERAL";          Get-InfoResumo    | Format-List
            Write-Titulo "SISTEMA OPERACIONAL";   Get-InfoSO        | Format-List
            Write-Titulo "BIOS / PLACA-MAE";      Get-InfoBiosPlaca | Format-List
            Write-Titulo "MEMORIA RAM";           Get-InfoMemoria   | Format-Table -AutoSize
            Write-Titulo "VOLUMES";               Get-InfoVolumes   | Format-Table -AutoSize
            Write-Titulo "REDE";                  Get-InfoRede      | Format-List
            Write-Titulo "ACESSO REMOTO (ANYDESK)"; Get-InfoAnyDesk | Format-List
            Write-Titulo "USUARIOS DA MAQUINA";    Show-InfoUsuarios
            Write-Titulo "APLICATIVOS INSTALADOS"; Show-InfoAppsLista
            Pausar
        }
        "11" {
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
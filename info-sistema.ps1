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

function Show-SubMenuExportar {
    $voltar = $false
    do {
        Clear-Host
        Write-Titulo "BAIXAR RELATORIO"
        Write-Host ""
        Write-Host "   [1] Exportar para a Area de Trabalho"
        Write-Host "   [2] Selecionar local de download (abre janela)"
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

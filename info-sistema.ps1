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

    [PSCustomObject]@{
        "Marca"    = $cs.Manufacturer
        "Modelo"   = $cs.Model
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

function Get-InfoMemoria {
    Get-CimInstance Win32_PhysicalMemory | ForEach-Object {
        [PSCustomObject]@{
            "Slot"       = $_.DeviceLocator
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
        [PSCustomObject]@{
            "Unidade"    = $_.DeviceID
            "Rotulo"     = $_.VolumeName
            "Sistema Arq"= $_.FileSystem
            "Total (GB)" = $totalGB
            "Livre (GB)" = $livreGB
            "% Livre"    = if ($_.Size -gt 0) { [math]::Round(($_.FreeSpace / $_.Size) * 100, 1) } else { 0 }
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
    $tpm = try { (Get-CimInstance -Namespace "root\cimv2\security\microsofttpm" -ClassName Win32_Tpm -ErrorAction Stop) } catch { $null }

    [PSCustomObject]@{
        "BIOS"          = $bio.Name
        "Versao BIOS"   = ($bio.SMBIOSBIOSVersion)
        "Data BIOS"     = $bio.ReleaseDate
        "S/N Chassi"    = $bio.SerialNumber
        "Placa-mae"     = "$($mb.Manufacturer) $($mb.Product)"
        "S/N Placa-mae" = $mb.SerialNumber
        "Modo Boot"     = if ($env:firmware_type) { $env:firmware_type } else { "N/D" }
        "Secure Boot"   = try { (Confirm-SecureBootUEFI -ErrorAction Stop) } catch { "N/D" }
        "TPM presente"  = if ($tpm) { "$($tpm.SpecVersion)" } else { "Nao detectado / requer admin" }
    }
}

#endregion

#region ---------- Exportacao ----------

function Export-Relatorio {
    $destino = Join-Path ([Environment]::GetFolderPath("Desktop")) `
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

    $conteudo | Out-File -FilePath $destino -Encoding UTF8
    Write-Host ""
    Write-Host "Relatorio salvo em:" -ForegroundColor Green
    Write-Host "  $destino" -ForegroundColor White
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
    Write-Host "   [8] Exportar relatorio para a Area de Trabalho"
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
            Write-Titulo "EXPORTANDO"
            Export-Relatorio
            Pausar
        }
        "0" {
            Write-Host ""
            Write-Host "  Encerrando..." -ForegroundColor DarkGray
        }
        default {
            Write-Host "  Opcao invalida." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
} while ($opcao -ne "0")

#endregion

function Normalize-String {
    param([string]$text)
    if (-not $text) { return "N/A" }
    $normalized = $text.Normalize([Text.NormalizationForm]::FormD)
    $noAccents = -join ($normalized.ToCharArray() | Where-Object {
        [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne "NonSpacingMark"
    })
    return ($noAccents -replace "[^A-Za-z0-9 .,-]", "").Trim()
}

$info = [ordered]@{}

try {
    # 1. Componentes Base
    $sys   = Get-CimInstance Win32_ComputerSystem
    $os    = Get-CimInstance Win32_OperatingSystem
    $bios  = Get-CimInstance Win32_BIOS
    $cpu   = Get-CimInstance Win32_Processor
    $driveC = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"

    $info["Data da Coleta"]   = (Get-Date).ToString("dd/MM/yyyy HH:mm")
    $info["Nome do PC"]       = Normalize-String $env:COMPUTERNAME
    $info["Fabricante"]       = Normalize-String $sys.Manufacturer
    $info["Modelo"]           = Normalize-String $sys.Model
    $info["Numero de Serie"]  = Normalize-String $bios.SerialNumber
    
    # 2. Processamento e Memoria
    $info["Processador"]      = Normalize-String $cpu.Name
    $physicalRAM = (Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum / 1GB
    $info["RAM Instalada GB"] = [math]::Round($physicalRAM, 0)

    # 3. Armazenamento (Logica Multi-nivel)
    $pDisk = Get-PhysicalDisk | Select-Object -First 1
    if (-not $pDisk) { $pDisk = Get-CimInstance Win32_DiskDrive | Select-Object -First 1 }

    $info["Tipo do Disco"]    = if ($pDisk.MediaType) { $pDisk.MediaType } else { "SSD" }
    $info["Saude do Disco"]   = if ($pDisk.HealthStatus) { $pDisk.HealthStatus } else { "Saudavel" }
    $info["Capacidade Total"] = "$([math]::Round(($pDisk.Size / 1GB), 2)) GB"
    $info["Espaco Livre C:"]  = "$([math]::Round(($driveC.FreeSpace / 1GB), 2)) GB"

    # 4. Saude da Bateria (Exclusivo Notebook)
    $battery = Get-CimInstance -ClassName Win32_Battery
    if ($battery) {
        $info["Bateria Status"] = "$($battery.EstimatedChargeRemaining)%"
    }

    # 5. Sistema Operacional
    $info["Windows"]          = Normalize-String $os.Caption
    $info["Versao Build"]     = $os.Version
    $info["Arquitetura"]      = $os.OSArchitecture

} catch {
    Write-Host "Ocorreu um erro na coleta: $($_.Exception.Message)" -ForegroundColor Red
}

# --- Exportacao Corrigida ---
$fileName = "Info_$($info['Nome do PC']).txt"
$path = Join-Path -Path $env:USERPROFILE\Desktop -ChildPath $fileName

$relatorio = $info.GetEnumerator() | ForEach-Object { "{0,-20}: {1}" -f $_.Key, $_.Value }
$utf8 = New-Object System.Text.UTF8Encoding($false)

try {
    [System.IO.File]::WriteAllLines($path, $relatorio, $utf8)
    $info | Out-String | Write-Host -ForegroundColor Cyan
    Write-Host "Relatorio salvo com sucesso em: $path" -ForegroundColor Green
} catch {
    Write-Host "Erro ao salvar arquivo: $($_.Exception.Message)" -ForegroundColor Red
}
# Проверка доступности интернета для Prometheus
# Оригинал: local/tools/prometheus/exporters/internet-access.ps1

$TestHost = "8.8.8.8"  # Google DNS
$TestTimeout = 1000    # ms
$Port = 53             # DNS
$Duration = 10         # секунд (не используется явно)
$OutputFile = "C:\monitoring\internet_metrics.prom"

if (-not (Test-Path -Path (Split-Path -Path $OutputFile -Parent))) {
    New-Item -ItemType Directory -Path (Split-Path -Path $OutputFile -Parent) -Force
}

function Test-InternetConnection {
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $asyncResult = $tcpClient.BeginConnect($TestHost, $Port, $null, $null)
        $waitResult = $asyncResult.AsyncWaitHandle.WaitOne($TestTimeout, $false)
        if ($waitResult -and $tcpClient.Connected) {
            $tcpClient.EndConnect($asyncResult)
            $tcpClient.Close()
            return $true
        } else {
            $tcpClient.Close()
            return $false
        }
    } catch {
        return $false
    }
}

$success = if (Test-InternetConnection) { 1 } else { 0 }

$metrics = @()
$metrics += "# HELP internet_access_success Интернет доступен (1 — да, 0 — нет)"
$metrics += "# TYPE internet_access_success gauge"
$metrics += "internet_access_success $success"

$metrics -join "`n" | Set-Content -Path $OutputFile -Encoding UTF8


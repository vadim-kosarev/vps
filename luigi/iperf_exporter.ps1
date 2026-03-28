# Экспортер скорости через iperf3 для Prometheus
# Оригинал: local/tools/prometheus/exporters/iperf_exporter/iperf_exporter.ps1

function Is-Numeric {
    param ($value)
    return ($value -is [int] -or $value -is [double] -or $value -is [decimal])
}

# Настройки
$iperfServer = "vkosarev.name"   # IP или DNS iperf3-сервера
$port = 5201
$outputFile = "C:\monitoring\iperf3.prom"

# Создать папку, если нет
if (-not (Test-Path "C:\monitoring")) {
    New-Item -Path "C:\monitoring" -ItemType Directory | Out-Null
}

# Запуск теста (5 секунд)
$iperfOutput = & .\iperf3.exe -c $iperfServer -p $port -J -t 5 2>&1

# Парсинг JSON-ответа
try {
    $json = $iperfOutput | ConvertFrom-Json
} catch {
    Write-Host "Не удалось распарсить ответ iperf3"
    exit 1
}

# Извлечение upload/download
$upload_bps = $json.end.sum_sent.bytes_per_second
$download_bps = $json.end.sum_received.bytes_per_second

$timestamp = [int][double]::Parse((Get-Date -UFormat %s))

# Формирование метрик
$metrics = @()

# === Время старта ===
$metrics += "# HELP iperf3_start_time_utc_seconds Test start timestamp (UTC)"
$metrics += "# TYPE iperf3_start_time_utc_seconds gauge"
$metrics += "iperf3_start_time_utc_seconds $($json.start.timestamp.timesecs)"

# === CPU ===
$cpu = $json.end.cpu_utilization_percent
foreach ($field in $cpu.PSObject.Properties) {
    $metrics += "# HELP iperf3_cpu_$($field.Name) CPU usage percent"
    $metrics += "# TYPE iperf3_cpu_$($field.Name) gauge"
    $metrics += "iperf3_cpu_$($field.Name) $($field.Value)"
}

# === Метрики передачи ===
foreach ($dir in @("sum_sent", "sum_received")) {
    $obj = $json.end.$dir
    $metrics += "# HELP iperf3_${dir}_bytes Bytes transferred"
    $metrics += "# TYPE iperf3_${dir}_bytes gauge"
    $metrics += "iperf3_${dir}_bytes $($obj.bytes)"

    $metrics += "# HELP iperf3_${dir}_bps Bits per second"
    $metrics += "# TYPE iperf3_${dir}_bps gauge"
    $metrics += "iperf3_${dir}_bps $($obj.bits_per_second)"
}

# === Итоговые upload/download ===
$metrics += "# HELP iperf3_upload_bps Upload bandwidth (bytes/sec)"
$metrics += "# TYPE iperf3_upload_bps gauge"
$metrics += "iperf3_upload_bps $upload_bps"

$metrics += "# HELP iperf3_download_bps Download bandwidth (bytes/sec)"
$metrics += "# TYPE iperf3_download_bps gauge"
$metrics += "iperf3_download_bps $download_bps"

# Сохраняем метрики
$metrics -join "`n" | Set-Content -Path $outputFile -Encoding UTF8


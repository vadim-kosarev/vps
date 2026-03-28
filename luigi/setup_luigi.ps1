# Автоматизация запуска мониторинговых сервисов на luigi
# Формат отчёта:  - Имя шага : результат

$report = @()
$report += "--- ОТЧЁТ ПО ЗАПУСКУ LUIGI ---"

function Log-Step($step, $result) {
    $report += " - $step : $result"
}

# Проверка наличия iperf3.exe
if (Test-Path "./iperf3.exe") {
    Log-Step "Проверка iperf3.exe" "Найден"
} else {
    Log-Step "Проверка iperf3.exe" "Не найден! Поместите iperf3.exe рядом с iperf_exporter.ps1"
}

# Запуск iperf_exporter-run.ps1
try {
    Start-Process powershell -ArgumentList '-ExecutionPolicy Bypass -File ./iperf_exporter-run.ps1' -WindowStyle Hidden
    Log-Step "Запуск iperf_exporter-run.ps1" "OK (запущен в фоне)"
} catch {
    Log-Step "Запуск iperf_exporter-run.ps1" $_.Exception.Message
}

# Запуск internet-access-runner.ps1
try {
    Start-Process powershell -ArgumentList '-ExecutionPolicy Bypass -File ./internet-access-runner.ps1' -WindowStyle Hidden
    Log-Step "Запуск internet-access-runner.ps1" "OK (запущен в фоне)"
} catch {
    Log-Step "Запуск internet-access-runner.ps1" $_.Exception.Message
}

# Проверка метрик
Start-Sleep -Seconds 5
if (Test-Path "C:/monitoring/iperf3.prom") {
    Log-Step "Проверка iperf3.prom" "OK"
} else {
    Log-Step "Проверка iperf3.prom" "Файл не найден"
}
if (Test-Path "C:/monitoring/internet_metrics.prom") {
    Log-Step "Проверка internet_metrics.prom" "OK"
} else {
    Log-Step "Проверка internet_metrics.prom" "Файл не найден"
}

$report += "--- КОНЕЦ ОТЧЁТА ---"
$report -join "`n" | Set-Content -Path "../.tmp/luigi_setup_report.log" -Encoding UTF8
Write-Host "Отчёт записан в .tmp/luigi_setup_report.log"


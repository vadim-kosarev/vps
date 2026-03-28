# Циклический запуск проверки доступности интернета
# Оригинал: local/tools/prometheus/exporters/internet-access-runner.ps1

while ($true) {
    & ".\internet-access.ps1"
    Start-Sleep -Seconds 60
}


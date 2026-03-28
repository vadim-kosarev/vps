# Хост luigi

Рабочая Windows-машина в локальной сети, используется для мультимедиа, мониторинга и тестирования.

## Основные сервисы и экспортеры

| Сервис/Экспортер      | Описание/Назначение                | Порт(ы)      | Как запущен/служба         |
|----------------------|-------------------------------------|--------------|----------------------------|
| iperf_exporter       | Экспортер скорости через iperf3     | 9115         | Служба IPerfExporter        |
| InternetExporter     | Проверка доступности интернета      | 9182         | Служба InternetExporter     |
| windows_exporter     | Экспортер метрик Windows            | 9182         | Служба windows_exporter     |
| Prometheus           | Сбор метрик                         | 9090         | Служба Prometheus           |
| Grafana              | Дашборды, визуализация              | 3000         | Служба Grafana              |
| Subsonic             | Музыкальный сервер                  | 4040, 9412   | Службы subsonic-service/agent|
| qBittorrent          | Торрент-клиент                      | 3535, 24222  | Приложение qBittorrent      |

## Мониторинг и тестирование
- Все экспортеры интегрированы с Prometheus и Grafana.
- Для проверки скорости интернета используется iperf_exporter (порт 9115).
- InternetExporter и windows_exporter предоставляют метрики о доступности и состоянии системы.
- Grafana доступна на http://luigi:3000 (или через reverse proxy).
- Subsonic: http://luigi:4040 и http://luigi:9412.
- qBittorrent web-интерфейс: http://luigi:3535 и http://luigi:24222.

## Управление
- Удалённое администрирование через PowerShell Remoting:
  - `Enter-PSSession -ComputerName luigi -Credential luigi\local-admin`
- Все сервисы оформлены как службы (часть через NSSM), автозапуск.

## Документация
- Подробный отчёт о диагностике и настройке: см. `.ai/2026.03.28_luigi_diagnostics_report.md`
- Описание сервисов и mindmap: см. `local/tools/README.md`

---

# Инструкция по запуску мониторинга на luigi

## Проверка скорости интернета (iperf_exporter)
- iperf_exporter.ps1 — основной скрипт экспорта метрик скорости
- iperf_exporter-run.ps1 — циклический запуск (PowerShell)
- iperf_exporter-run.cmd — циклический запуск (cmd)

### Пример запуска вручную:
```powershell
powershell -ExecutionPolicy Bypass -File .\iperf_exporter.ps1
```

### Циклический запуск (PowerShell):
```powershell
powershell -ExecutionPolicy Bypass -File .\iperf_exporter-run.ps1
```

### Циклический запуск (cmd):
```bat
iperf_exporter-run.cmd
```

## Проверка доступности интернета
- internet-access.ps1 — основной скрипт
- internet-access-runner.ps1 — циклический запуск

### Пример запуска вручную:
```powershell
powershell -ExecutionPolicy Bypass -File .\internet-access.ps1
```

### Циклический запуск:
```powershell
powershell -ExecutionPolicy Bypass -File .\internet-access-runner.ps1
```

---
- Все метрики пишутся в C:\monitoring\ и подхватываются Prometheus (см. основной README).
- Для speedtest требуется iperf3.exe (поместить рядом с iperf_exporter.ps1).

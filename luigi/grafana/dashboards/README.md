# Дашборды Grafana (luigi)

Живые дашборды хранятся в `grafana.db` (sqlite) на самой luigi, а не провижинятся
из файлов. JSON-файлы в этой папке — это snapshot текущего состояния дашборда
для истории/бэкапа, экспортированный через Grafana HTTP API
(`GET /api/dashboards/uid/<uid>`). Изменения в самой Grafana этот файл
автоматически не подхватывают — при следующем значимом изменении дашборда
нужно заново экспортировать и закоммитить JSON.

| Файл | Дашборд | URL |
|---|---|---|
| `nvidia-gpu-metrics.json` | Nvidia GPU Metrics — по строке (row) на каждый хост с GPU: Starlight (RTX 4060 Ti) и Brightsky (RTX 3060 Ti) | `http://luigi:3000/d/vlvPlrgnk/nvidia-gpu-metrics` |

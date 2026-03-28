# Prometheus (Docker migration)

- prometheus.yml — основной конфиг (актуальный, считан с luigi)
- data/ — каталог для хранения данных TSDB (создастся автоматически контейнером)

## Пример volume-маппинга для docker-compose:

```yaml
  prometheus:
    image: prom/prometheus:v3.2.1
    container_name: prometheus
    restart: unless-stopped
    extra_hosts:
      - "host.docker.internal:host-gateway"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ./prometheus/data:/prometheus
    command:
      - "--config.file=/etc/prometheus/prometheus.yml"
      - "--storage.tsdb.path=/prometheus"
      - "--storage.tsdb.retention.time=90d"
      - "--web.enable-lifecycle"
    ports:
      - "9090:9090"
```


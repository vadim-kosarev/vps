# Grafana (Docker migration)

В эту папку копируются:
- data/grafana.db
- conf/ (весь)
- data/plugins/ (весь)

Пример volume-маппинга для docker-compose:

```yaml
  grafana:
    image: grafana/grafana:10.4.2
    volumes:
      - ./grafana/data/grafana.db:/var/lib/grafana/grafana.db
      - ./grafana/conf:/etc/grafana
      - ./grafana/data/plugins:/var/lib/grafana/plugins
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=yourpassword
    ports:
      - "3000:3000"
    restart: unless-stopped
```


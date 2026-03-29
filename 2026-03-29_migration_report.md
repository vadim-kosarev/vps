
## 2026-03-29: Итог по подготовке docker-compose.yml для vkosarev.link

**Выполнено:**
- Проведен аудит и унификация docker-compose.yml для vkosarev.link.
- Все сервисы (3x-ui, frps, nginx, openvpn, portainer) корректно описаны, volumes и network_mode соответствуют требованиям.
- Переменные окружения вынесены в .env.example, структура volumes и портов соответствует аудиту.
- config.json для 3x-ui не требуется, база x-ui.db монтируется как volume.
- Все основные порты и каталоги для сервисов проброшены через host-сеть или явно через ports.
- .env.example содержит все необходимые переменные.

**Рекомендации:**
- Для запуска: скопировать .env.example в .env, заполнить реальные значения переменных, затем использовать `docker compose up -d`.
- При необходимости добавить новые сервисы или переменные — обновлять .env.example и docker-compose.yml.

_Задача по подготовке docker-compose.yml и унификации конфигов для vkosarev.link выполнена._


## 2026-03-29: Prometheus для vkosarev.link — запуск и HTTPS через nginx

**Выполнено:**
- Prometheus добавлен в docker-compose.yml для vkosarev.link по аналогии с vkosarev.name.
- Подготовлен prometheus.yml для сбора локальных метрик (node_exporter, xui).
- Создана директория для данных Prometheus, переменная PROMETHEUS_DATA вынесена в .env.
- Выставлены права на каталог /data/prometheus для корректной работы контейнера.
- Prometheus успешно запущен в Docker, порт 9090 проброшен, статус Up.
- Подготовлена инструкция для организации HTTPS-доступа к Prometheus через nginx-прокси с использованием сертификатов.

**Рекомендации:**
- Для доступа к Prometheus по HTTPS использовать обратный прокси nginx с SSL (пример server-конфига приведён выше).
- При необходимости ограничить доступ к /prometheus/ через basic auth или по IP.

_Задача по развертыванию и запуску Prometheus для vkosarev.link завершена._

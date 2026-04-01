#!/usr/bin/env python3
"""
check.py - Проверка доступности всех сервисов vkosarev.name

Использование:
  python3 check.py                    # Проверить локальные сервисы (localhost)
  python3 check.py vkosarev.name      # Проверить удаленные сервисы по FQDN
  python3 check.py --help             # Справка

Примеры:
  python3 check.py                    # Проверить localhost
  python3 check.py 127.0.0.1          # Проверить локально
  python3 check.py vkosarev.name      # Проверить по FQDN
"""

import sys
import socket
import urllib.request
import urllib.error
import ssl
from urllib.parse import urlparse

GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
CYAN = "\033[96m"
ORANGE = "\033[38;5;208m"  # Оранжевый для WARN
RESET = "\033[0m"
BOLD = "\033[1m"


def parse_url(url):
    """
    Парсит URL и возвращает кортеж (protocol, host, port, path)
    
    Примеры:
        parse_url("http://vkosarev.name:3000/query")
        → ("http", "vkosarev.name", 3000, "/query")
        
        parse_url("https://example.com/")
        → ("https", "example.com", 443, "/")
        
        parse_url("tcp://localhost:5201")
        → ("tcp", "localhost", 5201, "")
    """
    parsed = urlparse(url)
    
    # Определяем порт по умолчанию если не указан
    if parsed.port:
        port = parsed.port
    elif parsed.scheme == "https":
        port = 443
    elif parsed.scheme == "http":
        port = 80
    elif parsed.scheme == "tcp":
        port = 0  # TCP обычно без порта по умолчанию
    else:
        port = 80
    
    # Путь (для HTTP/HTTPS запросов)
    path = parsed.path if parsed.path else "/"
    # Если path пуст, оставляем пустую строку для TCP
    if parsed.scheme == "tcp":
        path = ""
    
    return parsed.scheme, parsed.hostname, port, path

# ════════════════════════════════════════════════════════════════════════════════
# КОНФИГУРАЦИЯ СЕРВИСОВ
# ════════════════════════════════════════════════════════════════════════════════
# Формат: (Название, Локация, Категория, FullURL)
# - Название: отображаемое имя сервиса
# - Локация: Docker / Host / FRP-туннель
# - Категория: Мониторинг / Инфраструктура / Медиа / Видеонаблюдение / Утилиты
# - FullURL: полный URL для проверки (http://, https://, tcp://)
# ════════════════════════════════════════════════════════════════════════════════

SERVICES = [
    # 📊 Мониторинг
    ("Grafana", "Docker", "1. Мониторинг", "http://vkosarev.name:3000/"),
    ("Prometheus", "Docker", "1. Мониторинг", "http://vkosarev.name:9090/query"),
    ("node_exporter", "Host", "1. Мониторинг", "http://vkosarev.name:9100/metrics"),
    ("3x-ui Exporter", "Docker", "1. Мониторинг", "http://vkosarev.name:3001/metrics"),
    ("frps Dashboard", "Docker", "1. Мониторинг", "http://vkosarev.name:7599/"),
    
    # 🛠️ Инфраструктура
    ("Portainer", "Docker", "2. Инфраструктура", "https://vkosarev.name:9443/"),
    ("3x-ui", "Docker", "2. Инфраструктура", "https://vkosarev.name:2055/vkosarev.name.eu/"),
    ("Mermaid Live", "Docker", "2. Инфраструктура", "http://vkosarev.name:3200/"),
    ("MTProxy", "Docker", "2. Инфраструктура", "tcp://vkosarev.name:2443"),
    ("Myip", "Docker", "2. Инфраструктура", "http://vkosarev.name:88/"),
    
    # 📸 Медиа
    ("Immich", "FRP-туннель", "3. Медиа", "https://vkosarev.name:7601/"),
    ("Subsonic", "FRP-туннель", "3. Медиа", "http://vkosarev.name:4041/"),
    
    # 📷 Видеонаблюдение
    ("Frigate", "FRP-туннель", "4. Видеонаблюдение", "https://vkosarev.name:5001/"),
    ("HikCam", "FRP-туннель", "4. Видеонаблюдение", "https://vkosarev.name:981/"),
    
    # ⚡ Утилиты
    ("iperf3", "Docker", "5. Утилиты", "tcp://vkosarev.name:5201"),
]


def check_tcp(host, port, timeout=2.0):
    """Проверка TCP соединения"""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        result = sock.connect_ex((host, port))
        sock.close()
        if result == 0:
            return True, "соединение установлено"
        else:
            return False, f"отказано (errno {result})"
    except socket.timeout:
        return False, f"тайм-аут ({timeout}s)"
    except socket.gaierror as e:
        return False, f"хост не разрешен: {str(e)[:30]}"
    except Exception as e:
        return False, str(e)[:40]


def check_http(host, port, scheme, url_path="/", timeout=2.0):
    """
    Проверка HTTP/HTTPS доступности. Возвращает (available, status_code_or_error)
    Использует GET вместо HEAD для лучшей совместимости.
    Следует за редиректами один раз.
    """
    try:
        url = f"{scheme}://{host}:{port}{url_path}"
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        
        # Используем GET вместо HEAD для лучшей совместимости (например, Prometheus)
        req = urllib.request.Request(url, method='GET')
        req.add_header('User-Agent', 'curl/7.68.0')  # Добавляем User-Agent как curl
        
        try:
            with urllib.request.urlopen(req, timeout=timeout, context=ctx) as response:
                return True, response.status
        except urllib.error.HTTPError as e:
            # Если это редирект (301, 302, 303, 307, 308), следуем один раз
            if e.code in (301, 302, 303, 307, 308):
                location = e.headers.get('Location')
                if location:
                    # Пробуем с новой локацией
                    req2 = urllib.request.Request(location, method='GET')
                    req2.add_header('User-Agent', 'curl/7.68.0')
                    try:
                        with urllib.request.urlopen(req2, timeout=timeout, context=ctx) as response:
                            return True, response.status
                    except urllib.error.HTTPError as e2:
                        if 400 <= e2.code < 600:
                            return True, e2.code
                        return False, e2.code
            
            # HTTP ошибки (401, 403, 404 и т.д.) означают, что сервис работает
            if 400 <= e.code < 600:
                return True, e.code
            return False, e.code
    except socket.gaierror as e:
        return False, f"хост не разрешен: {str(e)[:30]}"
    except ssl.SSLError as e:
        return False, f"SSL ошибка: {str(e)[:35]}"
    except urllib.error.URLError as e:
        if isinstance(e.reason, socket.timeout):
            return False, f"тайм-аут ({timeout}s)"
        return False, str(e.reason)[:40]
    except Exception as e:
        return False, str(e)[:40]


def check_http_fallback(host, port, url_path="/", timeout=2.0):
    """
    Проверка HTTP/HTTPS с fallback и WARN для кодов не 200.
    Если HTTP вернул WARN - сразу пробуем HTTPS.
    Возвращает (available, diagnostic, is_warn)
    diagnostic содержит результаты обоих протоколов: "HTTP:200/HTTPS:200" или "HTTP:404/HTTPS:401"
    """
    # Сначала пробуем http
    available_http, status_http = check_http(host, port, "http", url_path, timeout)
    
    # Пробуем https
    available_https, status_https = check_http(host, port, "https", url_path, timeout)
    
    # Форматируем диагностику: показываем оба результата
    if isinstance(status_http, int):
        http_diag = str(status_http)
    else:
        http_diag = "ERR"
    
    if isinstance(status_https, int):
        https_diag = str(status_https)
    else:
        https_diag = "ERR"
    
    diag_both = f"HTTP:{http_diag} HTTPS:{https_diag}"
    
    # Логика выбора
    if available_http and status_http == 200:
        # HTTP 200 - идеально
        return True, diag_both, False
    elif available_https and status_https == 200:
        # HTTP не 200, но HTTPS 200 - OK
        return True, diag_both, False
    elif available_http and available_https:
        # Оба доступны но не 200 - WARN
        return True, diag_both, True
    elif available_http:
        # Только HTTP доступен
        if status_http == 200:
            return True, diag_both, False
        else:
            return True, diag_both, True
    elif available_https:
        # Только HTTPS доступен
        if status_https == 200:
            return True, diag_both, False
        else:
            return True, diag_both, True
    else:
        # Оба не доступны
        return False, diag_both, False


def check_service(host_from_url, name, location, url, number=None, total=None):
    """Проверить один сервис и вывести результат"""
    # Парсим URL с помощью встроенной функции
    protocol, host, port, path = parse_url(url)
    
    # Определяем тип сервиса и проводим проверку
    if protocol == "tcp":
        available, diagnostic = check_tcp(host, port)
        is_warn = False
    elif protocol == "https":
        available, diagnostic = check_http(host, port, "https", path)
        is_warn = (isinstance(diagnostic, int) and diagnostic != 200)
    else:  # http - с fallback на https
        available, diagnostic, is_warn = check_http_fallback(host, port, path)
    
    # Форматированный вывод
    if available:
        if is_warn:
            status = f"{ORANGE}⚠ WARN{RESET}"
        else:
            status = f"{GREEN}✓ OK{RESET}"
        if diagnostic:
            status += f" ({diagnostic})"
    else:
        status = f"{RED}✗ ERROR{RESET}"
        if diagnostic:
            status += f": {diagnostic}"
    
    port_str = f":{port}"
    type_str = f"[{protocol.upper()}]"
    
    # Добавляем нумерацию если передана
    if number is not None and total is not None:
        num_str = f"[{number:2d}/{total}]"
        print(f"  {num_str} {name:.<22} {port_str:>6}  {type_str:.<8} {status}")
    else:
        print(f"  {name:.<25} {port_str:>6}  {type_str:.<8} {status}")
    
    return available


def print_header(host, total_services=15):
    """Печать заголовка"""
    line_width = 69
    title = "Проверка доступности сервисов vkosarev.name"
    title_padding = (line_width - len(title)) // 2
    
    host_info = f"Хост: {host} ({total_services} сервисов)"
    host_padding = (line_width - len(host_info)) // 2
    
    print(f"\n{BOLD}{CYAN}╔{'═'*line_width}╗{RESET}")
    print(f"{BOLD}{CYAN}║{' '*title_padding}{title}{' '*(line_width - title_padding - len(title))}║{RESET}")
    print(f"{BOLD}{CYAN}║{' '*host_padding}{host_info}{' '*(line_width - host_padding - len(host_info))}║{RESET}")
    print(f"{BOLD}{CYAN}╚{'═'*line_width}╝{RESET}\n")


def print_section(name):
    """Печать заголовка секции"""
    print(f"{BOLD}{YELLOW}{name}{RESET}")


def print_summary(total, ok):
    """Печать итогов"""
    error_count = total - ok
    ok_pct = (ok / total * 100) if total > 0 else 0
    
    print(f"\n{BOLD}{CYAN}{'─'*69}{RESET}")
    print(f"{BOLD}Итого:{RESET} {total} сервисов")
    print(f"  {GREEN}✓ OK:{RESET} {ok}/{total} ({ok_pct:.0f}%)", end="")
    if error_count > 0:
        print(f"  {RED}✗ ERROR:{RESET} {error_count}/{total}")
    else:
        print()
    print(f"{BOLD}{CYAN}{'═'*69}{RESET}\n")


def main():
    # Парсим аргументы
    host = "localhost"
    if len(sys.argv) > 1:
        if sys.argv[1] in ('--help', '-h', '-?'):
            print(__doc__)
            sys.exit(0)
        host = sys.argv[1]
    
    print_header(host, len(SERVICES))
    
    ok_count = 0
    service_number = 1
    
    # Категоризируем сервисы
    categories = {}
    for name, location, category, url in SERVICES:
        if category not in categories:
            categories[category] = []
        categories[category].append((name, location, url))
    
    # Сортируем по имени категории (автоматически по номерам: 1, 2, 3, 4, 5)
    first_section = True
    for category_name in sorted(categories.keys()):
        if not first_section:
            print()
        
        # Конвертируем имя обратно в emoji формат для вывода
        emoji_map = {
            "1. Мониторинг": "📊 Мониторинг",
            "2. Инфраструктура": "🛠️ Инфраструктура",
            "3. Медиа": "📸 Медиа",
            "4. Видеонаблюдение": "📷 Видеонаблюдение",
            "5. Утилиты": "⚡ Утилиты",
        }
        section_emoji = emoji_map.get(category_name, category_name)
        
        print_section(section_emoji)
        first_section = False
        
        for name, location, url in categories[category_name]:
            if check_service(host, f"{name} ({location})", location, url, service_number, len(SERVICES)):
                ok_count += 1
            service_number += 1
    
    print_summary(len(SERVICES), ok_count)


if __name__ == "__main__":
    main()


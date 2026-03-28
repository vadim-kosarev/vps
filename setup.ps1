# PowerShell-скрипт для создания локального администратора и настройки WinRM
# Дата генерации: 2026-03-28

$User = "local-admin"
$Password = $null

# === Инициализация статусов для отчёта ===
$report = @()

# Проверка, есть ли уже такой пользователь
$userCreated = $false
if (-not (Get-LocalUser -Name $User -ErrorAction SilentlyContinue)) {
    $Password = Read-Host "Введите пароль для пользователя $User" -AsSecureString
    New-LocalUser -Name $User -Password $Password -FullName "Local Admin" -Description "Для удалённого управления" -PasswordNeverExpires -UserMayNotChangePassword
    $report += " - Создание пользователя : Пользователь $User создан."
    $userCreated = $true
} else {
    $report += " - Создание пользователя : Пользователь $User уже существует. Пропущено."
}

# Добавление пользователя в группу Администраторы
try {
    Add-LocalGroupMember -Group "Administrators" -Member $User -ErrorAction Stop
    $report += " - Добавление в Администраторы : Пользователь $User добавлен в группу."
} catch {
    $report += " - Добавление в Администраторы : Ошибка — $_"
}

# Включение WinRM и настройка брандмауэра
try {
    Enable-PSRemoting -Force -ErrorAction Stop
    $report += " - Включение WinRM : Успешно."
} catch {
    $report += " - Включение WinRM : Ошибка — $_"
}

# Разрешение подключения для локальных админов (UAC bypass для WinRM)
try {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "LocalAccountTokenFilterPolicy" -Value 1 -Type DWord -ErrorAction Stop
    $report += " - LocalAccountTokenFilterPolicy : Установлен."
} catch {
    $report += " - LocalAccountTokenFilterPolicy : Ошибка — $_"
}

# Проверка статуса WinRM
try {
    Start-Service WinRM -ErrorAction Stop
    $report += " - Запуск службы WinRM : Служба запущена."
} catch {
    $report += " - Запуск службы WinRM : Ошибка — $_"
}

# Информация для входа
$report += " - Инструкция по входу : WinRM включён, можно подключаться через Enter-PSSession -ComputerName <имя> -Credential .\\local-admin"

# === Скачивание windows_exporter.exe в bin ===
$binDir = Join-Path $PSScriptRoot 'bin'
$exporterExe = Join-Path $binDir 'windows_exporter.exe'
$exporterUrl = 'https://github.com/prometheus-community/windows_exporter/releases/download/v0.31.5/windows_exporter-0.31.5-amd64.exe'
$downloadedExe = Join-Path $binDir 'windows_exporter-0.31.5-amd64.exe'
$configFile = Join-Path $binDir 'windows_exporter_config.yml'
$exporterDownloaded = $false

if (-not (Test-Path $binDir)) {
    New-Item -Path $binDir -ItemType Directory | Out-Null
}

if (-not (Test-Path $exporterExe)) {
    try {
        Invoke-WebRequest -Uri $exporterUrl -OutFile $downloadedExe -ErrorAction Stop
        Move-Item -Force $downloadedExe $exporterExe
        $report += " - Скачивание windows_exporter : windows_exporter.exe скачан и помещён в $binDir."
        $exporterDownloaded = $true
    } catch {
        $report += " - Скачивание windows_exporter : Ошибка — $_"
    }
} else {
    $report += " - Скачивание windows_exporter : windows_exporter.exe уже есть в $binDir."
    $exporterDownloaded = $true
}

# === Установка windows_exporter как Windows-сервиса из bin ===
$serviceName = 'windows_exporter'
if (Test-Path $exporterExe) {
    try {
        if (-not (Get-Service -Name $serviceName -ErrorAction SilentlyContinue)) {
            $binArgs = "$exporterExe --config.file=`"$configFile`""
            New-Service -Name $serviceName -BinaryPathName $binArgs -DisplayName "windows_exporter" -Description "Prometheus Windows Exporter" -StartupType Automatic
            Start-Service $serviceName
            $report += " - Установка windows_exporter : Сервис установлен и запущен. Конфиг: $configFile. Метрики: http://localhost:9182/metrics"
        } else {
            Restart-Service $serviceName
            $report += " - Установка windows_exporter : Сервис уже существует. Перезапущен. Метрики: http://localhost:9182/metrics"
        }
    } catch {
        $report += " - Установка windows_exporter : Ошибка — $_"
    }
} else {
    $report += " - Установка windows_exporter : windows_exporter.exe не найден в $binDir. Скопируйте бинарник и конфиг вручную и повторите установку."
}

# === Финальный отчёт ===
Write-Host "--- ОТЧЁТ ПО УСТАНОВКЕ ---" -ForegroundColor Cyan
$report | ForEach-Object { Write-Host $_ }
Write-Host "--- КОНЕЦ ОТЧЁТА ---" -ForegroundColor Cyan

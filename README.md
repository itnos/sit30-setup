# Установка sit30 Server Stack

Автоматическая установка полного стека sit30 на чистый сервер одной командой.

## Быстрый старт

Для установки стека выполните команду:

```bash
curl -fsSL https://raw.githubusercontent.com/itnos/sit30-setup/refs/heads/master/sit30-install.sh | bash -s -- --site-dir=/var/www/site/sit30.net
```

**Обязательный параметр:**
- `--site-dir` - путь для установки сайта

## Параметры установки

### Обязательные параметры

- `--site-dir=/path/to/site` - директория для установки сайта (обязательно)

### Опциональные параметры

- `--stack-dir=/path/to/stack` - директория для установки стека (по умолчанию `/opt/sit30-server-stack`)
- `--data-dir=/path/to/data` - директория для данных, секретов и бэкапов (по умолчанию `/opt/sit30-data`)
- `--branch=branch-name` - ветка для клонирования (по умолчанию `master`)

## Примеры использования

### Базовая установка

```bash
curl -fsSL https://raw.githubusercontent.com/itnos/sit30-setup/refs/heads/master/sit30-install.sh | bash -s -- --site-dir=/var/www/site/sit30.net
```

### Установка с пользовательскими путями

```bash
curl -fsSL https://raw.githubusercontent.com/itnos/sit30-setup/refs/heads/master/sit30-install.sh | bash -s -- \
  --site-dir=/var/www/mysite \
  --stack-dir=/opt/my-stack \
  --data-dir=/opt/my-data
```

### Локальная установка

Если скрипт уже скачан:

```bash
chmod +x sit30-install.sh
./sit30-install.sh --site-dir=/var/www/site/sit30.net
```

## Что устанавливается

Скрипт автоматически устанавливает и настраивает:

1. **Базовые зависимости:**
   - Git
   - Docker
   - Docker Compose

2. **SSH ключи для GitHub:**
   - Генерируются два SSH ключа (для репозитория стека и сайта)
   - Настраивается SSH конфигурация

3. **Структура директорий:**
   - `/opt/sit30-server-stack` - репозиторий стека
   - `/opt/sit30-data` - данные, секреты, бэкапы, SSL сертификаты
   - Директория сайта (по вашему выбору)

4. **Конфигурация:**
   - `.env` файл в `$DATA_DIR`
   - Символическая ссылка из `$STACK_DIR/.env` на `$DATA_DIR/.env`

## Следующие шаги после установки

### 1. Добавить SSH ключи в GitHub Deploy Keys

После установки скрипт выведет два публичных ключа, которые нужно добавить в GitHub:

**Для репозитория sit30-server-stack:**
- Перейти: https://github.com/itnos/sit30-server-stack/settings/keys/new
- Добавить публичный ключ из вывода скрипта

**Для репозитория sit30_site_new:**
- Перейти: https://github.com/itnos/sit30_site_new/settings/keys/new
- Добавить публичный ключ из вывода скрипта

### 2. Настроить .env файл

```bash
nano /opt/sit30-data/.env
```

**Обязательные настройки:**
- `DB_PASSWORD` - пароль для базы данных
- `REDIS_PASSWORD` - пароль для Redis
- `DOMAIN` - доменное имя
- `SSL_EMAIL` - email для SSL сертификатов
- `ACME_DNS_PROVIDER` - DNS провайдер для SSL (например, `cloudflare`)
- `CF_TOKEN` - токен Cloudflare (если используется Cloudflare)

### 3. Добавить секреты Firebase и Dialogflow

Поместите JSON файлы с секретами в:
- `/opt/sit30-data/secrets/firebase/`
- `/opt/sit30-data/secrets/dialogflow/`

### 4. Запустить стек

```bash
cd /opt/sit30-server-stack
./scripts/deploy-dual-repo.sh start
```

### 5. Получить SSL сертификат

```bash
cd /opt/sit30-server-stack
./scripts/ssl-manager.sh issue
```

## Структура директорий после установки

```
/opt/sit30-server-stack/          # Репозиторий стека
  ├── .env -> /opt/sit30-data/.env # Символическая ссылка на конфигурацию
  └── scripts/                     # Скрипты управления

/opt/sit30-data/                   # Данные и секреты
  ├── .env                         # Конфигурация
  ├── secrets/                     # Секреты
  │   ├── firebase/
  │   ├── dialogflow/
  │   ├── ssl/
  │   └── ssh/
  ├── backups/                     # Бэкапы
  └── volumes/                     # Volumes для Docker
      ├── logs/
      ├── ssl/
      └── acme/

/var/www/site/sit30.net/                # Репозиторий сайта
```

## Требования

- Ubuntu/Debian сервер (чистая установка)
- Доступ с правами root или sudo
- Интернет-соединение

## Безопасность

- Все секреты хранятся в `/opt/sit30-data/secrets/` с правами `700`
- SSH ключи генерируются автоматически и уникальны для каждого сервера
- Рекомендуется использовать сильные пароли в `.env` файле

## Поддержка

При возникновении проблем:
1. Проверьте логи Docker: `docker-compose logs`
2. Убедитесь, что SSH ключи добавлены в GitHub
3. Проверьте настройки `.env` файла

## Лицензия

MIT

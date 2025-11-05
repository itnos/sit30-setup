#!/bin/bash
# scripts/sit30-install.sh
# Быстрая установка sit30 стека на чистый сервер
# Использование: curl -fsSL https://raw.githubusercontent.com/itnos/sit30-setup/refs/heads/master/sit30-install.sh | bash

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Конфигурация по умолчанию
STACK_REPO="git@github.com:itnos/sit30-server-stack.git"
SITE_REPO="git@github.com:itnos/sit30_site_new.git"
STACK_DIR="/opt/sit30-server-stack"
SITE_DIR=""
DATA_DIR="/opt/sit30-data"
BRANCH="master"

# Парсинг аргументов командной строки
for arg in "$@"; do
    case $arg in
        --stack-dir=*)
            STACK_DIR="${arg#*=}"
            shift
            ;;
        --site-dir=*)
            SITE_DIR="${arg#*=}"
            shift
            ;;
        --data-dir=*)
            DATA_DIR="${arg#*=}"
            shift
            ;;
        --branch=*)
            BRANCH="${arg#*=}"
            shift
            ;;
    esac
done

# Проверка обязательных параметров
if [ -z "$SITE_DIR" ]; then
    echo ""
    echo -e "${RED}✗ Ошибка: Не указан путь для установки сайта!${NC}"
    echo ""
    echo -e "${YELLOW}Использование:${NC}"
    echo -e "  ${CYAN}$0 --site-dir=/path/to/site${NC}"
    echo ""
    echo -e "${YELLOW}Пример:${NC}"
    echo -e "  ${CYAN}$0 --site-dir=/var/www/site/sit30.net${NC}"
    echo ""
    echo -e "${YELLOW}С дополнительными параметрами:${NC}"
    echo -e "  ${CYAN}$0 --site-dir=/var/www/mysite --stack-dir=/opt/my-stack --data-dir=/opt/my-data${NC}"
    echo ""
    echo -e "${YELLOW}Через curl:${NC}"
    echo -e "  ${CYAN}curl -fsSL https://raw.githubusercontent.com/itnos/sit30-setup/refs/heads/master/sit30-install.sh | bash -s -- --site-dir=/var/www/site/sit30.net${NC}"
    echo ""
    echo -e "${YELLOW}Примечание:${NC}"
    echo -e "  DATA_DIR (по умолчанию /opt/sit30-data) - для секретов, бэкапов, SSL"
    echo ""
    exit 1
fi

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                                                            ║${NC}"
echo -e "${CYAN}║          ${GREEN}Установка sit30 Server Stack${CYAN}                   ║${NC}"
echo -e "${CYAN}║                                                            ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================
# Функция: Проверка наличия команды
# ============================================
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# ============================================
# Шаг 1: Установка базовых зависимостей
# ============================================
echo -e "${BLUE}[1/5]${NC} ${YELLOW}Проверка и установка зависимостей...${NC}"
echo ""

if ! command_exists git; then
    echo "  → Устанавливаю git..."
    apt-get update -qq && apt-get install -y -qq git >/dev/null 2>&1
    echo -e "  ${GREEN}✓${NC} Git установлен"
else
    echo -e "  ${GREEN}✓${NC} Git уже установлен"
fi

if ! command_exists docker; then
    echo "  → Устанавливаю Docker..."
    curl -fsSL https://get.docker.com | sh >/dev/null 2>&1
    systemctl enable docker >/dev/null 2>&1
    systemctl start docker
    echo -e "  ${GREEN}✓${NC} Docker установлен"
else
    echo -e "  ${GREEN}✓${NC} Docker уже установлен"
fi

if ! command_exists docker-compose; then
    echo "  → Устанавливаю Docker Compose..."
    curl -sL "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    echo -e "  ${GREEN}✓${NC} Docker Compose установлен"
else
    echo -e "  ${GREEN}✓${NC} Docker Compose уже установлен"
fi

echo ""

# ============================================
# Шаг 2: Настройка SSH ключей для GitHub
# ============================================
echo -e "${BLUE}[2/5]${NC} ${YELLOW}Настройка SSH ключей для доступа к GitHub...${NC}"
echo ""

mkdir -p ~/.ssh
chmod 700 ~/.ssh

ssh_dir="$HOME/.ssh"
stack_key="$ssh_dir/sit30_stack_deploy_key"
site_key="$ssh_dir/sit30_site_deploy_key"

# Генерируем ключи если их нет
if [ ! -f "$stack_key" ]; then
    echo "  → Генерирую SSH ключ для репозитория стека..."
    ssh-keygen -t ed25519 -C "deploy@sit30-stack" -f "$stack_key" -N "" >/dev/null 2>&1
    echo -e "  ${GREEN}✓${NC} Ключ для стека создан"
else
    echo -e "  ${GREEN}✓${NC} Ключ для стека уже существует"
fi

if [ ! -f "$site_key" ]; then
    echo "  → Генерирую SSH ключ для репозитория сайта..."
    ssh-keygen -t ed25519 -C "deploy@sit30-site" -f "$site_key" -N "" >/dev/null 2>&1
    echo -e "  ${GREEN}✓${NC} Ключ для сайта создан"
else
    echo -e "  ${GREEN}✓${NC} Ключ для сайта уже существует"
fi

chmod 600 "$stack_key" "$site_key"

# Настраиваем SSH config
cat > ~/.ssh/config <<EOF
# Deploy key для sit30-server-stack
Host github-stack
    HostName github.com
    User git
    IdentityFile $stack_key
    IdentitiesOnly yes
    StrictHostKeyChecking no

# Deploy key для sit30_site_new
Host github-site
    HostName github.com
    User git
    IdentityFile $site_key
    IdentitiesOnly yes
    StrictHostKeyChecking no
EOF

chmod 600 ~/.ssh/config

# Добавляем github.com в known_hosts
ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null

echo ""

# ============================================
# Шаг 3: Клонирование репозитория стека
# ============================================
echo -e "${BLUE}[3/5]${NC} ${YELLOW}Клонирование репозитория стека...${NC}"
echo ""

if [ -d "$STACK_DIR" ]; then
    echo -e "  ${YELLOW}⚠${NC}  Директория уже существует: ${CYAN}$STACK_DIR${NC}"
    echo "  Пропускаю клонирование..."
else
    mkdir -p "$(dirname "$STACK_DIR")"

    # Используем SSH алиас github-stack из ~/.ssh/config
    ssh_repo=$(echo "$STACK_REPO" | sed 's|github.com|github-stack|')

    echo "  → Клонирую стек через SSH..."
    if git clone -q -b "$BRANCH" "$ssh_repo" "$STACK_DIR" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Стек успешно клонирован"
        echo -e "  ${BLUE}  Директория:${NC} ${CYAN}$STACK_DIR${NC}"
        echo -e "  ${BLUE}  Ветка:${NC} ${CYAN}$BRANCH${NC}"

        # Создаём необходимые директории для данных
        echo ""
        echo "  → Создаю директории для данных в ${CYAN}$DATA_DIR${NC}..."
        mkdir -p "$DATA_DIR/secrets/firebase"
        mkdir -p "$DATA_DIR/secrets/dialogflow"
        mkdir -p "$DATA_DIR/secrets/ssl"
        mkdir -p "$DATA_DIR/secrets/ssh"
        mkdir -p "$DATA_DIR/backups"
        mkdir -p "$DATA_DIR/volumes/logs/nginx"
        mkdir -p "$DATA_DIR/volumes/ssl"
        mkdir -p "$DATA_DIR/volumes/acme"

        chmod 700 "$DATA_DIR/secrets"
        chmod 700 "$DATA_DIR/backups"

        echo -e "  ${GREEN}✓${NC} Директории созданы в ${CYAN}$DATA_DIR${NC}"

        # Создаём .env из .env.example в DATA_DIR (только если не существует!)
        if [ ! -f "$DATA_DIR/.env" ]; then
            if [ -f "$STACK_DIR/.env.example" ]; then
                echo ""
                echo "  → Настраиваю .env файл в ${CYAN}$DATA_DIR${NC}..."
                cp "$STACK_DIR/.env.example" "$DATA_DIR/.env"

                # Записываем SITE_PATH и DATA_DIR
                if grep -q "^SITE_PATH=" "$DATA_DIR/.env" 2>/dev/null; then
                    sed -i.bak "s|^SITE_PATH=.*|SITE_PATH=$SITE_DIR|g" "$DATA_DIR/.env"
                else
                    echo "SITE_PATH=$SITE_DIR" >> "$DATA_DIR/.env"
                fi

                if grep -q "^DATA_DIR=" "$DATA_DIR/.env" 2>/dev/null; then
                    sed -i.bak "s|^DATA_DIR=.*|DATA_DIR=$DATA_DIR|g" "$DATA_DIR/.env"
                else
                    echo "DATA_DIR=$DATA_DIR" >> "$DATA_DIR/.env"
                fi

                rm -f "$DATA_DIR/.env.bak"

                echo -e "  ${GREEN}✓${NC} .env создан в ${CYAN}$DATA_DIR/.env${NC}"
            fi
        else
            echo ""
            echo -e "  ${YELLOW}⚠${NC} .env уже существует в ${CYAN}$DATA_DIR/.env${NC} (не затираю)"
        fi

        # Создаём символическую ссылку из STACK_DIR/.env на DATA_DIR/.env
        ln -sf "$DATA_DIR/.env" "$STACK_DIR/.env"
        echo -e "  ${GREEN}✓${NC} Символическая ссылка: ${CYAN}$STACK_DIR/.env${NC} → ${CYAN}$DATA_DIR/.env${NC}"
    else
        echo -e "  ${RED}✗${NC} Ошибка клонирования!"
        echo ""
        echo -e "${YELLOW}ВАЖНО:${NC} Сначала добавьте SSH ключ в GitHub Deploy Keys!"
        echo "  См. инструкции ниже в шаге [5/5]"
        echo ""
        echo "После добавления ключа запустите команду вручную:"
        echo -e "  ${CYAN}git clone -b $BRANCH $ssh_repo $STACK_DIR${NC}"
        echo ""
    fi
fi

echo ""

# ============================================
# Шаг 4: Клонирование репозитория сайта
# ============================================
echo -e "${BLUE}[4/5]${NC} ${YELLOW}Клонирование репозитория сайта...${NC}"
echo ""

if [ -d "$SITE_DIR" ]; then
    echo -e "  ${YELLOW}⚠${NC}  Директория уже существует: ${CYAN}$SITE_DIR${NC}"
    echo "  Пропускаю клонирование..."
else
    mkdir -p "$(dirname "$SITE_DIR")"

    # Используем SSH алиас github-site из ~/.ssh/config
    ssh_site_repo=$(echo "$SITE_REPO" | sed 's|github.com|github-site|')

    echo "  → Клонирую сайт через SSH..."
    if git clone -q -b "$BRANCH" "$ssh_site_repo" "$SITE_DIR" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Сайт успешно клонирован"
        echo -e "  ${BLUE}  Директория:${NC} ${CYAN}$SITE_DIR${NC}"
        echo -e "  ${BLUE}  Ветка:${NC} ${CYAN}$BRANCH${NC}"
    else
        echo -e "  ${RED}✗${NC} Ошибка клонирования сайта!"
        echo ""
        echo -e "${YELLOW}ВАЖНО:${NC} Сначала добавьте SSH ключ в GitHub Deploy Keys!"
        echo "  См. инструкции ниже в шаге [5/5]"
        echo ""
        echo "После добавления ключа запустите команду вручную:"
        echo -e "  ${CYAN}git clone -b $BRANCH $ssh_site_repo $SITE_DIR${NC}"
        echo ""
    fi
fi

echo ""

# ============================================
# Шаг 5: Инструкции для пользователя
# ============================================
echo -e "${BLUE}[5/5]${NC} ${GREEN}Следующие шаги${NC}"
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  ВАЖНО: Добавьте SSH ключи в GitHub Deploy Keys!${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${CYAN}1. Для репозитория sit30-server-stack:${NC}"
echo -e "   ${BLUE}https://github.com/itnos/sit30-server-stack/settings/keys/new${NC}"
echo ""
echo -e "   ${GREEN}Title:${NC} Production Server $(hostname)"
echo -e "   ${GREEN}Key:${NC}"
echo ""
cat "$stack_key.pub"
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${CYAN}2. Для репозитория sit30_site_new:${NC}"
echo -e "   ${BLUE}https://github.com/itnos/sit30_site_new/settings/keys/new${NC}"
echo ""
echo -e "   ${GREEN}Title:${NC} Production Server $(hostname)"
echo -e "   ${GREEN}Key:${NC}"
echo ""
cat "$site_key.pub"
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${GREEN}После добавления ключей выполните:${NC}"
echo ""
echo -e "  ${BLUE}1.${NC} Отредактируйте настройки .env:"
echo -e "     ${CYAN}nano $DATA_DIR/.env${NC}"
echo ""
echo -e "     ${YELLOW}Обязательно настройте:${NC}"
echo -e "     • DB_PASSWORD, REDIS_PASSWORD"
echo -e "     • DOMAIN, SSL_EMAIL"
echo -e "     • ACME_DNS_PROVIDER, CF_TOKEN (для SSL)"
echo ""
echo -e "  ${BLUE}2.${NC} Добавьте секреты Firebase/Dialogflow в:"
echo -e "     ${CYAN}$DATA_DIR/secrets/${NC}"
echo ""
echo -e "  ${BLUE}3.${NC} Обновите и запустите стек:"
echo -e "     ${CYAN}cd $STACK_DIR && ./scripts/deploy-dual-repo.sh update${NC}"
echo -e "     ${CYAN}cd $STACK_DIR && ./scripts/deploy-dual-repo.sh start${NC}"
echo ""
echo -e "  ${BLUE}4.${NC} Получите SSL сертификат:"
echo -e "     ${CYAN}cd $STACK_DIR && ./scripts/ssl-manager.sh issue${NC}"
echo ""
echo -e "     ${GREEN}Примечание:${NC} Путь к сайту уже настроен в .env: ${CYAN}$SITE_DIR${NC}"
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${GREEN}✓ Базовая установка завершена!${NC}"
echo ""
echo -e "${BLUE}Что было установлено:${NC}"
echo -e "  ${GREEN}✓${NC} Git"
echo -e "  ${GREEN}✓${NC} Docker & Docker Compose"
echo -e "  ${GREEN}✓${NC} SSH ключи для GitHub (2 шт.)"
if [ -d "$STACK_DIR" ]; then
    echo -e "  ${GREEN}✓${NC} Репозиторий стека: ${CYAN}$STACK_DIR${NC}"
fi
if [ -d "$SITE_DIR" ]; then
    echo -e "  ${GREEN}✓${NC} Репозиторий сайта: ${CYAN}$SITE_DIR${NC}"
fi
echo ""

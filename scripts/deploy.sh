#!/bin/bash
# ─── Скрипт деплоя на VPS ────────────────────────────────────────────────────
# Запускать на VPS: bash scripts/deploy.sh
set -e

REPO_URL="https://github.com/YOUR_USERNAME/YOUR_REPO.git"
APP_DIR="/opt/diploma"

echo "▶ Деплой начат..."

# ── 1. Установка Docker (если не установлен) ──────────────────────────────────
if ! command -v docker &> /dev/null; then
  echo "▶ Устанавливаем Docker..."
  curl -fsSL https://get.docker.com | sh
  systemctl enable docker
  systemctl start docker
fi

# ── 2. Клонирование / обновление репозитория ──────────────────────────────────
if [ -d "$APP_DIR" ]; then
  echo "▶ Обновляем репозиторий..."
  cd "$APP_DIR"
  git pull
else
  echo "▶ Клонируем репозиторий..."
  git clone "$REPO_URL" "$APP_DIR"
  cd "$APP_DIR"
fi

# ── 3. Проверка .env.prod ──────────────────────────────────────────────────────
if [ ! -f ".env.prod" ]; then
  echo "✗ Файл .env.prod не найден!"
  echo "  Скопируй backend/.env.prod.example → .env.prod и заполни значения."
  exit 1
fi

# ── 4. Создание папки для SSL сертификатов ────────────────────────────────────
mkdir -p nginx/certs

# ── 5. Сборка и запуск контейнеров ───────────────────────────────────────────
echo "▶ Собираем и запускаем контейнеры..."
docker compose -f docker-compose.prod.yml --env-file .env.prod pull --ignore-pull-failures
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build

echo ""
echo "✓ Деплой завершён!"
echo ""
echo "Следующие шаги:"
echo "  • Настрой DNS: A-запись api.yourdomain.com → $(curl -s ifconfig.me)"
echo "  • Для HTTPS: certbot certonly --standalone -d api.yourdomain.com"
echo "  • Скопируй сертификаты в nginx/certs/ и раскомментируй HTTPS блок в nginx/nginx.conf"
echo "  • Задеплой фронтенд на Vercel с переменной NEXT_PUBLIC_API_URL=http://$(curl -s ifconfig.me)"

#!/bin/bash
# MelaVPN Admin Panel — установка
# Использование: bash install.sh
set -e

INSTALL_DIR=/opt/mela
PANEL_USER=www-data

echo "=== MelaVPN Panel Install ==="

# Зависимости
apt-get update -qq
apt-get install -y -qq nginx python3 python3-pip git
pip3 install paramiko -q

# Клонируем или обновляем
if [ -d "$INSTALL_DIR/.git" ]; then
  echo "Обновляем репозиторий..."
  git -C "$INSTALL_DIR" pull
else
  echo "Клонируем репозиторий..."
  git clone https://github.com/TurkmenVpn/mela-vpn.git "$INSTALL_DIR"
fi

# Данные панели
mkdir -p /etc/mela

# Пароль
if [ ! -f /etc/mela/password ]; then
  echo ""
  echo "Задай пароль для входа в панель:"
  while true; do
    read -s -p "Пароль: " PW; echo
    read -s -p "Повтори: " PW2; echo
    if [ -z "$PW" ]; then
      echo "Пароль не может быть пустым"
    elif [ "$PW" != "$PW2" ]; then
      echo "Пароли не совпадают"
    else
      echo -n "$PW" | sha256sum | awk '{print $1}' > /etc/mela/password
      echo "✅ Пароль сохранён"
      break
    fi
  done
else
  echo "Пароль уже задан (чтобы сбросить: rm /etc/mela/password)"
fi

# Инициализация файлов данных
[ -f /etc/mela/config.json ] || echo '{"proxy":"","sub":"","mirrors":[]}' > /etc/mela/config.json
[ -f /etc/mela/subscription.txt ] || touch /etc/mela/subscription.txt
[ -f /etc/mela/relays.json ] || echo '[]' > /etc/mela/relays.json

# Systemd сервис
cat > /etc/systemd/system/mela-panel.service << 'EOF'
[Unit]
Description=MelaVPN Admin Panel Backend
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/mela/admin/panel-server.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable mela-panel
systemctl restart mela-panel

# Nginx конфиг
cat > /etc/nginx/sites-available/mela-panel << 'EOF'
server {
    listen 80;
    server_name _;

    root /opt/mela/admin;
    index panel.html;

    location / {
        try_files $uri panel.html;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:7979;
        proxy_set_header X-Token $http_x_token;
        proxy_set_header Content-Type $http_content_type;
    }
}
EOF

ln -sf /etc/nginx/sites-available/mela-panel /etc/nginx/sites-enabled/mela-panel
rm -f /etc/nginx/sites-enabled/default

nginx -t && systemctl restart nginx

echo ""
echo "✅ Готово!"
echo "Открывай в браузере: http://$(curl -s ifconfig.me 2>/dev/null || echo ВАШ_IP)"
echo "Сброс пароля: rm /etc/mela/password && bash $INSTALL_DIR/admin/install.sh"

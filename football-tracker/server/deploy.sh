#!/bin/bash
set -euo pipefail

#=============================================================================
# Football Tracker 一键部署脚本
# 目标环境: Ubuntu 22.04 (Azure East Asia VM)
#
# 用法:
#   1. 将整个 server/ 目录上传到 VM (scp -r server/ user@vm-ip:~/football-tracker-server/)
#   2. SSH 到 VM
#   3. cd ~/football-tracker-server
#   4. chmod +x deploy.sh
#   5. sudo ./deploy.sh
#=============================================================================

echo "=========================================="
echo "  Football Tracker 部署脚本"
echo "=========================================="

# ── 1. 系统更新 + 基础工具 ──
echo "[1/5] 安装系统依赖..."
apt-get update -qq
apt-get install -y -qq curl gnupg lsb-release ca-certificates

# ── 2. 安装 Docker ──
if ! command -v docker &> /dev/null; then
    echo "[2/5] 安装 Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
else
    echo "[2/5] Docker 已安装，跳过"
fi

# 安装 Docker Compose plugin (如果没有)
if ! docker compose version &> /dev/null; then
    echo "  安装 Docker Compose plugin..."
    apt-get install -y -qq docker-compose-plugin
fi

# ── 3. 安装 Nginx ──
if ! command -v nginx &> /dev/null; then
    echo "[3/5] 安装 Nginx..."
    apt-get install -y -qq nginx
    systemctl enable nginx
else
    echo "[3/5] Nginx 已安装，跳过"
fi

# ── 4. 配置 Nginx ──
echo "[4/5] 配置 Nginx 反向代理..."
cp nginx/football-tracker.conf /etc/nginx/sites-available/football-tracker
ln -sf /etc/nginx/sites-available/football-tracker /etc/nginx/sites-enabled/football-tracker
rm -f /etc/nginx/sites-enabled/default

# 测试配置
nginx -t
systemctl reload nginx

# ── 5. 检查 .env 文件并启动服务 ──
echo "[5/5] 启动 Docker 服务..."
if [ ! -f .env ]; then
    echo ""
    echo "⚠️  未找到 .env 文件！"
    echo "   请先复制 .env.example 为 .env 并填入实际密钥:"
    echo "   cp .env.example .env"
    echo "   nano .env"
    echo "   然后再运行: docker compose up -d"
    echo ""
    exit 1
fi

docker compose up -d --build

echo ""
echo "=========================================="
echo "  部署完成！"
echo "=========================================="
echo ""
echo "服务状态:"
docker compose ps
echo ""
echo "API 测试:"
echo "  curl http://localhost:8080/api/auth/sms/send"
echo ""
echo "查看日志:"
echo "  docker compose logs -f app"
echo ""

# ── 后续步骤提示 ──
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "后续步骤:"
echo ""
echo "1. 绑定域名后，安装 SSL 证书:"
echo "   apt install certbot python3-certbot-nginx"
echo "   certbot --nginx -d YOUR_DOMAIN"
echo ""
echo "2. 然后编辑 Nginx 配置，取消注释 SSL server 块:"
echo "   nano /etc/nginx/sites-available/football-tracker"
echo "   systemctl reload nginx"
echo ""
echo "3. 在 Azure Portal 的 NSG 中放行 TCP 443 端口"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

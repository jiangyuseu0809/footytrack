#!/bin/bash
set -euo pipefail

#=============================================================================
# Football Tracker SSL 证书配置脚本
# 前置条件: 域名 DNS 已解析到本服务器 IP
#
# 用法:
#   sudo ./setup-ssl.sh
#=============================================================================

DOMAIN="footytrack.cn"

echo "=========================================="
echo "  配置 SSL 证书 - ${DOMAIN}"
echo "=========================================="

# ── 1. 验证 DNS 解析 ──
echo "[1/4] 验证 DNS 解析..."
RESOLVED_IP=$(dig +short ${DOMAIN} 2>/dev/null || true)
if [ -z "$RESOLVED_IP" ]; then
    echo "❌ 域名 ${DOMAIN} 尚未解析，请先在腾讯云添加 A 记录"
    echo "   主机记录: @   记录类型: A   记录值: $(curl -s ifconfig.me)"
    exit 1
fi
echo "  ✅ ${DOMAIN} -> ${RESOLVED_IP}"

# ── 2. 安装 Certbot ──
echo "[2/4] 安装 Certbot..."
if ! command -v certbot &> /dev/null; then
    apt-get update -qq
    apt-get install -y -qq certbot python3-certbot-nginx
else
    echo "  Certbot 已安装，跳过"
fi

# ── 3. 申请 SSL 证书 ──
echo "[3/4] 申请 Let's Encrypt SSL 证书..."
certbot --nginx -d ${DOMAIN} -d www.${DOMAIN} --non-interactive --agree-tos --email admin@${DOMAIN} --redirect

# ── 4. 验证 ──
echo "[4/4] 验证 SSL 配置..."
nginx -t
systemctl reload nginx

echo ""
echo "=========================================="
echo "  SSL 配置完成！"
echo "=========================================="
echo ""
echo "  https://${DOMAIN}"
echo "  https://www.${DOMAIN}"
echo ""
echo "证书自动续期已配置 (certbot renew)"
echo "可手动测试续期: sudo certbot renew --dry-run"
echo ""

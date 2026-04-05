#!/bin/bash
set -euo pipefail

# Football Tracker 一键远程部署脚本
# 用法：./remote-deploy.sh
#
# 前置条件：az login 已登录

RESOURCE_GROUP="FOOTBALL-TRACKER-RG"
VM_NAME="football-tracker-vm"
SUBSCRIPTION="7b237a27-e9d2-402d-bcd2-d72130f20134"

echo "=== Football Tracker 部署 ==="

az account set --subscription "$SUBSCRIPTION" 2>/dev/null

echo "[1/2] git pull..."
az vm run-command invoke \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --command-id RunShellScript \
    --scripts "cd /home/azureuser/footytrack-repo && git checkout -- . && git clean -fd && git pull" \
    --query "value[0].message" -o tsv

echo "[2/2] docker compose build & restart..."
az vm run-command invoke \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --command-id RunShellScript \
    --scripts "
      cd /home/azureuser/football-tracker-server && docker compose down 2>/dev/null || true
      cd /home/azureuser/footytrack-repo/football-tracker/server && docker compose up -d --build 2>&1 | tail -20
    " \
    --query "value[0].message" -o tsv

echo "=== 部署完成 ==="

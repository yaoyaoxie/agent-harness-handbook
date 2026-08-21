#!/bin/bash
# 一键发布：构建 → 打包 → 上传 → 服务器解压 → 刷新访问统计
# 用法：bash deploy/deploy.sh
#
# 前提：
# 1. ~/.ssh/id_ed25519 已加入服务器 administrators_authorized_keys
# 2. 服务器已完成首次部署（Nginx / 目录结构 / 计划任务已就位）
set -euo pipefail

SERVER="Administrator@43.156.82.156"
SSH_KEY="$HOME/.ssh/id_ed25519"
REMOTE_ZIP="C:/web/harness-dist.zip"
REMOTE_WEBROOT="C:\\web\\harness"

cd "$(dirname "$0")/.."
echo "==> 1/4 构建站点"
npm run docs:build

echo "==> 2/4 打包产物"
(cd docs/.vitepress/dist && zip -qr /tmp/harness-dist.zip .)

echo "==> 3/4 上传并在服务器解压"
scp -i "$SSH_KEY" /tmp/harness-dist.zip "$SERVER:$REMOTE_ZIP"
ssh -i "$SSH_KEY" "$SERVER" "Get-ChildItem $REMOTE_WEBROOT | Remove-Item -Recurse -Force; tar.exe -xf C:\\web\\harness-dist.zip -C $REMOTE_WEBROOT; (Get-ChildItem $REMOTE_WEBROOT -Recurse -File | Measure-Object).Count"

echo "==> 4/5 刷新访问统计"
ssh -i "$SSH_KEY" "$SERVER" "powershell -ExecutionPolicy Bypass -File C:\\stats\\Update-Stats.ps1" || true

echo "==> 5/5 收录推送（百度主动推送 + IndexNow，服务器执行）"
ssh -i "$SSH_KEY" "$SERVER" "powershell -ExecutionPolicy Bypass -File C:\\stats\\Push-Baidu.ps1" || true

echo "==> 发布完成: https://harness.zhigouread.com （统计: /stats/）"

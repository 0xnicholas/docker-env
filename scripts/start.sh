#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_DIR="$SCRIPT_DIR/../compose"
ENV_FILE="$SCRIPT_DIR/../.env"

# 解析参数
EXT=false
DEV=true
while [[ $# -gt 0 ]]; do
  case $1 in
    --ext) EXT=true; shift ;;
    --no-dev) DEV=false; shift ;;
    *) echo "未知参数: $1"; exit 1 ;;
  esac
done

PROFILE=()
$EXT && PROFILE+=(--profile ext)

cd "$COMPOSE_DIR"

if $DEV; then
  # 自动加载 docker-compose.yml + docker-compose.override.yml
  echo "启动命令: docker compose ${PROFILE[*]} --env-file $ENV_FILE up -d"
  docker compose "${PROFILE[@]}" --env-file "$ENV_FILE" up -d
else
  # 显式指定 -f，阻止 override 加载
  echo "启动命令: docker compose -f docker-compose.yml ${PROFILE[*]} --env-file $ENV_FILE up -d"
  docker compose -f docker-compose.yml "${PROFILE[@]}" --env-file "$ENV_FILE" up -d
fi

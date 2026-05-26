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

COMPOSE_FILES=(-f "$COMPOSE_DIR/docker-compose.yml")
$EXT && COMPOSE_FILES+=(-f "$COMPOSE_DIR/docker-compose.ext.yml")
$DEV && COMPOSE_FILES+=(-f "$COMPOSE_DIR/docker-compose.dev.yml")
$EXT && $DEV && COMPOSE_FILES+=(-f "$COMPOSE_DIR/docker-compose.ext.dev.yml")

echo "启动命令: docker compose ${COMPOSE_FILES[*]} up -d"
docker compose "${COMPOSE_FILES[@]}" --env-file "$ENV_FILE" up -d

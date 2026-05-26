#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"

# 加载 .env
set -a
source "$ENV_FILE"
set +a

echo "=== docker-env 服务版本检查 ==="
echo ""

# 检查核心服务
check_service() {
  local name=$1
  local container=$2
  local expected=$3
  local version_cmd=$4

  if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
    actual=$(docker exec "$container" sh -c "$version_cmd" 2>/dev/null || echo "UNKNOWN")
    if echo "$actual" | grep -q "$expected"; then
      echo "✅ $name: $expected (运行中)"
    else
      echo "⚠️  $name: 期望 $expected, 实际: $actual"
    fi
  else
    echo "❌ $name: 未运行 (期望版本: $expected)"
  fi
}

check_service "PostgreSQL" "docker-env-postgres" "$POSTGRES_VERSION" "psql --version | awk '{print \$3}'"
check_service "Redis"      "docker-env-redis"     "$REDIS_VERSION"     "redis-server --version | awk '{print \$3}' | sed 's/v=//'"
check_service "ClickHouse" "docker-env-clickhouse" "$CLICKHOUSE_VERSION" "clickhouse-server --version | head -1 | awk '{print \$3}'"
check_service "Neo4j"      "docker-env-neo4j"     "$NEO4J_VERSION"     "neo4j --version | awk '{print \$2}'"
check_service "MinIO"      "docker-env-minio"     "$MINIO_VERSION"     "minio --version | head -1 | awk '{print \$3}'"

echo ""
echo "检查完成"

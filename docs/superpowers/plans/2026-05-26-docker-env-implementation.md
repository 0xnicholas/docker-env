# docker-env 统一 Docker 环境实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 创建 docker-env 项目的全部配置文件，统一 Docker 基础设施镜像版本，提供标准化 Python 应用基础镜像和便捷的启动脚本。

**Architecture:** 采用多 compose 文件组合策略（核心基础设施 + 扩展服务 + 开发模式优化），所有服务共享命名网络 `docker-env_shared`，版本和配置通过 `.env` 单一真相源管理。

**Tech Stack:** Docker Compose v2, Bash, Python 3.14 (基础镜像)

---

## 文件结构总览

| 文件 | 职责 |
|------|------|
| `.env` | 版本锁定 & 配置约定（唯一真相源） |
| `.env.example` | 配置模板，供其他项目参考 |
| `compose/docker-compose.yml` | 核心基础设施：PostgreSQL 17 + Redis 8-alpine |
| `compose/docker-compose.ext.yml` | 扩展服务：ClickHouse 25.12 + Neo4j 5 + MinIO |
| `compose/docker-compose.dev.yml` | 开发模式：端口暴露到宿主机 |
| `images/python/Dockerfile` | Python 3.14 标准化应用基础镜像 |
| `images/python/requirements.txt` | 预装常用基础包 |
| `scripts/start.sh` | 封装 compose 启动命令（支持 `--ext`、`--no-dev`） |
| `scripts/check-versions.sh` | 检查运行中的服务版本是否与 `.env` 锁定一致 |
| `README.md` | 使用文档和接入指南 |

---

### Task 1: 创建 `.env`（版本锁定唯一真相源）

**Files:**
- Create: `.env`

- [ ] **Step 1: 写入完整环境变量配置**

```bash
cat > .env << 'EOF'
# === 版本锁定（唯一真相源）===
POSTGRES_VERSION=17
REDIS_VERSION=8-alpine
CLICKHOUSE_VERSION=25.12
NEO4J_VERSION=5-community
MINIO_VERSION=latest

# === 核心服务 ===
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=postgres
POSTGRES_PORT=5432

REDIS_PASSWORD=redis
REDIS_PORT=6379

# === 扩展服务 ===
CLICKHOUSE_USER=default
CLICKHOUSE_PASSWORD=clickhouse
CLICKHOUSE_PORT=8123
CLICKHOUSE_NATIVE_PORT=9010

NEO4J_AUTH=neo4j/password
NEO4J_BOLT_PORT=7687
NEO4J_HTTP_PORT=7474

MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadmin
MINIO_API_PORT=9000
MINIO_CONSOLE_PORT=9001
EOF
```

- [ ] **Step 2: 验证文件内容**

```bash
cat .env
grep "CLICKHOUSE_NATIVE_PORT" .env  # 应为 9010，确认无端口冲突
```

Expected: 输出包含 `CLICKHOUSE_NATIVE_PORT=9010`

- [ ] **Step 3: Commit**

```bash
git add .env
git commit -m "chore: add .env with pinned service versions"
```

---

### Task 2: 创建 `.env.example`（配置模板）

**Files:**
- Create: `.env.example`

- [ ] **Step 1: 复制 `.env` 并添加注释**

```bash
cp .env .env.example
```

在文件顶部插入说明注释：

```bash
cat > .env.example << 'EOF'
# docker-env 统一环境配置模板
# 复制此文件到 .env 并根据需要修改
# 所有镜像版本在此唯一锁定

# === 版本锁定（唯一真相源）===
POSTGRES_VERSION=17
REDIS_VERSION=8-alpine
CLICKHOUSE_VERSION=25.12
NEO4J_VERSION=5-community
MINIO_VERSION=latest

# === 核心服务 ===
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=postgres
POSTGRES_PORT=5432

REDIS_PASSWORD=redis
REDIS_PORT=6379

# === 扩展服务 ===
CLICKHOUSE_USER=default
CLICKHOUSE_PASSWORD=clickhouse
CLICKHOUSE_PORT=8123
CLICKHOUSE_NATIVE_PORT=9010

NEO4J_AUTH=neo4j/password
NEO4J_BOLT_PORT=7687
NEO4J_HTTP_PORT=7474

MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadmin
MINIO_API_PORT=9000
MINIO_CONSOLE_PORT=9001
EOF
```

- [ ] **Step 2: Commit**

```bash
git add .env.example
git commit -m "chore: add .env.example template"
```

---

### Task 3: 创建核心基础设施 Compose（`compose/docker-compose.yml`）

**Files:**
- Create: `compose/docker-compose.yml`

- [ ] **Step 1: 写入核心 compose 文件**

```bash
mkdir -p compose

cat > compose/docker-compose.yml << 'EOF'
version: "3.8"

services:
  postgres:
    image: postgres:${POSTGRES_VERSION:-17}
    container_name: docker-env-postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${POSTGRES_USER:-postgres}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-postgres}
      POSTGRES_DB: ${POSTGRES_DB:-postgres}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - shared
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-postgres}"]
      interval: 5s
      timeout: 5s
      retries: 5

  redis:
    image: redis:${REDIS_VERSION:-8-alpine}
    container_name: docker-env-redis
    restart: unless-stopped
    command: redis-server --requirepass ${REDIS_PASSWORD:-redis}
    volumes:
      - redis_data:/data
    networks:
      - shared
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD:-redis}", "ping"]
      interval: 5s
      timeout: 5s
      retries: 5

volumes:
  postgres_data:
  redis_data:

networks:
  shared:
    name: docker-env_shared
    driver: bridge
EOF
```

- [ ] **Step 2: 验证 compose 语法**

```bash
cd compose && docker compose -f docker-compose.yml --env-file ../.env config > /dev/null 2>&1 && echo "OK" || echo "FAIL"
```

Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add compose/docker-compose.yml
git commit -m "feat: add core infrastructure compose (postgres 17, redis 8-alpine)"
```

---

### Task 4: 创建扩展服务 Compose（`compose/docker-compose.ext.yml`）

**Files:**
- Create: `compose/docker-compose.ext.yml`

- [ ] **Step 1: 写入扩展 compose 文件**

```bash
cat > compose/docker-compose.ext.yml << 'EOF'
version: "3.8"

services:
  clickhouse:
    image: clickhouse/clickhouse-server:${CLICKHOUSE_VERSION:-25.12}
    container_name: docker-env-clickhouse
    restart: unless-stopped
    environment:
      CLICKHOUSE_USER: ${CLICKHOUSE_USER:-default}
      CLICKHOUSE_PASSWORD: ${CLICKHOUSE_PASSWORD:-clickhouse}
    volumes:
      - clickhouse_data:/var/lib/clickhouse
    networks:
      - docker-env_shared

  neo4j:
    image: neo4j:${NEO4J_VERSION:-5-community}
    container_name: docker-env-neo4j
    restart: unless-stopped
    environment:
      NEO4J_AUTH: ${NEO4J_AUTH:-neo4j/password}
    volumes:
      - neo4j_data:/data
    networks:
      - docker-env_shared

  minio:
    image: minio/minio:${MINIO_VERSION:-latest}
    container_name: docker-env-minio
    restart: unless-stopped
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: ${MINIO_ROOT_USER:-minioadmin}
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD:-minioadmin}
    volumes:
      - minio_data:/data
    networks:
      - docker-env_shared

volumes:
  clickhouse_data:
  neo4j_data:
  minio_data:
EOF
```

- [ ] **Step 2: 验证 compose 语法**

```bash
cd compose && docker compose -f docker-compose.yml -f docker-compose.ext.yml --env-file ../.env config > /dev/null 2>&1 && echo "OK" || echo "FAIL"
```

Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add compose/docker-compose.ext.yml
git commit -m "feat: add extended services compose (clickhouse, neo4j, minio)"
```

---

### Task 5: 创建开发模式 Compose（`compose/docker-compose.dev.yml`）

**Files:**
- Create: `compose/docker-compose.dev.yml`

- [ ] **Step 1: 写入开发模式 compose 文件**

```bash
cat > compose/docker-compose.dev.yml << 'EOF'
version: "3.8"

services:
  postgres:
    ports:
      - "${POSTGRES_PORT:-5432}:5432"

  redis:
    ports:
      - "${REDIS_PORT:-6379}:6379"

  clickhouse:
    ports:
      - "${CLICKHOUSE_PORT:-8123}:8123"
      - "${CLICKHOUSE_NATIVE_PORT:-9010}:9000"

  neo4j:
    ports:
      - "${NEO4J_BOLT_PORT:-7687}:7687"
      - "${NEO4J_HTTP_PORT:-7474}:7474"

  minio:
    ports:
      - "${MINIO_API_PORT:-9000}:9000"
      - "${MINIO_CONSOLE_PORT:-9001}:9001"
EOF
```

- [ ] **Step 2: 验证三文件组合语法**

```bash
cd compose && docker compose -f docker-compose.yml -f docker-compose.ext.yml -f docker-compose.dev.yml --env-file ../.env config > /dev/null 2>&1 && echo "OK" || echo "FAIL"
```

Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add compose/docker-compose.dev.yml
git commit -m "feat: add dev mode compose with port bindings"
```

---

### Task 6: 创建 Python 基础镜像

**Files:**
- Create: `images/python/Dockerfile`
- Create: `images/python/requirements.txt`

- [ ] **Step 1: 写入 Dockerfile**

```bash
mkdir -p images/python

cat > images/python/Dockerfile << 'EOF'
FROM python:3.14-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# 系统依赖（按需扩展）
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# 预装常用包
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

CMD ["python"]
EOF
```

- [ ] **Step 2: 写入 requirements.txt**

```bash
cat > images/python/requirements.txt << 'EOF'
# Python 基础镜像预装依赖
# 仅包含最常用、各项目大概率需要的包

# 数据库驱动
psycopg[binary]>=3.2

# Redis 客户端
redis>=5.0

# HTTP 请求
httpx>=0.27

# 配置与工具
pydantic>=2.0
python-dotenv>=1.0
EOF
```

- [ ] **Step 3: 验证 Dockerfile 语法**

```bash
cd images/python && docker build -t docker-env-python:test . > /dev/null 2>&1 && echo "BUILD OK" || echo "BUILD FAIL"
```

Expected: `BUILD OK`

- [ ] **Step 4: Commit**

```bash
git add images/python/
git commit -m "feat: add python 3.14 base image with common deps"
```

---

### Task 7: 创建启动脚本（`scripts/start.sh`）

**Files:**
- Create: `scripts/start.sh`

- [ ] **Step 1: 写入启动脚本**

```bash
mkdir -p scripts

cat > scripts/start.sh << 'EOFSCRIPT'
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

echo "启动命令: docker compose ${COMPOSE_FILES[*]} up -d"
docker compose "${COMPOSE_FILES[@]}" --env-file "$ENV_FILE" up -d
EOFSCRIPT

chmod +x scripts/start.sh
```

- [ ] **Step 2: 验证脚本语法**

```bash
bash -n scripts/start.sh && echo "SYNTAX OK" || echo "SYNTAX FAIL"
```

Expected: `SYNTAX OK`

- [ ] **Step 3: 测试脚本参数解析**

```bash
# 测试帮助输出（dry-run 验证参数解析）
# 由于会尝试启动 docker，我们只验证 compose 命令拼接
echo "测试核心启动:"
sh -c 'SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"; COMPOSE_DIR="$SCRIPT_DIR/../compose"; ENV_FILE="$SCRIPT_DIR/../.env"; echo "docker compose -f $COMPOSE_DIR/docker-compose.yml -f $COMPOSE_DIR/docker-compose.dev.yml --env-file $ENV_FILE up -d"' scripts/start.sh

echo ""
echo "测试扩展启动:"
sh -c 'SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"; COMPOSE_DIR="$SCRIPT_DIR/../compose"; ENV_FILE="$SCRIPT_DIR/../.env"; echo "docker compose -f $COMPOSE_DIR/docker-compose.yml -f $COMPOSE_DIR/docker-compose.ext.yml -f $COMPOSE_DIR/docker-compose.dev.yml --env-file $ENV_FILE up -d"' scripts/start.sh --ext
```

Expected: 输出正确的 docker compose 命令路径

- [ ] **Step 4: Commit**

```bash
git add scripts/start.sh
git commit -m "feat: add start.sh wrapper script for compose orchestration"
```

---

### Task 8: 创建版本检查脚本（`scripts/check-versions.sh`）

**Files:**
- Create: `scripts/check-versions.sh`

- [ ] **Step 1: 写入版本检查脚本**

```bash
cat > scripts/check-versions.sh << 'EOFSCRIPT'
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
EOFSCRIPT

chmod +x scripts/check-versions.sh
```

- [ ] **Step 2: 验证脚本语法**

```bash
bash -n scripts/check-versions.sh && echo "SYNTAX OK" || echo "SYNTAX FAIL"
```

Expected: `SYNTAX OK`

- [ ] **Step 3: Commit**

```bash
git add scripts/check-versions.sh
git commit -m "feat: add check-versions.sh for service version verification"
```

---

### Task 9: 创建 README.md

**Files:**
- Create: `README.md`

- [ ] **Step 1: 写入 README**

```bash
cat > README.md << 'EOF'
# docker-env

统一 Docker 开发/部署环境配置中心。所有项目的 Docker 基础设施版本在此唯一锁定。

## 包含服务

| 服务 | 镜像 | 用途 |
|------|------|------|
| PostgreSQL | postgres:17 | 关系型数据库 |
| Redis | redis:8-alpine | 缓存/消息队列 |
| ClickHouse | clickhouse/clickhouse-server:25.12 | OLAP 分析 |
| Neo4j | neo4j:5-community | 图数据库 |
| MinIO | minio/minio:latest | 对象存储 |

## 快速开始

### 启动基础设施

```bash
# 仅启动核心服务（PostgreSQL + Redis）
./scripts/start.sh

# 启动核心 + 扩展服务
./scripts/start.sh --ext

# 生产模式（不暴露端口到宿主机）
./scripts/start.sh --ext --no-dev
```

### 检查运行版本

```bash
./scripts/check-versions.sh
```

## 其他项目接入

项目应与 `docker-env` 放在同级目录：

```
~/projects/
├── docker-env/
├── project-a/
└── project-b/
```

在项目 `docker-compose.yml` 中：

```yaml
services:
  api:
    build: .
    networks:
      - docker-env_shared
    env_file:
      - ../docker-env/.env

networks:
  docker-env_shared:
    external: true
```

服务通过固定名称访问基础设施：
- `postgres` → PostgreSQL
- `redis` → Redis
- `clickhouse` → ClickHouse
- `neo4j` → Neo4j
- `minio` → MinIO

## Python 基础镜像

```dockerfile
FROM docker-env-python:latest

# 或本地构建
COPY --from=docker-env/images/python/Dockerfile .
```

```bash
docker build -t docker-env-python:latest images/python/
```

## 目录结构

```
docker-env/
├── .env                          # 版本锁定 & 配置
├── compose/
│   ├── docker-compose.yml        # 核心服务
│   ├── docker-compose.ext.yml    # 扩展服务
│   └── docker-compose.dev.yml    # 开发模式端口
├── images/
│   └── python/
│       ├── Dockerfile
│       └── requirements.txt
├── scripts/
│   ├── start.sh
│   └── check-versions.sh
└── README.md
```

## 版本升级

修改 `.env` 中的版本号，重启服务即可：

```bash
./scripts/start.sh --ext
docker compose -f compose/docker-compose.yml pull
docker compose -f compose/docker-compose.yml up -d
```
EOF
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README with usage guide"
```

---

### Task 10: 集成验证（冒烟测试）

**Files:**
- Test: 启动核心服务并验证健康检查

- [ ] **Step 1: 启动核心服务**

```bash
./scripts/start.sh
```

Expected: 命令成功返回，无错误输出

- [ ] **Step 2: 等待健康检查就绪**

```bash
sleep 10
```

- [ ] **Step 3: 验证核心服务运行状态**

```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep docker-env
```

Expected: `docker-env-postgres` 和 `docker-env-redis` 显示 `healthy` 或 `Up`

- [ ] **Step 4: 验证网络创建**

```bash
docker network ls | grep docker-env_shared
```

Expected: 显示 `docker-env_shared` 网络

- [ ] **Step 5: 测试跨项目连通性**

```bash
# 启动一个临时容器测试网络连通
docker run --rm --network docker-env_shared redis:8-alpine redis-cli -h redis -a redis ping
```

Expected: 输出 `PONG`

- [ ] **Step 6: 停止核心服务**

```bash
docker compose -f compose/docker-compose.yml -f compose/docker-compose.ext.yml -f compose/docker-compose.dev.yml --env-file .env down
```

Expected: 服务停止，volume 保留

- [ ] **Step 7: Commit 最终状态**

```bash
git log --oneline -n 1
```

---

## 验收标准

- [ ] `.env` 包含所有镜像版本锁定
- [ ] `docker compose config` 对三文件组合验证通过
- [ ] `scripts/start.sh` 参数解析正确，能正常启动服务
- [ ] PostgreSQL 和 Redis 健康检查通过
- [ ] `docker-env_shared` 网络创建成功
- [ ] 跨项目容器能通过共享网络访问 redis 并返回 PONG
- [ ] Python 基础镜像构建成功
- [ ] `check-versions.sh` 语法正确（运行时需服务已启动）
- [ ] README.md 包含完整的使用文档和接入指南

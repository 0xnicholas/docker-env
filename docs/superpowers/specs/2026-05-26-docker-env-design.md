# docker-env 统一 Docker 环境设计文档

## 1. 背景与目标

当前本地存在多个版本的 PostgreSQL（`postgres:17` 与 `pgvector:pg16`）以及多个独立运行的基础设施服务，版本和配置分散在各项目中。本仓库旨在成为所有项目的**单一 Docker 环境配置中心**，通过统一的镜像版本、网络、配置约定，实现开发环境和构建流程的一致性。

### 目标
- 锁定所有基础设施镜像版本（唯一真相源）
- 所有项目共享同一套基础设施，通过固定网络接入
- 提供标准化的 Python 3.14 应用基础镜像
- 支持按需组合启动（核心 vs 扩展服务）
- 区分开发模式（端口暴露、volume 持久化）与生产/CI 模式

---

## 2. 架构方案：模块化分层（Modular）

采用**多 compose 文件组合**的方式，替代单一臃肿文件。

```
docker-env/
├── compose/
│   ├── docker-compose.yml           # 核心共享基础设施
│   ├── docker-compose.ext.yml       # 扩展服务（ClickHouse、Neo4j、MinIO）
│   └── docker-compose.dev.yml       # 开发模式优化（端口绑定、健康检查）
├── images/
│   └── python/
│       ├── Dockerfile               # 标准化 Python 3.14 应用构建镜像
│       └── requirements.txt         # 预装常用基础包
├── .env                             # 版本锁定 & 配置约定（唯一真相源）
├── .env.example                     # 配置模板
├── scripts/
│   ├── start.sh                     # 封装 compose 启动命令
│   └── check-versions.sh            # 检查版本一致性
└── README.md                        # 使用文档
```

### 设计原则
1. **单一真相源**：所有镜像版本、端口、密码集中在 `.env`
2. **共享网络**：所有服务挂载到 `docker-env_shared`，其他项目通过 `external: true` 接入
3. **按需组合**：通过 `-f` 参数组合 compose 文件
4. **开发友好**：`docker-compose.dev.yml` 提供端口暴露和持久化，生产/CI 不加载
5. **健康检查**：核心服务内置健康检查，确保依赖就绪

---

## 3. 服务定义

### 3.1 核心基础设施（`compose/docker-compose.yml`）

```yaml
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
```

**设计要点：**
- `container_name` 固定，便于其他项目通过名称引用
- `restart: unless-stopped` 开发友好，手动停止后不会自动重启
- `healthcheck` 确保服务就绪后才被依赖方使用

### 3.2 扩展服务（`compose/docker-compose.ext.yml`）

```yaml
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
```

**注意：** 扩展服务复用核心网络 `docker-env_shared`，不重新定义网络。

### 3.3 开发优化（`compose/docker-compose.dev.yml`）

```yaml
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
```

---

## 4. 环境变量（`.env`）

```bash
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
```

**设计要点：**
- 版本号和连接配置集中管理，升级时只改此处
- 密码为开发环境弱密码，不适用于生产部署
- 所有端口可通过环境变量覆盖，避免本地冲突

---

## 5. 基础镜像

### 5.1 Python 3.14 应用镜像（`images/python/Dockerfile`）

```dockerfile
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

# 预装常用包（可选）
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

CMD ["python"]
```

**设计要点：**
- 基于 `python:3.14-slim`，平衡体积与兼容性
- 环境变量优化 Python 运行行为
- 预装 `libpq-dev` 以支持 PostgreSQL 连接（Python 应用常见需求）
- 其他业务依赖通过各项目的 `requirements.txt` 或 `poetry` 安装

---

## 6. 脚本工具

### 6.1 `scripts/start.sh`

封装 compose 组合启动逻辑，避免手动拼接 `-f` 参数。

```bash
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
```

**用法：**
```bash
./scripts/start.sh              # 启动核心服务（开发模式）
./scripts/start.sh --ext        # 启动核心 + 扩展服务
./scripts/start.sh --ext --no-dev  # 启动全部服务，不暴露端口
```

### 6.2 `scripts/check-versions.sh`（未来扩展）

检查各服务实际运行版本与 `.env` 中锁定版本是否一致。

---

## 7. 其他项目接入方式

### 7.1 目录约定

所有项目与 `docker-env` 放在同级目录：

```
~/projects/
├── docker-env/
├── project-a/
└── project-b/
```

### 7.2 项目级 docker-compose.yml

```yaml
version: "3.8"

services:
  api:
    build: .
    networks:
      - docker-env_shared
    env_file:
      - ../docker-env/.env
    depends_on:
      - postgres
      - redis

networks:
  docker-env_shared:
    external: true
```

### 7.3 环境变量复用

项目可通过以下方式引用统一配置：
- **方式1**：`docker compose --env-file ../docker-env/.env up`
- **方式2**：在 `docker-compose.yml` 中声明 `env_file: - ../docker-env/.env`
- **方式3**：在项目中创建 `.env` 软链接：`ln -s ../docker-env/.env .env`

### 7.4 日常开发工作流

```bash
# 1. 启动统一基础设施（一次即可，除非 Docker Desktop 重启）
cd ~/projects/docker-env
./scripts/start.sh --ext

# 2. 启动项目 A（自动接入已有网络）
cd ~/projects/project-a
docker compose up
```

接入后，项目内服务可通过固定主机名访问基础设施：
- `postgres` → PostgreSQL 17
- `redis` → Redis 8
- `clickhouse` → ClickHouse 25.12
- `neo4j` → Neo4j 5
- `minio` → MinIO

---

## 8. 已知限制与注意事项

1. **端口冲突**：`.env` 中的默认端口（5432、6379 等）若与本地已安装服务冲突，可修改 `.env` 中的 `*_PORT` 变量
2. **MinIO 端口**：MinIO API 默认使用 9000，与 ClickHouse Native 端口冲突。已修正：ClickHouse Native 端口改为 9010
3. **密码安全**：`.env` 中为开发弱密码，生产环境应通过外部 secret 注入
4. **pgvector**：当前 PostgreSQL 17 需单独安装 pgvector 扩展。未来可在 `docker-compose.yml` 中切换到 `pgvector/pgvector:pg17` 镜像，或提供初始化 SQL 安装扩展

---

## 9. 后续扩展路径

- **方案 C 演进**：增加 `templates/` 项目脚手架、`new-project.sh` 一键生成
- **CI 构建**：GitHub Actions 自动构建 `images/python` 并推送至镜像仓库
- **pgvector 统一**：在 PostgreSQL 镜像中预装 pgvector，彻底解决版本分裂问题

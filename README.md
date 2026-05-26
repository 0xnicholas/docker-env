# docker-env

统一 Docker 开发/部署环境配置中心。所有项目的 Docker 基础设施版本在此唯一锁定。

## 包含服务

| 服务 | 镜像 | 用途 |
|------|------|------|
| PostgreSQL | postgres:17 | 关系型数据库 |
| Redis | redis:8.0 | 缓存/消息队列 |
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

```bash
# 构建基础镜像
docker build -t docker-env-python:latest images/python/
```

```dockerfile
# 在其他项目中使用
FROM docker-env-python:latest
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["python", "main.py"]
```

## 目录结构

```
docker-env/
├── .env                          # 版本锁定 & 配置
├── .env.example                  # 配置模板
├── compose/
│   ├── docker-compose.yml        # 所有服务定义
│   └── docker-compose.override.yml   # 开发模式端口（自动加载）
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

修改 `.env` 中的版本号，拉取并重启：

```bash
cd compose
docker compose --profile ext pull
docker compose --profile ext up -d
```

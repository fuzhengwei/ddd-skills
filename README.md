# xfg-ddd-skills · DDD 工程解决方案

> 一套完整的 DDD 六边形架构工程搭建与开发解决方案。
> 从项目创建、分层设计、代码规范到 DevOps 部署，覆盖工程全生命周期。

---

## 这是什么

**xfg-ddd-skills** 是一个面向 AI 编程助手（QClaw）的技能包，让 AI 具备 DDD 工程的完整落地能力。

日常开发中，DDD 最大的痛点不是理论，而是**落地**：

- 项目怎么搭？模块怎么划分？包名怎么定？
- Entity、Aggregate、VO 各放哪里？怎么写？
- Repository 接口定义在哪层？实现放哪里？
- 业务复杂了，Case 层怎么编排？
- 策略模式、责任链怎么在 DDD 里用？
- 部署时 Docker、docker-compose 怎么配？

这个技能包把上述问题的答案全部沉淀下来，让 AI 在你开口说"帮我创建 DDD 项目"或"帮我设计这个领域"时，直接给出符合规范的工程结构和代码。

---

## 解决什么问题

| 阶段 | 问题 | 解决方式 |
|------|------|----------|
| **工程搭建** | 多模块怎么划分、pom 怎么配 | 脚手架一键生成标准工程 |
| **分层设计** | 各层职责边界不清晰 | 明确的分层规范与依赖规则 |
| **领域建模** | Entity/Aggregate/VO 怎么写 | 完整的模板与示例代码 |
| **接口设计** | Repository/Port 定义在哪层 | 六边形架构端口适配器规范 |
| **复杂业务** | 多领域协作怎么编排 | Case 层编排模式 |
| **设计模式** | 策略/责任链怎么落地 | Domain 层模式指南 |
| **基础设施** | DAO/PO/Gateway 怎么组织 | Infrastructure 层规范 |
| **DevOps** | Docker 部署怎么配 | 标准 docker-compose 模板 |

---

## 架构全景

```
┌─────────────────────────────────────────────────────────────┐
│                      触发层 Trigger                          │
│              (HTTP Controller / MQ Listener / Job)           │
│              职责：接收请求，路由转发，不含业务逻辑            │
└─────────────────────────┬───────────────────────────────────┘
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                       API 层                                 │
│                  (DTO / Request / Response)                  │
│              职责：定义对外契约，纯数据结构                   │
└─────────────────────────┬───────────────────────────────────┘
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                      编排层 Case                             │
│              (业务编排 / 跨域协作 / 流程串联)                 │
│              职责：组合多个领域服务，完成复杂业务场景          │
└─────────────────────────┬───────────────────────────────────┘
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                      领域层 Domain                           │
│          (Entity / Aggregate / VO / Domain Service)         │
│              职责：核心业务逻辑，不依赖任何基础设施            │
└─────────────────────────┬───────────────────────────────────┘
                          ▲
┌─────────────────────────────────────────────────────────────┐
│                  基础设施层 Infrastructure                   │
│        (Repository Impl / Port Adapter / DAO / PO)          │
│              职责：实现领域层接口，处理数据持久化与外部调用    │
└─────────────────────────────────────────────────────────────┘
```

**核心依赖规则**：`Trigger → API → Case → Domain ← Infrastructure`

Domain 层不依赖任何框架，Infrastructure 层实现 Domain 层定义的接口。

---

## 工程结构

脚手架生成的标准多模块工程：

```
your-project/
├── your-project-types/          # 公共类型：枚举、常量、异常
├── your-project-domain/         # 领域层：Entity、Aggregate、VO、Service、接口定义
├── your-project-infrastructure/ # 基础设施层：Repository 实现、DAO、PO、Gateway
├── your-project-api/            # API 层：DTO、对外接口定义
├── your-project-case/           # 编排层：跨域业务流程编排
├── your-project-trigger/        # 触发层：HTTP Controller、MQ Listener、Job
├── your-project-app/            # 启动入口：Spring Boot Application
└── docs/dev-ops/                # 部署配置：docker-compose 模板
```

### Domain 层内部结构

```
domain/{bounded-context}/
├── adapter/
│   ├── port/                    # 外部系统端口接口（防腐层）
│   │   └── IXxxPort.java        # 远程调用抽象（HTTP/RPC）
│   └── repository/              # 仓储接口
│       └── IXxxRepository.java  # 数据持久化抽象
├── model/
│   ├── aggregate/               # 聚合对象（跨实体的事务边界）
│   ├── entity/                  # 实体（含命令实体 XxxCommandEntity）
│   └── valobj/                  # 值对象（含枚举 XxxEnumVO）
└── service/                     # 领域服务
    ├── IXxxService.java
    └── {capability}/
        └── XxxServiceImpl.java
```

### Infrastructure 层内部结构

```
infrastructure/
├── adapter/
│   ├── repository/              # 实现 Domain 层 IXxxRepository
│   └── port/                    # 实现 Domain 层 IXxxPort
├── dao/                         # MyBatis DAO 接口
│   └── po/                      # 数据库映射 PO 对象
├── gateway/                     # HTTP/RPC 客户端
│   └── dto/                     # 远程调用 DTO
└── redis/                       # Redis 配置
```

---

## 快速创建项目

### 方式一：通过 AI 对话（推荐）

在 QClaw 中直接说：

```
帮我在 /path/to/workspace 创建一个 DDD 项目，名称为 xfg-xxx
```

AI 会引导确认参数并自动生成完整工程。

### 方式二：Maven 命令行

```bash
mvn archetype:generate \
  -DarchetypeGroupId=io.github.fuzhengwei \
  -DarchetypeArtifactId=ddd-scaffold-std-jdk17 \
  -DarchetypeVersion=1.8 \
  -DarchetypeRepository=https://maven.xiaofuge.cn/ \
  -DgroupId=cn.bugstack \
  -DartifactId=your-project-name \
  -Dversion=1.0.0-SNAPSHOT \
  -Dpackage=cn.bugstack.your.project \
  -B
```

### 方式三：IDEA 图形界面

将脚手架仓库配置到 `~/.m2/settings.xml`，即可在 IDEA 的 **New Project → Maven Archetype** 中直接选用。

<details>
<summary>展开查看 settings.xml 配置</summary>

```xml
<profiles>
  <profile>
    <id>xfg-archetype</id>
    <repositories>
      <repository>
        <id>xfg-archetype-repo</id>
        <name>小傅哥 DDD 脚手架仓库</name>
        <url>https://maven.xiaofuge.cn/</url>
        <releases><enabled>true</enabled></releases>
        <snapshots><enabled>false</enabled></snapshots>
      </repository>
    </repositories>
    <pluginRepositories>
      <pluginRepository>
        <id>xfg-archetype-plugin-repo</id>
        <url>https://maven.xiaofuge.cn/</url>
        <releases><enabled>true</enabled></releases>
        <snapshots><enabled>false</enabled></snapshots>
      </pluginRepository>
    </pluginRepositories>
  </profile>
</profiles>

<activeProfiles>
  <activeProfile>xfg-archetype</activeProfile>
</activeProfiles>
```

配置后执行 `mvn archetype:update-local-catalog` 更新本地目录。

在 IDEA 中若列表未出现，点击 **Add Archetype** 手动填写：
- GroupId：`io.github.fuzhengwei`
- ArtifactId：`ddd-scaffold-std-jdk17`
- Version：`1.8`

</details>

---

## 参考文档

| 主题 | 文档 |
|------|------|
| 架构概览 | [references/architecture.md](references/architecture.md) |
| 项目结构 | [references/project-structure.md](references/project-structure.md) |
| 命名规范 | [references/naming.md](references/naming.md) |
| 实体设计 | [references/entity.md](references/entity.md) |
| 聚合根设计 | [references/aggregate.md](references/aggregate.md) |
| 值对象设计 | [references/value-object.md](references/value-object.md) |
| 仓储模式 | [references/repository.md](references/repository.md) |
| 端口与适配器 | [references/port-adapter.md](references/port-adapter.md) |
| 领域服务 | [references/domain-service.md](references/domain-service.md) |
| 领域设计指南 | [references/domain-design-guide.md](references/domain-design-guide.md) |
| 领域核心模式 | [references/domain-patterns.md](references/domain-patterns.md) |
| 编排层设计 | [references/case-layer.md](references/case-layer.md) |
| 触发层设计 | [references/trigger-layer.md](references/trigger-layer.md) |
| 基础设施层 | [references/infrastructure-layer.md](references/infrastructure-layer.md) |
| 基础设施模式 | [references/infrastructure-patterns.md](references/infrastructure-patterns.md) |
| DevOps 部署 | [references/devops-deployment.md](references/devops-deployment.md) |
| Docker 镜像 | [references/docker-images.md](references/docker-images.md) |

---

## 参考项目

| 项目 | 说明 |
|------|------|
| [group-buy-market](https://bugstack.cn/md/project/group-buy-market/group-buy-market.html) | 拼团营销领域完整实现，含策略模式、责任链、领域事件 |
| [ai-mcp-gateway](https://bugstack.cn/md/project/ai-mcp-gateway/ai-mcp-gateway.html) | AI MCP 网关领域完整实现，含端口适配器、多模型路由 |

---

## License

MIT © [小傅哥 bugstack.cn](https://bugstack.cn)

# Project Structure Reference

## Maven Multi-Module Structure

```
{project-name}/
├── pom.xml                          # Parent POM
├── {project}-types/                 # Common types
│   ├── pom.xml
│   └── src/main/java/
│       └── cn/{company}/types/
│           ├── enums/               # Enums
│           ├── exception/           # Exceptions
│           └── common/              # Common utils
│
├── {project}-domain/                # Domain layer
│   ├── pom.xml
│   └── src/main/java/
│       └── cn/{company}/domain/
│           ├── {domain1}/
│           │   ├── adapter/                    # ⭐ 适配器接口（定义在此层）
│           │   │   ├── port/
│           │   │   │   └── IProductPort.java   # 远程调用接口（HTTP/RPC）
│           │   │   └── repository/
│           │   │       └── IOrderRepository.java # 本地仓储接口（MySQL/Redis）
│           │   ├── model/
│           │   │   ├── aggregate/    # Aggregates
│           │   │   ├── entity/       # Entities
│           │   │   └── valobj/       # Value objects
│           │   └── service/          # Domain services
│           │       ├── I{Domain}Service.java
│           │       └── impl/
│           └── {domain2}/
│               └── ...
│
├── {project}-infrastructure/        # Infrastructure layer
│   ├── pom.xml
│   └── src/main/java/
│       └── cn/{company}/infrastructure/
│           ├── adapter/                        # ⭐ 适配器实现
│           │   ├── port/                       # Port 实现（远程调用）
│           │   │   └── XxxPort.java           # HTTP / RPC / WebSocket
│           │   └── repository/                 # Repository 实现（本地数据）
│           │       └── XxxRepository.java     # MySQL + Redis
│           ├── dao/                            # ⭐ MyBatis DAO 接口
│           │   ├── po/                         # ⭐ PO 对象（数据库映射）
│           │   │   └── XxxPO.java
│           │   └── IXxxDao.java
│           ├── gateway/                       # ⭐ HTTP/RPC 客户端
│           │   ├── dto/                        # ⭐ 远程调用 DTO
│           │   │   ├── XxxRequestDTO.java
│           │   │   └── XxxResponseDTO.java
│           │   └── XxxGateway.java             # HTTP 服务客户端
│           ├── redis/                         # Redis 配置
│           └── config/                        # 配置类
│
├── {project}-api/                   # API layer
│   ├── pom.xml
│   └── src/main/java/
│       └── cn/{company}/api/
│           ├── I{Domain}Service.java # RPC interfaces
│           ├── dto/                  # DTOs
│           └── error/                # Error codes
│
├── {project}-case/                  # Case layer
│   ├── pom.xml
│   └── src/main/java/
│       └── cn/{company}/cases/
│           └── {domain}/
│               ├── I{Domain}CaseService.java
│               ├── impl/
│               ├── node/            # 复杂流程节点
│               └── factory/         # 流程工厂
│
├── {project}-trigger/               # Trigger layer
│   ├── pom.xml
│   └── src/main/java/
│       └── cn/{company}/trigger/
│           ├── http/                 # Controllers
│           ├── mq/                   # MQ listeners
│           └── job/                  # Scheduled jobs
│
└── {project}-app/                   # Application (main)
    ├── pom.xml
    └── src/main/
        ├── java/
        │   └── cn/{company}/
        │       └── Application.java
        └── resources/
            ├── application.yml
            └── mybatis/                         # ⭐ MyBatis 配置
                └── mapper/                     # ⭐ Mapper XML 文件
                    └── xxx_mapper.xml
```

## Infrastructure 层职责

| 目录 | 职责 | 技术栈 |
|------|------|--------|
| `adapter/repository/` | 实现 Repository 接口 | MySQL + Redis |
| `adapter/port/` | 实现 Port 接口 | HTTP + RPC |
| `dao/` | MyBatis DAO 接口 | MyBatis Mapper |
| `dao/po/` | PO 对象（数据库映射） | Java Bean |
| `gateway/` | HTTP/RPC 客户端 | OkHttp / Retrofit |
| `gateway/dto/` | 远程调用 DTO | JSON 序列化 |
| `mybatis/mapper/` | Mapper XML 文件 | MyBatis XML |

## DAO 与 PO 规范

### 目录结构

```
infrastructure/
└── dao/
    ├── po/
    │   ├── UserPO.java
    │   ├── OrderPO.java
    │   └── base/           # 基类 PO
    │       └── BasePO.java
    └── IUserDao.java
```

### DAO 接口命名

```
接口名：I{Xxx}Dao
示例：IUserDao、IOrderDao、IProductDao
```

### PO 对象命名

```
类名：{Xxx}PO
示例：UserPO、OrderPO、ProductPO
```

## Gateway 与 DTO 规范

### 目录结构

```
infrastructure/
└── gateway/
    ├── dto/
    │   ├── UserRequestDTO.java
    │   └── UserResponseDTO.java
    └── UserGatewayService.java
```

### Gateway 命名

```
服务类：XxxGatewayService
示例：ProductGatewayService、OrderGatewayService
DTO：XxxRequestDTO / XxxResponseDTO
```

## MyBatis Mapper XML 规范

### 存放位置

```
{project}-app/src/main/resources/mybatis/mapper/
├── user_mapper.xml
├── order_mapper.xml
└── product_mapper.xml
```

### namespace 规范

```xml
<mapper namespace="cn.{company}.infrastructure.dao.I{Xxx}Dao">
```

## POM Dependencies

### Parent POM

```xml
<project>
    <groupId>cn.{company}</groupId>
    <artifactId>{project}</artifactId>
    <version>1.0.0</version>
    <packaging>pom</packaging>
    
    <modules>
        <module>{project}-types</module>
        <module>{project}-domain</module>
        <module>{project}-infrastructure</module>
        <module>{project}-api</module>
        <module>{project}-case</module>
        <module>{project}-trigger</module>
        <module>{project}-app</module>
    </modules>
    
    <dependencyManagement>
        <dependencies>
            <!-- Internal modules -->
            <dependency>
                <groupId>${project.groupId}</groupId>
                <artifactId>{project}-types</artifactId>
                <version>${project.version}</version>
            </dependency>
            <dependency>
                <groupId>${project.groupId}</groupId>
                <artifactId>{project}-domain</artifactId>
                <version>${project.version}</version>
            </dependency>
            <!-- ... -->
        </dependencies>
    </dependencyManagement>
</project>
```

### Domain POM

```xml
<project>
    <artifactId>{project}-domain</artifactId>
    
    <dependencies>
        <!-- Only types, no infrastructure! -->
        <dependency>
            <groupId>${project.groupId}</groupId>
            <artifactId>{project}-types</artifactId>
        </dependency>
    </dependencies>
</project>
```

### Infrastructure POM

```xml
<project>
    <artifactId>{project}-infrastructure</artifactId>
    
    <dependencies>
        <!-- Domain for interfaces -->
        <dependency>
            <groupId>${project.groupId}</groupId>
            <artifactId>{project}-domain</artifactId>
        </dependency>
        
        <!-- Infrastructure frameworks -->
        <dependency>
            <groupId>org.mybatis.spring.boot</groupId>
            <artifactId>mybatis-spring-boot-starter</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-redis</artifactId>
        </dependency>
        <dependency>
            <groupId>com.squareup.okhttp3</groupId>
            <artifactId>okhttp</artifactId>
        </dependency>
    </dependencies>
</project>
```

### Trigger POM

```xml
<project>
    <artifactId>{project}-trigger</artifactId>
    
    <dependencies>
        <dependency>
            <groupId>${project.groupId}</groupId>
            <artifactId>{project}-api</artifactId>
        </dependency>
        <dependency>
            <groupId>${project.groupId}</groupId>
            <artifactId>{project}-case</artifactId>
        </dependency>
    </dependencies>
</project>
```

## Dependency Rules

```
┌─────────────────────────────────────────────────────────────┐
│                       app                                   │
│                    (all modules)                            │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                     trigger                                 │
│                   (api, case)                               │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                      case                                   │
│                   (api, domain)                             │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                      api                                    │
│                    (types)                                  │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                     domain                                  │
│                    (types)                                  │
└─────────────────────────┬───────────────────────────────────┘
                          ▲
                          │
┌─────────────────────────────────────────────────────────────┐
│                  infrastructure                             │
│                   (domain)                                  │
└─────────────────────────────────────────────────────────────┘
```

## Critical Rules

1. **Domain has NO infrastructure dependencies**
2. **Infrastructure implements Domain interfaces**
3. **Trigger depends on API and Case only**
4. **All modules depend on Types**

## 参考项目

- [group-buy-market](file:///Users/fuzhengwei/Documents/project/ddd-demo/group-buy-market) - 完整的多模块实现
- [ai-mcp-gateway](file:///Users/fuzhengwei/Documents/project/ddd-demo/ai-mcp-gateway) - Gateway + DTO 示例

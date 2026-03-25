---
name: xfg-ddd-skills
version: 2.1.0
description: "DDD 六边形架构设计与开发技能包。包含：领域层设计（Aggregate/Entity/CommandEntity/ValueObject/EnumVO）、Domain Service（策略模式/责任链模式/模板方法）、Repository、Port适配器、Case编排层、Trigger触发层、Infrastructure基础设施层。参考 group-buy-market 真实工程规范。触发词：'DDD'、'六边形架构'、'领域驱动设计'、'创建 DDD 项目'、'新建项目'。不要用于简单 CRUD 应用或没有领域复杂度的微服务。@小傅哥"
author: xiaofuge
license: MIT
triggers:
  - "DDD"
  - "六边形架构"
  - "domain-driven design"
  - "领域驱动设计"
  - "ports and adapters"
  - "创建 Entity"
  - "创建聚合根"
  - "创建 DDD 项目"
  - "新建项目"
  - "Aggregate"
  - "ValueObject"
  - "值对象"
  - "聚合根"
metadata:
  openclaw:
    emoji: "🏗️"
---

# DDD Hexagonal Architecture

Design and implement software using Domain-Driven Design with Hexagonal Architecture. This skill provides patterns, templates, and best practices for building maintainable domain-centric applications.

## Scripts

### 创建 DDD 项目

当用户说"创建 DDD 项目"、"新建项目"、"创建项目"、"创建ddd项目"时，**必须使用 `scripts/create-ddd-project.sh` 脚本**。

**脚本支持系统**: Windows (Git Bash/MSYS2)、Mac (macOS)、Linux，自动检测并适配。

**⚠️ 环境提醒**: 建议提前安装 JDK 17+ 和 Maven 3.8.*，脚本启动时会自动检测并给出各平台安装指引，未安装也可继续但可能导致生成失败。

**⚠️ 重要提醒：必须询问用户项目创建地址**

**在创建项目前，如果用户没有明确给出工程创建地址，必须询问用户在哪里创建项目。** 不能随意创建到默认目录，必须获得用户确认。

示例对话：
```
用户：帮我创建一个 DDD 项目
AI：好的，我来帮您创建 DDD 项目。请问您希望将项目创建在哪个目录？
     例如：
     1) /Users/xxx/projects
     2) /Users/xxx/Documents
     3) /home/xxx/workspace
     4) 其他路径（请直接输入）

用户：创建在 /Users/xxx/projects 下
AI：确认在 /Users/xxx/projects 下创建项目，开始执行...
```

**流程:**

1. **第一步：确认项目创建目录**

   **必须询问用户**，如果用户未指定，列出可选项供用户选择。

   示例：
   ```
   📂 选择项目生成目录
   ──────────────────────────────
   1) /Users/xxx/projects
   2) /Users/xxx/Documents
   3) /home/xxx/workspace
   4) 自定义路径（直接输入路径）

   直接回车 = 选择 [1]
   ```

2. **第二步：填写项目配置**（逐一询问，直接回车使用默认值）

   | 参数 | 说明 | 默认值 | 示例 |
   |------|------|--------|------|
   | GroupId | Maven 坐标 groupId，标识组织或公司 | `com.yourcompany` | `cn.bugstack` |
   | ArtifactId | 项目模块唯一标识名称 | `your-project-name` | `order-system` |
   | Version | 项目版本号 | `1.0.0-SNAPSHOT` | `1.0.0-RELEASE` |
   | Package | Java 代码根包名 | 自动从 GroupId + ArtifactId 推导 | `cn.bugstack.order` |
   | Archetype 版本 | 脚手架模板版本 | `1.3` | - |

3. **第三步：确认并生成**

   显示所有配置，确认后执行 Maven Archetype 生成项目。

**脚本执行方式**（在 `ddd-skills-v2` 项目根目录下运行）:
```bash
bash scripts/create-ddd-project.sh
```

> ⚠️ **必须先 cd 到 `ddd-skills-v2` 项目目录下再执行**，脚本会自动定位自身路径。
> AI 负责引导用户选择目录、填写参数，无需手动拼凑 Maven 命令。
> **⚠️ 再次强调：创建项目前必须询问用户项目创建地址，不能随意创建！**

---

## Quick Reference

| Task | Reference |
|------|-----------|
| Architecture overview | [references/architecture.md](references/architecture.md) |
| Entity design | [references/entity.md](references/entity.md) |
| Aggregate design | [references/aggregate.md](references/aggregate.md) |
| Value Object design | [references/value-object.md](references/value-object.md) |
| Repository pattern | [references/repository.md](references/repository.md) |
| Port & Adapter | [references/port-adapter.md](references/port-adapter.md) |
| Domain Service | [references/domain-service.md](references/domain-service.md) |
| Case layer orchestration | [references/case-layer.md](references/case-layer.md) |
| Trigger layer | [references/trigger-layer.md](references/trigger-layer.md) |
| Infrastructure layer | [references/infrastructure-layer.md](references/infrastructure-layer.md) |
| Project structure | [references/project-structure.md](references/project-structure.md) |
| Naming conventions | [references/naming.md](references/naming.md) |
| Docker Images | [references/docker-images.md](references/docker-images.md) |

## Architecture Layers

```
┌─────────────────────────────────────────────────────────────┐
│                     Trigger Layer                            │
│         (HTTP Controller / MQ Listener / Job)               │
└─────────────────────────┬───────────────────────────────────┘
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                       API Layer                              │
│              (DTO / Request / Response)                     │
└─────────────────────────┬───────────────────────────────────┘
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                      Case Layer                              │
│            (Orchestration / Business Flow)                   │
└─────────────────────────┬───────────────────────────────────┘
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                     Domain Layer                             │
│        (Entity / Aggregate / VO / Domain Service)           │
└─────────────────────────┬───────────────────────────────────┘
                          ▲
┌─────────────────────────────────────────────────────────────┐
│                  Infrastructure Layer                        │
│      (Repository Impl / Port Adapter / DAO / PO)            │
└─────────────────────────────────────────────────────────────┘
```

**Dependency Rule**: `Trigger → API → Case → Domain ← Infrastructure`

## Domain Layer 目录结构

```
model/
├── aggregate/              # 聚合对象
│   └── XxxAggregate.java
├── entity/               # 实体对象
│   ├── XxxEntity.java          # 普通实体
│   └── XxxCommandEntity.java  # 命令实体
└── valobj/               # 值对象
    ├── XxxVO.java             # 普通值对象
    └── XxxEnumVO.java         # 枚举值对象
```

**⚠️ 注意**：`model/` 下没有单独的 `command/` 包，命令实体统一放在 `entity/` 包下。

## Quick Templates

### Aggregate 聚合对象

```java
@Data @Builder @AllArgsConstructor @NoArgsConstructor
public class GroupBuyOrderAggregate {
    /** 用户实体对象 */
    private UserEntity userEntity;
    /** 支付活动实体对象 */
    private PayActivityEntity payActivityEntity;
    /** 支付优惠实体对象 */
    private PayDiscountEntity payDiscountEntity;
    /** 已参与拼团量 */
    private Integer userTakeOrderCount;
}
```

### Entity 普通实体

```java
@Data @Builder @AllArgsConstructor @NoArgsConstructor
public class MarketPayOrderEntity {
    private String teamId;
    private String orderId;
    private BigDecimal originalPrice;
    private BigDecimal deductionPrice;
    private BigDecimal payPrice;
    private TradeOrderStatusEnumVO tradeOrderStatusEnumVO;
}
```

### Entity 命令实体（放在 entity 包）

```java
/** 命令实体放在 entity 包，使用 CommandEntity 后缀 */
@Data @Builder @AllArgsConstructor @NoArgsConstructor
public class TradeLockRuleCommandEntity {
    private String userId;
    private Long activityId;
    private String teamId;
}
```

### Value Object 值对象

```java
@Getter @Builder @AllArgsConstructor @NoArgsConstructor
public class NotifyConfigVO {
    private NotifyTypeEnumVO notifyType;
    private String notifyMQ;
    private String notifyUrl;
}
```

### EnumVO 枚举值对象（可包含策略逻辑）

```java
@Getter @AllArgsConstructor
public enum RefundTypeEnumVO {

    UNPAID_UNLOCK("unpaid_unlock", "Unpaid2RefundStrategy", "未支付，未成团") {
        @Override
        public boolean matches(GroupBuyOrderEnumVO groupBuyOrderEnumVO, TradeOrderStatusEnumVO tradeOrderStatusEnumVO) {
            return GroupBuyOrderEnumVO.PROGRESS.equals(groupBuyOrderEnumVO) 
                && TradeOrderStatusEnumVO.CREATE.equals(tradeOrderStatusEnumVO);
        }
    },
    
    PAID_UNFORMED("paid_unformed", "Paid2RefundStrategy", "已支付，未成团") {
        @Override
        public boolean matches(GroupBuyOrderEnumVO groupBuyOrderEnumVO, TradeOrderStatusEnumVO tradeOrderStatusEnumVO) {
            return GroupBuyOrderEnumVO.PROGRESS.equals(groupBuyOrderEnumVO) 
                && TradeOrderStatusEnumVO.COMPLETE.equals(tradeOrderStatusEnumVO);
        }
    };

    private String code;
    private String strategy;
    private String info;

    public abstract boolean matches(GroupBuyOrderEnumVO groupBuyOrderEnumVO, TradeOrderStatusEnumVO tradeOrderStatusEnumVO);

    public static RefundTypeEnumVO getRefundStrategy(GroupBuyOrderEnumVO g, TradeOrderStatusEnumVO t) {
        return Arrays.stream(values()).filter(v -> v.matches(g, t)).findFirst()
                .orElseThrow(() -> new RuntimeException("不支持的退款状态组合"));
    }
}
```

### Domain Service 完整编码

```java
/** 1. 定义服务接口 */
public interface ITradeLockOrderService {
    MarketPayOrderEntity lockMarketPayOrder(UserEntity user, PayActivityEntity activity, PayDiscountEntity discount) throws Exception;
}

/** 2. 实现服务（放在子包中） */
@Slf4j @Service
public class TradeLockOrderService implements ITradeLockOrderService {

    @Resource private ITradeRepository repository;
    @Resource private BusinessLinkedList<TradeLockRuleCommandEntity, TradeLockRuleFilterFactory.DynamicContext, TradeLockRuleFilterBackEntity> tradeRuleFilter;

    @Override
    public MarketPayOrderEntity lockMarketPayOrder(UserEntity userEntity, PayActivityEntity payActivityEntity, PayDiscountEntity payDiscountEntity) throws Exception {
        log.info("锁定营销优惠支付订单:{} activityId:{}", userEntity.getUserId(), payActivityEntity.getActivityId());

        // 1. 交易规则过滤（责任链）
        TradeLockRuleFilterBackEntity back = tradeRuleFilter.apply(TradeLockRuleCommandEntity.builder()
                .activityId(payActivityEntity.getActivityId())
                .userId(userEntity.getUserId())
                .teamId(payActivityEntity.getTeamId()).build(),
                new TradeLockRuleFilterFactory.DynamicContext());

        // 2. 构建聚合对象
        GroupBuyOrderAggregate aggregate = GroupBuyOrderAggregate.builder()
                .userEntity(userEntity)
                .payActivityEntity(payActivityEntity)
                .payDiscountEntity(payDiscountEntity)
                .userTakeOrderCount(back.getUserTakeOrderCount())
                .build();

        // 3. 锁定聚合订单
        return repository.lockMarketPayOrder(aggregate);
    }
}
```

### 策略模式实现

```java
/** 1. 策略接口 */
public interface IRefundOrderStrategy {
    void refundOrder(TradeRefundOrderEntity entity) throws Exception;
    void reverseStock(TeamRefundSuccess success) throws Exception;
}

/** 2. 抽象基类（模板方法） */
@Slf4j
public abstract class AbstractRefundOrderStrategy implements IRefundOrderStrategy {
    @Resource protected ITradeRepository repository;
    @Resource protected ThreadPoolExecutor threadPoolExecutor;

    protected void doReverseStock(TeamRefundSuccess s, String type) throws Exception {
        log.info("退单恢复锁单量 - {}", type);
        repository.refund2AddRecovery(s.getActivityId() + ":" + s.getTeamId(), s.getOrderId());
    }
}

/** 3. 具体策略 */
@Slf4j @Service("paid2RefundStrategy")
public class Paid2RefundStrategy extends AbstractRefundOrderStrategy {
    @Override
    public void refundOrder(TradeRefundOrderEntity e) throws Exception {
        log.info("退单-已支付，未成团 userId:{}", e.getUserId());
        NotifyTaskEntity n = repository.paid2Refund(GroupBuyRefundAggregate.buildPaid2RefundAggregate(e, -1, -1));
        if (n != null) threadPoolExecutor.execute(() -> tradeTaskService.execNotifyJob(n));
    }
    @Override
    public void reverseStock(TeamRefundSuccess s) throws Exception {
        doReverseStock(s, "已支付，但有锁单记录，恢复锁单库存");
    }
}
```

## Core Principles

| Principle | Description |
|-----------|-------------|
| **Dependency Inversion** | Domain defines interfaces, Infrastructure implements |
| **Rich Domain Model** | Entity contains both data and behavior |
| **Aggregate Boundary** | Transaction consistency inside, eventual consistency outside |
| **Anti-Corruption Layer** | Use Port to isolate external systems |
| **Lightweight Trigger** | Trigger layer only routes requests, no business logic |

## When to Use DDD

**Use DDD when:**
- Complex business domain with rich rules
- Need to capture domain knowledge in code
- Long-lived project with evolving requirements
- Team needs shared domain language

**Don't use DDD when:**
- Simple CRUD operations
- Prototype or throwaway code
- Domain logic is trivial
- Team unfamiliar with DDD concepts

## Example Projects

- [group-buy-market](file:///Users/fuzhengwei/Documents/project/ddd-demo/group-buy-market) - E-commerce domain
- [ai-mcp-gateway](file:///Users/fuzhengwei/Documents/project/ddd-demo/ai-mcp-gateway) - API gateway domain

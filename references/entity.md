# Entity 实体对象设计规范

## 概述

Entity（实体对象）是 DDD 领域层中最核心的概念之一。它代表具有唯一标识的对象，其生命周期内身份保持不变。

## 目录结构

```
model/
├── aggregate/              # 聚合根
│   └── XxxAggregate.java
├── entity/               # ⭐ 实体对象（包括命令实体）
│   ├── XxxEntity.java     # 普通实体对象
│   └── XxxCommandEntity.java  # 命令实体对象
└── valobj/               # 值对象
    ├── XxxVO.java        # 值对象
    └── XxxEnumVO.java   # 枚举值对象
```

**⚠️ 注意**：不要创建单独的 `command/` 包，命令实体统一放在 `entity/` 包下。

## 命名规范

| 类型 | 命名规范 | 示例 | 说明 |
|------|---------|------|------|
| 普通实体 | `XxxEntity` | `UserEntity` | 代表业务主体 |
| 命令实体 | `XxxCommandEntity` | `TradeLockRuleCommandEntity` | 用于接收输入/命令 |
| 过滤反馈实体 | `XxxFilterBackEntity` | `TradeLockRuleFilterBackEntity` | 责任链模式返回结果 |

## 普通实体对象

### 定义

普通实体对象代表业务领域中具有唯一标识和生命周期的主体。

### 特征

- **唯一标识**：具有唯一 ID
- **生命周期**：有创建、修改、删除等状态变化
- **连续性**：标识在生命周期内保持不变
- **行为**：封装了与自身相关的业务行为

### 编码示例

```java
package cn.bugstack.domain.trade.model.entity;

import cn.bugstack.domain.trade.model.valobj.TradeOrderStatusEnumVO;
import lombok.*;

/**
 * 拼团，预购订单营销实体对象
 * @author Fuzhengwei bugstack.cn @小傅哥
 */
@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class MarketPayOrderEntity {

    /** 拼单组队ID */
    private String teamId;
    
    /** 预购订单ID */
    private String orderId;
    
    /** 原始价格 */
    private BigDecimal originalPrice;
    
    /** 折扣金额 */
    private BigDecimal deductionPrice;
    
    /** 支付金额 */
    private BigDecimal payPrice;
    
    /** 交易订单状态枚举 */
    private TradeOrderStatusEnumVO tradeOrderStatusEnumVO;

}
```

## 命令实体对象

### 定义

命令实体对象（Command Entity）用于接收来自外部的输入命令，通常用于：
- Controller 传入的请求参数
- 服务间的调用参数
- 责任链/过滤器模式的输入参数

### 特征

- **无状态**：只承载数据，不持有业务状态
- **扁平化**：属性结构尽量扁平，避免深层嵌套
- **验证**：可以包含参数校验逻辑
- **命名后缀**：统一使用 `CommandEntity` 后缀

### 编码示例

```java
package cn.bugstack.domain.trade.model.entity;

import lombok.*;

/**
 * 拼团交易命令实体
 * @author Fuzhengwei bugstack.cn @小傅哥
 */
@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class TradeLockRuleCommandEntity {

    /** 用户ID */
    private String userId;
    
    /** 活动ID */
    private Long activityId;
    
    /** 组队ID */
    private String teamId;

}
```

## 过滤反馈实体

### 定义

过滤反馈实体（Filter Back Entity）用于责任链/过滤器模式中，返回过滤执行后的结果。

### 编码示例

```java
package cn.bugstack.domain.trade.model.entity;

import lombok.*;

/**
 * 拼团交易，过滤反馈实体
 * @author Fuzhengwei bugstack.cn @小傅哥
 */
@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class TradeLockRuleFilterBackEntity {

    /** 用户参与活动的订单量 */
    private Integer userTakeOrderCount;

    /** 恢复组队库存缓存key */
    private String recoveryTeamStockKey;

}
```

## 实体与值对象的区别

| 维度 | 实体 Entity | 值对象 Value Object |
|------|-------------|-------------------|
| 标识 | 有唯一标识 | 无标识，通过属性值相等 |
| 可变性 | 可变状态 | 不可变，创建后不可修改 |
| 生命周期 | 有生命周期 | 无生命周期概念 |
| 相等性判断 | 通过 ID 判断 | 通过属性值判断 |
| 存放位置 | `entity/` 包 | `valobj/` 包 |
| 命名后缀 | `XxxEntity` | `XxxVO` / `XxxEnumVO` |

## 真实工程示例

参考 `group-buy-market` 项目的 entity 目录结构：

```
domain/trade/model/entity/
├── MarketPayOrderEntity.java              # 普通实体
├── GroupBuyTeamEntity.java                # 普通实体
├── UserEntity.java                        # 普通实体
├── PayActivityEntity.java                 # 普通实体
├── PayDiscountEntity.java                 # 普通实体
├── TradeRefundCommandEntity.java          # 命令实体
├── TradeLockRuleCommandEntity.java        # 命令实体
├── TradeSettlementRuleCommandEntity.java  # 命令实体
├── TradeLockRuleFilterBackEntity.java     # 过滤反馈实体
└── TradeSettlementRuleFilterBackEntity.java # 过滤反馈实体
```

## 设计原则

### 1. 实体应包含业务行为

```java
// ✅ 正确：实体包含行为
@Data
public class OrderEntity {
    private String orderId;
    private BigDecimal amount;
    
    public void pay() {
        // 支付逻辑
    }
    
    public boolean canRefund() {
        // 退款条件判断
        return true;
    }
}

// ❌ 错误：实体只是数据容器
@Data
public class OrderEntity {
    private String orderId;
    private BigDecimal amount;
    // 只有 getter/setter
}
```

### 2. 命令实体保持简洁

```java
// ✅ 正确：命令实体简洁扁平
@Data
public class CreateOrderCommandEntity {
    private String userId;
    private Long activityId;
    private BigDecimal amount;
}

// ❌ 错误：命令实体嵌套过深
@Data
public class CreateOrderCommandEntity {
    private UserInfo user;      // 嵌套对象，尽量避免
    private Activity activity;  // 保持扁平化
}
```

### 3. 避免贫血模型

实体应该有丰富的业务行为，而不是只有 getter/setter：

```java
@Data
public class FormDefinitionEntity {

    private Long id;
    private String name;
    private String status;
    private List<FormFieldEntity> fields;

    // ✅ 业务行为方法
    public boolean canPublish() {
        return "draft".equals(status) && fields != null && !fields.isEmpty();
    }

    public void publish() {
        if (!canPublish()) {
            throw new IllegalStateException("表单不能发布");
        }
        this.status = "published";
    }

    public void addField(FormFieldEntity field) {
        if (fields == null) {
            fields = new ArrayList<>();
        }
        fields.add(field);
    }
}
```

## 常见问题

### Q: 什么时候用命令实体？

当需要接收外部输入时使用命令实体：
- Controller 的请求参数
- Domain Service 的入参
- 过滤器/责任链的输入参数

### Q: 命令实体和普通实体的区别？

| 维度 | 普通实体 | 命令实体 |
|------|---------|---------|
| 生命周期 | 有完整生命周期 | 只存在于请求处理中 |
| 状态 | 有业务状态 | 无状态，只有数据 |
| 行为 | 可能有业务行为 | 一般不包含行为 |

### Q: 命令实体放在哪里？

统一放在 `entity/` 包下，使用 `XxxCommandEntity` 后缀命名。

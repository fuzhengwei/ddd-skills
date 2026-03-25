# Value Object 值对象设计规范

## 概述

Value Object（值对象）是 DDD 领域层中用于表示**没有唯一标识**、**不可变**的概念。值对象强调的是"是什么"而不是"是谁"。

## 目录结构

```
model/
├── aggregate/              # 聚合根
├── entity/               # 实体对象
└── valobj/               # ⭐ 值对象
    ├── XxxVO.java         # 普通值对象
    ├── XxxEnumVO.java    # 枚举值对象
    └── enums/            # 枚举内部类（可选）
        └── XxxEnum.java
```

## 值对象特征

1. **无唯一标识**：不具有唯一 ID，通过属性值判断相等性
2. **不可变**：创建后不可修改，任何修改都返回新实例
3. **可替换**：两个属性相同的值对象可以互换
4. **内聚性**：可以包含相关的业务逻辑方法

## 值对象分类

### 1. 普通值对象（VO）

#### 编码示例

```java
package cn.bugstack.domain.trade.model.valobj;

import lombok.*;

/**
 * 拼团退单消息
 * @author xiaofuge bugstack.cn @小傅哥
 */
@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class TeamRefundSuccess {

    /** 退单类型 */
    private String type;
    
    /** 用户ID */
    private String userId;
    
    /** 拼单组队ID */
    private String teamId;
    
    /** 活动ID */
    private Long activityId;
    
    /** 预购订单ID */
    private String orderId;
    
    /** 外部交易单号 */
    private String outTradeNo;

}
```

### 2. 配置值对象

```java
package cn.bugstack.domain.trade.model.valobj;

import lombok.*;

/**
 * 回调配置值对象
 * @author Fuzhengwei bugstack.cn @小傅哥
 */
@Getter
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class NotifyConfigVO {

    /** 回调方式：MQ、HTTP */
    private NotifyTypeEnumVO notifyType;
    
    /** 回调消息 */
    private String notifyMQ;
    
    /** 回调地址 */
    private String notifyUrl;

}
```

### 3. 进度值对象

```java
package cn.bugstack.domain.trade.model.valobj;

import lombok.*;

/**
 * 拼团进度值对象
 */
@Data
public class GroupBuyProgressVO {

    /** 组队ID */
    private String teamId;
    
    /** 目标数量 */
    private Integer targetCount;
    
    /** 完成数量 */
    private Integer completeCount;
    
    /** 进度百分比 */
    private Double progressPercent;
    
    /** 是否完成 */
    public boolean isCompleted() {
        return completeCount >= targetCount;
    }
    
    /** 获取剩余数量 */
    public Integer getRemainingCount() {
        return Math.max(0, targetCount - completeCount);
    }
}
```

## 枚举值对象（Enum VO）

### 概述

枚举值对象用于表示**一组固定的业务状态或类型**，是值对象的一种特殊形式。

### 特征

- 使用 `enum` 关键字定义
- 包含状态码和描述
- 可以包含行为方法
- 可以使用抽象方法让每个枚举值实现自己的逻辑

### 简单枚举

```java
package cn.bugstack.domain.trade.model.valobj;

import lombok.*;

/**
 * 交易订单状态枚举
 * @author Fuzhengwei bugstack.cn @小傅哥
 */
@Getter
@AllArgsConstructor
public enum TradeOrderStatusEnumVO {

    CREATE(0, "初始创建"),
    COMPLETE(1, "消费完成"),
    CLOSE(2, "用户退单");

    private Integer code;
    private String info;

    /**
     * 根据状态码获取枚举
     */
    public static TradeOrderStatusEnumVO valueOf(Integer code) {
        switch (code) {
            case 0: return CREATE;
            case 1: return COMPLETE;
            case 2: return CLOSE;
        }
        return CREATE;
    }
}
```

### 复杂枚举（策略模式）

当枚举值需要包含行为时，使用抽象方法：

```java
package cn.bugstack.domain.trade.model.valobj;

import lombok.*;

/**
 * 退单类型枚举 - 策略枚举
 * @author xiaofuge bugstack.cn @小傅哥
 */
@Getter
@AllArgsConstructor
public enum RefundTypeEnumVO {

    /** 未支付，未成团 */
    UNPAID_UNLOCK("unpaid_unlock", "Unpaid2RefundStrategy", "未支付，未成团") {
        @Override
        public boolean matches(GroupBuyOrderEnumVO groupBuyOrderEnumVO, TradeOrderStatusEnumVO tradeOrderStatusEnumVO) {
            return GroupBuyOrderEnumVO.PROGRESS.equals(groupBuyOrderEnumVO) 
                && TradeOrderStatusEnumVO.CREATE.equals(tradeOrderStatusEnumVO);
        }
    },
    
    /** 已支付，未成团 */
    PAID_UNFORMED("paid_unformed", "Paid2RefundStrategy", "已支付，未成团") {
        @Override
        public boolean matches(GroupBuyOrderEnumVO groupBuyOrderEnumVO, TradeOrderStatusEnumVO tradeOrderStatusEnumVO) {
            return GroupBuyOrderEnumVO.PROGRESS.equals(groupBuyOrderEnumVO) 
                && TradeOrderStatusEnumVO.COMPLETE.equals(tradeOrderStatusEnumVO);
        }
    },
    
    /** 已支付，已成团 */
    PAID_FORMED("paid_formed", "PaidTeam2RefundStrategy", "已支付，已成团") {
        @Override
        public boolean matches(GroupBuyOrderEnumVO groupBuyOrderEnumVO, TradeOrderStatusEnumVO tradeOrderStatusEnumVO) {
            return (GroupBuyOrderEnumVO.COMPLETE.equals(groupBuyOrderEnumVO) 
                    || GroupBuyOrderEnumVO.COMPLETE_FAIL.equals(groupBuyOrderEnumVO))
                && TradeOrderStatusEnumVO.COMPLETE.equals(tradeOrderStatusEnumVO);
        }
    };

    private String code;
    private String strategy;
    private String info;

    /**
     * 抽象方法，由每个枚举值实现自己的匹配逻辑
     */
    public abstract boolean matches(GroupBuyOrderEnumVO groupBuyOrderEnumVO, TradeOrderStatusEnumVO tradeOrderStatusEnumVO);

    /**
     * 根据状态组合获取对应的退款策略枚举
     */
    public static RefundTypeEnumVO getRefundStrategy(GroupBuyOrderEnumVO groupBuyOrderEnumVO, 
                                                     TradeOrderStatusEnumVO tradeOrderStatusEnumVO) {
        return Arrays.stream(values())
                .filter(refundType -> refundType.matches(groupBuyOrderEnumVO, tradeOrderStatusEnumVO))
                .findFirst()
                .orElseThrow(() -> new RuntimeException("不支持的退款状态组合"));
    }
}
```

### 枚举值对象的使用

```java
// 1. 基本使用
TradeOrderStatusEnumVO status = TradeOrderStatusEnumVO.CREATE;
System.out.println(status.getInfo()); // 输出：初始创建

// 2. 策略枚举的匹配
RefundTypeEnumVO refundType = RefundTypeEnumVO.getRefundStrategy(
    GroupBuyOrderEnumVO.PROGRESS, 
    TradeOrderStatusEnumVO.COMPLETE
);
String strategy = refundType.getStrategy(); // 获取对应的策略bean名称

// 3. 使用 Spring 注入策略
@Service
public class RefundService {
    
    @Resource
    private Map<String, IRefundOrderStrategy> strategyMap;
    
    public void refund(TradeRefundCommandEntity command) {
        RefundTypeEnumVO refundType = RefundTypeEnumVO.getRefundStrategy(
            command.getGroupBuyStatus(), 
            command.getTradeStatus()
        );
        
        // 根据枚举获取策略实现
        IRefundOrderStrategy strategy = strategyMap.get(refundType.getStrategy());
        strategy.refundOrder(command);
    }
}
```

## 真实工程示例

参考 `group-buy-market` 项目的 valobj 目录：

```
domain/trade/model/valobj/
├── TeamRefundSuccess.java              # 普通值对象
├── NotifyConfigVO.java                 # 配置值对象
├── GroupBuyProgressVO.java            # 进度值对象
├── RefundTypeEnumVO.java             # 枚举值对象（策略模式）
├── NotifyTypeEnumVO.java             # 枚举值对象
└── TradeOrderStatusEnumVO.java        # 枚举值对象
```

## 命名规范

| 类型 | 命名规范 | 示例 | 说明 |
|------|---------|------|------|
| 普通值对象 | `XxxVO` | `TeamRefundSuccess` | 代表业务概念 |
| 枚举值对象 | `XxxEnumVO` | `TradeOrderStatusEnumVO` | 表示固定状态 |
| 内部枚举类 | `XxxEnum` | `StatusEnum` | 可以在 VO 内部定义 |

## 设计原则

### 1. 值对象应该不可变

```java
// ✅ 正确：不可变值对象
@Getter
public final class MoneyVO {
    private final BigDecimal amount;
    private final String currency;
    
    private MoneyVO(BigDecimal amount, String currency) {
        this.amount = amount;
        this.currency = currency;
    }
    
    /** 加法操作返回新实例 */
    public MoneyVO add(MoneyVO other) {
        return new MoneyVO(amount.add(other.amount), currency);
    }
}

// ❌ 错误：可变值对象
@Getter
public class MoneyVO {
    private BigDecimal amount;
    private String currency;
    
    public void add(MoneyVO other) {
        this.amount = this.amount.add(other.amount); // 直接修改
    }
}
```

### 2. 枚举值可以包含行为

```java
public enum OrderStatusEnumVO {
    
    PENDING("待支付") {
        @Override
        public boolean canPay() { return true; }
        @Override
        public boolean canCancel() { return true; }
    },
    
    PAID("已支付") {
        @Override
        public boolean canPay() { return false; }
        @Override
        public boolean canCancel() { return false; }
    };
    
    private String description;
    
    public abstract boolean canPay();
    public abstract boolean canCancel();
}

// 使用
OrderStatusEnumVO status = OrderStatusEnumVO.PENDING;
if (status.canCancel()) {
    // 可以取消
}
```

### 3. 使用内部类组织相关枚举

```java
@Getter
public class OrderAggregate {

    /** 聚合根属性 */
    private String orderId;
    private OrderStatusEnumVO status;
    
    // ========== 内部枚举类 ==========
    public enum OrderStatusEnumVO {
        PENDING, PAID, COMPLETED, CANCELLED
    }
    
    public enum PaymentMethodEnumVO {
        WECHAT, ALIPAY, CARD
    }
}
```

## 常见问题

### Q: 值对象和实体的区别？

| 维度 | 值对象 | 实体 |
|------|--------|------|
| 标识 | 无标识 | 有唯一标识 |
| 相等性 | 通过属性值判断 | 通过标识判断 |
| 可变性 | 不可变 | 可变 |
| 生命周期 | 无生命周期 | 有生命周期 |

### Q: 什么时候用枚举值对象？

当业务状态或类型是**固定**的、可枚举的，应该使用枚举：
- 订单状态：待支付、已支付、已完成、已取消
- 退款类型：未支付退款、已支付退款
- 通知方式：MQ、HTTP

### Q: 枚举值对象的方法放在哪里？

如果方法只涉及该枚举本身，放在枚举类中：
```java
public enum StatusEnum {
    ACTIVE, INACTIVE;
    
    public boolean isActive() {
        return this == ACTIVE;
    }
}
```

如果方法需要依赖其他领域对象，应该放在 Domain Service 中。

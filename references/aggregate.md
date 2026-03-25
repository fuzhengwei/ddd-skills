# Aggregate 聚合对象设计规范

## 概述

Aggregate（聚合对象）是 DDD 领域层中用于**封装业务一致性和事务边界**的核心概念。聚合定义了一组相关对象的边界，确保在边界内的对象遵循同一套业务规则。

## 目录结构

```
model/
├── aggregate/              # ⭐ 聚合对象
│   └── XxxAggregate.java
├── entity/               # 实体对象
└── valobj/               # 值对象
```

## 聚合的定义

### 什么是聚合？

> 聚合是将多个相关对象视为一个单一的单元。聚合根（Aggregate Root）是聚合对外的唯一入口，负责维护聚合内的一致性规则。

### 真实工程示例

参考 `group-buy-market` 项目的 `GroupBuyOrderAggregate`：

```java
package cn.bugstack.domain.trade.model.aggregate;

import cn.bugstack.domain.trade.model.entity.*;
import lombok.*;

/**
 * 拼团订单聚合对象
 * 聚合可以理解用各个四肢、身体、头等组装出来一个人
 * @author Fuzhengwei bugstack.cn @小傅哥
 */
@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
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

## 聚合的特征

### 1. 聚合根是唯一入口

聚合内的其他对象只能通过聚合根访问：

```java
// ✅ 正确：通过聚合根访问
GroupBuyOrderAggregate aggregate = repository.findById(orderId);
UserEntity user = aggregate.getUserEntity(); // 通过聚合根访问

// ❌ 错误：直接访问聚合内对象
UserEntity user = userRepository.findById(userId); // 应该通过聚合
```

### 2. 事务边界

聚合定义了一个事务边界内的操作：

```java
@Service
public class OrderService {

    @Resource
    private IOrderRepository repository;

    @Transactional
    public void createOrder(Long userId, Long productId) {
        // 整个操作在一个事务中
        GroupBuyOrderAggregate aggregate = GroupBuyOrderAggregate.builder()
                .userEntity(userRepository.findById(userId))
                .payActivityEntity(activityRepository.findById(productId))
                .build();
        
        repository.save(aggregate);
    }
}
```

### 3. 聚合内对象的一致性

聚合根负责维护聚合内的一致性规则：

```java
@Data
public class OrderAggregate {

    private OrderEntity order;
    private List<OrderItemEntity> items;
    private AddressVO address;

    /**
     * 计算订单总金额
     */
    public BigDecimal calculateTotalAmount() {
        return items.stream()
                .map(OrderItemEntity::getPrice)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    /**
     * 验证订单有效性
     */
    public void validate() {
        if (items.isEmpty()) {
            throw new IllegalStateException("订单不能为空");
        }
        // ... 更多验证
    }
}
```

## 聚合与实体的关系

| 维度 | 聚合 Aggregate | 实体 Entity |
|------|----------------|-------------|
| 位置 | `aggregate/` 包 | `entity/` 包 |
| 职责 | 封装一组相关对象 | 代表单个业务主体 |
| 标识 | 聚合根有标识 | 有唯一标识 |
| 访问 | 外部只能访问聚合根 | 外部不能直接访问 |
| 事务 | 定义事务边界 | 参与聚合的事务 |

## 聚合的使用场景

### 1. 需要保持一致性的对象组

```java
// 订单及其订单项需要保持一致性
@Data
public class OrderAggregate {
    private OrderEntity order;           // 订单主体
    private List<OrderItemEntity> items; // 订单项列表
    private AddressVO address;           // 收货地址
}

// 只能通过聚合根操作
@Service
public class OrderService {
    public void addItem(Long orderId, OrderItemEntity item) {
        OrderAggregate aggregate = repository.findById(orderId);
        aggregate.addItem(item); // 通过聚合根添加
        repository.save(aggregate);
    }
}
```

### 2. 需要事务边界的操作

```java
@Transactional
public void placeOrder(OrderAggregate aggregate) {
    // 1. 扣减库存（外部系统）
    inventoryService.deduct(aggregate.getItems());
    
    // 2. 创建订单
    repository.save(aggregate);
    
    // 3. 发送通知（外部系统）
    notificationService.send(aggregate);
    
    // 以上操作在一个事务中
}
```

## 真实工程示例

参考 `group-buy-market` 项目：

### GroupBuyOrderAggregate - 订单聚合

```java
/**
 * 拼团订单聚合
 * 包含：用户、活动、优惠、参与次数
 */
@Data
public class GroupBuyOrderAggregate {
    private UserEntity userEntity;
    private PayActivityEntity payActivityEntity;
    private PayDiscountEntity payDiscountEntity;
    private Integer userTakeOrderCount;
}
```

### GroupBuyRefundAggregate - 退款聚合

```java
/**
 * 拼团退款聚合
 */
@Data
public class GroupBuyRefundAggregate {
    
    private TradeRefundOrderEntity refundOrder;
    private GroupBuyTeamEntity team;
    private MarketPayOrderEntity payOrder;
    private Integer deductStock;
    private Integer deductComplete;
    
    /**
     * 构建退款聚合
     */
    public static GroupBuyRefundAggregate buildPaid2RefundAggregate(
            TradeRefundOrderEntity entity, Integer deductStock, Integer deductComplete) {
        return GroupBuyRefundAggregate.builder()
                .refundOrder(entity)
                .deductStock(deductStock)
                .deductComplete(deductComplete)
                .build();
    }
}
```

### GroupBuyTeamSettlementAggregate - 结算聚合

```java
/**
 * 拼团结算聚合
 */
@Data
public class GroupBuyTeamSettlementAggregate {
    private GroupBuyTeamEntity team;
    private List<MarketPayOrderEntity> orders;
    private NotifyConfigVO notifyConfig;
}
```

## 命名规范

| 类型 | 命名规范 | 示例 |
|------|---------|------|
| 聚合 | `XxxAggregate` | `GroupBuyOrderAggregate` |

## 设计原则

### 1. 聚合应该尽量小

```java
// ✅ 正确：聚合只包含必要的对象
@Data
public class OrderAggregate {
    private OrderEntity order;           // 必需
    private List<OrderItemEntity> items;  // 必需
    // 不要把无关的对象放进来
}

// ❌ 错误：聚合过大
@Data
public class OrderAggregate {
    private OrderEntity order;
    private List<OrderItemEntity> items;
    private AddressVO address;
    private UserEntity user;           // 应该通过 userId 查询
    private ProductEntity product;     // 应该通过 productId 查询
    private WarehouseEntity warehouse; // 无关对象
}
```

### 2. 聚合根应该有业务方法

```java
@Data
public class OrderAggregate {

    private OrderEntity order;
    private List<OrderItemEntity> items;

    /**
     * 计算总金额
     */
    public BigDecimal totalAmount() {
        return items.stream()
                .map(item -> item.getPrice().multiply(BigDecimal.valueOf(item.getQuantity())))
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    /**
     * 添加订单项
     */
    public void addItem(OrderItemEntity item) {
        if (item == null) {
            throw new IllegalArgumentException("订单项不能为空");
        }
        this.items.add(item);
    }

    /**
     * 验证订单
     */
    public void validate() {
        if (items.isEmpty()) {
            throw new IllegalStateException("订单不能为空");
        }
        if (order.getAmount().compareTo(BigDecimal.ZERO) <= 0) {
            throw new IllegalStateException("订单金额必须大于0");
        }
    }
}
```

### 3. 聚合内对象不应被外部直接引用

```java
// ✅ 正确：通过聚合根访问
OrderAggregate aggregate = repository.findById(id);
aggregate.getItems().add(item);

// ❌ 错误：直接修改聚合内对象（绕过了聚合根）
OrderAggregate aggregate = repository.findById(id);
aggregate.getItems().get(0).setQuantity(5); // 绕过了聚合根
```

## 常见问题

### Q: 什么时候需要聚合？

当业务操作涉及**多个相关对象**需要保持一致性时，应该使用聚合。

### Q: 聚合和实体有什么区别？

- **实体**：代表单个业务主体，有唯一标识
- **聚合**：封装一组相关对象，定义事务边界

简单来说：如果一个业务操作只需要操作单个对象，可能不需要聚合；如果需要操作多个相关对象，应该使用聚合。

### Q: 聚合应该有多大？

聚合应该**尽量小**，只包含完成业务操作所必需的对象。过大的聚合会导致性能问题和事务冲突。

### Q: 聚合根必须是实体吗？

是的，聚合根必须是实体，因为它需要持有唯一标识来被外部引用。

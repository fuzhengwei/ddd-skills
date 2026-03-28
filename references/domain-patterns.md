# Domain 层核心设计模式

## 概述

Domain 层（领域层）是 DDD 六边形架构的核心，负责封装所有业务逻辑。本文档介绍领域层的核心设计模式，帮助你在实际项目中合理选择和使用。

**重要原则**：设计模式是工具，不是目的。简单业务用简单方式实现，只有业务复杂度提升时才引入设计模式。

## 目录结构

```
domain/
├── {domain}/
│   ├── adapter/                    # 适配器接口（端口）
│   │   ├── port/                   # 外部系统调用接口
│   │   │   └── I{Xxx}Port.java
│   │   └── repository/             # 数据仓储接口
│   │       └── I{Xxx}Repository.java
│   ├── model/                      # 领域模型
│   │   ├── aggregate/             # 聚合根
│   │   ├── entity/                # 实体（含命令实体）
│   │   └── valobj/                # 值对象（含枚举值对象）
│   └── service/                   # 领域服务
│       ├── I{Xxx}Service.java     # 服务接口
│       └── {能力}/
│           ├── {Xxx}Service.java  # 服务实现
│           ├── factory/            # 工厂（可选）
│           ├── filter/            # 责任链过滤器（可选）
│           ├── strategy/          # 策略（可选）
│           └── node/              # 树形节点（可选）
```

---

## 模式一：简单领域服务（无设计模式）

**适用场景**：
- 业务逻辑相对简单
- 步骤线性，无分支判断
- 不需要组合多个子步骤

**不适用场景**：
- 有多种处理策略需要选择
- 有多个独立的校验步骤
- 有复杂的流程分支

### 示例：简单的人群标签服务

```java
/**
 * 人群标签服务接口
 */
public interface ITagService {
    void execTagBatchJob(String tagId, String batchId);
}

/**
 * 人群标签服务实现
 * 
 * 注意：这是一个简单的服务，没有使用任何设计模式。
 * 因为业务逻辑简单：查询 → 处理 → 写入 → 更新统计。
 * 
 * @author xiaofuge
 */
@Slf4j
@Service
public class TagService implements ITagService {

    @Resource
    private ITagRepository repository;

    @Override
    public void execTagBatchJob(String tagId, String batchId) {
        log.info("人群标签批次任务 tagId:{} batchId:{}", tagId, batchId);

        // 1. 查询批次任务
        CrowdTagsJobEntity crowdTagsJobEntity = repository.queryCrowdTagsJobEntity(tagId, batchId);

        // 2. 采集用户数据
        // ... 采集逻辑

        // 3. 数据写入记录
        List<String> userIdList = fetchUserList();
        for (String userId : userIdList) {
            repository.addCrowdTagsUserId(tagId, userId);
        }

        // 4. 更新统计量
        repository.updateCrowdTagsStatistics(tagId, userIdList.size());
    }
}
```

### 示例：简单的回调任务服务

```java
/**
 * 回调任务服务
 * 
 * 简单业务：查询任务列表 → 遍历处理 → 更新状态 → 返回结果
 */
@Slf4j
@Service
public class TradeTaskService implements ITradeTaskService {

    @Resource
    private ITradeRepository repository;
    @Resource
    private ITradePort port;

    @Override
    public Map<String, Integer> execNotifyJob() throws Exception {
        log.info("执行回调通知任务");

        // 1. 查询未执行任务
        List<NotifyTaskEntity> notifyTaskList = repository.queryUnExecutedNotifyTaskList();

        // 2. 遍历处理
        int successCount = 0, errorCount = 0;
        for (NotifyTaskEntity task : notifyTaskList) {
            String response = port.groupBuyNotify(task);
            if (NotifyTaskHTTPEnumVO.SUCCESS.getCode().equals(response)) {
                repository.updateNotifyTaskStatusSuccess(task);
                successCount++;
            } else {
                repository.updateNotifyTaskStatusError(task);
                errorCount++;
            }
        }

        // 3. 返回结果
        Map<String, Integer> result = new HashMap<>();
        result.put("successCount", successCount);
        result.put("errorCount", errorCount);
        return result;
    }
}
```

---

## 模式二：策略模式（Strategy Pattern）

**适用场景**：
- 同一操作有**多种处理策略**
- 根据条件动态选择策略
- 策略之间有部分共性逻辑

**典型案例**：退单场景
- 未支付退单：只需恢复锁单库存
- 已支付未成团退单：更新订单状态 + 恢复锁单库存 + 发送MQ通知
- 已支付已成团退单：更新订单状态 + 恢复完成库存 + 发送MQ通知

### 策略接口定义

```java
/**
 * 退单策略接口
 * 
 * 定义所有退单策略的通用行为
 */
public interface IRefundOrderStrategy {

    /**
     * 执行退单操作
     */
    void refundOrder(TradeRefundOrderEntity entity) throws Exception;

    /**
     * 恢复库存（用于MQ消费后的补偿操作）
     */
    void reverseStock(TeamRefundSuccess success) throws Exception;
}
```

### 抽象基类（模板方法）

```java
/**
 * 退单策略抽象基类
 * 
 * 封装通用逻辑，子类只需实现差异化部分
 * 
 * @author xiaofuge
 */
@Slf4j
public abstract class AbstractRefundOrderStrategy implements IRefundOrderStrategy {

    @Resource
    protected ITradeRepository repository;

    @Resource
    protected ThreadPoolExecutor threadPoolExecutor;

    /**
     * 通用库存恢复逻辑 - 所有策略都相同
     */
    protected void doReverseStock(TeamRefundSuccess success, String refundType) throws Exception {
        log.info("退单-恢复锁单量 {} userId:{}", refundType, success.getUserId());
        
        // 1. 生成恢复key
        String recoveryKey = TradeLockRuleFilterFactory.generateRecoveryTeamStockKey(
                success.getActivityId(), success.getTeamId());
        
        // 2. 恢复库存
        repository.refund2AddRecovery(recoveryKey, success.getOrderId());
    }

    /**
     * 通用MQ消息发送 - 所有策略都相同
     */
    protected void sendNotifyMessage(NotifyTaskEntity task, String refundType) {
        if (task == null) return;
        
        threadPoolExecutor.execute(() -> {
            try {
                log.info("退单回调通知 {} result:{}", refundType, task);
                // 发送MQ逻辑
            } catch (Exception e) {
                log.error("退单回调通知失败", e);
            }
        });
    }
}
```

### 具体策略实现

```java
/**
 * 策略A：未支付退单
 * 
 * 特点：只需恢复锁单库存，无需发送MQ通知
 */
@Slf4j
@Service("unpaid2RefundStrategy")
public class Unpaid2RefundStrategy extends AbstractRefundOrderStrategy {

    @Override
    public void refundOrder(TradeRefundOrderEntity entity) throws Exception {
        log.info("退单-未支付 userId:{} teamId:{}", entity.getUserId(), entity.getTeamId());
        
        // 只需恢复锁单库存
        GroupBuyRefundAggregate aggregate = GroupBuyRefundAggregate.buildUnpaidRefundAggregate(entity);
        repository.unpaid2Refund(aggregate);
    }

    @Override
    public void reverseStock(TeamRefundSuccess success) throws Exception {
        doReverseStock(success, "未支付");
    }
}

/**
 * 策略B：已支付未成团退单
 * 
 * 特点：更新订单状态 + 恢复锁单库存 + 发送MQ通知
 */
@Slf4j
@Service("paid2RefundStrategy")
public class Paid2RefundStrategy extends AbstractRefundOrderStrategy {

    @Override
    public void refundOrder(TradeRefundOrderEntity entity) throws Exception {
        log.info("退单-已支付，未成团 userId:{} teamId:{}", entity.getUserId(), entity.getTeamId());

        // 1. 执行退单
        NotifyTaskEntity task = repository.paid2Refund(
                GroupBuyRefundAggregate.buildPaid2RefundAggregate(entity, -1, -1));

        // 2. 发送MQ通知
        sendNotifyMessage(task, "已支付，未成团");
    }

    @Override
    public void reverseStock(TeamRefundSuccess success) throws Exception {
        doReverseStock(success, "已支付，未成团");
    }
}

/**
 * 策略C：已支付已成团退单
 * 
 * 特点：恢复完成库存（不同于锁单库存）
 */
@Slf4j
@Service("paidTeam2RefundStrategy")
public class PaidTeam2RefundStrategy extends AbstractRefundOrderStrategy {

    @Override
    public void refundOrder(TradeRefundOrderEntity entity) throws Exception {
        log.info("退单-已支付，已成团 userId:{} teamId:{}", entity.getUserId(), entity.getTeamId());
        
        // 退单逻辑...
    }

    @Override
    public void reverseStock(TeamRefundSuccess success) throws Exception {
        doReverseStock(success, "已支付，已成团");
    }
}
```

### 策略路由（工厂）

```java
/**
 * 退单策略工厂
 * 
 * 根据退单类型选择对应策略
 */
@Service
public class RefundStrategyFactory {

    @Resource
    private Map<String, IRefundOrderStrategy> strategyMap;

    /**
     * 根据退单类型获取策略
     */
    public IRefundOrderStrategy getStrategy(RefundTypeEnumVO type) {
        return strategyMap.get(type.getStrategy());
    }
}

/**
 * 退单类型枚举（包含策略选择逻辑）
 */
@Getter
@AllArgsConstructor
public enum RefundTypeEnumVO {
    
    UNPAID_UNLOCK("unpaid_unlock", "未支付退单") {
        @Override
        public boolean matches(GroupBuyOrderEnumVO orderStatus, TradeOrderStatusEnumVO tradeStatus) {
            return GroupBuyOrderEnumVO.PROGRESS.equals(orderStatus) 
                && TradeOrderStatusEnumVO.CREATE.equals(tradeStatus);
        }
    },
    
    PAID_UNFORMED("paid_unformed", "已支付未成团") {
        @Override
        public boolean matches(GroupBuyOrderEnumVO orderStatus, TradeOrderStatusEnumVO tradeStatus) {
            return GroupBuyOrderEnumVO.PROGRESS.equals(orderStatus) 
                && TradeOrderStatusEnumVO.COMPLETE.equals(tradeStatus);
        }
    };

    private String code;
    private String info;

    public abstract boolean matches(GroupBuyOrderEnumVO orderStatus, TradeOrderStatusEnumVO tradeStatus);

    public static RefundTypeEnumVO getByStatus(GroupBuyOrderEnumVO orderStatus, 
                                                TradeOrderStatusEnumVO tradeStatus) {
        return Arrays.stream(values())
                .filter(v -> v.matches(orderStatus, tradeStatus))
                .findFirst()
                .orElseThrow(() -> new RuntimeException("不支持的退单状态组合"));
    }
}
```

### 服务调用策略

```java
@Service
public class TradeRefundOrderService implements ITradeRefundOrderService {

    @Resource
    private RefundStrategyFactory strategyFactory;

    @Override
    public void refundOrder(TradeRefundCommandEntity command) throws Exception {
        // 1. 根据状态判断退单类型
        RefundTypeEnumVO refundType = RefundTypeEnumVO.getByStatus(
                command.getOrderStatus(), command.getTradeStatus());
        
        // 2. 获取策略
        IRefundOrderStrategy strategy = strategyFactory.getStrategy(refundType);
        
        // 3. 执行退单
        strategy.refundOrder(command.toEntity());
    }
}
```

### ai-mcp-gateway 真实案例：协议解析策略

除了退单场景，在 `ai-mcp-gateway` 中也使用了策略模式来处理不同类型的协议参数解析：

```java
// 策略接口
public interface IProtocolAnalysisStrategy {
    void analysis(String protocol, Map<String, Object> params);
}

// 策略实现 A：Query 参数解析
@Service("parametersAnalysisStrategy")
public class ParametersAnalysisStrategy implements IProtocolAnalysisStrategy {
    @Override
    public void analysis(String protocol, Map<String, Object> params) {
        // ...
    }
}

// 策略实现 B：Body 参数解析
@Service("requestBodyAnalysisStrategy")
public class RequestBodyAnalysisStrategy implements IProtocolAnalysisStrategy {
    @Override
    public void analysis(String protocol, Map<String, Object> params) {
        // ...
    }
}
```

---

## 模式三：责任链模式（Chain Pattern）

**适用场景**：
- 有**多个独立的校验/过滤步骤**
- 每个步骤可独立运行
- 步骤之间有顺序要求
- 任何一个步骤失败则整体失败

**典型案例**：订单锁定前的多步校验
1. 校验活动是否可用（状态、时间）
2. 校验用户参与次数限制
3. 校验库存是否充足

### 命令实体和结果实体

```java
/**
 * 锁单规则命令实体
 * 包含校验所需的全部入参
 */
@Data
@Builder
public class TradeLockRuleCommandEntity {
    private String userId;
    private Long activityId;
    private String teamId;
}

/**
 * 锁单规则过滤结果实体
 * 包含校验通过后的上下文数据
 */
@Data
@Builder
public class TradeLockRuleFilterBackEntity {
    /** 用户已参与次数 */
    private Integer userTakeOrderCount;
    /** 恢复库存的key */
    private String recoveryTeamStockKey;
}

/**
 * 动态上下文
 * 存放中间状态，供后续过滤器使用
 */
@Data
@Builder
public class DynamicContext {
    private GroupBuyActivityEntity activity;
    private Integer userTakeOrderCount;
}
```

### 过滤器接口

```java
/**
 * 规则过滤器接口
 * 
 * 每个过滤器负责一个独立的校验步骤
 */
public interface ITradeLockRuleFilter {

    /**
     * 执行过滤校验
     * @param command  命令实体
     * @param context  动态上下文（存放中间状态）
     * @return 过滤结果
     */
    TradeLockRuleFilterBackEntity filter(TradeLockRuleCommandEntity command, 
                                         DynamicContext context) throws Exception;
}
```

### 具体过滤器实现

```java
/**
 * 过滤器1：活动可用性校验
 * 
 * 校验活动状态和时间是否有效
 */
@Slf4j
@Service
public class ActivityUsabilityRuleFilter implements ITradeLockRuleFilter {

    @Resource
    private ITradeRepository repository;

    @Override
    public TradeLockRuleFilterBackEntity filter(TradeLockRuleCommandEntity command,
                                                DynamicContext context) throws Exception {
        log.info("规则过滤-活动可用性校验 activityId:{}", command.getActivityId());

        // 1. 查询活动信息
        GroupBuyActivityEntity activity = repository.queryActivityById(command.getActivityId());

        // 2. 校验活动状态
        if (!ActivityStatusEnumVO.EFFECTIVE.equals(activity.getStatus())) {
            throw new AppException("活动状态无效");
        }

        // 3. 校验活动时间
        Date now = new Date();
        if (now.before(activity.getStartTime()) || now.after(activity.getEndTime())) {
            throw new AppException("活动不在可参与时间内");
        }

        // 4. 保存到上下文，供后续过滤器使用
        context.setActivity(activity);

        // 5. 返回结果，继续下一个过滤器
        return TradeLockRuleFilterBackEntity.builder().build();
    }
}

/**
 * 过滤器2：用户参与次数校验
 * 
 * 校验用户是否超过参与限制
 */
@Slf4j
@Service
public class UserTakeLimitRuleFilter implements ITradeLockRuleFilter {

    @Resource
    private ITradeRepository repository;

    @Override
    public TradeLockRuleFilterBackEntity filter(TradeLockRuleCommandEntity command,
                                                DynamicContext context) throws Exception {
        log.info("规则过滤-用户参与次数校验 userId:{}", command.getUserId());

        // 1. 从上下文获取活动信息
        GroupBuyActivityEntity activity = context.getActivity();

        // 2. 查询用户已参与次数
        Integer count = repository.queryUserOrderCount(
                command.getActivityId(), command.getUserId());

        // 3. 校验是否超限
        if (count >= activity.getTakeLimitCount()) {
            throw new AppException("用户参与次数已达上限");
        }

        // 4. 保存到上下文
        context.setUserTakeOrderCount(count);

        return TradeLockRuleFilterBackEntity.builder()
                .userTakeOrderCount(count)
                .build();
    }
}

/**
 * 过滤器3：库存占用校验
 * 
 * 校验并预占库存
 */
@Slf4j
@Service
public class TeamStockOccupyRuleFilter implements ITradeLockRuleFilter {

    @Resource
    private ITradeRepository repository;

    @Override
    public TradeLockRuleFilterBackEntity filter(TradeLockRuleCommandEntity command,
                                                DynamicContext context) throws Exception {
        log.info("规则过滤-库存占用校验 teamId:{}", command.getTeamId());

        // 1. 生成库存key
        String stockKey = generateTeamStockKey(command.getActivityId(), command.getTeamId());
        String recoveryKey = generateRecoveryKey(command.getActivityId(), command.getTeamId());

        // 2. 尝试预占库存
        boolean success = repository.occupyTeamStock(stockKey, 1);
        if (!success) {
            throw new AppException("库存不足");
        }

        // 3. 保存恢复key（失败时回退用）
        return TradeLockRuleFilterBackEntity.builder()
                .userTakeOrderCount(context.getUserTakeOrderCount())
                .recoveryTeamStockKey(recoveryKey)
                .build();
    }
}
```

### 工厂组装责任链

```java
/**
 * 锁单规则过滤器工厂
 * 
 * 负责组装和执行责任链
 */
@Slf4j
@Service
public class TradeLockRuleFilterFactory {

    @Bean("tradeRuleFilter")
    public BusinessLinkedList<TradeLockRuleCommandEntity, DynamicContext, TradeLockRuleFilterBackEntity> 
            buildFilterChain(
                    ActivityUsabilityRuleFilter f1,
                    UserTakeLimitRuleFilter f2,
                    TeamStockOccupyRuleFilter f3) {
        
        // 1. 创建责任链
        LinkArmory<TradeLockRuleCommandEntity, DynamicContext, TradeLockRuleFilterBackEntity> armory = 
            new LinkArmory<>("锁单规则过滤链", f1, f2, f3);
        
        return armory.getLogicLink();
    }
}
```

### 服务使用责任链

```java
@Service
public class TradeLockOrderService implements ITradeLockOrderService {

    @Resource
    private ITradeRepository repository;

    @Resource
    private BusinessLinkedList<TradeLockRuleCommandEntity, DynamicContext, TradeLockRuleFilterBackEntity> 
            tradeRuleFilter;

    @Override
    public MarketPayOrderEntity lockOrder(UserEntity user, PayActivityEntity activity, 
                                          PayDiscountEntity discount) throws Exception {
        log.info("锁定营销订单 userId:{} activityId:{}", user.getUserId(), activity.getActivityId());

        // 1. 执行责任链校验
        TradeLockRuleFilterBackEntity back = tradeRuleFilter.apply(
                TradeLockRuleCommandEntity.builder()
                        .activityId(activity.getActivityId())
                        .userId(user.getUserId())
                        .teamId(activity.getTeamId())
                        .build(),
                new DynamicContext());

        // 2. 构建聚合对象
        GroupBuyOrderAggregate aggregate = GroupBuyOrderAggregate.builder()
                .userEntity(user)
                .payActivityEntity(activity)
                .payDiscountEntity(discount)
                .userTakeOrderCount(back.getUserTakeOrderCount())
                .build();

        try {
            // 3. 执行锁定
            return repository.lockOrder(aggregate);
        } catch (Exception e) {
            // 4. 失败时回退库存
            repository.recoveryTeamStock(back.getRecoveryTeamStockKey());
            throw e;
        }
    }
}
```

---

## 模式四：决策树模式（Tree Pattern）

**适用场景**：
- 业务流程有**多个分支判断**
- 分支之间有明确的流转关系
- 需要根据条件选择下一个处理节点

**典型案例**：营销试算流程
1. 根节点 → 参数校验
2. 开关节点 → 判断功能开关
3. 营销节点 → 执行优惠计算
4. 标签节点 → 判断人群标签
5. 结束节点 → 返回结果

### 节点接口

```java
/**
 * 策略处理器接口
 */
public interface IStrategyHandler<Req, Ctx, Res> {

    /**
     * 处理业务
     */
    Res handle(Req request, Ctx context) throws Exception;

    /**
     * 选择下一个处理器
     */
    IStrategyHandler<Req, Ctx, Res> getNext(Req request, Ctx context) throws Exception;
}
```

### 抽象基类

```java
/**
 * 策略路由抽象基类
 * 提供通用的路由能力
 */
public abstract class AbstractStrategyRouter<Req, Ctx, Res> {

    @Resource
    protected IActivityRepository repository;

    /**
     * 执行业务并路由到下一个节点
     */
    protected Res router(Req request, Ctx context) throws Exception {
        // 1. 执行当前节点业务
        Res result = doApply(request, context);
        
        // 2. 选择下一个节点
        IStrategyHandler<Req, Ctx, Res> nextHandler = getNext(request, context);
        
        // 3. 如果有下一个节点，继续执行
        if (nextHandler != null) {
            return nextHandler.handle(request, context);
        }
        
        return result;
    }

    /**
     * 子类实现业务逻辑
     */
    protected abstract Res doApply(Req request, Ctx context) throws Exception;

    /**
     * 子类实现路由选择逻辑
     */
    protected abstract IStrategyHandler<Req, Ctx, Res> getNext(Req request, Ctx context) throws Exception;
}
```

### 具体节点实现

```java
/**
 * 根节点：参数校验
 */
@Slf4j
@Service
public class RootNode extends AbstractStrategyRouter<MarketProductEntity, DynamicContext, TrialBalanceEntity> {

    @Resource
    private SwitchNode switchNode;

    @Override
    protected TrialBalanceEntity doApply(MarketProductEntity request, DynamicContext context) {
        log.info("营销试算-根节点 userId:{}", request.getUserId());
        
        // 参数校验
        if (StringUtils.isBlank(request.getUserId()) || 
            StringUtils.isBlank(request.getGoodsId())) {
            throw new AppException("参数错误");
        }
        
        return null;
    }

    @Override
    protected IStrategyHandler<MarketProductEntity, DynamicContext, TrialBalanceEntity> 
            getNext(MarketProductEntity request, DynamicContext context) {
        return switchNode;
    }
}

/**
 * 开关节点：判断功能开关
 */
@Slf4j
@Service
public class SwitchNode extends AbstractStrategyRouter<MarketProductEntity, DynamicContext, TrialBalanceEntity> {

    @Resource
    private MarketNode marketNode;
    @Resource
    private EndNode endNode;

    @Override
    protected TrialBalanceEntity doApply(MarketProductEntity request, DynamicContext context) {
        return null;
    }

    @Override
    protected IStrategyHandler<MarketProductEntity, DynamicContext, TrialBalanceEntity> 
            getNext(MarketProductEntity request, DynamicContext context) {
        // 根据开关状态选择下一节点
        return Boolean.TRUE.equals(context.getEnable()) ? marketNode : endNode;
    }
}

/**
 * 营销节点：执行优惠计算
 */
@Slf4j
@Service
public class MarketNode extends AbstractStrategyRouter<MarketProductEntity, DynamicContext, TrialBalanceEntity> {

    @Resource
    private Map<String, IDiscountCalculateService> discountServiceMap;
    @Resource
    private TagNode tagNode;
    @Resource
    private ErrorNode errorNode;

    @Override
    protected TrialBalanceEntity doApply(MarketProductEntity request, DynamicContext context) {
        log.info("营销试算-营销节点");

        // 执行优惠计算
        IDiscountCalculateService service = discountServiceMap.get(context.getDiscountType());
        BigDecimal payPrice = service.calculate(request.getUserId(), context.getOriginalPrice());
        
        context.setPayPrice(payPrice);
        return null;
    }

    @Override
    protected IStrategyHandler<MarketProductEntity, DynamicContext, TrialBalanceEntity> 
            getNext(MarketProductEntity request, DynamicContext context) {
        // 有优惠结果走标签节点，失败走错误节点
        return context.getPayPrice() != null ? tagNode : errorNode;
    }
}

/**
 * 结束节点：返回结果
 */
@Slf4j
@Service
public class EndNode extends AbstractStrategyRouter<MarketProductEntity, DynamicContext, TrialBalanceEntity> {

    @Override
    protected TrialBalanceEntity doApply(MarketProductEntity request, DynamicContext context) {
        return TrialBalanceEntity.builder()
                .payPrice(context.getPayPrice())
                .deductionPrice(context.getDeductionPrice())
                .success(true)
                .build();
    }

    @Override
    protected IStrategyHandler<MarketProductEntity, DynamicContext, TrialBalanceEntity> 
            getNext(MarketProductEntity request, DynamicContext context) {
        return null; // 结束
    }
}
```

### 服务入口

```java
@Service
public class MarketTrialService implements IMarketTrialService {

    @Resource
    private RootNode rootNode;

    @Override
    public TrialBalanceEntity trial(MarketProductEntity request) throws Exception {
        return rootNode.handle(request, new DynamicContext());
    }
}
```

---

## 设计模式的适度使用原则

### 决策树：根据业务复杂度选择

```
业务复杂度
    │
    │         ┌─────────────────┐
    │         │   简单线性逻辑    │  → 直接实现，无需设计模式
    │         └────────┬────────┘
    │                  │
    │         ┌────────▼────────┐
    │         │   多种策略选择    │  → 策略模式
    │         └────────┬────────┘
    │                  │
    │         ┌────────▼────────┐
    │         │   多步校验过滤    │  → 责任链模式
    │         └────────┬────────┘
    │                  │
    │         ┌────────▼────────┐
    │         │   复杂流程分支    │  → 决策树模式
    │         └─────────────────┘
```

### 何时不需要设计模式

```java
// ✅ 场景1：简单查询
@Service
public class UserQueryService {
    public UserEntity getUserById(Long id) {
        return repository.findById(id);
    }
}

// ✅ 场景2：简单转换
@Service
public class UserConvertService {
    public UserVO toVO(UserEntity entity) {
        return UserVO.builder()
                .id(entity.getId())
                .name(entity.getName())
                .build();
    }
}

// ✅ 场景3：简单状态更新
@Service
public class OrderStatusService {
    public void updateStatus(Long orderId, Integer status) {
        repository.updateStatus(orderId, status);
    }
}
```

### 何时需要设计模式

```java
// ✅ 场景1：多策略选择
// 退单：根据状态组合选择不同处理策略
RefundTypeEnumVO type = RefundTypeEnumVO.getByStatus(orderStatus, tradeStatus);
IRefundOrderStrategy strategy = strategyFactory.getStrategy(type);
strategy.refundOrder(entity);

// ✅ 场景2：多步校验
// 下单：活动状态 → 用户限制 → 库存 → 支付
tradeRuleFilter.apply(command, context);

// ✅ 场景3：复杂分支
// 营销试算：开关 → 活动 → 标签 → 结果
rootNode.handle(request, context);
```

### 警告信号

| 信号 | 说明 | 处理 |
|------|------|------|
| 大量 if-else | 策略模式征兆 | 重构为策略+工厂 |
| 方法过长 | 违反单一职责 | 拆分为多个过滤器 |
| switch-case 满天飞 | 决策树征兆 | 重构为树形节点 |
| 重复代码多 | 缺少抽象 | 引入模板方法基类 |

---

## Repository 和 Port 接口设计

### Repository 接口（数据仓储）

```java
/**
 * 仓储接口 - 定义在 domain 层
 * 
 * 职责：定义对数据库的操作方法
 * 实现：由 Infrastructure 层完成
 */
public interface ITradeRepository {

    // ========== 查询 ==========
    MarketPayOrderEntity queryOrderByOutTradeNo(String userId, String outTradeNo);
    GroupBuyProgressVO queryGroupBuyProgress(String teamId);
    GroupBuyActivityEntity queryActivityById(Long activityId);
    Integer queryUserOrderCount(Long activityId, String userId);

    // ========== 操作 ==========
    MarketPayOrderEntity lockOrder(GroupBuyOrderAggregate aggregate);
    boolean occupyTeamStock(String stockKey, Integer count);
    void recoveryTeamStock(String recoveryKey);

    // ========== 通知 ==========
    NotifyTaskEntity createNotifyTask(NotifyTaskEntity entity);
    int updateNotifyTaskStatus(NotifyTaskEntity entity);
}
```

### Port 接口（外部系统调用）

```java
/**
 * 端口接口 - 定义在 domain 层
 * 
 * 职责：定义对外部系统的调用方法
 * 实现：由 Infrastructure 层完成
 */
public interface ITradePort {

    /**
     * 拼团回调通知
     */
    String groupBuyNotify(NotifyTaskEntity notifyTask) throws Exception;
}

/**
 * 另一个 Port 示例
 */
public interface IPaymentPort {

    /**
     * 发起支付
     */
    PaymentResult pay(PaymentRequest request) throws Exception;

    /**
     * 查询支付状态
     */
    PaymentStatus queryStatus(String paymentId) throws Exception;
}
```

---

## 真实工程目录结构参考

```
group-buy-market-domain/
└── cn/bugstack/domain/
    ├── trade/                          # 交易域
    │   ├── adapter/
    │   │   ├── port/ITradePort.java
    │   │   └── repository/ITradeRepository.java
    │   ├── model/
    │   │   ├── aggregate/
    │   │   │   ├── GroupBuyOrderAggregate.java
    │   │   │   └── GroupBuyRefundAggregate.java
    │   │   ├── entity/
    │   │   │   ├── MarketPayOrderEntity.java
    │   │   │   ├── TradeLockRuleCommandEntity.java
    │   │   │   └── TradeLockRuleFilterBackEntity.java
    │   │   └── valobj/
    │   │       ├── TradeOrderStatusEnumVO.java
    │   │       └── RefundTypeEnumVO.java
    │   └── service/
    │       ├── ITradeLockOrderService.java
    │       ├── ITradeRefundOrderService.java
    │       ├── lock/
    │       │   ├── TradeLockOrderService.java
    │       │   ├── factory/TradeLockRuleFilterFactory.java
    │       │   └── filter/
    │       │       ├── ActivityUsabilityRuleFilter.java
    │       │       └── UserTakeLimitRuleFilter.java
    │       └── refund/
    │           ├── TradeRefundOrderService.java
    │           ├── business/
    │           │   ├── AbstractRefundOrderStrategy.java
    │           │   ├── IRefundOrderStrategy.java
    │           │   └── impl/Paid2RefundStrategy.java
    │           └── factory/RefundStrategyFactory.java
    │
    └── activity/                       # 活动域
        ├── adapter/repository/IActivityRepository.java
        ├── model/entity/MarketProductEntity.java
        └── service/
            ├── IMarketTrialService.java
            └── trial/
                ├── MarketTrialService.java
                ├── factory/DefaultActivityStrategyFactory.java
                └── node/
                    ├── RootNode.java
                    ├── MarketNode.java
                    └── EndNode.java
```

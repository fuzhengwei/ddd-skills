# Infrastructure 层核心实现模式

## 目录结构

```
infrastructure/
├── adapter/
│   ├── repository/         # Repository 实现（实现领域层 IXxxRepository 接口）
│   │   └── TradeRepository.java
│   └── port/               # Port 实现（实现领域层 IXxxPort 接口）
│       └── TradePort.java
├── dao/
│   ├── po/                 # 数据持久化对象（命名必须以 PO 结尾）
│   │   ├── GroupBuyOrderPO.java
│   │   └── GroupBuyOrderListPO.java
│   ├── IGroupBuyOrderDao.java      # MyBatis Mapper 接口
│   └── IGroupBuyOrderListDao.java
├── redis/
│   ├── IRedisService.java  # Redis 服务接口
│   └── RedissonService.java # Redis 服务实现（基于 Redisson）
├── gateway/
│   ├── dto/                # 网关 DTO（命名以 RequestDTO/ResponseDTO 结尾）
│   │   ├── XxxRequestDTO.java
│   │   └── XxxResponseDTO.java
│   └── XxxGateway.java     # 外部服务适配
└── config/                 # Spring 配置类（线程池、OkHttp、RedisTemplate Bean 等）
    └── InfrastructureConfig.java
```

**⚠️ 命名规范：**
- PO 类必须以 `PO` 结尾：`GroupBuyOrderPO`，不能是 `GroupBuyOrder`
- Redis 操作封装放在 `redis/` 包，不能放在 `config/` 包
- Repository 实现放在 `adapter/repository/`，不能放在 `persistent/` 或其他包

---

## 一、DAO 层实现

### 1.1 PO 对象定义

```java
/**
 * 数据持久化对象 - 与数据库表一一对应
 */
@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class GroupBuyOrderPO {

    private Long id;
    
    /** 拼团ID */
    private String teamId;
    
    /** 活动ID */
    private Long activityId;
    
    /** 来源 */
    private String source;
    
    /** 渠道 */
    private String channel;
    
    /** 原价 */
    private BigDecimal originalPrice;
    
    /** 折扣金额 */
    private BigDecimal deductionPrice;
    
    /** 支付金额 */
    private BigDecimal payPrice;
    
    /** 目标人数 */
    private Integer targetCount;
    
    /** 完成人数 */
    private Integer completeCount;
    
    /** 锁定人数 */
    private Integer lockCount;
    
    /** 有效期开始 */
    private Date validStartTime;
    
    /** 有效期结束 */
    private Date validEndTime;
    
    /** 创建时间 */
    private Date createTime;
    
    /** 更新时间 */
    private Date updateTime;
}
```

### 1.2 MyBatis Mapper 接口

```java
/**
 * MyBatis Mapper 接口
 * 方法命名规范见名知意
 */
@Mapper
public interface IGroupBuyOrderDao {

    void insert(GroupBuyOrderPO groupBuyOrderPO);

    int updateAddLockCount(String teamId);

    int updateSubtractionLockCount(String teamId);

    GroupBuyOrderPO queryGroupBuyProgress(String teamId);

    int updateAddCompleteCount(String teamId);

    int updateOrderStatus2COMPLETE(String teamId);

    List<GroupBuyOrderPO> queryGroupBuyTeamByTeamIds(@Param("teamIds") Set<String> teamIds);

    int unpaid2Refund(GroupBuyOrderPO groupBuyOrderPO);

    int paid2Refund(GroupBuyOrderPO groupBuyOrderPO);
}
```

### 1.3 Mapper XML

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE mapper PUBLIC "-//mybatis.org//DTD Mapper 3.0//EN" 
    "http://mybatis.org/dtd/mybatis-3-mapper.dtd">

<mapper namespace="cn.bugstack.infrastructure.dao.IGroupBuyOrderDao">

    <resultMap id="BaseResultMap" type="cn.bugstack.infrastructure.dao.po.GroupBuyOrderPO">
        <id column="id" property="id"/>
        <result column="team_id" property="teamId"/>
        <result column="activity_id" property="activityId"/>
        <!-- 其他字段映射 -->
    </resultMap>

    <insert id="insert" parameterType="cn.bugstack.infrastructure.dao.po.GroupBuyOrderPO" useGeneratedKeys="true" keyProperty="id">
        INSERT INTO group_buy_order (
            team_id, activity_id, source, channel,
            original_price, deduction_price, pay_price,
            target_count, complete_count, lock_count,
            valid_start_time, valid_end_time
        ) VALUES (
            #{teamId}, #{activityId}, #{source}, #{channel},
            #{originalPrice}, #{deductionPrice}, #{payPrice},
            #{targetCount}, #{completeCount}, #{lockCount},
            #{validStartTime}, #{validEndTime}
        )
    </insert>

    <update id="updateAddLockCount">
        UPDATE group_buy_order 
        SET lock_count = lock_count + 1,
            update_time = NOW()
        WHERE team_id = #{teamId}
          AND lock_count + 1 &lt;= target_count
    </update>

    <select id="queryGroupBuyProgress" resultMap="BaseResultMap">
        SELECT * FROM group_buy_order 
        WHERE team_id = #{teamId}
    </select>

    <select id="queryGroupBuyTeamByTeamIds" resultMap="BaseResultMap">
        SELECT * FROM group_buy_order 
        WHERE team_id IN 
        <foreach collection="teamIds" item="teamId" open="(" separator="," close=")">
            #{teamId}
        </foreach>
    </select>

</mapper>
```

### 1.4 批量查询优化

```java
/**
 * 批量查询技巧 - IN 查询
 */
@Override
public List<UserGroupBuyOrderDetailEntity> queryTimeoutUnpaidOrderList() {
    // 1. 批量查询超时订单
    List<GroupBuyOrderListPO> orderLists = groupBuyOrderListDao.queryTimeoutUnpaidOrderList();
    if (CollectionUtils.isEmpty(orderLists)) {
        return new ArrayList<>();
    }

    // 2. 提取所有 teamId
    Set<String> teamIds = orderLists.stream()
            .map(GroupBuyOrderListPO::getTeamId)
            .collect(Collectors.toSet());

    // 3. 批量查询团队信息
    List<GroupBuyOrderPO> groupBuyOrders = groupBuyOrderDao.queryGroupBuyTeamByTeamIds(teamIds);
    
    // 4. 转 Map 便于查询
    Map<String, GroupBuyOrderPO> orderMap = groupBuyOrders.stream()
            .collect(Collectors.toMap(GroupBuyOrderPO::getTeamId, o -> o));

    // 5. 转换结果
    return orderLists.stream()
            .map(list -> {
                GroupBuyOrderPO order = orderMap.get(list.getTeamId());
                // 映射逻辑
            })
            .collect(Collectors.toList());
}
```

---

## 二、Redis 服务实现

### 2.1 接口定义

```java
/**
 * Redis 服务接口
 * 封装常用 Redis 操作
 */
public interface IRedisService {

    // ========== 基本操作 ==========
    <T> void setValue(String key, T value);
    <T> void setValue(String key, T value, long expired);
    <T> T getValue(String key);
    void remove(String key);
    boolean isExists(String key);

    // ========== 计数器 ==========
    void setAtomicLong(String key, long value);
    Long getAtomicLong(String key);
    long incr(String key);
    long incrBy(String key, long delta);
    long decr(String key);
    long decrBy(String key, long delta);

    // ========== 集合 ==========
    void addToSet(String key, String value);
    boolean isSetMember(String key, String value);
    void addToList(String key, String value);

    // ========== Map ==========
    <K, V> RMap<K, V> getMap(String key);
    void addToMap(String key, String field, String value);
    <K, V> V getFromMap(String key, K field);

    // ========== 分布式锁 ==========
    RLock getLock(String key);
    RLock getFairLock(String key);
    RReadWriteLock getReadWriteLock(String key);
    Boolean setNx(String key, long expired, TimeUnit timeUnit);

    // ========== 高级特性 ==========
    RSemaphore getSemaphore(String key);
    RPermitExpirableSemaphore getPermitExpirableSemaphore(String key);
    RCountDownLatch getCountDownLatch(String key);
    <T> RBloomFilter<T> getBloomFilter(String key);

    // ========== 工具方法 ==========
    RBitSet getBitSet(String key);
    default int getIndexFromUserId(String userId) {
        // MD5 哈希取模，用于分片
    }
}
```

### 2.2 实现示例

```java
/**
 * Redis 服务实现 - 基于 Redisson
 */
@Slf4j
@Service
public class RedissonService implements IRedisService {

    @Resource
    private RedissonClient redissonClient;

    @Override
    public <T> void setValue(String key, T value) {
        redissonClient.getBucket(key).set(value);
    }

    @Override
    public <T> void setValue(String key, T value, long expired) {
        redissonClient.getBucket(key).set(value, expired, TimeUnit.SECONDS);
    }

    @Override
    public <T> T getValue(String key) {
        RBucket<T> bucket = redissonClient.getBucket(key);
        return bucket.get();
    }

    @Override
    public long incr(String key) {
        return redissonClient.getAtomicLong(key).incrementAndGet();
    }

    @Override
    public RLock getLock(String key) {
        return redissonClient.getLock(key);
    }

    @Override
    public Boolean setNx(String key, long expired, TimeUnit timeUnit) {
        return redissonClient.getBucket(key).setIfAbsent(true, expired, timeUnit);
    }

    @Override
    public <T> RBloomFilter<T> getBloomFilter(String key) {
        return redissonClient.getBloomFilter(key);
    }
}
```

### 2.3 分布式锁使用

```java
/**
 * 分布式锁使用示例
 */
public void processWithLock(String key) {
    RLock lock = redisService.getLock(key);
    try {
        // 尝试加锁，等待10秒，锁定30秒
        boolean locked = lock.tryLock(10, 30, TimeUnit.SECONDS);
        if (locked) {
            // 业务处理
            doBusiness();
        }
    } catch (InterruptedException e) {
        Thread.currentThread().interrupt();
    } finally {
        // 必须在 finally 中释放锁
        if (lock.isHeldByCurrentThread()) {
            lock.unlock();
        }
    }
}
```

### 2.4 BitSet 用户画像

使用 Redis 的 `RBitSet` 结构，通过用户 ID 转换的偏移量快速判断用户是否属于特定人群标签：

```java
/**
 * 使用 BitSet 快速判断用户标签（节省内存且高效）
 */
@Override
public boolean isTagCrowdRange(String tagId, String userId) {
    RBitSet bitSet = redisService.getBitSet(tagId);
    if (!bitSet.isExists()) {
        return false;
    }
    // 将用户 ID 映射为 BitSet 的偏移量
    return bitSet.get(redisService.getIndexFromUserId(userId));
}
```

---

## 三、Repository 实现

### 3.1 基础 Repository 与 Cache-Aside 模式

```java
/**
 * 基础 Repository - 提供通用能力（包含 Cache-Aside 旁路缓存实现）
 */
@Slf4j
public abstract class AbstractRepository {

    @Resource
    protected IRedisService redisService;
    
    @Resource
    protected DCCService dccService;

    /**
     * Cache-Aside 缓存回退模板方法
     * 1. 查缓存，有则返回
     * 2. 无缓存，查库
     * 3. 写缓存，返回库结果
     */
    protected <T> T getFromCacheOrDb(String cacheKey, Supplier<T> dbFallback) {
        // DCC 动态降级开关
        if (dccService.isCacheOpenSwitch()) {
            T cacheResult = redisService.getValue(cacheKey);
            if (null != cacheResult) return cacheResult;
            
            T dbResult = dbFallback.get();
            if (null == dbResult) return null;
            
            redisService.setValue(cacheKey, dbResult);
            return dbResult;
        } else {
            log.warn("缓存降级 {}", cacheKey);
            return dbFallback.get();
        }
    }

    /**
     * 通用分页查询
     */
    protected <T> Page<T> queryPage(PageQuery<T> query, BaseDao<T> dao) {
        int offset = (query.getPage() - 1) * query.getSize();
        List<T> records = dao.queryByCondition(query, offset, query.getSize());
        long total = dao.countByCondition(query);
        return Page.of(records, total, query.getPage(), query.getSize());
    }
}
```

### 3.2 业务 Repository

```java
/**
 * 交易仓储实现
 */
@Slf4j
@Repository
public class TradeRepository implements ITradeRepository {

    @Resource
    private IGroupBuyOrderDao groupBuyOrderDao;
    
    @Resource
    private IGroupBuyOrderListDao groupBuyOrderListDao;
    
    @Resource
    private INotifyTaskDao notifyTaskDao;
    
    @Resource
    private DCCService dccService;
    
    @Resource
    private IRedisService redisService;

    @Value("${rabbitmq.routing.key.team_success}")
    private String topicTeamSuccess;

    /**
     * 查询映射 - PO → Entity
     */
    @Override
    public MarketPayOrderEntity queryMarketPayOrderEntityByOutTradeNo(String userId, String outTradeNo) {
        GroupBuyOrderListPO list = groupBuyOrderListDao.queryGroupBuyOrderRecordByOutTradeNo(
            GroupBuyOrderListPO.builder()
                .userId(userId)
                .outTradeNo(outTradeNo)
                .build()
        );
        if (null == list) return null;

        return MarketPayOrderEntity.builder()
                .teamId(list.getTeamId())
                .orderId(list.getOrderId())
                .payPrice(list.getPayPrice())
                .tradeOrderStatusEnumVO(TradeOrderStatusEnumVO.valueOf(list.getStatus()))
                .build();
    }

    /**
     * 聚合操作 - 事务保证一致性
     */
    @Transactional(timeout = 500)
    @Override
    public MarketPayOrderEntity lockMarketPayOrder(GroupBuyOrderAggregate aggregate) {
        // 1. 构建 PO
        GroupBuyOrderPO order = GroupBuyOrderPO.builder()
                .teamId(generateTeamId())
                .activityId(aggregate.getPayActivityEntity().getActivityId())
                .build();

        // 2. 写入主记录
        groupBuyOrderDao.insert(order);

        // 3. 写入明细记录
        GroupBuyOrderListPO orderList = GroupBuyOrderListPOPO.builder()
                .teamId(order.getTeamId())
                .orderId(generateOrderId())
                .userId(aggregate.getUserEntity().getUserId())
                .build();
        groupBuyOrderListDao.insert(orderList);

        // 4. 返回实体
        return MarketPayOrderEntity.builder()
                .teamId(order.getTeamId())
                .orderId(orderList.getOrderId())
                .build();
    }

    /**
     * 乐观锁更新
     */
    @Override
    public boolean occupyTeamStock(String teamStockKey, String recoveryKey, Integer target, Integer validTime) {
        // 1. 检查恢复量
        Long recoveryCount = redisService.getAtomicLong(recoveryKey);
        recoveryCount = null == recoveryCount ? 0 : recoveryCount;

        // 2. 自增并校验
        long occupy = redisService.incr(teamStockKey) + 1;
        if (occupy > target + recoveryCount) {
            redisService.decr(teamStockKey);
            return false;
        }

        // 3. 加锁保护
        String lockKey = teamStockKey + "_" + occupy;
        return redisService.setNx(lockKey, validTime + 60, TimeUnit.MINUTES);
    }
}
```

---

## 四、事务处理技巧

### 4.1 超时控制

```java
/**
 * 事务超时设置
 */
@Transactional(timeout = 500)  // 500ms 超时
public MarketPayOrderEntity lockMarketPayOrder(...) {
    // 操作
}
```

### 4.2 影响行数校验

```java
/**
 * 乐观锁模式 - 检查更新影响行数
 */
@Override
public int updateAddLockCount(String teamId) {
    return groupBuyOrderDao.updateAddLockCount(teamId);
}

// 在服务层校验
int updateCount = repository.updateAddLockCount(teamId);
if (1 != updateCount) {
    // 并发冲突或数据不存在
    throw new AppException(ResponseCode.E0005);
}
```

### 4.3 异常回滚 + 补偿

```java
@Override
public MarketPayOrderEntity lockMarketPayOrder(...) {
    // 1. 占用库存
    TradeLockRuleFilterBackEntity back = tradeRuleFilter.apply(...);
    
    try {
        // 2. 执行业务
        return repository.lockMarketPayOrder(aggregate);
    } catch (Exception e) {
        // 3. 失败补偿 - 恢复库存
        repository.recoveryTeamStock(back.getRecoveryTeamStockKey(), activity.getValidTime());
        throw e;
    }
}
```

---

## 五、外部服务适配

### 5.1 泛型 HTTP 网关 (Retrofit)
**适用场景**：动态 URL、多变参数的外部接口调用（如 `ai-mcp-gateway`）。

```java
/**
 * 基于 Retrofit 的通用 HTTP 网关接口
 */
public interface GenericHttpGateway {
    @POST
    Call<ResponseBody> post(
            @Url String url,
            @HeaderMap Map<String, Object> headers,
            @Body RequestBody body
    );

    @GET
    Call<ResponseBody> get(
            @Url String url,
            @HeaderMap Map<String, Object> headers,
            @QueryMap Map<String, Object> queryParams
    );
}

/**
 * Port 实现类调用泛型网关
 */
@Slf4j
@Service
public class SessionPort implements ISessionPort {
    @Resource
    private GenericHttpGateway genericHttpGateway;

    @Override
    public String toolCall(String url, Map<String, Object> params) throws Exception {
        RequestBody body = RequestBody.create(
                MediaType.parse("application/json"), JSON.toJSONString(params));
        Response<ResponseBody> response = genericHttpGateway.post(url, new HashMap<>(), body).execute();
        return response.body().string();
    }
}
```

### 5.2 外部 API 调用 (RestTemplate)

```java
/**
 * 外部网关服务适配
 */
@Slf4j
@Service
public class GroupBuyNotifyService {

    @Resource
    private RestTemplate restTemplate;

    /**
     * HTTP 回调通知
     */
    public Map<String, Object> notifyByHttp(String url, Map<String, Object> params) {
        try {
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            
            HttpEntity<Map<String, Object>> request = new HttpEntity<>(params, headers);
            ResponseEntity<Map> response = restTemplate.postForEntity(url, request, Map.class);
            
            return response.getBody();
        } catch (Exception e) {
            log.error("HTTP 通知失败 url:{} error:{}", url, e.getMessage());
            throw new AppException(ResponseCode.NOTIFY_FAILED);
        }
    }
}
```

### 5.2 配置中心

```java
/**
 * 分布式配置中心服务
 */
@Slf4j
@Service
public class DCCService {

    @Resource
    private Config config;

    /**
     * 查询是否在黑名单
     */
    public boolean isSCBlackIntercept(String source, String channel) {
        // 从配置中心获取黑名单
        String blackList = config.getString("sc.black.list", "");
        
        // 逗号分隔的 source:channel 列表
        return Arrays.stream(blackList.split(","))
                .anyMatch(item -> item.equals(source + ":" + channel));
    }
}
```

---

## 六、事件发布

### 6.1 本地消息表模式

```java
/**
 * 事件发布 - 本地消息表
 */
@Slf4j
@Service
public class EventPublisher {

    @Resource
    private INotifyTaskDao notifyTaskDao;

    /**
     * 发布事件
     */
    public void publishSettlementEvent(GroupBuyTeamEntity team, List<String> outTradeNos) {
        NotifyTask task = NotifyTask.builder()
                .teamId(team.getTeamId())
                .activityId(team.getActivityId())
                .notifyType("MQ")
                .notifyMQ("topic.team.success")
                .parameterJson(JSON.toJSONString(new HashMap<String, Object>() {{
                    put("teamId", team.getTeamId());
                    put("outTradeNoList", outTradeNos);
                }}))
                .build();
        
        notifyTaskDao.insert(task);
    }
}
```

---

## 七、PO → Entity 转换

### 7.1 手动转换

```java
/**
 * 单个转换
 */
GroupBuyActivityEntity toEntity(GroupBuyActivity po) {
    return GroupBuyActivityEntity.builder()
            .activityId(po.getActivityId())
            .activityName(po.getActivityName())
            .status(ActivityStatusEnumVO.valueOf(po.getStatus()))
            .build();
}

/**
 * 批量转换
 */
List<GroupBuyActivityEntity> toEntityList(List<GroupBuyActivity> poList) {
    return poList.stream()
            .map(this::toEntity)
            .collect(Collectors.toList());
}
```

### 7.2 MapStruct 转换（可选）

```java
/**
 * MapStruct 映射
 */
@Mapper(componentModel = "spring")
public interface ActivityConverter {
    
    @Mapping(source = "activityId", target = "id")
    @Mapping(source = "status", target = "statusEnum", qualifiedByName = "statusToEnum")
    GroupBuyActivityEntity toEntity(GroupBuyActivity po);
    
    default ActivityStatusEnumVO mapStatus(Integer status) {
        return ActivityStatusEnumVO.valueOf(status);
    }
}
```

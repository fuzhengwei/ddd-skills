# Domain 层设计指南 - 避免常见错误

## 核心原则

**Domain 层负责业务规则，Infrastructure 层负责数据读写。**

两者的边界非常清晰：
- Domain：业务校验、流程编排、规则判断、状态变更
- Infrastructure：DAO 操作、Redis 读写、HTTP 调用

---

## 一、常见错误诊断

### ❌ 错误1：Domain Service 代码平铺，缺少拆分

**问题表现**：一个 Service 实现类几百行，所有逻辑堆在一起。

```java
// ❌ 错误示例：executeApproval 方法 100+ 行，逻辑全部平铺
@Service
public class CapabilityApprovalServiceImpl implements ICapabilityApprovalService {

    @Override
    public CapabilityResultVO executeApproval(String submitId, String capabilityCode, String approveBy) {
        // 1. 查重复审批
        ApproveRecordEntity existRecord = capabilityConfigRepository.queryApproveRecordBySubmitId(submitId);
        if (existRecord != null && existRecord.isApproved()) {
            return CapabilityResultVO.fail("4001", "该记录已审批通过");
        }

        // 2. 查字段值
        List<FormFieldValueEntity> fieldValues = formRepository.queryFormFieldValueList(submitId);
        Map<String, String> fieldValueMap = new HashMap<>();
        String formId = null;
        for (FormFieldValueEntity fv : fieldValues) {
            fieldValueMap.put(fv.getFieldId(), fv.getFieldValue());
            if (formId == null) formId = fv.getFormId();
        }

        // 3. 查能力配置
        CapabilityConfigEntity config = null;
        List<CapabilityConfigEntity> configs = capabilityConfigRepository.queryCapabilityConfigByFormId(formId);
        for (CapabilityConfigEntity c : configs) {
            if (c.getCapabilityCode().equals(capabilityCode)) { config = c; break; }
        }

        // 4. 执行审批（if-else 判断能力类型）
        CapabilityResultVO result;
        if (CAPABILITY_GITCODE_APPROVE.equals(capabilityCode)) {
            // ... 大量逻辑
        } else {
            result = CapabilityResultVO.fail("4004", "不支持的能力类型");
        }

        // 5. 保存审批记录
        ApproveRecordEntity record = new ApproveRecordEntity();
        // ... 大量字段赋值
        capabilityConfigRepository.saveApproveRecord(record);

        return result;
    }
}
```

**问题根因**：
1. 没有识别出"多种审批能力"是策略模式的典型场景
2. 没有把"校验"、"执行"、"记录"拆分为独立步骤（责任链）
3. 所有逻辑写在一个方法里，难以扩展和测试

---

### ❌ 错误2：业务逻辑写进 Infrastructure 层

**问题表现**：Infrastructure 层的 Repository 或 Executor 里包含业务判断逻辑。

```java
// ❌ 错误示例：GitCodeScenarioExecutor 在 Infrastructure 层做业务判断
@Service
public class GitCodeScenarioExecutor implements IScenarioExecutor {

    @Override
    public ScenarioResultVO execute(Map<String, String> configParams, Map<String, String> paramValues) {
        // ❌ 这里做了业务校验（应该在 Domain 层做）
        if (!paramValues.containsKey("username")) {
            return ScenarioResultVO.fail("缺少用户名参数");
        }
        if (!paramValues.containsKey("projectName")) {
            return ScenarioResultVO.fail("缺少项目名参数");
        }

        // ❌ 这里做了业务规则判断（应该在 Domain 层做）
        String username = paramValues.get("username");
        if (username.length() < 3) {
            return ScenarioResultVO.fail("用户名长度不能小于3");
        }

        // 调用外部 API（这部分是对的，属于 Infrastructure 职责）
        return gitCodeGateway.createRepository(configParams, paramValues);
    }
}
```

**正确做法**：Infrastructure 层只负责数据读写和外部调用，业务校验放在 Domain 层。

---

### ❌ 错误3：Domain Service 直接依赖另一个 Domain 的 Repository

**问题表现**：`CapabilityApprovalServiceImpl` 直接注入了 `IFormRepository`（跨域依赖）。

```java
// ❌ 错误：capability 域的 Service 直接依赖 form 域的 Repository
@Service
public class CapabilityApprovalServiceImpl implements ICapabilityApprovalService {

    @Resource
    private ICapabilityConfigRepository capabilityConfigRepository;

    @Resource
    private IFormRepository formRepository;  // ❌ 跨域依赖
}
```

**正确做法**：通过 Case 层编排，或在同一个 Repository 接口中聚合所需数据。

---

## 二、正确的 Domain 层设计

### 场景：审批能力执行（多种能力类型）

**分析**：
- 有多种审批能力（GitCode、HTTP、钉钉等）→ **策略模式**
- 执行前需要多步校验（重复审批、数据存在、配置存在）→ **责任链模式**
- 执行后需要记录日志 → **模板方法**

#### 第一步：识别策略，定义接口

```java
/**
 * 审批能力策略接口
 * 
 * 每种能力类型（GitCode、HTTP、钉钉等）实现此接口
 */
public interface IApprovalCapabilityStrategy {

    /**
     * 执行审批
     *
     * @param configParams  能力配置参数（来自管理员配置）
     * @param fieldValues   用户填写的字段值（来自表单提交）
     * @return 审批结果
     */
    CapabilityResultVO execute(Map<String, String> configParams, Map<String, String> fieldValues) throws Exception;

    /**
     * 支持的能力类型编码
     */
    String capabilityCode();
}
```

#### 第二步：抽象基类（模板方法）

```java
/**
 * 审批能力策略抽象基类
 * 
 * 封装通用逻辑：参数提取、日志记录
 */
@Slf4j
public abstract class AbstractApprovalCapabilityStrategy implements IApprovalCapabilityStrategy {

    /**
     * 从字段值中按映射关系提取参数
     */
    protected Map<String, String> extractParams(Map<String, String> fieldValueMap,
                                                  Map<String, String> fieldMapping) {
        Map<String, String> params = new HashMap<>();
        for (Map.Entry<String, String> entry : fieldMapping.entrySet()) {
            String paramKey = entry.getKey();
            String fieldId = entry.getValue();
            String value = fieldValueMap.get(fieldId);
            if (value != null) {
                params.put(paramKey, value);
            }
        }
        return params;
    }

    /**
     * 子类实现具体审批逻辑
     */
    protected abstract CapabilityResultVO doExecute(Map<String, String> configParams,
                                                      Map<String, String> params) throws Exception;

    @Override
    public CapabilityResultVO execute(Map<String, String> configParams,
                                       Map<String, String> fieldValues) throws Exception {
        log.info("执行审批能力 type:{}", capabilityCode());
        return doExecute(configParams, fieldValues);
    }
}
```

#### 第三步：具体策略实现

```java
/**
 * GitCode 仓库审批策略
 */
@Slf4j
@Service("gitcode_approve")
public class GitCodeApprovalStrategy extends AbstractApprovalCapabilityStrategy {

    @Resource
    private IGitCodeApprovalPort gitCodeApprovalPort;  // 调用 Port，不直接调 HTTP

    @Override
    public String capabilityCode() {
        return "gitcode_approve";
    }

    @Override
    protected CapabilityResultVO doExecute(Map<String, String> configParams,
                                            Map<String, String> params) throws Exception {
        log.info("GitCode 审批 username:{}", params.get("username"));
        return gitCodeApprovalPort.approveRepository(configParams, params);
    }
}

/**
 * HTTP 回调审批策略（未来扩展）
 */
@Slf4j
@Service("http_approve")
public class HttpApprovalStrategy extends AbstractApprovalCapabilityStrategy {

    @Resource
    private ICapabilityPort capabilityPort;

    @Override
    public String capabilityCode() {
        return "http_approve";
    }

    @Override
    protected CapabilityResultVO doExecute(Map<String, String> configParams,
                                            Map<String, String> params) throws Exception {
        return capabilityPort.callHttpApproval(configParams, params);
    }
}
```

#### 第四步：责任链过滤器（多步校验）

```java
/**
 * 审批规则过滤器接口
 */
public interface IApprovalRuleFilter {
    ApprovalRuleFilterBackEntity filter(ApprovalRuleCommandEntity command,
                                        ApprovalRuleFilterFactory.DynamicContext context) throws Exception;
}

/**
 * 过滤器1：重复审批校验
 */
@Slf4j
@Service
public class DuplicateApprovalFilter implements IApprovalRuleFilter {

    @Resource
    private ICapabilityConfigRepository repository;

    @Override
    public ApprovalRuleFilterBackEntity filter(ApprovalRuleCommandEntity command,
                                                ApprovalRuleFilterFactory.DynamicContext context) throws Exception {
        log.info("校验重复审批 submitId:{}", command.getSubmitId());

        ApproveRecordEntity record = repository.queryApproveRecordBySubmitId(command.getSubmitId());
        if (record != null && record.isApproved()) {
            throw new AppException(ResponseCode.ALREADY_APPROVED);
        }

        context.setExistRecord(record);
        return ApprovalRuleFilterBackEntity.builder().build();
    }
}

/**
 * 过滤器2：提交数据存在性校验
 */
@Slf4j
@Service
public class SubmitDataExistFilter implements IApprovalRuleFilter {

    @Resource
    private ICapabilityConfigRepository repository;

    @Override
    public ApprovalRuleFilterBackEntity filter(ApprovalRuleCommandEntity command,
                                                ApprovalRuleFilterFactory.DynamicContext context) throws Exception {
        log.info("校验提交数据 submitId:{}", command.getSubmitId());

        List<FormFieldValueEntity> fieldValues = repository.queryFieldValuesBySubmitId(command.getSubmitId());
        if (fieldValues == null || fieldValues.isEmpty()) {
            throw new AppException(ResponseCode.SUBMIT_DATA_NOT_FOUND);
        }

        // 构建字段值 Map，写入上下文
        Map<String, String> fieldValueMap = fieldValues.stream()
                .collect(Collectors.toMap(FormFieldValueEntity::getFieldId,
                                          FormFieldValueEntity::getFieldValue));
        context.setFieldValueMap(fieldValueMap);
        context.setFormId(fieldValues.get(0).getFormId());

        return ApprovalRuleFilterBackEntity.builder().build();
    }
}

/**
 * 过滤器3：能力配置存在性校验
 */
@Slf4j
@Service
public class CapabilityConfigExistFilter implements IApprovalRuleFilter {

    @Resource
    private ICapabilityConfigRepository repository;

    @Override
    public ApprovalRuleFilterBackEntity filter(ApprovalRuleCommandEntity command,
                                                ApprovalRuleFilterFactory.DynamicContext context) throws Exception {
        log.info("校验能力配置 formId:{} capabilityCode:{}", context.getFormId(), command.getCapabilityCode());

        CapabilityConfigEntity config = repository.queryCapabilityConfig(
                context.getFormId(), command.getCapabilityCode());
        if (config == null) {
            throw new AppException(ResponseCode.CAPABILITY_CONFIG_NOT_FOUND);
        }

        context.setCapabilityConfig(config);
        return ApprovalRuleFilterBackEntity.builder().build();
    }
}
```

#### 第五步：工厂组装责任链

```java
/**
 * 审批规则过滤器工厂
 */
@Slf4j
@Service
public class ApprovalRuleFilterFactory {

    @Bean("approvalRuleFilter")
    public BusinessLinkedList<ApprovalRuleCommandEntity, DynamicContext, ApprovalRuleFilterBackEntity>
            buildFilterChain(DuplicateApprovalFilter f1,
                             SubmitDataExistFilter f2,
                             CapabilityConfigExistFilter f3) {
        LinkArmory<ApprovalRuleCommandEntity, DynamicContext, ApprovalRuleFilterBackEntity> armory =
                new LinkArmory<>("审批规则过滤链", f1, f2, f3);
        return armory.getLogicLink();
    }

    /**
     * 动态上下文 - 在过滤器之间传递数据
     */
    @Data
    @Builder
    @AllArgsConstructor
    @NoArgsConstructor
    public static class DynamicContext {
        private ApproveRecordEntity existRecord;
        private Map<String, String> fieldValueMap;
        private String formId;
        private CapabilityConfigEntity capabilityConfig;
    }
}
```

#### 第六步：精简的 Domain Service

```java
/**
 * 审批能力服务实现
 * 
 * 职责：编排责任链 + 选择策略 + 保存结果
 * 不包含：具体校验逻辑、具体执行逻辑（已拆到过滤器和策略中）
 */
@Slf4j
@Service
public class CapabilityApprovalServiceImpl implements ICapabilityApprovalService {

    @Resource
    private ICapabilityConfigRepository repository;

    @Resource
    private BusinessLinkedList<ApprovalRuleCommandEntity, ApprovalRuleFilterFactory.DynamicContext,
            ApprovalRuleFilterBackEntity> approvalRuleFilter;

    @Resource
    private Map<String, IApprovalCapabilityStrategy> strategyMap;  // Spring 自动注入所有策略

    @Override
    @Transactional
    public CapabilityResultVO executeApproval(String submitId, String capabilityCode, String approveBy) {
        log.info("执行审批 submitId:{} capabilityCode:{} approveBy:{}", submitId, capabilityCode, approveBy);

        // 1. 责任链校验（校验逻辑已拆到各过滤器中）
        ApprovalRuleFilterFactory.DynamicContext context = new ApprovalRuleFilterFactory.DynamicContext();
        try {
            approvalRuleFilter.apply(
                    ApprovalRuleCommandEntity.builder()
                            .submitId(submitId)
                            .capabilityCode(capabilityCode)
                            .build(),
                    context);
        } catch (AppException e) {
            return CapabilityResultVO.fail(e.getCode(), e.getMessage());
        }

        // 2. 选择策略执行（策略逻辑已拆到各 Strategy 中）
        IApprovalCapabilityStrategy strategy = strategyMap.get(capabilityCode);
        if (strategy == null) {
            return CapabilityResultVO.fail(ResponseCode.CAPABILITY_NOT_SUPPORT);
        }

        CapabilityResultVO result;
        try {
            CapabilityConfigEntity config = context.getCapabilityConfig();
            result = strategy.execute(config.getConfigParamsMap(), context.getFieldValueMap());
        } catch (Exception e) {
            log.error("执行审批能力失败", e);
            result = CapabilityResultVO.fail(ResponseCode.EXECUTE_FAILED);
        }

        // 3. 保存审批记录
        saveApproveRecord(submitId, context.getFormId(), capabilityCode, approveBy, result, context.getExistRecord());

        return result;
    }

    private void saveApproveRecord(String submitId, String formId, String capabilityCode,
                                    String approveBy, CapabilityResultVO result,
                                    ApproveRecordEntity existRecord) {
        ApproveRecordEntity record = ApproveRecordEntity.builder()
                .submitId(submitId)
                .formId(formId)
                .capabilityCode(capabilityCode)
                .approveStatus(result.getSuccess() ? ApproveRecordEntity.STATUS_APPROVED
                                                   : ApproveRecordEntity.STATUS_REJECTED)
                .approveTime(System.currentTimeMillis())
                .approveBy(approveBy)
                .approveMessage(result.getMessage())
                .build();

        if (existRecord != null) {
            record.setId(existRecord.getId());
            repository.updateApproveRecord(record);
        } else {
            repository.saveApproveRecord(record);
        }
    }
}
```

---

## 三、何时需要设计模式

### 判断流程

```
新功能需求
    │
    ▼
有多种处理方式，根据条件选择？
    │是 → 策略模式（IXxxStrategy + 实现类 + Map<String, IXxxStrategy>）
    │否
    ▼
有多个独立的校验/过滤步骤？
    │是 → 责任链模式（IXxxFilter + Factory 组装链）
    │否
    ▼
有复杂的流程分支，需要节点路由？
    │是 → 决策树模式（AbstractNode + RootNode + XxxNode）
    │否
    ▼
有通用逻辑 + 子类差异化实现？
    │是 → 模板方法（AbstractXxxStrategy + 子类）
    │否
    ▼
直接实现（无需设计模式）
```

### 典型场景对应

| 业务场景 | 设计模式 | 示例 |
|---------|---------|------|
| 多种审批能力（GitCode/HTTP/钉钉） | 策略模式 | `IApprovalCapabilityStrategy` |
| 多种退单类型（未支付/已支付未成团/已成团） | 策略模式 | `IRefundOrderStrategy` |
| 多种折扣计算（满减/折扣/免单） | 策略模式 | `IDiscountCalculateService` |
| 下单前多步校验（活动状态/用户限制/库存） | 责任链模式 | `ITradeLockRuleFilter` |
| 审批前多步校验（重复/数据/配置） | 责任链模式 | `IApprovalRuleFilter` |
| 营销试算流程（开关→活动→标签→结果） | 决策树模式 | `RootNode → MarketNode → TagNode` |
| 退单策略共用逻辑（MQ发送/库存恢复） | 模板方法 | `AbstractRefundOrderStrategy` |
| 简单 CRUD、单一流程 | 无需设计模式 | 直接实现 |

---

## 四、Infrastructure 层的正确边界

### Infrastructure 只做这些事

```java
// ✅ 正确：Repository 只做数据读写，不做业务判断
@Repository
public class CapabilityConfigRepository implements ICapabilityConfigRepository {

    @Resource
    private ICapabilityConfigDao capabilityConfigDao;

    @Override
    public CapabilityConfigEntity queryCapabilityConfig(String formId, String capabilityCode) {
        // 只做：查询 PO → 转换 Entity，不做业务判断
        CapabilityConfigPO po = capabilityConfigDao.selectByFormIdAndCode(formId, capabilityCode);
        return po == null ? null : convertToEntity(po);
    }

    @Override
    public void saveApproveRecord(ApproveRecordEntity entity) {
        // 只做：转换 PO → 插入数据库
        ApproveRecordPO po = convertToPO(entity);
        approveRecordDao.insert(po);
    }

    private CapabilityConfigEntity convertToEntity(CapabilityConfigPO po) {
        return CapabilityConfigEntity.builder()
                .id(po.getId())
                .formId(po.getFormId())
                .capabilityCode(po.getCapabilityCode())
                .configParams(po.getConfigParams())
                .build();
    }
}

// ✅ 正确：Port 只做外部调用，不做业务判断
@Component
public class GitCodeApprovalPort implements IGitCodeApprovalPort {

    @Resource
    private IGitCodeGateway gitCodeGateway;

    @Override
    public CapabilityResultVO approveRepository(Map<String, String> configParams,
                                                 Map<String, String> params) throws Exception {
        // 只做：调用外部 API，转换结果
        GitCodeMemberDTO result = gitCodeGateway.addMember(
                configParams.get("baseUrl"),
                configParams.get("token"),
                params.get("username"),
                params.get("projectName"));

        return result != null
                ? CapabilityResultVO.success("审批成功")
                : CapabilityResultVO.fail("5001", "GitCode 调用失败");
    }
}
```

### Infrastructure 不做这些事

```java
// ❌ 错误：在 Infrastructure 层做业务校验
@Component
public class GitCodeScenarioExecutor implements IScenarioExecutor {

    @Override
    public ScenarioResultVO execute(Map<String, String> configParams, Map<String, String> paramValues) {
        // ❌ 业务校验不应在 Infrastructure 层
        if (!paramValues.containsKey("username")) {
            return ScenarioResultVO.fail("缺少用户名参数");
        }
        // ❌ 业务规则不应在 Infrastructure 层
        if (paramValues.get("username").length() < 3) {
            return ScenarioResultVO.fail("用户名长度不能小于3");
        }
        // 调用外部 API（这部分是对的）
        return gitCodeGateway.execute(configParams, paramValues);
    }
}

// ✅ 正确：业务校验放在 Domain 层的过滤器中
@Service
public class ParamValidateFilter implements IScenarioRuleFilter {

    @Override
    public ScenarioRuleFilterBackEntity filter(ScenarioRuleCommandEntity command,
                                                DynamicContext context) throws Exception {
        // 业务校验在 Domain 层
        if (!command.getParamValues().containsKey("username")) {
            throw new AppException(ResponseCode.PARAM_MISSING, "缺少用户名参数");
        }
        if (command.getParamValues().get("username").length() < 3) {
            throw new AppException(ResponseCode.PARAM_INVALID, "用户名长度不能小于3");
        }
        return ScenarioRuleFilterBackEntity.builder().build();
    }
}
```

---

## 五、重构 easy-form 的建议

### 当前问题汇总

| 问题 | 位置 | 建议 |
|------|------|------|
| `executeApproval` 方法 100+ 行平铺 | `CapabilityApprovalServiceImpl` | 拆分为责任链（校验）+ 策略（执行） |
| 多种能力类型用 if-else 判断 | `CapabilityApprovalServiceImpl` | 策略模式 `IApprovalCapabilityStrategy` |
| 业务校验写在 Infrastructure 层 | `GitCodeScenarioExecutor` | 校验移到 Domain 层过滤器 |
| capability 域直接依赖 form 域 Repository | `CapabilityApprovalServiceImpl` | 通过 Case 层编排，或合并 Repository 接口 |
| `persistent/repository/` 包名错误 | Infrastructure 层 | 改为 `adapter/repository/` |
| `scenario/dao/` 包名错误 | Infrastructure 层 | 改为 `dao/` |

### 重构后的目录结构

```
domain/
└── capability/
    ├── adapter/
    │   ├── port/IGitCodeApprovalPort.java
    │   └── repository/ICapabilityConfigRepository.java
    ├── model/
    │   ├── aggregate/ApprovalAggregate.java
    │   ├── entity/
    │   │   ├── ApprovalRuleCommandEntity.java
    │   │   ├── ApprovalRuleFilterBackEntity.java
    │   │   └── CapabilityConfigEntity.java
    │   └── valobj/
    │       ├── CapabilityResultVO.java
    │       └── CapabilityTypeEnumVO.java
    └── service/
        ├── ICapabilityApprovalService.java
        └── approval/
            ├── CapabilityApprovalServiceImpl.java   # 精简，只做编排
            ├── factory/
            │   └── ApprovalRuleFilterFactory.java   # 组装责任链
            ├── filter/                               # 责任链过滤器
            │   ├── DuplicateApprovalFilter.java
            │   ├── SubmitDataExistFilter.java
            │   └── CapabilityConfigExistFilter.java
            └── strategy/                             # 能力策略
                ├── IApprovalCapabilityStrategy.java
                ├── AbstractApprovalCapabilityStrategy.java
                └── impl/
                    ├── GitCodeApprovalStrategy.java
                    └── HttpApprovalStrategy.java
```

---

## 六、设计模式使用原则

### 适度原则

**不是所有代码都需要设计模式。** 判断标准：

| 业务特征 | 是否需要设计模式 |
|---------|----------------|
| 逻辑简单，步骤固定 | ❌ 不需要，直接实现 |
| 有 2 种以上处理方式，且未来可能扩展 | ✅ 策略模式 |
| 有 3 个以上独立校验步骤 | ✅ 责任链模式 |
| 流程有明显分支，需要路由 | ✅ 决策树模式 |
| 多个实现类有大量重复代码 | ✅ 模板方法 |

### 警告信号

当你看到以下代码，说明需要引入设计模式：

```java
// 信号1：大量 if-else 判断类型
if ("gitcode".equals(type)) {
    // 100行逻辑
} else if ("http".equals(type)) {
    // 100行逻辑
} else if ("dingtalk".equals(type)) {
    // 100行逻辑
}
// → 策略模式

// 信号2：方法超过 80 行，包含多个独立步骤
public void execute(...) {
    // 步骤1：校验重复（20行）
    // 步骤2：查询数据（20行）
    // 步骤3：校验配置（20行）
    // 步骤4：执行业务（30行）
    // 步骤5：保存记录（20行）
}
// → 责任链模式（步骤1-3）+ 策略模式（步骤4）

// 信号3：Infrastructure 层出现业务判断
if (result == null || result.isEmpty()) {
    return fail("业务校验失败");  // ❌ 这是业务逻辑，不属于 Infrastructure
}
// → 将校验移到 Domain 层
```

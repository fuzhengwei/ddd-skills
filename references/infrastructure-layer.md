# Infrastructure Layer - 基础设施层

## 🚨 重要警告：禁止使用 `persistent` 包

> **在生成 Infrastructure 层代码时，AI 必须严格遵守以下规则：**
> 
> ❌ **绝对禁止创建 `persistent/`、`persistent/repository/`、`persistent/dao/`、`persistent/po/` 等任何以 `persistent` 开头的包**
> 
> ❌ **这些包名在 DDD 六边形架构中不存在，使用它们是严重的架构违规**
> 
> ✅ **唯一正确的结构如下文所述，任何偏离都是错误的**

## 概述

基础设施层（Infrastructure Layer）是 DDD 六边形架构的最底层，负责：
1. **实现 Domain 层定义的接口**（Repository、Port）
2. **提供数据持久化能力**（MyBatis DAO + PO）
3. **提供远程服务调用能力**（HTTP Gateway + DTO）

## 整体结构

```
{infrastructure-module}/
├── adapter/                              # 适配器实现（实现领域层定义的接口）
│   ├── port/                             # Port 实现（远程调用）
│   │   └── XxxPort.java                  # 实现领域层定义的 IPort 接口，调用 gateway
│   └── repository/                       # Repository 实现（本地数据）
│       └── XxxRepository.java            # 实现领域层定义的 IRepository 接口，调用 dao/redis
├── dao/                                  # MyBatis DAO 接口和 PO 对象
│   ├── po/                               # Persistence Object（数据库映射对象）
│   │   └── XxxPO.java
│   └── IXxxDao.java                      # DAO 接口，操作数据库
├── gateway/                              # HTTP / RPC 客户端
│   ├── dto/                              # 远程调用 DTO
│   │   ├── XxxRequestDTO.java
│   │   └── XxxResponseDTO.java
│   └── XxxGateway.java                   # HTTP 服务客户端
├── redis/                                # Redis 操作（RedisTemplate 封装）
│   └── IRedisService.java / RedisService.java
└── config/                               # Spring 配置类（线程池、OkHttp 等）

{app-module}/src/main/resources/
└── mybatis/
    └── mapper/                           # Mapper XML 文件
        └── xxx_mapper.xml
```

**⚠️ 重要规范说明：**

| 包路径 | 职责 | 禁止事项 |
|--------|------|----------|
| `adapter/repository/` | 实现领域层 IRepository 接口，调用 dao/redis | ❌ 禁止放 DAO 操作代码 |
| `adapter/port/` | 实现领域层 IPort 接口，调用 gateway | ❌ 禁止直接操作数据库 |
| `dao/` | DAO 接口 + PO 对象，直接操作数据库 | ❌ 禁止放 Repository 实现 |
| `redis/` | Redis 操作封装（RedisTemplate） | ❌ 禁止放 Spring 配置类 |
| `config/` | Spring 配置类（线程池、OkHttp 等） | ❌ 禁止放 Redis 操作代码 |

**❌ 严格禁止的错误包名：**
- `persistent/` — **严格禁止！** Repository 实现必须放在 `adapter/repository/`，DAO 必须放在 `dao/`，PO 必须放在 `dao/po/`
- `persistent/repository/` — **严格禁止！** 不存在此结构，应为 `adapter/repository/`
- `persistent/dao/` — **严格禁止！** 不存在此结构，应为 `dao/`
- `persistent/dao/po/` — **严格禁止！** 不存在此结构，应为 `dao/po/`
- `scenario/` — **严格禁止！** DAO 操作必须放在 `dao/`，不能放在其他包
- `config/` 下放 Redis 操作 — **严格禁止！** Redis 操作放 `redis/`

## 目录职责

| 目录 | 职责 | 技术栈 | 说明 |
|------|------|--------|------|
| `adapter/repository/` | Repository 实现 | MySQL + Redis | 实现领域层 IRepository 接口，调用 dao/redis |
| `adapter/port/` | Port 实现 | HTTP + RPC | 实现领域层 IPort 接口，调用 gateway |
| `dao/` | DAO 接口 | MyBatis Mapper | 定义数据库操作方法 |
| `dao/po/` | PO 对象 | 数据库映射 | 与数据库表字段一一对应 |
| `gateway/` | HTTP/RPC 客户端 | OkHttp / Retrofit | 远程服务调用客户端 |
| `gateway/dto/` | 远程调用 DTO | JSON 序列化 | 远程请求/响应数据传输对象 |
| `redis/` | Redis 操作封装 | RedisTemplate | 封装 Redis 读写操作，供 adapter/repository 调用 |
| `config/` | Spring 配置类 | Spring Bean | 线程池、OkHttp、MyBatis 等配置，不放 Redis 操作 |
| `mybatis/mapper/` | Mapper XML | MyBatis XML | SQL 映射配置文件 |

## Redis 包规范

`redis/` 包负责封装 Redis 操作，供 `adapter/repository/` 调用。

```java
package cn.{company}.infrastructure.redis;

import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

import javax.annotation.Resource;
import java.util.concurrent.TimeUnit;

/**
 * Redis 操作服务
 * 
 * 职责：封装 RedisTemplate 操作，提供统一的 Redis 读写接口
 * 调用方：adapter/repository/ 中的 Repository 实现类
 */
@Service
public class RedisService {

    @Resource
    private RedisTemplate<String, Object> redisTemplate;

    /**
     * 设置值（带过期时间）
     */
    public void setValue(String key, Object value, long timeout, TimeUnit unit) {
        redisTemplate.opsForValue().set(key, value, timeout, unit);
    }

    /**
     * 获取值
     */
    public Object getValue(String key) {
        return redisTemplate.opsForValue().get(key);
    }

    /**
     * 删除 key
     */
    public Boolean delete(String key) {
        return redisTemplate.delete(key);
    }

    /**
     * 判断 key 是否存在
     */
    public Boolean hasKey(String key) {
        return redisTemplate.hasKey(key);
    }

    /**
     * 原子自增
     */
    public Long increment(String key, long delta) {
        return redisTemplate.opsForValue().increment(key, delta);
    }

    /**
     * 设置过期时间
     */
    public Boolean expire(String key, long timeout, TimeUnit unit) {
        return redisTemplate.expire(key, timeout, unit);
    }
}
```

**Redis 配置（放在 `app` 模块的 `application.yml` 中）：**

```yaml
spring:
  redis:
    host: ${REDIS_HOST:localhost}
    port: ${REDIS_PORT:6379}
    password: ${REDIS_PASSWORD:}
    database: 0
    lettuce:
      pool:
        max-active: 8
        max-idle: 8
        min-idle: 0
```

**⚠️ 注意**：Redis 的 `RedisTemplate` Bean 配置（序列化等）放在 `config/` 包下，但 Redis 的读写操作封装放在 `redis/` 包下。

## DAO 与 PO

### DAO 接口

```java
package cn.{company}.infrastructure.dao;

import cn.{company}.infrastructure.dao.po.{Xxx}PO;
import org.apache.ibatis.annotations.Mapper;

import java.util.List;

/**
 * {领域}DAO接口
 * 
 * 职责：定义数据库操作方法
 * 实现：MyBatis Mapper XML
 */
@Mapper
public interface I{Xxx}Dao {

    // ==================== 新增 ====================
    
    int insert({Xxx}PO po);

    int batchInsert(List<{Xxx}PO> poList);

    // ==================== 删除 ====================
    
    int deleteById(Long id);

    int deleteByIds(List<Long> ids);

    // ==================== 修改 ====================
    
    int updateById({Xxx}PO po);

    int updateStatus({Xxx}PO po);

    // ==================== 查询 ====================
    
    {Xxx}PO selectById(Long id);

    {Xxx}PO selectByBizId(String bizId);

    List<{Xxx}PO> selectByIds(List<Long> ids);

    List<{Xxx}PO> selectByCondition({Xxx}PO po);

    List<{Xxx}PO> selectPage({Xxx}PO po, int offset, int limit);

    long count({Xxx}PO po);

    boolean existsByBizId(String bizId);
}
```

### PO 对象

```java
package cn.{company}.infrastructure.dao.po;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.io.Serializable;
import java.util.Date;

/**
 * {领域}持久化对象
 * 
 * 职责：与数据库表字段一一对应
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class {Xxx}PO implements Serializable {

    private static final long serialVersionUID = 1L;

    /**
     * 主键ID
     */
    private Long id;
    
    /**
     * 业务ID
     */
    private String bizId;
    
    /**
     * 名称
     */
    private String name;
    
    /**
     * 状态：0-禁用，1-启用
     */
    private Integer status;
    
    /**
     * 创建时间
     */
    private Date createTime;
    
    /**
     * 更新时间
     */
    private Date updateTime;
}
```

### 完整示例

**DAO 接口**：
```java
package cn.bugstack.ai.infrastructure.dao;

import cn.bugstack.ai.infrastructure.dao.po.McpGatewayPO;
import org.apache.ibatis.annotations.Mapper;

import java.util.List;

@Mapper
public interface IMcpGatewayDao {

    int insert(McpGatewayPO po);

    int deleteById(Long id);

    int updateById(McpGatewayPO po);

    McpGatewayPO queryById(Long id);

    List<McpGatewayPO> queryAll();

    McpGatewayPO queryMcpGatewayByGatewayId(String gatewayId);

}
```

**PO 对象**：
```java
package cn.bugstack.ai.infrastructure.dao.po;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.io.Serializable;
import java.util.Date;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class McpGatewayPO implements Serializable {

    private Long id;
    private String gatewayId;
    private String gatewayName;
    private String gatewayDesc;
    private String version;
    private Integer status;
    private Integer auth;
    private Date createTime;
    private Date updateTime;
}
```

## MyBatis Mapper XML

### 存放位置

```
{app-module}/src/main/resources/mybatis/mapper/
├── mcp_gateway_mapper.xml
├── mcp_gateway_tool_mapper.xml
└── ...
```

### 完整示例

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE mapper PUBLIC "-//mybatis.org//DTD Mapper 3.0//EN" "http://mybatis.org/dtd/mybatis-3-mapper.dtd">
<mapper namespace="cn.{company}.infrastructure.dao.I{Xxx}Dao">

    <!-- 结果映射 -->
    <resultMap id="{Xxx}Map" type="cn.{company}.infrastructure.dao.po.{Xxx}PO">
        <id column="id" property="id"/>
        <result column="biz_id" property="bizId"/>
        <result column="name" property="name"/>
        <result column="status" property="status"/>
        <result column="create_time" property="createTime"/>
        <result column="update_time" property="updateTime"/>
    </resultMap>

    <!-- Base Column List -->
    <sql id="Base_Column_List">
        id, biz_id, name, status, create_time, update_time
    </sql>

    <!-- 新增 -->
    <insert id="insert" parameterType="cn.{company}.infrastructure.dao.po.{Xxx}PO" 
            useGeneratedKeys="true" keyProperty="id">
        INSERT INTO {table_name} (biz_id, name, status)
        VALUES (#{bizId}, #{name}, #{status})
    </insert>

    <!-- 批量新增 -->
    <insert id="batchInsert" parameterType="java.util.List">
        INSERT INTO {table_name} (biz_id, name, status)
        VALUES
        <foreach collection="list" item="item" separator=",">
            (#{item.bizId}, #{item.name}, #{item.status})
        </foreach>
    </insert>

    <!-- 删除 -->
    <delete id="deleteById" parameterType="java.lang.Long">
        DELETE FROM {table_name} WHERE id = #{id}
    </delete>

    <!-- 修改 -->
    <update id="updateById" parameterType="cn.{company}.infrastructure.dao.po.{Xxx}PO">
        UPDATE {table_name}
        SET name = #{name},
            status = #{status},
            update_time = NOW()
        WHERE id = #{id}
    </update>

    <!-- 根据ID查询 -->
    <select id="selectById" parameterType="java.lang.Long" resultMap="{Xxx}Map">
        SELECT <include refid="Base_Column_List"/>
        FROM {table_name}
        WHERE id = #{id}
    </select>

    <!-- 根据业务ID查询 -->
    <select id="selectByBizId" parameterType="java.lang.String" resultMap="{Xxx}Map">
        SELECT <include refid="Base_Column_List"/>
        FROM {table_name}
        WHERE biz_id = #{bizId}
    </select>

    <!-- 分页查询 -->
    <select id="selectPage" resultMap="{Xxx}Map">
        SELECT <include refid="Base_Column_List"/>
        FROM {table_name}
        WHERE 1=1
        <if test="status != null">
            AND status = #{status}
        </if>
        ORDER BY id DESC
        LIMIT #{offset}, #{limit}
    </select>

    <!-- 统计数量 -->
    <select id="count" resultType="long">
        SELECT COUNT(*) FROM {table_name}
        WHERE 1=1
        <if test="status != null">
            AND status = #{status}
        </if>
    </select>

</mapper>
```

## Gateway - HTTP/RPC 客户端

### Gateway 接口

```java
package cn.{company}.infrastructure.gateway;

import okhttp3.RequestBody;
import okhttp3.ResponseBody;
import retrofit2.Call;
import retrofit2.http.*;

/**
 * 通用HTTP网关接口
 * 
 * 职责：定义HTTP调用方法
 * 实现：Retrofit + OkHttp
 */
public interface IGenericHttpGateway {

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
```

### Gateway DTO

```java
package cn.{company}.infrastructure.gateway.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.io.Serializable;

/**
 * 远程调用请求DTO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class XxxRequestDTO implements Serializable {

    private static final long serialVersionUID = 1L;

    /**
     * 业务ID
     */
    private String bizId;
    
    /**
     * 请求数据
     */
    private Object data;
}

/**
 * 远程调用响应DTO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class XxxResponseDTO implements Serializable {

    private static final long serialVersionUID = 1L;

    /**
     * 响应码
     */
    private String code;
    
    /**
     * 响应消息
     */
    private String message;
    
    /**
     * 响应数据
     */
    private Object data;
}
```

### Gateway 服务实现

```java
package cn.{company}.infrastructure.gateway;

import cn.{company}.types.enums.ResponseCode;
import cn.{company}.types.exception.AppException;
import com.alibaba.fastjson2.JSON;
import lombok.extern.slf4j.Slf4j;
import okhttp3.*;
import org.springframework.stereotype.Service;

import javax.annotation.Resource;
import java.util.Map;

/**
 * 远程服务网关
 * 
 * 职责：封装HTTP调用逻辑
 */
@Slf4j
@Service
public class XxxGatewayService {

    @Resource
    private OkHttpClient okHttpClient;

    /**
     * 发送POST请求
     */
    public String post(String apiUrl, Object request) throws Exception {
        try {
            // 1. 构建请求体
            MediaType mediaType = MediaType.parse("application/json");
            RequestBody body = RequestBody.create(mediaType, JSON.toJSONString(request));
            
            // 2. 构建请求
            Request request = new Request.Builder()
                    .url(apiUrl)
                    .post(body)
                    .addHeader("content-type", "application/json")
                    .build();

            // 3. 执行调用
            Response response = okHttpClient.newCall(request).execute();

            // 4. 返回结果
            return response.body().string();
            
        } catch (Exception e) {
            log.error("HTTP接口调用异常, url={}", apiUrl, e);
            throw new AppException(ResponseCode.HTTP_EXCEPTION);
        }
    }

    /**
     * 发送GET请求
     */
    public String get(String apiUrl, Map<String, Object> params) throws Exception {
        try {
            // 1. 构建URL参数
            StringBuilder urlBuilder = new StringBuilder(apiUrl);
            if (params != null && !params.isEmpty()) {
                urlBuilder.append("?");
                params.forEach((key, value) -> 
                    urlBuilder.append(key).append("=").append(value).append("&"));
            }
            
            // 2. 构建请求
            Request request = new Request.Builder()
                    .url(urlBuilder.toString())
                    .get()
                    .build();

            // 3. 执行调用
            Response response = okHttpClient.newCall(request).execute();

            // 4. 返回结果
            return response.body().string();
            
        } catch (Exception e) {
            log.error("HTTP接口调用异常, url={}", apiUrl, e);
            throw new AppException(ResponseCode.HTTP_EXCEPTION);
        }
    }
}
```

## 完整示例

### 1. Domain 层定义 Port 接口

```java
// Domain 层
package cn.bugstack.ai.domain.session.adapter.port;

public interface ISessionPort {
    
    /**
     * 调用远程工具
     */
    Object toolCall(Object httpConfig, Object params) throws IOException;
}
```

### 2. Infrastructure 层实现 Port

```java
// Infrastructure 层
package cn.bugstack.ai.infrastructure.adapter.port;

import cn.bugstack.ai.domain.session.adapter.port.ISessionPort;
import cn.bugstack.ai.infrastructure.gateway.GenericHttpGateway;
import okhttp3.RequestBody;
import okhttp3.ResponseBody;
import retrofit2.Call;

@Component
public class SessionPort implements ISessionPort {

    @Resource
    private GenericHttpGateway gateway;

    @Override
    public Object toolCall(Object httpConfig, Object params) throws IOException {
        // 使用 gateway 调用远程服务
        // ...
    }
}
```

### 3. Domain 层定义 Repository 接口

```java
// Domain 层
package cn.bugstack.ai.domain.session.adapter.repository;

public interface ISessionRepository {
    
    McpGatewayConfigVO queryMcpGatewayConfigByGatewayId(String gatewayId);
}
```

### 4. Infrastructure 层实现 Repository

```java
// Infrastructure 层
package cn.bugstack.ai.infrastructure.adapter.repository;

import cn.bugstack.ai.domain.session.adapter.repository.ISessionRepository;
import cn.bugstack.ai.infrastructure.dao.IMcpGatewayDao;
import cn.bugstack.ai.infrastructure.dao.po.McpGatewayPO;

@Repository
public class SessionRepository implements ISessionRepository {

    @Resource
    private IMcpGatewayDao mcpGatewayDao;

    @Override
    public McpGatewayConfigVO queryMcpGatewayConfigByGatewayId(String gatewayId) {
        McpGatewayPO po = mcpGatewayDao.queryMcpGatewayByGatewayId(gatewayId);
        if (po == null) {
            return null;
        }
        return McpGatewayConfigVO.builder()
                .gatewayId(po.getGatewayId())
                .gatewayName(po.getGatewayName())
                .build();
    }
}
```

## 命名规范

| 组件 | 命名格式 | 示例 |
|------|---------|------|
| DAO 接口 | `I{Xxx}Dao` | `IUserDao` |
| PO 类 | `{Xxx}PO` | `UserPO` |
| Repository 实现 | `{Xxx}Repository` | `UserRepository` |
| Port 实现 | `{Xxx}Port` | `ProductPort` |
| Gateway 接口 | `I{Xxx}Gateway` | `IProductGateway` |
| Gateway 实现 | `{Xxx}GatewayService` | `ProductGatewayService` |
| Request DTO | `{Xxx}RequestDTO` | `ProductRequestDTO` |
| Response DTO | `{Xxx}ResponseDTO` | `ProductResponseDTO` |
| Mapper XML | `{table}_mapper.xml` | `user_mapper.xml` |

## 最佳实践

### ✅ 推荐做法

```java
// ✅ PO 只包含数据字段，与数据库表对应
@Data
public class UserPO {
    private Long id;
    private String name;
    private Integer status;
}

// ✅ DAO 接口清晰定义数据库操作，放在 dao/ 包
@Mapper
public interface IUserDao {
    UserPO selectById(Long id);
    int insert(UserPO po);
}

// ✅ Repository 实现放在 adapter/repository/，调用 dao 和 redis
@Repository
public class UserRepository implements IUserRepository {
    @Resource
    private IUserDao userDao;
    @Resource
    private RedisService redisService;
    
    @Override
    public UserEntity queryById(Long id) {
        UserPO po = userDao.selectById(id);
        return convert(po);
    }
}

// ✅ Redis 操作封装放在 redis/ 包
@Service
public class RedisService {
    @Resource
    private RedisTemplate<String, Object> redisTemplate;
    
    public void setValue(String key, Object value, long timeout, TimeUnit unit) {
        redisTemplate.opsForValue().set(key, value, timeout, unit);
    }
}

// ✅ config/ 只放 Spring 配置类（线程池、OkHttp、RedisTemplate Bean 等）
@Configuration
public class RedisConfig {
    @Bean
    public RedisTemplate<String, Object> redisTemplate(RedisConnectionFactory factory) {
        // 配置序列化方式
    }
}
```

### ❌ 避免做法

```java
// ❌ 错误1：在 persistent/ 包下创建 Repository 实现
// 包名：cn.xxx.infrastructure.persistent.repository.UserRepository
// 正确：cn.xxx.infrastructure.adapter.repository.UserRepository

// ❌ 错误2：在 scenario/ 包下写 DAO 操作
// 包名：cn.xxx.infrastructure.scenario.UserScenario（内部调用 DAO）
// 正确：DAO 操作只能放在 dao/ 包，Repository 实现放在 adapter/repository/

// ❌ 错误3：在 config/ 包下写 Redis 读写操作
@Configuration
public class RedisConfig {
    @Resource
    private RedisTemplate<String, Object> redisTemplate;
    
    public void setValue(String key, Object value) {  // ❌ 操作代码不应在 config/
        redisTemplate.opsForValue().set(key, value);
    }
}
// 正确：Redis 操作封装放在 redis/ 包的 RedisService 中

// ❌ 错误4：PO 包含业务逻辑
public class UserPO {
    public boolean isActive() {  // ❌ 应该放在 Domain 层
        return this.status == 1;
    }
}

// ❌ 错误5：Repository 直接操作数据库（绕过 DAO）
@Repository
public class UserRepository implements IUserRepository {
    @Resource
    private JdbcTemplate jdbcTemplate;  // ❌ 应该通过 DAO 接口操作
    
    public UserEntity queryById(Long id) {
        return jdbcTemplate.queryForObject("SELECT * FROM user WHERE id = ?", ...);
    }
}
```

## 与其他层的关系

```
┌─────────────────────────────────────────────────────────────┐
│                      Domain 层                              │
│  - 定义 Repository 接口（IUserRepository）                    │
│  - 定义 Port 接口（IProductPort）                            │
│  - 定义 Domain Service                                      │
│  - 定义 Entity / Aggregate / VO                            │
└─────────────────────────────────────────────────────────────┘
                          ▲
                          │ implements
                          │
┌─────────────────────────────────────────────────────────────┐
│                   Infrastructure 层                         │
│                                                            │
│  adapter/repository/    ← 实现 Repository 接口              │
│      UserRepository       调用 DAO 操作 MySQL/Redis          │
│                                                            │
│  adapter/port/         ← 实现 Port 接口                    │
│      ProductPort         调用 Gateway 访问远程服务            │
│                                                            │
│  dao/                 ← MyBatis DAO 接口                    │
│      IUserDao           对应 Mapper XML                     │
│                                                            │
│  dao/po/              ← PO 对象                           │
│      UserPO             数据库表字段映射                     │
│                                                            │
│  gateway/             ← HTTP/RPC 客户端                     │
│      dto/                请求/响应 DTO                      │
│      XxxGatewayService   远程服务调用实现                    │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                       App 层                                │
│  resources/mybatis/mapper/                                  │
│      user_mapper.xml    ← MyBatis Mapper XML               │
└─────────────────────────────────────────────────────────────┘
```

## 参考项目

- [group-buy-market](file:///Users/fuzhengwei/Documents/project/ddd-demo/group-buy-market) - 完整的基础设施层实现
- [ai-mcp-gateway](file:///Users/fuzhengwei/Documents/project/ddd-demo/ai-mcp-gateway) - Gateway + DTO 示例

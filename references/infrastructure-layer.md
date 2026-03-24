# Infrastructure Layer - 基础设施层

## 概述

基础设施层（Infrastructure Layer）是 DDD 六边形架构的最底层，负责：
1. **实现 Domain 层定义的接口**（Repository、Port）
2. **提供数据持久化能力**（MyBatis DAO + PO）
3. **提供远程服务调用能力**（HTTP Gateway + DTO）

## 整体结构

```
{infrastructure-module}/
├── adapter/                              # 适配器实现
│   ├── port/                             # Port 实现（远程调用）
│   │   └── XxxPort.java
│   └── repository/                       # Repository 实现（本地数据）
│       └── XxxRepository.java
├── dao/                                  # MyBatis DAO 接口
│   ├── po/                               # Persistence Object
│   │   └── XxxPO.java
│   └── IXxxDao.java
├── gateway/                              # HTTP / RPC 客户端
│   ├── dto/                              # 远程调用 DTO
│   │   ├── XxxRequestDTO.java
│   │   └── XxxResponseDTO.java
│   └── XxxGateway.java                   # HTTP 服务客户端
├── redis/                                # Redis 配置
└── config/                               # 配置类

{app-module}/src/main/resources/
└── mybatis/
    └── mapper/                           # Mapper XML 文件
        └── xxx_mapper.xml
```

## 目录职责

| 目录 | 职责 | 技术栈 |
|------|------|--------|
| `adapter/repository/` | Repository 实现 | MySQL + Redis |
| `adapter/port/` | Port 实现 | HTTP + RPC |
| `dao/` | DAO 接口 | MyBatis Mapper |
| `dao/po/` | PO 对象 | 数据库映射 |
| `gateway/` | HTTP/RPC 客户端 | OkHttp / Retrofit |
| `gateway/dto/` | 远程调用 DTO | JSON 序列化 |
| `mybatis/mapper/` | Mapper XML | MyBatis XML |

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

// ✅ DAO 接口清晰定义数据库操作
@Mapper
public interface IUserDao {
    UserPO selectById(Long id);
    int insert(UserPO po);
}

// ✅ Gateway 封装 HTTP 调用
@Service
public class ProductGatewayService {
    public ProductResponseDTO queryProduct(String productId) { }
}
```

### ❌ 避免做法

```java
// ❌ PO 包含业务逻辑
public class UserPO {
    public boolean isActive() {  // ❌ 应该放在 Domain 层
        return this.status == 1;
    }
}

// ❌ DAO 包含业务逻辑
@Mapper
public interface IUserDao {
    public void createUser(UserPO po) {
        // ❌ 这里不应该有业务逻辑
    }
}

// ❌ Gateway 返回内部对象
public class ProductGatewayService {
    public ProductEntity getProduct() {  // ❌ 应该返回 DTO
        return productDao.selectById();
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

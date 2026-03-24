#!/bin/bash

# DDD 项目脚手架生成脚本
# 使用 ddd-scaffold-lite-jdk17 模板创建 DDD 多模块项目

set -e

# 默认值
DEFAULT_GROUP_ID="com.yourcompany"
DEFAULT_ARTIFACT_ID="your-project-name"
DEFAULT_VERSION="1.0.0-SNAPSHOT"
DEFAULT_PACKAGE="com.yourcompany.project"
DEFAULT_ARCHETYPE_VERSION="1.3"

# Maven 仓库
ARCHETYPE_REPOSITORY="https://maven.xiaofuge.cn/"

echo "============================================"
echo "  DDD 项目脚手架生成工具"
echo "============================================"
echo ""

# 交互式询问函数
ask_input() {
    local prompt="$1"
    local default="$2"
    local result_var="$3"
    
    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " input
        eval "$result_var='${input:-$default}'"
    else
        read -p "$prompt: " input
        eval "$result_var='$input'"
    fi
}

# 1. 询问 GroupId
echo "📦 项目配置"
echo "--------------------------------------------"
ask_input "请输入 GroupId（项目包前缀）" "$DEFAULT_GROUP_ID" "GROUP_ID"
echo ""
echo "   用途: Maven 坐标的 groupId，用于标识组织或公司"
echo "   示例: com.yourcompany、cn.bugstack"
echo ""

# 2. 询问 ArtifactId
ask_input "请输入 ArtifactId（项目名称）" "$DEFAULT_ARTIFACT_ID" "ARTIFACT_ID"
echo ""
echo "   用途: 项目模块的唯一标识名称"
echo "   示例: order-system、user-center"
echo ""

# 3. 询问 Version
ask_input "请输入 Version（版本号）" "$DEFAULT_VERSION" "VERSION"
echo ""
echo "   用途: 项目的版本号"
echo "   示例: 1.0.0-SNAPSHOT、2.1.0-RELEASE"
echo ""

# 4. 询问 Package
ask_input "请输入 Package（根包名）" "$DEFAULT_PACKAGE" "PACKAGE"
echo ""
echo "   用途: Java 代码的根包名"
echo "   示例: com.yourcompany.project、cn.bugstack.order"
echo ""

# 5. 询问 Archetype 版本
ask_input "请输入 Archetype 版本" "$DEFAULT_ARCHETYPE_VERSION" "ARCHETYPE_VERSION"
echo ""

echo "============================================"
echo "  确认配置"
echo "============================================"
echo "   GroupId:    $GROUP_ID"
echo "   ArtifactId: $ARTIFACT_ID"
echo "   Version:    $VERSION"
echo "   Package:    $PACKAGE"
echo "   Archetype:  $ARCHETYPE_VERSION"
echo ""
read -p "确认以上配置开始生成？(y/n): " confirm

if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "已取消生成"
    exit 0
fi

# 生成项目
echo ""
echo "============================================"
echo "  开始生成项目..."
echo "============================================"

cd ~

mvn archetype:generate \
    -DarchetypeGroupId=io.github.fuzhengwei \
    -DarchetypeArtifactId=ddd-scaffold-lite-jdk17 \
    -DarchetypeVersion="$ARCHETYPE_VERSION" \
    -DarchetypeRepository="$ARCHETYPE_REPOSITORY" \
    -DgroupId="$GROUP_ID" \
    -DartifactId="$ARTIFACT_ID" \
    -Dversion="$VERSION" \
    -Dpackage="$PACKAGE" \
    -B

echo ""
echo "============================================"
echo "  ✅ 项目生成完成！"
echo "============================================"
echo ""
echo "项目已生成到当前目录: $ARTIFACT_ID"
echo ""
echo "下一步操作:"
echo "   1. cd $ARTIFACT_ID"
echo "   2. mvn clean install -DskipTests"
echo "   3. 导入 IDE 开始开发"
echo ""

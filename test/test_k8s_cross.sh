#!/bin/bash

# k8s_cross插件集成测试脚本

# 设置颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# 当前脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 测试配置
COREDNS_PORT="1053"
HEADSCALE_URL="http://192.168.24.4:8002"
HEADSCALE_TOKEN="Sb49LRo.djRq_TeNwbjfDFubrYBZhzjxdVo65S_X"
TEST_TIMEOUT="30s"

# 日志目录
LOGS_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOGS_DIR"

# 测试结果文件
RESULT_FILE="$LOGS_DIR/integration_test_$(date +%Y%m%d%H%M%S).log"

# PID文件
COREDNS_PID_FILE="$LOGS_DIR/coredns.pid"

# 清理函数
cleanup() {
    echo -e "${YELLOW}清理测试环境...${NC}" | tee -a "$RESULT_FILE"
    
    # 停止CoreDNS
    if [ -f "$COREDNS_PID_FILE" ]; then
        COREDNS_PID=$(cat "$COREDNS_PID_FILE")
        if kill -0 "$COREDNS_PID" 2>/dev/null; then
            echo "停止CoreDNS (PID: $COREDNS_PID)" | tee -a "$RESULT_FILE"
            kill "$COREDNS_PID"
            sleep 2
            # 如果进程还在，强制终止
            if kill -0 "$COREDNS_PID" 2>/dev/null; then
                kill -9 "$COREDNS_PID"
            fi
        fi
        rm -f "$COREDNS_PID_FILE"
    fi
    
    echo -e "${GREEN}清理完成${NC}" | tee -a "$RESULT_FILE"
}

# 设置退出时清理
trap cleanup EXIT

# 检查依赖
check_dependencies() {
    echo -e "${YELLOW}检查依赖...${NC}" | tee -a "$RESULT_FILE"
    
    # 检查dig
    if ! command -v dig &> /dev/null; then
        echo -e "${RED}错误: 需要安装dig工具${NC}" | tee -a "$RESULT_FILE"
        exit 1
    fi
    
    # 检查CoreDNS二进制文件
    if [ ! -f "$PROJECT_ROOT/coredns/coredns" ]; then
        echo -e "${RED}错误: CoreDNS二进制文件不存在${NC}" | tee -a "$RESULT_FILE"
        exit 1
    fi
    
    echo -e "${GREEN}依赖检查通过${NC}" | tee -a "$RESULT_FILE"
}

# 检查Headscale连接
check_headscale() {
    echo -e "${YELLOW}检查Headscale连接...${NC}" | tee -a "$RESULT_FILE"
    
    # 测试Headscale API连接
    if curl -s -H "Authorization: Bearer $HEADSCALE_TOKEN" "$HEADSCALE_URL/api/v1/health" > /dev/null; then
        echo -e "${GREEN}Headscale连接正常${NC}" | tee -a "$RESULT_FILE"
        
        # 获取节点列表
        echo "获取Headscale节点列表:" | tee -a "$RESULT_FILE"
        curl -s -H "Authorization: Bearer $HEADSCALE_TOKEN" "$HEADSCALE_URL/api/v1/node" | tee -a "$RESULT_FILE"
        echo "" | tee -a "$RESULT_FILE"
        
        return 0
    else
        echo -e "${RED}无法连接到Headscale服务器${NC}" | tee -a "$RESULT_FILE"
        return 1
    fi
}

# 启动CoreDNS
start_coredns() {
    echo -e "${YELLOW}启动CoreDNS...${NC}" | tee -a "$RESULT_FILE"
    
    # 启动CoreDNS
    cd "$PROJECT_ROOT"
    timeout $TEST_TIMEOUT ./coredns/coredns -conf "$SCRIPT_DIR/coredns-test.conf" -dns.port "$COREDNS_PORT" > "$LOGS_DIR/coredns.log" 2>&1 &
    COREDNS_PID=$!
    echo $COREDNS_PID > "$COREDNS_PID_FILE"
    
    # 等待CoreDNS启动
    echo "等待CoreDNS启动..." | tee -a "$RESULT_FILE"
    sleep 5
    
    # 检查CoreDNS是否启动成功
    if kill -0 "$COREDNS_PID" 2>/dev/null; then
        echo -e "${GREEN}CoreDNS启动成功 (PID: $COREDNS_PID)${NC}" | tee -a "$RESULT_FILE"
        return 0
    else
        echo -e "${RED}CoreDNS启动失败${NC}" | tee -a "$RESULT_FILE"
        echo "CoreDNS日志:" | tee -a "$RESULT_FILE"
        tail -20 "$LOGS_DIR/coredns.log" | tee -a "$RESULT_FILE"
        return 1
    fi
}

# 执行DNS查询测试
run_dns_tests() {
    echo -e "${YELLOW}执行DNS查询测试...${NC}" | tee -a "$RESULT_FILE"
    
    # 设置CoreDNS服务器地址和端口
    COREDNS_SERVER="127.0.0.1"
    
    # 函数：执行DNS查询并记录结果
    run_dns_query() {
        local query_type=$1
        local query_domain=$2
        local description=$3
        
        echo "======================" | tee -a "$RESULT_FILE"
        echo "测试: $description" | tee -a "$RESULT_FILE"
        echo "查询类型: $query_type" | tee -a "$RESULT_FILE"
        echo "查询域名: $query_domain" | tee -a "$RESULT_FILE"
        echo "时间: $(date)" | tee -a "$RESULT_FILE"
        echo "======================" | tee -a "$RESULT_FILE"
        
        # 执行查询
        dig @"$COREDNS_SERVER" -p "$COREDNS_PORT" "$query_domain" "$query_type" +short +noall +answer | tee -a "$RESULT_FILE"
        
        echo "" | tee -a "$RESULT_FILE"
    }
    
    # 函数：验证特定查询类型的结果
    validate_query_result() {
        local query_type=$1
        local query_domain=$2
        local expected_pattern=$3
        local description=$4
        
        echo "验证: $description" | tee -a "$RESULT_FILE"
        
        # 执行查询并捕获结果
        result=$(dig @"$COREDNS_SERVER" -p "$COREDNS_PORT" "$query_domain" "$query_type" +short +noall +answer)
        
        # 检查结果是否符合预期
        if echo "$result" | grep -q "$expected_pattern"; then
            echo "✅ 通过: 结果符合预期模式 '$expected_pattern'" | tee -a "$RESULT_FILE"
            return 0
        else
            echo "❌ 失败: 结果不符合预期模式 '$expected_pattern'" | tee -a "$RESULT_FILE"
            echo "实际结果: $result" | tee -a "$RESULT_FILE"
            return 1
        fi
    }
    
    # 函数：测试不存在服务的查询
    test_nonexistent_service() {
        echo "测试不存在的服务查询" | tee -a "$RESULT_FILE"
        
        # 执行查询
        result=$(dig @"$COREDNS_SERVER" -p "$COREDNS_PORT" "nonexistent-service.default.svc.clusterset.local" A +short +noall +answer)
        
        # 检查结果是否为空（NXDOMAIN）
        if [ -z "$result" ]; then
            echo "✅ 通过: 不存在的服务返回空结果（NXDOMAIN）" | tee -a "$RESULT_FILE"
            return 0
        else
            echo "❌ 失败: 不存在的服务应返回空结果，但得到: $result" | tee -a "$RESULT_FILE"
            return 1
        fi
    }
    
    # 函数：测试非clusterset.local域的查询
    test_non_clusterset_domain() {
        echo "测试非clusterset.local域的查询" | tee -a "$RESULT_FILE"
        
        # 执行查询
        result=$(dig @"$COREDNS_SERVER" -p "$COREDNS_PORT" "google.com" A +short +noall +answer)
        
        # 检查结果是否不为空（应转发到上游DNS）
        if [ -n "$result" ]; then
            echo "✅ 通过: 非clusterset.local域的查询正确转发到上游DNS" | tee -a "$RESULT_FILE"
            return 0
        else
            echo "❌ 失败: 非clusterset.local域的查询应返回结果" | tee -a "$RESULT_FILE"
            return 1
        fi
    }
    
    # 等待CoreDNS完全启动
    echo "等待CoreDNS完全启动..." | tee -a "$RESULT_FILE"
    sleep 5
    
    # 测试A记录查询
    echo "执行A记录查询测试" | tee -a "$RESULT_FILE"
    run_dns_query "A" "web-service.default.svc.clusterset.local" "web-service A记录查询"
    run_dns_query "A" "api-service.production.svc.clusterset.local" "api-service A记录查询"
    
    # 测试AAAA记录查询
    echo "执行AAAA记录查询测试" | tee -a "$RESULT_FILE"
    run_dns_query "AAAA" "web-service.default.svc.clusterset.local" "web-service AAAA记录查询"
    run_dns_query "AAAA" "api-service.production.svc.clusterset.local" "api-service AAAA记录查询"
    
    # 测试SRV记录查询
    echo "执行SRV记录查询测试" | tee -a "$RESULT_FILE"
    run_dns_query "SRV" "_http._tcp.web-service.default.svc.clusterset.local" "web-service SRV记录查询"
    run_dns_query "SRV" "_http._tcp.api-service.production.svc.clusterset.local" "api-service SRV记录查询"
    
    # 测试TXT记录查询
    echo "执行TXT记录查询测试" | tee -a "$RESULT_FILE"
    run_dns_query "TXT" "web-service.default.svc.clusterset.local" "web-service TXT记录查询"
    run_dns_query "TXT" "api-service.production.svc.clusterset.local" "api-service TXT记录查询"
    
    # 验证特定查询结果
    echo "验证查询结果" | tee -a "$RESULT_FILE"
    validate_query_result "A" "web-service.default.svc.clusterset.local" "10.0.0.1" "web-service应返回IP 10.0.0.1"
    validate_query_result "A" "api-service.production.svc.clusterset.local" "10.0.0.2" "api-service应返回IP 10.0.0.2"
    
    # 测试不存在服务
    test_nonexistent_service
    
    # 测试非clusterset.local域
    test_non_clusterset_domain
    
    echo -e "${GREEN}DNS查询测试完成${NC}" | tee -a "$RESULT_FILE"
    return 0
}

# 显示日志
show_logs() {
    echo -e "${YELLOW}=== CoreDNS日志 ===${NC}" | tee -a "$RESULT_FILE"
    tail -20 "$LOGS_DIR/coredns.log" | tee -a "$RESULT_FILE"
}

# 主函数
main() {
    echo -e "${GREEN}开始k8s_cross插件集成测试${NC}" | tee "$RESULT_FILE"
    echo "测试时间: $(date)" | tee -a "$RESULT_FILE"
    echo "Headscale服务器: $HEADSCALE_URL" | tee -a "$RESULT_FILE"
    echo "测试日志: $RESULT_FILE" | tee -a "$RESULT_FILE"
    
    # 检查依赖
    check_dependencies || exit 1
    
    # 检查Headscale连接
    check_headscale || exit 1
    
    # 启动CoreDNS
    start_coredns || exit 1
    
    # 执行DNS测试
    run_dns_tests || exit 1
    
    # 显示日志
    show_logs
    
    echo -e "${GREEN}集成测试完成${NC}" | tee -a "$RESULT_FILE"
    echo "完整测试日志: $RESULT_FILE"
}

# 执行主函数
main
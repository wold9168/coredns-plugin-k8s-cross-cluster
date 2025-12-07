#!/bin/bash

# DNS查询测试脚本

# 设置CoreDNS服务器地址和端口
COREDNS_SERVER="127.0.0.1"
COREDNS_PORT="8053"

# 结果目录
RESULTS_DIR="../logs"
mkdir -p "$RESULTS_DIR"

# 测试结果文件
RESULT_FILE="$RESULTS_DIR/dns_test_results_$(date +%Y%m%d%H%M%S).log"

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

# 主测试函数
main() {
    echo "开始k8s_cross插件DNS查询测试" | tee "$RESULT_FILE"
    echo "CoreDNS服务器: $COREDNS_SERVER:$COREDNS_PORT" | tee -a "$RESULT_FILE"
    echo "测试时间: $(date)" | tee -a "$RESULT_FILE"
    
    # 等待CoreDNS启动
    echo "等待CoreDNS服务器启动..." | tee -a "$RESULT_FILE"
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
    
    echo "DNS查询测试完成。结果已保存到: $RESULT_FILE"
}

# 执行主函数
main
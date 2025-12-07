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
COREDNS_PORT="8053"
HEADSCALE_PORT="8002"
TEST_TIMEOUT="30s"

# 日志目录
LOGS_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOGS_DIR"

# 测试结果文件
RESULT_FILE="$LOGS_DIR/integration_test_$(date +%Y%m%d%H%M%S).log"

# PID文件
HEADSCALE_PID_FILE="$LOGS_DIR/headscale.pid"
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
    
    # 停止Headscale模拟器
    if [ -f "$HEADSCALE_PID_FILE" ]; then
        HEADSCALE_PID=$(cat "$HEADSCALE_PID_FILE")
        if kill -0 "$HEADSCALE_PID" 2>/dev/null; then
            echo "停止Headscale模拟器 (PID: $HEADSCALE_PID)" | tee -a "$RESULT_FILE"
            kill "$HEADSCALE_PID"
            sleep 2
            # 如果进程还在，强制终止
            if kill -0 "$HEADSCALE_PID" 2>/dev/null; then
                kill -9 "$HEADSCALE_PID"
            fi
        fi
        rm -f "$HEADSCALE_PID_FILE"
    fi
    
    echo -e "${GREEN}清理完成${NC}" | tee -a "$RESULT_FILE"
}

# 设置退出时清理
trap cleanup EXIT

# 检查依赖
check_dependencies() {
    echo -e "${YELLOW}检查依赖...${NC}" | tee -a "$RESULT_FILE"
    
    # 检查Go
    if ! command -v go &> /dev/null; then
        echo -e "${RED}错误: 需要安装Go${NC}" | tee -a "$RESULT_FILE"
        exit 1
    fi
    
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

# 启动Headscale模拟器
start_headscale_mock() {
    echo -e "${YELLOW}启动Headscale模拟器...${NC}" | tee -a "$RESULT_FILE"
    
    cd "$SCRIPT_DIR/headscale-mock"
    go build -o headscale-mock server.go
    
    # 启动模拟器
    ./headscale-mock > "$LOGS_DIR/headscale.log" 2>&1 &
    HEADSCALE_PID=$!
    echo $HEADSCALE_PID > "$HEADSCALE_PID_FILE"
    
    # 等待服务器启动
    echo "等待Headscale模拟器启动..." | tee -a "$RESULT_FILE"
    sleep 3
    
    # 检查服务器是否启动成功
    if kill -0 "$HEADSCALE_PID" 2>/dev/null; then
        # 检查健康状态
        if curl -s "http://localhost:$HEADSCALE_PORT/api/v1/health" > /dev/null; then
            echo -e "${GREEN}Headscale模拟器启动成功 (PID: $HEADSCALE_PID)${NC}" | tee -a "$RESULT_FILE"
        else
            echo -e "${RED}Headscale模拟器启动失败${NC}" | tee -a "$RESULT_FILE"
            exit 1
        fi
    else
        echo -e "${RED}Headscale模拟器启动失败${NC}" | tee -a "$RESULT_FILE"
        exit 1
    fi
}

# 启动CoreDNS
start_coredns() {
    echo -e "${YELLOW}启动CoreDNS...${NC}" | tee -a "$RESULT_FILE"
    
    # 启动CoreDNS
    cd "$PROJECT_ROOT"
    timeout $TEST_TIMEOUT ./coredns/coredns -conf "$SCRIPT_DIR/coredns-test.conf" -dns.port=":$COREDNS_PORT" > "$LOGS_DIR/coredns.log" 2>&1 &
    COREDNS_PID=$!
    echo $COREDNS_PID > "$COREDNS_PID_FILE"
    
    # 等待CoreDNS启动
    echo "等待CoreDNS启动..." | tee -a "$RESULT_FILE"
    sleep 5
    
    # 检查CoreDNS是否启动成功
    if kill -0 "$COREDNS_PID" 2>/dev/null; then
        echo -e "${GREEN}CoreDNS启动成功 (PID: $COREDNS_PID)${NC}" | tee -a "$RESULT_FILE"
    else
        echo -e "${RED}CoreDNS启动失败${NC}" | tee -a "$RESULT_FILE"
        echo "CoreDNS日志:" | tee -a "$RESULT_FILE"
        tail -20 "$LOGS_DIR/coredns.log" | tee -a "$RESULT_FILE"
        exit 1
    fi
}

# 执行DNS查询测试
run_dns_tests() {
    echo -e "${YELLOW}执行DNS查询测试...${NC}" | tee -a "$RESULT_FILE"
    
    # 使测试脚本可执行
    chmod +x "$SCRIPT_DIR/dns-queries/test_queries.sh"
    
    # 执行测试
    cd "$SCRIPT_DIR/dns-queries"
    ./test_queries.sh
    
    # 检查测试结果
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}DNS查询测试通过${NC}" | tee -a "$RESULT_FILE"
    else
        echo -e "${RED}DNS查询测试失败${NC}" | tee -a "$RESULT_FILE"
    fi
}

# 显示日志
show_logs() {
    echo -e "${YELLOW}=== CoreDNS日志 ===${NC}" | tee -a "$RESULT_FILE"
    tail -20 "$LOGS_DIR/coredns.log" | tee -a "$RESULT_FILE"
    
    echo -e "${YELLOW}=== Headscale模拟器日志 ===${NC}" | tee -a "$RESULT_FILE"
    tail -20 "$LOGS_DIR/headscale.log" | tee -a "$RESULT_FILE"
}

# 主函数
main() {
    echo -e "${GREEN}开始k8s_cross插件集成测试${NC}" | tee "$RESULT_FILE"
    echo "测试时间: $(date)" | tee -a "$RESULT_FILE"
    echo "测试日志: $RESULT_FILE" | tee -a "$RESULT_FILE"
    
    # 检查依赖
    check_dependencies
    
    # 启动Headscale模拟器
    start_headscale_mock
    
    # 启动CoreDNS
    start_coredns
    
    # 执行DNS测试
    run_dns_tests
    
    # 显示日志
    show_logs
    
    echo -e "${GREEN}集成测试完成${NC}" | tee -a "$RESULT_FILE"
    echo "完整测试日志: $RESULT_FILE"
}

# 执行主函数
main
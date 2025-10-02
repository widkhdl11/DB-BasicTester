#!/bin/bash

# LOG 레벨별 출력 함수
log_message(){
    local level="$1"    # DEBUG, INFO, WARN, ERROR
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
# 색상 코드
    local color=""
    case "$level" in
        "DEBUG") color="\033[36m" ;;  # 청색
        "INFO")  color="\033[32m" ;;  # 녹색  
        "WARN")  color="\033[33m" ;;  # 노란색
        "ERROR") color="\033[31m" ;;  # 빨간색
    esac
    
    echo -e "${color}[$timestamp] [$level] $message\033[0m" | tee -a "$LOG_FILE"
}

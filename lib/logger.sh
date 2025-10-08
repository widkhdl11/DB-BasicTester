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
    
    echo -e "${color}[$timestamp] [$level] $message\033[0m"
    echo -e "[$timestamp] [$level] $message" | tee -a "$LOG_FILE" >/dev/null 
}



# json 파일 생성 함수
write_json_log_file() {
    
    local session_start="$1"
    local session_end=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "JSON 로그 파일 생성 중..." > "$JSON_LOG_FILE"
   {
        echo "{"
        echo "  \"session_info\": {"
        echo "    \"start_time\": \"$session_start\","
        echo "    \"end_time\": \"$session_end\","
        echo "    \"total_tests\": $total_tests,"
        echo "    \"passed_tests\": $passed_tests,"
        echo "    \"failed_tests\": $failed_tests"
        echo "  },"
        echo "  \"test_results\": ["
        
        for i in "${!json_logs[@]}"; do
            echo -n "    ${json_logs[i]}"
            # 마지막 요소가 아니면 쉼표 추가
            if [ $i -lt $((${#json_logs[@]} - 1)) ]; then
                echo ","
            else
                echo "" 
            fi
        done
       
        echo "  ]"
        
        echo "}"
    } > "$JSON_LOG_FILE"
    if command -v jq >/dev/null 2>&1; then
        jq '.' "$JSON_LOG_FILE" > "${JSON_LOG_FILE}.tmp" && mv "${JSON_LOG_FILE}.tmp" "$JSON_LOG_FILE"
    fi
}


# 테스트 결과 기록 함수
log_test_result() {
    local test_name="$1"
    local result="$2"
    local execution_time="$3"
    local additional_json="$4"
    local error_message="$5"
    local status=""
    
    ((total_tests++))
    
    if [ $result -eq 0 ]; then
        ((passed_tests++))
        status="PASS"
        echo "[$total_tests/?] $test_name ✅ PASS" | tee -a "$LOG_FILE"
        log_message "INFO" "테스트 성공: $test_name"

    else
        ((failed_tests++))
        status="FAIL"
        echo "[$total_tests/?] $test_name ❌ FAIL - $error_message" | tee -a "$LOG_FILE"
        log_message "ERROR" "테스트 실패: $test_name - $error_message"

    fi
    echo | tee -a "$LOG_FILE"
    create_json_log_entry "$test_name" "$status" "$execution_time" "$additional_json" "$error_message"
}

# Json(TestResult) 파일에 넣을 테스트 결과 json 생성
create_json_log_entry(){
    local test_name="$1"
    local status="$2"
    local execution_time="$3"
    local additional_json="$4"
    local error_message="$5"

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    local details_part=""
    [ -n "$additional_json" ] && details_part="\"details\":$additional_json,"

    local json_entry="{
      \"timestamp\": \"$timestamp\",
      \"test_name\": \"$test_name\",
      \"status\": \"$status\",
      \"execution_time\": \"${execution_time}s\",
      "$details_part"
      \"error_message\": $([ -n "$error_message" ] && echo "\"$error_message\"" || echo "null")
    }"

    json_logs+=("$json_entry") 

}


# 결과 csv 리포트 생성
write_csv_report() {
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # CSV 헤더 생성 (파일이 없을 때만)
    if [ ! -f "$CSV_REPORT_FILE" ]; then
        echo "timestamp,session_id,total_tests,passed_tests,failed_tests,success_rate" > "$CSV_REPORT_FILE"
    fi
    
    local session_id=$(date '+%Y%m%d_%H%M%S')
    
    # 성공률
    local success_rate=0
    if [ $total_tests -gt 0 ]; then
        success_rate=$((passed_tests * 100 / total_tests))
    fi
    
    echo "$timestamp,$session_id,$total_tests,$passed_tests,$failed_tests,$success_rate" >> $CSV_REPORT_FILE
    
}

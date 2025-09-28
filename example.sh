#!/bin/bash

# ==========================================
# DB-HealthMate Phase 2A - 로그 관리 고도화
# CUBRID QA 플랫폼 개발자 포트폴리오
# ==========================================

# 설정 변수들
DB_DIR="db"
LOG_DIR="logs"
REPORT_DIR="reports"

# 디렉토리 생성
for dir in "$DB_DIR" "$LOG_DIR" "$REPORT_DIR"; do
    [ ! -d "$dir" ] && mkdir -p "$dir"
done

DB_FILE="$DB_DIR/test_database.db"
LOG_FILE="$LOG_DIR/db_test_results.txt"
JSON_LOG_FILE="$LOG_DIR/db_test_results.json"
CSV_REPORT_FILE="$REPORT_DIR/test_history.csv"
TEST_TABLE="users"

# 테스트 카운터
total_tests=0
passed_tests=0
failed_tests=0

# 전역 변수 (JSON 로그용)
declare -a json_logs=()

# ==========================================
# 고도화된 로깅 시스템
# ==========================================

# 실행 시간 측정 시작
start_timer() {
    test_start_time=$(date +%s.%N)
}

# 실행 시간 측정 종료 및 반환
end_timer() {
    local end_time=$(date +%s.%N)
    local execution_time=$(echo "$end_time - $test_start_time" | bc -l 2>/dev/null || echo "0.000")
    printf "%.3f" "$execution_time"
}

# 로그 레벨별 출력 함수
log_message() {
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

# JSON 로그 엔트리 생성
create_json_log_entry() {
    local test_name="$1"
    local status="$2"
    local execution_time="$3"
    local details="$4"
    local error_message="$5"
    
    # TODO: JSON 형태로 로그 엔트리 생성
    # 힌트: 다음과 같은 구조로 만들어야 함
    # {
    #   "timestamp": "2024-01-15 10:30:25",
    #   "test_name": "INSERT 테스트",
    #   "status": "PASS" 또는 "FAIL", 
    #   "execution_time": "0.023s",
    #   "details": {
    #     "rows_affected": 3,
    #     "sql_command": "INSERT INTO...",
    #     "additional_info": "추가 정보"
    #   },
    #   "error_message": null 또는 "에러 메시지"
    # }
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # TODO: 여기서 JSON 문자열을 구성하세요
    # json_entry 변수에 완성된 JSON 문자열을 저장
    local json_entry=""
    
    # json_logs 배열에 추가
    json_logs+=("$json_entry")
}

# 향상된 테스트 결과 기록 함수
log_test_result() {
    local test_name="$1"
    local result="$2"
    local message="$3"
    local execution_time="$4"
    local additional_details="$5"
    
    ((total_tests++))
    
    if [ "$result" -eq 0 ]; then
        ((passed_tests++))
        echo "[$total_tests/5] $test_name ✅ PASS (${execution_time}s)" | tee -a "$LOG_FILE"
        log_message "INFO" "테스트 성공: $test_name"
        
        # JSON 로그 생성
        create_json_log_entry "$test_name" "PASS" "${execution_time}s" "$additional_details" ""
        
    else
        ((failed_tests++))
        echo "[$total_tests/5] $test_name ❌ FAIL - $message (${execution_time}s)" | tee -a "$LOG_FILE"
        log_message "ERROR" "테스트 실패: $test_name - $message"
        
        # JSON 로그 생성
        create_json_log_entry "$test_name" "FAIL" "${execution_time}s" "$additional_details" "$message"
    fi
}

# ==========================================
# JSON 로그 파일 출력 함수
# ==========================================

write_json_log_file() {
    # TODO: JSON 배열 형태로 로그 파일 생성
    # 힌트: 다음과 같은 구조로 작성해야 함
    # {
    #   "test_session": {
    #     "start_time": "2024-01-15 10:30:00",
    #     "end_time": "2024-01-15 10:32:15", 
    #     "total_tests": 5,
    #     "passed_tests": 4,
    #     "failed_tests": 1,
    #     "success_rate": "80%"
    #   },
    #   "test_results": [
    #     { 각각의 테스트 결과들... }
    #   ]
    # }
    
    local session_start="$1"
    local session_end=$(date '+%Y-%m-%d %H:%M:%S')
    
    # TODO: 전체 JSON 구조 생성
    echo "JSON 로그 파일 생성 중..." > "$JSON_LOG_FILE"
    
    # 임시로 기본 구조만 생성 (TODO에서 완성하세요)
    echo "{" > "$JSON_LOG_FILE"
    echo "  \"session_info\": {" >> "$JSON_LOG_FILE"
    echo "    \"start_time\": \"$session_start\"," >> "$JSON_LOG_FILE"
    echo "    \"end_time\": \"$session_end\"," >> "$JSON_LOG_FILE"  
    echo "    \"total_tests\": $total_tests," >> "$JSON_LOG_FILE"
    echo "    \"passed_tests\": $passed_tests," >> "$JSON_LOG_FILE"
    echo "    \"failed_tests\": $failed_tests" >> "$JSON_LOG_FILE"
    echo "  }," >> "$JSON_LOG_FILE"
    echo "  \"test_results\": [" >> "$"
    echo "    {}  # TODO: 실제 테스트 결과들로 채워야 함" >> "$JSON_LOG_FILE"
    echo "  ]" >> "$JSON_LOG_FILE"
    echo "}" >> "$JSON_LOG_FILE"
}

# ==========================================
# CSV 리포트 생성 함수  
# ==========================================

write_csv_report() {
    # TODO: CSV 형태로 테스트 히스토리 저장
    # 힌트: 다음과 같은 형태로 저장해야 함
    # timestamp,test_name,status,execution_time,error_message
    # 2024-01-15 10:30:25,INSERT 테스트,PASS,0.023,
    # 2024-01-15 10:30:28,SELECT 테스트,FAILJSON_LOG_FILE,0.015,COUNT 불일치
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # CSV 헤더 생성 (파일이 없을 때만)
    if [ ! -f "$CSV_REPORT_FILE" ]; then
        echo "timestamp,session_id,total_tests,passed_tests,failed_tests,success_rate" > "$CSV_REPORT_FILE"
    fi
    
    # TODO: CSV 데이터 행 추가
    # 세션 요약 정보를 CSV에 추가하세요
    local session_id=$(date '+%Y%m%d_%H%M%S')
    
    # 성공률 계산
    local success_rate=0
    if [ $total_tests -gt 0 ]; then
        success_rate=$((passed_tests * 100 / total_tests))
    fi
    
    # TODO: CSV 행 추가하는 코드 작성
    # echo 명령어로 CSV 파일에 데이터 추가
}

# ==========================================
# 기존 CRUD 테스트 함수들 (Phase 1에서 가져옴)
# ==========================================

create_test_database() {
    log_message "INFO" "데이터베이스 생성 시작"
    start_timer
    
    table_name="users"
    error_msg=$(sqlite3 "$DB_FILE" << EOF 2>&1
    CREATE TABLE IF NOT EXISTS $table_name(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE
    );
EOF
)
    result=$?
    execution_time=$(end_timer)
    
    log_test_result "테이블 생성 테스트" $result "$error_msg" "$execution_time" "table_name=$table_name"
}

test_insert_data() {
    log_message "INFO" "데이터 삽입 테스트 시작"
    start_timer
    
    table_name="users"
    insert_data=(
        "NULL,'김나경','nakyung_ju@naver.com'"
        "NULL,'박성수','bagazzzzz@gmail.com'"
        "NULL,'홍겸','hnk1194@naver.com'"
        "NULL,'강민석','nakyung_ju@daum.net'"
        "NULL,'강이서','luv_2s@naver.com'"
    )

    result=0
    rows_inserted=0
    
    for row in "${insert_data[@]}"; do
        error_msg=$(sqlite3 "$DB_FILE" "INSERT INTO $table_name(id, name, email) VALUES($row);" 2>&1)
        if [ $? -ne 0 ]; then
            result=1
            break
        else
            ((rows_inserted++))
        fi
    done
    
    execution_time=$(end_timer)
    log_test_result "데이터 삽입 테스트" $result "$error_msg" "$execution_time" "rows_inserted=$rows_inserted"
}

test_select_data() {
    log_message "INFO" "데이터 조회 테스트 시작"
    start_timer
    
    table_name="users"
    expected_value=5
    result_msg=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM $table_name;" 2>&1)
    result=$?

    if [ $result -eq 0 ] && [ "$result_msg" -ne $expected_value ]; then
        result=1
        result_msg="값이 다름(기대값: $expected_value, 실제값: $result_msg)"
    fi
    
    execution_time=$(end_timer)
    log_test_result "데이터 조회 테스트" $result "$result_msg" "$execution_time" "expected=$expected_value,actual=$result_msg"
}

test_update_data() {
    log_message "INFO" "데이터 수정 테스트 시작" 
    start_timer
    
    table_name="users"
    result_msg=$(sqlite3 "$DB_FILE" "UPDATE $table_name SET email='UpdatedEmail@test.com' WHERE id=1;" 2>&1)
    result=$?

    if [ $result -eq 0 ]; then
        check_msg=$(sqlite3 "$DB_FILE" "SELECT email FROM $table_name WHERE id=1;")
        if [ "$check_msg" != "UpdatedEmail@test.com" ]; then
            result=1
            result_msg="UPDATE 후 값 확인 실패"
        fi
    fi
    
    execution_time=$(end_timer) 
    log_test_result "데이터 수정 테스트" $result "$result_msg" "$execution_time" "updated_field=email"
}

test_delete_data() {
    log_message "INFO" "데이터 삭제 테스트 시작"
    start_timer
    
    table_name="users" 
    result_msg=$(sqlite3 "$DB_FILE" "DELETE FROM $table_name WHERE id = 1;" 2>&1)
    result=$?

    if [ $result -eq 0 ]; then
        expected_value=4
        result_cnt=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM $table_name;" 2>&1)
        
        if [ $result_cnt -ne $expected_value ]; then
            result=1
            result_msg="삭제 후 개수 불일치(기대값: $expected_value, 실제값: $result_cnt)"
        fi
    fi
    
    execution_time=$(end_timer)
    log_test_result "데이터 삭제 테스트" $result "$result_msg" "$execution_time" "expected_count=$expected_value"
}

# ==========================================
# 고도화된 테스트 결과 요약 출력
# ==========================================

print_advanced_test_summary() {
    local session_end=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "" | tee -a "$LOG_FILE"
    echo "===========================================" | tee -a "$LOG_FILE"
    echo "=== 고도화된 테스트 결과 요약 ===" | tee -a "$LOG_FILE"
    echo "세션 종료 시간: $session_end" | tee -a "$LOG_FILE"
    echo "총 테스트: $total_tests개" | tee -a "$LOG_FILE"
    echo "성공: $passed_tests개" | tee -a "$LOG_FILE"
    echo "실패: $failed_tests개" | tee -a "$LOG_FILE"
    
    if [ $total_tests -gt 0 ]; then
        success_rate=$((passed_tests * 100 / total_tests))
        echo "성공률: $success_rate%" | tee -a "$LOG_FILE"
    fi
    
    echo "" | tee -a "$LOG_FILE"
    echo "📊 생성된 리포트 파일들:" | tee -a "$LOG_FILE"
    echo "  - 텍스트 로그: $LOG_FILE" | tee -a "$LOG_FILE"
    echo "  - JSON 로그: $JSON_LOG_FILE" | tee -a "$LOG_FILE"  
    echo "  - CSV 리포트: $CSV_REPORT_FILE" | tee -a "$LOG_FILE"
    echo "===========================================" | tee -a "$LOG_FILE"
}

cleanup_test_data() {
    log_message "INFO" "테스트 환경 정리 시작"
    
    if [ -f "$DB_FILE" ]; then
        rm "$DB_FILE"
        if [ $? -eq 0 ]; then
            log_message "INFO" "테스트 DB 파일 삭제 완료"
        else
            log_message "ERROR" "테스트 DB 파일 삭제 실패"
        fi
    fi
}

# ==========================================
# 메인 실행 부분
# ==========================================

main() {
    local session_start=$(date '+%Y-%m-%d %H:%M:%S')
    
    log_message "INFO" "=== DB-HealthMate Phase 2A 테스트 시작 ==="
    log_message "INFO" "세션 시작 시간: $session_start"
    
    # Phase 1 기본 테스트들 실행
    create_test_database
    test_insert_data
    test_select_data
    test_update_data
    test_delete_data
    
    # Phase 2A 고도화 기능들
    write_json_log_file "$session_start"
    write_csv_report
    
    # 결과 요약
    print_advanced_test_summary
    
    # 정리 작업
    cleanup_test_data
    
    log_message "INFO" "=== DB-HealthMate Phase 2A 테스트 완료 ==="
}

# 스크립트 실행
main "$@"
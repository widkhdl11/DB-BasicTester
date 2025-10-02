#!/bin/bash


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


# 실행시간 측정 시작
start_timer(){
    test_start_time=$(date +%s.%N)
}

# 실행시간 측정 종료
end_timer(){
    test_end_timer=$(date +%s.%N)
    execution_time=$(echo "$test_end_timer - $test_start_time" | bc -l)
    printf "%.3f" $execution_time

}

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


# SQL 타입별 details 처리 함수
create_details_by_operation(){
    local operation="$1"
    local table_name="$2"
    # local query="$3"
    shift 2

    local base="\"operation\": \"$operation\", \"table_name\": \"$table_name\""

    case "$operation" in
        "CREATE") echo "$base" ;;
        "INSERT") echo "$base, \"rows_inserted\": $1, \"total_attempted\": $2" ;;
        "SELECT") echo "$base, \"expected_count\": $1, \"actual_count\": $2" ;;
        "UPDATE") echo "$base, \"updated_field\": \"$1\", \"target_id\": $2" ;;
        "DELETE") echo "$base, \"deleted_id\": $1, \"remaining_count\": $2" ;;
        "CONSTRAINT_TEST") echo "$base, \"constraint_type\": \"$1\", \"violation_attempted\": \"$2\", \"error_expected\": true" ;;
        "TYPE_VALIDATION") echo "$base, \"field_name\": \"$1\", \"invalid_type\": \"$2\", \"error_expected\": true" ;;
        "FOREIGN_KEY") echo "$base, \"referenced_table\": \"$1\", \"invalid_reference\": \"$2\"" ;;
        *) echo "$base" ;;
    esac

}


# json 파일 생성 함수
write_json_log_file() {
    
    local session_start="$1"
    local session_end=$(date '+%Y-%m-%d %H:%M:%S')
    
    # TODO: 전체 JSON 구조 생성
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
        
        # 배열 요소들 출력 (쉼표 처리 포함)
        for i in "${!json_logs[@]}"; do
            echo -n "    ${json_logs[i]}"
            # 마지막 요소가 아니면 쉼표 추가
            if [ $i -lt $((${#json_logs[@]} - 1)) ]; then
                echo ","
            else
                echo ""  # 마지막 요소는 쉼표 없음
            fi
        done
       
        echo "  ]"
        
        echo "}"
    } > "$JSON_LOG_FILE"
    if command -v jq >/dev/null 2>&1; then
        jq '.' "$JSON_LOG_FILE" > "${JSON_LOG_FILE}.tmp" && mv "${JSON_LOG_FILE}.tmp" "$JSON_LOG_FILE"
    fi
}
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
    echo "$timestamp,$session_id,$total_tests,$passed_tests,$failed_tests,$success_rate" >> $CSV_REPORT_FILE
    
}

# 테스트 결과 기록 함수
log_test_result() {
    local test_name="$1"
    local result="$2"
    local execution_time="$3"
    local additional_details="$4"
    local error_message="$5"
    
    ((total_tests++))
    
    if [ $result -eq 0 ]; 
    then
        ((passed_tests++))
        echo "[$total_tests/?] $test_name ✅ PASS" | tee -a "$LOG_FILE"
        log_message "INFO" "테스트 성공: $test_name"

        # JSON 로그 생성
        create_json_log_entry "$test_name" "PASS" "$execution_time" "$additional_details" "$error_message"
    else
        ((failed_tests++))
        echo "[$total_tests/?] $test_name ❌ FAIL - $error_message" | tee -a "$LOG_FILE"
        log_message "ERROR" "테스트 실패: $test_name - $error_message"
    fi
}

create_json_log_entry(){
    local test_name="$1"
    local status="$2"
    local execution_time="$3"
    local details="$4"
    local error_message="$5"

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    local json_entry="{
      \"timestamp\": \"$timestamp\",
      \"test_name\": \"$test_name\",
      \"status\": \"$status\",
      \"execution_time\": \"${execution_time}s\",
      \"details\": {
        $details
      },
      \"error_message\": $([ -n "$error_message" ] && echo "\"$error_message\"" || echo "null")
    }"

    # json_logs 배열에 추가
    json_logs+=("$json_entry")  # 괄호와 따옴표 필요

}

setup_test_database() {

    log_message "INFO" "무결성 테스트를 위한 데이터베이스 설정"
    start_timer
    
    local users_query="CREATE TABLE IF NOT EXISTS users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        age INTEGER CHECK(age >= 0 AND age <= 150),
        status TEXT DEFAULT 'active'
    );"

    local orders_query="CREATE TABLE IF NOT EXISTS orders(
        order_id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        product TEXT NOT NULL,
        amount REAL CHECK(amount > 0),
        FOREIGN KEY (user_id) REFERENCES users(id)
    );"

    error_msg=$(sqlite3 "$DB_FILE" "$users_query; $orders_query" 2>&1)
    result=$?

    if [ $result -eq 0 ]; then
        sqlite3 "$DB_FILE" "INSERT INTO users (name, email, age) VALUES 
            ('김테스트', 'test1@test.com', 25),
            ('박테스트', 'test2@test.com', 30);" 2>/dev/null
    fi

    execution_time=$(end_timer)
    details=$(create_details_by_operation "CREATE" "users" "constraints_enabled" "true")
    log_test_result "테스트 데이터베이스 설정" "$result" "$execution_time" "$details" "$error_msg"
    # TODO: log_test_result 호출
}

# ==========================================
# Phase 2B: 무결성 검증 테스트 함수들
# ==========================================

# 1. NOT NULL 제약 조건 테스트
test_not_null_constraints() {
    # TODO: NOT NULL 제약 위반 테스트 구현
    # TODO: name 컬럼에 NULL 삽입 시도 (에러 발생해야 함)
    # TODO: email 컬럼에 NULL 삽입 시도 (에러 발생해야 함)
    # 힌트: INSERT INTO users (email, age) VALUES ('test@test.com', 25);
    # 힌트: 에러가 발생하면 result=0 (테스트 성공), 에러 없으면 result=1 (테스트 실패)
    

    log_message "INFO" "NOT NULL 제약 조건 테스트 시작"
    start_timer

    name_null_query="INSERT INTO users (email, age) VALUES ('test@test', 25)"
    email_null_query="INSERT INTO users (name, age) VALUES ('김가서', 25)"
    
    name_null_error_msg=$(sqlite3 "$DB_FILE" "$name_null_query" 2>&1)
    result1=$?
    email_null_error_msg=$(sqlite3 "$DB_FILE" "$email_null_query" 2>&1)
    result2=$?

    if [ $result1 -ne 0 ] && [ $result2 -ne 0 ]; then
        result=0
        error_msg="NOT NULL 제약조건 위반 감지"
    else
        result=1
        error_msg="NOT NULL 제약조건이 동작하지 않음"
    fi
    
    execution_time=$(end_timer)
    # TODO: details와 log_test_result 호출
    details=$(create_details_by_operation "CONSTRAINT_TEST" "users" "NOT_NULL" "name,email")
    log_test_result "NOT NULL 제약 조건 테스트" "$result" "$execution_time" "$details" "$error_msg"
    
}

# 2. UNIQUE 제약 조건 테스트
test_unique_constraints() {
    
    
    log_message "INFO" "UNIQUE 제약 조건 테스트 시작"
    start_timer

    email_unique_query="INSERT INTO users (name, email, age) VALUES ('홍서진', 'test1@test.com', 32)"
    
    error_msg=$(sqlite3 "$DB_FILE" "$email_unique_query" 2>&1)
    result=$?

     # 에러가 발생해야 성공 (UNIQUE 제약 위반)
    if [ $result -ne 0 ]; then
        result=0  # 테스트 성공
        error_msg="정상적으로 UNIQUE 제약 위반 감지"
    else
        result=1  # 테스트 실패
        error_msg="UNIQUE 제약이 제대로 동작하지 않음"
    fi
    
    execution_time=$(end_timer)
    details=$(create_details_by_operation "CONSTRAINT_TEST" "users" "UNIQUE" "email")
    log_test_result "UNIQUE 제약 조건 테스트" "$result" "$execution_time" "$details" "$error_msg"
}


# 테이블 초기화
setup_transaction_test() {
    log_message "INFO" "트랜잭션 테스트용 테이블 준비 중..."
    
    sqlite3 "$DB_FILE" <<EOF
-- 기존 데이터 정리
DELETE FROM orders;
DELETE FROM users;

-- 테스트용 초기 데이터
INSERT INTO users (name, email, age) VALUES 
    ('Alice', 'alice@test.com', 25),
    ('Bob', 'bob@test.com', 30);
EOF
    
    if [ $? -eq 0 ]; then
        log_message "INFO" "테이블 초기화 완료"
        return 0
    else
        log_message "ERROR" "테이블 초기화 실패"
        return 1
    fi
}


test_transaction_commit() {
    log_message "INFO" "트랜잭션 커밋 테스트 시작"
    
    start_timer

    query="
    BEGIN;
        INSERT INTO users (name, email, age) VALUES ('Charlie', 'charlie@test.com', 28);
        INSERT INTO orders (user_id,product, amount) VALUES (last_insert_rowid(),'Laptop', 999.99);
    COMMIT;
    "

    error_msg=$(sqlite3 "$DB_FILE" "$query" 2>&1)
    result=$?
    
    if  [ $result -eq 0 ]; then
        insert_check=$(sqlite3 "$DB_FILE" "
        SELECT COUNT(*) FROM users u
        JOIN orders o ON u.id = o.user_id
        WHERE u.name='Charlie' 
        AND u.email='charlie@test.com'
        AND u.age=28
        AND o.product='Laptop' 
        AND o.amount=999.99;    
        " 2>&1)
        result=$?

        if [ "$insert_check" -ne 1 ]; then
            result=1
            error_msg="값이 올바르게 삽입되지 않음"
        fi
    fi

    execution_time=$(end_timer)
    log_test_result "트랜젝션 커밋 테스트" "$result" "$execution_time" "$details" "$error_msg"
}

# === UNIQUE 제약조건 위반 자동 롤백 테스트 ==="
test_transaction_rollback() {
    log_message "INFO" "트랜잭션 롤백 테스트 시작"

    start_timer

    query="
    BEGIN;
        INSERT INTO users (name, email, age) VALUES ('eliie','alice@test.com', 30);
        INSERT INTO orders (user_id,product, amount) VALUES (last_insert_rowid(),'Phone', 11.00);
    COMMIT;
    "
    error_msg=$(sqlite3 "$DB_FILE" "$query" 2>&1)
    result=$?
    
    if [ $result -ne 0 ]; then  
  
    users_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM users WHERE name='eliie';")
    orders_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM orders WHERE product='Phone';")
    
        if [ "$users_count" -eq 0 ] && [ "$orders_count" -eq 0 ]; then
            result=0  
            error_msg="자동 롤백 성공"
        else
            result=1 
            error_msg="롤백 실패: users=$users_count, orders=$orders_count"
        fi
    else
        result=1  
        error_msg="예상과 다름: 제약 조건 위반이 발생하지 않음"
    fi
    execution_time=$(end_timer)
    log_test_result "트랜젝션 자동 롤백 테스트" "$result" "$execution_time" "$details" "$error_msg"
}

# 수동 롤백 테스트 함수

test_manual_rollback() {
    log_message "INFO" "수동 롤백 테스트 시작"
    start_timer

    before_users_cnt=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM users;")
    before_orders_cnt=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM orders;")
    
    error_msg=$(sqlite3 "$DB_FILE" << SQL 2>&1
    BEGIN;
        INSERT INTO users (name, email, age) VALUES ('rollbackTest', 'rollback@test.com', 30);
        INSERT INTO orders (user_id,product, amount) VALUES (last_insert_rowid(),'Phone', 11.00);
    ROLLBACK;
SQL
)

    result=$?

    after_users_cnt=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM users;")
    after_orders_cnt=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM orders;")
    
    if [ $result -eq 0 ]; then
        if [ $before_users_cnt -ne $after_users_cnt ] ||  [ $before_orders_cnt -ne $after_orders_cnt ]; then
            result=1
            error_msg="수동 롤백 실패(데이터 수 : 전/후) users=($before_users_cnt/$after_users_cnt), orders=($before_orders_cnt/$after_orders_cnt)"
        fi
    else
        result=1
        error_msg="수동 롤백 실패"
    fi
    
    execution_time=$(end_timer)
    log_test_result "트랜젝션 수동 롤백 테스트" "$result" "$execution_time" "$details" "$error_msg"

}

# 테스트 시작 헤더 출력
print_test_header() {

    echo "===========================================" | tee "$LOG_FILE"
    echo "=== DB-HealthMate 테스트 시작 ===" | tee -a "$LOG_FILE"
    echo "테스트 시간: $(date)" | tee -a "$LOG_FILE"
    echo "===========================================" | tee -a "$LOG_FILE"
    echo ""
}

# 테스트 결과 요약 출력
print_advanced_test_summary() {
    local session_end=$(date '+%Y-%m-%d %H:%M:%S')

    echo "" | tee -a "$LOG_FILE"
    echo "===========================================" | tee -a "$LOG_FILE"
    echo "=== 테스트 결과 요약 ===" | tee -a "$LOG_FILE"
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


# 프로세스 동시성으로 INSERT 문 누락 테스트
test_concurrent_inserts() {
    echo "=== 동시 INSERT 테스트 ==="
    
    sqlite3 "$DB_FILE" "DELETE FROM users WHERE name LIKE 'Concurrent%';"
    
    # 성공/실패 카운터
    success=0
    failed=0
    
    # 3개 프로세스 동시 실행
    for i in {1..3}; do
        sqlite3 "$DB_FILE" "INSERT INTO users (name, email, age) VALUES ('Concurrent$i', 'c$i@test.com', $((25+i)));" &
        pids[$i]=$!
    done
    
    # 각 프로세스 결과 확인
    for i in {1..3}; do
        wait ${pids[$i]}
        result=$?
        if [ $result -eq 0 ]; then
            success=$((success + 1))
        else
            failed=$((failed + 1))
            echo "⚠️  프로세스 $i 실패 (exit code: $result)"
        fi
    done
    
    echo "성공: $success, 실패: $failed"
    
    # 실제 삽입된 레코드 확인
    concurrent_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM users WHERE name LIKE 'Concurrent%';")
    echo "DB에 삽입된 레코드: $concurrent_count"
    
    # 검증: 성공한 개수와 DB 레코드 수가 일치해야 함
    if [ "$concurrent_count" -eq "$success" ]; then
        echo "✅ 동시성 테스트 통과"
        return 0
    else
        echo "❌ 데이터 불일치 발생!"
        return 1
    fi
}

# 데이터베이스 동시성으로 인해 데이터베이스 값 유실 테스트
test_update_conflicts() {
    echo "=== Lost Update 테스트 ==="
    
    # 초기화
    sqlite3 "$DB_FILE" "DELETE FROM users;"
    sqlite3 "$DB_FILE" "INSERT INTO users (name, email, age) VALUES('Test', 'test@test.com', 30);"
    
    update_separated() {
        age=$(sqlite3 "$DB_FILE" "SELECT age FROM users WHERE name='Test';")
        
        new_age=$((age + 1))
        
        sleep 0.1
        sqlite3 "$DB_FILE" "UPDATE users SET age=$new_age WHERE name='Test';"
        return $?
    }
    
    for i in {1..5}; do
        update_separated &
        pids[$i]=$!
    done
    
    # 대기
    success=0
    for i in {1..5}; do
        wait ${pids[$i]}
        [ $? -eq 0 ] && success=$((success + 1))
    done
    
    final_age=$(sqlite3 "$DB_FILE" "SELECT age FROM users WHERE name='Test';")
    
    echo "성공한 프로세스: $success"
    echo "최종 age: $final_age"
    echo "기대 age: $((30 + success))"
    
    if [ "$final_age" -lt "$((30 + success))" ]; then
        echo "🔥 Lost Update 발생!"
        echo "   손실: $((30 + success - final_age))번"
    fi
}

# 1. 데이터베이스 및 테이블 생성 함수
create_test_database() {
    # TODO: SQLite 데이터베이스 파일 생성
    # TODO: users 테이블 생성 (id INTEGER PRIMARY KEY, name TEXT, email TEXT)
    # TODO: 성공/실패에 따라 log_test_result 호출
    log_message "INFO" "데이터베이스 생성 시작"
    start_timer

    table_name="users"
    query="CREATE TABLE IF NOT EXISTS $table_name(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    email TEXT NOT NULL
    );"

    error_msg=$(sqlite3 "$DB_FILE" "$query" 2>&1)
    result=$?

    execution_time=$(end_timer)
    details=$(create_details_by_operation "CREATE" "$table_name" "$query")
    log_test_result "테이블 생성 테스트" "$result" "$execution_time" "$details" "$error_msg"

}

test_deadlock_detection() {
    echo "=== 잠금 타임아웃 테스트 ==="
    
    sqlite3 "$DB_FILE" "DELETE FROM users; DELETE FROM orders;"

    sqlite3 "$DB_FILE" >/dev/null 2>&1 <<EOF &
BEGIN IMMEDIATE;
INSERT INTO users (name, email, age) VALUES ('LongTx', 'long@test.com', 40);

-- 시간 지연용 쿼리
WITH RECURSIVE cnt(x) AS (
    SELECT 1
    UNION ALL
    SELECT x+1 FROM cnt
    LIMIT 5000000
)
SELECT COUNT(*) FROM cnt;

COMMIT;
EOF
    pid1=$!
    
    echo "긴 트랜잭션 시작 (PID: $pid1)"
    sleep 0.1
    # 여기에 코드 작성
    sqlite3 "$DB_FILE" >/dev/null 2>&1 <<EOF &
.timeout 100
BEGIN IMMEDIATE;
INSERT INTO users (name, email, age) VALUES ('ShortTx', 'short@test.com', 25);
COMMIT;
EOF
    pid2=$!
    
    
    echo "짧은 트랜잭션 시작 (PID: $pid2)"
    
    wait $pid1
    result1=$?
    wait $pid2
    result2=$?
    
    
    echo "프로세스 1 (긴 트랜잭션): exit code $result1"
    echo "프로세스 2 (짧은 트랜잭션): exit code $result2"
    
    
    has_long=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM users WHERE name='LongTx';" 2>&1)
    has_short=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM users WHERE name='ShortTx';" 2>&1)
    
    echo "DB에 저장된 레코드: LongTx=$has_long, ShortTx=$has_short"
    
    # 검증
    if [ $result1 -eq 0 ] && [ $result2 -ne 0 ]; then
        if [ $has_long -eq 1 ] && [ $has_short -eq 0 ]; then
            echo "✅ 테스트 성공: 타임아웃으로 충돌 방지됨"
            return 0
        fi
    fi
    
    echo "❌ 테스트 실패: 예상과 다른 결과"
    return 1
}

# 2. INSERT 테스트 함수
test_insert_data() {
    # TODO: 테스트용 사용자 데이터 3개 INSERT
    # TODO: 각 INSERT 후 성공 여부 확인
    # TODO: 결과를 log_test_result로 기록
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

    rows_inserted=0
    for row in "${insert_data[@]}"; do
        query="INSERT INTO $table_name(id, name, email) VALUES($row);"
        error_msg=$(sqlite3 "$DB_FILE" "$query" 2>&1)
        result=$?
        
        if [ $result -eq 0 ]; 
        then
            (( rows_inserted++ ))
        fi
    done
    execution_time=$(end_timer)
    total_attempted=${#insert_data[@]}
    details=$(create_details_by_operation "INSERT" "$table_name" "$rows_inserted" "$total_attempted")
    log_test_result "데이터 삽입 테스트" "$result" "$execution_time" "$details" "$error_msg"

    
    
    # 힌트: INSERT INTO users (name, email) VALUES ('이름', '이메일');
}

# 3. SELECT 테스트 함수  
test_select_data() {
    # TODO: 삽입된 데이터 조회
    # TODO: 예상되는 개수(3개)와 실제 조회 개수 비교
    # TODO: 결과를 log_test_result로 기록
    log_message "INFO" "데이터 조회 테스트 시작"
    start_timer
    table_name="users"

    expected_cnt=5
    actual_cnt=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM $table_name;" 2>&1)
    result=$?

    if [ $actual_cnt -ne $expected_cnt ];
    then
        result=1
        error_msg="값이 다름"
    fi


    execution_time=$(end_timer)

    details=$(create_details_by_operation "SELECT" "$table_name" "$actual_cnt" "$expected_cnt")
    log_test_result "데이터 조회 테스트" "$result" "$execution_time" "$details" "$error_msg"

}

# 4. UPDATE 테스트 함수
test_update_data() {

    log_message "INFO" "데이터 수정 테스트 시작" 
    start_timer    
    
    table_name="users"
    target_id=1
    updated_field="email"
    result_msg=$(sqlite3 "$DB_FILE" "UPDATE $table_name SET $updated_field='UpdateEmail' WHERE id=$target_id;" 2>&1)
    result=$?

    check_msg=$(sqlite3 "$DB_FILE" "SELECT email FROM $table_name WHERE id=1;")


    if [ $result -ne 0 ];
        then log_test_result "UPDATE 테스트" $result $result_msg
    fi
    
    [ $check_msg == "UpdateEmail" ]
    result=$?

    execution_time=$(end_timer) 
    details=$(create_details_by_operation "UPDATE" "$table_name" "$updated_field" "$target_id")
    log_test_result "데이터 업데이트 테스트" "$result" "$execution_time" "$details" "$error_msg"


    
}

# 5. DELETE 테스트 함수
test_delete_data() {

    log_message "INFO" "데이터 삭제 테스트 시작"
    start_timer

    table_name="users"
    target_id=1
    result_msg=$(sqlite3 "$DB_FILE" "DELETE FROM $table_name WHERE id = $target_id;" 2>&1)
    result=$?

    # DELETE가 성공했다면 개수 검증
    if [ $result -eq 0 ]; then
        expected_cnt=4
        remaining_cnt=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM $table_name;" 2>&1)
        
        if [ $remaining_cnt -ne $expected_cnt ]; then
            result=1  
            error_msg="개수 검증 실패"
        fi
    fi
    
    execution_time=$(end_timer) 
    details=$(create_details_by_operation "DELETE" "$table_name" "$target_id" "$remaining_cnt")
    log_test_result "데이터 삭제 테스트" "$result" "$execution_time" "$details" "$error_msg"

    
}

# 6. 정리 함수
cleanup_test_data() {
    
    echo "테스트 환경 정리 중..."
    
    if [ -f "$DB_FILE" ]; then
        rm "$DB_FILE"
        if [ $? -eq 0 ]; then
            echo "✅ 테스트 DB 파일 삭제 완료"
        else
            echo "❌ 테스트 DB 파일 삭제 실패"
        fi
    fi
}

# ==========================================
# 메인 실행 부분
# ==========================================

main() {
    local session_start=$(date '+%Y-%m-%d %H:%M:%S')
    print_test_header
    
    # # 1단계: 데이터베이스 생성
    # create_test_database
    
    # # 2단계: INSERT 테스트
    # test_insert_data
    
    # # 3단계: SELECT 테스트  
    # test_select_data
    
    # # 4단계: UPDATE 테스트
    # test_update_data
    
    # # 5단계: DELETE 테스트
    # test_delete_data
    # 데이터베이스 설정
    setup_test_database
    setup_transaction_test
    # test_transaction_commit
    # test_transaction_rollback
    # test_manual_rollback

    # test_update_conflicts
    test_deadlock_detection
    # 무결성 검증 테스트들
    # test_not_null_constraints
    # test_unique_constraints

    # 결과 요약 출력
    # print_advanced_test_summary

    # json 파일 생성
    # write_json_log_file "$session_start"

    # csv 히스토리 추가
    # write_csv_report

    # 정리 작업
    cleanup_test_data
    
    echo ""
    echo "테스트 로그는 '$LOG_FILE' 에서 확인하실 수 있습니다."
}

# 스크립트 실행
main "$@"
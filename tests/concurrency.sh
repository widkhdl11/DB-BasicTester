#!/bin/bash


# 프로세스 동시성으로 INSERT 문 누락 테스트
test_concurrent_inserts() {
    log_message "INFO" "동시성 INSERT 테스트 시작"
    start_timer
    reset_tables "users" "orders"
    
    # 성공/실패 카운터
    local success=0
    local failed=0
    local pids=()
    local actual_count=0
    local error_msg=""
    local json=""
    local query_result=""

    # 3개 프로세스 동시 실행
    for i in {1..3}; do
        query_result=$(run_query "INSERT INTO users (name, email, age) VALUES ('Concurrent$i', 'c$i@test.com', $((25+i)));") &
        pids[$i]=$!
    done
    
    # 각 프로세스 결과 확인
    for i in {1..3}; do
        wait ${pids[$i]}
        result=$?
        if [ $result -eq 0 ]; then
            success=$((success + 1))
        else
            if [[ $query_result == "Error: database is locked" ]]; then 
                echo "❌ 예상치 못한 에러 발생: $query_result"
                break
            fi
            failed=$((failed + 1))
            echo "⚠️  프로세스 $i 실패 (exit code: $result)"
        fi
    done
    
    echo "성공: $success, 실패: $failed"
    
    actual_count=$(assert_count "SELECT COUNT(*) FROM users WHERE name LIKE 'Concurrent%';" "$success")

    # 검증: 성공한 개수와 DB 레코드 수가 일치해야 함
    if [ "$actual_count" -eq "$success" ]; then
        echo "✅ 동시성 테스트 통과"
        result=0
    else
        echo "❌ 데이터 불일치 발생!"
        error_msg="데이터 불일치(success_count=$success / failed_count=$failed)"
        result=1
    fi
    execution_time=$(end_timer) 

    json=$(make_json "success_count=$success" "failed_count=$failed" )
    log_test_result "동시성 INSERT 테스트" "$result" "$execution_time" "$json" "$error_msg"

}

# 데이터베이스 동시성으로 인해 데이터베이스 값 유실 테스트
test_update_conflicts() {
    log_message "INFO" "Lost Update 테스트 시작"
    start_timer
    reset_tables "users" "orders"
    setup_data

    local pids=()    
    local error_msg=""
    local json=""
    local query_result=""
    local age=0
    local success=0
    local final_age=0
    local expected_age=0

    update_separated() {
        age=$(run_query "SELECT age FROM users WHERE name='test1';")
        
        (( age + 1 ))
        
        sleep 0.1
        run_query "UPDATE users SET age=$age WHERE name='test1';"
        return $?
    }
    
    for i in {1..5}; do
        update_separated &
        pids[$i]=$!
    done
    
    # 대기
    for i in {1..5}; do
        wait ${pids[$i]}
        [ $? -eq 0 ] && success=$((success + 1))
    done
    
    final_age=$(run_query "SELECT age FROM users WHERE name='test1';")
    expected_age=$(( 25+success ))

    echo "성공한 프로세스: $success"
    echo "최종 age: $final_age"
    echo "기대 age: $expected_age"
    
    if [ "$final_age" -lt "$expected_age" ]; then
        result=0
        echo "✅ 테스트 성공 (Lost Update 발생)"
        echo "   손실: $((25 + success - final_age))번"
    else
        result=1
        echo "❌ 테스트 실패(데이터 손실 발생하지 않음)"
        error_msg="데이터 손실 발생하지 않음"
    fi
    execution_time=$(end_timer) 

    json=$(make_json "query_attempts_count=5" "success_query_count=$success" "expected_age=$expected_age" "actual_age=$final_age")
    log_test_result "동시성 INSERT 테스트" "$result" "$execution_time" "$json" "$error_msg"

}


# IMMEDIATE를 사용하여 동시성으로 인한 데이터 유실 방지 확인 테스트
test_deadlock_detection() {
    echo "=== 잠금 타임아웃 테스트 ==="
    start_timer
    reset_tables "users" "orders"

    local error_msg=""
    local json=""
    local result
    # 긴 트랜잭션
    sqlite3 "$DB_FILE" >/dev/null 2>&1 <<EOF &
BEGIN IMMEDIATE;
INSERT INTO users (name, email, age) VALUES ('LongTx', 'long@test.com', 40);

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

    # 짧은 트랜잭션
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
    
    has_long=$(run_query "SELECT COUNT(*) FROM users WHERE name='LongTx';")
    has_short=$(run_query "SELECT COUNT(*) FROM users WHERE name='ShortTx';")

    execution_time=$(end_timer) 
    
    if [ $result1 -ne 0 ]; then
        result=1
        error_msg="긴 트랜잭션 실패"
    elif [ $result2 -ne 0 ]; then
        result=0
        echo "✅ 타임아웃으로 충돌 방지됨"
    else
        result=1
        echo "⚠️  두 트랜잭션 모두 성공 (긴 트랜잭션이 빨리 끝남)"
        error_msg="두 트랜잭션 모두 성공"
    fi
    json=$(make_json long_success=$result1 short_success=$result2)
    
    log_test_result "타임아웃 테스트" $result "$execution_time" "$json" "$error_msg"

}

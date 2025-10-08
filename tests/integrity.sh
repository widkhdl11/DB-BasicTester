# !/bin.bash


# 1. NOT NULL 제약 조건 테스트
test_not_null_constraints() {
    # TODO: NOT NULL 제약 위반 테스트 구현
    # TODO: name 컬럼에 NULL 삽입 시도 (에러 발생해야 함)
    # TODO: email 컬럼에 NULL 삽입 시도 (에러 발생해야 함)
    

    log_message "INFO" "NOT NULL 제약 조건 테스트 시작"
    start_timer

    reset_tables "users" "orders"
    
    local name_null_query="INSERT INTO users (email, age) VALUES ('test@test', 25)"
    local email_null_query="INSERT INTO users (name, age) VALUES ('김가서', 25)"
    local error_msg=""
    local result=0
    local before_rows=0
    local after_rows=0

    before_rows=$(run_query "SELECT COUNT(*) FROM users;")

    run_query "$name_null_query" "false"
    result1=$?
    run_query "$email_null_query" "false"
    result2=$?

    if [ $result1 -eq 0 ] && [ $result2 -eq 0 ]; then
        result=0
        error_msg="✅ NOT NULL 제약조건 위반 감지"
    else
        result=1
        error_msg="❌ NOT NULL 제약조건이 동작하지 않음"
    fi
    after_rows=$(run_query "SELECT COUNT(*) FROM users;")
    
    execution_time=$(end_timer)
    if [ $result -eq 0 ]; then
        json=$(make_json before_rows="$before_rows" after_rows="$after_rows")
    fi
    log_test_result "NOT NULL 제약 조건 테스트" "$result" "$execution_time" "$json" "$error_msg"
    
}

# 2. UNIQUE 제약 조건 테스트
test_unique_constraints() {
    
    log_message "INFO" "UNIQUE 제약 조건 테스트 시작"
    start_timer

    reset_tables "users" "orders"
    setup_data

    local email_unique_query="INSERT INTO users (name, email, age) VALUES ('홍서진', 'test1@test.com', 32)"
    local query_result=""
    local error_msg=""
    local before_rows=0
    local after_rows=0


    before_rows=$(run_query "SELECT COUNT(*) FROM users;")

    query_result=$(run_query "$email_unique_query" "false")
    result=$?

    if [ $result -eq 0 ]; then
        error_msg="✅ 정상적으로 UNIQUE 제약 위반 감지"
    else
        error_msg="❌ UNIQUE 제약이 제대로 동작하지 않음"
    fi
    after_rows=$(run_query "SELECT COUNT(*) FROM users;")
    execution_time=$(end_timer)
    if [ $result -eq 0 ]; then
        json=$(make_json before_rows=$before_rows after_rows=$after_rows)
    fi
    log_test_result "NOT NULL 제약 조건 테스트" "$result" "$execution_time" "$json" "$error_msg"
}

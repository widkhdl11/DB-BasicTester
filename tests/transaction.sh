#!/bin/bash

# 트랜잭션 테스트
test_transaction_commit() {
    log_message "INFO" "트랜잭션 커밋 테스트 시작"
    start_timer
    local query="
    BEGIN;
        INSERT INTO users (name, email, age) VALUES ('Charlie', 'charlie@test.com', 28);
        INSERT INTO orders (user_id,product, amount) VALUES (last_insert_rowid(),'Laptop', 999.99);
    COMMIT;
    "
    local error_msg=""
    local before_rows=0
    local after_rows=0
    local json

    before_rows=$(run_query "SELECT COUNT(*) FROM users;")

    run_query "$query"
    result=$?
    
    if  [ $result -eq 0 ]; then
        check_query="
        SELECT COUNT(*) FROM users u
        JOIN orders o ON u.id = o.user_id
        WHERE u.name='Charlie' 
        AND u.email='charlie@test.com'
        AND u.age=28
        AND o.product='Laptop'
        AND o.amount=999.99;
        "
        assert_count "$check_query" "1" >/dev/null
        result=$?

        if [ $result -ne 0 ]; then
            result=1
            error_msg="❌ 값이 올바르게 삽입되지 않음"
        fi
    fi
    after_rows=$(run_query "SELECT COUNT(*) FROM users;")

    execution_time=$(end_timer)
    if [ $result -eq 0 ]; then
        json=$(make_json before_rows=$before_rows inserted_rows=2 after_rows=$after_rows)
    fi
    log_test_result "트랜젝션 커밋 테스트" "$result" "$execution_time" "$json" "$error_msg"
}

# UNIQUE 제약조건 위반 자동 롤백 테스트
test_transaction_rollback() {
    log_message "INFO" "트랜잭션 자동 롤백 테스트 시작"
    start_timer

    local query="
    BEGIN;
        INSERT INTO users (name, email, age) VALUES ('eliie','test1@test.com', 30);
        INSERT INTO orders (user_id,product, amount) VALUES (last_insert_rowid(),'Phone', 11.00);
    COMMIT;
    "
    local error_msg=""
    local before_users_count=0
    local after_users_count=0
    local user_check_count=""
    local order_check_count=""

    reset_tables "users" "orders"
    setup_data

    before_users_count=$(run_query "SELECT COUNT(*) FROM users;")

    run_query "$query" "false"
    result=$?
    
    after_users_count=$(run_query "SELECT COUNT(*) FROM users;")

    if [ $result -eq 0 ]; then  
    user_check_count=$(assert_count "SELECT COUNT(*) FROM users WHERE name='eliie' AND email='test1@test.com';" "0")
    user_check_result=$?

    order_check_count=$(assert_count "SELECT COUNT(*) FROM orders WHERE product='Phone' AND amount=11.00;" "0")
    order_check_result=$?
    
        if [ "$user_check_result" -eq 0 ] && [ "$order_check_result" -eq 0 ]; then
            result=0
        else
            result=1
            user_check_count="$user_check_count" | jq -r '.actual_count'
            order_check_count="$order_check_result" | jq -r '.actual_count'
            error_msg="❌ 자동 롤백 검증 실패"
        fi
        json=$(make_json "users_table_expected_count=0" \
        "users_table_actual_count=$user_check_count" \
        "orders_table_expected_count=0" \
        "odrers_table_actual_count=$order_check_count")
    else
        result=1 
        error_msg="❌ 제약조건 위반이 발생하지 않음"
    fi
    execution_time=$(end_timer)
   
    log_test_result "트랜젝션 자동 롤백 테스트" "$result" "$execution_time" "$json" "$error_msg"
}

# 수동 롤백 테스트 함수
test_manual_rollback() {
    log_message "INFO" "수동 롤백 테스트 시작"
    start_timer

    reset_tables "users" "orders"
    setup_data

    local json=""
    local error_msg=""
    local query_result=""
    local before_users_count=0
    local before_orders_count=0
    local after_users_count=0
    local after_orders_count=0
    
    before_users_count=$(run_query "SELECT COUNT(*) FROM users;")
    before_orders_count=$(run_query "SELECT COUNT(*) FROM orders;")
    
    local query="
    BEGIN;
        INSERT INTO users (name, email, age) VALUES ('rollbackTest', 'rollback@test.com', 30);
        INSERT INTO orders (user_id,product, amount) VALUES (last_insert_rowid(),'Phone', 11.00);
    ROLLBACK;
    "
    query_result=$(run_query "$query")
    result=$?

    after_users_count=$(run_query "SELECT COUNT(*) FROM users;")
    after_orders_count=$(run_query "SELECT COUNT(*) FROM orders;")
    
    if [ $result -eq 0 ]; then

        after_users_count=$(assert_count "SELECT COUNT(*) FROM users;" "$before_users_count")
        users_check_result=$?
        after_orders_count=$(assert_count "SELECT COUNT(*) FROM orders;" "$before_orders_count")
        orders_check_result=$?

        if [ $users_check_result -eq 0 ] && [ $orders_check_result -eq 0 ]; then
            result=0
        else
            result=1
            after_users_count="$after_users_count" | jq -r ".actual_count"
            after_orders_count="$after_orders_count" | jq -r ".actual_count"

            error_msg="❌ 수동 롤백 검증 실패"
        fi
        json=$(make_json "users_table_expected_count=$before_users_count" "users_table_actual_count=$after_users_count" "orders_table_expected_count=$before_orders_count" "odrers_table_actual_count=$after_orders_count")

    else
        result=1
        error_msg="❌ 수동 롤백 실패($query_result)"
    fi

    execution_time=$(end_timer)
    log_test_result "트랜젝션 수동 롤백 테스트" "$result" "$execution_time" "$json" "$error_msg"

}

#!/bin/bash


#  데이터베이스 및 테이블 생성 테스트 함수
create_test_database() {

    log_message "INFO" "테이블 생성 시작"
    start_timer
    local query_result=""
    local error_msg=""
    local json=""

    local table_name="users"
    local show_tables=""
    local query="CREATE TABLE IF NOT EXISTS users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        age INTEGER CHECK(age >= 0 AND age <= 150),
        status TEXT DEFAULT 'active'
    );
    CREATE TABLE IF NOT EXISTS orders(
        order_id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        product TEXT NOT NULL,
        amount REAL CHECK(amount > 0),
        FOREIGN KEY (user_id) REFERENCES users(id)
    );"

    run_query "DROP TABLE users; DROP TABLE orders;"

    query_result=$(run_query "$query")
    result=$?

    execution_time=$(end_timer)

    if [ $result -eq 0 ]; then
        # 생성된 테이블 목록 가져오기
        show_tables=$(run_query "SELECT name FROM sqlite_master WHERE type='table'AND NOT name='sqlite_sequence';")

        IFS=$'\n' read -r -d '' -a tables_array <<< "$show_tables"
        tables_json="["
        for t in "${tables_array[@]}"; do
            tables_json+="$t,"
        done

        tables_json="${tables_json%,}]"

        json=$(make_json created_tables="$tables_json")
        error_msg="$query_result"
    fi

    log_test_result "테이블 생성 테스트" "$result" "$execution_time" "$json" "$error_msg"

}

# 2. INSERT 테스트 함수
test_insert_data() {
    log_message "INFO" "데이터 삽입 테스트 시작"
    start_timer
    local query_result=""
    local error_msg=""
    local json=""


    local table_name="users"
    local insert_data=(
    "NULL,'김나경','nakyung_ju@naver.com'"
    "NULL,'박성수','bagazzzzz@gmail.com'"
    "NULL,'홍겸','hnk1194@naver.com'"
    "NULL,'강민석','nakyung_ju@daum.net'"
    "NULL,'강이서','luv_2s@naver.com'"
    )

    
    local total_attempted=${#insert_data[@]}
    local rows_inserted=0


    reset_tables "users" "orders"

    for row in "${insert_data[@]}"; do
        local query="INSERT INTO $table_name(id, name, email) VALUES($row);"
        query_result=$(run_query "$query")
        result=$?

        if [ $result -eq 0 ]; then
            (( rows_inserted++ ))
        else
            error_msg="$query_result"
            break
        fi
    done

    execution_time=$(end_timer)
    if [ $result -eq 0 ]; then
        json=$(make_json inserted_rows=5)
        error_msg="$query_result"
    fi
    log_test_result "데이터 삽입 테스트" "$result" "$execution_time" "$json" "$error_msg"

}

# 3. SELECT 테스트 함수  
test_select_data() {

    log_message "INFO" "데이터 조회 테스트 시작"
    start_timer
    local table_name="users"
    local expected_count=5
    local query_result=""
    local error_msg=""
    local json=""

    reset_tables "users"
    setup_data

    query_result=$(assert_count "SELECT COUNT(*) FROM $table_name" "$expected_count")
    result=$?

    local execution_time=$(end_timer)

    if [ $result -eq 0 ]; then
        json=$(make_json actual_count=$query_result expected_count=$expected_count)
        error_msg="$query_result"
    fi
    
    log_test_result "데이터 조회 테스트" "$result" "$execution_time" "$json" "$error_msg"

}

# 4. UPDATE 테스트 함수
test_update_data() {

    log_message "INFO" "데이터 수정 테스트 시작" 
    start_timer    
    
    local table_name="users"
    local updated_id=1
    local updated_value="UpdateEmail"
    local query_result=""
    local error_msg=""
    local json=""

    reset_tables "users" "orders"
    setup_data

    updated_id=$(select_first_id "users")

    query_result=$(run_query "UPDATE $table_name SET email='$updated_value' WHERE id=$updated_id")
    result=$?

    if [ $result -eq 0 ]; then
        query_result=$(assert_value "SELECT email FROM $table_name WHERE id=$updated_id" "$updated_value")  
        result=$?
    fi
    
    execution_time=$(end_timer) 

    if [ $result -eq 0 ]; then
        json=$(make_json updated_id="$updated_id" updated_filed="email" updated_value="$updated_value")
        error_msg="$query_result"
    fi
    log_test_result "데이터 업데이트 테스트" "$result" "$execution_time" "$json" "$error_msg"

    
}

# 5. DELETE 테스트 함수
test_delete_data() {

    log_message "INFO" "데이터 삭제 테스트 시작"
    start_timer

    local table_name="users"
    local deleted_id=1
    local expected_count=4
    local query_result=""
    local error_msg=""
    local json=""

    reset_tables "users" "orders"
    setup_data
    deleted_id=$(select_first_id "users")

    query_result=$(run_query "DELETE FROM $table_name WHERE id = $deleted_id;")
    result=$?
    # DELETE가 성공했다면 개수 검증
    if [ $result -eq 0 ]; then
        query_result=$(assert_count "SELECT COUNT(*) FROM $table_name;" "$expected_count")
        result=$?
    fi
    
    execution_time=$(end_timer) 

    if [ $result -eq 0 ]; then
        json=$(make_json deleted_id="$deleted_id" actual_count=$query_result expected_count=$expected_count)
        error_msg="$query_result"
    fi

    log_test_result "데이터 삭제 테스트" "$result" "$execution_time" "$json" "$error_msg"
    
}
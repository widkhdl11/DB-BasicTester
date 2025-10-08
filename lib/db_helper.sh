#!/bin/bash


show_tables(){
    local query_result=""
    query_result=$(sqlite3 "$DB_FILE" ".tables" 2>&1)
    result=$?

    if [ $result -eq 0 ]; then
        echo "$query_result"
        return 0
    else
        echo "$query_result"
        return 1
    fi
}

# 쿼리 실행 함수 (쿼리, 결과값(default:"true") ) 
# 해당 쿼리가 올바르게 작동하는지 체크
run_query(){
    local query="$1"
    local expected_success="${2:-true}"
    local query_result=""

    query_result=$(sqlite3 "$DB_FILE" "$query" 2>&1)
    result=$?

    if [ "$expected_success" = "true" ]; then
        if [ $result -ne 0 ]; then
            echo "❌ 쿼리 실패: $query_result" >&2
            echo "쿼리 : $query" >&2
            echo "$query_result"
            return 1
        fi
    else
        if [ $result -eq 0 ]; then
            echo "❌ 에러가 발생해야 하는데 성공함" >&2
            echo "   쿼리: $query" >&2
            return 1
        fi
    fi

    if [ -n "$query_result" ]; then
        echo "$query_result"
    fi
    return 0
}

# 결과 카운트 검증 함수 (count query, 기대값(개수))
# 해당 쿼리 결과가 원하는 개수가 나오는지 체크
assert_count(){
    local query="$1"
    local expected_count="${2:-}"
    local json=""
    query_result=$(run_query "$query")
    result=$?
    
    if [ $result -eq 0 ]; then
        if [ "$query_result" -eq "$expected_count" ]; then
            echo "✅ 검증 성공" >&2
            echo "$query_result"
            return 0
        else 
            echo "❌ 검증 실패" >&2
            echo "쿼리 : $query" >&2
            echo "검증값 : "$expected_count", 결과값: "$query_result"" >&2
            json=$(make_json expected_count=$expected_count actual_count=$query_result)
            echo "$json"
            return 1
        fi
    else
        echo "$query_result"
        return 1
    fi
}

# 결과 카운트 검증 함수 (query, 기대값(개수))
# 해당 쿼리 결과가 원하는 값이 나오는지 체크
assert_value(){
    local query="$1"
    local expected_value="${2:-1}"
    local json=""

    query_result=$(run_query "$query")
    result=$?
    
    if [ $result -eq 0 ]; then
        if [ "$query_result" = "$expected_value" ]; then
            echo "✅ 검증 성공" >&2
            echo "$query_result"
            return 0
        else
            if [ -n "$query_result" ]; then
                query_result=0
            fi
            echo "❌ 검증 실패 (검증값 : "$expected_value", 결과값: "$query_result" )" >&2
            json=$(make_json expected_value=$expected_value actual_value=$query_result)
            echo "$json"
            return 1
        fi
    else
        echo "$query_result"
        return 1
    fi
  
}

# 테이블 초기화 함수
reset_tables() {
    while [ -n "$1" ]; do
        run_query "DELETE FROM "$1";"
        if [ $? -ne 0 ]; then
            echo "❌ '$1' 초기화 실패" >&2
            return 1
        fi
        shift
    done
    echo "✅ 모든 테이블 초기화 완료"
}

setup_data(){
    local table_name="users"

    local data_set=(
        "'test1', 'test1@test.com', 25, 'active'"
        "'test2', 'test2@test.com', 26, 'inactive'"
        "'test3', 'test3@test.com', 27, 'inactive'"
        "'test4', 'test4@test.com', 28, 'active'"
        "'test5', 'test5@test.com', 29, 'active'"
    )

    for d in "${data_set[@]}"; do
        run_query "INSERT INTO $table_name(name,email,age,status) VALUES ($d);"
        if [ $? -ne 0 ]; then
            echo "❌ '$d' 데이터 삽입 실패" >&2
            echo "'$d'"
            return 1
        fi
    done
    echo "✅ 모든 데이터 삽입 완료"
    return 0
}

setup_tables(){
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



    run_query "$users_query"
    result1=$?
    run_query "$orders_query"
    result2=$?

    if [ $result1 -eq 0 ] && [ $result1 -eq 0 ]; then
        echo "✅ 테스트 테이블 생성 완료" >&2
        return 0
    else
        echo "❌ 테스트 테이블 생성 실패" >&2
        return 1
    fi

}


print_table(){
    local table_name="$1"
    local result=$(sqlite3 "$DB_FILE" "SELECT * FROM $table_name;" 2>&1)

    echo "$result"
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

#테스트용 첫번째 행 id 가져오는 함수 (테이블 이름)
select_first_id(){
    local table_name="$1"
    local query_result=""

    query_result=$(run_query "SELECT id FROM $table_name limit 1;")
    result=$?

    if [ $result -eq 0 ];then
        echo "$query_result"
        return 0
    else 
        echo "❌ 테스트용 첫번째 행 가져오기 실패" >&2
        echo "에러내용 : $query_result" >&2
        return 1
    fi
}
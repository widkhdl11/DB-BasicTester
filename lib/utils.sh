#!/bin/bash


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

# json 형식 변환 함수 make_json "key=value"
make_json() {
    local result="{"
    local first=true
    
    while [ $# -gt 0 ]; do
        IFS='=' read -r key value <<< "$1"

        [ "$first" = false ] && result="$result,"
        
        if [[ "$value" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            result="$result\"$key\":$value"
        elif [[ "$value" =~ ^(true|false)$ ]]; then
            result="$result\"$key\":$value"
        else
            result="$result\"$key\":\"$value\""
        fi
        
        first=false
        shift
    done
    
    result="$result}"
    echo "$result"
}


# make_json() {
#     local result=""
#     local first=true
    
#     while [ $# -gt 0 ]; do
#         IFS='=' read -r key value <<< "$1"
        
#         [ "$first" = false ] && result="$result,"
        
#         # 숫자 판별
#         if [[ "$value" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
#             result="$result\"$key\":$value"
#         elif [[ "$value" =~ ^(true|false|null)$ ]]; then
#             result="$result\"$key\":$value"
#         else
#             result="$result\"$key\":\"$value\""
#         fi
        
#         first=false
#         shift
#     done
    
#     echo "$result"
# }



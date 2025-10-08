#!/bin/bash


assert_count(){
    local actual=$1
    local expected=$2
    
    if [ $actual -eq $expected ]; then
        echo "✅ 검증 성공" >&2  # 터미널 출력
        echo "$actual"          # 반환값
        return 0
    else
        echo "검증 실패 (기대: $expected, 실제: $actual)" 
        return 1
    fi
}

assert_count 1 2
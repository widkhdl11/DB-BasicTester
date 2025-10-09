#!/bin/bash

check_list=("sqlite3" "bash" "bc" "jq")

for p in "${check_list[@]}"; do
    version=""
    echo "$p 설치 확인 중"
    if command -v $p >/dev/null 2>&1 ; then
        if $p --version >/dev/null 2>&1 ; then
            env_success=true
            version=$($p --version | head -n 1 | grep -oP '\d+\.\d+(\.\d+)?')
            echo "✅ 설치 확인(버전: $version)"
        else 
            echo "❌ $p 버전 확인 실패"
            exit 1
        fi
    else
        echo "❌ $p 설치 확인 실패"
        exit 1
    fi
done
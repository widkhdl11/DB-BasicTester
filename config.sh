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


# 전역 변수 (JSON 로그용)
declare -a json_logs=()


# 테스트 카운터
total_tests=0
passed_tests=0
failed_tests=0
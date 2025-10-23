#!/bin/bash

# 스크립트 파일 임포트
source ./config.sh
for lib in lib/*.sh; do
    source "$lib"
done
for test in tests/*.sh; do
    source "$test"
done

# 절대경로 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 버전 출력 옵션
if [ "$1" = "--version" ] || [ "$1" = "-v" ]; then
    echo "DB-BasicTester v$VERSION"
    exit 0
fi

# 테스트 시작 헤더 출력
print_test_header() {
    {

    echo "===========================================" 
    echo "=== DB-HealthMate 테스트 시작 ===" 
    echo "테스트 시간: $(date)" 
    echo "===========================================" 
    echo ""
    } | tee "$LOG_FILE"
}

# 테스트 결과 요약 출력
print_advanced_test_summary() {
    local session_end=$(date '+%Y-%m-%d %H:%M:%S')

    {
    echo "" 
    echo "===========================================" 
    echo "--- 테스트 결과 요약 ---" 
    echo "세션 종료 시간: $session_end" 
    echo "총 테스트: $total_tests개" 
    echo "성공: $passed_tests개" 
    echo "실패: $failed_tests개" 
    
    
    if [ $total_tests -gt 0 ]; then
        success_rate=$((passed_tests * 100 / total_tests))
        echo "성공률: $success_rate%" 
    fi

    echo "" 
    echo "📊 생성된 리포트 파일들:" 
    echo "  - 텍스트 로그: $LOG_FILE" 
    echo "  - JSON 로그: $JSON_LOG_FILE" 
    echo "  - CSV 리포트: $CSV_REPORT_FILE" 
    echo "==========================================="
    } | tee -a "$LOG_FILE"
}



test(){
    print_table "users"
    setup_data
    local query="INSERT INTO users (id, name,email,age,status) VALUES (NULL, '홍서진', 'test1@test.com', 32)"
    local result_query=$(run_query "$query" false)
    print_table "users"
    echo "result_query : $result_query"
}
# ==========================================
# 메인 실행 부분
# ==========================================

main() {
    local session_start=$(date '+%Y-%m-%d %H:%M:%S')
    print_test_header

    # 테스트할 테이블 생성
    setup_tables
    # 기본 테이블 생성 및 CRUD 테스트
    # create_test_database
    # test_insert_data
    # test_select_data
    # test_update_data
    # test_delete_data


    # 무결성 검증 테스트들
    # test_not_null_constraints
    # test_unique_constraints

    # 트랜젝션 테스트
    # test_transaction_commit
    # test_transaction_rollback
    # test_manual_rollback

    # 동시성 테스트
    test_concurrent_inserts
    test_update_conflicts
    test_deadlock_detection

    # 결과 요약 출력
    print_advanced_test_summary

    # json 파일 생성
    write_json_log_file "$session_start"

    # csv 히스토리 추가
    write_csv_report

    # 정리 작업
    cleanup_test_data
    
    echo ""
    echo "테스트 로그는 '$LOG_FILE' 에서 확인하실 수 있습니다."
}

# 스크립트 실행
main "$@"
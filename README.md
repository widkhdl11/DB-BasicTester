# DB-BasicTester

Shell Script 기반 데이터베이스 테스트 자동화 도구

---

## 프로젝트 소개

SQLite를 사용한 데이터베이스 자동 테스트 프로그램
CRUD, 트랜잭션, 동시성 등 실제 DB 환경에서 발생할 수 있는 다양한 시나리오를 테스트합니다.

---

## 기술 스택

- Shell Script (Bash)
- SQLite3
- JSON/CSV 로깅

---


## 프로젝트 구조
project/
├── db_basicTest_runner.sh    # 메인 실행 파일
├── config.sh                  # 설정
├── lib/                       # 라이브러리
│   ├── db_helper.sh          # DB 헬퍼 함수
│   ├── logger.sh             # 로깅 함수
│   └── utils.sh              # 유틸리티 함수
└── tests/                     # 테스트케이스
├── crud.sh               # CRUD 테스트
├── integrity.sh          # 무결성 검증
├── transaction.sh        # 트랜잭션 테스트
└── concurrency.sh        # 동시성 테스트

---

## 주요 기능 설명

### 1. CRUD 테스트 (4개)
- 테이블 생성, 데이터 삽입, 조회, 수정, 삭제

### 2. 무결성 검증 테스트 (2개)
- NOT NULL 제약조건
- UNIQUE 제약조건

### 3. 트랜잭션 테스트 (3개)
- COMMIT 정상 처리
- 제약조건 위반 시 자동 ROLLBACK
- 수동 ROLLBACK

### 4. 동시성 테스트 (3개)
- 동시 INSERT 처리 ( 프로세스 에러 )
- Lost Update 시나리오 ( 동시성으로 인한 데이터 누수 )
- 타임아웃 확인 테스트

---

## 설계 특징
### 모듈화
- 기능별로 파일을 분리하여 유지보수성을 높였습니다.

- 설정: config.sh
- DB 작업: lib/db_helper.sh
- 로깅: lib/logger.sh
- 테스트: tests/*.sh

### 로깅 기능
- 용도에 따라 3가지 포맷으로 결과를 기록합니다.
- TXT: 사람이 읽기 위한 성공/실패 분석 로그용
- JSON: 프로그램간 통신을 위한 JSON 파일
- CSV: 통계 및 트렌드 분석을 위한 데이터셋
  
### stdout/stderr 분리
- stdout: 함수 반환값 (JSON 형태로 데이터 반환)
- stderr: 사용자 피드백 (터미널 출력)

---

### JSON 구조
```
{
  "session_info": {
    "start_time": "2025-10-08 16:35:59",
    "total_tests": 13,
    "passed_tests": 13
  },
  "test_results": [
    {
      "test_name": "테이블 생성 테스트",
      "status": "PASS",
      "execution_time": "0.897s",
      "details": {...}
    }
  ]
}
```


### 요구사항
- Linux/Unix 환경
- Bash 4.0 이상
- SQLite3
- jq

## 실행 방법
# 1. 실행 권한
chmod +x check_env.sh
chmod +x db_basicTest_runner.sh

# 2. 환경 확인
./check_env.sh

# 3. 테스트 실행
./db_basicTest_runner.sh

# JobKorea 크롤러

잡코리아에서 채용공고를 크롤링해 MariaDB의 `job` 테이블에 바로 저장하는 스크립트입니다. (라즈베리파이 Ubuntu 22.04 환경 기준)

## 파일 구성

| 파일 | 설명 |
|---|---|
| `crawl3.py` | 크롤링 + DB 저장 메인 스크립트 |
| `run.sh` | 가상환경 생성/활성화 → 패키지 설치 → 크롤링 실행까지 한 번에 처리하는 원터치 스크립트 |
| `requirements.txt` | 필요한 파이썬 패키지 목록 |
| `.env.example` | DB 접속 정보 템플릿 (실제 `.env`는 커밋하지 않음) |

## 사전 준비

### 1. DB 계정 및 테이블

`apply_db` 데이터베이스에 아래 구조의 `job` 테이블이 있어야 합니다.

```sql
CREATE TABLE job (
    job_id            INT AUTO_INCREMENT PRIMARY KEY,
    source            VARCHAR(20)   NOT NULL,
    job_part          VARCHAR(100),
    company_name      VARCHAR(255),
    post_title        VARCHAR(500),
    region            VARCHAR(255),
    personal_history  VARCHAR(100),
    pay               VARCHAR(255),
    end_at            DATE,
    crawled_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    job_url           VARCHAR(1000),
    post_id           VARCHAR(255) NOT NULL UNIQUE,
    apply             VARCHAR(20)  NOT NULL DEFAULT 'PENDING'
);
```

크롤링 전용 계정도 만들어 둡니다 (root 직접 사용 비권장).

```sql
CREATE USER 'crawler'@'127.0.0.1' IDENTIFIED BY '원하는비밀번호';
GRANT ALL PRIVILEGES ON apply_db.* TO 'crawler'@'127.0.0.1';
FLUSH PRIVILEGES;
```

### 2. `.env` 파일 생성

`.env.example`을 참고해 같은 폴더에 `.env` 파일을 만들고 실제 값을 채웁니다.

```
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=crawler
DB_PASSWORD=원하는비밀번호
DB_NAME=apply_db
```

`.env`는 비밀번호가 들어있으므로 반드시 `.gitignore`에 등록해 커밋되지 않도록 합니다. 가상환경 폴더(`venv/`)도 함께 제외합니다.

```
echo ".env" >> .gitignore
echo "venv/" >> .gitignore
```

## 실행 방법

```bash
chmod +x run.sh
./run.sh
```

`run.sh`가 하는 일:

1. `venv` 폴더가 없으면 가상환경 생성
2. 가상환경 활성화
3. `.env` 파일 존재 여부 확인 (없으면 안내 후 중단)
4. `requirements.txt`에 있는 패키지 설치
5. `crawl3.py` 실행

## 동작 개요

- `requests` + `BeautifulSoup`으로 잡코리아 검색 결과 페이지를 파싱합니다.
- 공고 URL에서 `post_id`를 추출하며, 추출에 실패한 공고는 저장하지 않습니다 (`post_id`가 DB에서 `UNIQUE NOT NULL`이기 때문).
- 마감일 텍스트("상시채용", "~07/31(금)" 등)는 `parse_end_at()` 함수로 `DATE` 값 또는 `NULL`로 변환합니다.
- DB 저장은 `INSERT ... ON DUPLICATE KEY UPDATE` 방식으로, 이미 존재하는 공고(`post_id` 기준)는 제목/지역/급여/마감일/크롤링 시각만 갱신하고 `apply` 상태(지원 여부)는 건드리지 않습니다.

## 주의사항

- 크롤링 대상 검색 키워드, 페이지 범위는 `crawl3.py`의 `main()` 함수 내 `keyword`, `start_page`, `end_page` 값을 수정해 변경합니다.
- 사이트 구조가 바뀌어 공고를 하나도 못 찾으면 `debug_page_N.html` 파일로 원본 HTML을 저장하니, 이 파일로 선택자를 다시 확인하면 됩니다.

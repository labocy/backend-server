# JobKorea 크롤러

잡코리아에서 채용공고를 크롤링해 MariaDB의 `job` 테이블에 바로 저장하는 스크립트입니다. (라즈베리파이 Ubuntu 22.04 환경 기준)

## 파일 구성

| 파일 | 설명 |
|---|---|
| `crawl3.py` | 크롤링 + DB 저장 + 디스코드 알림 메인 스크립트 |
| `run.sh` | 가상환경 생성/활성화 → 패키지 설치 → 크롤링 실행까지 한 번에 처리하는 원터치 스크립트 |
| `requirements.txt` | 필요한 파이썬 패키지 목록 |
| `.env.example` | DB / 디스코드 웹훅 접속 정보 템플릿 (실제 `.env`는 커밋하지 않음) |

## 사전 준비

### 1. DB 계정 및 테이블

`apply_db` 데이터베이스에 아래 구조의 `job` 테이블이 있어야 합니다. (지원 여부는 더 이상 `job` 테이블에 두지 않고, 회원별로 여러 건 지원 가능하도록 `member_job_apply` 매핑 테이블로 분리되었습니다.)

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
    post_id           VARCHAR(255) NOT NULL UNIQUE
);
```

참고: 지원 현황은 별도 테이블(`member_job_apply`: member_id, job_id, apply, applied_at)에서 회원-공고 다대다로 관리됩니다. 크롤러는 이 테이블을 다루지 않으며, `job` 테이블에만 INSERT/UPDATE 합니다.

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

# 디스코드 알림 (선택 사항 — 없으면 알림만 건너뛰고 크롤링/DB 저장은 정상 동작)
DISCORD_WEBHOOK_URL=디스코드_채널_웹훅_URL
```

`DISCORD_WEBHOOK_URL`은 알림 받을 디스코드 채널의 설정(톱니바퀴) → 연동(Integrations) → 웹후크(Webhooks) → 새 웹후크 만들기에서 발급받은 URL을 그대로 넣으면 됩니다.

`.env`는 비밀번호/웹훅 URL이 들어있으므로 반드시 `.gitignore`에 등록해 커밋되지 않도록 합니다. 가상환경 폴더(`venv/`)도 함께 제외합니다.

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
- DB 저장은 `INSERT ... ON DUPLICATE KEY UPDATE` 방식으로, 이미 존재하는 공고(`post_id` 기준)는 제목/지역/급여/마감일/크롤링 시각만 갱신합니다. 지원 여부(`apply`)는 `job` 테이블이 아니라 `member_job_apply` 테이블에서 회원별로 관리되므로 크롤러는 이 값에 관여하지 않습니다.
- 저장 시 MariaDB의 `affected rows` 값(신규 INSERT=1, 기존 행 값 변경=2, 값 동일=0)으로 신규/갱신 공고를 구분해서, **신규로 새로 저장된 공고만** 디스코드로 알림을 보냅니다.

## 디스코드 알림

`DISCORD_WEBHOOK_URL`이 `.env`에 설정되어 있으면, 크롤링이 끝날 때마다 결과를 디스코드 채널로 전송합니다.

- 신규 공고가 있을 때: 회사명 + 제목(공고 링크) 목록을 임베드 카드로 전송 (최대 10건, 초과분은 "…외 N건"으로 표시)
- 신규 공고가 없을 때: "신규 공고 없음 (갱신 X건 / 실패 Y건)" 텍스트 메시지 전송
- `DISCORD_WEBHOOK_URL`이 없으면 알림 전송을 조용히 건너뛰고, 크롤링/DB 저장은 그대로 정상 동작

## 자동 실행 (crontab)

라즈베리파이에 `crontab`으로 등록해두면 지정한 주기마다 자동으로 크롤링 + 알림이 실행됩니다.

```
crontab -e
```

아래처럼 한 줄 추가 (예: 매일 오전 9시 실행):

```
0 9 * * * cd /home/사용자명/backend-server/crawler && /home/사용자명/backend-server/crawler/venv/bin/python crawl3.py >> /home/사용자명/backend-server/crawler/crawl.log 2>&1
```

- `cd`로 먼저 폴더 이동: `load_dotenv()`가 현재 디렉토리의 `.env`를 찾기 때문에 필요
- `venv/bin/python`으로 가상환경 안의 파이썬을 직접 지정해야 필요한 패키지를 정상적으로 찾음
- `>> crawl.log 2>&1`: 실행 로그/에러를 파일로 남겨서 문제 발생 시 확인 가능

등록 확인:

```
crontab -l
```

자주 쓰는 주기 예시: `0 */6 * * *`(6시간마다), `*/30 * * * *`(30분마다), `0 9,18 * * *`(매일 오전 9시·오후 6시)

## 주의사항

- 크롤링 대상 검색 키워드, 페이지 범위는 `crawl3.py`의 `main()` 함수 내 `keyword`, `start_page`, `end_page` 값을 수정해 변경합니다.
- 사이트 구조가 바뀌어 공고를 하나도 못 찾으면 `debug_page_N.html` 파일로 원본 HTML을 저장하니, 이 파일로 선택자를 다시 확인하면 됩니다.
- crontab으로 자동 실행하기 전에, 먼저 수동으로 `python crawl3.py` 실행해서 디스코드 채널에 알림이 정상적으로 오는지 확인해보는 것을 권장합니다.


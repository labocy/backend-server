# Discord Job Notifier Bot

PortfoLink 서비스의 채용 공고 DB(`apply_db`의 `job` 테이블)를 조회하여,
매일 지정한 시간에 특정 직무(job_part) 신규 공고를 디스코드 채널로 알림 보내는 봇입니다.

## 대상 환경

- Ubuntu 22.04
- Python 3
- MariaDB (`apply_db`, `mysql-connector`로 접속 가능)

## 프로젝트 구조

```
job_notifier/
├── .env                    # 실제 설정값 (직접 생성, .env.example 참고)
├── .env.example            # 설정 템플릿
├── config.py               # 환경변수 로딩
├── db.py                   # DB 조회 (job_id 증분 조회)
├── state.py                # 마지막 처리 job_id 저장/불러오기
├── bot.py                  # 디스코드 봇 + 스케줄러
├── last_job_id.txt         # (자동 생성) 마지막 전송한 job_id 기록
├── setup.sh                # 설치 + 실행 (최초 1회)
├── auto.sh                 # 정지 시 자동 재시작
├── reset.sh                # 저장 기록 초기화 (처음 상태로)
├── job-notifier.service    # systemd 서비스 등록 파일
├── requirements.txt
└── README.md
```

## 빠른 실행 (셸 스크립트)

| 스크립트 | 용도 |
|----------|------|
| `./setup.sh` | 가상환경 생성 + 의존성 설치 + 봇 실행 (최초 1회). `.env`가 없으면 템플릿을 만들고 안내 후 종료 → 값 입력 후 다시 실행 |
| `./auto.sh` | 봇이 정지되면 자동으로 다시 실행 (감시 루프). 중지는 `Ctrl+C` |
| `./reset.sh` | `last_job_id.txt`를 삭제해 처음 상태로 초기화 (다음 실행 시 전체 재발송) |

```bash
# 최초 설치 및 실행
./setup.sh
# (.env가 새로 생성되면) 값 입력 후 다시
nano .env
./setup.sh

# 상시 가동 (죽으면 자동 재시작)
./auto.sh

# 처음부터 전체 다시 보내기
./reset.sh
```

## DB 테이블 (job) — `01_schema.sql` 기준

| 컬럼 | 타입 | 설명 |
|------|------|------|
| job_id | INT PK | auto_increment |
| source | VARCHAR(20) | 플랫폼 [SARAMIN, JOBKOREA] |
| job_part | VARCHAR(100) | 직무 |
| company_name | VARCHAR(255) | 회사명 |
| post_title | VARCHAR(500) | 공고제목 |
| region | VARCHAR(255) | 지역 |
| personal_history | VARCHAR(100) | 경력조건 |
| pay | VARCHAR(255) | 급여 |
| end_at | DATE | 마감일 |
| crawled_at | DATETIME | 크롤링 날짜 (DEFAULT CURRENT_TIMESTAMP) |
| job_url | VARCHAR(1000) | 링크 |
| post_id | VARCHAR(255) UNIQUE | 고유번호 (중복 크롤링 방지) |

> ※ 스키마 변경으로 `apply`(지원여부)는 `job` 테이블에서 빠지고,
> 회원별 지원 상태를 관리하는 `member_job_apply` 테이블로 분리되었습니다.
> 이 봇은 채널 공용 알림용이라 회원별 지원 상태와 무관하게
> **당일 신규 공고**를 알립니다.

## 설치

```bash
cd ~/job_notifier

# 가상환경 생성 및 활성화
python3 -m venv venv
source venv/bin/activate

# 의존성 설치
pip install -r requirements.txt
```

## 설정

`.env.example`을 복사해 `.env`를 만들고 값을 채웁니다.

```bash
cp .env.example .env
nano .env
```

| 변수 | 설명 |
|------|------|
| DISCORD_TOKEN | 디스코드 봇 토큰 |
| CHANNEL_ID | 알림을 보낼 채널 ID |
| DB_HOST / DB_PORT / DB_USER / DB_PASSWORD / DB_NAME | MySQL 접속 정보 |
| NOTIFY_HOUR / NOTIFY_MINUTE | 알림 시각 (24시간 형식, Asia/Seoul) |
| TARGET_JOB_PARTS | 알림 대상 직무 (쉼표 구분, 비우면 전체) |

## 디스코드 봇 준비

1. https://discord.com/developers/applications 에서 애플리케이션 생성
2. **Bot** 탭에서 봇 생성 후 TOKEN 복사 → `.env`의 `DISCORD_TOKEN`
3. **OAuth2 → URL Generator**에서 `bot` 스코프, `Send Messages` + `Embed Links` 권한 선택 후 생성된 URL로 서버 초대
4. 디스코드 설정에서 개발자 모드 활성화 → 채널 우클릭 → "ID 복사" → `.env`의 `CHANNEL_ID`

## 실행

```bash
source venv/bin/activate
python bot.py
```

## systemd 상시 실행 등록

`job-notifier.service` 파일의 `User`, `WorkingDirectory`, `ExecStart` 경로를 본인 환경에 맞게 수정한 뒤 등록합니다.

```bash
sudo cp job-notifier.service /etc/systemd/system/job-notifier.service
sudo systemctl daemon-reload
sudo systemctl enable --now job-notifier

# 상태 확인
sudo systemctl status job-notifier

# 로그 실시간 확인
journalctl -u job-notifier -f
```

## 동작 방식

- 매일 `NOTIFY_HOUR:NOTIFY_MINUTE` 시각에 DB를 조회합니다.
- 크롤링은 외부에서 별도로 수행됩니다. 이 봇은 **이전에 알린 마지막 `job_id` 이후 추가된 공고만** 감지해 전송합니다.
  - **최초 실행**(상태 파일 없음): 조건에 맞는 전체 공고를 전송합니다.
  - **이후 실행**: `job_id > 마지막 처리값`인 신규 공고만 전송합니다.
- 마지막으로 처리한 `job_id`는 `last_job_id.txt` 파일에 저장됩니다.
- 조건: `TARGET_JOB_PARTS` 직무 키워드 부분일치.
- 조회 결과를 직무별로 묶어 디스코드 임베드 메시지로 전송합니다.

### 상태 파일 (last_job_id.txt)

- 봇이 자동으로 생성·갱신하는 파일로, 마지막으로 전송한 공고의 `job_id`가 들어 있습니다.
- **처음부터 다시 전체를 보내고 싶으면** 이 파일을 삭제하면 됩니다 (`rm last_job_id.txt`).
- `job_id`가 AUTO_INCREMENT라 새 공고일수록 값이 커지므로, 이 값을 기준으로 추가분을 정확히 감지합니다.

### 직무 매칭 방식 (중요)

크롤러(`crawl3.py`)는 검색 키워드를 그대로 `job_part`에 저장합니다(예: "파이썬 개발자").
따라서 정확일치(IN)로는 매칭이 어려워 **LIKE 부분일치**를 사용합니다.
`TARGET_JOB_PARTS=백엔드`로 설정하면 `"백엔드 개발자"`, `"파이썬 백엔드"` 등이 모두 매칭됩니다.
(API 명세서 v2.1 7장 이슈 4-1 반영)

## 참고

- `post_id UNIQUE` 제약으로 중복 공고는 DB 단계에서 제거되므로, 봇은 `job_id` 증가분만 추적하면 됩니다.
- 재전송을 다시 하고 싶으면 `last_job_id.txt`를 삭제하세요 (다음 실행 시 전체 재전송).
- 테스트 시 `on_ready` 안에서 `await send_notification()`을 직접 호출하면 즉시 확인할 수 있습니다.

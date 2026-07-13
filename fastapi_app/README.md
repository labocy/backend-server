# FastAPI 백엔드 (인증 + 회원 API)

라즈베리파이 2B(Ubuntu 22.04) 위에서 동작하는 FastAPI 서버 코드입니다. 기능이 추가될 때마다 이 문서의 "3. API 엔드포인트"와 "6. 기능별 구현 메모"만 이어서 추가하면 되도록 구성했습니다.

## 1. 파일 구조

```
fastapi_app/
├── main.py             # FastAPI 앱 생성 + 라우터 등록
├── database.py         # MariaDB 커넥션 생성
├── security.py         # 비밀번호 해싱 + JWT 발급/검증
├── deps.py             # 인증 확인용 Depends 함수 (get_current_member)
├── auth_router.py      # 인증: signup / login / logout
├── members_router.py   # 회원: 내 정보 조회 / 희망조건 수정 / 탈퇴
├── requirements.txt
├── .env.example
└── README.md
```

> 새 기능 라우터를 추가할 때는 `xxx_router.py` 파일을 만들고 `main.py`에 `app.include_router(...)` 한 줄만 추가하면 됩니다.

## 2. 설치 및 설정

```
pip install -r requirements.txt
```

`.env.example`을 참고해 `.env` 파일을 만들고 값을 채웁니다.

```
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=fastapi_app
DB_PASSWORD=실제_비밀번호
DB_NAME=apply_db
JWT_SECRET_KEY=본인이_직접_생성한_랜덤값
```

`JWT_SECRET_KEY`는 아래 명령어로 직접 생성하세요 (채팅이나 코드에 노출된 값은 절대 재사용 금지).

```
python3 -c "import secrets; print(secrets.token_hex(32))"
```

`.env`는 반드시 `.gitignore`에 등록해서 커밋되지 않도록 합니다.

## 3. 실행

```
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

`http://<서버주소>:8000/docs` (Swagger UI)에서 아래 엔드포인트를 직접 호출하며 테스트할 수 있습니다.

## 4. API 엔드포인트

새 엔드포인트를 추가할 때마다 이 표에 행만 추가하면 됩니다.

| 도메인 | Method | Path | 인증 | 설명 | 구현 파일 |
| --- | --- | --- | --- | --- | --- |
| 인증 | POST | `/api/auth/signup` | - | 회원가입 | `auth_router.py` |
| 인증 | POST | `/api/auth/login` | - | 로그인, JWT 쿠키 발급 | `auth_router.py` |
| 인증 | POST | `/api/auth/logout` | 필요 | 로그아웃, 쿠키 삭제 | `auth_router.py` |
| 회원 | GET | `/api/users/me` | 필요 | 내 정보 조회 (마이페이지) | `members_router.py` |
| 회원 | PUT | `/api/users/me/preferences` | 필요 | 희망 조건 수정 | `members_router.py` |
| 회원 | DELETE | `/api/users/me` | 필요 | 회원 탈퇴 | `members_router.py` |

> 앞으로 추가될 예정: 채용공고(`/api/jobs`), 지원 현황(`/api/users/me/applications`), 포트폴리오(`/api/portfolios/*`) — `docs/백엔드_개발_기능_정리.md` 참고

## 5. 인증 방식 설계 — 왜 JWT인가 (세션 방식과 비교)

인증 방식은 크게 "서버가 상태를 저장하는 방식(세션)"과 "서버가 아무것도 저장하지 않는 방식(JWT)"으로 나뉩니다.

**세션 방식 (서버가 DB/Redis에 저장)**
- 로그인 성공 시 서버가 세션ID를 발급하고, DB(또는 Redis)에 회원 정보를 저장. 클라이언트는 세션ID만 쿠키로 보관
- 장점: 로그아웃/강제 만료 시 서버에서 해당 행만 지우면 즉시 완전히 무효화됨. 쿠키가 탈취돼도 무의미한 랜덤값이라 정보 노출 없음
- 단점: 요청마다 DB 조회가 추가됨 (트래픽이 많을수록 부담)

**JWT 방식 (이 프로젝트가 선택)**
- 로그인 성공 시 회원 정보(`member_id`, `email`, `nickname`)와 만료시간을 담아 서명한 토큰을 발급, DB 조회 없이 서명 검증만으로 인증
- 장점: 서버 저장소가 필요 없어 구현이 단순, 서버를 여러 대로 늘려도 세션 공유 문제 없음
- 단점(트레이드오프): 로그아웃해도 토큰 자체는 만료시간(24시간) 전까지 유효함 (탈취 시 즉시 무효화 불가), payload는 서명만 되고 암호화는 안 되어 있어 민감정보 저장 금지, 서명키 유출 시 전체 토큰 위조 가능

**결정 이유**: 순수 보안 관점에서는 세션 방식이 더 안전합니다 (즉시 무효화 가능). 다만 라즈베리파이 2B(1GB RAM)에 Redis를 새로 얹는 부담, 소규모 프로젝트 규모를 고려해 서버 상태를 안 가져도 되는 JWT를 선택했고, 유효기간을 24시간으로 짧게 잡아 트레이드오프의 영향을 최소화했습니다.

## 6. 기능별 구현 메모

기능을 추가할 때마다 이 아래에 `### 기능명` 섹션을 하나씩 추가하세요.

### 인증 (auth_router.py)

- 비밀번호는 `bcrypt`로 해싱해서 저장, 로그인 시 `bcrypt.checkpw`로 비교
- 로그인 성공 시 JWT를 httpOnly 쿠키(`access_token`)로 전달, 유효기간 24시간, 알고리즘 `HS256`
- 이메일 존재 여부가 드러나지 않도록, 이메일 없음/비밀번호 틀림을 구분하지 않고 동일한 401(`INVALID_CREDENTIALS`)로 응답

### 회원 (members_router.py)

- `GET /users/me`: JWT의 `member_id`로 DB를 조회해 최신 프로필(닉네임, 희망조건, 가입일 등) 반환. 탈퇴 등으로 DB에 없으면 404
- `PUT /users/me/preferences`: 희망 직무/지역/경력/급여 수정
- `DELETE /users/me`: 회원 삭제. `member_job_apply`는 FK `ON DELETE CASCADE`라 자동으로 함께 삭제되고, 응답 시 쿠키도 삭제

## 7. 다음 단계

`docs/백엔드_개발_기능_정리.md`에서 정리한 순서대로 채용공고 API(`GET /jobs`, `PATCH /jobs/{post_id}/apply`) → 지원 현황 API → 포트폴리오 API(테이블 신규 생성 필요) 순으로 이어가면 됩니다. 각 단계가 끝나면 4번 표와 6번 메모에 내용을 추가해주세요.

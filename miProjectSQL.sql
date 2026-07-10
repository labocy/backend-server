CREATE DATABASE apply_db CHARACTER SET utf8mb4;

-- ============================
-- 1. 채용 공고 테이블 (job)
-- ============================
CREATE TABLE job (
    job_id            INT AUTO_INCREMENT PRIMARY KEY,
    source            VARCHAR(20)  NOT NULL,                   -- 플랫폼 (SARAMIN, JOBKOREA)
    job_part          VARCHAR(100),                            -- 직무
    company_name      VARCHAR(255),                            -- 회사명
    post_title        VARCHAR(500),                            -- 공고제목
    region            VARCHAR(255),                            -- 지역
    personal_history  VARCHAR(100),                            -- 경력조건
    pay               VARCHAR(255),                            -- 급여
    end_at            DATE,                                    -- 마감일
    crawled_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, -- 크롤링 날짜
    job_url           VARCHAR(1000),                           -- 링크
    post_id           VARCHAR(255) NOT NULL UNIQUE,             -- 고유번호
    apply             VARCHAR(20)  NOT NULL DEFAULT 'PENDING'   -- 지원여부 (PENDING, APPLY)
);
-- ============================
-- 2. 유저 정보 테이블 (members)
-- ============================
CREATE TABLE members (
    member_id             INT AUTO_INCREMENT PRIMARY KEY,
    job_id                INT,                                 -- job 테이블 참조 (FK 제약 없음)
    portfolio_id          INT,                                 -- portfolio 테이블 참조 (FK 제약 없음)
    email                 VARCHAR(255) NOT NULL UNIQUE,
    password              VARCHAR(255) NOT NULL,
    nickname              VARCHAR(100) NOT NULL,               -- 닉네임(영문)
    user_job_part         VARCHAR(100),                        -- 희망 직무
    user_region           VARCHAR(255),                        -- 희망 지역
    user_personal_history VARCHAR(100),                        -- 경력조건
    user_pay              VARCHAR(255)                         -- 희망 급여
);




-- ============================================
-- JOB 테이블 CRUD
-- ============================================

-- ---------- SELECT ----------

-- 전체 조회
SELECT
    job_id, source, job_part, company_name, post_title, region,
    personal_history, pay,
    end_at, crawled_at, job_url, post_id, apply
FROM job;

-- 특정 공고 1건 조회 (PK 기준)
SELECT
    job_id, source, job_part, company_name, post_title, region,
    personal_history, pay,
    end_at, crawled_at, job_url, post_id, apply
FROM job
WHERE job_id = ?;

-- 고유번호(post_id)로 조회 (중복 크롤링 체크 시 사용)
SELECT
    job_id, source, job_part, company_name, post_title, region,
    personal_history, pay,
    end_at, crawled_at, job_url, post_id, apply
FROM job
WHERE post_id = '?';

-- 플랫폼 + 직무로 조회
SELECT
    job_id, source, job_part, company_name, post_title, region,
    personal_history, pay,
    end_at, crawled_at, job_url, post_id, apply
FROM job
WHERE source = '?'
  AND job_part = '?';

-- 아직 지원 안 한 공고만 조회
SELECT
    job_id, source, job_part, company_name, post_title, region,
    personal_history, pay,
    end_at, crawled_at, job_url, post_id, apply
FROM job
WHERE apply = '?';

-- 마감일이 지나지 않은 공고만 최신순 조회
SELECT
    job_id, source, job_part, company_name, post_title, region,
    personal_history, pay,
    end_at, crawled_at, job_url, post_id, apply
FROM job
WHERE end_at >= CURDATE()
ORDER BY crawled_at DESC;


-- ---------- INSERT ----------

INSERT INTO job (
    source, job_part, company_name, post_title, region,
    personal_history, pay,
    end_at, job_url, post_id, apply
) VALUES (
    ?, ?, ?, ?, ?,
    ?, ?,
    ?, ?, ?, ?
);


-- ---------- UPDATE ----------

-- 지원 여부 변경 (지원 완료 처리)
UPDATE job
SET apply = '?'
WHERE job_id = ?;

-- 크롤링 재수행 시 정보 갱신 (post_id 기준으로 최신화)
UPDATE job
SET post_title = '?',
    pay = '?',
    end_at = '?',
    crawled_at = NOW()
WHERE post_id = '?';


-- ---------- DELETE ----------

-- 특정 공고 삭제
DELETE FROM job
WHERE job_id = ?;

-- 마감된 공고 일괄 삭제
DELETE FROM job
WHERE end_at < CURDATE();


-- ============================================
-- MEMBERS 테이블 CRUD
-- ============================================

-- ---------- SELECT ----------

-- 전체 조회
SELECT
    member_id, job_id, portfolio_id, email, password, nickname,
    user_job_part, user_region, user_personal_history,
    user_pay
FROM members;

-- 특정 회원 1건 조회 (PK 기준)
SELECT
    member_id, job_id, portfolio_id, email, password, nickname,
    user_job_part, user_region, user_personal_history,
    user_pay
FROM members
WHERE member_id = ?;

-- 이메일로 로그인 조회 (비밀번호 매칭은 애플리케이션 로직에서 해시 비교 권장)
SELECT
    member_id, job_id, portfolio_id, email, password, nickname,
    user_job_part, user_region, user_personal_history,
    user_pay
FROM members
WHERE email = '?';

-- 희망 직무/지역으로 회원 조회
SELECT
    member_id, job_id, portfolio_id, email, password, nickname,
    user_job_part, user_region, user_personal_history,
    user_pay
FROM members
WHERE user_job_part = '?'
  AND user_region = '?';

-- 특정 공고를 지원한 회원 조회 (job_id 기준)
SELECT
    member_id, job_id, portfolio_id, email, password, nickname,
    user_job_part, user_region, user_personal_history,
    user_pay
FROM members
WHERE job_id = ?;


-- ---------- INSERT ----------

INSERT INTO members (
    job_id, portfolio_id, email, password, nickname,
    user_job_part, user_region, user_personal_history,
    user_pay
) VALUES (
    ?, ?, ?, ?, ?,
    ?, ?, ?,
    ?
);


-- ---------- UPDATE ----------

-- 희망 조건 수정
UPDATE members
SET user_job_part = '?',
    user_region = '?',
    user_pay = '?'
WHERE member_id = ?;

-- 비밀번호 변경
UPDATE members
SET password = '?'
WHERE member_id = ?;

-- 지원한 공고 연결 (지원 처리 시)
UPDATE members
SET job_id = ?
WHERE member_id = ?;


-- ---------- DELETE ----------

-- 특정 회원 삭제
DELETE FROM members
WHERE member_id = ?;

-- 이메일 기준 회원 삭제
DELETE FROM members
WHERE email = '?';

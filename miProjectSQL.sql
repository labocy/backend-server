-- ============================
-- 1. 채용 공고 테이블 (job) - 전체 유저 공유, 중복 없음
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
    crawled_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    job_url           VARCHAR(1000),
    post_id           VARCHAR(255) NOT NULL UNIQUE              -- 고유번호 (중복 크롤링 방지)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================
-- 2. 유저 정보 테이블 (members)
-- ============================
CREATE TABLE members (
    member_id             INT AUTO_INCREMENT PRIMARY KEY,
    email                 VARCHAR(255) NOT NULL UNIQUE,
    password              VARCHAR(255) NOT NULL,
    nickname              VARCHAR(100) NOT NULL,
    user_job_part         VARCHAR(100),
    user_region           VARCHAR(255),
    user_personal_history VARCHAR(100),
    user_pay              VARCHAR(255),
    created_at            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================
-- 3. 유저-공고 지원 표시 테이블 (member_job_apply) 
-- ============================
CREATE TABLE member_job_apply (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    member_id   INT NOT NULL,
    job_id      INT NOT NULL,
    apply       VARCHAR(20) NOT NULL DEFAULT 'PENDING',  -- PENDING, APPLY
    applied_at  DATETIME,                                -- APPLY로 바뀐 시각
    created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_member_job (member_id, job_id),         -- 한 유저-공고 조합은 1행만
    FOREIGN KEY (member_id) REFERENCES members(member_id) ON DELETE CASCADE,
    FOREIGN KEY (job_id)    REFERENCES job(job_id)        ON DELETE CASCADE,
    INDEX idx_member_apply (member_id, apply)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;



------------------------------------------------------------
-- CRUD 문
--------------------------------------------------------------

-- [CREATE]
INSERT INTO job
    (source, job_part, company_name, post_title, region,
     personal_history, pay, end_at, job_url, post_id)
VALUES
    (@source, @job_part, @company_name, @post_title, @region,
     @personal_history, @pay, @end_at, @job_url, @post_id);

-- [READ] 단건 조회
SELECT job_id, source, job_part, company_name, post_title, region,
       personal_history, pay, end_at, crawled_at, job_url, post_id
FROM job
WHERE job_id = @job_id;

-- [READ] post_id 중복 체크
SELECT job_id, post_id
FROM job
WHERE post_id = @post_id;

-- [READ] 조건별 목록 조회 (직무/지역 필터 + 페이징)
SELECT job_id, source, job_part, company_name, post_title, region,
       personal_history, pay, end_at, crawled_at, job_url, post_id
FROM job
WHERE job_part LIKE CONCAT('%', @job_part, '%')
  AND region   LIKE CONCAT('%', @region, '%')
ORDER BY crawled_at DESC
LIMIT @limit OFFSET @offset;

-- [UPDATE]
UPDATE job
SET end_at = @end_at,
    pay = @pay
WHERE job_id = @job_id;

-- [DELETE]
DELETE FROM job
WHERE job_id = @job_id;


-----------------------------------------------------------------------------------------

-- [CREATE] password는 애플리케이션에서 해시 처리 후 대입
INSERT INTO members
    (email, password, nickname, user_job_part, user_region,
     user_personal_history, user_pay)
VALUES
    (@email, @password, @nickname, @user_job_part, @user_region,
     @user_personal_history, @user_pay);

-- [READ] 단건 조회 (password 제외)
SELECT member_id, email, nickname, user_job_part, user_region,
       user_personal_history, user_pay, created_at, updated_at
FROM members
WHERE member_id = @member_id;

-- [READ] 목록 조회 (password 제외)
SELECT member_id, email, nickname, user_job_part, user_region,
       user_personal_history, user_pay, created_at, updated_at
FROM members
ORDER BY member_id
LIMIT @limit OFFSET @offset;

-- [READ] 로그인 검증용 (password 포함하는 유일한 쿼리)
SELECT member_id, email, password, nickname, user_job_part,
       user_region, user_personal_history, user_pay
FROM members
WHERE email = @email;

-- [UPDATE] 닉네임/희망 조건 수정
UPDATE members
SET nickname = @nickname,
    user_job_part = @user_job_part,
    user_region = @user_region
WHERE member_id = @member_id;

-- [UPDATE] 비밀번호만 별도 변경
UPDATE members
SET password = @new_hashed_password
WHERE member_id = @member_id;

-- [DELETE]
DELETE FROM members
WHERE member_id = @member_id;

------------------------------------------------------------------------------------


-- [CREATE/UPDATE] 지원 표시 UPSERT
INSERT INTO member_job_apply (member_id, job_id, apply, applied_at)
VALUES (@member_id, @job_id, @apply,
        CASE WHEN @apply = 'APPLY' THEN NOW() ELSE NULL END)
ON DUPLICATE KEY UPDATE
    apply = VALUES(apply),
    applied_at = CASE WHEN VALUES(apply) = 'APPLY' THEN NOW() ELSE applied_at END;

-- [READ] 특정 유저-공고 조합의 지원 상태
SELECT id, member_id, job_id, apply, applied_at, created_at
FROM member_job_apply
WHERE member_id = @member_id AND job_id = @job_id;

-- [READ] 특정 유저의 지원 이력 전체
SELECT id, member_id, job_id, apply, applied_at, created_at
FROM member_job_apply
WHERE member_id = @member_id
ORDER BY created_at DESC
LIMIT @limit OFFSET @offset;

-- [READ] 공고 목록 + 내 지원 상태 함께 보기
SELECT
    j.job_id, j.source, j.job_part, j.company_name, j.post_title,
    j.region, j.personal_history, j.pay, j.end_at, j.crawled_at,
    j.job_url, j.post_id,
    COALESCE(mja.apply, 'PENDING') AS my_apply_status
FROM job j
LEFT JOIN member_job_apply mja
    ON mja.job_id = j.job_id AND mja.member_id = @member_id
ORDER BY j.crawled_at DESC
LIMIT @limit OFFSET @offset;

-- [UPDATE] 지원 취소 (이력은 남기고 상태만 되돌림)
UPDATE member_job_apply
SET apply = 'PENDING',
    applied_at = NULL
WHERE member_id = @member_id AND job_id = @job_id;

-- [DELETE] 지원 기록 완전 삭제
DELETE FROM member_job_apply
WHERE member_id = @member_id AND job_id = @job_id;

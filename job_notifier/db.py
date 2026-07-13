import mysql.connector
from config import DB_CONFIG, TARGET_JOB_PARTS


def get_connection():
    return mysql.connector.connect(**DB_CONFIG)


def fetch_new_jobs(last_job_id=0):
    """
    이전에 처리한 마지막 job_id 이후에 추가된 공고만 조회한다.
    last_job_id=0 (최초 실행)이면 전체 공고를 조회한다.

    ※ 크롤링은 외부에서 별도로 수행되며, 이 봇은 DB에 새로 쌓인
      공고(job_id > last_job_id)만 감지해 알린다.
      job_id가 AUTO_INCREMENT이므로 새 공고일수록 값이 크다.

    ※ job_part 매칭: 크롤러가 검색 키워드를 그대로 job_part에
      저장하므로(예: "파이썬 개발자") 정확일치가 아닌 LIKE 부분일치를
      사용한다. (API 명세서 v2.1 7장 4-1 이슈 반영)

    반환: (rows, max_job_id)
      rows       - 조회된 공고 리스트
      max_job_id - 이번에 조회된 공고 중 가장 큰 job_id
                   (다음 실행 시 last_job_id로 저장·전달)
    """
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)

    query = """
        SELECT job_id, source, job_part, company_name,
               post_title, region, personal_history, pay,
               end_at, job_url
        FROM job
        WHERE job_id > %s
    """
    params = [last_job_id]

    if TARGET_JOB_PARTS:
        # 각 키워드에 대해 부분일치 OR 조건 구성
        like_clauses = " OR ".join(["job_part LIKE %s"] * len(TARGET_JOB_PARTS))
        query += f" AND ({like_clauses})"
        params.extend([f"%{kw}%" for kw in TARGET_JOB_PARTS])

    query += " ORDER BY job_part, job_id ASC"

    cursor.execute(query, params)
    rows = cursor.fetchall()

    cursor.close()
    conn.close()

    # 다음 실행 기준점: 이번 조회분 중 최대 job_id (없으면 기존 값 유지)
    max_job_id = max((r["job_id"] for r in rows), default=last_job_id)
    return rows, max_job_id

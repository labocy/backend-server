import os
import re
import time
import urllib.parse
from datetime import date
import requests
from bs4 import BeautifulSoup
import pymysql  # pip install pymysql --break-system-packages
from dotenv import load_dotenv  # pip install python-dotenv --break-system-packages

# =========================================================
# DB 접속 정보 (.env 파일에서 불러옴 — 절대 코드에 직접 쓰지 않기)
# =========================================================
load_dotenv()

DB_CONFIG = {
    "host": os.getenv("DB_HOST", "127.0.0.1"),
    "port": int(os.getenv("DB_PORT", "3306")),
    "user": os.getenv("DB_USER"),
    "password": os.getenv("DB_PASSWORD"),
    "database": os.getenv("DB_NAME", "apply_db"),
    "charset": "utf8mb4",
}

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                  "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
}


# =========================================================
# 1. 마감일 문자열 -> DATE 변환
#    job.end_at 컬럼이 DATE 타입이라 "상시채용" 같은 문자열은 그대로 넣을 수 없음
# =========================================================
def parse_end_at(text: str):
    """
    '상시채용', '~07/31(금)' 등의 문자열을 date 객체로 변환.
    변환할 수 없으면 None (컬럼이 NULL 허용).
    """
    if not text or "상시" in text:
        return None

    match = re.search(r"(\d{1,2})\s*/\s*(\d{1,2})", text)
    if not match:
        return None

    month, day = int(match.group(1)), int(match.group(2))
    today = date.today()
    year = today.year
    try:
        end_date = date(year, month, day)
    except ValueError:
        return None

    # 마감월이 이번 달보다 훨씬 이전이면 내년 공고로 간주
    if end_date < today.replace(day=1):
        end_date = date(year + 1, month, day)
    return end_date


# =========================================================
# 2. 크롤링 함수 (requests + BeautifulSoup, 브라우저 불필요)
# =========================================================
def crawl_jobkorea(keyword, start_page=1, end_page=1):
    job_list = []
    encoded_keyword = urllib.parse.quote(keyword)
    url = f"https://www.jobkorea.co.kr/Search?stext={encoded_keyword}"

    for current_page in range(start_page, end_page + 1):
        print(f"[진행 중] {current_page} 페이지 수집 중...")
        try:
            resp = requests.get(f"{url}&Page_No={current_page}", headers=HEADERS, timeout=15)
            resp.raise_for_status()
        except requests.RequestException as e:
            print(f"[에러] {current_page} 페이지 요청 실패: {e}")
            continue

        html = resp.text
        soup = BeautifulSoup(html, 'html.parser')

        # 2026년 리뉴얼된 잡코리아 구조 (data-sentry-component 속성 기반)
        post_list = soup.select('div[data-sentry-component="CardJob"]')
        print(f"[디버그] {current_page} 페이지에서 찾은 공고 수: {len(post_list)}")

        if not post_list:
            debug_path = f"debug_page_{current_page}.html"
            with open(debug_path, "w", encoding="utf-8") as f:
                f.write(html)
            print(f"[디버그] 선택자가 안 맞는 것 같아 원본 HTML을 '{debug_path}'로 저장했습니다.")

        for post in post_list:
            try:
                title_element = post.select_one('a[data-sentry-component="Title"]')
                if not title_element:
                    continue
                post_title = title_element.get_text(strip=True)
                job_url = title_element['href']  # 이미 절대경로 URL

                match = re.search(r"/GI_Read/(\d+)", job_url)
                post_id = match.group(1) if match else ""
                if not post_id:
                    # post_id는 UNIQUE + NOT NULL 컬럼이라 값이 없으면 저장하지 않음
                    continue

                company_span = post.select_one("span.mb-5 a span")
                company_name = company_span.get_text(strip=True) if company_span else ""

                # 지역 / 직무 / 급여가 순서대로 GrayChip으로 표시됨
                chips = [c.get_text(strip=True) for c in post.select('div[data-sentry-component="GrayChip"] span.truncate')]
                region = chips[0] if len(chips) > 0 else ""
                pay = chips[2] if len(chips) > 2 else "면접 후 결정"

                career_element = post.select_one("span.flex-shrink-0.text-gray700.text-typo-c1-13")
                personal_history = career_element.get_text(strip=True) if career_element else ""

                end_at_text = "상시채용"
                for span in post.find_all("span"):
                    if "마감" in span.get_text():
                        end_at_text = span.get_text(strip=True)
                        break

                job_list.append({
                    "source": "잡코리아",
                    "post_id": post_id,
                    "job_part": keyword,
                    "company_name": company_name,
                    "post_title": post_title,
                    "region": region,
                    "personal_history": personal_history,
                    "pay": pay,
                    "end_at": parse_end_at(end_at_text),
                    "job_url": job_url
                })
            except Exception as e:
                print(f"데이터 파싱 에러: {e}")
                continue

        # 사이트에 부담을 덜 주기 위한 딜레이
        time.sleep(1.5)

    return job_list


# =========================================================
# 3. 데이터 저장 함수 (job 테이블에 직접 INSERT)
# =========================================================
def save_to_mariadb(job_list):
    if not job_list:
        print("저장할 데이터가 없습니다.")
        return

    if not DB_CONFIG["user"] or not DB_CONFIG["password"]:
        print("[에러] DB_USER / DB_PASSWORD가 설정되지 않았습니다. .env 파일을 확인하세요.")
        return

    try:
        conn = pymysql.connect(**DB_CONFIG)
    except pymysql.MySQLError as e:
        print(f"DB 연결 에러: {e}")
        return

    # crawled_at은 DEFAULT current_timestamp(), apply는 DEFAULT 'PENDING'이라
    # 최초 INSERT 시에는 값을 넣지 않고 DB 기본값을 그대로 사용
    insert_query = """
        INSERT INTO job
        (source, post_id, job_part, company_name, post_title,
         region, personal_history, pay, end_at, job_url)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        ON DUPLICATE KEY UPDATE
            post_title = VALUES(post_title),
            region = VALUES(region),
            pay = VALUES(pay),
            end_at = VALUES(end_at),
            crawled_at = CURRENT_TIMESTAMP
    """

    inserted, skipped = 0, 0
    with conn.cursor() as cursor:
        for job in job_list:
            try:
                cursor.execute(insert_query, (
                    job["source"],
                    job["post_id"],
                    job["job_part"],
                    job["company_name"],
                    job["post_title"],
                    job["region"],
                    job["personal_history"],
                    job["pay"],
                    job["end_at"],
                    job["job_url"]
                ))
                inserted += 1
            except pymysql.MySQLError as e:
                print(f"INSERT 실패 (post_id={job.get('post_id')}): {e}")
                skipped += 1
                continue

    conn.commit()
    conn.close()

    print(f"DB 저장 완료: 처리 {inserted}건 / 실패 {skipped}건")


# =========================================================
# 4. 실행부
# =========================================================
def main():
    keyword = "파이썬 개발자"
    start_page = 1   # 크롤링 시작 페이지
    end_page = 5     # 크롤링 종료 페이지 (예: 1~5페이지)

    result = crawl_jobkorea(keyword, start_page=start_page, end_page=end_page)

    if not result:
        print("⚠️ 수집된 데이터가 없습니다. 사이트 구조가 바뀌었거나 크롤링이 차단됐을 수 있습니다.")
        return

    save_to_mariadb(result)


if __name__ == "__main__":
    main()


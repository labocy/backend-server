import os

# 마지막으로 처리(알림 전송)한 job_id를 기록하는 파일
STATE_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "last_job_id.txt")


def load_last_job_id():
    """
    마지막으로 처리한 job_id를 읽어온다.
    파일이 없으면(최초 실행) 0을 반환 → 전체 공고 조회.
    """
    if not os.path.exists(STATE_FILE):
        return 0
    try:
        with open(STATE_FILE, "r") as f:
            return int(f.read().strip() or 0)
    except (ValueError, OSError):
        return 0


def save_last_job_id(job_id):
    """이번에 처리한 최대 job_id를 저장한다."""
    try:
        with open(STATE_FILE, "w") as f:
            f.write(str(job_id))
    except OSError as e:
        print(f"[ERROR] 상태 저장 실패: {e}")

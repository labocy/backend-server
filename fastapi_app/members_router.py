from fastapi import APIRouter, Depends, HTTPException, Response
from pydantic import BaseModel

from database import get_connection
from deps import get_current_member, COOKIE_NAME

router = APIRouter()


# =========================================================
# 요청 바디 스키마
# =========================================================
class PreferencesUpdateRequest(BaseModel):
    user_job_part: str | None = None
    user_region: str | None = None
    user_personal_history: str | None = None
    user_pay: str | None = None


# =========================================================
# 내 정보 조회 (마이페이지)
# =========================================================
@router.get("/users/me")
def read_me(current_member: dict = Depends(get_current_member)):
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                """
                SELECT member_id, email, nickname, user_job_part, user_region,
                       user_personal_history, user_pay, created_at, updated_at
                FROM members
                WHERE member_id = %s
                """,
                (current_member["member_id"],),
            )
            member = cursor.fetchone()
    finally:
        conn.close()

    if not member:
        # 토큰은 유효하지만(만료 전) DB에서 이미 탈퇴 처리된 경우
        raise HTTPException(
            status_code=404,
            detail={"code": "NOT_FOUND", "message": "회원 정보를 찾을 수 없습니다."},
        )

    return {"success": True, "data": member}


# =========================================================
# 희망 조건 수정
# =========================================================
@router.put("/users/me/preferences")
def update_preferences(
    body: PreferencesUpdateRequest,
    current_member: dict = Depends(get_current_member),
):
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                """
                UPDATE members
                SET user_job_part = %s,
                    user_region = %s,
                    user_personal_history = %s,
                    user_pay = %s
                WHERE member_id = %s
                """,
                (
                    body.user_job_part,
                    body.user_region,
                    body.user_personal_history,
                    body.user_pay,
                    current_member["member_id"],
                ),
            )
            conn.commit()
    finally:
        conn.close()

    return {"success": True, "data": {"message": "희망 조건이 저장되었습니다."}}


# =========================================================
# 회원 탈퇴
# =========================================================
@router.delete("/users/me")
def delete_me(response: Response, current_member: dict = Depends(get_current_member)):
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            # member_job_apply는 FK ON DELETE CASCADE라 자동으로 함께 삭제됨
            cursor.execute("DELETE FROM members WHERE member_id = %s", (current_member["member_id"],))
            conn.commit()
    finally:
        conn.close()

    response.delete_cookie(key=COOKIE_NAME, path="/")
    return {"success": True, "data": {"message": "회원 탈퇴가 완료되었습니다."}}

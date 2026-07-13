from fastapi import APIRouter, Depends, HTTPException, Response, status
from pydantic import BaseModel, EmailStr

from database import get_connection
from security import hash_password, verify_password, create_access_token
from deps import get_current_member, COOKIE_NAME

router = APIRouter()

COOKIE_MAX_AGE = 60 * 60 * 24  # 1일 (초 단위, JWT_EXPIRE_HOURS와 맞춤)


# =========================================================
# 요청 바디 스키마
# =========================================================
class SignupRequest(BaseModel):
    email: EmailStr
    password: str
    nickname: str
    user_job_part: str | None = None
    user_region: str | None = None
    user_personal_history: str | None = None
    user_pay: str | None = None


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


# =========================================================
# 회원가입
# =========================================================
@router.post("/auth/signup", status_code=status.HTTP_201_CREATED)
def signup(body: SignupRequest):
    if len(body.password) < 8:
        raise HTTPException(
            status_code=400,
            detail={"code": "INVALID_INPUT", "message": "비밀번호는 8자 이상이어야 합니다."},
        )

    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT member_id FROM members WHERE email = %s", (body.email,))
            if cursor.fetchone():
                raise HTTPException(
                    status_code=409,
                    detail={"code": "EMAIL_DUPLICATED", "message": "이미 가입된 이메일입니다."},
                )

            hashed_pw = hash_password(body.password)
            cursor.execute(
                """
                INSERT INTO members
                    (email, password, nickname, user_job_part, user_region,
                     user_personal_history, user_pay)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    body.email, hashed_pw, body.nickname,
                    body.user_job_part, body.user_region,
                    body.user_personal_history, body.user_pay,
                ),
            )
            conn.commit()
            member_id = cursor.lastrowid
    finally:
        conn.close()

    return {
        "success": True,
        "data": {"member_id": member_id, "email": body.email, "nickname": body.nickname},
    }


# =========================================================
# 로그인
# =========================================================
@router.post("/auth/login")
def login(body: LoginRequest, response: Response):
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                "SELECT member_id, email, password, nickname FROM members WHERE email = %s",
                (body.email,),
            )
            member = cursor.fetchone()
    finally:
        conn.close()

    # 이메일이 없는 경우와 비밀번호가 틀린 경우를 구분하지 않고 동일하게 응답 (계정 존재 여부 노출 방지)
    if not member or not verify_password(body.password, member["password"]):
        raise HTTPException(
            status_code=401,
            detail={"code": "INVALID_CREDENTIALS", "message": "이메일 또는 비밀번호가 일치하지 않습니다."},
        )

    token = create_access_token(member["member_id"], member["email"], member["nickname"])

    response.set_cookie(
        key=COOKIE_NAME,
        value=token,
        max_age=COOKIE_MAX_AGE,
        httponly=True,
        samesite="lax",
        # secure=True,  # HTTPS 전환 후 활성화
        path="/",
    )

    return {
        "success": True,
        "data": {
            "member_id": member["member_id"],
            "email": member["email"],
            "nickname": member["nickname"],
        },
    }


# =========================================================
# 로그아웃
# =========================================================
@router.post("/auth/logout")
def logout(response: Response, current_member: dict = Depends(get_current_member)):
    response.delete_cookie(key=COOKIE_NAME, path="/")
    return {"success": True, "data": {"message": "로그아웃 되었습니다."}}


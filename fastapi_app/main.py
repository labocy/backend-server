from fastapi import FastAPI
from auth_router import router as auth_router
from members_router import router as members_router

app = FastAPI()

app.include_router(auth_router, prefix="/api")
app.include_router(members_router, prefix="/api")


@app.get("/")
def read_root():
    return {"message": "FastAPI 서버가 정상적으로 실행 중입니다."}


@app.get("/health")
def health_check():
    return {"status": "ok"}

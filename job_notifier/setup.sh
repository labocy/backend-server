#!/usr/bin/env bash
# ============================================================
# setup.sh - 설치부터 실행까지 한 번에
#   1) 가상환경(venv) 생성 (없으면)
#   2) 의존성 설치
#   3) .env 확인 (없으면 .env.example 복사 후 안내)
#   4) 봇 실행
# 사용법: ./setup.sh
# ============================================================
set -e

# 이 스크립트가 있는 디렉터리로 이동 (어디서 실행하든 동작하도록)
cd "$(dirname "$0")"

echo "[setup] 작업 디렉터리: $(pwd)"

# ---------- 1) 가상환경 ----------
if [ ! -d "venv" ]; then
    echo "[setup] 가상환경 생성 중..."
    python3 -m venv venv
else
    echo "[setup] 가상환경 이미 존재 - 건너뜀"
fi

# venv 활성화
source venv/bin/activate

# ---------- 2) 의존성 설치 ----------
echo "[setup] 의존성 설치 중..."
pip install --upgrade pip >/dev/null
pip install -r requirements.txt

# ---------- 3) .env 확인 ----------
if [ ! -f ".env" ]; then
    echo "[setup] .env 파일이 없습니다. .env.example을 복사합니다."
    cp .env.example .env
    echo ""
    echo "  ⚠️  .env 파일을 열어 DISCORD_TOKEN, CHANNEL_ID, DB 정보를 입력한 뒤"
    echo "      다시 ./setup.sh 를 실행하세요."
    echo "      편집:  nano .env"
    echo ""
    exit 0
fi

# ---------- 4) 실행 ----------
echo "[setup] 봇을 실행합니다. (종료: Ctrl+C)"
python3 bot.py

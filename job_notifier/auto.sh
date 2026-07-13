#!/usr/bin/env bash
# ============================================================
# auto.sh - 프로그램이 정지되면 자동으로 다시 실행
#   봇이 어떤 이유로든 종료되면 잠시 후 다시 실행한다.
#   (설치는 하지 않음. 최초 설치는 setup.sh로 먼저 진행)
# 사용법: ./auto.sh
#   중지: Ctrl+C (감시 루프까지 완전히 종료)
# ============================================================
set -e

cd "$(dirname "$0")"

# 가상환경 확인
if [ ! -d "venv" ]; then
    echo "[auto] venv가 없습니다. 먼저 ./setup.sh 를 실행하세요."
    exit 1
fi

# .env 확인
if [ ! -f ".env" ]; then
    echo "[auto] .env가 없습니다. 먼저 ./setup.sh 로 설정을 완료하세요."
    exit 1
fi

source venv/bin/activate

RESTART_DELAY=5   # 재시작 대기 시간(초)

echo "[auto] 자동 재시작 감시를 시작합니다. (중지: Ctrl+C)"

# Ctrl+C 시 루프까지 확실히 종료
trap 'echo ""; echo "[auto] 감시 루프를 종료합니다."; exit 0' INT TERM

while true; do
    echo "[auto] $(date "+%Y-%m-%d %H:%M:%S") 봇 실행"
    python3 bot.py || true      # 봇이 오류로 죽어도 루프는 계속
    echo "[auto] 봇이 종료됨. ${RESTART_DELAY}초 후 재시작..."
    sleep "$RESTART_DELAY"
done

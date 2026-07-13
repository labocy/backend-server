#!/usr/bin/env bash
# 원터치 실행 스크립트
# 1) 가상환경 생성/활성화 -> 2) 패키지 설치 -> 3) 크롤링 프로그램 실행
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

VENV_DIR="$SCRIPT_DIR/venv"
PYTHON_FILE="crawl3.py"

# 1) 가상환경이 없으면 생성
if [ ! -d "$VENV_DIR" ]; then
    echo "[INFO] 가상환경이 없어 새로 생성합니다: $VENV_DIR"
    python3 -m venv "$VENV_DIR"
fi

# 2) 가상환경 활성화
source "$VENV_DIR/bin/activate"

# 3) .env 파일 존재 확인 (없으면 DB 접속 정보가 없어 실행이 실패함)
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo "[경고] .env 파일이 없습니다. .env.example을 참고해서 .env를 먼저 만들어주세요."
    deactivate
    exit 1
fi

# 4) 필요한 패키지 설치 (requirements.txt 기준)
echo "[INFO] 패키지를 설치합니다..."
pip install --upgrade pip --quiet
pip install -r requirements.txt --quiet

# 5) 크롤링 프로그램 실행
echo "[INFO] 크롤링 프로그램을 실행합니다..."
python "$PYTHON_FILE"

deactivate
echo "[INFO] 실행이 완료되었습니다."


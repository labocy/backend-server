#!/usr/bin/env bash
# ============================================================
# reset.sh - 저장 기록을 초기화해 '처음 상태'로 되돌린다
#   last_job_id.txt를 삭제하면 다음 실행 때 전체 공고를 다시 발송한다.
# 사용법: ./reset.sh
# ============================================================
set -e

cd "$(dirname "$0")"

STATE_FILE="last_job_id.txt"

if [ -f "$STATE_FILE" ]; then
    rm -f "$STATE_FILE"
    echo "[reset] $STATE_FILE 삭제 완료 - 다음 실행 시 전체 공고를 다시 발송합니다."
else
    echo "[reset] $STATE_FILE 이(가) 없습니다. 이미 초기 상태입니다."
fi

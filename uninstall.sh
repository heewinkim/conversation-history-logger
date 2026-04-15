#!/bin/bash
# conversation-history-logger/uninstall.sh
#
# Claude Code 대화 히스토리 로거 제거 스크립트
# 사용법: bash uninstall.sh

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
RESET='\033[0m'

# ───────────────────────────────────────────────
# settings.json 에서 훅 제거
# ───────────────────────────────────────────────
deregister_hooks() {
  local SETTINGS="$1"

  [ -f "$SETTINGS" ] || return 0

  python3 - "$SETTINGS" << 'PYEOF'
import sys, json, os

settings_path = sys.argv[1]

with open(settings_path, 'r') as f:
    try:
        settings = json.load(f)
    except json.JSONDecodeError:
        print("  settings.json 파싱 실패, 건너뜀")
        sys.exit(0)

hooks = settings.get('hooks', {})

def is_history_logger(cmd):
    return 'history_logger' in cmd or 'log-history.sh' in cmd

removed = 0
for event in list(hooks.keys()):
    before = len(hooks[event])
    hooks[event] = [
        g for g in hooks[event]
        if not any(is_history_logger(h.get('command', '')) for h in g.get('hooks', []))
    ]
    removed += before - len(hooks[event])
    if not hooks[event]:
        del hooks[event]

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
    f.write('\n')

if removed:
    print(f"  settings.json 에서 훅 {removed}개 제거: {settings_path}")
else:
    print(f"  등록된 훅 없음, 건너뜀: {settings_path}")
PYEOF
}

# ───────────────────────────────────────────────
# 전역 제거
# ───────────────────────────────────────────────
uninstall_global() {
  local HOOK_DIR="$HOME/.claude/hooks/history_logger"
  local SETTINGS="$HOME/.claude/settings.json"

  echo ""
  echo -e "${YELLOW}[전역 제거]${RESET} ~/.claude 에서 제거합니다."

  if [ -d "$HOOK_DIR" ]; then
    rm -rf "$HOOK_DIR"
    echo "  훅 디렉토리 삭제: $HOOK_DIR"
  else
    echo "  훅 디렉토리 없음, 건너뜀"
  fi

  deregister_hooks "$SETTINGS"

  echo ""
  echo -e "${GREEN}✓ 전역 제거 완료!${RESET}"
}

# ───────────────────────────────────────────────
# 로컬 제거
# ───────────────────────────────────────────────
uninstall_local() {
  local SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local PROJECT_ROOT
  PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

  local HOOK_DIR="$PROJECT_ROOT/.claude/hooks/history_logger"
  local SETTINGS="$PROJECT_ROOT/.claude/settings.json"
  local HISTORY_DIR="$PROJECT_ROOT/full_history"

  echo ""
  echo -e "${YELLOW}[로컬 제거]${RESET} 프로젝트에서 제거합니다."
  echo "  프로젝트 루트: $PROJECT_ROOT"

  if [ -d "$HOOK_DIR" ]; then
    rm -rf "$HOOK_DIR"
    echo "  훅 디렉토리 삭제: $HOOK_DIR"
  else
    echo "  훅 디렉토리 없음, 건너뜀"
  fi

  deregister_hooks "$SETTINGS"

  # full_history/ 삭제 여부 확인
  if [ -d "$HISTORY_DIR" ]; then
    echo ""
    read -r -p "  full_history/ 디렉토리도 삭제할까요? [y/N]: " DEL_HISTORY
    if [[ "$DEL_HISTORY" == "y" || "$DEL_HISTORY" == "Y" ]]; then
      rm -rf "$HISTORY_DIR"
      echo -e "  ${RED}✗ full_history/ 삭제됨${RESET}"
    else
      echo "  full_history/ 유지됨"
    fi
  fi

  echo ""
  echo -e "${GREEN}✓ 로컬 제거 완료!${RESET}"
}

# ───────────────────────────────────────────────
# 메인
# ───────────────────────────────────────────────
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${CYAN}  conversation-history-logger 제거${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo "제거 방식을 선택하세요:"
echo ""
echo -e "  ${GREEN}1)${RESET} 전역 제거  (~/.claude 에서 제거)"
echo -e "  ${GREEN}2)${RESET} 로컬 제거  (이 폴더의 상위 디렉토리 프로젝트에서 제거)"
echo ""
read -r -p "선택 [1/2]: " CHOICE

case "$CHOICE" in
  1) uninstall_global ;;
  2) uninstall_local ;;
  *)
    echo "잘못된 선택입니다. 1 또는 2를 입력하세요."
    exit 1
    ;;
esac

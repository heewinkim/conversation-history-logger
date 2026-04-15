#!/bin/bash
# conversation-history-logger/setup.sh
#
# Claude Code 대화 히스토리 로거 설치 스크립트
# 사용법: bash setup.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_SRC="$SCRIPT_DIR/hooks/log-history.sh"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# ───────────────────────────────────────────────
# settings.json 에 훅 등록 (기존 설정 보존)
# ───────────────────────────────────────────────
register_hooks() {
  local SETTINGS="$1"
  local HOOK_CMD="$2"

  mkdir -p "$(dirname "$SETTINGS")"

  python3 - "$SETTINGS" "$HOOK_CMD" << 'PYEOF'
import sys, json, os

settings_path = sys.argv[1]
hook_cmd = sys.argv[2]

if os.path.exists(settings_path):
    with open(settings_path, 'r') as f:
        try:
            settings = json.load(f)
        except json.JSONDecodeError:
            settings = {}
else:
    settings = {}

if 'hooks' not in settings:
    settings['hooks'] = {}

hooks = settings['hooks']

def is_history_logger(cmd):
    return 'history_logger' in cmd or 'log-history.sh' in cmd

# 구버전 훅 정리: UserPromptSubmit, PostToolUse에서 history_logger 제거
for event in ('UserPromptSubmit', 'PostToolUse'):
    if event in hooks:
        hooks[event] = [
            g for g in hooks[event]
            if not any(is_history_logger(h.get('command', '')) for h in g.get('hooks', []))
        ]
        if not hooks[event]:
            del hooks[event]

def already_registered(hook_list, cmd):
    for group in hook_list:
        for h in group.get('hooks', []):
            if h.get('command', '').startswith(cmd.split()[0]):
                return True
    return False

if 'Stop' not in hooks:
    hooks['Stop'] = []
if not already_registered(hooks['Stop'], hook_cmd):
    hooks['Stop'].append({
        "hooks": [{"type": "command", "command": f"{hook_cmd} stop", "async": True}]
    })

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
    f.write('\n')

print(f"  settings.json 업데이트: {settings_path}")
PYEOF
}

# ───────────────────────────────────────────────
# 전역 설치
# ───────────────────────────────────────────────
install_global() {
  local HOOK_DEST="$HOME/.claude/hooks/history_logger/log-history.sh"
  local SETTINGS="$HOME/.claude/settings.json"
  local HOOK_CMD="$HOME/.claude/hooks/history_logger/log-history.sh"

  echo ""
  echo -e "${YELLOW}[전역 설치]${RESET} ~/.claude 에 설치합니다."
  echo "  훅 경로   : $HOOK_DEST"
  echo "  설정 파일 : $SETTINGS"

  mkdir -p "$(dirname "$HOOK_DEST")"
  cp "$HOOK_SRC" "$HOOK_DEST"
  chmod +x "$HOOK_DEST"

  register_hooks "$SETTINGS" "$HOOK_CMD"

  echo ""
  echo -e "${GREEN}✓ 전역 설치 완료!${RESET}"
  echo "  히스토리는 각 프로젝트의 full_history/ 폴더에 저장됩니다."
  echo "  30일 이상 지난 파일은 세션 종료 시 자동으로 삭제됩니다."
}

# ───────────────────────────────────────────────
# 로컬 설치
# ───────────────────────────────────────────────
install_local() {
  local PROJECT_ROOT
  PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

  local HOOK_DEST="$PROJECT_ROOT/.claude/hooks/history_logger/log-history.sh"
  local SETTINGS="$PROJECT_ROOT/.claude/settings.json"
  local HOOK_CMD=".claude/hooks/history_logger/log-history.sh"

  echo ""
  echo -e "${YELLOW}[로컬 설치]${RESET} 프로젝트에 설치합니다."
  echo "  프로젝트 루트: $PROJECT_ROOT"
  echo "  훅 경로      : $HOOK_DEST"
  echo "  설정 파일    : $SETTINGS"

  mkdir -p "$(dirname "$HOOK_DEST")"
  cp "$HOOK_SRC" "$HOOK_DEST"
  chmod +x "$HOOK_DEST"

  register_hooks "$SETTINGS" "$HOOK_CMD"

  # .gitignore 에 full_history/ 추가 여부
  local GITIGNORE="$PROJECT_ROOT/.gitignore"
  if ! grep -qF "full_history/" "$GITIGNORE" 2>/dev/null; then
    echo ""
    read -r -p ".gitignore 에 full_history/ 를 추가할까요? [Y/n]: " ADD_GITIGNORE
    if [[ "$ADD_GITIGNORE" != "n" && "$ADD_GITIGNORE" != "N" ]]; then
      echo "" >> "$GITIGNORE"
      echo "# conversation-history-logger" >> "$GITIGNORE"
      echo "full_history/" >> "$GITIGNORE"
      echo -e "${GREEN}✓ .gitignore 에 full_history/ 추가됨${RESET}"
    fi
  fi

  echo ""
  echo -e "${GREEN}✓ 로컬 설치 완료!${RESET}"
  echo "  히스토리는 $PROJECT_ROOT/full_history/ 에 저장됩니다."
  echo "  30일 이상 지난 파일은 세션 종료 시 자동으로 삭제됩니다."
}

# ───────────────────────────────────────────────
# 메인
# ───────────────────────────────────────────────
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${CYAN}  conversation-history-logger 설치${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo "설치 방식을 선택하세요:"
echo ""
echo -e "  ${GREEN}1)${RESET} 전역 설치  (~/.claude, 모든 프로젝트에 적용)"
echo -e "  ${GREEN}2)${RESET} 로컬 설치  (이 폴더의 상위 디렉토리를 프로젝트 루트로 설치)"
echo ""
read -r -p "선택 [1/2]: " CHOICE

case "$CHOICE" in
  1) install_global ;;
  2) install_local ;;
  *)
    echo "잘못된 선택입니다. 1 또는 2를 입력하세요."
    exit 1
    ;;
esac

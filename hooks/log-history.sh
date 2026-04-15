#!/bin/bash
# conversation-history-logger/hooks/log-history.sh
#
# Claude Code 대화 히스토리를 Markdown 형식으로 기록
# Event: stop (세션 종료 시 전체 Q&A 쌍 저장)

EVENT_TYPE="$1"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
SESSION_ID="${CLAUDE_SESSION_ID:-$(date +%s%N)_$$}"
SESSION_SHORT="${SESSION_ID:0:8}"
DATE=$(date +"%Y-%m-%d")

INPUT=$(cat)

case "$EVENT_TYPE" in
  "stop")
    HISTORY_DIR="$PROJECT_DIR/full_history"
    SESSION_FILE="$HISTORY_DIR/${DATE}_${SESSION_SHORT}.md"
    mkdir -p "$HISTORY_DIR"

    CMUX_WORKSPACE=$(cmux list-workspaces 2>/dev/null | grep '^\*' | sed 's/^\* workspace:[0-9]*[[:space:]]*//' | sed 's/[[:space:]]*\[selected\].*//')

    # JSONL에서 전체 대화 추출
    JSONL_DIR="$HOME/.claude/projects"
    PROJECT_HASH=$(echo "$PROJECT_DIR" | sed 's|/|-|g')
    EXACT_JSONL="$JSONL_DIR/$PROJECT_HASH/${SESSION_ID}.jsonl"
    if [ -f "$EXACT_JSONL" ]; then
      LATEST_JSONL="$EXACT_JSONL"
    else
      LATEST_JSONL=$(ls -t "$JSONL_DIR/$PROJECT_HASH/"*.jsonl 2>/dev/null | head -1)
    fi

    [ -z "$LATEST_JSONL" ] && exit 0

    {
      echo "# Session: $DATE ($SESSION_SHORT)"
      echo ""
      echo "**Project**: $PROJECT_DIR"
      echo "**Saved**: $(date +"%Y-%m-%d %H:%M:%S")"
      echo "**Session ID**: $SESSION_ID"
      [ -n "$CMUX_WORKSPACE" ] && echo "**Workspace**: $CMUX_WORKSPACE"
      echo ""
      echo "---"

      python3 - "$LATEST_JSONL" << 'PYEOF'
import sys, json
from datetime import datetime

jsonl_file = sys.argv[1]
entries = []

try:
    with open(jsonl_file, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
                msg = entry.get('message', {})
                role = msg.get('role', '')
                if role not in ('user', 'assistant'):
                    continue

                content = msg.get('content', '')
                if isinstance(content, list):
                    texts = []
                    for c in content:
                        if isinstance(c, dict) and c.get('type') == 'text':
                            t = c.get('text', '').strip()
                            if t:
                                texts.append(t)
                    content = '\n\n'.join(texts)
                elif isinstance(content, str):
                    content = content.strip()

                if not content:
                    continue

                ts = entry.get('timestamp', '')
                if ts:
                    try:
                        dt = datetime.fromisoformat(ts.replace('Z', '+00:00'))
                        ts = dt.strftime('%H:%M:%S')
                    except:
                        ts = ''

                entries.append({'role': role, 'content': content, 'ts': ts})
            except:
                pass
except:
    pass

for e in entries:
    ts_str = f" [{e['ts']}]" if e['ts'] else ''
    if e['role'] == 'user':
        print(f"\n## 💬 User{ts_str}\n\n{e['content']}\n")
    else:
        print(f"\n## 🤖 Assistant{ts_str}\n\n{e['content']}\n")
PYEOF
    } > "$SESSION_FILE"

    # 30일 초과 히스토리 자동 정리
    find "$HISTORY_DIR" -name "*.md" -mtime +30 -delete 2>/dev/null
    ;;
esac

exit 0

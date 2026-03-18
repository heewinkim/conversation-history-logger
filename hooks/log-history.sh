#!/bin/bash
# conversation-history-logger/hooks/log-history.sh
#
# Claude Code 대화 히스토리를 Markdown 형식으로 기록
# Events: user_prompt | post_tool | stop

EVENT_TYPE="$1"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
SESSION_ID="${CLAUDE_SESSION_ID:-$(date +%s)}"
SESSION_SHORT="${SESSION_ID:0:8}"
DATE=$(date +"%Y-%m-%d")
TIMESTAMP=$(date +"%H:%M:%S")

HISTORY_DIR="$PROJECT_DIR/full_history"
SESSION_FILE="$HISTORY_DIR/${DATE}_${SESSION_SHORT}.md"

mkdir -p "$HISTORY_DIR"

# 세션 파일이 없으면 헤더 생성
if [ ! -f "$SESSION_FILE" ]; then
  cat > "$SESSION_FILE" << EOF
# Session: $DATE ($SESSION_SHORT)

**Project**: $PROJECT_DIR
**Started**: $(date +"%Y-%m-%d %H:%M:%S")
**Session ID**: $SESSION_ID

---

EOF
fi

INPUT=$(cat)

case "$EVENT_TYPE" in
  "user_prompt")
    PROMPT=$(python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('prompt', ''))
except:
    print('')
" <<< "$INPUT")
    if [ -n "$PROMPT" ]; then
      printf "\n## 💬 [%s] User\n\n%s\n\n" "$TIMESTAMP" "$PROMPT" >> "$SESSION_FILE"
    fi
    ;;

  "post_tool")
    TOOL_NAME=$(python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_name', ''))
except:
    print('')
" <<< "$INPUT")

    case "$TOOL_NAME" in
      "Bash")
        CMD=$(python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', ''))
except:
    print('')
" <<< "$INPUT")
        if [ -n "$CMD" ]; then
          printf "\n> 🔧 **[%s] Bash**\n> \`\`\`\n> %s\n> \`\`\`\n" "$TIMESTAMP" "$CMD" >> "$SESSION_FILE"
        fi
        ;;
      "Edit")
        FILE=$(python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('file_path', ''))
except:
    print('')
" <<< "$INPUT")
        if [ -n "$FILE" ]; then
          printf "\n> ✏️  **[%s] Edit**: \`%s\`\n" "$TIMESTAMP" "$FILE" >> "$SESSION_FILE"
        fi
        ;;
      "Write")
        FILE=$(python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('file_path', ''))
except:
    print('')
" <<< "$INPUT")
        if [ -n "$FILE" ]; then
          printf "\n> 📝 **[%s] Write**: \`%s\`\n" "$TIMESTAMP" "$FILE" >> "$SESSION_FILE"
        fi
        ;;
      "Read")
        FILE=$(python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('file_path', ''))
except:
    print('')
" <<< "$INPUT")
        if [ -n "$FILE" ]; then
          printf "\n> 📖 **[%s] Read**: \`%s\`\n" "$TIMESTAMP" "$FILE" >> "$SESSION_FILE"
        fi
        ;;
      "Task")
        DESC=$(python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    inp = d.get('tool_input', {})
    print(inp.get('description', inp.get('prompt', '')))
except:
    print('')
" <<< "$INPUT")
        if [ -n "$DESC" ]; then
          printf "\n> 🤖 **[%s] Task**: %s\n" "$TIMESTAMP" "$DESC" >> "$SESSION_FILE"
        fi
        ;;
      "Glob"|"Grep")
        PATTERN=$(python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    inp = d.get('tool_input', {})
    print(inp.get('pattern', inp.get('query', '')))
except:
    print('')
" <<< "$INPUT")
        if [ -n "$PATTERN" ]; then
          printf "\n> 🔍 **[%s] %s**: \`%s\`\n" "$TIMESTAMP" "$TOOL_NAME" "$PATTERN" >> "$SESSION_FILE"
        fi
        ;;
    esac
    ;;

  "stop")
    printf "\n\n---\n*🏁 Session activity ended at %s*\n" "$(date +"%Y-%m-%d %H:%M:%S")" >> "$SESSION_FILE"

    # 세션 JSONL에서 마지막 assistant 메시지 추출
    JSONL_DIR="$HOME/.claude/projects"
    PROJECT_HASH=$(echo "$PROJECT_DIR" | sed 's|/|-|g')
    LATEST_JSONL=$(ls -t "$JSONL_DIR/$PROJECT_HASH/"*.jsonl 2>/dev/null | head -1)

    if [ -n "$LATEST_JSONL" ]; then
      LAST_ASSISTANT=$(python3 -c "
import sys, json

jsonl_file = sys.argv[1]
last_msg = None
try:
    with open(jsonl_file, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
                msg = entry.get('message', {})
                if msg.get('role') == 'assistant':
                    content = msg.get('content', '')
                    if isinstance(content, list):
                        texts = [c.get('text', '') for c in content
                                 if isinstance(c, dict) and c.get('type') == 'text']
                        content = '\n'.join(texts)
                    if content:
                        last_msg = content
            except:
                pass
    if last_msg:
        print(last_msg[:2000])
except:
    pass
" "$LATEST_JSONL" 2>/dev/null)

      if [ -n "$LAST_ASSISTANT" ]; then
        printf "\n## 🤖 [%s] Assistant (마지막 응답)\n\n%s\n\n" "$TIMESTAMP" "$LAST_ASSISTANT" >> "$SESSION_FILE"
      fi
    fi
    ;;
esac

exit 0

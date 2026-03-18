# conversation-history-logger

Claude Code 대화 히스토리를 **Markdown 파일**로 자동 기록하는 훅 로거.

유저 메시지, 툴 사용 내역, 마지막 어시스턴트 응답을 세션 단위로 저장한다.

---

## 설치

```bash
# 1. 프로젝트 루트에서 클론
git clone https://github.com/heewinkim/conversation-history-logger

# 2. 설치 스크립트 실행
bash conversation-history-logger/setup.sh
```

설치 방식 선택:

| 선택 | 설명 |
|---|---|
| `1` 전역 | `~/.claude` 에 설치. 모든 프로젝트에 자동 적용 |
| `2` 로컬 | 클론한 폴더의 **상위 디렉토리**를 프로젝트 루트로 인식해 `.claude/` 에 설치 |

로컬 설치 시 디렉토리 구조:

```
my-project/                        ← 프로젝트 루트
├── conversation-history-logger/   ← 여기에 클론
│   └── setup.sh
├── .claude/                       ← 자동 생성
│   ├── settings.json              ← 훅 등록됨 (기존 내용 보존)
│   └── hooks/history_logger/
│       └── log-history.sh
└── full_history/                  ← 히스토리 저장 위치
    ├── 2026-03-18_a1b2c3d4.md
    └── ...
```

---

## 출력 형식

세션마다 `full_history/{날짜}_{세션ID}.md` 파일이 생성된다.

```markdown
# Session: 2026-03-18 (a1b2c3d4)

**Project**: /Users/hian/my-project
**Started**: 2026-03-18 10:00:00
**Session ID**: a1b2c3d4...

---

## 💬 [10:00:01] User

기능 추가해줘

> 📖 **[10:00:03] Read**: `src/main.kt`
> ✏️  **[10:00:05] Edit**: `src/main.kt`

---
*🏁 Session activity ended at 2026-03-18 10:05:00*

## 🤖 [10:05:00] Assistant (마지막 응답)

완료했습니다. ...
```

### 기록되는 툴

| 툴 | 기록 내용 |
|---|---|
| `Bash` | 실행한 명령어 |
| `Edit` | 수정한 파일 경로 |
| `Write` | 작성한 파일 경로 |
| `Read` | 읽은 파일 경로 |
| `Task` | 서브에이전트 설명 |
| `Glob` / `Grep` | 검색 패턴 |

---

## 동작 방식

Claude Code의 3가지 훅 이벤트를 사용한다.

```
UserPromptSubmit  → 유저 메시지 기록
PostToolUse       → 툴 사용 내역 기록 (비동기)
Stop              → 세션 종료 마커 + 마지막 어시스턴트 응답 기록
```

`settings.json` 수정 시 기존 훅·권한 설정은 그대로 유지되며, 중복 등록도 방지된다.

---

## 요구사항

- Claude Code
- `python3` (JSON 파싱용)

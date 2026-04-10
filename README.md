# conversation-history-logger

Claude Code 대화 히스토리를 **Markdown 파일**로 자동 기록하는 훅 로거.

세션 종료 시 유저 질문과 어시스턴트 응답을 Q&A 쌍으로 저장한다.

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
**Saved**: 2026-03-18 10:05:00
**Session ID**: a1b2c3d4...

---

## 💬 User [10:00:01]

기능 추가해줘

## 🤖 Assistant [10:05:00]

완료했습니다. ...

## 💬 User [10:06:00]

다시 이렇게 바꿔줘

## 🤖 Assistant [10:10:00]

수정했습니다. ...
```

---

## 동작 방식

Claude Code의 `Stop` 훅 이벤트만 사용한다.

```
Stop → 세션 종료 시 JSONL에서 전체 Q&A 쌍 추출 → Markdown 파일로 저장
```

`settings.json` 수정 시 기존 훅·권한 설정은 그대로 유지되며, 중복 등록도 방지된다.

---

## 요구사항

- Claude Code
- `python3` (JSONL 파싱용)

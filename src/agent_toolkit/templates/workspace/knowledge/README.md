# Knowledge Base

Persistent memory across AI sessions.

## Structure

```
knowledge/
├── learnings/general.md    # factual learnings and patterns
├── processes/              # how-to procedures (one file per topic)
└── todos/pending.md        # follow-up items
```

## Usage

```bash
agent-toolkit memory add --type learning "what you learned"
agent-toolkit memory add --type todo "follow-up item"
agent-toolkit memory search "topic"
agent-toolkit memory inject   # output all for session context
agent-toolkit memory todo     # show pending todos
```

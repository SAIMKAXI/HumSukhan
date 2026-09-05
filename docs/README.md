# HumSukhan documentation

| Document | What it is | Authority |
|---|---|---|
| [design.md](design.md) | UI and design system **as built** in v2.4.x | Descriptive — matches shipping code |
| [architecture.md](architecture.md) | A proposed architecture redesign | Aspirational — *not* the current tree |
| [instructions.md](instructions.md) | User experience, DOs/DON'Ts, and a register of bugs that actually shipped | Normative — §5.1 is binding |
| [BUILD_PROMPT.md](BUILD_PROMPT.md) | Self-contained brief to rebuild the app to v1.0.0 | Reference |

For the structure of the code as it exists today, see
`humsukhan/FEATURE_MODULE_ARCHITECTURE.md` and
`humsukhan/ENVIRONMENTAL_MONITORING_ARCHITECTURE.md`.

**Start with [instructions.md §5.1](instructions.md#51-bug-register--these-shipped-do-not-reintroduce-them).**
Fifteen defects that reached users, each written as a rule with its root cause.
It is the highest-value part of this set for anyone touching the speech stack.

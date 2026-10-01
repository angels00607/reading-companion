# Reading Companion — Codex Technical Kickoff Pack V2

V2 incorporates the decisions made after reviewing Codex's initial architecture audit.

## Put these files directly at repository root

```text
reading-companion/
├── AGENTS.md
├── README_KICKOFF.md
└── docs/
    ├── MASTER_SPEC.md
    ├── PRODUCT_RULES.md
    ├── DESIGN_SYSTEM.md
    ├── DATA_MODEL.md
    ├── ARCHITECTURE.md
    ├── CHALLENGE_CATALOG.md
    └── IMPLEMENTATION_PLAN.md
```

Do **not** commit the outer ZIP/folder as a nested directory.

## Next
1. Replace V1 kickoff files with V2.
2. Commit and push.
3. Send Codex the `V2 — Audit closure prompt` at the end of `docs/IMPLEMENTATION_PLAN.md`.
4. Codex returns an ADR only; no code.
5. Review ADR before authorizing Phase 0.

Suggested commit:
`docs: finalize post-audit decisions and challenge catalog`

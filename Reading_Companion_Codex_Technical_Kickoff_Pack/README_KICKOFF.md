# Reading Companion --- Codex Technical Kickoff Pack

Place these files at the root of the `reading-companion` repository:

``` text
reading-companion/
├── AGENTS.md
├── README_KICKOFF.md
└── docs/
    ├── MASTER_SPEC.md
    ├── PRODUCT_RULES.md
    ├── DESIGN_SYSTEM.md
    ├── DATA_MODEL.md
    ├── ARCHITECTURE.md
    └── IMPLEMENTATION_PLAN.md
```

## What to do next

1.  Commit these files to the repository.
2.  Open the repository in Codex.
3.  Give Codex the **First Codex prompt** at the end of
    `docs/IMPLEMENTATION_PLAN.md`.
4.  Do **not** ask it to build the whole app yet.
5.  Review its architecture proposal before starting Phase 0.

`AGENTS.md` contains non-negotiable rules.\
`docs/MASTER_SPEC.md` is the product source of truth.\
`docs/ARCHITECTURE.md` and `docs/DATA_MODEL.md` are architecture inputs
that Codex must validate, not permission to override the Master Spec.

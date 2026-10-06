# Phase 5 — Challenges

Branch: `codex/phase-5-challenges`; authoritative starting main: `61ef0cafc885a28d1d6b284abbda1dc8eb4d3e25`.

Implementation and validation are in progress. No merge or Phase 6 is authorized.

## Acceptance criteria

- Immutable yearly configuration; even=A, odd=B; 2027=B.
- Nine configured types; exact authoritative catalog strings and stable missing slots.
- Independent occupancy, explicit idempotent confirmation, >=70% reliable-evidence proposals, exact compact percentage, one best candidate, reject without reason, next best, material-evidence suppression.
- Manual selection without invented confidence; no implicit displacement.
- Seasonal/Monthly finish-month eligibility; city-only Around the World; Alphabet articles and two-per-Series constraint.
- ISO Monday–Sunday finish-date placement and same-week replacement; completion-only 100 numbered slots.
- Durable offline archive/decisions, owner-scoped additive migrations/outbox, shared Attention and independent Journal component/corrections.
- Light Standard, Dark Standard and Accessibility XXXL visual evidence; no old audit suppression.

## Unresolved catalog and technical boundaries

- Archetype B #10: TBD — DO NOT INFER; identity preserved.
- December B #2/#3: TBD — DO NOT INFER; Winter Sport remains #1.
- Reading Roulette: ten unavailable slots; catalog TBD — DO NOT INFER.
- 52 Weeks rewards: TBD; no XP invented.
- 100 Books rewards: TBD; no XP invented.
- Production semantic matcher and Ask Assistant provider/model remain unavailable injection boundaries. No fabricated analysis or automatic semantic confirmation.
- Full sync/restore, Quests, Gamification, Stats and notification delivery remain later phases.

The user explicitly approved preserving ISO week 53 as unconfigured and date-only finish ties without automatic selection. A manual same-week choice remains available for configured weeks. Finish dates are date-only; operational timestamps are not substituted for chronology.

Historical imported readings never generate automatic proposals, placements, notification or reward cascades. Explicit manual historical assignment remains user-authoritative where finish-date eligibility is known.

Existing Foundation findings remain visible and deferred to Phase 12. No physical-device/VoiceOver certification is claimed.

## Validation

Local SQLite: 17 baseline + 3 Books + 7 additive Challenges tests pass.
Swift, iOS, Supabase/RLS, native acceptance flows and visual boards: pending CI.

## Implementation notes

The catalog resource is copied from `CHALLENGE_CATALOG.md`, retaining Archetype B’s 21 numbered slots including the gap. Generic unavailable UI preserves slot keys; no internal TBD instructions are presented as prompt content.

Snapshots reuse Foundation tables. SQLite v6 and Supabase `202610060001_challenges.sql` preserve all old migrations/data, add analysis/rejection provenance and a general persistent `attention_items` table using the existing category model. Raw cloud mutations remain denied pending Phase 9 command transport.

Confirmed Challenge assignments make only the Challenges Journal component ready. Copied payload changes enter existing `journal_corrections`; Book Review readiness is independent. No second Journal Session is introduced.

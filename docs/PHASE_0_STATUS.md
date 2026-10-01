# Phase 0 — Foundations

Scope: foundations only; no feature-rich screens, live providers, AI, imports,
backup UI, challenge matching engine or gamification engine.
The approved V2 documents remain authoritative.

## Implemented
- Swift package boundaries: ReadingDomain, ReadingData and ReadingUI.
- SwiftUI five-tab preview shell and Light/Dark semantic tokens.
- To Read membership separate from reading occurrences; explicit finish, DNF/resume,
  historical-import suppression, user-only Format and unknown/rating states.
- Date-only Gregorian values and ISO-week keys; immutable yearly snapshot types.
- Provenance/review primitives, reward merge semantics and stable mutation IDs.
- GRDB migration and account-scoped store: Book and outbox commit/rollback together.
- Sequential outbox coordinator; conflicts block later commands across retries.
- Supabase schema/RLS and a minimal book.create RPC proving command authorization,
  generation checks, receipts and transactional change-log writes.
- Keychain credential boundary, deployment configuration and redacted event logging.
- SQLite, native invariant/repository/sync and Supabase RLS test infrastructure.

## Validation
Windows SQLite migration checks: 8 tests passed.
Native Swift/GRDB compilation, iOS build, Supabase integration tests and visual/accessibility
checks require the CI/Mac environment and are not claimed as passed here.
Phase 0 exit gate remains open until those required checks pass.

## Engineering baselines
Swift 6 / Xcode 16+, iOS 17+, GRDB 7.0.0 pinned; XcodeGen generates the app project.
No production cloud resources or Apple capabilities have been provisioned.
The Sign in with Apple direction is retained through the account-session boundary;
the native authorization/onboarding flow is deferred to its feature phase.

## Deliberate scaffolding limits
The cloud transport supports book.create only. Pull application, lifecycle commands,
conflict-resolution UI, retries with scheduling/backoff and restore generation rotation
are future integrations. Unsupported commands fail closed.
The foundational schema is incremental; subsequent phase migrations add Series,
Stats, Quests and full Journal features rather than inventing their implementation now.
No provider can supply Journal Format. A portable restore may preserve explicitly
user-chosen Format as stored data; the provider-setting command cannot set it.
No Challenge TBD content is seeded or inferred.
GitHub backup authentication, AI, reward balancing and push delivery remain deferred.

## Assets and acceptance
Font binaries were not supplied. Registration/font-role wiring is present; approved,
licensed assets and PostScript-name verification are needed for typography visual QA.
No screenshot or device QA is claimed.
Phase 1 or any broader feature work requires review and explicit authorization.

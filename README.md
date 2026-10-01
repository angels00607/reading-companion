# Reading Companion

Native iPhone app foundations. Phase 0 only.
Read AGENTS.md and all docs before changing implementation.

## Native checks (Mac)
Requirements: Xcode 16+, Swift 6, XcodeGen.

```sh
swift test
xcodegen generate
xcodebuild -project ReadingCompanion.xcodeproj -scheme ReadingCompanion -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

## Database checks
```sh
python3 scripts/test_local_schema.py
supabase start
supabase db reset
supabase test db
```

These Supabase commands target the disposable local development stack, not production.
Never apply reset against a remote project.

See docs/PHASE_0_STATUS.md for implementation boundaries and unverified exit gates.
The app currently displays only the five-tab foundation preview.

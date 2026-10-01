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

## Simulator acceptance (Mac)
Set `READING_SIMULATOR_ID` to an available iPhone UDID from `xcrun simctl list devices available`.
After generating the project:

```sh
xcrun simctl bootstatus "$READING_SIMULATOR_ID" -b
xcrun simctl ui "$READING_SIMULATOR_ID" appearance dark
xcrun simctl ui "$READING_SIMULATOR_ID" content_size large
xcodebuild -project ReadingCompanion.xcodeproj -scheme ReadingCompanion -destination "platform=iOS Simulator,id=$READING_SIMULATOR_ID" -parallel-testing-enabled NO -resultBundlePath work/FoundationDefault.xcresult -only-testing:FoundationFontTests -only-testing:FoundationAcceptanceTests/FoundationAcceptanceTests/testLightDefault -only-testing:FoundationAcceptanceTests/FoundationAcceptanceTests/testDarkDefault -only-testing:FoundationAcceptanceTests/FoundationAcceptanceTests/testSystemFollowsSimulatorDarkAppearance CODE_SIGNING_ALLOWED=NO test
xcrun simctl ui "$READING_SIMULATOR_ID" content_size accessibility-extra-extra-extra-large
xcodebuild -project ReadingCompanion.xcodeproj -scheme ReadingCompanion -destination "platform=iOS Simulator,id=$READING_SIMULATOR_ID" -parallel-testing-enabled NO -resultBundlePath work/FoundationAccessibility.xcresult -only-testing:FoundationAcceptanceTests/FoundationAcceptanceTests/testLightAccessibilityXXXL -only-testing:FoundationAcceptanceTests/FoundationAcceptanceTests/testDarkAccessibilityXXXLLandscape CODE_SIGNING_ALLOWED=NO test
```

This runs hosted font registration and five foundation-shell accessibility scenarios.
Debug-only launch arguments force Light/Dark for QA; normal launches follow System.
See `App/Fonts/README.md` and `scripts/prepare_fonts.py` for verified font metadata
and reproducible resource generation with FontTools 4.60.2.

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

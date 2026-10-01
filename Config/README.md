# Environments
Use separate development, staging and production Supabase projects.
Do not deploy migrations to production during Phase 0.
The iOS shell does not connect to a cloud project yet.

Provide the HTTPS project URL and publishable key through deployment configuration.
Publishable keys are not authorization: RLS and database privileges enforce access.
Never embed service-role keys, Apple signing secrets, AI keys or GitHub tokens.
Account sessions belong in Keychain, isolated by account; outboxes are account-scoped.
Sign in with Apple is approved. Email OTP and guest onboarding remain deferred.

Implementation baseline: Swift 6, Xcode 16+, iOS 17+, macOS 14+ for package tests.
These are engineering baselines, not an expansion of product scope.

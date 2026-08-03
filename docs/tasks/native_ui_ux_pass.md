# Native iOS UI/UX Pass

Status: done (code/Simulator verification only)

Date: 2026-07-25

## Goal

Improve the clarity, safety, and accessibility of the existing native workout flow without changing pose analysis, rep counting, coaching, persistence, or workout-domain behavior.

## Trusted Base

- Base commit: `aa57e1196886e4ec6a633f86a9c4d53b2750fb79`
- Isolated branch: `agent/native-ui-ux-pass`
- Isolated worktree on branch `agent/native-ui-ux-pass`
- The pass must not use or modify the uncommitted changes on `agent/overnight-native-verification`.

## Selected Improvements

1. **State hierarchy and exit safety:** establish one accessible visual hierarchy for recording, processing, review, and camera-error states; require the existing controlled actions while transient session work exists.
2. **Zero/discard/rollback recovery:** give canonical zero-rep results a clear empty state, make discard confirmation phase-accurate and safely destructive, and expose the existing corrected-set rollback.
3. **Adaptive review and summary accessibility:** make review editing and multi-set results adaptive at large text sizes, with field-specific focus, clearer validation, keyboard dismissal, accessible labels, minimum touch targets, and deterministic component previews.

## Guardrails

- Keep the current `Arm set` wording and arming semantics.
- Do not redesign weak-setup override discovery without physical validation.
- Preserve immediate zero-rep discard and detected-rep confirmation semantics.
- Preserve correction order, validation rules, original analyzer evidence, and corrected-set rollback behavior.
- Preserve the transient, in-memory session-summary domain projection.
- Do not close any existing physical-device gate.

## Verification

- Compile `TrainerApp` for an arm64 iOS Simulator through `SquatTrainer.xcworkspace`.
- Run the affected package tests; run all four package suites if practical.
- Compile deterministic SwiftUI preview declarations with the app target.
- Run `git diff --check`.
- Inspect the complete diff and confirm no unrelated files or excluded repo-memory files changed.

## Result

- All three selected outcome initiatives are implemented in the app presentation layer.
- Package tests pass: `PoseCore` 4, `SquatAnalysis` 10, `TrainerCore` 53, and `TrainerRuntime` 14.
- `TrainerApp` compiles cleanly for an arm64 Simulator through the workspace; Debug compilation includes the deterministic preview declarations.
- Swift parsing and `git diff --check` pass.
- Final scope inspection shows one SwiftUI source file plus repo-memory documentation only. `.agents/`, `skills-lock.json`, draft PR #1, and the isolated overnight-verification checkout remain untouched.
- No physical acceptance gate was closed.

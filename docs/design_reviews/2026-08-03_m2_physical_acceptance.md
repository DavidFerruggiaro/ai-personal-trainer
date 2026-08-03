# M2 Consolidated Physical Acceptance Pass

Date: 2026-08-03

Status: concluded with one deferred scenario and two selected follow-ups

Branch: `codex/native-rebuild-checkpoint`

Commit under test: `5276914`

Device: iPhone 16 Pro Max (`iPhone17,2`)

## Delivery Evidence

- Full consolidated native harness passed before the device build: PoseCore 4, SquatAnalysis 10, TrainerCore 53, TrainerRuntime 19, plus both workspace Simulator builds.
- A fresh Debug device build succeeded through `ios/SquatTrainer.xcworkspace` using Xcode 16.4 and the configured Apple Development profile.
- Bundle `com.aiPersonalTrainer.TrainerApp` installed successfully on the connected iPhone.
- Initial automated launch was correctly denied until the user trusted the developer profile; the user then opened the installed app manually and confirmed that Quick Start was visible.

Delivery evidence does not close any workout-behavior or accuracy gate.

## Physical Scenarios

### 1. Normal arm, countdown, capture, Stop, processing, and review

Status: passed with one follow-up finding

Protocol:

- Start a Back Squat quick session with `0 lb`.
- Arm the set, place the phone side-on approximately 5–6 ft away, and obtain passing setup checks.
- Let the countdown start and transition into capture automatically.
- Perform three slow bodyweight squats and tap Stop.
- Observe provisional/final counts, camera removal, processing transition, and review evidence wording.

Result:

- The user completed three slow bodyweight squats at `0 lb`; finalized review reported 3 counted reps.
- The provisional live count was not separately reported, so live/final agreement is not claimed from this observation alone.
- Tapping Stop removed the camera immediately.
- Processing completed and advanced automatically to review without an observed failure.
- Review clearly presented `0 lb × 3`, `Clean reps unavailable`, the explanation that unavailable is not zero clean reps, three unassessed rep markers, and an unavailable form takeaway.
- The user characterized the path as an overall success. A supplied screenshot showed a legible standard-size review hierarchy with `Next Set` visible and no obvious clipping.
- Follow-up finding: the transition from the end of the countdown to visible recording state took approximately 9 seconds. The capture still completed successfully, but this delay is long enough to warrant a focused timing/feedback investigation. Preserve it as an open follow-up rather than treating the successful capture itself as failed.

### 2. Review corrections, validation, provenance, and load carry-forward

Status: passed

Result:

- The user corrected the reviewed set to `45 lb`, 4 counted reps, and 3 clean reps.
- Review displayed `User corrected — not analyzer evidence.`, preserving the distinction between user-entered clean results and analyzer evidence.
- Attempting to set 5 clean reps while counted reps remained 4 produced the expected `clean reps cannot exceed counted reps` validation error.
- After restoring the valid correction, `Next Set` defaulted the following set load to `45 lb`.

### 3. Active and reviewed-set discard behavior

Status: passed with two UI follow-up findings

Result:

- During Set 2 at the carried-forward `45 lb`, the user armed capture and discarded before performing a rep.
- Zero-rep active discard was immediate: no confirmation alert appeared, the camera closed, and the app preserved the current set ordinal and `45 lb` load for retry.
- Follow-up finding: the expected `Capture discarded` recovery notice did not appear. The destructive action and rollback behaved correctly, but the missing visible acknowledgement weakens recovery clarity.
- On a subsequent active capture with detected provisional reps, `Discard` presented the expected confirmation. Cancelling preserved recording; confirming the second request closed the camera and preserved the current set/load for retry.
- The `Capture discarded` notice appeared after the confirmed detected-rep discard. The supplied screenshot shows it on the Set 3 setup screen at `45 lb`.
- Visual-hierarchy follow-up: the recovery notice is not distinct enough from the surrounding full-width cards to reliably draw the user's eye.
- Phase-relevance follow-up: the large `Set setup` status block is redundant after discard has already returned the user to the setup form and need not remain on that screen in a future hierarchy pass.
- The user then finalized a new Set 3, corrected it to `50 lb`, 2 counted reps, and 1 clean rep, and discarded it from review.
- Review discard returned to Set 3 rather than advancing to Set 4, restored the corrected `50 lb` load, reduced the completed-set count from 3 back to 2, removed the result from the workout, and displayed `Corrected set discarded`.
- All M2.12 physical behavior paths passed. The missing zero-rep notice on one attempt and the broader visual-hierarchy/phase-relevance notes remain UX follow-ups.

### 4. Weak-setup override and low-confidence review

Status: failed physical acceptance — override is not reachable in the intended solo flow

Result:

- The current `Setup looks weak — other options` control exists before `Arm set` and only while every check is evaluated and at least one check is failing.
- In the intended solo-gym flow, the user must leave the phone to enter frame. If checks then fail, walking back to interact with the phone changes the live evidence in real time, so the conditional override can disappear before it can be selected.
- After `Arm set`, the waiting UI exposes only `Cancel`; it does not expose the weak-setup override while the user is in the armed waiting state.
- The user had never seen the conditional control during normal physical use. This validates that code reachability is not equivalent to usable reachability.
- Do not force the test through an artificial multi-person or contorted setup. The override interaction needs redesign around the same solo-use constraint that motivated `Arm set`.
- Consequently, physical low-confidence review labeling remains unverified even though the offline rendering path exists.

### 5. Multi-set summary and Done

Status: deferred by user until the next natural multi-set workout

Result:

- The current ad hoc session no longer exposed the summary state, and recreating several sets solely for acceptance testing was becoming cumbersome.
- The user explicitly chose to move on and retest the summary during a future session that naturally contains several sets.
- This is deferred, not failed. M2.14 remains `in_progress`; its physical summary-row, totals, provenance, discarded-set exclusion, and `Done` checks stay open.

## Acceptance Audit

- M2.5 remains `in_progress`. Normal propped-phone arming works, but the conditional pre-arm weak-setup override is not usable in the intended solo flow.
- M2.6 remains `in_progress`. Deliberate arming, automatic countdown, and automatic transition work, but duration choices remain unimplemented and the approximately 9-second post-countdown transition needs investigation.
- M2.7 is closed as `done`: prior physical evidence covers analyzer-backed provisional counting, and this pass confirms automatic active capture, Stop, both active-discard paths, and the absence of a pause path.
- M2.9 is closed as `done`: Stop removed the camera immediately, processing completed, review opened automatically, and no explicit save was required.
- M2.10 remains `in_progress`: normal review passed physically, but required clean gates remain unimplemented and low-confidence override review is still physically unverified.
- M2.11 remains `done`; its physical correction, validation, provenance, load-carry, and corrected-discard follow-up all passed.
- M2.12 is closed as `done`: zero-rep active discard, detected-rep confirmation/cancel/confirm, and corrected review rollback all passed.
- M2.14 remains `in_progress`; its physical multi-set summary check is deferred until a natural multi-set session.

## Selected Follow-up

The next implementation slice is **M2.5b: reachable armed weak-setup recovery for a solo lifter**. It should preserve the deliberate `Arm set` interaction, latch an evaluated weak-setup decision after arming, and provide a persistent retry/start-anyway choice that remains reachable when the user returns to the phone. It must not silently override failures or require another person.

The approximately 9-second countdown-to-visible-recording delay is the next M2.6 investigation after M2.5b. The missing zero-rep notice on one attempt and the recovery-card/setup-card hierarchy notes remain presentation follow-ups rather than new scope for M2.5b.

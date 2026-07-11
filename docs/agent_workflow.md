# Agent Workflow

Last updated: 2026-07-11

This document templates a lightweight GStack/GBrain-inspired workflow for this repo. It does not require GStack or GBrain to be installed yet.

Use this as the operating rhythm for future agents and implementation sessions.

## Workflow Principles

- Product truth first: know what user experience the code is serving.
- Engineering evidence second: verify with small tests, real clips, and clear acceptance criteria.
- Memory always: capture decisions and results so future agents do not restart the conversation.
- Scope discipline: do not widen the product before the core tracking loop is trustworthy.

## Standard Agent Loop

1. Read context.
   - `docs/native_rebuild_agent_handoff.md`
   - `docs/rebuild_product_spec.md`
   - `docs/pose_bakeoff_plan.md`
   - `docs/decision_log.md`
   - `docs/tasks/M2_back_squat_vertical_slice_tasks.md`
   - `docs/design_reviews/2026-07-11_post_m2_11_roadmap_review.md`

2. Identify the current milestone.
   - Default current milestone: **Milestone 2, Back Squat Vertical Slice** (M1 bakeoff complete; MediaPipe selected).
   - Current code boundary: M2.11 essential corrections is complete; M2.9/M2.10/M2.12 and parts of M2.5-M2.7 retain documented physical or product gates.
   - Do not infer a next implementation ticket from ticket number alone. Read `docs/design_reviews/2026-07-11_post_m2_11_roadmap_review.md` and get the user's scope choice.

3. Pick one small ticket.
   - Prefer the next ticket in `docs/native_rebuild_agent_handoff.md` / `docs/tasks/M2_back_squat_vertical_slice_tasks.md`.
   - Keep engine-specific code behind shared live-pose / estimator boundaries.

4. Implement narrowly.
   - Keep shared code in `ios/Packages`.
   - Keep app/debug UI in `ios/PoseBakeoff` or `ios/TrainerApp`.
   - Preserve Python prototype unless explicitly changing it.

5. Verify.
   - Run the smallest relevant checks.
   - For Swift packages, use `swift test --package-path ...`.
   - For `TrainerApp`, always build through `ios/SquatTrainer.xcworkspace`, never the project directly.
   - For Python prototype changes, run the relevant existing manual or scripted checks.

6. Review through roles.
   - Product: does this preserve the user experience and trust promise?
   - Staff engineer: is this scoped, testable, and aligned with architecture?
   - QA: what could fail in a real gym clip?
   - Release/documentation: what needs to be recorded for the next agent?

7. Update memory.
   - Append important decisions to `docs/decision_log.md`.
   - Update the handoff/spec if the source of truth changed.
   - Update the active task result and test counts.
   - Ask before committing; exclude `.agents/` and `skills-lock.json` unless explicitly requested.

## Role Prompts

Use these as lightweight review passes.

### Product Co-Founder Review

Ask:

- Does this make the app more trustworthy during real lifting?
- Does it keep the user flow fast in a commercial gym?
- Does it avoid overclaiming what pose data can know?
- Does it preserve v1 focus on side-view back squat?

### Staff Engineer Review

Ask:

- Is the code in the right layer?
- Does engine-specific code stay behind `PoseEstimator`?
- Does UI avoid owning analysis logic?
- Is the change small enough to verify?
- Are heavy artifacts kept outside structured app records?

### QA Review

Ask:

- What happens with bad framing, low confidence, occlusion, or poor lighting?
- Does the app fail gracefully?
- Can the user discard accidental sets?
- Is low-confidence data labeled instead of silently trusted?

### Documentation Review

Ask:

- Did this change a locked decision?
- Does the handoff need an update?
- Should a decision log entry be added?
- Can a new agent understand the next step?

## GStack/GBrain Installation Plan

Do not install these remotely from a phone unless the user explicitly asks and is available to handle prompts.

When the user is back at the computer, evaluate installing:

```bash
git clone https://github.com/garrytan/gstack.git ~/.codex/skills/gstack
cd ~/.codex/skills/gstack
./setup --host codex
```

For GBrain:

```bash
bun install -g github:garrytan/gbrain
gbrain init --pglite
gbrain doctor
gbrain import docs/
```

Use GStack/GBrain for development workflow and memory only. They are not part of the mobile app runtime.

## Memory Candidates

When GBrain is available, import or capture:

- Product spec.
- Pose bakeoff plan.
- Agent handoff.
- Decision log.
- Milestone ticket results.
- Bakeoff exported JSON summaries.
- Engine-selection write-up.
- Toolchain setup notes.

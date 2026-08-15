# Agent Build System Plan

Last updated: 2026-07-26

## Purpose

This document defines the system for building the app with agents. It is inspired by Ryan Carson's public agent workflow ideas, GStack/GBrain-style memory, and Ralph-loop style repeated execution.

The premise:

> Build the system that builds the MVP first.

For this project, that means turning product thinking, specs, decisions, task lists, verification, and review into durable repo artifacts that future agents can read and execute.

## What We Are Applying

### 1. PRD -> Tasks -> Iteration

Use a strict sequence:

1. Capture the product decision in docs.
2. Convert it into implementation tickets.
3. Execute one ticket at a time.
4. Verify.
5. Update docs and decision log.

This maps directly to Ryan Carson's AI Dev Tasks pattern: create a PRD, generate atomic actionable tasks, then iterate on tasks one at a time.

### 2. Fresh-Context Work

Long agent sessions drift. Persistent state should live in files, not chat memory.

Every new agent should be able to restart from:

- `AGENTS.md`
- `docs/native_rebuild_agent_handoff.md`
- `docs/rebuild_product_spec.md`
- `docs/pose_bakeoff_plan.md`
- `docs/agent_workflow.md`
- `docs/decision_log.md`
- `docs/tasks/M2_back_squat_vertical_slice_tasks.md`
- `docs/design_reviews/2026-07-11_post_m2_11_roadmap_review.md`
- `docs/design_reviews/2026-07-24_native_verification_harness.md`

The repo should be the brain. Chat is temporary.

### 3. Atomic Tickets With Acceptance Criteria

Each build task should be small enough that an agent can complete, verify, and document it independently.

Ticket shape:

```md
## Ticket ID: M1.x

Goal:

Context:

Tasks:

Acceptance criteria:

Verification commands:

Files likely touched:

Documentation updates:
```

Avoid vague tickets like "build app UI." Prefer tickets like "Add video picker to PoseBakeoff and show selected filename."

### 4. Role-Based Review

Each substantial change should pass four lenses:

- Product co-founder: does this serve the real gym experience?
- Staff engineer: is the code in the right layer and easy to verify?
- QA: what fails with bad clips, bad lighting, occlusion, or weird timing?
- Documentation/release: did we update the handoff and decision log?

This gives us the benefits of a small team without pretending the agent is magic.

### 5. Agent Permissions Like Employee Permissions

If OpenClaw, GBrain, GStack, or long-running agent loops are installed later, treat them like employees:

- separate credentials where possible
- least-privilege access
- no production secrets in prompts
- no broad destructive permissions by default
- human approval for app-store, cloud, billing, credentials, and destructive git actions

## Project-Specific Agent System

### Current System

Already implemented:

- `AGENTS.md`
- `docs/agent_workflow.md`
- `docs/decision_log.md`
- `docs/native_rebuild_agent_handoff.md`
- Milestone 1 ticket breakdown
- `docs/tasks/M1_pose_bakeoff_tasks.md`
- `docs/tasks/M2_back_squat_vertical_slice_tasks.md`
- Native iOS skeleton
- MediaPipe-backed live pose abstraction and `TrainerApp` camera flow
- Foundation-only `TrainerCore` with 56 tests through M2.14a/M2.13a's `SetResult` boundary
- Full-sequence finalization, durable structured auto-save, honest review, transactional correction replacement, discard rollback/deletion, and transient ended-session projection
- `TrainerRuntime` analyzer-to-domain mapping plus a deterministic synthetic package-contract scenario
- Versioned local-only `TrainerPersistence` with 10 isolated SwiftData tests and no heavy payload fields
- `scripts/verify_native_ios.sh` as the one-command baseline for all five package suites and both single-architecture workspace Simulator builds

### Missing But Planned

Add later:

- More task files as milestones become concrete.
- Optional GBrain import of `docs/`.
- Optional GStack/GBrain installation.
- Optional Ralph-style loop only after tasks and verification gates are strong enough.

## Recommended Folder Additions

```text
docs/
  tasks/
    M1_pose_bakeoff_tasks.md
    M2_back_squat_vertical_slice_tasks.md
  bakeoff_results/
    README.md
  design_reviews/
    README.md
```

Do not add automation before the task documents are clear. The loop is only as good as the spec it reads.

## Agent Loop For This Project

### Human-Guided Loop

Use now:

1. User and agent resolve a product/architecture decision.
2. Agent updates spec/handoff/decision log.
3. Agent asks the next dependency-order question.

### Build Loop

Use now:

1. Agent reads `AGENTS.md`.
2. Agent identifies next milestone ticket.
3. Agent implements only that ticket.
4. Agent runs verification.
5. Agent performs role-based review.
6. Agent updates docs and decision log.
7. Agent stops or asks for approval before the next ticket.

Xcode is installed, all five package suites pass, and both apps build through `ios/SquatTrainer.xcworkspace`. Run `scripts/verify_native_ios.sh` before handing off native changes; use `--packages-only` while iterating. The harness verifies deterministic contracts, local-store reopen behavior, and compilation, not physical restart, device behavior, or pose accuracy. Current work should still use one bounded ticket per loop because several M2 tickets retain physical gates.

### Fresh Chat Loop

Use a fresh chat when either of these is true:

- A long planning/build session has accumulated too much conversation context.
- The next unit of work is a well-defined milestone ticket with acceptance criteria.

Fresh chat start contract:

1. The user provides a narrow goal.
2. The agent reads repo docs instead of relying on chat history.
3. The agent confirms the active ticket and acceptance criteria.
4. The agent implements, verifies, updates docs, and stops.

The current fresh-chat contract is:

```text
Read the native rebuild handoff, the post-M2.11 roadmap review, and the latest verification report. Then execute one user-selected bounded ticket, preserve every documented physical gate, run the native verification harness, update repo memory, and stop.
```

Do not use a broad goal like "build the whole app." Use `/goal` for one milestone ticket or one clearly bounded vertical slice.

### Future Ralph-Style Loop

Use only after:

- Xcode builds work.
- Milestone tasks are explicit.
- Verification commands exist.
- Git workflow is clean.
- Human approval rules are clear.

Loop contract:

- One ticket per iteration.
- Fresh context each iteration.
- State persisted to docs.
- Tests/build checks required when available.
- No scope expansion without human approval.

## Guardrails

Agents must not:

- Reopen locked product decisions without user request.
- Skip the pose bakeoff and jump to polished TrainerApp UI.
- Add backend/cloud/account systems to v1.
- Turn the app into a generic workout logger.
- Claim form accuracy that the camera cannot support.
- Store heavy video/pose streams in structured app records.
- Run destructive commands without explicit approval.

## Near-Term Action Plan

1. Continue from the locally finalized M2.V1 work on `agent/overnight-native-verification`; it starts from checkpoint `aa57e11` and intentionally excludes `.agents/` and `skills-lock.json`.
2. At the next device session, close or update the physical gates for M2.5-M2.7, M2.9, M2.10, M2.11 UI, M2.12, and the parent M2.14 summary.
3. For offline work, choose exactly one bounded ticket from `docs/design_reviews/2026-07-11_post_m2_11_roadmap_review.md`. M2.11a atomic edits remain the next listed code-hardening option; do not start it without a new user choice.
4. Run `scripts/verify_native_ios.sh` for the five Swift package suites and both workspace Simulator builds.
5. Update the task file, handoff, README, decision log, and applicable review report.
6. Stop and ask before the next ticket.

Do not start an unattended Ralph-style loop while the working tree is large, physical gates are open, or the next ticket has not been chosen by the user.

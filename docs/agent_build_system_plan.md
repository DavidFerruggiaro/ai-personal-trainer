# Agent Build System Plan

Last updated: 2026-05-24

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

Use once Xcode is installed:

1. Agent reads `AGENTS.md`.
2. Agent identifies next milestone ticket.
3. Agent implements only that ticket.
4. Agent runs verification.
5. Agent performs role-based review.
6. Agent updates docs and decision log.
7. Agent stops or asks for approval before the next ticket.

Use this loop now. Xcode is installed, the native harness builds, and M1 tickets have enough structure to execute one at a time.

### Fresh Chat Loop

Use a fresh chat when either of these is true:

- A long planning/build session has accumulated too much conversation context.
- The next unit of work is a well-defined milestone ticket with acceptance criteria.

Fresh chat start contract:

1. The user provides a narrow goal.
2. The agent reads repo docs instead of relying on chat history.
3. The agent confirms the active ticket and acceptance criteria.
4. The agent implements, verifies, updates docs, and stops.

The best current fresh-chat goal is:

```text
Complete M1.10 manual labels and scoring for side-view squat clips.
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

1. Start a fresh chat for M1.10.
2. Use `/goal` if available to anchor the work around one ticket.
3. Build the manual label schema and first scoring loop.
4. Verify against the existing in-app MediaPipe export artifacts.
5. Update the handoff, task file, decision log, and bakeoff results.
6. Run the standard verification commands.
7. Only then decide whether to expand the labeled dataset or move to live camera viability.

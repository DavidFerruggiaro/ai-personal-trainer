# Agent Instructions

This repo contains the current Python/Streamlit squat MVP and the planned native iOS rebuild.

## Start Here

Before making architecture or product changes, read these files in order:

1. `docs/native_rebuild_agent_handoff.md`
2. `docs/rebuild_product_spec.md`
3. `docs/pose_bakeoff_plan.md`
4. `docs/agent_workflow.md`
5. `docs/agent_build_system_plan.md`
6. `docs/decision_log.md`

The handoff document is the source of truth for current state, locked decisions, open questions, and next implementation steps.

Executable milestone tasks live in `docs/tasks/`. Prefer those task files when choosing implementation work.

## Role

Act as a staff software engineer and product-minded co-founder.

Protect the product from two failure modes:

- Building a beautiful app on untrustworthy pose data.
- Building an impressive technical demo that is too noisy or awkward to use during real lifting.

The right first version is narrow, honest, and trustworthy.

## Locked Direction

Do not reopen locked decisions unless the user explicitly asks.

Important locked decisions:

- Native iOS first.
- Existing Python/Streamlit app remains as reference.
- Rebuild starts fresh under `ios/`.
- V1 focuses on side-view barbell back squat.
- Pose engine choice comes from a bakeoff between Apple Vision and MediaPipe.
- MediaPipe Pose Landmarker is selected for Milestone 2; Apple Vision remains a baseline comparator, not an open parallel production path.
- Tracking quality beats SDK convenience.
- V1 uses quick-start sessions only.
- V1 is local-first with no required account/cloud/backend.
- V1 separates counted reps from clean reps.
- V1 keeps real-time coaching conservative.

## Working Rules

- Keep docs current as decisions are made.
- Update task status in `docs/tasks/` when implementation work starts, blocks, or completes.
- Use the Ryan-style loop: repo docs as memory, one ticket at a time, verify, document, then continue.
- Prefer small, verifiable implementation steps.
- Do not expand exercise scope before back squat is trustworthy.
- Do not add cloud/backend work unless the user explicitly changes v1 scope.
- Do not build generic workout logging before analysis is reliable.
- Do not store full videos or per-frame pose streams inside structured app records.
- Preserve the current Python prototype unless explicitly asked to refactor or remove it.

## If GStack/GBrain Are Installed Later

If GStack or GBrain are installed, use them as workflow/memory tools only. Do not integrate them into the mobile app runtime.

Recommended use:

- Search project memory before architecture changes.
- Capture decisions after design sessions.
- Run role-based review passes before and after major implementation changes.
- Store bakeoff results and engine-selection rationale.

See `docs/agent_workflow.md` for the repo-local version of that process.
See `docs/agent_build_system_plan.md` for the longer-term plan to make agents execute this rebuild reliably.

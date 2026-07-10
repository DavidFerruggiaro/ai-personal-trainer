# Next Chat Prompt: M1.10 Manual Labels And Scoring

Use this prompt to start the next fresh Codex chat.

```text
/goal Complete M1.10 manual labels and scoring for the side-view squat pose bakeoff.

Workspace:
/Users/lab/AI_Lab/projects/ai_personal_trainer/squat_mvp

Role:
Act as a staff software engineer and product-minded co-founder. Use the Ryan-style build system: repo docs are memory, one ticket at a time, verify, document, then continue. Do not rely on prior chat history.

Start by reading:
- AGENTS.md
- docs/native_rebuild_agent_handoff.md
- docs/tasks/M1_pose_bakeoff_tasks.md
- docs/bakeoff_results/2026-05-24_in_app_mediapipe/README.md
- docs/agent_build_system_plan.md
- docs/decision_log.md

Current state:
- Native iOS PoseBakeoff harness exists.
- Apple Vision baseline exists.
- Native MediaPipe is integrated through MediaPipeTasksVision and is the working engine direction.
- In-app MediaPipe exports exist for bodyweight, barbell, and goblet squat clips.
- The next active ticket is M1.10: Add Manual Labels And Scoring.

Goal for this chat:
Create the first human-editable label and scoring loop so we can evaluate MediaPipe by rep-count/form usefulness, not just visual overlay quality.

Recommended scope:
1. Define a simple JSON or YAML label schema for squat reps:
   - start_s
   - bottom_s
   - end_s
   - counted
   - clean
   - failures
2. Add an initial label file for one side-view squat clip.
3. Add a loader/scoring script or Swift package test that compares labels to an existing MediaPipe export.
4. Report counted-rep mismatch, missing/extra reps, and bottom timing error.
5. Keep it inspectable. Do not build a labeling UI yet.
6. Run verification commands.
7. Update docs/tasks/M1_pose_bakeoff_tasks.md, docs/native_rebuild_agent_handoff.md, docs/decision_log.md, and bakeoff result notes.

Guardrails:
- Do not jump to polished TrainerApp UI.
- Do not add backend/cloud/account work.
- Do not claim final form accuracy yet.
- Keep Apple Vision as a baseline comparator for now.
- Ask before expanding beyond M1.10.
```

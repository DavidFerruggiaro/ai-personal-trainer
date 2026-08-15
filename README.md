# AI Personal Trainer - Squat MVP

This repo contains two implementations:

- The original Python/Streamlit batch squat analyzer, preserved as a reference prototype.
- The active native iOS rebuild under `ios/`, focused on trustworthy live side-view barbell back-squat tracking.

Start native work with `AGENTS.md` and `docs/native_rebuild_agent_handoff.md`. Native build instructions live in `ios/README.md`.

## Python Prototype Features

- **Rep Counting**: State-machine rep detection with pose-validity, motion, and cooldown gates to suppress false positives.
- **Per-Rep Form Feedback**: After each completed rep, one concise cue covering:
  - Squat depth (knee-angle-based)
  - Torso lean angle
  - Knee valgus (cave-in detection)
- **Visual Overlays**:
  - State-colored pose skeleton (idle / countdown / active)
  - Knee-angle readout
  - Depth progress bar
  - Prominent rep counter with pulse animation
  - TTL-based per-rep feedback (no live cue spam)
- **Session Summary**: Post-workout rep table, good-form percentage, rep-quality distribution, and coaching recommendations.

## Installation

### Prerequisites

- Python 3.12
- pip

Note: This Squat MVP currently uses the legacy MediaPipe Solutions API (`mp.solutions.pose`). For compatibility, run it with Python 3.12 and `mediapipe==0.10.21` from [requirements.txt](/Users/lab/AI_Lab/projects/ai_personal_trainer/squat_mvp/requirements.txt).

### Setup

1. Navigate to the squat_mvp directory:
   ```bash
   cd squat_mvp
   ```

2. Create a virtual environment (recommended):
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

## Usage

### Running the Application

```bash
streamlit run ui/streamlit_app.py
```

Or use the entry point:
```bash
python main.py
```

The app will open in your browser at `http://localhost:8501`. Upload an `.mp4`, `.mov`, `.avi`, or `.mkv` file, then click **Analyze Video**. The app processes the video frame-by-frame, counts reps, checks form, and shows a session summary when the clip ends.

> The Python app is intentionally still a batch analyzer. The separate native `TrainerApp` now has live MediaPipe camera capture, setup gating, provisional rep counting, full-sequence finalization, review, corrections, and discard behavior.

### Recording Tips

For best results when recording your squat video:

1. **Camera Position**: Place camera at hip height
2. **Angle**: Face sideways (perpendicular to camera)
3. **Distance**: Stand 6-8 feet from camera
4. **Visibility**: Ensure full body is in frame (head to feet)
5. **Lighting**: Good lighting on your body
6. **Clothing**: Wear fitted clothing for better joint detection

## Architecture

```
squat_mvp/
├── main.py                 # Entry point
├── requirements.txt        # Dependencies
├── README.md              # This file
├── core/                  # Platform-agnostic logic
│   ├── pose_pipeline.py   # MediaPipe wrapper
│   ├── smoothing.py       # Savitzky-Golay filter
│   ├── rep_counter.py     # Rep counting state machine
│   └── form_feedback.py   # Form analysis
├── ui/                    # Streamlit UI
│   ├── streamlit_app.py   # Main application
│   ├── overlay_renderer.py # Visual overlays
│   └── camera_guidance.py # Setup instructions
├── utils/                 # Python utilities
│   ├── math_utils.py      # Geometry functions
│   └── session_logger.py  # Session tracking
├── ios/                   # Native iOS rebuild and shared Swift packages
└── docs/                  # Product, architecture, evidence, tasks, and handoff
```

### Native Rebuild Direction

The Python `core/` modules remain useful reference logic, but they are not a literal Swift specification. The locked native direction is:

- Native SwiftUI iOS first.
- MediaPipe Pose Landmarker behind app-owned pose abstractions.
- Foundation-only `TrainerCore` for session/review behavior.
- `SquatAnalysis` for production counted-rep and future clean-gate analysis.
- Local-first hybrid persistence later: SwiftData for structured records and files for heavy artifacts.

## Configuration

Adjustable settings in the sidebar:

| Setting | Default | Description |
|---------|---------|-------------|
| Smoothing Window | 5 | Landmark smoothing (higher = smoother) |
| Frame Skip | 2 | Process every Nth frame |
| Depth Threshold | 0.0 | Hip-knee offset for depth |
| Max Torso Lean | 45° | Acceptable forward lean |

## Rep Quality Tags

- **Explosive**: Rep completed in < 800ms
- **Good**: Rep completed in 800-2500ms
- **Grind**: Rep completed in > 2500ms

## Troubleshooting

### Low Detection Rate

- Improve lighting
- Adjust camera angle (side view works best)
- Wear contrasting clothing
- Reduce background clutter

### Incorrect Rep Counts

- Ensure full range of motion is visible
- Adjust depth threshold in settings
- Check that you're perpendicular to camera

### Performance Issues

- Increase frame skip setting
- Use a lower resolution video
- Close other applications

## Development

### Code Structure

- `core/` - Platform-agnostic analysis logic (pose pipeline, smoothing, rep counter, form feedback).
- `ui/` - Streamlit-specific code (upload flow, overlay renderer, camera guidance).
- `utils/` - Shared utilities (geometry helpers, session logger).

### Testing

The Python prototype still relies mainly on manual sample-video verification.

The native rebuild has automated Swift package suites:

```bash
swift test --package-path ios/Packages/PoseCore
swift test --package-path ios/Packages/SquatAnalysis
swift test --package-path ios/Packages/TrainerCore
```

Always build native apps through `ios/SquatTrainer.xcworkspace`; `TrainerCore` has 45 passing tests through M2.11.

### Roadmap

- Current milestone: native Back Squat vertical slice.
- MediaPipe is selected; portrait live feasibility and one eight-rep provisional-count run passed.
- M2.11 in-memory post-set corrections are complete and Simulator-build verified.
- Several Stop/review/discard and setup/countdown tickets retain physical-device gates.
- Persistence, history, video retention, clean-gate scoring, coaching, and exercise expansion remain later scoped work.
- See `docs/design_reviews/2026-07-11_post_m2_11_roadmap_review.md` for ranked offline code-only next steps.

## License

MIT License

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

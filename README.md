# AI Personal Trainer - Squat MVP

A real-time squat analysis application using computer vision and pose detection.

## Features

- **Rep Counting**: Accurate rep detection with state machine tracking
- **Form Feedback**: Real-time analysis of:
  - Squat depth (hip below knee)
  - Torso lean angle
  - Knee valgus (cave-in detection)
- **Visual Overlays**: 
  - Pose skeleton visualization
  - Knee angle display
  - Depth progress bar
  - Rep counter
  - Form feedback text
- **Session Summary**: Post-workout statistics and recommendations

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

The app will open in your browser at `http://localhost:8501`.

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
└── utils/                 # Utilities
    ├── math_utils.py      # Geometry functions
    └── session_logger.py  # Session tracking
```

### Mobile-Ready Design

All core modules (`/core`) are platform-agnostic with no UI dependencies. This enables:

- Future migration to React Native with native camera modules
- ONNX export for on-device inference
- Clean separation of concerns

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

### Running Tests

```bash
pytest tests/
```

### Code Structure

- `core/` - Business logic, no external dependencies except numpy/scipy
- `ui/` - Streamlit-specific code
- `utils/` - Shared utilities

## License

MIT License

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request


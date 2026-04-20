"""
Streamlit application for Squat MVP.
Main UI for video upload, analysis, and results display.
"""

import streamlit as st
import cv2
import numpy as np
import tempfile
import time
from pathlib import Path
import sys
import os

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from core.pose_pipeline import PosePipeline, LEFT_HIP, RIGHT_HIP, LEFT_KNEE, RIGHT_KNEE, LEFT_ANKLE, RIGHT_ANKLE
from core.rep_counter import RepCounter, SquatPhase
from core.form_feedback import FormFeedback, FormAnalysis
from utils.math_utils import calculate_angle
from utils.session_logger import SessionLogger, RepData
from ui.overlay_renderer import OverlayRenderer, SetState, RepFeedback
from ui.camera_guidance import CameraGuidance


# Page configuration
st.set_page_config(
    page_title="Squat MVP - AI Personal Trainer",
    page_icon="🏋️",
    layout="wide",
)


def init_session_state():
    """Initialize Streamlit session state variables."""
    if "session_active" not in st.session_state:
        st.session_state.session_active = False
    if "session_complete" not in st.session_state:
        st.session_state.session_complete = False
    if "session_logger" not in st.session_state:
        st.session_state.session_logger = SessionLogger()
    if "last_results" not in st.session_state:
        st.session_state.last_results = None
    if "processing" not in st.session_state:
        st.session_state.processing = False


def render_sidebar():
    """Render sidebar with settings and guidance."""
    st.sidebar.title("⚙️ Settings")
    
    # Analysis settings
    st.sidebar.subheader("Analysis Settings")
    
    smoothing = st.sidebar.slider(
        "Smoothing Window",
        min_value=3,
        max_value=11,
        value=5,
        step=2,
        help="Higher = smoother but more lag",
    )
    
    frame_skip = st.sidebar.slider(
        "Frame Skip",
        min_value=1,
        max_value=5,
        value=2,
        help="Process every Nth frame for speed",
    )
    
    # Thresholds
    st.sidebar.subheader("Detection Thresholds")

    depth_threshold = st.sidebar.slider(
        "Depth Threshold",
        min_value=-0.05,
        max_value=0.1,
        value=0.0,
        step=0.01,
        help="Hip must be this far below knee for depth",
    )

    torso_max = st.sidebar.slider(
        "Max Torso Lean (°)",
        min_value=30,
        max_value=60,
        value=45,
        help="Maximum acceptable forward lean",
    )

    # Debug settings
    st.sidebar.subheader("Debug")

    show_debug = st.sidebar.checkbox(
        "Show Debug Overlay",
        value=False,
        help="Show gate status (pose/motion/cooldown) on video",
    )
    
    # Camera guidance
    st.sidebar.markdown("---")
    st.sidebar.subheader("📷 Camera Setup")
    
    guidance = CameraGuidance()
    for instruction in guidance.get_setup_instructions():
        st.sidebar.markdown(f"• {instruction}")
    
    return {
        "smoothing_window": smoothing,
        "frame_skip": frame_skip,
        "depth_threshold": depth_threshold,
        "torso_lean_max": torso_max,
        "show_debug": show_debug,
    }


def render_live_stats(rep_count: int, phase: SquatPhase, feedback: FormAnalysis):
    """Render live statistics panel."""
    st.subheader("📊 Live Stats")
    
    # Rep count
    st.metric("Reps", rep_count)
    
    # Current phase
    phase_colors = {
        SquatPhase.TOP: "🟢",
        SquatPhase.DESCENDING: "🔵",
        SquatPhase.BOTTOM: "🟡",
        SquatPhase.ASCENDING: "🔵",
        SquatPhase.LOCKOUT: "🟢",
    }
    st.markdown(f"**Phase:** {phase_colors.get(phase, '⚪')} {phase.value.upper()}")
    
    # Form feedback
    st.markdown("**Form Check:**")
    if feedback:
        if feedback.depth_ok:
            st.markdown("✅ Depth")
        else:
            st.markdown(f"❌ {feedback.depth_message}")
        
        if feedback.torso_ok:
            st.markdown("✅ Torso")
        else:
            st.markdown(f"❌ {feedback.torso_message}")
        
        if feedback.valgus_ok:
            st.markdown("✅ Knees")
        else:
            st.markdown(f"❌ {feedback.valgus_message}")


def select_visible_leg_angle(landmarks):
    """Use the more visible leg for knee-angle measurements."""
    left_leg = (
        landmarks[LEFT_HIP],
        landmarks[LEFT_KNEE],
        landmarks[LEFT_ANKLE],
    )
    right_leg = (
        landmarks[RIGHT_HIP],
        landmarks[RIGHT_KNEE],
        landmarks[RIGHT_ANKLE],
    )

    left_visibility = min(joint[2] for joint in left_leg)
    right_visibility = min(joint[2] for joint in right_leg)

    selected_leg = left_leg if left_visibility >= right_visibility else right_leg

    return calculate_angle(
        selected_leg[0][:2],
        selected_leg[1][:2],
        selected_leg[2][:2],
    )


def process_video(uploaded_file, settings: dict):
    """Process uploaded video and analyze squat form."""
    st.session_state.processing = True
    st.session_state.session_complete = False

    # Save uploaded file to temp location
    with tempfile.NamedTemporaryFile(delete=False, suffix=".mp4") as tmp:
        tmp.write(uploaded_file.read())
        video_path = tmp.name

    # Initialize components
    pipeline = PosePipeline(smoothing_window=settings["smoothing_window"])
    rep_counter = RepCounter(depth_threshold=settings["depth_threshold"])
    form_feedback = FormFeedback(
        depth_threshold=settings["depth_threshold"],
        torso_lean_max=settings["torso_lean_max"],
    )
    renderer = OverlayRenderer()
    logger = SessionLogger()
    guidance = CameraGuidance()

    # Countdown / set-active state (UI-level, not in rep_counter)
    COUNTDOWN_DURATION = 3.0  # seconds
    INACTIVITY_DISARM_TIME = 5.0  # seconds of standing tall to auto-disarm
    GO_FLASH_DURATION = 0.5  # seconds to show "GO!" flash
    STANDING_TALL_ANGLE = 165.0  # knee angle threshold for "standing tall"
    PERSON_STABLE_TIME = 0.5  # seconds person must be detected before countdown starts

    countdown_start_time: float = None  # When countdown started
    set_active: bool = False  # Whether rep counting is allowed
    go_flash_until: float = 0.0  # Show "GO!" flash until this timestamp
    last_activity_time: float = 0.0  # Last time not standing tall
    person_detected_start: float = None  # When person was first detected stable

    # Rep feedback state (TTL-based, one message per rep)
    current_rep_feedback: RepFeedback = None  # Current feedback to display

    # Set summary tracking
    good_reps_in_set: int = 0  # Count of reps with all form checks passed

    # Open video
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        st.error("Failed to open video file")
        return
    
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    fps = cap.get(cv2.CAP_PROP_FPS) or 30
    
    # UI elements
    progress_bar = st.progress(0)
    status_text = st.empty()
    frame_display = st.empty()
    
    # Stats display
    col1, col2 = st.columns([3, 1])
    with col2:
        stats_placeholder = st.empty()
    
    frame_count = 0
    current_feedback = FormAnalysis(
        depth_ok=True, depth_message="",
        torso_ok=True, torso_message="",
        valgus_ok=True, valgus_message="",
        quality_tag="good",
    )
    
    # Rep tracking for form aggregation
    rep_start_frame = 0
    torso_issues_in_rep = 0
    valgus_issues_in_rep = 0
    frames_in_rep = 0
    
    try:
        while cap.isOpened():
            ret, frame = cap.read()
            if not ret:
                break
            
            frame_count += 1
            timestamp = frame_count / fps
            
            # Frame skip for performance
            if frame_count % settings["frame_skip"] != 0:
                continue
            
            # Process pose
            result = pipeline.process_frame(frame)
            
            # Log detection
            detected = result is not None
            logger.log_frame(detected)
            
            if result:
                landmarks = result["landmarks"]
                h, w = result["frame_shape"]

                # Get key joints for analysis
                left_hip = landmarks[LEFT_HIP]
                right_hip = landmarks[RIGHT_HIP]
                left_knee = landmarks[LEFT_KNEE]
                right_knee = landmarks[RIGHT_KNEE]
                left_ankle = landmarks[LEFT_ANKLE]
                right_ankle = landmarks[RIGHT_ANKLE]

                # Use the clearest leg each frame so side-view clips work from either direction.
                knee_angle = select_visible_leg_angle(landmarks)

                # Average positions
                hip_y = (left_hip[1] + right_hip[1]) / 2
                knee_y = (left_knee[1] + right_knee[1]) / 2

                # --- UI-level countdown/set-active logic ---
                # Track person detection stability
                if person_detected_start is None:
                    person_detected_start = timestamp

                person_detected_duration = timestamp - person_detected_start

                # Determine if currently "standing tall" (not actively squatting)
                is_standing_tall = knee_angle >= STANDING_TALL_ANGLE

                if not is_standing_tall:
                    last_activity_time = timestamp

                # State machine for countdown/set_active
                if not set_active:
                    # Not yet armed - check if we should start/continue countdown
                    if person_detected_duration >= PERSON_STABLE_TIME:
                        # Person detected long enough, start countdown if not started
                        if countdown_start_time is None:
                            countdown_start_time = timestamp

                        # Check if countdown complete
                        countdown_elapsed = timestamp - countdown_start_time
                        if countdown_elapsed >= COUNTDOWN_DURATION:
                            set_active = True
                            go_flash_until = timestamp + GO_FLASH_DURATION

                    # SMART BYPASS: If video starts mid-squat (already in depth),
                    # immediately arm the set without waiting for countdown.
                    # Uses the same knee angle depth threshold as rep_counter.
                    if countdown_start_time is not None and not set_active:
                        if knee_angle <= rep_counter.knee_angle_depth_threshold:
                            # Already in squat depth - bypass countdown immediately
                            set_active = True
                            countdown_start_time = None  # Cancel countdown
                            # No GO flash - user is already squatting
                else:
                    # Set is active - check for auto-disarm due to inactivity
                    time_since_activity = timestamp - last_activity_time
                    if is_standing_tall and time_since_activity >= INACTIVITY_DISARM_TIME:
                        # Auto-disarm: standing tall for too long
                        # Generate set summary before disarming
                        if rep_counter.rep_count > 0:
                            current_rep_feedback = RepFeedback.generate_set_summary(
                                total_reps=rep_counter.rep_count,
                                good_reps=good_reps_in_set,
                                timestamp=timestamp,
                            )

                        set_active = False
                        countdown_start_time = None
                        person_detected_start = None
                        good_reps_in_set = 0  # Reset for next set

                # Only update rep counter when set is active
                if set_active:
                    rep_result = rep_counter.update(knee_angle, hip_y, knee_y, timestamp, landmarks=landmarks)
                else:
                    # Create a dummy result with current state but no rep counting
                    rep_result = type('obj', (object,), {
                        'rep_count': rep_counter.rep_count,
                        'phase': rep_counter.phase,
                        'rep_completed': False,
                        'depth_reached': False,
                        'min_knee_angle': 180.0,
                        'rep_duration_ms': 0,
                        'gate_status': None,
                    })()
                
                # Analyze form
                current_feedback = form_feedback.analyze(landmarks, rep_result.rep_duration_ms)
                
                # Track form issues for rep summary
                if rep_result.phase in (SquatPhase.DESCENDING, SquatPhase.BOTTOM, SquatPhase.ASCENDING):
                    frames_in_rep += 1
                    if not current_feedback.torso_ok:
                        torso_issues_in_rep += 1
                    if not current_feedback.valgus_ok:
                        valgus_issues_in_rep += 1
                
                # Handle rep completion
                if rep_result.rep_completed:
                    # Create rep summary
                    rep_summary = form_feedback.analyze_rep_summary(
                        depth_reached=rep_result.depth_reached,
                        min_knee_angle=rep_result.min_knee_angle,
                        rep_duration_ms=rep_result.rep_duration_ms,
                        torso_issues_count=torso_issues_in_rep,
                        valgus_issues_count=valgus_issues_in_rep,
                        total_frames=max(1, frames_in_rep),
                    )

                    # Generate rep feedback (one message per rep, TTL-based)
                    current_rep_feedback = RepFeedback.generate(
                        rep_number=rep_result.rep_count,
                        depth_ok=rep_summary.depth_ok,
                        torso_ok=rep_summary.torso_ok,
                        valgus_ok=rep_summary.valgus_ok,
                        quality_tag=rep_summary.quality_tag,
                        timestamp=timestamp,
                    )

                    # Track good reps for set summary
                    if rep_summary.depth_ok and rep_summary.torso_ok and rep_summary.valgus_ok:
                        good_reps_in_set += 1

                    # Log the rep
                    logger.log_rep(RepData(
                        rep_number=rep_result.rep_count,
                        depth_ok=rep_summary.depth_ok,
                        torso_ok=rep_summary.torso_ok,
                        valgus_ok=rep_summary.valgus_ok,
                        quality_tag=rep_summary.quality_tag,
                        duration_ms=rep_result.rep_duration_ms,
                        min_knee_angle=rep_result.min_knee_angle,
                        timestamp=timestamp,
                    ))

                    # Reset rep tracking
                    rep_start_frame = frame_count
                    torso_issues_in_rep = 0
                    valgus_issues_in_rep = 0
                    frames_in_rep = 0
                
                # Determine current UI set state
                if set_active:
                    current_set_state = SetState.ACTIVE
                elif countdown_start_time is not None:
                    current_set_state = SetState.COUNTDOWN
                else:
                    current_set_state = SetState.IDLE

                # Render overlays with state-based coloring
                # Note: feedback=None disables live spam; rep_feedback provides TTL-based messages
                annotated = renderer.render(
                    frame=frame,
                    landmarks=landmarks,
                    rep_count=rep_result.rep_count,
                    feedback=None,  # Disabled: no live feedback spam
                    phase=rep_result.phase,
                    knee_angle=knee_angle,
                    gate_status=rep_result.gate_status,
                    show_debug=settings["show_debug"],
                    set_state=current_set_state,
                    timestamp=timestamp,
                    rep_feedback=current_rep_feedback,  # TTL-based feedback
                )

                # Draw countdown overlay if countdown is active
                if current_set_state == SetState.COUNTDOWN:
                    countdown_remaining = COUNTDOWN_DURATION - (timestamp - countdown_start_time)
                    if countdown_remaining > 0:
                        annotated = renderer.draw_countdown(annotated, countdown_remaining)

                # Draw "GO!" flash after countdown completes
                if timestamp < go_flash_until:
                    annotated = renderer.draw_set_armed_indicator(annotated)
            else:
                # No detection - reset person detection timer if countdown hasn't started
                if not set_active and countdown_start_time is None:
                    person_detected_start = None

                # Show original frame
                annotated = frame
                rep_result = type('obj', (object,), {
                    'rep_count': rep_counter.rep_count,
                    'phase': rep_counter.phase,
                })()
            
            # Convert BGR to RGB for display
            display_frame = cv2.cvtColor(annotated, cv2.COLOR_BGR2RGB)
            
            # Update UI (throttled)
            if frame_count % 3 == 0:
                with col1:
                    frame_display.image(display_frame, channels="RGB", use_container_width=True)
                
                with stats_placeholder.container():
                    render_live_stats(
                        rep_count=rep_result.rep_count if hasattr(rep_result, 'rep_count') else rep_counter.rep_count,
                        phase=rep_result.phase if hasattr(rep_result, 'phase') else rep_counter.phase,
                        feedback=current_feedback,
                    )
            
            # Update progress
            progress = frame_count / max(1, total_frames)
            progress_bar.progress(progress)
            status_text.text(f"Processing frame {frame_count}/{total_frames}")
    
    except Exception as e:
        st.error(f"Error processing video: {e}")
        raise
    
    finally:
        cap.release()
        pipeline.cleanup()
        
        # Clean up temp file
        try:
            os.unlink(video_path)
        except:
            pass
    
    # Store results
    st.session_state.session_logger = logger
    st.session_state.session_complete = True
    st.session_state.processing = False
    
    progress_bar.empty()
    status_text.empty()
    
    st.success(f"✅ Analysis complete! Detected {rep_counter.rep_count} reps.")


def render_session_summary():
    """Display session summary after analysis."""
    st.markdown("---")
    st.header("📊 Session Summary")
    
    summary = st.session_state.session_logger.get_summary()
    
    # Key metrics
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        st.metric("Total Reps", summary["total_reps"])
    
    with col2:
        st.metric("Good Form %", f"{summary['good_form_pct']}%")
    
    with col3:
        st.metric("Rep Quality", summary["dominant_quality"].title())
    
    with col4:
        st.metric("Detection Rate", f"{summary['detection_rate']}%")
    
    # Quality distribution
    st.subheader("Rep Quality Distribution")
    qual_dist = summary["quality_distribution"]
    
    qual_col1, qual_col2, qual_col3 = st.columns(3)
    with qual_col1:
        st.metric("🚀 Explosive", qual_dist.get("explosive", 0))
    with qual_col2:
        st.metric("✅ Good", qual_dist.get("good", 0))
    with qual_col3:
        st.metric("💪 Grind", qual_dist.get("grind", 0))
    
    # Rep details table
    if summary["rep_details"]:
        st.subheader("Rep Breakdown")
        
        # Create a formatted table
        import pandas as pd
        df = pd.DataFrame(summary["rep_details"])
        
        # Color code the dataframe
        def highlight_issues(val):
            if val in ("SHALLOW", "FORWARD", "CAVE-IN"):
                return "background-color: #ffcccc"
            elif val == "OK":
                return "background-color: #ccffcc"
            return ""
        
        styled_df = df.style.applymap(
            highlight_issues, 
            subset=["depth", "torso", "valgus"]
        )
        
        st.dataframe(styled_df, use_container_width=True)
    
    # Recommendations
    st.subheader("💡 Recommendations")
    
    recommendations = []
    
    if summary["good_form_pct"] < 80:
        if any(r.get("depth") == "SHALLOW" for r in summary["rep_details"]):
            recommendations.append("🔻 Focus on hitting depth - aim to get hips below knee level")
        
        if any(r.get("torso") == "FORWARD" for r in summary["rep_details"]):
            recommendations.append("🔼 Keep chest up - avoid excessive forward lean")
        
        if any(r.get("valgus") == "CAVE-IN" for r in summary["rep_details"]):
            recommendations.append("⬅️➡️ Push knees out - avoid letting them cave inward")
    
    if qual_dist.get("grind", 0) > qual_dist.get("explosive", 0):
        recommendations.append("⚡ Consider reducing weight to improve rep speed")
    
    if summary["detection_rate"] < 80:
        recommendations.append("📷 Improve camera positioning for better tracking")
    
    if not recommendations:
        recommendations.append("🎉 Great work! Keep up the consistent form!")
    
    for rec in recommendations:
        st.markdown(f"• {rec}")
    
    # Reset button
    st.markdown("---")
    if st.button("🔄 Analyze Another Video"):
        st.session_state.session_complete = False
        st.session_state.session_logger = SessionLogger()
        st.rerun()


def main():
    """Main application entry point."""
    init_session_state()
    
    # Header
    st.title("🏋️ AI Personal Trainer - Squat MVP")
    st.markdown("Upload a video of your squats for real-time form analysis")
    
    # Sidebar settings
    settings = render_sidebar()
    
    # Main content
    if st.session_state.session_complete:
        render_session_summary()
    else:
        # Video upload section
        st.subheader("📹 Upload Video")
        
        uploaded_file = st.file_uploader(
            "Choose a squat video",
            type=["mp4", "mov", "avi", "mkv"],
            help="Record yourself doing squats from a side angle",
        )
        
        if uploaded_file:
            st.video(uploaded_file)
            
            col1, col2 = st.columns([1, 3])
            with col1:
                if st.button("🔬 Analyze Video", type="primary", disabled=st.session_state.processing):
                    # Reset file pointer
                    uploaded_file.seek(0)
                    process_video(uploaded_file, settings)
            
            with col2:
                if st.session_state.processing:
                    st.info("Processing video... This may take a moment.")
        else:
            # Placeholder content
            st.info("👆 Upload a video to get started")
            
            # Tips section
            with st.expander("📌 Tips for best results"):
                guidance = CameraGuidance()
                
                st.markdown("**Camera Setup:**")
                for tip in guidance.get_setup_instructions():
                    st.markdown(f"• {tip}")
                
                st.markdown("**Recording Tips:**")
                for tip in guidance.get_quick_tips():
                    st.markdown(f"• {tip}")


if __name__ == "__main__":
    main()


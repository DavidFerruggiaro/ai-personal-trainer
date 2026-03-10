"""
Overlay renderer for drawing pose visualization on video frames.
Draws skeleton, angles, depth bar, rep count, and feedback text.
"""

import cv2
import numpy as np
import math
from typing import List, Optional, Tuple
from enum import Enum
import sys
import os

# Add parent directory for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.form_feedback import FormAnalysis
from core.rep_counter import SquatPhase, GateStatus
from core.pose_pipeline import POSE_CONNECTIONS
from utils.math_utils import calculate_angle


class SetState(Enum):
    """UI state for set tracking."""
    IDLE = "idle"           # No person detected or waiting
    COUNTDOWN = "countdown" # Countdown in progress
    ACTIVE = "active"       # Set is active, counting reps


class RepFeedback:
    """
    Feedback for a completed rep with TTL support.

    Generated once per rep, displayed briefly, then cleared.
    """
    # Feedback TTL in seconds
    TTL = 1.5

    def __init__(
        self,
        message: str,
        is_positive: bool,
        timestamp: float,
        rep_number: int,
    ):
        self.message = message
        self.is_positive = is_positive
        self.timestamp = timestamp
        self.rep_number = rep_number

    def is_expired(self, current_time: float) -> bool:
        """Check if feedback has expired based on TTL."""
        return (current_time - self.timestamp) >= self.TTL

    @staticmethod
    def generate(
        rep_number: int,
        depth_ok: bool,
        torso_ok: bool,
        valgus_ok: bool,
        quality_tag: str,
        timestamp: float,
    ) -> "RepFeedback":
        """
        Generate feedback for a completed rep.

        Returns a single, concise message based on rep quality.
        Priority: depth > torso > valgus > quality
        """
        # Determine primary feedback
        if not depth_ok:
            return RepFeedback(
                message="Go deeper next rep",
                is_positive=False,
                timestamp=timestamp,
                rep_number=rep_number,
            )

        if not torso_ok:
            return RepFeedback(
                message="Keep chest up",
                is_positive=False,
                timestamp=timestamp,
                rep_number=rep_number,
            )

        if not valgus_ok:
            return RepFeedback(
                message="Push knees out",
                is_positive=False,
                timestamp=timestamp,
                rep_number=rep_number,
            )

        # All form checks passed - positive feedback based on quality
        if quality_tag == "explosive":
            message = "Great rep!"
        elif quality_tag == "grind":
            message = "Good grind"
        else:
            message = "Good rep"

        return RepFeedback(
            message=message,
            is_positive=True,
            timestamp=timestamp,
            rep_number=rep_number,
        )

    @staticmethod
    def generate_set_summary(
        total_reps: int,
        good_reps: int,
        timestamp: float,
    ) -> "RepFeedback":
        """
        Generate a brief set summary when auto-disarm triggers.

        Args:
            total_reps: Total reps in the set
            good_reps: Reps with good form (all checks passed)
            timestamp: Current timestamp

        Returns:
            RepFeedback with set summary message
        """
        if total_reps == 0:
            return RepFeedback(
                message="Set complete",
                is_positive=True,
                timestamp=timestamp,
                rep_number=0,
            )

        pct = int((good_reps / total_reps) * 100)
        message = f"{total_reps} reps - {good_reps}/{total_reps} good form"

        return RepFeedback(
            message=message,
            is_positive=(pct >= 70),
            timestamp=timestamp,
            rep_number=total_reps,
        )


class OverlayRenderer:
    """
    Renders visual overlays on video frames.
    
    Overlays include:
    - Pose skeleton with joint connections
    - Knee angle arc indicator
    - Depth progress bar
    - Rep counter display
    - Real-time form feedback text
    - Movement phase indicator
    
    Usage:
        renderer = OverlayRenderer()
        annotated = renderer.render(frame, landmarks, rep_count, feedback, phase)
    """
    
    # Colors (BGR format for OpenCV)
    COLOR_SKELETON = (0, 255, 0)       # Green
    COLOR_JOINT = (0, 200, 255)        # Orange
    COLOR_FEEDBACK_OK = (0, 255, 0)    # Green
    COLOR_FEEDBACK_WARN = (0, 165, 255)  # Orange
    COLOR_FEEDBACK_BAD = (0, 0, 255)   # Red
    COLOR_TEXT = (255, 255, 255)       # White
    COLOR_TEXT_BG = (0, 0, 0)          # Black
    COLOR_DEPTH_BAR_BG = (50, 50, 50)  # Dark gray
    COLOR_DEPTH_BAR_FILL = (0, 255, 0) # Green
    COLOR_ANGLE_ARC = (255, 255, 0)    # Cyan

    # State-based colors
    COLOR_IDLE = (128, 128, 128)       # Gray
    COLOR_COUNTDOWN = (0, 200, 255)    # Yellow/Orange
    COLOR_ACTIVE = (0, 255, 0)         # Green

    # Skeleton colors by state
    SKELETON_COLORS = {
        SetState.IDLE: ((100, 100, 100), (80, 80, 80)),       # Muted gray (skeleton, joint)
        SetState.COUNTDOWN: ((0, 180, 255), (0, 140, 200)),   # Yellow tint
        SetState.ACTIVE: ((0, 255, 0), (0, 200, 255)),        # Green skeleton, orange joints
    }

    # Font settings
    FONT = cv2.FONT_HERSHEY_SIMPLEX
    FONT_SCALE_LARGE = 1.5
    FONT_SCALE_MEDIUM = 0.8
    FONT_SCALE_SMALL = 0.6
    FONT_THICKNESS = 2

    # Landmark categories for differentiated styling
    # Face landmarks (0-10) should be dimmer than body landmarks
    FACE_LANDMARKS = set(range(0, 11))
    # Squat-relevant joints get full brightness
    SQUAT_LANDMARKS = {11, 12, 23, 24, 25, 26, 27, 28}  # shoulders, hips, knees, ankles

    def __init__(self):
        """Initialize renderer with default settings."""
        self.joint_radius = 3  # Reduced from 5
        self.line_thickness = 1  # Reduced from 2
        # Animation state
        self._last_rep_count = 0
        self._rep_pulse_start = 0.0  # Timestamp when pulse started
        self._current_set_state = SetState.IDLE
    
    def render(
        self,
        frame: np.ndarray,
        landmarks: Optional[List[tuple]],
        rep_count: int,
        feedback: Optional[FormAnalysis],
        phase: SquatPhase,
        knee_angle: float = 180.0,
        gate_status: Optional[GateStatus] = None,
        show_debug: bool = False,
        set_state: SetState = None,
        timestamp: float = 0.0,
        rep_feedback: Optional["RepFeedback"] = None,
    ) -> np.ndarray:
        """
        Render all overlays onto a frame.

        Args:
            frame: Input frame (BGR format)
            landmarks: List of (x, y, visibility) tuples (normalized 0-1)
            rep_count: Current rep count
            feedback: Form analysis results (deprecated, kept for compatibility)
            phase: Current movement phase
            knee_angle: Current knee angle for arc display
            gate_status: Gate validation status for debug display
            show_debug: Whether to show debug overlay
            set_state: Current UI set state (IDLE, COUNTDOWN, ACTIVE)
            timestamp: Current video timestamp for animations
            rep_feedback: TTL-based feedback from completed rep (replaces live feedback)

        Returns:
            New frame with overlays rendered
        """
        # Default to ACTIVE for backwards compatibility
        if set_state is None:
            set_state = SetState.ACTIVE

        self._current_set_state = set_state

        # Detect rep count change for pulse animation
        if rep_count > self._last_rep_count:
            self._rep_pulse_start = timestamp
            self._last_rep_count = rep_count

        # Work on a copy
        output = frame.copy()
        h, w = output.shape[:2]

        # Draw skeleton if landmarks available (colored by state)
        if landmarks:
            self._draw_skeleton(output, landmarks, w, h, set_state)

            # Draw angle arc at knee
            if len(landmarks) > 26:  # Ensure we have knee landmarks
                self._draw_angle_arc(output, landmarks, w, h, knee_angle)

        # Draw depth bar
        self._draw_depth_bar(output, phase, w, h)

        # Draw rep count with pulse animation (top right)
        self._draw_rep_count(output, rep_count, w, h, timestamp)

        # Draw phase indicator (debug mode only - reduces cognitive noise for users)
        if show_debug:
            self._draw_phase_indicator(output, phase, w, h)

        # Draw set state badge (top left corner)
        self._draw_set_state_badge(output, set_state, w, h)

        # Draw rep feedback (TTL-based, replaces live feedback spam)
        if rep_feedback and not rep_feedback.is_expired(timestamp):
            self._draw_rep_feedback(output, rep_feedback, timestamp, w, h)

        # Draw debug overlay if enabled
        if show_debug and gate_status:
            self._draw_debug_overlay(output, phase, gate_status, rep_count, w, h)

        return output
    
    def _draw_skeleton(
        self,
        frame: np.ndarray,
        landmarks: List[tuple],
        width: int,
        height: int,
        set_state: SetState = SetState.ACTIVE,
    ) -> None:
        """Draw pose skeleton on frame with state-based coloring and softened visuals."""
        # Get colors for current state
        skeleton_color, joint_color = self.SKELETON_COLORS.get(
            set_state, (self.COLOR_SKELETON, self.COLOR_JOINT)
        )

        # Apply opacity reduction for ACTIVE state (skeleton becomes secondary)
        if set_state == SetState.ACTIVE:
            skeleton_opacity = 0.5  # Reduced opacity for active state
        else:
            skeleton_opacity = 0.8

        # Create overlay for alpha blending
        overlay = frame.copy()

        # Draw connections on overlay
        for start_idx, end_idx in POSE_CONNECTIONS:
            if start_idx >= len(landmarks) or end_idx >= len(landmarks):
                continue

            start = landmarks[start_idx]
            end = landmarks[end_idx]

            # Skip if low visibility
            if start[2] < 0.5 or end[2] < 0.5:
                continue

            # Convert to pixel coordinates
            start_px = (int(start[0] * width), int(start[1] * height))
            end_px = (int(end[0] * width), int(end[1] * height))

            cv2.line(overlay, start_px, end_px, skeleton_color, self.line_thickness)

        # Blend skeleton lines with reduced opacity
        cv2.addWeighted(overlay, skeleton_opacity, frame, 1 - skeleton_opacity, 0, frame)

        # Draw joints with differentiated styling based on landmark type
        for i, lm in enumerate(landmarks):
            if lm[2] < 0.5:  # Skip low visibility
                continue

            px = int(lm[0] * width)
            py = int(lm[1] * height)

            # Determine joint styling based on landmark category
            if i in self.FACE_LANDMARKS:
                # Face landmarks: very dim, smallest dots
                dim_factor = 0.3
                radius = max(1, self.joint_radius - 1)
            elif i in self.SQUAT_LANDMARKS:
                # Squat-relevant joints: slightly dimmed but visible
                dim_factor = 0.7
                radius = self.joint_radius
            else:
                # Other body landmarks: moderately dim
                dim_factor = 0.5
                radius = max(2, self.joint_radius - 1)

            # Apply dimming to joint color
            dimmed_color = tuple(int(c * dim_factor) for c in joint_color)

            cv2.circle(frame, (px, py), radius, dimmed_color, -1)
    
    def _draw_angle_arc(
        self,
        frame: np.ndarray,
        landmarks: List[tuple],
        width: int,
        height: int,
        knee_angle: float,
    ) -> None:
        """Draw angle arc at knee joint."""
        # Use right side joints for visibility (assuming side view)
        # Indices: right_hip=24, right_knee=26, right_ankle=28
        try:
            hip = landmarks[24]
            knee = landmarks[26]
            ankle = landmarks[28]
            
            if hip[2] < 0.5 or knee[2] < 0.5 or ankle[2] < 0.5:
                return
            
            # Knee position in pixels
            knee_px = (int(knee[0] * width), int(knee[1] * height))
            
            # Draw arc background
            arc_radius = 30
            
            # Draw the angle value near the knee
            angle_text = f"{int(knee_angle)}°"
            text_pos = (knee_px[0] + 35, knee_px[1] - 10)
            
            # Background for text
            (tw, th), _ = cv2.getTextSize(angle_text, self.FONT, self.FONT_SCALE_SMALL, 1)
            cv2.rectangle(
                frame,
                (text_pos[0] - 2, text_pos[1] - th - 2),
                (text_pos[0] + tw + 2, text_pos[1] + 2),
                self.COLOR_TEXT_BG,
                -1,
            )
            
            cv2.putText(
                frame,
                angle_text,
                text_pos,
                self.FONT,
                self.FONT_SCALE_SMALL,
                self.COLOR_ANGLE_ARC,
                1,
            )
            
        except (IndexError, ValueError):
            pass
    
    def _draw_depth_bar(
        self,
        frame: np.ndarray,
        phase: SquatPhase,
        width: int,
        height: int,
    ) -> None:
        """Draw subtle vertical depth progress bar on left side."""
        # Bar dimensions (narrower for subtlety)
        bar_x = 25
        bar_y = 100
        bar_width = 15  # Reduced from 25
        bar_height = height - 200

        # Calculate fill based on phase
        if phase == SquatPhase.TOP:
            fill_pct = 0.0
        elif phase == SquatPhase.DESCENDING:
            fill_pct = 0.4
        elif phase == SquatPhase.BOTTOM:
            fill_pct = 1.0
        elif phase == SquatPhase.ASCENDING:
            fill_pct = 0.6
        else:  # LOCKOUT
            fill_pct = 0.1

        # Dim the bar when near lockout (standing tall) - less distracting
        if phase in (SquatPhase.TOP, SquatPhase.LOCKOUT):
            bar_opacity = 0.3  # Very subtle when standing
        elif phase == SquatPhase.BOTTOM:
            bar_opacity = 0.8  # More visible at depth
        else:
            bar_opacity = 0.5  # Moderate during movement

        # Create overlay for alpha blending
        overlay = frame.copy()

        # Draw background on overlay
        cv2.rectangle(
            overlay,
            (bar_x, bar_y),
            (bar_x + bar_width, bar_y + bar_height),
            self.COLOR_DEPTH_BAR_BG,
            -1,
        )

        fill_height = int(bar_height * fill_pct)
        fill_y = bar_y + bar_height - fill_height

        if fill_height > 0:
            cv2.rectangle(
                overlay,
                (bar_x, fill_y),
                (bar_x + bar_width, bar_y + bar_height),
                self.COLOR_DEPTH_BAR_FILL,
                -1,
            )

        # Draw target line on overlay
        target_y = bar_y + int(bar_height * 0.5)
        cv2.line(
            overlay,
            (bar_x - 3, target_y),
            (bar_x + bar_width + 3, target_y),
            self.COLOR_TEXT,
            1,  # Thinner line
        )

        # Blend with reduced opacity
        cv2.addWeighted(overlay, bar_opacity, frame, 1 - bar_opacity, 0, frame)

        # Label (also dimmed based on phase)
        label_color = tuple(int(c * bar_opacity) for c in self.COLOR_TEXT)
        cv2.putText(
            frame,
            "DEPTH",
            (bar_x - 5, bar_y - 10),
            self.FONT,
            self.FONT_SCALE_SMALL * 0.8,  # Slightly smaller
            label_color,
            1,
        )
    
    def _draw_rep_count(
        self,
        frame: np.ndarray,
        rep_count: int,
        width: int,
        height: int,
        timestamp: float = 0.0,
    ) -> None:
        """Draw prominent rep counter as primary visual anchor with pulse animation."""
        text = str(rep_count)

        # Calculate pulse scale (1.0 to 1.4 over 250ms) - slightly larger and longer
        PULSE_DURATION = 0.25  # seconds
        pulse_elapsed = timestamp - self._rep_pulse_start
        is_pulsing = pulse_elapsed < PULSE_DURATION and self._rep_pulse_start > 0

        if is_pulsing:
            # Ease-out animation: starts big, shrinks to normal
            progress = pulse_elapsed / PULSE_DURATION
            scale_factor = 1.0 + 0.4 * (1.0 - progress)  # Larger pulse (1.4x)
            glow_intensity = 1.0 - progress  # Fades out
        else:
            scale_factor = 1.0
            glow_intensity = 0.0

        # Larger base font for prominence
        base_font_scale = self.FONT_SCALE_LARGE * 2.5  # Increased from 2
        font_scale = base_font_scale * scale_factor
        thickness = int(self.FONT_THICKNESS * 3)  # Thicker for better contrast

        # Get text size with current scale
        (tw, th), baseline = cv2.getTextSize(text, self.FONT, font_scale, thickness)

        # Position (top right with padding) - adjusted for larger size
        base_x = width - 75
        base_y = 85
        x = base_x - tw // 2
        y = base_y + th // 2

        # Background box (fixed size, doesn't pulse) - slightly larger
        box_left = width - 120
        box_top = 20
        box_right = width - 10
        box_bottom = 125

        # Border styling based on pulse state
        if is_pulsing:
            border_color = self.COLOR_FEEDBACK_OK
            border_thickness = 3  # Thicker during pulse
        else:
            border_color = (80, 80, 80)  # Subtle border when not pulsing
            border_thickness = 2

        # Draw background with slight transparency for depth
        cv2.rectangle(
            frame,
            (box_left, box_top),
            (box_right, box_bottom),
            self.COLOR_TEXT_BG,
            -1,
        )

        # Draw border
        cv2.rectangle(
            frame,
            (box_left, box_top),
            (box_right, box_bottom),
            border_color,
            border_thickness,
        )

        # Draw glow effect during pulse (green halo behind number)
        if is_pulsing and glow_intensity > 0.1:
            glow_color = tuple(int(c * glow_intensity * 0.5) for c in self.COLOR_FEEDBACK_OK)
            # Draw slightly offset/larger text as glow
            cv2.putText(
                frame,
                text,
                (x, y),
                self.FONT,
                font_scale,
                glow_color,
                thickness + 4,  # Thicker for glow effect
            )

        # Rep count number (centered in box) - high contrast white
        cv2.putText(
            frame,
            text,
            (x, y),
            self.FONT,
            font_scale,
            self.COLOR_TEXT,
            thickness,
        )

        # "REPS" label - subtle, doesn't compete
        label_color = (120, 120, 120)  # Dim gray
        cv2.putText(
            frame,
            "REPS",
            (box_left + 30, box_bottom - 8),
            self.FONT,
            self.FONT_SCALE_SMALL * 0.9,
            label_color,
            1,
        )
    
    def _draw_phase_indicator(
        self,
        frame: np.ndarray,
        phase: SquatPhase,
        width: int,
        height: int,
    ) -> None:
        """Draw current movement phase."""
        phase_text = phase.value.upper()
        
        # Choose color based on phase
        if phase in (SquatPhase.TOP, SquatPhase.LOCKOUT):
            color = self.COLOR_FEEDBACK_OK
        elif phase == SquatPhase.BOTTOM:
            color = self.COLOR_ANGLE_ARC
        else:
            color = self.COLOR_FEEDBACK_WARN
        
        # Position (top center)
        (tw, th), _ = cv2.getTextSize(phase_text, self.FONT, self.FONT_SCALE_MEDIUM, 2)
        x = (width - tw) // 2
        y = 40
        
        # Background
        cv2.rectangle(
            frame,
            (x - 10, y - th - 5),
            (x + tw + 10, y + 5),
            self.COLOR_TEXT_BG,
            -1,
        )
        
        cv2.putText(
            frame,
            phase_text,
            (x, y),
            self.FONT,
            self.FONT_SCALE_MEDIUM,
            color,
            2,
        )

    def _draw_set_state_badge(
        self,
        frame: np.ndarray,
        set_state: SetState,
        width: int,
        height: int,
    ) -> None:
        """Draw set state badge in top-left corner."""
        # State text and colors
        state_config = {
            SetState.IDLE: ("READY", self.COLOR_IDLE),
            SetState.COUNTDOWN: ("GET READY", self.COLOR_COUNTDOWN),
            SetState.ACTIVE: ("SET ACTIVE", self.COLOR_ACTIVE),
        }

        text, color = state_config.get(set_state, ("READY", self.COLOR_IDLE))

        # Position (top-left, below any debug overlay area)
        x = 15
        y = 30

        # Get text size
        (tw, th), _ = cv2.getTextSize(text, self.FONT, self.FONT_SCALE_SMALL, 2)

        # Draw rounded-corner-style badge
        padding_x = 10
        padding_y = 6

        # Background with color tint
        cv2.rectangle(
            frame,
            (x - padding_x, y - th - padding_y),
            (x + tw + padding_x, y + padding_y),
            self.COLOR_TEXT_BG,
            -1,
        )

        # Colored border
        cv2.rectangle(
            frame,
            (x - padding_x, y - th - padding_y),
            (x + tw + padding_x, y + padding_y),
            color,
            2,
        )

        # Small colored indicator dot
        dot_x = x - padding_x + 8
        dot_y = y - th // 2
        cv2.circle(frame, (dot_x, dot_y), 4, color, -1)

        # Text (offset to make room for dot)
        cv2.putText(
            frame,
            text,
            (x + 8, y),
            self.FONT,
            self.FONT_SCALE_SMALL,
            color,
            1,
        )

    def _draw_feedback_text(
        self,
        frame: np.ndarray,
        feedback: FormAnalysis,
        width: int,
        height: int,
    ) -> None:
        """Draw form feedback messages at bottom."""
        messages = []
        
        # Collect messages with colors
        if not feedback.depth_ok and feedback.depth_message:
            messages.append((feedback.depth_message, self.COLOR_FEEDBACK_BAD))
        
        if not feedback.torso_ok and feedback.torso_message:
            messages.append((feedback.torso_message, self.COLOR_FEEDBACK_BAD))
        
        if not feedback.valgus_ok and feedback.valgus_message:
            messages.append((feedback.valgus_message, self.COLOR_FEEDBACK_BAD))
        
        # If all good, show positive message
        if not messages:
            messages.append(("Good form!", self.COLOR_FEEDBACK_OK))
        
        # Draw messages
        y_start = height - 30 - (len(messages) - 1) * 35
        
        for i, (msg, color) in enumerate(messages):
            y = y_start + i * 35
            
            # Get text size for centering
            (tw, th), _ = cv2.getTextSize(msg, self.FONT, self.FONT_SCALE_MEDIUM, 2)
            x = (width - tw) // 2
            
            # Background
            cv2.rectangle(
                frame,
                (x - 10, y - th - 5),
                (x + tw + 10, y + 5),
                self.COLOR_TEXT_BG,
                -1,
            )
            
            cv2.putText(
                frame,
                msg,
                (x, y),
                self.FONT,
                self.FONT_SCALE_MEDIUM,
                color,
                2,
            )

    def _draw_rep_feedback(
        self,
        frame: np.ndarray,
        rep_feedback: "RepFeedback",
        current_time: float,
        width: int,
        height: int,
    ) -> None:
        """
        Draw calm, supportive TTL-based rep completion feedback.

        Displays a subtle, non-intrusive message near the rep counter
        that fades out as TTL expires. Feels like a quiet coach's voice.
        """
        # Calculate fade based on TTL remaining
        elapsed = current_time - rep_feedback.timestamp
        remaining = RepFeedback.TTL - elapsed
        if remaining <= 0:
            return

        # Fade out over last 0.4 seconds (slightly longer for gentler fade)
        if remaining < 0.4:
            alpha = remaining / 0.4
        else:
            alpha = 1.0

        # Calm, muted colors - not harsh or alerting
        # Soft green for positive feedback (less saturated than pure green)
        # Muted orange/amber for corrective cues (warm, not alarming)
        if rep_feedback.is_positive:
            base_color = (100, 200, 130)  # Soft sage green (BGR)
        else:
            base_color = (100, 160, 200)  # Muted amber/orange (BGR)

        # Apply alpha to color
        color = tuple(int(c * alpha) for c in base_color)

        # Smaller font to not compete with rep counter
        font_scale = self.FONT_SCALE_SMALL * 0.85

        # Position: below the rep counter box (top right area)
        text = rep_feedback.message
        (tw, th), _ = cv2.getTextSize(text, self.FONT, font_scale, 1)

        # Center under rep counter (which is at width-120 to width-10)
        box_center_x = width - 65
        x = box_center_x - tw // 2
        y = 145  # Below rep counter box (which ends at y=125)

        # Semi-transparent background with very subtle presence
        overlay = frame.copy()
        cv2.rectangle(
            overlay,
            (x - 6, y - th - 3),
            (x + tw + 6, y + 3),
            self.COLOR_TEXT_BG,
            -1,
        )
        cv2.addWeighted(overlay, alpha * 0.6, frame, 1 - alpha * 0.6, 0, frame)

        # Very subtle border (dimmed, thin)
        border_color = tuple(int(c * 0.5) for c in color)
        cv2.rectangle(
            frame,
            (x - 6, y - th - 3),
            (x + tw + 6, y + 3),
            border_color,
            1,
        )

        # Text - thinner stroke for calmer appearance
        cv2.putText(
            frame,
            text,
            (x, y),
            self.FONT,
            font_scale,
            color,
            1,
        )

    def _draw_debug_overlay(
        self,
        frame: np.ndarray,
        phase: SquatPhase,
        gate_status: GateStatus,
        rep_count: int,
        width: int,
        height: int,
    ) -> None:
        """Draw debug overlay showing gate status and state info."""
        # Position in top-left corner, below depth bar label
        x = 10
        y_start = 60
        line_height = 22

        # Build debug lines
        lines = [
            f"State: {phase.value.upper()}",
            f"Reps: {rep_count}",
            f"Set: {'ARMED' if gate_status.set_armed else 'disarmed'}",
            f"Pose: {'OK' if gate_status.pose_valid else 'INVALID'} ({gate_status.pose_confidence:.2f})",
            f"Motion: {'OK' if gate_status.motion_valid else 'FROZEN'} (d={gate_status.motion_scale_delta:.3f})",
            f"Cooldown: {'ACTIVE' if gate_status.cooldown_active else 'off'}",
        ]

        # Calculate background box size
        max_width = 0
        for line in lines:
            (tw, _), _ = cv2.getTextSize(line, self.FONT, self.FONT_SCALE_SMALL, 1)
            max_width = max(max_width, tw)

        box_height = len(lines) * line_height + 10
        box_width = max_width + 20

        # Draw semi-transparent background
        overlay = frame.copy()
        cv2.rectangle(
            overlay,
            (x, y_start - 15),
            (x + box_width, y_start + box_height - 15),
            self.COLOR_TEXT_BG,
            -1,
        )
        cv2.addWeighted(overlay, 0.7, frame, 0.3, 0, frame)

        # Draw border
        cv2.rectangle(
            frame,
            (x, y_start - 15),
            (x + box_width, y_start + box_height - 15),
            (100, 100, 100),
            1,
        )

        # Draw each line with appropriate color
        for i, line in enumerate(lines):
            y = y_start + i * line_height

            # Determine color based on status
            if "INVALID" in line or "FROZEN" in line or "ACTIVE" in line or "disarmed" in line:
                color = self.COLOR_FEEDBACK_BAD
            elif "OK" in line or "off" in line or "ARMED" in line:
                color = self.COLOR_FEEDBACK_OK
            else:
                color = self.COLOR_TEXT

            cv2.putText(
                frame,
                line,
                (x + 5, y),
                self.FONT,
                self.FONT_SCALE_SMALL,
                color,
                1,
            )

    def draw_countdown(
        self,
        frame: np.ndarray,
        seconds_remaining: float,
    ) -> np.ndarray:
        """
        Draw polished countdown overlay centered on frame.

        Features:
        - Large, centered countdown numbers (3, 2, 1)
        - Subtle scale animation (pops at each second)
        - "GET READY" text above
        - Progress ring around number
        - Semi-transparent background dim

        Args:
            frame: Input frame (BGR format)
            seconds_remaining: Seconds left in countdown (0 = done)

        Returns:
            Frame with countdown overlay
        """
        output = frame.copy()
        h, w = output.shape[:2]

        if seconds_remaining <= 0:
            return output

        # Calculate which second we're on and the fractional part
        display_seconds = int(seconds_remaining) + 1
        if display_seconds > 3:
            display_seconds = 3

        # Fractional part within current second (0.0 = just started, 1.0 = about to change)
        frac = 1.0 - (seconds_remaining - int(seconds_remaining))

        # Scale animation: pop at start of each second, ease out
        # Scale from 1.2 down to 1.0 over the first 0.3 seconds of each count
        if frac < 0.3:
            scale_factor = 1.2 - (0.2 * (frac / 0.3))
        else:
            scale_factor = 1.0

        # Fade animation: slight fade-in at start of each second
        if frac < 0.1:
            alpha = 0.7 + (0.3 * (frac / 0.1))
        else:
            alpha = 1.0

        # Semi-transparent dark overlay for visibility (lighter than before)
        overlay = output.copy()
        cv2.rectangle(overlay, (0, 0), (w, h), (0, 0, 0), -1)
        cv2.addWeighted(overlay, 0.4, output, 0.6, 0, output)

        # Main countdown number with scale
        countdown_text = str(display_seconds)
        base_font_scale = 6.0
        font_scale = base_font_scale * scale_factor
        thickness = int(10 * scale_factor)

        (tw, th), _ = cv2.getTextSize(countdown_text, self.FONT, font_scale, thickness)
        x = (w - tw) // 2
        y = (h + th) // 2

        # Glow color intensity based on alpha
        glow_intensity = int(100 * alpha)
        glow_color = (0, glow_intensity, 0)

        # Outer glow
        cv2.putText(output, countdown_text, (x, y), self.FONT, font_scale, glow_color, thickness + 6)
        # Main text
        text_color = (0, int(255 * alpha), 0)
        cv2.putText(output, countdown_text, (x, y), self.FONT, font_scale, text_color, thickness)

        # "GET READY" text above - subtle yellow tint
        ready_text = "GET READY"
        (rtw, rth), _ = cv2.getTextSize(ready_text, self.FONT, self.FONT_SCALE_LARGE, 3)
        rx = (w - rtw) // 2
        ry = y - th - 50

        cv2.putText(output, ready_text, (rx, ry), self.FONT, self.FONT_SCALE_LARGE, self.COLOR_COUNTDOWN, 3)

        # Progress ring
        center = (w // 2, h // 2)
        radius = int(min(w, h) // 3.5)

        # Background ring (subtle)
        cv2.circle(output, center, radius, (40, 40, 40), 3)

        # Progress arc - fills as countdown progresses
        progress = (3.0 - seconds_remaining) / 3.0
        end_angle = int(-90 + progress * 360)
        cv2.ellipse(output, center, (radius, radius), 0, -90, end_angle, self.COLOR_COUNTDOWN, 5)

        # Small dot at current progress position
        angle_rad = math.radians(end_angle)
        dot_x = int(center[0] + radius * math.cos(angle_rad))
        dot_y = int(center[1] + radius * math.sin(angle_rad))
        cv2.circle(output, (dot_x, dot_y), 8, self.COLOR_COUNTDOWN, -1)

        return output

    def draw_set_armed_indicator(
        self,
        frame: np.ndarray,
    ) -> np.ndarray:
        """
        Draw brief "SET ACTIVE" indicator after countdown completes.

        Args:
            frame: Input frame (BGR format)

        Returns:
            Frame with indicator
        """
        output = frame.copy()
        h, w = output.shape[:2]

        text = "GO!"
        font_scale = 3.0
        thickness = 6

        (tw, th), _ = cv2.getTextSize(text, self.FONT, font_scale, thickness)
        x = (w - tw) // 2
        y = (h + th) // 2

        # Green background box
        padding = 30
        cv2.rectangle(
            output,
            (x - padding, y - th - padding),
            (x + tw + padding, y + padding),
            self.COLOR_FEEDBACK_OK,
            -1,
        )

        # Text
        cv2.putText(output, text, (x, y), self.FONT, font_scale, self.COLOR_TEXT_BG, thickness)

        return output


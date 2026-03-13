"""
Rep counter with state machine for squat detection.
Tracks movement phases and counts completed reps.

Includes gates for filtering false positives:
- Pose validity gate: requires key landmarks visible with sufficient confidence
- Motion gate: detects forward-walk/non-squat motion and freezes counting
- Rep cooldown: prevents double-counting reps
"""

from enum import Enum
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass, field


class SquatPhase(Enum):
    """Movement phases of a squat rep."""
    TOP = "top"
    DESCENDING = "descending"
    BOTTOM = "bottom"
    ASCENDING = "ascending"
    LOCKOUT = "lockout"


@dataclass
class GateStatus:
    """Status of validation gates for debug/display."""
    pose_valid: bool = True
    motion_valid: bool = True
    cooldown_active: bool = False
    set_armed: bool = False
    pose_confidence: float = 1.0
    motion_scale_delta: float = 0.0


@dataclass
class RepResult:
    """Result of a rep counter update."""
    phase: SquatPhase
    rep_completed: bool
    rep_count: int
    rep_duration_ms: float
    min_knee_angle: float
    depth_reached: bool
    gate_status: GateStatus = field(default_factory=GateStatus)


class RepCounter:
    """
    State machine for counting squat reps.

    Tracks the movement through phases:
    TOP -> DESCENDING -> BOTTOM -> ASCENDING -> LOCKOUT -> TOP

    A rep is counted when transitioning from LOCKOUT back to TOP.

    Includes validation gates to reduce false positives:
    - Pose validity gate: requires key landmarks visible with sufficient confidence
    - Motion gate: detects forward-walk motion and freezes counting
    - Rep cooldown: prevents double-counting reps

    Usage:
        counter = RepCounter()
        result = counter.update(knee_angle, hip_y, knee_y, timestamp, landmarks=landmarks)
        if result.rep_completed:
            print(f"Rep {result.rep_count} completed!")
    """

    # Thresholds
    DESCENDING_ANGLE_DELTA = 5.0      # Degrees of flexion to enter descending
    ASCENDING_ANGLE_DELTA = 5.0       # Degrees of extension to enter ascending
    LOCKOUT_ANGLE = 160.0             # Knee angle for lockout
    BOTTOM_HOLD_FRAMES = 2            # Frames at bottom before ascending
    LOCKOUT_HOLD_FRAMES = 3           # Frames at lockout before counting rep

    # Gate thresholds (tunable)
    POSE_MIN_VISIBILITY = 0.15        # Minimum landmark visibility (0-1), very low for side-view
    MOTION_SCALE_THRESHOLD = 0.08     # Max bounding box scale change per frame
    MOTION_STABLE_FRAMES = 5          # Frames of stability before re-enabling
    REP_COOLDOWN_FRAMES = 10          # Minimum frames between rep counts
    REP_COOLDOWN_SECONDS = 0.5        # Minimum seconds between rep counts

    # Landmark indices for left/right leg (hip, knee, ankle)
    LEFT_LEG_LANDMARKS = [23, 25, 27]   # left hip, left knee, left ankle
    RIGHT_LEG_LANDMARKS = [24, 26, 28]  # right hip, right knee, right ankle

    # Knee angle threshold for rep_ready (smaller = deeper squat)
    # 120° = parallel, 90° = very deep, 100° = good depth
    KNEE_ANGLE_DEPTH_THRESHOLD = 120.0

    # Set boundary thresholds
    SET_ARM_ANGLE_THRESHOLD = 150.0   # Knee angle below which set_armed activates (deliberate descent)
    SET_DISARM_ANGLE_THRESHOLD = 165.0  # Knee angle above which disarm timer starts (standing tall)
    SET_DISARM_STABLE_FRAMES = 15     # Frames of standing tall + motion stable to disarm

    # Minimum time in depth before rep can be finalized (FPS-independent)
    MIN_DEPTH_TIME = 0.15             # Seconds - prevents brief positioning bends from counting

    # Indices of landmarks required for squat analysis (hip, knee, ankle)
    REQUIRED_LANDMARKS = [23, 24, 25, 26, 27, 28]  # L/R hip, knee, ankle

    def __init__(
        self,
        depth_threshold: float = 0.0,
        lockout_threshold: float = 160.0,
        pose_min_visibility: float = 0.15,
        motion_scale_threshold: float = 0.08,
        rep_cooldown_frames: int = 10,
        rep_cooldown_seconds: float = 0.5,
        knee_angle_depth_threshold: float = 120.0,
    ):
        """
        Initialize rep counter.

        Args:
            depth_threshold: Hip Y must be >= Knee Y + this value for depth
            lockout_threshold: Knee angle threshold for lockout (degrees)
            pose_min_visibility: Min visibility for required landmarks (0-1)
            motion_scale_threshold: Max bounding box scale change to allow counting
            rep_cooldown_frames: Minimum frames between rep counts
            rep_cooldown_seconds: Minimum seconds between rep counts
            knee_angle_depth_threshold: Knee angle (degrees) at which rep_ready arms (lower = deeper)
        """
        self.depth_threshold = depth_threshold
        self.lockout_threshold = lockout_threshold
        self.pose_min_visibility = pose_min_visibility
        self.motion_scale_threshold = motion_scale_threshold
        self.rep_cooldown_frames = rep_cooldown_frames
        self.rep_cooldown_seconds = rep_cooldown_seconds
        self.knee_angle_depth_threshold = knee_angle_depth_threshold

        # State
        self.phase = SquatPhase.TOP
        self.rep_count = 0

        # Current rep tracking
        self.current_rep_start_time: Optional[float] = None
        self.min_knee_angle_this_rep: float = 180.0
        self.depth_reached_this_rep: bool = False

        # Knee-angle-based rep_ready latch (arms when depth achieved, persists until rep counted)
        self._rep_ready: bool = False
        self._min_knee_angle_for_ready: float = 180.0  # Min knee angle seen, lower = deeper squat

        # Rep ownership latch: each squat cycle may produce AT MOST ONE rep
        self._rep_consumed: bool = False  # True after a rep is counted, reset on new cycle

        # Depth-exit based rep finalization (independent of phase state machine)
        self._exited_depth: bool = False  # True when knee angle rises above lockout threshold after depth
        self._depth_entry_timestamp: Optional[float] = None  # When depth was first achieved this cycle

        # Phase transition tracking
        self.prev_knee_angle: float = 180.0
        self.frames_in_phase: int = 0
        self.last_timestamp: float = 0.0

        # Gate tracking
        self._prev_bbox_height: Optional[float] = None
        self._motion_frozen_frames: int = 0
        self._last_rep_timestamp: float = 0.0
        self._last_rep_frame: int = 0
        self._frame_count: int = 0
        self._stable_frames: int = 0

        # Set boundary tracking
        self._set_armed: bool = False
        self._set_disarm_frames: int = 0  # Frames of standing tall + motion stable
    
    def _check_pose_validity(
        self,
        landmarks: Optional[List[Tuple[float, float, float]]],
    ) -> Tuple[bool, float]:
        """
        Check if at least ONE leg (left OR right) has visible landmarks.

        In side-view, one leg is often occluded. We only need one visible leg
        to compute knee angle reliably.

        Args:
            landmarks: List of (x, y, visibility) tuples, or None

        Returns:
            (is_valid, best_leg_min_confidence) tuple
        """
        if landmarks is None:
            return False, 0.0

        def check_leg(leg_indices: List[int]) -> float:
            """Return min visibility for a leg, or 0 if any landmark missing."""
            min_vis = 1.0
            for idx in leg_indices:
                if idx >= len(landmarks):
                    return 0.0
                min_vis = min(min_vis, landmarks[idx][2])
            return min_vis

        left_conf = check_leg(self.LEFT_LEG_LANDMARKS)
        right_conf = check_leg(self.RIGHT_LEG_LANDMARKS)

        # Use the better leg's confidence
        best_conf = max(left_conf, right_conf)

        return best_conf >= self.pose_min_visibility, best_conf

    def _check_motion_gate(
        self,
        landmarks: Optional[List[Tuple[float, float, float]]],
    ) -> Tuple[bool, float]:
        """
        Detect forward-walk / non-squat motion using bounding box scaling.

        When walking toward camera, the person's bounding box grows rapidly.
        This heuristic detects that and freezes counting.

        Args:
            landmarks: List of (x, y, visibility) tuples

        Returns:
            (motion_valid, scale_delta) - motion_valid is False if walking detected
        """
        if landmarks is None:
            return True, 0.0

        # Compute bounding box height from shoulder to ankle
        # Using indices: shoulders (11,12), ankles (27,28)
        try:
            shoulder_y = min(landmarks[11][1], landmarks[12][1])
            ankle_y = max(landmarks[27][1], landmarks[28][1])
            bbox_height = ankle_y - shoulder_y
        except (IndexError, TypeError):
            return True, 0.0

        if bbox_height <= 0:
            return True, 0.0

        scale_delta = 0.0
        if self._prev_bbox_height is not None and self._prev_bbox_height > 0:
            scale_delta = abs(bbox_height - self._prev_bbox_height) / self._prev_bbox_height

        self._prev_bbox_height = bbox_height

        # Check if scale change exceeds threshold (walking toward/away from camera)
        if scale_delta > self.motion_scale_threshold:
            self._motion_frozen_frames = self.MOTION_STABLE_FRAMES
            self._stable_frames = 0
            return False, scale_delta

        # Count stable frames
        if self._motion_frozen_frames > 0:
            self._stable_frames += 1
            if self._stable_frames >= self.MOTION_STABLE_FRAMES:
                self._motion_frozen_frames = 0
                self._stable_frames = 0
            else:
                return False, scale_delta

        return True, scale_delta

    def _check_cooldown(self, timestamp: float) -> bool:
        """
        Check if we're still in cooldown period after last rep.

        Returns:
            True if cooldown is active (should block rep counting)
        """
        frames_since_rep = self._frame_count - self._last_rep_frame
        time_since_rep = timestamp - self._last_rep_timestamp

        return (
            frames_since_rep < self.rep_cooldown_frames
            or time_since_rep < self.rep_cooldown_seconds
        )

    def update(
        self,
        knee_angle: float,
        hip_y: float,
        knee_y: float,
        timestamp: float,
        landmarks: Optional[List[Tuple[float, float, float]]] = None,
    ) -> RepResult:
        """
        Update state machine with current frame data.

        Args:
            knee_angle: Current knee angle in degrees (180 = straight)
            hip_y: Normalized Y position of hip (0=top, 1=bottom of frame)
            knee_y: Normalized Y position of knee
            timestamp: Current timestamp in seconds
            landmarks: Optional list of (x, y, visibility) for gate checks

        Returns:
            RepResult with current state and rep info
        """
        self._frame_count += 1
        rep_completed = False
        rep_duration_ms = 0.0

        # Check validation gates
        pose_valid, pose_conf = self._check_pose_validity(landmarks)
        motion_valid, scale_delta = self._check_motion_gate(landmarks)
        cooldown_active = self._check_cooldown(timestamp)

        # Set boundary logic: arm on deliberate descent, disarm on prolonged standing
        # Arm: knee angle drops below threshold (deliberate squat initiation)
        if knee_angle <= self.SET_ARM_ANGLE_THRESHOLD:
            self._set_armed = True
            self._set_disarm_frames = 0  # Reset disarm counter when actively squatting
            # Reset rep_consumed: new squat cycle can produce a new rep
            self._rep_consumed = False

        # Disarm: standing tall (high knee angle) AND motion stable for N frames
        # OR immediate disarm if standing upright AND walking detected (motion_valid=False)
        if self._set_armed:
            standing_tall = knee_angle >= self.SET_DISARM_ANGLE_THRESHOLD

            # Immediate disarm: upright + walking (motion invalid while standing)
            # This prevents phantom reps when walking away after a set
            if standing_tall and not motion_valid:
                self._set_armed = False
                self._set_disarm_frames = 0
            elif standing_tall and motion_valid:
                # Normal disarm: standing tall + motion stable for N frames
                self._set_disarm_frames += 1
                if self._set_disarm_frames >= self.SET_DISARM_STABLE_FRAMES:
                    self._set_armed = False
                    self._set_disarm_frames = 0
            else:
                # Reset disarm counter if not standing tall
                self._set_disarm_frames = 0

        gate_status = GateStatus(
            pose_valid=pose_valid,
            motion_valid=motion_valid,
            cooldown_active=cooldown_active,
            set_armed=self._set_armed,
            pose_confidence=pose_conf,
            motion_scale_delta=scale_delta,
        )

        # Track min angle for this rep
        if self.phase in (SquatPhase.DESCENDING, SquatPhase.BOTTOM, SquatPhase.ASCENDING):
            self.min_knee_angle_this_rep = min(self.min_knee_angle_this_rep, knee_angle)

        # Check depth (hip below or at knee level)
        hip_below_knee = hip_y >= (knee_y + self.depth_threshold)
        if hip_below_knee and self.phase in (SquatPhase.DESCENDING, SquatPhase.BOTTOM):
            self.depth_reached_this_rep = True

        # Knee-angle-based rep_ready latch (camera-angle invariant)
        # Track min knee angle seen this rep (lower = deeper squat)
        if self.phase in (SquatPhase.DESCENDING, SquatPhase.BOTTOM, SquatPhase.ASCENDING):
            self._min_knee_angle_for_ready = min(self._min_knee_angle_for_ready, knee_angle)

        # Arm rep_ready when knee angle drops below threshold (latch stays armed until rep counted)
        # This is based on knee angle, NOT hip-vs-knee screen position which varies with camera angle
        if knee_angle <= self.knee_angle_depth_threshold:
            if not self._rep_ready:
                # First frame entering depth - record timestamp
                self._depth_entry_timestamp = timestamp
            self._rep_ready = True
            self._exited_depth = False  # Reset exit flag when entering depth

        # Track depth exit: knee angle rises above lockout threshold after depth was achieved
        # This is independent of phase state machine - works even if pose landmarks drop
        if self._rep_ready and knee_angle >= self.lockout_threshold:
            self._exited_depth = True

        # DEPTH-EXIT BASED REP FINALIZATION (independent of phase state machine)
        # Count a rep when: depth achieved, exited depth, set armed, not consumed, not in cooldown
        # AND minimum time spent in depth (prevents FPS-dependent false positives from brief bends)
        # This works even if head turn causes landmark dropout during ascent
        depth_duration_ok = (
            self._depth_entry_timestamp is not None and
            (timestamp - self._depth_entry_timestamp) >= self.MIN_DEPTH_TIME
        )

        if (self._rep_ready and self._exited_depth and depth_duration_ok and
                self._set_armed and not self._rep_consumed and not cooldown_active and
                pose_valid and motion_valid):
            self.rep_count += 1
            rep_completed = True
            self._last_rep_timestamp = timestamp
            self._last_rep_frame = self._frame_count
            self._rep_consumed = True  # This cycle has claimed its rep

            if self.current_rep_start_time is not None:
                rep_duration_ms = (timestamp - self.current_rep_start_time) * 1000

            # Reset latches after counting
            self._rep_ready = False
            self._exited_depth = False
            self._min_knee_angle_for_ready = 180.0
            self._depth_entry_timestamp = None

        # State machine transitions
        prev_phase = self.phase

        if self.phase == SquatPhase.TOP:
            # Check for descent start
            if knee_angle < self.prev_knee_angle - self.DESCENDING_ANGLE_DELTA:
                self.phase = SquatPhase.DESCENDING
                self.current_rep_start_time = timestamp
                self.min_knee_angle_this_rep = knee_angle
                self.depth_reached_this_rep = False
        
        elif self.phase == SquatPhase.DESCENDING:
            # Check for bottom position
            if hip_below_knee:
                self.frames_in_phase += 1
                if self.frames_in_phase >= self.BOTTOM_HOLD_FRAMES:
                    self.phase = SquatPhase.BOTTOM
                    self.frames_in_phase = 0
            else:
                self.frames_in_phase = 0
            
            # Check if ascending without reaching depth (partial rep)
            if knee_angle > self.prev_knee_angle + self.ASCENDING_ANGLE_DELTA:
                if not hip_below_knee:
                    # Didn't reach depth - still track as ascending
                    self.phase = SquatPhase.ASCENDING
        
        elif self.phase == SquatPhase.BOTTOM:
            # Check for ascent start
            if knee_angle > self.prev_knee_angle + self.ASCENDING_ANGLE_DELTA:
                self.phase = SquatPhase.ASCENDING
        
        elif self.phase == SquatPhase.ASCENDING:
            # Check for lockout
            if knee_angle >= self.lockout_threshold:
                self.frames_in_phase += 1
                if self.frames_in_phase >= self.LOCKOUT_HOLD_FRAMES:
                    self.phase = SquatPhase.LOCKOUT
                    self.frames_in_phase = 0
            else:
                self.frames_in_phase = 0
            
            # Check if descending again (didn't complete rep)
            if knee_angle < self.prev_knee_angle - self.DESCENDING_ANGLE_DELTA:
                self.phase = SquatPhase.DESCENDING
        
        elif self.phase == SquatPhase.LOCKOUT:
            # LOCKOUT phase is now only used for phase display, not rep finalization
            # Rep finalization is handled by depth-exit logic above (independent of phase)
            # Always transition to TOP (don't leave state stuck in LOCKOUT)
            self.phase = SquatPhase.TOP
            self.current_rep_start_time = None
        
        # Update tracking
        self.prev_knee_angle = knee_angle
        self.last_timestamp = timestamp
        
        # Reset phase counter on phase change
        if self.phase != prev_phase:
            self.frames_in_phase = 0
        
        return RepResult(
            phase=self.phase,
            rep_completed=rep_completed,
            rep_count=self.rep_count,
            rep_duration_ms=rep_duration_ms,
            min_knee_angle=self.min_knee_angle_this_rep,
            depth_reached=self.depth_reached_this_rep,
            gate_status=gate_status,
        )
    
    def reset(self) -> None:
        """Reset counter for new session."""
        self.phase = SquatPhase.TOP
        self.rep_count = 0
        self.current_rep_start_time = None
        self.min_knee_angle_this_rep = 180.0
        self.depth_reached_this_rep = False
        self.prev_knee_angle = 180.0
        self.frames_in_phase = 0
        self.last_timestamp = 0.0
        # Reset rep_ready latch
        self._rep_ready = False
        self._min_knee_angle_for_ready = 180.0
        # Reset rep ownership latch
        self._rep_consumed = False
        # Reset depth-exit tracking
        self._exited_depth = False
        self._depth_entry_timestamp = None
        # Reset gate tracking
        self._prev_bbox_height = None
        self._motion_frozen_frames = 0
        self._last_rep_timestamp = 0.0
        self._last_rep_frame = 0
        self._frame_count = 0
        self._stable_frames = 0
        # Reset set boundary tracking
        self._set_armed = False
        self._set_disarm_frames = 0
    
    def get_state(self) -> Dict:
        """Get current state as dictionary."""
        return {
            "phase": self.phase.value,
            "rep_count": self.rep_count,
            "min_knee_angle_this_rep": self.min_knee_angle_this_rep,
            "depth_reached_this_rep": self.depth_reached_this_rep,
        }


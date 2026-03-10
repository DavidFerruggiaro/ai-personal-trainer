"""
Form feedback analysis for squat technique.
Analyzes depth, torso lean, and knee valgus.
"""

from dataclasses import dataclass
from typing import Dict, List, Optional, Tuple
import sys
import os

# Add parent directory for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from utils.math_utils import calculate_vertical_angle, distance_2d
from .pose_pipeline import (
    LEFT_SHOULDER, RIGHT_SHOULDER,
    LEFT_HIP, RIGHT_HIP,
    LEFT_KNEE, RIGHT_KNEE,
    LEFT_ANKLE, RIGHT_ANKLE,
)


@dataclass
class FormAnalysis:
    """Result of form analysis for a single frame."""
    depth_ok: bool
    depth_message: str
    torso_ok: bool
    torso_message: str
    valgus_ok: bool
    valgus_message: str
    quality_tag: str  # "explosive" | "good" | "grind"
    
    def all_ok(self) -> bool:
        """Check if all form aspects are good."""
        return self.depth_ok and self.torso_ok and self.valgus_ok
    
    def get_issues(self) -> List[str]:
        """Get list of current form issues."""
        issues = []
        if not self.depth_ok:
            issues.append(self.depth_message)
        if not self.torso_ok:
            issues.append(self.torso_message)
        if not self.valgus_ok:
            issues.append(self.valgus_message)
        return issues


class FormFeedback:
    """
    Analyzes squat form and provides feedback.
    
    Checks:
    - Depth: Whether hips go below knees
    - Torso: Forward lean angle
    - Valgus: Knee cave-in
    
    Also determines rep quality based on duration:
    - explosive: < 800ms
    - good: 800ms - 2500ms
    - grind: > 2500ms
    
    Usage:
        feedback = FormFeedback()
        analysis = feedback.analyze(landmarks, rep_duration_ms)
        if not analysis.depth_ok:
            print(analysis.depth_message)
    """
    
    # Quality thresholds (milliseconds)
    EXPLOSIVE_THRESHOLD_MS = 800.0
    GRIND_THRESHOLD_MS = 2500.0
    
    def __init__(
        self,
        depth_threshold: float = 0.0,
        torso_lean_max: float = 45.0,
        valgus_threshold: float = 0.05,
    ):
        """
        Initialize form feedback analyzer.
        
        Args:
            depth_threshold: Hip Y must be >= Knee Y + threshold for good depth
            torso_lean_max: Maximum acceptable forward lean in degrees
            valgus_threshold: Maximum acceptable knee inward ratio
        """
        self.depth_threshold = depth_threshold
        self.torso_lean_max = torso_lean_max
        self.valgus_threshold = valgus_threshold
    
    def analyze(
        self,
        landmarks: List[tuple],
        rep_duration_ms: float = 0.0,
    ) -> FormAnalysis:
        """
        Analyze form from current landmarks.
        
        Args:
            landmarks: List of (x, y, visibility) tuples
            rep_duration_ms: Duration of the rep (for quality tag)
            
        Returns:
            FormAnalysis with all feedback
        """
        # Extract joints
        left_shoulder = landmarks[LEFT_SHOULDER] if len(landmarks) > LEFT_SHOULDER else None
        right_shoulder = landmarks[RIGHT_SHOULDER] if len(landmarks) > RIGHT_SHOULDER else None
        left_hip = landmarks[LEFT_HIP] if len(landmarks) > LEFT_HIP else None
        right_hip = landmarks[RIGHT_HIP] if len(landmarks) > RIGHT_HIP else None
        left_knee = landmarks[LEFT_KNEE] if len(landmarks) > LEFT_KNEE else None
        right_knee = landmarks[RIGHT_KNEE] if len(landmarks) > RIGHT_KNEE else None
        
        # Check depth
        depth_ok, depth_message = self._check_depth(left_hip, right_hip, left_knee, right_knee)
        
        # Check torso
        torso_ok, torso_message = self._check_torso(
            left_shoulder, right_shoulder, left_hip, right_hip
        )
        
        # Check valgus
        valgus_ok, valgus_message = self._check_valgus(
            left_knee, right_knee, left_hip, right_hip
        )
        
        # Determine quality
        quality_tag = self._determine_quality(rep_duration_ms)
        
        return FormAnalysis(
            depth_ok=depth_ok,
            depth_message=depth_message,
            torso_ok=torso_ok,
            torso_message=torso_message,
            valgus_ok=valgus_ok,
            valgus_message=valgus_message,
            quality_tag=quality_tag,
        )
    
    def _check_depth(
        self,
        left_hip: Optional[tuple],
        right_hip: Optional[tuple],
        left_knee: Optional[tuple],
        right_knee: Optional[tuple],
    ) -> Tuple[bool, str]:
        """
        Check squat depth.
        
        Returns:
            (is_ok, message)
        """
        if not all([left_hip, right_hip, left_knee, right_knee]):
            return True, ""  # Can't assess, assume ok
        
        # Average hip and knee Y positions
        hip_y = (left_hip[1] + right_hip[1]) / 2
        knee_y = (left_knee[1] + right_knee[1]) / 2
        
        # In normalized coords, higher Y = lower in frame
        # Depth is good when hip Y >= knee Y (hip at or below knee)
        depth_ok = hip_y >= (knee_y + self.depth_threshold)
        
        if depth_ok:
            return True, "Good depth"
        else:
            return False, "Go deeper"
    
    def _check_torso(
        self,
        left_shoulder: Optional[tuple],
        right_shoulder: Optional[tuple],
        left_hip: Optional[tuple],
        right_hip: Optional[tuple],
    ) -> Tuple[bool, str]:
        """
        Check torso lean angle.
        
        Returns:
            (is_ok, message)
        """
        if not all([left_shoulder, right_shoulder, left_hip, right_hip]):
            return True, ""  # Can't assess
        
        # Calculate midpoints
        shoulder_mid = (
            (left_shoulder[0] + right_shoulder[0]) / 2,
            (left_shoulder[1] + right_shoulder[1]) / 2,
        )
        hip_mid = (
            (left_hip[0] + right_hip[0]) / 2,
            (left_hip[1] + right_hip[1]) / 2,
        )
        
        # Calculate angle from vertical
        lean_angle = calculate_vertical_angle(shoulder_mid, hip_mid)
        
        if lean_angle <= self.torso_lean_max:
            return True, "Torso upright"
        else:
            return False, "Chest up"
    
    def _check_valgus(
        self,
        left_knee: Optional[tuple],
        right_knee: Optional[tuple],
        left_hip: Optional[tuple],
        right_hip: Optional[tuple],
    ) -> Tuple[bool, str]:
        """
        Check knee valgus (inward collapse).
        
        Compares knee width to hip width - if knees cave in
        significantly compared to hip width, it's valgus.
        
        Returns:
            (is_ok, message)
        """
        if not all([left_knee, right_knee, left_hip, right_hip]):
            return True, ""  # Can't assess
        
        # Calculate widths
        hip_width = abs(right_hip[0] - left_hip[0])
        knee_width = abs(right_knee[0] - left_knee[0])
        
        if hip_width < 0.01:  # Avoid division by zero
            return True, ""
        
        # Ratio of knee width to hip width
        # If knees cave in, knee_width will be less than hip_width
        width_ratio = knee_width / hip_width
        
        # Valgus if knees are significantly closer than hips
        # ratio < (1 - threshold) indicates cave-in
        if width_ratio >= (1.0 - self.valgus_threshold):
            return True, "Knees tracking well"
        else:
            return False, "Knees out"
    
    def _determine_quality(self, rep_duration_ms: float) -> str:
        """
        Determine rep quality tag based on duration.
        
        Args:
            rep_duration_ms: Rep duration in milliseconds
            
        Returns:
            "explosive", "good", or "grind"
        """
        if rep_duration_ms <= 0:
            return "good"  # No duration info
        
        if rep_duration_ms < self.EXPLOSIVE_THRESHOLD_MS:
            return "explosive"
        elif rep_duration_ms > self.GRIND_THRESHOLD_MS:
            return "grind"
        else:
            return "good"
    
    def analyze_rep_summary(
        self,
        depth_reached: bool,
        min_knee_angle: float,
        rep_duration_ms: float,
        torso_issues_count: int = 0,
        valgus_issues_count: int = 0,
        total_frames: int = 1,
    ) -> FormAnalysis:
        """
        Analyze form for a completed rep based on aggregated data.
        
        Args:
            depth_reached: Whether depth was reached during rep
            min_knee_angle: Minimum knee angle during rep
            rep_duration_ms: Total rep duration
            torso_issues_count: Number of frames with torso issues
            valgus_issues_count: Number of frames with valgus issues
            total_frames: Total frames in the rep
            
        Returns:
            FormAnalysis summarizing the rep
        """
        # Depth
        depth_ok = depth_reached
        depth_message = "Good depth" if depth_ok else "Didn't hit depth"
        
        # Torso - issue if >30% of frames had problems
        torso_ratio = torso_issues_count / max(1, total_frames)
        torso_ok = torso_ratio < 0.3
        torso_message = "Torso upright" if torso_ok else "Too much forward lean"
        
        # Valgus - issue if >30% of frames had problems
        valgus_ratio = valgus_issues_count / max(1, total_frames)
        valgus_ok = valgus_ratio < 0.3
        valgus_message = "Knees tracking well" if valgus_ok else "Knee cave detected"
        
        # Quality
        quality_tag = self._determine_quality(rep_duration_ms)
        
        return FormAnalysis(
            depth_ok=depth_ok,
            depth_message=depth_message,
            torso_ok=torso_ok,
            torso_message=torso_message,
            valgus_ok=valgus_ok,
            valgus_message=valgus_message,
            quality_tag=quality_tag,
        )


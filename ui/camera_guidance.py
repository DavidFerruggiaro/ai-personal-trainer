"""
Camera positioning guidance for optimal pose detection.
Provides instructions and validates user positioning.
"""

from typing import List, Tuple, Optional
import sys
import os

# Add parent directory for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.pose_pipeline import (
    LEFT_SHOULDER, RIGHT_SHOULDER,
    LEFT_HIP, RIGHT_HIP,
    LEFT_KNEE, RIGHT_KNEE,
    LEFT_ANKLE, RIGHT_ANKLE,
)


class CameraGuidance:
    """
    Provides camera setup instructions and validates user positioning.
    
    Checks:
    - All key joints are visible
    - User is in approximate side-view position
    - User is at appropriate distance from camera
    
    Usage:
        guidance = CameraGuidance()
        instructions = guidance.get_setup_instructions()
        is_valid, message = guidance.validate_positioning(landmarks)
    """
    
    # Key joints required for squat analysis
    REQUIRED_JOINTS = [
        LEFT_SHOULDER, RIGHT_SHOULDER,
        LEFT_HIP, RIGHT_HIP,
        LEFT_KNEE, RIGHT_KNEE,
        LEFT_ANKLE, RIGHT_ANKLE,
    ]
    
    # Visibility threshold
    MIN_VISIBILITY = 0.5
    
    # Distance thresholds (normalized coordinates)
    MIN_BODY_HEIGHT = 0.4   # Body should take up at least 40% of frame
    MAX_BODY_HEIGHT = 0.95  # Body shouldn't be cut off
    
    @staticmethod
    def get_setup_instructions() -> List[str]:
        """
        Get list of camera positioning instructions.
        
        Returns:
            List of instruction strings
        """
        return [
            "📷 Position camera at hip height",
            "↔️ Stand sideways to the camera (perpendicular)",
            "📏 Move so your full body is visible (head to feet)",
            "💡 Ensure good lighting on your body",
            "🎯 Stand 6-8 feet from the camera",
        ]
    
    @staticmethod
    def get_quick_tips() -> List[str]:
        """
        Get quick tips for better tracking.
        
        Returns:
            List of tip strings
        """
        return [
            "Wear fitted clothing for better joint detection",
            "Avoid busy backgrounds if possible",
            "Keep the camera stable during recording",
            "Side view works best for squat analysis",
        ]
    
    def validate_positioning(
        self,
        landmarks: Optional[List[tuple]],
    ) -> Tuple[bool, str]:
        """
        Validate if user is positioned correctly for analysis.
        
        Args:
            landmarks: List of (x, y, visibility) tuples
            
        Returns:
            (is_valid, message) tuple
        """
        if not landmarks:
            return False, "No pose detected. Make sure your full body is visible."
        
        # Check visibility of required joints
        missing_joints = []
        for joint_idx in self.REQUIRED_JOINTS:
            if joint_idx >= len(landmarks):
                missing_joints.append(joint_idx)
                continue
            
            if landmarks[joint_idx][2] < self.MIN_VISIBILITY:
                missing_joints.append(joint_idx)
        
        if missing_joints:
            return False, self._get_visibility_message(missing_joints)
        
        # Check body is in frame properly
        body_check, body_msg = self._check_body_in_frame(landmarks)
        if not body_check:
            return False, body_msg
        
        # Check side view positioning
        side_check, side_msg = self._check_side_view(landmarks)
        if not side_check:
            return False, side_msg
        
        return True, "Good positioning! Ready to analyze."
    
    def _get_visibility_message(self, missing_joints: List[int]) -> str:
        """Get message for missing joints."""
        # Map joint indices to body parts
        joint_names = {
            LEFT_SHOULDER: "left shoulder",
            RIGHT_SHOULDER: "right shoulder",
            LEFT_HIP: "left hip",
            RIGHT_HIP: "right hip",
            LEFT_KNEE: "left knee",
            RIGHT_KNEE: "right knee",
            LEFT_ANKLE: "left ankle",
            RIGHT_ANKLE: "right ankle",
        }
        
        parts = [joint_names.get(j, f"joint {j}") for j in missing_joints[:3]]
        
        if len(missing_joints) > 3:
            return "Can't see enough of your body. Step back and ensure full visibility."
        else:
            return f"Can't see: {', '.join(parts)}. Adjust position."
    
    def _check_body_in_frame(
        self,
        landmarks: List[tuple],
    ) -> Tuple[bool, str]:
        """Check if body takes up appropriate portion of frame."""
        try:
            # Get shoulder and ankle Y positions
            shoulder_y = min(
                landmarks[LEFT_SHOULDER][1],
                landmarks[RIGHT_SHOULDER][1]
            )
            ankle_y = max(
                landmarks[LEFT_ANKLE][1],
                landmarks[RIGHT_ANKLE][1]
            )
            
            body_height = ankle_y - shoulder_y
            
            if body_height < self.MIN_BODY_HEIGHT:
                return False, "Move closer to the camera"
            
            if ankle_y > self.MAX_BODY_HEIGHT or shoulder_y < 0.05:
                return False, "Step back - parts of body are cut off"
            
            return True, ""
            
        except (IndexError, TypeError):
            return False, "Unable to detect body position"
    
    def _check_side_view(
        self,
        landmarks: List[tuple],
    ) -> Tuple[bool, str]:
        """Check if user is in approximate side view."""
        try:
            # Compare X positions of left and right hips
            left_hip_x = landmarks[LEFT_HIP][0]
            right_hip_x = landmarks[RIGHT_HIP][0]
            
            # In perfect side view, hips would overlap
            # Allow some tolerance
            hip_diff = abs(right_hip_x - left_hip_x)
            
            # If hips are too far apart horizontally, user is facing camera
            if hip_diff > 0.15:
                return False, "Turn more to the side (perpendicular to camera)"
            
            return True, ""
            
        except (IndexError, TypeError):
            return True, ""  # Can't check, assume ok
    
    def get_positioning_score(
        self,
        landmarks: Optional[List[tuple]],
    ) -> float:
        """
        Get a 0-1 score for positioning quality.
        
        Args:
            landmarks: Pose landmarks
            
        Returns:
            Score from 0.0 (poor) to 1.0 (excellent)
        """
        if not landmarks:
            return 0.0
        
        score = 0.0
        
        # Visibility score (40%)
        visible_count = 0
        for joint_idx in self.REQUIRED_JOINTS:
            if joint_idx < len(landmarks) and landmarks[joint_idx][2] >= self.MIN_VISIBILITY:
                visible_count += 1
        
        visibility_score = visible_count / len(self.REQUIRED_JOINTS)
        score += visibility_score * 0.4
        
        # Frame coverage score (30%)
        try:
            shoulder_y = min(landmarks[LEFT_SHOULDER][1], landmarks[RIGHT_SHOULDER][1])
            ankle_y = max(landmarks[LEFT_ANKLE][1], landmarks[RIGHT_ANKLE][1])
            body_height = ankle_y - shoulder_y
            
            if self.MIN_BODY_HEIGHT <= body_height <= 0.8:
                score += 0.3
            elif body_height > 0:
                score += 0.15
        except:
            pass
        
        # Side view score (30%)
        try:
            hip_diff = abs(landmarks[RIGHT_HIP][0] - landmarks[LEFT_HIP][0])
            if hip_diff < 0.1:
                score += 0.3
            elif hip_diff < 0.15:
                score += 0.2
            elif hip_diff < 0.25:
                score += 0.1
        except:
            pass
        
        return min(1.0, score)


"""
Pose detection pipeline using MediaPipe.
Wraps MediaPipe Pose and provides consistent landmark access.
"""

import cv2
import numpy as np
from typing import Dict, List, Optional, Tuple

try:
    import mediapipe as mp
    MEDIAPIPE_AVAILABLE = True
except ImportError:
    MEDIAPIPE_AVAILABLE = False

from .smoothing import LandmarkSmoother


# MediaPipe Pose landmark indices
# Reference: https://developers.google.com/mediapipe/solutions/vision/pose_landmarker
LEFT_SHOULDER = 11
RIGHT_SHOULDER = 12
LEFT_HIP = 23
RIGHT_HIP = 24
LEFT_KNEE = 25
RIGHT_KNEE = 26
LEFT_ANKLE = 27
RIGHT_ANKLE = 28
LEFT_HEEL = 29
RIGHT_HEEL = 30
LEFT_FOOT_INDEX = 31
RIGHT_FOOT_INDEX = 32

# Key joints for squat analysis
SQUAT_JOINTS = [
    LEFT_SHOULDER, RIGHT_SHOULDER,
    LEFT_HIP, RIGHT_HIP,
    LEFT_KNEE, RIGHT_KNEE,
    LEFT_ANKLE, RIGHT_ANKLE,
]

# Skeleton connections for drawing
POSE_CONNECTIONS = [
    (LEFT_SHOULDER, RIGHT_SHOULDER),   # shoulders
    (LEFT_SHOULDER, LEFT_HIP),          # left torso
    (RIGHT_SHOULDER, RIGHT_HIP),        # right torso
    (LEFT_HIP, RIGHT_HIP),              # hips
    (LEFT_HIP, LEFT_KNEE),              # left thigh
    (RIGHT_HIP, RIGHT_KNEE),            # right thigh
    (LEFT_KNEE, LEFT_ANKLE),            # left shin
    (RIGHT_KNEE, RIGHT_ANKLE),          # right shin
]


class PosePipeline:
    """
    MediaPipe Pose wrapper with smoothing and consistent interface.
    
    Isolates MediaPipe dependency and provides normalized landmarks
    suitable for cross-platform use.
    
    Usage:
        pipeline = PosePipeline()
        result = pipeline.process_frame(frame_bgr)
        if result:
            landmarks = result["landmarks"]
            knee_angle = calculate_angle(hip, knee, ankle)
    """
    
    def __init__(
        self,
        smoothing_window: int = 5,
        min_detection_confidence: float = 0.5,
        min_tracking_confidence: float = 0.5,
        model_complexity: int = 1,
    ):
        """
        Initialize the pose pipeline.
        
        Args:
            smoothing_window: Window size for Savitzky-Golay smoothing
            min_detection_confidence: Minimum confidence for initial detection
            min_tracking_confidence: Minimum confidence for tracking
            model_complexity: MediaPipe model complexity (0, 1, or 2)
        """
        if not MEDIAPIPE_AVAILABLE:
            raise RuntimeError("MediaPipe is not installed. Run: pip install mediapipe")
        
        self.mp_pose = mp.solutions.pose
        self.pose = self.mp_pose.Pose(
            static_image_mode=False,
            model_complexity=model_complexity,
            enable_segmentation=False,
            min_detection_confidence=min_detection_confidence,
            min_tracking_confidence=min_tracking_confidence,
        )
        
        self.smoother = LandmarkSmoother(window_size=smoothing_window)
        self._last_result = None
    
    def process_frame(self, frame_bgr: np.ndarray) -> Optional[Dict]:
        """
        Process a single frame and extract pose landmarks.
        
        Args:
            frame_bgr: Input frame in BGR format (OpenCV default)
            
        Returns:
            Dictionary with:
            - landmarks: List of (x, y, visibility) tuples (normalized 0-1)
            - raw_landmarks: Unsmoothed landmarks
            - frame_shape: (height, width) of input frame
            
            Returns None if no pose detected.
        """
        if frame_bgr is None or frame_bgr.size == 0:
            return None
        
        # Convert BGR to RGB for MediaPipe
        frame_rgb = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)
        
        # Process with MediaPipe
        results = self.pose.process(frame_rgb)
        
        if not results.pose_landmarks:
            return None
        
        # Extract landmarks as list of tuples
        raw_landmarks = []
        for lm in results.pose_landmarks.landmark:
            raw_landmarks.append((lm.x, lm.y, lm.visibility))
        
        # Apply smoothing
        smoothed_landmarks = self.smoother.smooth(raw_landmarks)
        
        h, w = frame_bgr.shape[:2]
        
        self._last_result = {
            "landmarks": smoothed_landmarks,
            "raw_landmarks": raw_landmarks,
            "frame_shape": (h, w),
        }
        
        return self._last_result
    
    def get_joint(
        self, 
        landmarks: List[tuple], 
        joint_idx: int
    ) -> Optional[Tuple[float, float, float]]:
        """
        Extract a specific joint from landmarks.
        
        Args:
            landmarks: List of (x, y, visibility) tuples
            joint_idx: MediaPipe joint index constant
            
        Returns:
            (x, y, visibility) tuple or None if index invalid
        """
        if not landmarks or joint_idx >= len(landmarks):
            return None
        return landmarks[joint_idx]
    
    def get_joint_pixel(
        self,
        landmarks: List[tuple],
        joint_idx: int,
        frame_width: int,
        frame_height: int,
    ) -> Optional[Tuple[int, int, float]]:
        """
        Get joint position in pixel coordinates.
        
        Args:
            landmarks: List of normalized landmarks
            joint_idx: Joint index
            frame_width: Frame width in pixels
            frame_height: Frame height in pixels
            
        Returns:
            (x_px, y_px, visibility) or None
        """
        joint = self.get_joint(landmarks, joint_idx)
        if joint is None:
            return None
        
        x_px = int(joint[0] * frame_width)
        y_px = int(joint[1] * frame_height)
        return (x_px, y_px, joint[2])
    
    def get_squat_joints(self, landmarks: List[tuple]) -> Dict[str, Tuple[float, float, float]]:
        """
        Get all joints relevant for squat analysis.
        
        Args:
            landmarks: List of landmarks
            
        Returns:
            Dictionary mapping joint names to (x, y, visibility)
        """
        return {
            "left_shoulder": self.get_joint(landmarks, LEFT_SHOULDER),
            "right_shoulder": self.get_joint(landmarks, RIGHT_SHOULDER),
            "left_hip": self.get_joint(landmarks, LEFT_HIP),
            "right_hip": self.get_joint(landmarks, RIGHT_HIP),
            "left_knee": self.get_joint(landmarks, LEFT_KNEE),
            "right_knee": self.get_joint(landmarks, RIGHT_KNEE),
            "left_ankle": self.get_joint(landmarks, LEFT_ANKLE),
            "right_ankle": self.get_joint(landmarks, RIGHT_ANKLE),
        }
    
    def check_visibility(
        self, 
        landmarks: List[tuple], 
        joint_indices: List[int],
        min_visibility: float = 0.5,
    ) -> Tuple[bool, List[int]]:
        """
        Check if required joints are visible.
        
        Args:
            landmarks: List of landmarks
            joint_indices: Indices of joints to check
            min_visibility: Minimum visibility threshold
            
        Returns:
            (all_visible, list_of_missing_indices)
        """
        missing = []
        for idx in joint_indices:
            joint = self.get_joint(landmarks, idx)
            if joint is None or joint[2] < min_visibility:
                missing.append(idx)
        
        return len(missing) == 0, missing
    
    def reset(self) -> None:
        """Reset smoother for new session."""
        self.smoother.reset()
        self._last_result = None
    
    def cleanup(self) -> None:
        """Release MediaPipe resources."""
        if self.pose:
            self.pose.close()


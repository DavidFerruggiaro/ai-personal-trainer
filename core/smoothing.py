"""
Landmark smoothing using Savitzky-Golay filter.
Reduces jitter in pose detection while preserving movement dynamics.
"""

from collections import deque
from typing import List, Optional
import numpy as np

try:
    from scipy.signal import savgol_filter
    SCIPY_AVAILABLE = True
except ImportError:
    SCIPY_AVAILABLE = False


class LandmarkSmoother:
    """
    Applies Savitzky-Golay smoothing to landmark sequences.
    
    The filter smooths each landmark coordinate independently over
    a sliding window, reducing noise while preserving peaks and
    movement dynamics.
    
    Usage:
        smoother = LandmarkSmoother(window_size=5)
        smoothed = smoother.smooth(landmarks)
    """
    
    def __init__(self, window_size: int = 5, poly_order: int = 2):
        """
        Initialize the smoother.
        
        Args:
            window_size: Number of frames to use for smoothing (must be odd)
            poly_order: Polynomial order for Savitzky-Golay filter
        """
        # Ensure window size is odd
        if window_size % 2 == 0:
            window_size += 1
        
        self.window_size = window_size
        self.poly_order = min(poly_order, window_size - 1)
        self.buffer: deque = deque(maxlen=window_size)
    
    def smooth(self, landmarks: List[tuple]) -> List[tuple]:
        """
        Apply smoothing to the current landmarks.
        
        Adds the landmarks to the buffer and returns smoothed version
        based on the buffer history.
        
        Args:
            landmarks: List of (x, y, visibility) tuples for each joint
            
        Returns:
            Smoothed landmarks as list of (x, y, visibility) tuples
        """
        if not landmarks:
            return landmarks
        
        # Add to buffer
        self.buffer.append(landmarks)
        
        # Not enough history yet - return as-is
        if len(self.buffer) < self.window_size:
            return landmarks
        
        # Apply Savitzky-Golay filter if scipy available
        if SCIPY_AVAILABLE:
            return self._apply_savgol()
        else:
            return self._apply_moving_average()
    
    def _apply_savgol(self) -> List[tuple]:
        """Apply Savitzky-Golay filter to buffer."""
        num_landmarks = len(self.buffer[0])
        smoothed = []
        
        for i in range(num_landmarks):
            # Extract x, y, visibility for this landmark across all frames
            xs = [frame[i][0] for frame in self.buffer]
            ys = [frame[i][1] for frame in self.buffer]
            vis = [frame[i][2] if len(frame[i]) > 2 else 1.0 for frame in self.buffer]
            
            # Apply filter
            smooth_x = savgol_filter(xs, self.window_size, self.poly_order)
            smooth_y = savgol_filter(ys, self.window_size, self.poly_order)
            
            # Use the center value (current frame)
            center_idx = self.window_size // 2
            smoothed.append((
                float(smooth_x[center_idx]),
                float(smooth_y[center_idx]),
                float(vis[center_idx])
            ))
        
        return smoothed
    
    def _apply_moving_average(self) -> List[tuple]:
        """Fallback: simple moving average if scipy not available."""
        num_landmarks = len(self.buffer[0])
        smoothed = []
        
        for i in range(num_landmarks):
            xs = [frame[i][0] for frame in self.buffer]
            ys = [frame[i][1] for frame in self.buffer]
            vis = [frame[i][2] if len(frame[i]) > 2 else 1.0 for frame in self.buffer]
            
            smoothed.append((
                float(np.mean(xs)),
                float(np.mean(ys)),
                float(vis[-1])  # Use most recent visibility
            ))
        
        return smoothed
    
    def reset(self) -> None:
        """Clear the buffer for a new session."""
        self.buffer.clear()


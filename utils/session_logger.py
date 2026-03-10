"""
Session logging for tracking workout data.
Collects rep data and provides summary statistics.
"""

from dataclasses import dataclass, field
from typing import List, Dict, Any
from datetime import datetime


@dataclass
class RepData:
    """Data for a single rep."""
    rep_number: int
    depth_ok: bool
    torso_ok: bool
    valgus_ok: bool
    quality_tag: str  # "explosive" | "good" | "grind"
    duration_ms: float
    min_knee_angle: float = 180.0
    timestamp: float = 0.0


class SessionLogger:
    """
    Logs workout session data and provides summary statistics.
    
    Usage:
        logger = SessionLogger()
        logger.log_rep(RepData(...))
        summary = logger.get_summary()
    """
    
    def __init__(self):
        self.reps: List[RepData] = []
        self.start_time: datetime = datetime.now()
        self.frames_processed: int = 0
        self.frames_with_detection: int = 0
    
    def log_rep(self, rep_data: RepData) -> None:
        """
        Log a completed rep.
        
        Args:
            rep_data: RepData object with rep information
        """
        self.reps.append(rep_data)
    
    def log_frame(self, detected: bool) -> None:
        """
        Log frame processing result for detection rate tracking.
        
        Args:
            detected: Whether pose was detected in this frame
        """
        self.frames_processed += 1
        if detected:
            self.frames_with_detection += 1
    
    def get_summary(self) -> Dict[str, Any]:
        """
        Get session summary statistics.
        
        Returns:
            Dictionary with:
            - total_reps: int
            - good_form_pct: float (0-100)
            - dominant_quality: str
            - detection_rate: float (0-100)
            - rep_details: list of rep dictionaries
            - quality_distribution: dict
        """
        if not self.reps:
            return {
                "total_reps": 0,
                "good_form_pct": 0.0,
                "dominant_quality": "N/A",
                "detection_rate": self._get_detection_rate(),
                "rep_details": [],
                "quality_distribution": {"explosive": 0, "good": 0, "grind": 0},
                "avg_duration_ms": 0.0,
            }
        
        # Calculate good form percentage
        good_form_count = sum(
            1 for r in self.reps 
            if r.depth_ok and r.torso_ok and r.valgus_ok
        )
        good_form_pct = (good_form_count / len(self.reps)) * 100
        
        # Calculate quality distribution
        quality_dist = {"explosive": 0, "good": 0, "grind": 0}
        for rep in self.reps:
            if rep.quality_tag in quality_dist:
                quality_dist[rep.quality_tag] += 1
        
        # Determine dominant quality
        dominant_quality = max(quality_dist, key=quality_dist.get)
        
        # Average duration
        avg_duration = sum(r.duration_ms for r in self.reps) / len(self.reps)
        
        # Build rep details list
        rep_details = []
        for rep in self.reps:
            rep_details.append({
                "rep": rep.rep_number,
                "depth": "OK" if rep.depth_ok else "SHALLOW",
                "torso": "OK" if rep.torso_ok else "FORWARD",
                "valgus": "OK" if rep.valgus_ok else "CAVE-IN",
                "quality": rep.quality_tag,
                "duration_ms": round(rep.duration_ms, 0),
                "min_angle": round(rep.min_knee_angle, 1),
            })
        
        return {
            "total_reps": len(self.reps),
            "good_form_pct": round(good_form_pct, 1),
            "dominant_quality": dominant_quality,
            "detection_rate": self._get_detection_rate(),
            "rep_details": rep_details,
            "quality_distribution": quality_dist,
            "avg_duration_ms": round(avg_duration, 0),
        }
    
    def _get_detection_rate(self) -> float:
        """Calculate pose detection rate as percentage."""
        if self.frames_processed == 0:
            return 0.0
        return round((self.frames_with_detection / self.frames_processed) * 100, 1)
    
    def reset(self) -> None:
        """Reset logger for a new session."""
        self.reps = []
        self.start_time = datetime.now()
        self.frames_processed = 0
        self.frames_with_detection = 0


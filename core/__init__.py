"""
Core modules for squat analysis.
Platform-agnostic - no UI dependencies.
"""

from .pose_pipeline import PosePipeline
from .rep_counter import RepCounter, SquatPhase
from .form_feedback import FormFeedback, FormAnalysis
from .smoothing import LandmarkSmoother

__all__ = [
    "PosePipeline",
    "RepCounter",
    "SquatPhase",
    "FormFeedback",
    "FormAnalysis",
    "LandmarkSmoother",
]


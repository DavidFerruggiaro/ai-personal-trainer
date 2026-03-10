"""
Math utilities for pose analysis.
Platform-agnostic geometry functions.
"""

import numpy as np
from typing import Tuple, Union

# Type alias for points
Point = Union[Tuple[float, float], Tuple[float, float, float]]


def calculate_angle(p1: Point, p2: Point, p3: Point) -> float:
    """
    Calculate the angle at p2 formed by the line segments p1-p2 and p2-p3.
    
    Args:
        p1: First point (x, y) or (x, y, z)
        p2: Vertex point where angle is measured (x, y) or (x, y, z)
        p3: Third point (x, y) or (x, y, z)
        
    Returns:
        Angle in degrees (0-180)
    """
    # Extract x, y coordinates
    a = np.array([p1[0], p1[1]])
    b = np.array([p2[0], p2[1]])
    c = np.array([p3[0], p3[1]])
    
    # Calculate vectors
    ba = a - b
    bc = c - b
    
    # Calculate angle using dot product
    cosine_angle = np.dot(ba, bc) / (np.linalg.norm(ba) * np.linalg.norm(bc) + 1e-8)
    cosine_angle = np.clip(cosine_angle, -1.0, 1.0)
    angle = np.degrees(np.arccos(cosine_angle))
    
    return float(angle)


def calculate_vertical_angle(p1: Point, p2: Point) -> float:
    """
    Calculate the angle of the line p1-p2 from vertical (0 = straight up).
    
    Args:
        p1: Upper point (x, y)
        p2: Lower point (x, y)
        
    Returns:
        Angle in degrees from vertical (0-180)
    """
    dx = p2[0] - p1[0]
    dy = p2[1] - p1[1]
    
    # Angle from vertical (y-axis points down in image coordinates)
    # Vertical is when dx = 0
    angle = np.degrees(np.arctan2(abs(dx), abs(dy)))
    
    return float(angle)


def distance_2d(p1: Point, p2: Point) -> float:
    """
    Calculate Euclidean distance between two points.
    
    Args:
        p1: First point (x, y)
        p2: Second point (x, y)
        
    Returns:
        Distance as float
    """
    dx = p2[0] - p1[0]
    dy = p2[1] - p1[1]
    return float(np.sqrt(dx * dx + dy * dy))


def midpoint(p1: Point, p2: Point) -> Tuple[float, float]:
    """
    Calculate midpoint between two points.
    
    Args:
        p1: First point (x, y)
        p2: Second point (x, y)
        
    Returns:
        Midpoint as (x, y) tuple
    """
    return ((p1[0] + p2[0]) / 2.0, (p1[1] + p2[1]) / 2.0)


def normalize_to_frame(x: float, y: float, width: int, height: int) -> Tuple[int, int]:
    """
    Convert normalized coordinates (0-1) to pixel coordinates.
    
    Args:
        x: Normalized x coordinate (0-1)
        y: Normalized y coordinate (0-1)
        width: Frame width in pixels
        height: Frame height in pixels
        
    Returns:
        Pixel coordinates as (x, y) tuple
    """
    return (int(x * width), int(y * height))


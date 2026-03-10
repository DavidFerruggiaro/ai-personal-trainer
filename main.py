#!/usr/bin/env python3
"""
AI Personal Trainer - Squat MVP
Entry point for the application.

Usage:
    python main.py
    
This will launch the Streamlit application.
"""

import subprocess
import sys
import os


def main():
    """Launch the Streamlit application."""
    # Get the directory where this script is located
    script_dir = os.path.dirname(os.path.abspath(__file__))
    app_path = os.path.join(script_dir, "ui", "streamlit_app.py")
    
    # Run streamlit
    subprocess.run([sys.executable, "-m", "streamlit", "run", app_path])


if __name__ == "__main__":
    main()


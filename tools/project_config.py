"""Local tool paths shared by project tasks and offline research commands."""
from pathlib import Path
import os

ROOT = Path(__file__).resolve().parents[1]
DEST = Path(r'E:\Godot Games\grip_up')
ENGINE = Path(os.environ.get('GRIP_UP_GODOT', str(Path.home() / 'WrapRush/tools/godot.exe')))

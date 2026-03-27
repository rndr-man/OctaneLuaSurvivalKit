# Animate Float Nodes v7.12

A powerful Lua script for OctaneRender that applies keyframe animation to Float Value nodes with support for segment-based animation, custom value sequences, and full 4-channel animation data.

## Features

- **Segment Animation**: Define up to 10 animation segments with individual frame ranges, value ranges, and easing curves
- **Custom Values**: Paste value sequences or load from JSON files
- **6 Easing Curves**: Linear, Ease In, Ease Out, Ease In-Out, Bounce, Elastic
- **4-Channel Support**: Full support for Octane's 4-component float animations
- **JSON Export/Import**: Save and load animation data for external manipulation
- **Session Persistence**: Values persist between dialog opens via temp file
- **Multi-Node Support**: Apply the same animation to multiple Float nodes at once
- **Loop Animation**: Optional looping with automatic period calculation
- **Undo Support**: Single-click undo for all animation changes
- **Keyboard Shortcuts**: Enter to apply, Escape to close

## Requirements

- OctaneRender 2026.1 or later
- Octane Lua scripting enabled

## Installation

1. Copy the `AnimateFloatNodes` folder to your Octane Lua scripts directory

2. Restart OctaneRender or reload scripts

3. Access from: `Scripts` menu → `Animate Float Nodes`

## Usage

### Basic Workflow

1. Select one or more **Float Value** nodes in the Node Editor
2. Run the script from the Scripts menu (or press `Ctrl+Alt+A`)
3. Choose animation mode:
   - **Segments**: For simple A→B transitions with easing
   - **Custom Values**: For complex sequences or imported data
4. Configure frame range and values
5. Click **Apply Animation** (or press `Enter`)

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `Ctrl+Alt+A` | Launch script (configurable) |
| `Enter` | Apply animation |
| `Escape` | Close dialog |

### Segments Mode

Perfect for simple animations with easing:

- Add/remove segments with +/- buttons (1-10 segments)
- Each segment has:
  - Frame range (start → end)
  - Value range (start → end)  
  - Easing curve selection
- Segments can have gaps (values hold at last keyframe)
- Overlapping segments show a warning

### Custom Values Mode

For complex or externally-generated animation:

- **Text Editor**: Paste values (space, comma, or newline separated)
- **Copy from Selected Node**: Extract animation from an existing Float node
- **Load from File**: Import JSON animation file
- **Save to File**: Export current animation as JSON
- **Clear Buffer**: Reset values and frame range

### Advanced Options

- **Interpolation**: Linear, Smooth, or Step (affects playback, not keyframes)
- **Loop Animation**: Enables looping with automatic period calculation

## JSON Format

Animation data can be exported/imported as JSON for external manipulation:

```json
{
    "formatVersion": "1.0",
    "metadata": {
        "sourceNode": "Float value",
        "exportDate": "2024-01-15T10:30:00",
        "description": "Camera shake animation"
    },
    "project": {
        "fps": 24
    },
    "animation": {
        "frameRange": {
            "startFrame": 0,
            "endFrame": 100
        },
        "keyframes": {
            "count": 101,
            "times": [0.0, 0.0416, 0.0833, ...],
            "frames": [0, 1, 2, ...],
            "channels": {
                "0": [0.0, 0.1, 0.2, ...],
                "1": [0.0, 0.0, 0.0, ...],
                "2": [0.0, 0.0, 0.0, ...],
                "3": [0.0, 0.0, 0.0, ...]
            }
        },
        "loop": {
            "enabled": false,
            "period": 0
        },
        "interpolation": 1
    }
}
```

### JSON Fields

| Field | Description |
|-------|-------------|
| `formatVersion` | JSON format version for compatibility |
| `metadata.sourceNode` | Original node name |
| `metadata.exportDate` | ISO timestamp |
| `metadata.description` | User-provided description |
| `project.fps` | Frames per second |
| `animation.frameRange` | Start and end frame numbers |
| `animation.keyframes.times` | Time values in seconds |
| `animation.keyframes.frames` | Frame numbers (convenience) |
| `animation.keyframes.channels` | Up to 4 value channels (0-3) |
| `animation.loop.enabled` | Whether loop is enabled |
| `animation.loop.period` | Loop period in seconds |
| `animation.interpolation` | 1=Linear, 2=Smooth, 3=Step |

### External Tool Integration

The JSON format is designed for external manipulation. You can:

- **Apply noise**: Add procedural variation to values
- **Scale/offset**: Multiply or shift all values
- **Blend curves**: Combine multiple animations
- **Procedural generation**: Create animations from code (Python, etc.)
- **Import from DCC**: Convert from Maya, Blender, or Houdini curves
- **Simulation data**: Apply physics sim results to Float nodes

## File Structure

```
AnimateFloatNodes/
├── Animate Float Nodes.lua     # Main entry point
├── README.md                   # This file
└── AnimateFloatNodes_bin/
    ├── config.lua              # Centralized constants
    ├── logger.lua              # Logging with levels
    ├── widget.lua              # GUI component factory
    ├── helpers.lua             # Pure utility functions
    ├── state.lua               # Application state
    ├── gui_actions.lua         # User action handlers
    └── gui.lua                 # User interface
```

## Module Architecture

| Module | Lines | Purpose |
|--------|-------|---------|
| `config.lua` | ~300 | Centralized constants, limits, defaults, strings |
| `logger.lua` | ~170 | Logging system with DEBUG/INFO/WARN/ERROR levels |
| `widget.lua` | ~410 | GUI abstraction layer for Octane UI components |
| `helpers.lua` | ~800 | Pure functions for calculations, parsing, file I/O |
| `state.lua` | ~450 | Application state management and persistence |
| `gui_actions.lua` | ~480 | User action handlers (copy, save, load, apply) |
| `gui.lua` | ~750 | UI construction, callbacks, visibility management |

## Logging

The script includes a comprehensive logging system. To enable debug output:

1. Open `Animate Float Nodes.lua`
2. Find the line: `Logger.setLevel(Logger.LEVEL.INFO)`
3. Change to: `Logger.setLevel(Logger.LEVEL.DEBUG)`

Log levels:
- **DEBUG**: Detailed diagnostic information
- **INFO**: General operational messages (default)
- **WARN**: Warning conditions
- **ERROR**: Error conditions

All logs appear in the Octane console with `[AnimateFloat]` prefix.

## Troubleshooting

### "No Nodes Selected"
Select at least one Float Value node before running the script. Float nodes are found under `Basic → Float Value` in the Node Editor.

### "Time difference exceeding the period"
This error occurs with looping animations. The script automatically adjusts the period to avoid this.

### Values not persisting
The script saves a temp buffer file. If values aren't persisting, check write permissions to the system temp directory.

### Undo not working
Animation changes are wrapped in an undo block. Use `Ctrl+Z` or `Edit → Undo` to revert changes.

## Changelog

### v7.12
- Refactored architecture for maintainability
- Added centralized Config module for all constants
- Added Logger module with DEBUG/INFO/WARN/ERROR levels
- Split gui.lua into gui.lua + gui_actions.lua
- Added undo support (single-click undo)
- Added keyboard shortcuts (Enter=Apply, Esc=Close)
- Added pcall wrappers on all callbacks for crash prevention
- Standardized nil checks throughout codebase

### v7.11
- Full 4-channel animation support
- JSON export/import with channels structure
- Multi-channel detection for smart apply

### v7.10
- File-based persistence
- Clear/Save/Load buttons
- Buffer info display

### v7.9
- Session persistence between dialog opens

### v7.8
- Fixed copy-apply bug
- Console logging for debugging

### v7.7
- Fixed ghost text bug via window recreation

### v7.6
- Wider layout with larger sliders

### v7.5
- New single-column layout architecture

### v7.4
- Merged Linear/Multi-Segment into dynamic Segments mode

## License

MIT License - Feel free to modify and distribute.

## Credits

- **Author**: Padi Frigg (AI assisted)
- **Widget System**: Based on Ol' Ready Cam widget abstraction
- **Target Platform**: OctaneRender by OTOY

## Support

For issues or feature requests, please contact the author or submit via your preferred channel.

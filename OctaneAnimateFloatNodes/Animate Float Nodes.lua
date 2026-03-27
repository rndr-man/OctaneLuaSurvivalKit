-- @shortcut       ctrl+alt+a
--[[
================================================================================
Animate Float Nodes - Main Entry Point
================================================================================

@description    Applies keyframe animation to Octane Float Value nodes.
                Supports segment-based animation with easing curves and
                custom value sequences from text input or JSON files.
                Full 4-channel animation data support for advanced workflows.

@author         Padi Frigg (AI assisted)
@version        7.12
@date           20251213

@requires       OctaneRender 2026.1+
@requires       All modules in AnimateFloatNodes_bin/

--------------------------------------------------------------------------------
USAGE
--------------------------------------------------------------------------------

1. Select one or more Float Value nodes in the Octane Node Editor
2. Run this script from Scripts menu or assigned shortcut (Ctrl+Alt+A)
3. Choose animation mode:
   - Segments: Define start/end frames and values with easing curves
   - Custom Values: Paste values or load from JSON file
4. Click "Apply Animation" to set keyframes on selected nodes

--------------------------------------------------------------------------------
FILE STRUCTURE
--------------------------------------------------------------------------------

AnimateFloatNodes/
├── Animate Float Nodes.lua     -- This file (entry point)
├── README.md                   -- Documentation
└── AnimateFloatNodes_bin/
    ├── config.lua              -- Centralized constants and configuration
    ├── logger.lua              -- Logging system with log levels
    ├── widget.lua              -- GUI component factory (third-party)
    ├── helpers.lua             -- Pure functions for calculations and I/O
    ├── state.lua               -- Application state management
    ├── gui_actions.lua         -- User action handlers
    └── gui.lua                 -- User interface construction

--------------------------------------------------------------------------------
KEYBOARD SHORTCUTS
--------------------------------------------------------------------------------

In the dialog:
- Enter/Return: Apply Animation
- Escape: Close Window

--------------------------------------------------------------------------------
JSON FORMAT
--------------------------------------------------------------------------------

Animation data can be exported/imported as JSON for external manipulation:

{
    "formatVersion": "1.0",
    "metadata": {
        "sourceNode": "Float value",
        "exportDate": "2024-01-15T10:30:00",
        "description": "Camera shake animation"
    },
    "project": { "fps": 24 },
    "animation": {
        "frameRange": { "startFrame": 0, "endFrame": 100 },
        "keyframes": {
            "count": 101,
            "times": [0.0, 0.0416, ...],
            "frames": [0, 1, 2, ...],
            "channels": {
                "0": [0.0, 0.1, ...],
                "1": [0.0, 0.0, ...],
                "2": [0.0, 0.0, ...],
                "3": [0.0, 0.0, ...]
            }
        },
        "loop": { "enabled": false, "period": 0 },
        "interpolation": 1
    }
}

--------------------------------------------------------------------------------
CHANGELOG
--------------------------------------------------------------------------------

v7.12 - Refactored architecture:
        - Centralized Config module for constants
        - Logger module with DEBUG/INFO/WARN/ERROR levels
        - Split gui.lua into gui.lua + gui_actions.lua
        - Added undo support (single-click undo)
        - Added keyboard shortcuts (Enter=Apply, Esc=Close)
        - pcall wrappers on all callbacks for crash prevention
        - Standardized nil checks throughout

v7.11 - 4-channel animation support, JSON export/import
v7.10 - File-based persistence, Clear/Save/Load buttons
v7.9  - Persistent custom values between sessions
v7.8  - Fixed copy-apply bug, console logging
v7.7  - Ghost text bug fix via window recreation
v7.6  - Wider layout, larger sliders
v7.5  - Single-column layout with nested horizontal groups
v7.4  - Merged Linear/Multi-Segment into dynamic Segments mode

================================================================================
--]]

--------------------------------------------------------------------------------
-- Module Dependencies
--------------------------------------------------------------------------------

-- Get the directory containing this script
local scriptPath = debug.getinfo(1, "S").source:match("@(.*/)")
    or debug.getinfo(1, "S").source:match("@(.*\\)")
    or "./"

-- Construct path to bin directory
local binPath = scriptPath .. "AnimateFloatNodes_bin/"

-- Make module loading independent of Octane's `require` search path.
-- This allows developers to copy the entire `OctaneAnimateFloatNodes` folder
-- into their Octane Lua scripts directory without worrying about `LUA_PATH`.
package.path = scriptPath .. "?.lua;" .. scriptPath .. "?/?.lua;" .. package.path

-- Load required modules in dependency order
-- 1. Config must load first (no dependencies, provides constants)
require "AnimateFloatNodes_bin/config"

-- 2. Logger loads second (depends on nothing, used by all others)
require "AnimateFloatNodes_bin/logger"

-- 3. Dialog utilities (depends on config, logger)
require "AnimateFloatNodes_bin/dialog"

-- 4. Widget is standalone GUI factory
require "AnimateFloatNodes_bin/widget"

-- 5. Helpers are pure functions (depends on Config, Logger)
require "AnimateFloatNodes_bin/helpers"

-- 6. Validation functions (depends on Config, Logger, Helpers)
require "AnimateFloatNodes_bin/validation"

-- 7. State depends on Config, Logger, Helpers
require "AnimateFloatNodes_bin/state"

-- 8. GUI Actions depends on Config, Logger, Dialog, Helpers, State, Validation
require "AnimateFloatNodes_bin/gui_actions"

-- 9. GUI depends on everything above
require "AnimateFloatNodes_bin/gui"

--------------------------------------------------------------------------------
-- Main Entry Point
--------------------------------------------------------------------------------

---Main function with error handling
---@return boolean success Whether the script executed successfully
local function main()
    -- Set log level (change to Logger.LEVEL.DEBUG for verbose output)
    Logger.setLevel(Logger.LEVEL.INFO)
    
    Logger.info("Starting %s", Config.APP.WINDOW_TITLE)
    
    -- Initialize application state (validates selection, loads settings)
    if not State:initialize() then
        Logger.warn("Initialization failed - exiting")
        return false
    end
    
    Logger.info("Initialized with %d Float node(s) selected", State.nodeCount)
    
    -- Show the GUI (blocks until window is closed)
    GUI:show()
    
    Logger.info("Session ended")
    return true
end

--------------------------------------------------------------------------------
-- Script Execution
--------------------------------------------------------------------------------

-- Execute with protected call to catch and display errors gracefully
local success, errorMsg = pcall(main)

if not success then
    -- Log error to console
    local errStr = tostring(errorMsg)
    print("[AnimateFloat] FATAL ERROR: " .. errStr)
    
    -- Show error dialog to user
    octane.gui.showDialog{
        type = octane.gui.dialogType.BUTTON_DIALOG,
        title = "Script Error",
        text = "An error occurred:\n\n" .. errStr ..
               "\n\nPlease check the console for details."
    }
end

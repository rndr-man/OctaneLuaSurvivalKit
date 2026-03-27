--[[
================================================================================
Config Module - Centralized Constants and Configuration
================================================================================

@description    Contains all configuration constants, magic numbers, and default
                values used throughout the Animate Float Nodes tool. Centralizing
                these values makes the codebase easier to maintain and customize.

@author         Padi Frigg (AI assisted)
@version        7.12

--------------------------------------------------------------------------------
USAGE
--------------------------------------------------------------------------------

    local Config = require("AnimateFloatNodes_bin/config")
    
    -- Access layout constants
    local width = Config.LAYOUT.LABEL_WIDTH
    
    -- Access limits
    if frameCount > Config.LIMITS.MAX_FRAMES then
        -- warn user
    end

================================================================================
--]]

--------------------------------------------------------------------------------
-- Module Declaration
--------------------------------------------------------------------------------

---@class Config
---Centralized configuration constants
Config = {}

--------------------------------------------------------------------------------
-- Application Info
--------------------------------------------------------------------------------

---@class AppInfo
Config.APP = {
    NAME = "Animate Float Nodes",
    VERSION = "7.12",
    AUTHOR = "Padi Frigg (AI assisted)",
    
    ---Window title including version
    WINDOW_TITLE = "Animate Float Nodes v7.12"
}

--------------------------------------------------------------------------------
-- Layout Constants
--------------------------------------------------------------------------------

---@class LayoutConfig
---GUI layout dimensions and spacing
Config.LAYOUT = {
    ---Standard label width for form rows
    LABEL_WIDTH = 100,
    
    ---Standard slider width
    SLIDER_WIDTH = 180,
    
    ---Full width for spanning elements
    FULL_WIDTH = 560,
    
    ---Standard row height for form elements
    ROW_HEIGHT = 24,
    
    ---Standard button height
    BUTTON_HEIGHT = 28,
    
    ---Main window width
    WINDOW_WIDTH = 620,
    
    ---Main window height
    WINDOW_HEIGHT = 820,
    
    ---Width for custom section sliders (calculated)
    CUSTOM_SLIDER_WIDTH = 560 - 100 - 40,  -- FULL_WIDTH - LABEL_WIDTH - padding
    
    ---Text editor height for custom values
    EDITOR_HEIGHT = 80,
    
    ---"to" label width between sliders
    TO_LABEL_WIDTH = 25,
    
    ---Small button width (for +/- buttons)
    SMALL_BUTTON_WIDTH = 36,
    
    ---Standard group padding
    GROUP_PADDING = {6, 6},
    
    ---No padding
    NO_PADDING = {0, 0}
}

--------------------------------------------------------------------------------
-- Animation Limits
--------------------------------------------------------------------------------

---@class LimitsConfig
---Validation limits and boundaries
Config.LIMITS = {
    ---Maximum number of animation segments
    MAX_SEGMENTS = 10,
    
    ---Minimum number of segments
    MIN_SEGMENTS = 1,
    
    ---Maximum frame number allowed
    MAX_FRAME = 10000,
    
    ---Minimum frame number allowed
    MIN_FRAME = 0,
    
    ---Maximum value for sliders
    MAX_VALUE = 1000,
    
    ---Minimum value for sliders
    MIN_VALUE = -1000,
    
    ---Value slider step increment
    VALUE_STEP = 0.01,
    
    ---Frame slider step increment
    FRAME_STEP = 1,
    
    ---Minimum values required for custom animation
    MIN_CUSTOM_VALUES = 2,
    
    ---Default FPS if not specified
    DEFAULT_FPS = 24,
    
    ---Minimum FPS allowed
    MIN_FPS = 1,
    
    ---Maximum FPS allowed
    MAX_FPS = 120
}

--------------------------------------------------------------------------------
-- Default Values
--------------------------------------------------------------------------------

---@class DefaultsConfig
---Default values for new segments and state
Config.DEFAULTS = {
    ---Default segment configuration
    SEGMENT = {
        START_FRAME = 0,
        END_FRAME = 100,
        START_VALUE = 0,
        END_VALUE = 1,
        EASING_CURVE = 1  -- Linear
    },
    
    ---Default custom mode configuration
    CUSTOM = {
        START_FRAME = 0,
        END_FRAME = 100
    },
    
    ---Default animation mode (1 = Segments, 2 = Custom)
    ANIMATION_MODE = 1,
    
    ---Default interpolation type (1 = Linear, 2 = Smooth, 3 = Step)
    INTERPOLATION_TYPE = 1,
    
    ---Default loop setting
    LOOP_ANIMATION = false
}

--------------------------------------------------------------------------------
-- Animation Mode Constants
--------------------------------------------------------------------------------

---@enum AnimationMode
Config.MODE = {
    SEGMENTS = 1,
    CUSTOM = 2
}

---Display names for animation modes
Config.MODE_NAMES = {"Segments", "Custom Values"}

--------------------------------------------------------------------------------
-- Interpolation Type Constants
--------------------------------------------------------------------------------

---@enum InterpolationType
Config.INTERPOLATION = {
    LINEAR = 1,
    SMOOTH = 2,
    STEP = 3
}

---Display names for interpolation types
Config.INTERPOLATION_NAMES = {"Linear", "Smooth", "Step"}

--------------------------------------------------------------------------------
-- Easing Curve Constants
--------------------------------------------------------------------------------

---@enum EasingCurve
Config.EASING = {
    LINEAR = 1,
    EASE_IN = 2,
    EASE_OUT = 3,
    EASE_IN_OUT = 4,
    BOUNCE = 5,
    ELASTIC = 6
}

---Display names for easing curves
Config.EASING_NAMES = {"Linear", "Ease In", "Ease Out", "Ease In-Out", "Bounce", "Elastic"}

--------------------------------------------------------------------------------
-- File I/O Constants
--------------------------------------------------------------------------------

---@class FileConfig
Config.FILE = {
    ---Temp buffer filename for session persistence
    TEMP_FILENAME = "AnimateFloat_buffer.json",
    
    ---JSON format version for compatibility checking
    JSON_FORMAT_VERSION = "1.0",
    
    ---Default JSON file extension
    JSON_EXTENSION = ".json",
    
    ---File dialog wildcard for JSON files
    JSON_WILDCARD = "*.json"
}

--------------------------------------------------------------------------------
-- Keyboard Shortcuts
--------------------------------------------------------------------------------

---@class KeyboardConfig
---Key codes for keyboard shortcuts
Config.KEYS = {
    ---Enter key code
    ENTER = 13,
    
    ---Escape key code
    ESCAPE = 27,
    
    ---Return key code (alternative enter)
    RETURN = 10
}

--------------------------------------------------------------------------------
-- UI Strings
--------------------------------------------------------------------------------

---@class UIStrings
---Commonly used UI text strings
Config.STRINGS = {
    ---Button labels
    BUTTONS = {
        APPLY = "APPLY ANIMATION",
        CLOSE = "Close",
        ADD_SEGMENT = "+",
        REMOVE_SEGMENT = "-",
        PREVIEW = "Preview Values",
        COPY = "Copy from Selected Node",
        CLEAR = "Clear Buffer",
        SAVE = "Save to File...",
        LOAD = "Load from File..."
    },
    
    ---Dialog titles
    DIALOGS = {
        SUCCESS = "Success",
        ERROR = "Error",
        WARNING = "Warning",
        VALIDATION_ERROR = "Validation Error",
        NO_SELECTION = "No Selection",
        NO_NODES = "No Nodes Selected",
        NO_VALUES = "No Values",
        SAVE_ANIMATION = "Save Animation JSON",
        LOAD_ANIMATION = "Load Animation JSON",
        CLEAR_CONFIRM = "Clear Buffer?",
        ANIMATION_COPIED = "Animation Copied",
        VALUE_PREVIEW = "Value Preview",
        LOADED = "Loaded",
        SAVED = "Saved",
        SAVE_FAILED = "Save Failed",
        LOAD_FAILED = "Load Failed"
    },
    
    ---Section labels
    SECTIONS = {
        SEGMENT_ANIMATION = "Segment Animation",
        CUSTOM_VALUES = "Custom Values",
        ADVANCED_OPTIONS = "Advanced Options"
    },
    
    ---Field labels
    LABELS = {
        MODE = "Mode",
        FRAMES = "Frames",
        VALUES = "Values",
        EASING = "Easing",
        START_FRAME = "Start Frame",
        END_FRAME = "End Frame",
        INTERPOLATION = "Interpolation",
        LOOP = "Loop Animation",
        TO = "to"
    }
}

--------------------------------------------------------------------------------
-- Undo System
--------------------------------------------------------------------------------

---@class UndoConfig
---Note: octane.undo API may not be available in all Octane versions
Config.UNDO = {
    ---Undo action name for applying animation
    APPLY_ANIMATION = "Apply Float Animation"
}

return Config

# AnimateFloatNodes Architecture

> **Purpose**: Technical reference for contributors and maintainers.

## Overview

**AnimateFloatNodes** is an OctaneRender Lua script that applies keyframe animation to Float Value nodes. It supports segment-based animation with easing curves and custom value sequences from text/JSON.

**Version**: 7.12  
**Target**: OctaneRender 2026.1+  
**Lines of Code**: ~4,200 across 9 modules

---

## Module Dependency Graph

```
                    ┌─────────┐
                    │ config  │  (constants only, no dependencies)
                    └────┬────┘
                         │
                    ┌────▼────┐
                    │ logger  │  (depends on: config)
                    └────┬────┘
                         │
                    ┌────▼────┐
                    │ dialog  │  (depends on: config, logger)
                    └────┬────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
    ┌────▼────┐    ┌─────▼─────┐   ┌─────▼─────┐
    │ widget  │    │ helpers   │   │validation │
    └────┬────┘    └─────┬─────┘   └─────┬─────┘
         │               │               │
         └───────────────┼───────────────┘
                         │
                    ┌────▼────┐
                    │  state  │  (depends on: config, logger, helpers)
                    └────┬────┘
                         │
                  ┌──────▼──────┐
                  │ gui_actions │  (depends on: all above)
                  └──────┬──────┘
                         │
                    ┌────▼────┐
                    │   gui   │  (depends on: all above)
                    └─────────┘
```

---

## Module Responsibilities

| Module | Lines | Purpose | Key Exports |
|--------|-------|---------|-------------|
| `config.lua` | ~330 | All constants, limits, defaults, UI strings | `Config` table |
| `logger.lua` | ~210 | Logging with levels (DEBUG/INFO/WARN/ERROR) | `Logger` table |
| `dialog.lua` | ~120 | Standardized dialog functions | `Dialog` table |
| `validation.lua` | ~150 | Input validation functions | `Validation` table |
| `widget.lua` | ~410 | GUI component factory (third-party) | `widget` table |
| `helpers.lua` | ~940 | Pure utility functions (math, file I/O, parsing) | `Helpers` table |
| `state.lua` | ~570 | Application state management | `State` table |
| `gui_actions.lua` | ~560 | User action handlers (copy, save, load, apply) | `GUIActions` table |
| `gui.lua` | ~970 | UI construction and callbacks | `GUI` table |

---

## File Structure

```
AnimateFloatNodes/
├── Animate Float Nodes.lua      # Entry point (loads modules, calls main)
├── README.md                    # User documentation
├── ARCHITECTURE.md              # This file (LLM reference)
├── CHANGELOG.md                 # Version history (optional)
└── AnimateFloatNodes_bin/
    ├── config.lua               # Constants, limits, defaults
    ├── logger.lua               # Logging system
    ├── dialog.lua               # Dialog utilities
    ├── validation.lua           # Validation functions
    ├── widget.lua               # GUI abstraction layer
    ├── helpers.lua              # Pure utility functions
    ├── state.lua                # Application state
    ├── gui_actions.lua          # Action handlers
    └── gui.lua                  # UI construction
```

---

## Key Data Structures

### State Object (state.lua)

```lua
State = {
    -- Selection
    targetNodes = {},           -- Array of NT_FLOAT nodes
    nodeCount = 0,              -- Count of selected nodes
    
    -- Project
    fps = 24,                   -- From project settings
    
    -- Mode: 1 = Segments, 2 = Custom
    animationMode = 1,
    
    -- Segments mode
    segments = {                -- Array of segment definitions
        {startFrame=0, endFrame=100, startValue=0, endValue=1, easingCurve=1},
        -- ...
    },
    
    -- Custom mode
    customStartFrame = 0,
    customEndFrame = 100,
    valuesText = "",            -- Text editor content (channel 0)
    rawValues = {},             -- Full 4-channel: {{v1,v2,v3,v4}, ...}
    sourceNodeName = "",        -- Where values came from
    
    -- Advanced
    interpolationType = 1,      -- 1=Linear, 2=Smooth, 3=Step
    loopAnimation = false,
    
    -- Runtime
    isProcessing = false,
}
```

### Config Constants (config.lua)

```lua
Config.LAYOUT.LABEL_WIDTH = 100
Config.LAYOUT.SLIDER_WIDTH = 180
Config.LIMITS.MAX_SEGMENTS = 10
Config.LIMITS.MAX_FRAME = 10000
Config.DEFAULTS.SEGMENT = {startFrame=0, endFrame=100, ...}
Config.MODE.SEGMENTS = 1
Config.MODE.CUSTOM = 2
Config.EASING.LINEAR = 1  -- through ELASTIC = 6
Config.STRINGS.BUTTONS.APPLY = "APPLY ANIMATION"
Config.STRINGS.DIALOGS.SUCCESS = "Success"
```

---

## Common Patterns

### Adding a New Button

1. **Add string constant** in `config.lua`:
   ```lua
   Config.STRINGS.BUTTONS.MY_BUTTON = "My Button"
   ```

2. **Create button** in `gui.lua` (in appropriate build method):
   ```lua
   self.myBtn = octane.gui.create{
       type = octane.gui.componentType.BUTTON,
       text = Config.STRINGS.BUTTONS.MY_BUTTON,
       width = 120,
       height = Config.LAYOUT.BUTTON_HEIGHT
   }
   ```

3. **Add callback** in `gui.lua:setupAllCallbacks()`:
   ```lua
   self.myBtn.callback = function()
       GUIActions.myAction(self)
   end
   ```

4. **Implement action** in `gui_actions.lua`:
   ```lua
   function GUIActions.myAction(gui)
       local ok, err = pcall(function()
           -- Action logic here
       end)
       if not ok then
           Logger.error("myAction failed: %s", tostring(err))
       end
   end
   ```

### Adding a New Setting

1. **Add to State** in `state.lua`:
   ```lua
   State = {
       -- ...
       mySetting = false,
   }
   ```

2. **Add default** in `config.lua`:
   ```lua
   Config.DEFAULTS.MY_SETTING = false
   ```

3. **Add UI widget** in `gui.lua`

4. **Add persistence** in `state.lua:saveToTempBuffer()` and `loadFromTempBuffer()`

### Adding Validation

1. **Add function** in `validation.lua`:
   ```lua
   function Validation.checkMySetting()
       if not State.mySetting then
           return false, "My setting is required"
       end
       return true, nil
   end
   ```

2. **Call from** `State:validate()` or `GUIActions.applyAnimation()`

---

## API Constraints & Gotchas

### What Doesn't Exist
- ❌ `octane.undo` API - No undo/redo support in Lua
- ❌ `octane.clipboard` - No clipboard access
- ❌ Direct keyboard shortcuts in dialogs (except via window callback)

### Required Patterns
- ✅ Call `octane.changemanager.update()` after modifying nodes
- ✅ Use `node:setAttribute(attr, value, true)` - third param forces evaluation
- ✅ Wrap all callbacks in `pcall()` to prevent UI crashes
- ✅ Use `octane.gui.dispatchGuiEvents(ms)` in long loops to keep UI responsive

### Octane GUI Quirks
- ComboBox: `selectedIx` is 1-based
- Slider: `value` can be float even with integer `step`
- TextEditor: `callback` fires on every keystroke
- Window recreation needed after adding/removing children

---

## Coding Standards

### Nil Checks
```lua
-- Preferred (consistent throughout codebase)
if not x then

-- Avoid mixing styles
if x == nil then  -- Don't use
if x ~= nil then  -- Don't use
```

### Error Handling
```lua
-- All callbacks must be wrapped
self.myBtn.callback = function()
    local ok, err = pcall(function()
        -- Actual logic
    end)
    if not ok then
        Logger.error("myBtn callback failed: %s", tostring(err))
    end
end
```

### Logging
```lua
Logger.debug("Detailed info: %s", value)   -- Only shown if level=DEBUG
Logger.info("Operation completed")          -- Default level
Logger.warn("Potential issue: %s", msg)     -- Warnings
Logger.error("Failed: %s", tostring(err))   -- Errors
```

### String Formatting
```lua
-- Use Config.STRINGS for all user-facing text
title = Config.STRINGS.DIALOGS.SUCCESS

-- Use string.format for dynamic content
text = string.format("Applied to %d nodes", count)
```

---

## Testing Checklist

Before releasing changes:

- [ ] Script loads without errors
- [ ] Segments mode: Add/remove segments works
- [ ] Segments mode: Apply animation to single node
- [ ] Segments mode: Apply animation to multiple nodes
- [ ] Custom mode: Paste values and apply
- [ ] Custom mode: Copy from existing node
- [ ] Custom mode: Save to JSON file
- [ ] Custom mode: Load from JSON file
- [ ] Loop animation toggle works
- [ ] Keyboard shortcuts (Enter/Escape) work
- [ ] Error dialogs appear for invalid input
- [ ] No console errors during normal operation

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 7.12 | 2024-12 | Refactored: config, logger, split gui/gui_actions, pcall wrappers |
| 7.11 | 2024-12 | 4-channel animation, JSON export/import |
| 7.10 | 2024-11 | File persistence, Clear/Save/Load |
| 7.9 | 2024-11 | Session persistence |

---

## Development Notes

When extending behavior:

- keep pure logic in `helpers.lua`
- keep UI construction in `gui.lua`
- put user-triggered actions in `gui_actions.lua`

---

## Quick Reference

### Module Load Order (main.lua)
```lua
require "AnimateFloatNodes_bin/config"
require "AnimateFloatNodes_bin/logger"
require "AnimateFloatNodes_bin/dialog"
require "AnimateFloatNodes_bin/validation"
require "AnimateFloatNodes_bin/widget"
require "AnimateFloatNodes_bin/helpers"
require "AnimateFloatNodes_bin/state"
require "AnimateFloatNodes_bin/gui_actions"
require "AnimateFloatNodes_bin/gui"
```

### Key Functions
```lua
State:initialize()           -- Setup state, validate selection
State:validate()             -- Check state before apply
GUI:show()                   -- Build and show window
GUI:recreateWindow()         -- Rebuild after structure change
GUIActions.applyAnimation()  -- Main action
Helpers.parseValues(text)    -- Parse text to numbers
Helpers.buildAnimationData() -- Create time/value arrays
```

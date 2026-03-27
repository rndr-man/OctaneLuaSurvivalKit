--[[
================================================================================
GUI Module - User Interface Construction and Event Handling
================================================================================

@description    Builds and manages the user interface for Animate Float Nodes.
                Handles all GUI components, callbacks, and user interactions.
                Uses the widget abstraction layer for component creation.
                
                Action handlers (copy, save, load, apply) are delegated to
                the gui_actions.lua module for cleaner separation of concerns.

@author         Padi Frigg (AI assisted)
@version        7.12

@dependencies   config.lua, logger.lua, widget.lua, helpers.lua, state.lua,
                gui_actions.lua must be loaded first

--------------------------------------------------------------------------------
UI STRUCTURE
--------------------------------------------------------------------------------

Window (620x820, vertical scroll)
├── Header Section
│   ├── Title label ("Animate N Float Node(s)")
│   └── Mode combo box (Segments | Custom Values)
├── Segments Section (bordered group)
│   ├── Control row (Segments: N, +, - buttons)
│   └── Per-segment rows (dynamic 1-10 segments)
├── Custom Values Section (bordered group)
│   ├── Buffer info, frame range sliders
│   ├── Text editor for values
│   └── Buttons (Preview, Copy, Clear, Save, Load)
├── Advanced Options Section
│   ├── Interpolation combo
│   └── Loop checkbox
└── Action Section
    ├── Info label, Apply button, Close button

--------------------------------------------------------------------------------
CALLBACKS
--------------------------------------------------------------------------------

All UI callbacks are set up in setupAllCallbacks() and delegate to:
- State module for data changes
- GUIActions module for user actions (copy, save, load, apply)

--------------------------------------------------------------------------------
KEYBOARD SHORTCUTS
--------------------------------------------------------------------------------

- Enter/Return: Apply Animation
- Escape: Close Window

================================================================================
--]]

--------------------------------------------------------------------------------
-- Module Declaration
--------------------------------------------------------------------------------

GUI = widget:create()

---Reference to the main window (set during show())
local AnimateWindow = nil

---Flag to prevent callback execution during initialization
GUI._initializing = true

---Array of segment widget containers
GUI.segmentWidgets = {}

--------------------------------------------------------------------------------
-- GUI Construction
--------------------------------------------------------------------------------

---Builds all GUI components
function GUI:build()
    self:buildHeader()
    self:buildSegmentsSection()
    self:buildCustomSection()
    self:buildAdvancedSection()
    self:buildActionSection()
end

--------------------------------------------------------------------------------
-- Header Section
--------------------------------------------------------------------------------

---Builds the header section with title and mode selector
function GUI:buildHeader()
    self.title = octane.gui.create{
        type = octane.gui.componentType.LABEL,
        text = "Animate " .. State.nodeCount .. " Float Node(s)",
        width = Config.LAYOUT.FULL_WIDTH,
        height = 28
    }
    
    self.modeLabel = octane.gui.create{
        type = octane.gui.componentType.LABEL,
        text = Config.STRINGS.LABELS.MODE,
        width = Config.LAYOUT.LABEL_WIDTH,
        height = Config.LAYOUT.ROW_HEIGHT
    }
    
    self.modeCombo = octane.gui.create{
        type = octane.gui.componentType.COMBO_BOX,
        items = Config.MODE_NAMES,
        width = 200,
        height = Config.LAYOUT.ROW_HEIGHT,
        selectedIx = State.animationMode
    }
    
    self.modeRow = octane.gui.create{
        type = octane.gui.componentType.GROUP,
        children = {self.modeLabel, self.modeCombo},
        rows = 1,
        cols = 2,
        text = "",
        border = false,
        padding = Config.LAYOUT.NO_PADDING,
        inset = Config.LAYOUT.NO_PADDING
    }
    
    self.headerGroup = octane.gui.create{
        type = octane.gui.componentType.GROUP,
        children = {self.title, self.modeRow},
        rows = 2,
        cols = 1,
        text = "",
        border = false,
        padding = {4, 4},
        inset = Config.LAYOUT.NO_PADDING
    }
end

--------------------------------------------------------------------------------
-- Segments Section
--------------------------------------------------------------------------------

---Builds the segments section with add/remove controls and segment widgets
function GUI:buildSegmentsSection()
    self.segCountLabel = octane.gui.create{
        type = octane.gui.componentType.LABEL,
        text = string.format("Segments: %d", #State.segments),
        width = Config.LAYOUT.LABEL_WIDTH,
        height = Config.LAYOUT.ROW_HEIGHT
    }
    
    self.addBtn = octane.gui.create{
        type = octane.gui.componentType.BUTTON,
        text = Config.STRINGS.BUTTONS.ADD_SEGMENT,
        width = Config.LAYOUT.SMALL_BUTTON_WIDTH,
        height = Config.LAYOUT.ROW_HEIGHT
    }
    
    self.removeBtn = octane.gui.create{
        type = octane.gui.componentType.BUTTON,
        text = Config.STRINGS.BUTTONS.REMOVE_SEGMENT,
        width = Config.LAYOUT.SMALL_BUTTON_WIDTH,
        height = Config.LAYOUT.ROW_HEIGHT
    }
    
    self.controlRow = octane.gui.create{
        type = octane.gui.componentType.GROUP,
        children = {self.segCountLabel, self.addBtn, self.removeBtn},
        rows = 1,
        cols = 3,
        text = "",
        border = false,
        padding = Config.LAYOUT.NO_PADDING,
        inset = Config.LAYOUT.NO_PADDING
    }
    
    self:buildSegmentWidgets()
    self:assembleSegmentsGroup()
end

---Builds widget containers for each segment
function GUI:buildSegmentWidgets()
    self.segmentWidgets = {}
    
    for i = 1, #State.segments do
        local sw = self:createSegmentWidget(i)
        table.insert(self.segmentWidgets, sw)
    end
end

---Creates a complete widget container for a single segment
---@param index number The segment index (1-based)
---@return table sw Segment widget container with all components
function GUI:createSegmentWidget(index)
    local sw = {}
    local seg = State.segments[index]
    
    sw.header = octane.gui.create{
        type = octane.gui.componentType.LABEL,
        text = string.format("--- Segment %d ---", index),
        width = Config.LAYOUT.FULL_WIDTH,
        height = Config.LAYOUT.ROW_HEIGHT
    }
    
    -- Frames row
    sw.framesLabel = octane.gui.create{
        type = octane.gui.componentType.LABEL,
        text = Config.STRINGS.LABELS.FRAMES,
        width = Config.LAYOUT.LABEL_WIDTH,
        height = Config.LAYOUT.ROW_HEIGHT
    }
    sw.startFrameSlider = octane.gui.create{
        type = octane.gui.componentType.SLIDER,
        value = seg.startFrame,
        minValue = Config.LIMITS.MIN_FRAME,
        maxValue = Config.LIMITS.MAX_FRAME,
        step = Config.LIMITS.FRAME_STEP,
        width = Config.LAYOUT.SLIDER_WIDTH,
        height = Config.LAYOUT.ROW_HEIGHT
    }
    sw.toLabel1 = octane.gui.create{
        type = octane.gui.componentType.LABEL,
        text = Config.STRINGS.LABELS.TO,
        width = Config.LAYOUT.TO_LABEL_WIDTH,
        height = Config.LAYOUT.ROW_HEIGHT
    }
    sw.endFrameSlider = octane.gui.create{
        type = octane.gui.componentType.SLIDER,
        value = seg.endFrame,
        minValue = Config.LIMITS.MIN_FRAME,
        maxValue = Config.LIMITS.MAX_FRAME,
        step = Config.LIMITS.FRAME_STEP,
        width = Config.LAYOUT.SLIDER_WIDTH,
        height = Config.LAYOUT.ROW_HEIGHT
    }
    sw.framesRow = octane.gui.create{
        type = octane.gui.componentType.GROUP,
        children = {sw.framesLabel, sw.startFrameSlider, sw.toLabel1, sw.endFrameSlider},
        rows = 1,
        cols = 4,
        text = "",
        border = false,
        padding = Config.LAYOUT.NO_PADDING,
        inset = Config.LAYOUT.NO_PADDING
    }
    
    -- Values row
    sw.valuesLabel = octane.gui.create{
        type = octane.gui.componentType.LABEL,
        text = Config.STRINGS.LABELS.VALUES,
        width = Config.LAYOUT.LABEL_WIDTH,
        height = Config.LAYOUT.ROW_HEIGHT
    }
    sw.startValueSlider = octane.gui.create{
        type = octane.gui.componentType.SLIDER,
        value = seg.startValue,
        minValue = Config.LIMITS.MIN_VALUE,
        maxValue = Config.LIMITS.MAX_VALUE,
        step = Config.LIMITS.VALUE_STEP,
        width = Config.LAYOUT.SLIDER_WIDTH,
        height = Config.LAYOUT.ROW_HEIGHT
    }
    sw.toLabel2 = octane.gui.create{
        type = octane.gui.componentType.LABEL,
        text = Config.STRINGS.LABELS.TO,
        width = Config.LAYOUT.TO_LABEL_WIDTH,
        height = Config.LAYOUT.ROW_HEIGHT
    }
    sw.endValueSlider = octane.gui.create{
        type = octane.gui.componentType.SLIDER,
        value = seg.endValue,
        minValue = Config.LIMITS.MIN_VALUE,
        maxValue = Config.LIMITS.MAX_VALUE,
        step = Config.LIMITS.VALUE_STEP,
        width = Config.LAYOUT.SLIDER_WIDTH,
        height = Config.LAYOUT.ROW_HEIGHT
    }
    sw.valuesRow = octane.gui.create{
        type = octane.gui.componentType.GROUP,
        children = {sw.valuesLabel, sw.startValueSlider, sw.toLabel2, sw.endValueSlider},
        rows = 1,
        cols = 4,
        text = "",
        border = false,
        padding = Config.LAYOUT.NO_PADDING,
        inset = Config.LAYOUT.NO_PADDING
    }
    
    -- Easing row
    sw.easingLabel = octane.gui.create{
        type = octane.gui.componentType.LABEL,
        text = Config.STRINGS.LABELS.EASING,
        width = Config.LAYOUT.LABEL_WIDTH,
        height = Config.LAYOUT.ROW_HEIGHT
    }
    sw.easingCombo = octane.gui.create{
        type = octane.gui.componentType.COMBO_BOX,
        items = Config.EASING_NAMES,
        width = Config.LAYOUT.SLIDER_WIDTH,
        height = Config.LAYOUT.ROW_HEIGHT,
        selectedIx = seg.easingCurve or Config.EASING.LINEAR
    }
    sw.easingRow = octane.gui.create{
        type = octane.gui.componentType.GROUP,
        children = {sw.easingLabel, sw.easingCombo},
        rows = 1,
        cols = 2,
        text = "",
        border = false,
        padding = Config.LAYOUT.NO_PADDING,
        inset = Config.LAYOUT.NO_PADDING
    }
    
    return sw
end

---Assembles the segments group from control row and segment widgets
function GUI:assembleSegmentsGroup()
    local children = {self.controlRow}
    
    for _, sw in ipairs(self.segmentWidgets) do
        table.insert(children, sw.header)
        table.insert(children, sw.framesRow)
        table.insert(children, sw.valuesRow)
        table.insert(children, sw.easingRow)
    end
    
    local numRows = 1 + (#self.segmentWidgets * 4)
    
    self.segmentsGroup = octane.gui.create{
        type = octane.gui.componentType.GROUP,
        children = children,
        rows = numRows,
        cols = 1,
        text = Config.STRINGS.SECTIONS.SEGMENT_ANIMATION,
        border = true,
        padding = Config.LAYOUT.GROUP_PADDING,
        inset = Config.LAYOUT.NO_PADDING
    }
end

--------------------------------------------------------------------------------
-- Custom Section
--------------------------------------------------------------------------------

---Builds the custom values section with text editor and action buttons
function GUI:buildCustomSection()
    -- Buffer info label
    self.bufferInfoLabel = octane.gui.create{
        type = octane.gui.componentType.LABEL,
        text = State:getBufferInfo(),
        width = Config.LAYOUT.FULL_WIDTH,
        height = 20
    }
    
    -- Start frame row
    self.customStartLabel = octane.gui.create{
        type = octane.gui.componentType.LABEL,
        text = Config.STRINGS.LABELS.START_FRAME,
        width = Config.LAYOUT.LABEL_WIDTH,
        height = Config.LAYOUT.ROW_HEIGHT
    }
    self.customStartSlider = octane.gui.create{
        type = octane.gui.componentType.SLIDER,
        value = State.customStartFrame,
        minValue = Config.LIMITS.MIN_FRAME,
        maxValue = Config.LIMITS.MAX_FRAME,
        step = Config.LIMITS.FRAME_STEP,
        width = Config.LAYOUT.CUSTOM_SLIDER_WIDTH,
        height = Config.LAYOUT.ROW_HEIGHT
    }
    self.customStartRow = octane.gui.create{
        type = octane.gui.componentType.GROUP,
        children = {self.customStartLabel, self.customStartSlider},
        rows = 1,
        cols = 2,
        text = "",
        border = false,
        padding = Config.LAYOUT.NO_PADDING,
        inset = Config.LAYOUT.NO_PADDING
    }
    
    -- End frame row
    self.customEndLabel = octane.gui.create{
        type = octane.gui.componentType.LABEL,
        text = Config.STRINGS.LABELS.END_FRAME,
        width = Config.LAYOUT.LABEL_WIDTH,
        height = Config.LAYOUT.ROW_HEIGHT
    }
    self.customEndSlider = octane.gui.create{
        type = octane.gui.componentType.SLIDER,
        value = State.customEndFrame,
        minValue = Config.LIMITS.MIN_FRAME,
        maxValue = Config.LIMITS.MAX_FRAME,
        step = Config.LIMITS.FRAME_STEP,
        width = Config.LAYOUT.CUSTOM_SLIDER_WIDTH,
        height = Config.LAYOUT.ROW_HEIGHT
    }
    self.customEndRow = octane.gui.create{
        type = octane.gui.componentType.GROUP,
        children = {self.customEndLabel, self.customEndSlider},
        rows = 1,
        cols = 2,
        text = "",
        border = false,
        padding = Config.LAYOUT.NO_PADDING,
        inset = Config.LAYOUT.NO_PADDING
    }
    
    -- Values info label
    self.customInfoLabel = octane.gui.create{
        type = octane.gui.componentType.LABEL,
        text = "Values (one per line, comma/space separated):",
        width = Config.LAYOUT.FULL_WIDTH,
        height = 20
    }
    
    -- Text editor
    self.customEditor = octane.gui.create{
        type = octane.gui.componentType.TEXT_EDITOR,
        text = State.valuesText,
        width = Config.LAYOUT.FULL_WIDTH - 30,
        height = Config.LAYOUT.EDITOR_HEIGHT,
        enable = true,
        multiline = true
    }
    
    -- Button row 1: Preview, Copy from Node
    self.previewBtn = octane.gui.create{
        type = octane.gui.componentType.BUTTON,
        text = Config.STRINGS.BUTTONS.PREVIEW,
        width = 140,
        height = Config.LAYOUT.BUTTON_HEIGHT
    }
    
    self.copyBtn = octane.gui.create{
        type = octane.gui.componentType.BUTTON,
        text = Config.STRINGS.BUTTONS.COPY,
        width = 200,
        height = Config.LAYOUT.BUTTON_HEIGHT
    }
    
    self.btnRow1 = octane.gui.create{
        type = octane.gui.componentType.GROUP,
        children = {self.previewBtn, self.copyBtn},
        rows = 1,
        cols = 2,
        text = "",
        border = false,
        padding = Config.LAYOUT.NO_PADDING,
        inset = Config.LAYOUT.NO_PADDING
    }
    
    -- Button row 2: Clear, Save, Load
    self.clearBtn = octane.gui.create{
        type = octane.gui.componentType.BUTTON,
        text = Config.STRINGS.BUTTONS.CLEAR,
        width = 100,
        height = Config.LAYOUT.BUTTON_HEIGHT
    }
    
    self.saveBtn = octane.gui.create{
        type = octane.gui.componentType.BUTTON,
        text = Config.STRINGS.BUTTONS.SAVE,
        width = 120,
        height = Config.LAYOUT.BUTTON_HEIGHT
    }
    
    self.loadBtn = octane.gui.create{
        type = octane.gui.componentType.BUTTON,
        text = Config.STRINGS.BUTTONS.LOAD,
        width = 120,
        height = Config.LAYOUT.BUTTON_HEIGHT
    }
    
    self.btnRow2 = octane.gui.create{
        type = octane.gui.componentType.GROUP,
        children = {self.clearBtn, self.saveBtn, self.loadBtn},
        rows = 1,
        cols = 3,
        text = "",
        border = false,
        padding = Config.LAYOUT.NO_PADDING,
        inset = Config.LAYOUT.NO_PADDING
    }
    
    -- Assemble custom group
    self.customGroup = octane.gui.create{
        type = octane.gui.componentType.GROUP,
        children = {
            self.bufferInfoLabel,
            self.customStartRow,
            self.customEndRow,
            self.customInfoLabel,
            self.customEditor,
            self.btnRow1,
            self.btnRow2
        },
        rows = 7,
        cols = 1,
        text = Config.STRINGS.SECTIONS.CUSTOM_VALUES,
        border = true,
        padding = Config.LAYOUT.GROUP_PADDING,
        inset = Config.LAYOUT.NO_PADDING
    }
end

--------------------------------------------------------------------------------
-- Advanced Section
--------------------------------------------------------------------------------

---Builds the advanced options section with interpolation and loop controls
function GUI:buildAdvancedSection()
    self.interpLabel = octane.gui.create{
        type = octane.gui.componentType.LABEL,
        text = Config.STRINGS.LABELS.INTERPOLATION,
        width = Config.LAYOUT.LABEL_WIDTH,
        height = Config.LAYOUT.ROW_HEIGHT
    }
    self.interpCombo = octane.gui.create{
        type = octane.gui.componentType.COMBO_BOX,
        items = Config.INTERPOLATION_NAMES,
        width = 120,
        height = Config.LAYOUT.ROW_HEIGHT,
        selectedIx = State.interpolationType
    }
    
    self.loopCheck = octane.gui.create{
        type = octane.gui.componentType.CHECK_BOX,
        text = Config.STRINGS.LABELS.LOOP,
        width = 150,
        height = Config.LAYOUT.ROW_HEIGHT,
        checked = State.loopAnimation
    }
    
    self.advancedGroup = octane.gui.create{
        type = octane.gui.componentType.GROUP,
        children = {self.interpLabel, self.interpCombo, self.loopCheck},
        rows = 1,
        cols = 3,
        text = Config.STRINGS.SECTIONS.ADVANCED_OPTIONS,
        border = true,
        padding = {8, 8},
        inset = Config.LAYOUT.NO_PADDING
    }
end

--------------------------------------------------------------------------------
-- Action Section
--------------------------------------------------------------------------------

---Builds the action section with info label and apply/close buttons
function GUI:buildActionSection()
    self.infoLabel = octane.gui.create{
        type = octane.gui.componentType.LABEL,
        text = State:getSummary(),
        width = Config.LAYOUT.FULL_WIDTH,
        height = 40
    }
    
    self.applyBtn = octane.gui.create{
        type = octane.gui.componentType.BUTTON,
        text = Config.STRINGS.BUTTONS.APPLY,
        width = Config.LAYOUT.FULL_WIDTH,
        height = 36
    }
    
    self.closeBtn = octane.gui.create{
        type = octane.gui.componentType.BUTTON,
        text = Config.STRINGS.BUTTONS.CLOSE,
        width = Config.LAYOUT.FULL_WIDTH,
        height = Config.LAYOUT.BUTTON_HEIGHT
    }
    
    self.actionGroup = octane.gui.create{
        type = octane.gui.componentType.GROUP,
        children = {self.infoLabel, self.applyBtn, self.closeBtn},
        rows = 3,
        cols = 1,
        text = "",
        border = false,
        padding = {4, 4},
        inset = Config.LAYOUT.NO_PADDING
    }
end

--------------------------------------------------------------------------------
-- Window Assembly & Show
--------------------------------------------------------------------------------

---Builds and displays the main window
function GUI:show()
    GUI._initializing = true
    
    self:build()
    
    local layout = octane.gridlayout.create()
    layout:startSetup()
    layout:add(self.headerGroup, 1, 1)
    layout:add(self.segmentsGroup, 1, 2)
    layout:add(self.customGroup, 1, 3)
    layout:add(self.advancedGroup, 1, 4)
    layout:add(self.actionGroup, 1, 5)
    layout:endSetup()
    
    AnimateWindow = octane.gui.createWindow{
        text = Config.APP.WINDOW_TITLE,
        width = Config.LAYOUT.WINDOW_WIDTH,
        height = Config.LAYOUT.WINDOW_HEIGHT,
        gridLayout = layout,
        allowScroll = "v"
    }
    
    self:setupAllCallbacks()
    self:setupKeyboardShortcuts()
    self:updateModeVisibility()
    
    GUI._initializing = false
    
    octane.gui.showWindow(AnimateWindow)
end

--------------------------------------------------------------------------------
-- Recreate Window (fixes ghost elements)
--------------------------------------------------------------------------------

---Closes and recreates the window (used after segment add/remove)
function GUI:recreateWindow()
    if AnimateWindow then
        AnimateWindow:closeWindow()
    end
    self:show()
end

--------------------------------------------------------------------------------
-- Mode Visibility
--------------------------------------------------------------------------------

---Updates enabled/disabled state of components based on current mode
function GUI:updateModeVisibility()
    local isSegments = (State.animationMode == Config.MODE.SEGMENTS)
    local isCustom = (State.animationMode == Config.MODE.CUSTOM)
    
    -- Segment controls
    self.segCountLabel.enable = isSegments
    self.addBtn.enable = isSegments and (#State.segments < Config.LIMITS.MAX_SEGMENTS)
    self.removeBtn.enable = isSegments and (#State.segments > Config.LIMITS.MIN_SEGMENTS)
    
    -- Segment widgets
    for _, sw in ipairs(self.segmentWidgets) do
        sw.header.enable = isSegments
        sw.framesLabel.enable = isSegments
        sw.startFrameSlider.enable = isSegments
        sw.toLabel1.enable = isSegments
        sw.endFrameSlider.enable = isSegments
        sw.valuesLabel.enable = isSegments
        sw.startValueSlider.enable = isSegments
        sw.toLabel2.enable = isSegments
        sw.endValueSlider.enable = isSegments
        sw.easingLabel.enable = isSegments
    end
    
    -- Custom controls
    self.bufferInfoLabel.enable = isCustom
    self.customStartLabel.enable = isCustom
    self.customStartSlider.enable = isCustom
    self.customEndLabel.enable = isCustom
    self.customEndSlider.enable = isCustom
    self.customInfoLabel.enable = isCustom
    self.customEditor.enable = isCustom
    self.previewBtn.enable = isCustom
    self.copyBtn.enable = isCustom
    self.clearBtn.enable = isCustom
    self.saveBtn.enable = isCustom
    self.loadBtn.enable = isCustom
end

--------------------------------------------------------------------------------
-- Keyboard Shortcuts
--------------------------------------------------------------------------------

---Sets up keyboard shortcuts for the window
function GUI:setupKeyboardShortcuts()
    AnimateWindow.callback = function(component, event)
        if event == octane.gui.eventType.KEY_PRESSED then
            local keyCode = component.keyCode
            
            -- Enter/Return: Apply Animation
            if keyCode == Config.KEYS.ENTER or keyCode == Config.KEYS.RETURN then
                GUIActions.applyAnimation(self)
                return true
            end
            
            -- Escape: Close Window
            if keyCode == Config.KEYS.ESCAPE then
                AnimateWindow:closeWindow()
                return true
            end
        end
        return false
    end
end

--------------------------------------------------------------------------------
-- All Callbacks Setup
--------------------------------------------------------------------------------

---Sets up all UI callbacks with pcall wrappers for crash prevention
function GUI:setupAllCallbacks()
    -- Mode combo
    self.modeCombo.callback = function(component, event)
        if GUI._initializing then return end
        if event == octane.gui.eventType.VALUE_CHANGE then
            local ok, err = pcall(function()
                State.animationMode = component.selectedIx
                self:updateModeVisibility()
                self:updateInfoLabel()
            end)
            if not ok then
                Logger.error("modeCombo callback failed: %s", tostring(err))
            end
        end
    end
    
    -- Add/Remove buttons
    self.addBtn.callback = function()
        local ok, err = pcall(function()
            if State.animationMode ~= Config.MODE.SEGMENTS then return end
            local success, addErr = State:addSegment()
            if success then
                self:recreateWindow()
            else
                octane.gui.showDialog{
                    type = octane.gui.dialogType.BUTTON_DIALOG,
                    title = "Cannot Add Segment",
                    text = addErr
                }
            end
        end)
        if not ok then
            Logger.error("addBtn callback failed: %s", tostring(err))
        end
    end
    
    self.removeBtn.callback = function()
        local ok, err = pcall(function()
            if State.animationMode ~= Config.MODE.SEGMENTS then return end
            local success, removeErr = State:removeSegment()
            if success then
                self:recreateWindow()
            else
                octane.gui.showDialog{
                    type = octane.gui.dialogType.BUTTON_DIALOG,
                    title = "Cannot Remove Segment",
                    text = removeErr
                }
            end
        end)
        if not ok then
            Logger.error("removeBtn callback failed: %s", tostring(err))
        end
    end
    
    -- Segment callbacks
    for i = 1, #State.segments do
        self:setupSegmentCallbacks(i)
    end
    
    -- Custom callbacks (with persistence)
    self.customStartSlider.callback = function(component, event)
        if GUI._initializing then return end
        if event == octane.gui.eventType.VALUE_CHANGE then
            local ok, err = pcall(function()
                State.customStartFrame = math.floor(component.value)
                State:saveToTempBuffer()
                self:updateInfoLabel()
            end)
            if not ok then
                Logger.error("customStartSlider callback failed: %s", tostring(err))
            end
        end
    end
    
    self.customEndSlider.callback = function(component, event)
        if GUI._initializing then return end
        if event == octane.gui.eventType.VALUE_CHANGE then
            local ok, err = pcall(function()
                State.customEndFrame = math.floor(component.value)
                State:saveToTempBuffer()
                self:updateInfoLabel()
            end)
            if not ok then
                Logger.error("customEndSlider callback failed: %s", tostring(err))
            end
        end
    end
    
    self.customEditor.callback = function(component, event)
        if GUI._initializing then return end
        if event == octane.gui.eventType.VALUE_CHANGE then
            local ok, err = pcall(function()
                State.valuesText = component.text
                State:saveToTempBuffer()
                self:updateInfoLabel()
                self:updateBufferInfo()
            end)
            if not ok then
                Logger.error("customEditor callback failed: %s", tostring(err))
            end
        end
    end
    
    -- Action button callbacks (delegated to GUIActions)
    self.previewBtn.callback = function()
        GUIActions.previewValues(self)
    end
    
    self.copyBtn.callback = function()
        GUIActions.copyAnimation(self)
    end
    
    self.clearBtn.callback = function()
        GUIActions.clearBuffer(self)
    end
    
    self.saveBtn.callback = function()
        GUIActions.saveAnimationToFile(self)
    end
    
    self.loadBtn.callback = function()
        GUIActions.loadAnimationFromFile(self)
    end
    
    -- Advanced callbacks (with persistence)
    self.interpCombo.callback = function(component, event)
        if GUI._initializing then return end
        if event == octane.gui.eventType.VALUE_CHANGE then
            local ok, err = pcall(function()
                State.interpolationType = component.selectedIx
                State:saveToTempBuffer()
            end)
            if not ok then
                Logger.error("interpCombo callback failed: %s", tostring(err))
            end
        end
    end
    
    self.loopCheck.callback = function(component, event)
        if GUI._initializing then return end
        if event == octane.gui.eventType.VALUE_CHANGE then
            local ok, err = pcall(function()
                State.loopAnimation = component.checked
                State:saveToTempBuffer()
            end)
            if not ok then
                Logger.error("loopCheck callback failed: %s", tostring(err))
            end
        end
    end
    
    -- Action callbacks
    self.applyBtn.callback = function()
        GUIActions.applyAnimation(self)
    end
    
    self.closeBtn.callback = function()
        local ok, err = pcall(function()
            AnimateWindow:closeWindow()
        end)
        if not ok then
            Logger.error("closeBtn callback failed: %s", tostring(err))
        end
    end
end

---Sets up callbacks for a specific segment's widgets
---@param index number The segment index (1-based)
function GUI:setupSegmentCallbacks(index)
    local sw = self.segmentWidgets[index]
    if not sw then return end
    
    sw.startFrameSlider.callback = function(component, event)
        if GUI._initializing or index > #State.segments then return end
        if event == octane.gui.eventType.VALUE_CHANGE then
            local ok, err = pcall(function()
                State.segments[index].startFrame = math.floor(component.value)
                self:updateInfoLabel()
            end)
            if not ok then
                Logger.error("segment %d startFrameSlider callback failed: %s", index, tostring(err))
            end
        end
    end
    
    sw.endFrameSlider.callback = function(component, event)
        if GUI._initializing or index > #State.segments then return end
        if event == octane.gui.eventType.VALUE_CHANGE then
            local ok, err = pcall(function()
                State.segments[index].endFrame = math.floor(component.value)
                self:updateInfoLabel()
            end)
            if not ok then
                Logger.error("segment %d endFrameSlider callback failed: %s", index, tostring(err))
            end
        end
    end
    
    sw.startValueSlider.callback = function(component, event)
        if GUI._initializing or index > #State.segments then return end
        if event == octane.gui.eventType.VALUE_CHANGE then
            local ok, err = pcall(function()
                State.segments[index].startValue = component.value
                self:updateInfoLabel()
            end)
            if not ok then
                Logger.error("segment %d startValueSlider callback failed: %s", index, tostring(err))
            end
        end
    end
    
    sw.endValueSlider.callback = function(component, event)
        if GUI._initializing or index > #State.segments then return end
        if event == octane.gui.eventType.VALUE_CHANGE then
            local ok, err = pcall(function()
                State.segments[index].endValue = component.value
                self:updateInfoLabel()
            end)
            if not ok then
                Logger.error("segment %d endValueSlider callback failed: %s", index, tostring(err))
            end
        end
    end
    
    sw.easingCombo.callback = function(component, event)
        if GUI._initializing or index > #State.segments then return end
        if event == octane.gui.eventType.VALUE_CHANGE then
            local ok, err = pcall(function()
                State.segments[index].easingCurve = component.selectedIx
            end)
            if not ok then
                Logger.error("segment %d easingCombo callback failed: %s", index, tostring(err))
            end
        end
    end
end

--------------------------------------------------------------------------------
-- UI Updates
--------------------------------------------------------------------------------

---Updates the info label with current animation summary
function GUI:updateInfoLabel()
    self.infoLabel.text = State:getSummary()
end

---Updates the buffer info label with current buffer status
function GUI:updateBufferInfo()
    self.bufferInfoLabel.text = State:getBufferInfo()
end

---Refreshes all custom mode UI elements from state
function GUI:refreshCustomUI()
    self.customEditor.text = State.valuesText
    self.customStartSlider.value = State.customStartFrame
    self.customEndSlider.value = State.customEndFrame
    self.interpCombo.selectedIx = State.interpolationType
    self.loopCheck.checked = State.loopAnimation
    self:updateInfoLabel()
    self:updateBufferInfo()
end

return GUI

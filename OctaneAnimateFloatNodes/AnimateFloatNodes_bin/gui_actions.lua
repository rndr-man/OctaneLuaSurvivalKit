--[[
================================================================================
GUI Actions Module - User Actions and Animation Execution
================================================================================

@description    Handles all user-triggered actions for the Animate Float Nodes
                tool. This includes animation preview, copy, clear, save, load
                operations, and the core animation execution logic.
                
                Separated from gui.lua to maintain a clean separation between
                UI construction and business logic.

@author         Padi Frigg (AI assisted)
@version        7.12

@dependencies   config.lua, logger.lua, helpers.lua, state.lua must be loaded first

--------------------------------------------------------------------------------
MODULE CONTENTS
--------------------------------------------------------------------------------

Preview Actions:
  - previewValues()       : Shows statistics about parsed values

Copy/Paste Actions:
  - copyAnimation()       : Copies animation from selected node to buffer

Buffer Actions:
  - clearBuffer()         : Clears the animation buffer with confirmation

File Actions:
  - saveAnimationToFile() : Saves animation to JSON file
  - loadAnimationFromFile(): Loads animation from JSON file

Animation Execution:
  - applyAnimation()      : Validates and applies animation to nodes
  - executeAnimation()    : Core animation application logic

================================================================================
--]]

--------------------------------------------------------------------------------
-- Module Declaration
--------------------------------------------------------------------------------

---@class GUIActions
---Handles user actions and animation execution
GUIActions = {}

--------------------------------------------------------------------------------
-- Preview Actions
--------------------------------------------------------------------------------

---Shows a preview dialog with statistics about the parsed values
---@param gui table Reference to GUI module for UI updates
function GUIActions.previewValues(gui)
    local ok, err = pcall(function()
        local values = Helpers.parseValues(State.valuesText)
        
        if #values == 0 then
            Dialog.info(Config.STRINGS.DIALOGS.NO_VALUES, 
                "Please paste numeric values first.")
            return
        end
        
        local stats = Helpers.getValueStats(values)
        
        Dialog.info(Config.STRINGS.DIALOGS.VALUE_PREVIEW,
            string.format(
                "Parsed %d values:\n\nFirst: %.4f\nLast: %.4f\nMin: %.4f\nMax: %.4f",
                stats.count, stats.first, stats.last, stats.min, stats.max
            ))
    end)
    
    if not ok then
        Logger.error("previewValues failed: %s", tostring(err))
    end
end

--------------------------------------------------------------------------------
-- Copy Animation Action
--------------------------------------------------------------------------------

---Copies animation data from the currently selected Float node
---@param gui table Reference to GUI module for UI updates
function GUIActions.copyAnimation(gui)
    local ok, err = pcall(function()
        local selection = octane.project.getSelection()
        
        if #selection == 0 then
            Dialog.info(Config.STRINGS.DIALOGS.NO_SELECTION,
                "Please select a Float node with animation to copy from.")
            return
        end
        
        -- Find first Float node in selection
        local sourceNode = nil
        for _, node in ipairs(selection) do
            if node.type == octane.NT_FLOAT then
                sourceNode = node
                break
            end
        end
        
        if not sourceNode then
            Dialog.info(Config.STRINGS.DIALOGS.NO_SELECTION,
                "Please select a Float Value node (NT_FLOAT) with animation.")
            return
        end
        
        local animData, extractErr = Helpers.extractAnimation(sourceNode)
        if extractErr then
            Dialog.info("No Animation", extractErr)
            return
        end
        
        -- Store values as text (channel 0 only for display)
        State.valuesText = Helpers.formatValuesForEditor(animData.values)
        State.sourceNodeName = animData.nodeName
        -- Store raw 4-channel values for export
        State.rawValues = animData.rawValues or {}
        
        -- Convert times to frame range
        local firstFrame, lastFrame = Helpers.timesToFrameRange(animData.times, State.fps)
        State.customStartFrame = firstFrame
        State.customEndFrame = lastFrame
        
        -- Copy loop setting from source
        if animData.period and animData.period > 0 then
            State.loopAnimation = true
        end
        
        -- Save to temp buffer for persistence
        State:saveToTempBuffer()
        
        -- Update UI
        gui:refreshCustomUI()
        
        -- Switch to Custom mode
        State.animationMode = Config.MODE.CUSTOM
        gui.modeCombo.selectedIx = Config.MODE.CUSTOM
        gui:updateModeVisibility()
        
        Dialog.success(Config.STRINGS.DIALOGS.ANIMATION_COPIED,
            string.format(
                "Copied from '%s'\n\nKeyframes: %d\nFrames: %d to %d\nChannels: 4\nLoop: %s",
                animData.nodeName, animData.numKeyframes, firstFrame, lastFrame, 
                State.loopAnimation and "Yes" or "No"
            ))
    end)
    
    if not ok then
        Logger.error("copyAnimation failed: %s", tostring(err))
    end
end

--------------------------------------------------------------------------------
-- Buffer Actions
--------------------------------------------------------------------------------

---Clears the animation buffer with user confirmation
---@param gui table Reference to GUI module for UI updates
function GUIActions.clearBuffer(gui)
    local ok, err = pcall(function()
        if Dialog.confirm("This will clear all custom values and reset frame range.\n\nContinue?",
                          Config.STRINGS.DIALOGS.CLEAR_CONFIRM) then
            State:clearTempBuffer()
            gui:refreshCustomUI()
            Logger.info("Buffer cleared")
        end
    end)
    
    if not ok then
        Logger.error("clearBuffer failed: %s", tostring(err))
    end
end

--------------------------------------------------------------------------------
-- File Actions
--------------------------------------------------------------------------------

---Saves the current animation to a JSON file
---@param gui table Reference to GUI module for UI updates
function GUIActions.saveAnimationToFile(gui)
    local ok, err = pcall(function()
        local values = Helpers.parseValues(State.valuesText)
        
        if #values == 0 then
            octane.gui.showDialog{
                type = octane.gui.dialogType.BUTTON_DIALOG,
                title = Config.STRINGS.DIALOGS.NO_VALUES,
                text = "Please enter or copy values before saving."
            }
            return
        end
        
        -- Get save location
        local defaultDir = octane.file.getParentDirectory(
            octane.project.getCurrentProject() or ""
        ) or octane.file.getSpecialDirectories().homeDirectory
        
        local defaultName = string.format("animation_%s_%d-%d.json",
            os.date("%Y%m%d"),
            State.customStartFrame,
            State.customEndFrame
        )
        
        local result = octane.gui.showDialog{
            type = octane.gui.dialogType.FILE_DIALOG,
            title = Config.STRINGS.DIALOGS.SAVE_ANIMATION,
            save = true,
            defaultFilename = defaultName,
            wildcards = Config.FILE.JSON_WILDCARD,
            startDirectory = defaultDir
        }
        
        local filePath = result and result.result
        if not filePath or filePath == "" then
            return
        end
        
        -- Ensure .json extension
        if not string.match(filePath, "%.json$") then
            filePath = filePath .. Config.FILE.JSON_EXTENSION
        end
        
        -- Skip description dialog for simplicity
        local description = ""
        
        local saveOk, saveErr = State:saveToFile(filePath, description)
        
        if saveOk then
            octane.gui.showDialog{
                type = octane.gui.dialogType.BUTTON_DIALOG,
                title = Config.STRINGS.DIALOGS.SAVED,
                text = string.format("Animation saved to:\n%s\n\n%d keyframes, frames %d to %d",
                    filePath, #values, State.customStartFrame, State.customEndFrame)
            }
        else
            Logger.error("Save failed: %s", tostring(saveErr))
            octane.gui.showDialog{
                type = octane.gui.dialogType.BUTTON_DIALOG,
                title = Config.STRINGS.DIALOGS.SAVE_FAILED,
                text = "Could not save file:\n\n" .. tostring(saveErr)
            }
        end
    end)
    
    if not ok then
        Logger.error("saveAnimationToFile failed: %s", tostring(err))
    end
end

---Loads animation data from a JSON file
---@param gui table Reference to GUI module for UI updates
function GUIActions.loadAnimationFromFile(gui)
    local ok, err = pcall(function()
        local defaultDir = octane.file.getParentDirectory(
            octane.project.getCurrentProject() or ""
        ) or octane.file.getSpecialDirectories().homeDirectory
        
        local result = octane.gui.showDialog{
            type = octane.gui.dialogType.FILE_DIALOG,
            title = Config.STRINGS.DIALOGS.LOAD_ANIMATION,
            save = false,
            wildcards = Config.FILE.JSON_WILDCARD,
            startDirectory = defaultDir
        }
        
        local filePath = result and result.result
        if not filePath or filePath == "" then
            return
        end
        
        local loadOk, loadErr = State:loadFromFile(filePath)
        
        if loadOk then
            gui:refreshCustomUI()
            
            -- Switch to Custom mode
            State.animationMode = Config.MODE.CUSTOM
            gui.modeCombo.selectedIx = Config.MODE.CUSTOM
            gui:updateModeVisibility()
            
            local values = Helpers.parseValues(State.valuesText)
            octane.gui.showDialog{
                type = octane.gui.dialogType.BUTTON_DIALOG,
                title = Config.STRINGS.DIALOGS.LOADED,
                text = string.format("Animation loaded:\n\n%d values\nFrames: %d to %d\nLoop: %s",
                    #values, State.customStartFrame, State.customEndFrame,
                    State.loopAnimation and "Yes" or "No")
            }
        else
            Logger.error("Load failed: %s", tostring(loadErr))
            octane.gui.showDialog{
                type = octane.gui.dialogType.BUTTON_DIALOG,
                title = Config.STRINGS.DIALOGS.LOAD_FAILED,
                text = "Could not load file:\n\n" .. tostring(loadErr)
            }
        end
    end)
    
    if not ok then
        Logger.error("loadAnimationFromFile failed: %s", tostring(err))
    end
end

--------------------------------------------------------------------------------
-- Animation Execution
--------------------------------------------------------------------------------

---Validates state and applies animation to target nodes
---@param gui table Reference to GUI module for UI updates
function GUIActions.applyAnimation(gui)
    -- Use centralized validation
    local valid, validErr = Validation.beforeApply()
    if not valid then
        Logger.error("Validation failed: %s", tostring(validErr))
        Dialog.validationError(validErr)
        return
    end
    
    State.isProcessing = true
    
    local status, result = pcall(function()
        return GUIActions.executeAnimation(gui)
    end)
    
    State.isProcessing = false
    
    if not status then
        Logger.error("Animation execution exception: %s", tostring(result))
        Dialog.error("Animation Failed", tostring(result))
    end
end

---Executes the animation application to all target nodes
---Wrapped in undo block for single-click undo support
---@param gui table Reference to GUI module for UI updates
---@return boolean success True if animation was applied successfully
function GUIActions.executeAnimation(gui)
    local timeTable, valTable
    local modeDesc
    
    if State.animationMode == Config.MODE.SEGMENTS then
        timeTable, valTable = Helpers.mergeSegments(State.segments, State.fps)
        modeDesc = string.format("Segments (%d)", #State.segments)
    else
        Logger.debug("=== executeAnimation Custom Mode ===")
        Logger.debug("Start frame: %d", State.customStartFrame)
        Logger.debug("End frame: %d", State.customEndFrame)
        Logger.debug("FPS: %d", State.fps)
        Logger.debug("Loop: %s", tostring(State.loopAnimation))
        Logger.debug("rawValues count: %d", #(State.rawValues or {}))
        
        -- Check if we have rawValues with actual multi-channel data
        local useRawValues = false
        if State.rawValues and #State.rawValues > 0 then
            -- Check if any channel other than 0 has non-zero values
            for _, raw in ipairs(State.rawValues) do
                if type(raw) == "table" then
                    if (raw[2] and raw[2] ~= 0) or 
                       (raw[3] and raw[3] ~= 0) or 
                       (raw[4] and raw[4] ~= 0) then
                        useRawValues = true
                        break
                    end
                end
            end
        end
        
        Logger.debug("useRawValues: %s", tostring(useRawValues))
        
        if useRawValues then
            -- Use rawValues for full 4-channel support
            timeTable, valTable = Helpers.buildAnimationDataFromRaw(
                State.rawValues, State.customStartFrame, State.customEndFrame, State.fps
            )
            modeDesc = "Custom (multi-channel)"
            Logger.debug("Using rawValues path")
        else
            -- Use text editor values (channel 0 only)
            local values = Helpers.parseValues(State.valuesText)
            
            Logger.debug("Values count from text: %d", #values)
            
            if #values == 0 then
                Logger.error("No values parsed from text")
                octane.gui.showDialog{
                    type = octane.gui.dialogType.BUTTON_DIALOG,
                    title = Config.STRINGS.DIALOGS.ERROR,
                    text = "No values to apply. Please enter values in the text area."
                }
                return false
            end
            
            Logger.debug("First 3 values: %s, %s, %s", 
                tostring(values[1]), tostring(values[2]), tostring(values[3]))
            
            timeTable, valTable = Helpers.buildAnimationData(
                values, State.customStartFrame, State.customEndFrame, State.fps
            )
            modeDesc = "Custom"
            Logger.debug("Using text-based path")
        end
        
        Logger.debug("timeTable count: %d", #timeTable)
        Logger.debug("valTable count: %d", #valTable)
        if #timeTable > 0 then
            Logger.debug("timeTable[1]: %s", tostring(timeTable[1]))
            Logger.debug("timeTable[last]: %s", tostring(timeTable[#timeTable]))
        end
        if #valTable > 0 then
            local v1 = valTable[1]
            Logger.debug("valTable[1] type: %s", type(v1))
            if type(v1) == "table" then
                Logger.debug("valTable[1]: {%s, %s, %s, %s}", 
                    tostring(v1[1]), tostring(v1[2]), tostring(v1[3]), tostring(v1[4]))
            else
                Logger.debug("valTable[1]: %s", tostring(v1))
            end
        end
    end
    
    -- Calculate period for looping
    local period = 0
    if State.loopAnimation and #timeTable >= 2 then
        period = timeTable[#timeTable] - timeTable[1]
    end
    
    Logger.debug("Calculated period: %s", tostring(period))
    
    -- When looping, period must be > last time value
    -- Add one frame duration to ensure period exceeds time span
    if State.loopAnimation and period > 0 then
        local frameDuration = 1.0 / State.fps
        period = period + frameDuration
        Logger.debug("Adjusted period for loop: %s", tostring(period))
    end
    
    -- Validate time table
    if #timeTable < 1 then
        Logger.error("Empty time table")
        Dialog.error("No Keyframes", "No keyframes generated.")
        return false
    end
    
    -- Check for time ordering issues
    for i = 2, #timeTable do
        if timeTable[i] <= timeTable[i-1] then
            Logger.error("Time not increasing at index %d: %.6f <= %.6f", 
                i, timeTable[i], timeTable[i-1])
            Dialog.error("Invalid Animation", 
                string.format("Invalid time sequence at keyframe %d", i))
            return false
        end
    end
    
    -- Start undo block for single-click undo (if available)
    local undoSupported = octane.undo and type(octane.undo.start) == "function"
    if undoSupported then
        local undoOk, undoErr = pcall(function()
            octane.undo.start(Config.UNDO.APPLY_ANIMATION)
        end)
        if not undoOk then
            Logger.warn("Undo not available: %s", tostring(undoErr))
            undoSupported = false
        end
    end
    
    local applySuccess = true
    local applyError = nil
    
    -- Apply to all target nodes
    for i, node in ipairs(State.targetNodes) do
        local nodeName = node.name or ("Node " .. i)
        
        local nodeOk, nodeErr = pcall(function()
            node:setAnimator(octane.A_VALUE, timeTable, valTable, period, true)
        end)
        
        if not nodeOk then
            Logger.error("setAnimator failed on '%s': %s", nodeName, tostring(nodeErr))
            applySuccess = false
            applyError = string.format("Failed to apply to '%s':\n\n%s", nodeName, tostring(nodeErr))
            break
        end
    end
    
    -- End undo block (if we started one)
    if undoSupported then
        pcall(function()
            octane.undo.end_()
        end)
    end
    
    if not applySuccess then
        Dialog.error("Apply Failed", applyError)
        return false
    end
    
    octane.changemanager.update()
    
    local startF, endF
    if State.animationMode == Config.MODE.SEGMENTS then
        startF, endF = Helpers.getSegmentsFrameRange(State.segments)
    else
        startF, endF = State.customStartFrame, State.customEndFrame
    end
    
    Dialog.success("Animation Applied",
        string.format(
            "Mode: %s\nNodes: %d\nKeyframes: %d\nFrames: %d to %d\nLoop: %s",
            modeDesc, State.nodeCount, #timeTable, startF, endF,
            State.loopAnimation and "Yes" or "No"
        ))
    
    return true
end

return GUIActions

--[[
================================================================================
State Module - Application State Management
================================================================================

@description    Manages all application state for the Animate Float Nodes tool.
                Handles node selection, animation parameters, segment definitions,
                and file-based persistence between sessions.

@author         Padi Frigg (AI assisted)
@version        7.12

@dependencies   config.lua, logger.lua, helpers.lua must be loaded first

--------------------------------------------------------------------------------
STATE PROPERTIES
--------------------------------------------------------------------------------

Selection State:
  - targetNodes     : Array of selected Float Value nodes to animate
  - nodeCount       : Number of selected nodes

Project Settings:
  - fps             : Frames per second from project settings
  - projectSettings : Reference to Octane project settings node
  - sceneGraph      : Reference to current scene graph

Animation Mode:
  - animationMode   : 1 = Segments, 2 = Custom Values

Segment Parameters:
  - segments        : Array of segment definitions
  - maxSegments     : Maximum allowed segments (from Config)

Custom Mode Parameters:
  - customStartFrame : Start frame for custom animation
  - customEndFrame   : End frame for custom animation
  - valuesText       : Text content of values editor (channel 0)
  - sourceNodeName   : Name of node values were copied from
  - rawValues        : Full 4-channel values {v1, v2, v3, v4}[]

Advanced Options:
  - interpolationType : 1=Linear, 2=Smooth, 3=Step
  - loopAnimation     : Whether animation should loop

Runtime State:
  - isProcessing    : True while applying animation
  - lastError       : Last error message for debugging

================================================================================
--]]

--------------------------------------------------------------------------------
-- Module Declaration
--------------------------------------------------------------------------------

---@class State
---Global application state container
State = {
    -- Selection state
    targetNodes = {},
    nodeCount = 0,
    
    -- Project settings
    fps = nil,  -- Will be set from Config.LIMITS.DEFAULT_FPS
    projectSettings = nil,
    sceneGraph = nil,
    
    -- Animation mode: 1 = Segments, 2 = Custom
    animationMode = nil,  -- Will be set from Config.DEFAULTS.ANIMATION_MODE
    
    -- Segment parameters (dynamic array)
    segments = {},
    maxSegments = nil,  -- Will be set from Config.LIMITS.MAX_SEGMENTS
    
    -- Custom mode parameters
    customStartFrame = nil,  -- Will be set from Config.DEFAULTS.CUSTOM.START_FRAME
    customEndFrame = nil,    -- Will be set from Config.DEFAULTS.CUSTOM.END_FRAME
    valuesText = "",
    sourceNodeName = "",
    rawValues = {},  -- Full 4-channel values {v1, v2, v3, v4} for each keyframe
    
    -- Advanced options
    interpolationType = nil,  -- Will be set from Config.DEFAULTS.INTERPOLATION_TYPE
    loopAnimation = nil,      -- Will be set from Config.DEFAULTS.LOOP_ANIMATION
    
    -- Runtime state
    isProcessing = false,
    lastError = nil
}

-- Initialize defaults from Config (done here to ensure Config is loaded)
local function initializeDefaults()
    State.fps = Config.LIMITS.DEFAULT_FPS
    State.animationMode = Config.DEFAULTS.ANIMATION_MODE
    State.maxSegments = Config.LIMITS.MAX_SEGMENTS
    State.customStartFrame = Config.DEFAULTS.CUSTOM.START_FRAME
    State.customEndFrame = Config.DEFAULTS.CUSTOM.END_FRAME
    State.interpolationType = Config.DEFAULTS.INTERPOLATION_TYPE
    State.loopAnimation = Config.DEFAULTS.LOOP_ANIMATION
end

--------------------------------------------------------------------------------
-- Segment Factory
--------------------------------------------------------------------------------

---Creates a default segment definition
---If there's a previous segment, chains from its end values
---@param self State The state object
---@param index number The segment index (1-based)
---@return table segment New segment definition
function State:createDefaultSegment(index)
    local prevSeg = self.segments[index - 1]
    
    if prevSeg then
        -- Chain from previous segment
        return {
            startFrame = prevSeg.endFrame,
            endFrame = prevSeg.endFrame + Config.DEFAULTS.SEGMENT.END_FRAME,
            startValue = prevSeg.endValue,
            endValue = prevSeg.endValue + Config.DEFAULTS.SEGMENT.END_VALUE,
            easingCurve = Config.DEFAULTS.SEGMENT.EASING_CURVE
        }
    else
        -- First segment defaults
        return {
            startFrame = Config.DEFAULTS.SEGMENT.START_FRAME,
            endFrame = Config.DEFAULTS.SEGMENT.END_FRAME,
            startValue = Config.DEFAULTS.SEGMENT.START_VALUE,
            endValue = Config.DEFAULTS.SEGMENT.END_VALUE,
            easingCurve = Config.DEFAULTS.SEGMENT.EASING_CURVE
        }
    end
end

--------------------------------------------------------------------------------
-- Segment Management
--------------------------------------------------------------------------------

---Adds a new segment to the list
---@param self State The state object
---@return boolean success True if segment was added
---@return string|nil error Error message if failed
function State:addSegment()
    if #self.segments >= self.maxSegments then
        return false, string.format("Maximum %d segments allowed", self.maxSegments)
    end
    
    local newSeg = self:createDefaultSegment(#self.segments + 1)
    table.insert(self.segments, newSeg)
    return true, nil
end

---Removes the last segment from the list
---@param self State The state object
---@return boolean success True if segment was removed
---@return string|nil error Error message if failed
function State:removeSegment()
    if #self.segments <= Config.LIMITS.MIN_SEGMENTS then
        return false, "At least one segment is required"
    end
    
    table.remove(self.segments)
    return true, nil
end

---Gets the current segment count
---@param self State The state object
---@return number count Number of segments
function State:getSegmentCount()
    return #self.segments
end

--------------------------------------------------------------------------------
-- File-Based Persistence
--------------------------------------------------------------------------------

---Saves current custom values to temp file for session persistence
---@param self State The state object
---@return boolean success True if save succeeded
function State:saveToTempBuffer()
    local ok, err = Helpers.saveTempBuffer(
        self.valuesText,
        self.customStartFrame,
        self.customEndFrame,
        self.loopAnimation,
        self.interpolationType,
        self.fps,
        self.sourceNodeName
    )
    
    if not ok then
        Logger.error("Failed to save temp buffer: %s", tostring(err))
    end
    
    return ok
end

---Loads custom values from temp file
---@param self State The state object
---@return boolean success True if load succeeded (false if file doesn't exist)
function State:loadFromTempBuffer()
    local data, err = Helpers.loadTempBuffer()
    
    if not data then
        -- Not an error if file doesn't exist
        return false
    end
    
    self.valuesText = data.valuesText or ""
    self.customStartFrame = data.startFrame or Config.DEFAULTS.CUSTOM.START_FRAME
    self.customEndFrame = data.endFrame or Config.DEFAULTS.CUSTOM.END_FRAME
    self.loopAnimation = data.loopEnabled or false
    self.interpolationType = data.interpolation or Config.INTERPOLATION.LINEAR
    self.sourceNodeName = data.nodeName or ""
    
    Logger.info("Loaded buffer: %d values from '%s'",
        #Helpers.parseValues(self.valuesText), self.sourceNodeName)
    
    return true
end

---Clears temp buffer and resets custom values
---@param self State The state object
---@return boolean success True if cleared successfully
function State:clearTempBuffer()
    self.valuesText = ""
    self.customStartFrame = Config.DEFAULTS.CUSTOM.START_FRAME
    self.customEndFrame = Config.DEFAULTS.CUSTOM.END_FRAME
    self.loopAnimation = Config.DEFAULTS.LOOP_ANIMATION
    self.interpolationType = Config.DEFAULTS.INTERPOLATION_TYPE
    self.sourceNodeName = ""
    self.rawValues = {}
    
    return Helpers.clearTempBuffer()
end

--------------------------------------------------------------------------------
-- JSON File Operations
--------------------------------------------------------------------------------

---Saves animation data to a JSON file
---@param self State The state object
---@param filePath string Path to save file
---@param description string Optional description for metadata
---@return boolean success True if save succeeded
---@return string|nil error Error message if failed
function State:saveToFile(filePath, description)
    -- Build animation data structure
    local values = Helpers.parseValues(self.valuesText)
    
    if #values == 0 then
        return false, "No values to save"
    end
    
    -- Generate times array from frame range
    local times = {}
    local frames = {}
    local frameCount = self.customEndFrame - self.customStartFrame + 1
    
    for i = 1, frameCount do
        local frame = self.customStartFrame + (i - 1)
        table.insert(frames, frame)
        table.insert(times, frame / self.fps)
    end
    
    -- Distribute values to match frame count
    local distributedValues = Helpers.distributeValues(values, frameCount)
    
    -- Build channels structure
    -- If we have rawValues (from copy), use all 4 channels
    -- Otherwise, just save channel 0 from the text editor values
    local channels = {}
    
    if self.rawValues and #self.rawValues > 0 then
        -- Distribute raw values to match frame count
        local distributedRaw = Helpers.distributeValues(self.rawValues, frameCount)
        
        for c = 0, 3 do
            channels[tostring(c)] = {}
            for i, val in ipairs(distributedRaw) do
                if type(val) == "table" then
                    channels[tostring(c)][i] = val[c + 1] or 0
                else
                    channels[tostring(c)][i] = (c == 0) and val or 0
                end
            end
        end
    else
        -- Only channel 0 from text editor
        channels["0"] = distributedValues
        for c = 1, 3 do
            channels[tostring(c)] = {}
            for i = 1, #distributedValues do
                channels[tostring(c)][i] = 0
            end
        end
    end
    
    local jsonData = {
        formatVersion = Config.FILE.JSON_FORMAT_VERSION,
        metadata = {
            sourceNode = self.sourceNodeName or "Manual Entry",
            exportDate = os.date("%Y-%m-%dT%H:%M:%S"),
            description = description or ""
        },
        project = {
            fps = self.fps
        },
        animation = {
            frameRange = {
                startFrame = self.customStartFrame,
                endFrame = self.customEndFrame
            },
            keyframes = {
                count = #distributedValues,
                times = times,
                frames = frames,
                channels = channels
            },
            loop = {
                enabled = self.loopAnimation,
                period = self.loopAnimation and (times[#times] - times[1]) or 0
            },
            interpolation = self.interpolationType
        }
    }
    
    local ok, err = Helpers.saveJsonFile(filePath, jsonData)
    
    if ok then
        Logger.info("Saved animation to: %s", filePath)
    end
    
    return ok, err
end

---Loads animation data from a JSON file
---@param self State The state object
---@param filePath string Path to load file
---@return boolean success True if load succeeded
---@return string|nil error Error message if failed
function State:loadFromFile(filePath)
    local jsonData, err = Helpers.loadJsonFile(filePath)
    
    if not jsonData then
        return false, err
    end
    
    local parsed, parseErr = Helpers.parseAnimationJson(jsonData)
    
    if not parsed then
        return false, parseErr
    end
    
    -- Apply loaded data
    self.valuesText = Helpers.formatValuesForEditor(parsed.values)
    self.customStartFrame = parsed.startFrame
    self.customEndFrame = parsed.endFrame
    self.loopAnimation = parsed.loopEnabled
    self.interpolationType = parsed.interpolation or Config.INTERPOLATION.LINEAR
    self.sourceNodeName = parsed.nodeName or "Loaded"
    self.rawValues = parsed.rawValues or {}
    
    -- Save to temp buffer for persistence
    self:saveToTempBuffer()
    
    Logger.info("Loaded animation from: %s", filePath)
    Logger.info("  Keyframes: %d, Frames: %d to %d",
        parsed.keyframeCount or #parsed.values, parsed.startFrame, parsed.endFrame)
    
    -- Log which channels have data
    if parsed.channels then
        local channelInfo = {}
        for c = 0, 3 do
            if parsed.channels[c] and #parsed.channels[c] > 0 then
                table.insert(channelInfo, tostring(c))
            end
        end
        if #channelInfo > 0 then
            Logger.info("  Channels with data: %s", table.concat(channelInfo, ", "))
        end
    end
    
    return true, nil
end

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

---Initializes application state
---Loads project settings, validates selection, restores temp buffer
---@param self State The state object
---@return boolean success True if initialization succeeded
function State:initialize()
    -- Initialize defaults from Config
    initializeDefaults()
    
    -- Get scene graph reference
    self.sceneGraph = octane.project.getSceneGraph()
    if not self.sceneGraph then
        Dialog.error("No Scene", 
            "No scene is currently loaded. Please open or create a scene first.")
        return false
    end
    
    -- Get project FPS setting
    self.projectSettings = octane.project.getProjectSettings()
    if self.projectSettings then
        self.fps = self.projectSettings:getAttribute(octane.A_FRAMES_PER_SECOND) or Config.LIMITS.DEFAULT_FPS
    end
    
    -- Initialize with one default segment
    self.segments = {}
    table.insert(self.segments, self:createDefaultSegment(1))
    
    -- Load persistent custom values from temp file
    self:loadFromTempBuffer()
    
    -- Validate node selection
    if not self:validateSelection() then
        return false
    end
    
    return true
end

--------------------------------------------------------------------------------
-- Selection Management
--------------------------------------------------------------------------------

---Validates current node selection and filters for Float nodes
---@param self State The state object
---@return boolean valid True if at least one Float node is selected
function State:validateSelection()
    local selection = octane.project.getSelection()
    self.targetNodes = {}
    
    -- Filter for Float Value nodes only
    for _, node in ipairs(selection) do
        if node.type == octane.NT_FLOAT then
            table.insert(self.targetNodes, node)
        end
    end
    
    self.nodeCount = #self.targetNodes
    
    if self.nodeCount == 0 then
        Dialog.noSelection()
        return false
    end
    
    return true
end

--------------------------------------------------------------------------------
-- Validation
--------------------------------------------------------------------------------

---Validates current state before applying animation
---@deprecated Use Validation.beforeApply() instead
---@param self State The state object
---@return boolean valid True if state is valid
---@return string|nil error Error message if invalid
function State:validate()
    -- Delegate to Validation module
    return Validation.beforeApply()
end

--------------------------------------------------------------------------------
-- State Summary
--------------------------------------------------------------------------------

---Generates a human-readable summary of current animation settings
---@param self State The state object
---@return string summary Multi-line summary text
function State:getSummary()
    if self.animationMode == Config.MODE.SEGMENTS then
        -- Segments mode summary
        local minFrame, maxFrame = Helpers.getSegmentsFrameRange(self.segments)
        local totalFrames = maxFrame - minFrame + 1
        local duration = totalFrames / self.fps
        
        return string.format(
            "%d segment(s), %d total frames\nRange: %d to %d (%.2f seconds at %d fps)",
            #self.segments, totalFrames, minFrame, maxFrame, duration, self.fps
        )
    else
        -- Custom mode summary
        local values = Helpers.parseValues(self.valuesText)
        local totalFrames = self.customEndFrame - self.customStartFrame + 1
        local duration = totalFrames / self.fps
        
        local sourceInfo = ""
        if self.sourceNodeName and self.sourceNodeName ~= "" then
            sourceInfo = " from '" .. self.sourceNodeName .. "'"
        end
        
        return string.format(
            "Custom: %d values%s, %d frames\nRange: %d to %d (%.2f seconds at %d fps)",
            #values, sourceInfo, totalFrames, self.customStartFrame, self.customEndFrame, duration, self.fps
        )
    end
end

---Generates a short buffer status string
---@param self State The state object
---@return string info Buffer status text
function State:getBufferInfo()
    local values = Helpers.parseValues(self.valuesText)
    if #values == 0 then
        return "Buffer: Empty"
    end
    
    local sourceInfo = self.sourceNodeName or "Manual"
    return string.format("Buffer: %d values from '%s' (frames %d-%d)", 
        #values, sourceInfo, self.customStartFrame, self.customEndFrame)
end

return State

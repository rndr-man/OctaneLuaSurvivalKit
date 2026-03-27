--[[
================================================================================
Validation Module - Input Validation Functions
================================================================================

@description    Provides validation functions for user input before applying
                animations. Returns success/failure with descriptive error
                messages for user feedback.

@author         Padi Frigg (AI assisted)
@version        7.12

@dependencies   config.lua, logger.lua, helpers.lua must be loaded first

--------------------------------------------------------------------------------
USAGE
--------------------------------------------------------------------------------

    -- Single validation
    local ok, err = Validation.frameRange(0, 100)
    if not ok then
        Dialog.validationError(err)
        return
    end
    
    -- Full validation before apply
    local ok, err = Validation.beforeApply()
    if not ok then
        Dialog.validationError(err)
        return
    end

================================================================================
--]]

--------------------------------------------------------------------------------
-- Module Declaration
--------------------------------------------------------------------------------

---@class Validation
---Input validation functions
Validation = {}

--------------------------------------------------------------------------------
-- Selection Validation
--------------------------------------------------------------------------------

---Validates that Float nodes are selected
---@param nodes table|nil Array of nodes (uses State.targetNodes if nil)
---@return boolean valid True if at least one Float node selected
---@return string|nil error Error message if invalid
function Validation.selection(nodes)
    nodes = nodes or State.targetNodes
    
    if not nodes or #nodes == 0 then
        return false, "No Float Value nodes selected"
    end
    
    -- Verify all are Float nodes
    for i, node in ipairs(nodes) do
        if node.type ~= octane.NT_FLOAT then
            return false, string.format(
                "Node %d ('%s') is not a Float Value node",
                i, node.name or "unnamed"
            )
        end
    end
    
    return true, nil
end

--------------------------------------------------------------------------------
-- Frame Range Validation
--------------------------------------------------------------------------------

---Validates a frame range
---@param startFrame number Start frame
---@param endFrame number End frame
---@return boolean valid True if range is valid
---@return string|nil error Error message if invalid
function Validation.frameRange(startFrame, endFrame)
    if not startFrame or not endFrame then
        return false, "Frame range not specified"
    end
    
    if startFrame < Config.LIMITS.MIN_FRAME then
        return false, string.format(
            "Start frame (%d) cannot be negative",
            startFrame
        )
    end
    
    if endFrame > Config.LIMITS.MAX_FRAME then
        return false, string.format(
            "End frame (%d) exceeds maximum (%d)",
            endFrame, Config.LIMITS.MAX_FRAME
        )
    end
    
    if endFrame <= startFrame then
        return false, string.format(
            "End frame (%d) must be greater than start frame (%d)",
            endFrame, startFrame
        )
    end
    
    local frameCount = endFrame - startFrame + 1
    if frameCount > 5000 then
        Logger.warn("Large frame count: %d frames", frameCount)
    end
    
    return true, nil
end

--------------------------------------------------------------------------------
-- Values Validation
--------------------------------------------------------------------------------

---Validates custom values array
---@param values table|nil Array of values (parses State.valuesText if nil)
---@return boolean valid True if values are valid
---@return string|nil error Error message if invalid
function Validation.values(values)
    if not values then
        values = Helpers.parseValues(State.valuesText)
    end
    
    if #values < Config.LIMITS.MIN_CUSTOM_VALUES then
        return false, string.format(
            "At least %d values required (found %d)",
            Config.LIMITS.MIN_CUSTOM_VALUES, #values
        )
    end
    
    -- Check for extreme values
    local hasExtreme = false
    local extremeLimit = 1e6
    
    for _, v in ipairs(values) do
        if math.abs(v) > extremeLimit then
            hasExtreme = true
            break
        end
    end
    
    if hasExtreme then
        Logger.warn("Values contain extreme magnitudes (>%g)", extremeLimit)
    end
    
    return true, nil
end

--------------------------------------------------------------------------------
-- Segments Validation
--------------------------------------------------------------------------------

---Validates segment definitions
---@param segments table|nil Array of segments (uses State.segments if nil)
---@return boolean valid True if segments are valid
---@return string|nil error Error message if invalid
function Validation.segments(segments)
    segments = segments or State.segments
    
    if not segments or #segments == 0 then
        return false, "No segments defined"
    end
    
    -- Validate each segment
    for i, seg in ipairs(segments) do
        if seg.endFrame <= seg.startFrame then
            return false, string.format(
                "Segment %d: End frame (%d) must be greater than start frame (%d)",
                i, seg.endFrame, seg.startFrame
            )
        end
        
        if seg.startFrame < Config.LIMITS.MIN_FRAME then
            return false, string.format(
                "Segment %d: Start frame cannot be negative",
                i
            )
        end
        
        if seg.endFrame > Config.LIMITS.MAX_FRAME then
            return false, string.format(
                "Segment %d: End frame exceeds maximum (%d)",
                i, Config.LIMITS.MAX_FRAME
            )
        end
    end
    
    -- Check for overlaps
    local overlaps = Helpers.detectOverlaps(segments)
    if #overlaps > 0 then
        local msgs = {}
        for _, overlap in ipairs(overlaps) do
            table.insert(msgs, string.format(
                "Segments %d and %d overlap at frames %d-%d",
                overlap.seg1, overlap.seg2, overlap.startFrame, overlap.endFrame
            ))
        end
        return false, "Overlapping segments:\n• " .. table.concat(msgs, "\n• ")
    end
    
    return true, nil
end

--------------------------------------------------------------------------------
-- FPS Validation
--------------------------------------------------------------------------------

---Validates FPS value
---@param fps number|nil FPS value (uses State.fps if nil)
---@return boolean valid True if FPS is valid
---@return string|nil error Error message if invalid
function Validation.fps(fps)
    fps = fps or State.fps
    
    if not fps then
        return false, "FPS not specified"
    end
    
    if fps < Config.LIMITS.MIN_FPS then
        return false, string.format(
            "FPS (%d) is below minimum (%d)",
            fps, Config.LIMITS.MIN_FPS
        )
    end
    
    if fps > Config.LIMITS.MAX_FPS then
        return false, string.format(
            "FPS (%d) exceeds maximum (%d)",
            fps, Config.LIMITS.MAX_FPS
        )
    end
    
    return true, nil
end

--------------------------------------------------------------------------------
-- Combined Validation
--------------------------------------------------------------------------------

---Runs all validations before applying animation
---@return boolean valid True if all validations pass
---@return string|nil error Error message if any validation fails
function Validation.beforeApply()
    -- Always validate selection
    local ok, err = Validation.selection()
    if not ok then
        return false, err
    end
    
    -- Always validate FPS
    ok, err = Validation.fps()
    if not ok then
        return false, err
    end
    
    -- Mode-specific validation
    if State.animationMode == Config.MODE.SEGMENTS then
        ok, err = Validation.segments()
        if not ok then
            return false, err
        end
    else
        -- Custom mode
        ok, err = Validation.values()
        if not ok then
            return false, err
        end
        
        ok, err = Validation.frameRange(State.customStartFrame, State.customEndFrame)
        if not ok then
            return false, err
        end
    end
    
    return true, nil
end

--------------------------------------------------------------------------------
-- Quick Checks (return boolean only)
--------------------------------------------------------------------------------

---Quick check if selection is valid
---@return boolean valid
function Validation.hasSelection()
    return State.targetNodes and #State.targetNodes > 0
end

---Quick check if custom values exist
---@return boolean hasValues
function Validation.hasValues()
    local values = Helpers.parseValues(State.valuesText)
    return #values >= Config.LIMITS.MIN_CUSTOM_VALUES
end

---Quick check if segments are defined
---@return boolean hasSegments
function Validation.hasSegments()
    return State.segments and #State.segments > 0
end

return Validation

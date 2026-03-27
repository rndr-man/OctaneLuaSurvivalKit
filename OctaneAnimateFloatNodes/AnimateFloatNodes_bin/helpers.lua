--[[
================================================================================
Helpers Module - Pure Functions for Animation Processing
================================================================================

@description    Collection of pure utility functions for animation calculations,
                value parsing, easing curves, JSON file I/O, and data formatting.
                No side effects or global state modifications.

@author         Padi Frigg (AI assisted)
@version        7.12

@dependencies   config.lua, logger.lua must be loaded first

--------------------------------------------------------------------------------
MODULE CONTENTS
--------------------------------------------------------------------------------

- File path utilities
- JSON file I/O with error handling
- Animation JSON structure creation and parsing
- Temp file persistence for session continuity
- Value parsing from text
- Easing/interpolation functions (6 curve types)
- Value generation and distribution
- Animation data building (single and multi-channel)
- Segment overlap detection
- Multi-segment animation merging with gap filling
- Animation extraction from Octane nodes
- Formatting utilities

================================================================================
--]]

--------------------------------------------------------------------------------
-- Module Declaration
--------------------------------------------------------------------------------

---@class Helpers
---Collection of pure utility functions for animation processing
Helpers = {}

--------------------------------------------------------------------------------
-- File Path Utilities
--------------------------------------------------------------------------------

---Gets the full path to the temp buffer file
---@return string path Full path to temp JSON file in system temp directory
function Helpers.getTempFilePath()
    return octane.file.join(
        octane.file.getSpecialDirectories().tempDirectory,
        Config.FILE.TEMP_FILENAME
    )
end

--------------------------------------------------------------------------------
-- JSON File I/O
--------------------------------------------------------------------------------

---Checks if a file exists at the given path
---@param path string The file path to check
---@return boolean exists True if file exists and is readable
function Helpers.fileExists(path)
    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    end
    return false
end

---Saves data as JSON to a file
---@param path string The file path to write to
---@param data table The data structure to encode as JSON
---@return boolean success True if save succeeded
---@return string|nil error Error message if save failed
function Helpers.saveJsonFile(path, data)
    local ok, err = pcall(function()
        local jsonStr = octane.json.encode(data)
        local file = io.open(path, "w")
        if not file then
            error("Could not open file for writing: " .. path)
        end
        file:write(jsonStr)
        file:close()
    end)
    
    if not ok then
        Logger.error("saveJsonFile: %s", tostring(err))
        return false, err
    end
    
    return true, nil
end

---Loads and parses a JSON file
---@param path string The file path to read from
---@return table|nil data Parsed JSON data, or nil on error
---@return string|nil error Error message if load failed
function Helpers.loadJsonFile(path)
    if not Helpers.fileExists(path) then
        return nil, "File does not exist: " .. path
    end
    
    local data, err
    local ok = pcall(function()
        local file = io.open(path, "r")
        if not file then
            error("Could not open file for reading: " .. path)
        end
        local content = file:read("*all")
        file:close()
        
        if not content or content == "" then
            error("File is empty")
        end
        
        data = octane.json.decode(content)
    end)
    
    if not ok then
        Logger.error("loadJsonFile: %s", tostring(err))
        return nil, err
    end
    
    return data, nil
end

---Deletes a file at the given path
---@param path string The file path to delete
---@return boolean success True if delete succeeded or file didn't exist
function Helpers.deleteFile(path)
    local ok, err = pcall(function()
        os.remove(path)
    end)
    
    if not ok then
        Logger.error("deleteFile: %s", tostring(err))
        return false
    end
    return true
end

--------------------------------------------------------------------------------
-- Animation JSON Structure
--------------------------------------------------------------------------------

--[[
JSON FORMAT SPECIFICATION

This format is designed to be useful for external tools (simulation, 
procedural generation, data manipulation). External tools can:
  - Read/modify channel arrays (apply noise, scale, offset)
  - Change timing (speed up, slow down, retime)
  - Generate new animations (sine waves, procedural curves)
  - Import from other software (Maya, Blender, Houdini)
  - Merge/blend multiple animation curves
  - Manipulate individual channels independently

Octane Float nodes support up to 4 values per keyframe.
Only channels present in JSON will be applied to the node.

{
    "formatVersion": "1.0",
    "metadata": {
        "sourceNode": "Float value",
        "exportDate": "2024-01-15T10:30:00",
        "description": ""
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
            "times": [0.0, 0.0416, ...],    -- time in seconds
            "frames": [0, 1, 2, ...],       -- frame numbers (convenience)
            "channels": {
                "0": [0.0, 0.01, ...],      -- channel 0 values
                "1": [0.0, 0.0, ...],       -- channel 1 values (optional)
                "2": [0.0, 0.0, ...],       -- channel 2 values (optional)
                "3": [0.0, 0.0, ...]        -- channel 3 values (optional)
            }
        },
        "loop": {
            "enabled": false,
            "period": 0                      -- in seconds, 0 = no loop
        },
        "interpolation": 1                  -- 1=Linear, 2=Smooth, 3=Step
    }
}
--]]

---Creates a JSON-serializable animation data structure
---@param animData table Animation data with times, values, rawValues, period, nodeName
---@param fps number Frames per second
---@param loopEnabled boolean Whether animation should loop
---@param interpolationType number Interpolation type (1=Linear, 2=Smooth, 3=Step)
---@param description string Optional description for metadata
---@return table jsonData Complete JSON-serializable structure
function Helpers.createAnimationJson(animData, fps, loopEnabled, interpolationType, description)
    -- Generate frame numbers from times
    local frames = {}
    for i, t in ipairs(animData.times or {}) do
        frames[i] = math.floor(t * fps + 0.5)
    end
    
    local startFrame = frames[1] or 0
    local endFrame = frames[#frames] or 0
    
    -- Build channels from raw values (which are {v1, v2, v3, v4} tables)
    local channels = {}
    local rawValues = animData.rawValues or {}
    
    -- Initialize channel arrays
    for c = 0, 3 do
        channels[tostring(c)] = {}
    end
    
    -- Extract each channel from the raw values
    for i, val in ipairs(rawValues) do
        if type(val) == "table" then
            for c = 0, 3 do
                channels[tostring(c)][i] = val[c + 1] or 0
            end
        else
            -- Single value, put in channel 0
            channels["0"][i] = val
            for c = 1, 3 do
                channels[tostring(c)][i] = 0
            end
        end
    end
    
    -- If no raw values but we have extracted values (channel 0 only)
    if #rawValues == 0 and animData.values and #animData.values > 0 then
        channels["0"] = animData.values
        for c = 1, 3 do
            channels[tostring(c)] = {}
            for i = 1, #animData.values do
                channels[tostring(c)][i] = 0
            end
        end
    end
    
    return {
        formatVersion = Config.FILE.JSON_FORMAT_VERSION,
        metadata = {
            sourceNode = animData.nodeName or "Unknown",
            exportDate = os.date("%Y-%m-%dT%H:%M:%S"),
            description = description or ""
        },
        project = {
            fps = fps
        },
        animation = {
            frameRange = {
                startFrame = startFrame,
                endFrame = endFrame
            },
            keyframes = {
                count = #(animData.times or {}),
                times = animData.times or {},
                frames = frames,
                channels = channels
            },
            loop = {
                enabled = loopEnabled,
                period = animData.period or 0
            },
            interpolation = interpolationType or Config.INTERPOLATION.LINEAR
        }
    }
end

---Parses a JSON animation structure into usable data
---@param jsonData table The loaded JSON data
---@return table|nil parsed Parsed animation data with values, rawValues, channels, etc.
---@return string|nil error Error message if parsing failed
function Helpers.parseAnimationJson(jsonData)
    if not jsonData then
        return nil, "No data provided"
    end
    
    -- Validate format version (warn but continue)
    if jsonData.formatVersion and jsonData.formatVersion ~= Config.FILE.JSON_FORMAT_VERSION then
        Logger.info("JSON format version mismatch: %s vs %s (will try to parse anyway)",
            tostring(jsonData.formatVersion), Config.FILE.JSON_FORMAT_VERSION)
    end
    
    local anim = jsonData.animation
    if not anim then
        return nil, "Missing animation data"
    end
    
    local keyframes = anim.keyframes
    if not keyframes then
        return nil, "Missing keyframes data"
    end
    
    local channels = keyframes.channels
    if not channels then
        return nil, "Missing channels data"
    end
    
    -- Determine which channels are present and their length
    local presentChannels = {}
    local keyframeCount = 0
    
    for c = 0, 3 do
        local channelKey = tostring(c)
        if channels[channelKey] and #channels[channelKey] > 0 then
            presentChannels[c] = channels[channelKey]
            if #channels[channelKey] > keyframeCount then
                keyframeCount = #channels[channelKey]
            end
        end
    end
    
    if keyframeCount == 0 then
        return nil, "No channel data found"
    end
    
    -- Build raw values array {v1, v2, v3, v4} for each keyframe
    local rawValues = {}
    for i = 1, keyframeCount do
        local v = {0, 0, 0, 0}
        for c = 0, 3 do
            if presentChannels[c] then
                v[c + 1] = presentChannels[c][i] or 0
            end
        end
        rawValues[i] = v
    end
    
    -- Extract channel 0 as the primary values for UI display
    local values = presentChannels[0] or {}
    
    return {
        values = values,
        rawValues = rawValues,
        channels = presentChannels,
        times = keyframes.times,
        frames = keyframes.frames,
        startFrame = anim.frameRange and anim.frameRange.startFrame or Config.DEFAULTS.CUSTOM.START_FRAME,
        endFrame = anim.frameRange and anim.frameRange.endFrame or Config.DEFAULTS.CUSTOM.END_FRAME,
        loopEnabled = anim.loop and anim.loop.enabled or false,
        period = anim.loop and anim.loop.period or 0,
        interpolation = anim.interpolation or Config.INTERPOLATION.LINEAR,
        fps = jsonData.project and jsonData.project.fps or Config.LIMITS.DEFAULT_FPS,
        nodeName = jsonData.metadata and jsonData.metadata.sourceNode or "Unknown",
        keyframeCount = keyframeCount
    }, nil
end

--------------------------------------------------------------------------------
-- Temp File Persistence
--------------------------------------------------------------------------------

---Saves current animation buffer to temp file for session persistence
---@param valuesText string The text content of the values editor
---@param startFrame number Start frame of animation
---@param endFrame number End frame of animation
---@param loopEnabled boolean Whether loop is enabled
---@param interpolationType number Interpolation type
---@param fps number Frames per second
---@param nodeName string Source node name
---@return boolean success True if save succeeded
---@return string|nil error Error message if failed
function Helpers.saveTempBuffer(valuesText, startFrame, endFrame, loopEnabled, interpolationType, fps, nodeName)
    local data = {
        formatVersion = Config.FILE.JSON_FORMAT_VERSION,
        metadata = {
            sourceNode = nodeName or "Manual Entry",
            exportDate = os.date("%Y-%m-%dT%H:%M:%S"),
            description = "Temp buffer"
        },
        project = {
            fps = fps or Config.LIMITS.DEFAULT_FPS
        },
        buffer = {
            valuesText = valuesText or "",
            startFrame = startFrame or Config.DEFAULTS.CUSTOM.START_FRAME,
            endFrame = endFrame or Config.DEFAULTS.CUSTOM.END_FRAME,
            loopEnabled = loopEnabled or false,
            interpolation = interpolationType or Config.INTERPOLATION.LINEAR
        }
    }
    
    local path = Helpers.getTempFilePath()
    local ok, err = Helpers.saveJsonFile(path, data)
    
    if ok then
        Logger.debug("Saved temp buffer to: %s", path)
    end
    
    return ok, err
end

---Loads animation buffer from temp file
---@return table|nil buffer Loaded buffer data, or nil if not found
---@return string|nil error Error message if load failed
function Helpers.loadTempBuffer()
    local path = Helpers.getTempFilePath()
    
    if not Helpers.fileExists(path) then
        return nil, "No temp buffer found"
    end
    
    local data, err = Helpers.loadJsonFile(path)
    if not data then
        return nil, err
    end
    
    local buffer = data.buffer
    if not buffer then
        return nil, "Invalid temp buffer format"
    end
    
    Logger.debug("Loaded temp buffer from: %s", path)
    
    return {
        valuesText = buffer.valuesText or "",
        startFrame = buffer.startFrame or Config.DEFAULTS.CUSTOM.START_FRAME,
        endFrame = buffer.endFrame or Config.DEFAULTS.CUSTOM.END_FRAME,
        loopEnabled = buffer.loopEnabled or false,
        interpolation = buffer.interpolation or Config.INTERPOLATION.LINEAR,
        fps = data.project and data.project.fps or Config.LIMITS.DEFAULT_FPS,
        nodeName = data.metadata and data.metadata.sourceNode or "Unknown"
    }, nil
end

---Clears the temp buffer file
---@return boolean success True if cleared successfully
function Helpers.clearTempBuffer()
    local path = Helpers.getTempFilePath()
    if Helpers.fileExists(path) then
        if Helpers.deleteFile(path) then
            Logger.debug("Cleared temp buffer")
            return true
        end
        return false
    end
    return true
end

--------------------------------------------------------------------------------
-- Value Parsing
--------------------------------------------------------------------------------

---Parses numeric values from text (supports space, comma, semicolon, newline separators)
---@param text string Text containing numeric values
---@return table values Array of parsed numbers
function Helpers.parseValues(text)
    local values = {}
    if not text then
        return values
    end
    
    for str in string.gmatch(text, "[^%s,;]+") do
        local num = tonumber(str)
        if num then
            table.insert(values, num)
        end
    end
    return values
end

---Calculates statistics for an array of values
---@param values table Array of numbers
---@return table|nil stats Statistics table with count, min, max, avg, first, last
function Helpers.getValueStats(values)
    if not values or #values == 0 then
        return nil
    end
    
    local min, max = values[1], values[1]
    local sum = 0
    
    for _, v in ipairs(values) do
        if v < min then min = v end
        if v > max then max = v end
        sum = sum + v
    end
    
    return {
        count = #values,
        min = min,
        max = max,
        avg = sum / #values,
        first = values[1],
        last = values[#values]
    }
end

--------------------------------------------------------------------------------
-- Easing Functions
--------------------------------------------------------------------------------

---Applies an easing curve to a normalized time value
---@param t number Normalized time (0 to 1)
---@param curveType number Easing type: 1=Linear, 2=EaseIn, 3=EaseOut, 4=EaseInOut, 5=Bounce, 6=Elastic
---@return number easedT The eased time value
function Helpers.easingFunction(t, curveType)
    if curveType == Config.EASING.LINEAR then
        -- Linear
        return t
    elseif curveType == Config.EASING.EASE_IN then
        -- Ease In (quadratic)
        return t * t
    elseif curveType == Config.EASING.EASE_OUT then
        -- Ease Out (quadratic)
        return 1 - (1 - t) * (1 - t)
    elseif curveType == Config.EASING.EASE_IN_OUT then
        -- Ease In-Out (quadratic)
        if t < 0.5 then
            return 2 * t * t
        else
            return 1 - 2 * (1 - t) * (1 - t)
        end
    elseif curveType == Config.EASING.BOUNCE then
        -- Bounce
        local n1, d1 = 7.5625, 2.75
        if t < 1 / d1 then
            return n1 * t * t
        elseif t < 2 / d1 then
            t = t - 1.5 / d1
            return n1 * t * t + 0.75
        elseif t < 2.5 / d1 then
            t = t - 2.25 / d1
            return n1 * t * t + 0.9375
        else
            t = t - 2.625 / d1
            return n1 * t * t + 0.984375
        end
    elseif curveType == Config.EASING.ELASTIC then
        -- Elastic
        local c4 = (2 * math.pi) / 3
        if t == 0 then return 0
        elseif t == 1 then return 1
        else return math.pow(2, -10 * t) * math.sin((t * 10 - 0.75) * c4) + 1
        end
    end
    return t
end

---Gets the display name for an easing curve type
---@param curveType number The curve type index
---@return string name Human-readable name
function Helpers.getEasingName(curveType)
    return Config.EASING_NAMES[curveType] or "Unknown"
end

---Gets the list of available easing curve names for UI
---@return table names Array of easing curve names
function Helpers.getEasingItems()
    return Config.EASING_NAMES
end

--------------------------------------------------------------------------------
-- Value Generation
--------------------------------------------------------------------------------

---Generates interpolated values between start and end with easing
---@param startValue number Starting value
---@param endValue number Ending value
---@param steps number Number of values to generate (minimum 2)
---@param curveType number Easing curve type (default: 1=Linear)
---@return table values Array of interpolated values
function Helpers.generateLinearValues(startValue, endValue, steps, curveType)
    local values = {}
    if steps < 2 then steps = 2 end
    
    for i = 0, steps - 1 do
        local t = i / (steps - 1)
        local easedT = Helpers.easingFunction(t, curveType or Config.EASING.LINEAR)
        local value = startValue + (endValue - startValue) * easedT
        table.insert(values, value)
    end
    
    return values
end

---Distributes source values to match target frame count using nearest-neighbor sampling
---@param sourceValues table Array of source values
---@param targetFrameCount number Desired number of output values
---@return table distributed Array of distributed values
function Helpers.distributeValues(sourceValues, targetFrameCount)
    if not sourceValues or #sourceValues == 0 then
        return {}
    end
    
    if #sourceValues == targetFrameCount then
        return sourceValues
    end
    
    -- Guard against edge case
    if targetFrameCount < 1 then
        return {}
    end
    
    if targetFrameCount == 1 then
        return {sourceValues[1]}
    end
    
    local distributed = {}
    local sourceCount = #sourceValues
    
    for i = 1, targetFrameCount do
        local sourcePos = (i - 1) / (targetFrameCount - 1) * (sourceCount - 1)
        local sourceIndex = math.floor(sourcePos) + 1
        sourceIndex = math.max(1, math.min(sourceIndex, sourceCount))
        table.insert(distributed, sourceValues[sourceIndex])
    end
    
    return distributed
end

--------------------------------------------------------------------------------
-- Animation Data Building
--------------------------------------------------------------------------------

---Builds animation data arrays for Octane setAnimator (single channel)
---@param values table Array of float values (channel 0 only)
---@param startFrame number Start frame number
---@param endFrame number End frame number
---@param fps number Frames per second
---@return table timeTable Array of time values in seconds
---@return table valTable Array of value tables {v, 0, 0, 0}
function Helpers.buildAnimationData(values, startFrame, endFrame, fps)
    local timeTable, valTable = {}, {}
    local frameCount = endFrame - startFrame + 1
    local distributedValues = Helpers.distributeValues(values, frameCount)
    
    for i = 1, frameCount do
        local currentFrame = startFrame + (i - 1)
        table.insert(timeTable, currentFrame / fps)
        table.insert(valTable, {distributedValues[i], 0, 0, 0})
    end
    
    return timeTable, valTable
end

---Builds animation data arrays from raw 4-channel values
---@param rawValues table Array of {v1, v2, v3, v4} tables
---@param startFrame number Start frame number
---@param endFrame number End frame number
---@param fps number Frames per second
---@return table timeTable Array of time values in seconds
---@return table valTable Array of value tables {v1, v2, v3, v4}
function Helpers.buildAnimationDataFromRaw(rawValues, startFrame, endFrame, fps)
    local timeTable, valTable = {}, {}
    local frameCount = endFrame - startFrame + 1
    
    -- Guard against edge cases
    if not rawValues or #rawValues == 0 then
        return {}, {}
    end
    
    if frameCount < 1 then
        return {}, {}
    end
    
    -- Distribute raw values (which are {v1, v2, v3, v4} tables)
    local distributedRaw = {}
    local sourceCount = #rawValues
    
    if sourceCount == frameCount then
        distributedRaw = rawValues
    elseif frameCount == 1 then
        distributedRaw[1] = rawValues[1]
    else
        for i = 1, frameCount do
            local sourcePos = (i - 1) / (frameCount - 1) * (sourceCount - 1)
            local sourceIndex = math.floor(sourcePos) + 1
            sourceIndex = math.max(1, math.min(sourceIndex, sourceCount))
            distributedRaw[i] = rawValues[sourceIndex]
        end
    end
    
    for i = 1, frameCount do
        local currentFrame = startFrame + (i - 1)
        table.insert(timeTable, currentFrame / fps)
        
        local raw = distributedRaw[i]
        if type(raw) == "table" then
            table.insert(valTable, {raw[1] or 0, raw[2] or 0, raw[3] or 0, raw[4] or 0})
        else
            table.insert(valTable, {raw or 0, 0, 0, 0})
        end
    end
    
    return timeTable, valTable
end

--------------------------------------------------------------------------------
-- Segment Overlap Detection
--------------------------------------------------------------------------------

---Detects overlapping frame ranges between segments
---@param segments table Array of segment tables with startFrame and endFrame
---@return table overlaps Array of overlap info {seg1, seg2, startFrame, endFrame}
function Helpers.detectOverlaps(segments)
    local overlaps = {}
    
    if not segments or #segments < 2 then
        return overlaps
    end
    
    for i = 1, #segments - 1 do
        for j = i + 1, #segments do
            local seg1, seg2 = segments[i], segments[j]
            
            local overlapStart = math.max(seg1.startFrame, seg2.startFrame)
            local overlapEnd = math.min(seg1.endFrame, seg2.endFrame)
            
            if overlapStart < overlapEnd then
                table.insert(overlaps, {
                    seg1 = i,
                    seg2 = j,
                    startFrame = overlapStart,
                    endFrame = overlapEnd
                })
            end
        end
    end
    
    return overlaps
end

--------------------------------------------------------------------------------
-- Multi-Segment Animation Merging
--------------------------------------------------------------------------------

---Merges multiple segments into a single animation with gap filling
---Gaps between segments hold the last known value (step-and-hold)
---@param segments table Array of segment definitions
---@param fps number Frames per second
---@return table timeTable Array of time values in seconds
---@return table valTable Array of value tables
function Helpers.mergeSegments(segments, fps)
    if not segments or #segments == 0 then
        return {}, {}
    end
    
    -- Sort segments by start frame
    local sortedSegments = {}
    for i, seg in ipairs(segments) do
        sortedSegments[i] = {
            startFrame = seg.startFrame,
            endFrame = seg.endFrame,
            startValue = seg.startValue,
            endValue = seg.endValue,
            easingCurve = seg.easingCurve or Config.EASING.LINEAR
        }
    end
    table.sort(sortedSegments, function(a, b)
        return a.startFrame < b.startFrame
    end)
    
    -- Find overall frame range
    local minFrame = sortedSegments[1].startFrame
    local maxFrame = sortedSegments[1].endFrame
    for _, seg in ipairs(sortedSegments) do
        if seg.endFrame > maxFrame then maxFrame = seg.endFrame end
    end
    
    -- Build per-frame value map
    local frameValues = {}
    
    for _, seg in ipairs(sortedSegments) do
        if seg.endFrame > seg.startFrame then
            local steps = seg.endFrame - seg.startFrame + 1
            local segValues = Helpers.generateLinearValues(
                seg.startValue, seg.endValue, steps, seg.easingCurve
            )
            
            for i = 1, steps do
                local frame = seg.startFrame + (i - 1)
                frameValues[frame] = segValues[i]
            end
        end
    end
    
    -- Fill gaps with last known value (hold)
    local lastKnownValue = sortedSegments[1].startValue
    for frame = minFrame, maxFrame do
        if frameValues[frame] then
            lastKnownValue = frameValues[frame]
        else
            frameValues[frame] = lastKnownValue
        end
    end
    
    -- Build output arrays
    local timeTable, valTable = {}, {}
    for frame = minFrame, maxFrame do
        table.insert(timeTable, frame / fps)
        table.insert(valTable, {frameValues[frame], 0, 0, 0})
    end
    
    return timeTable, valTable
end

---Gets the overall frame range covered by segments
---@param segments table Array of segment definitions
---@return number minFrame Earliest start frame
---@return number maxFrame Latest end frame
function Helpers.getSegmentsFrameRange(segments)
    if not segments or #segments == 0 then
        return 0, 0
    end
    
    local minFrame = segments[1].startFrame
    local maxFrame = segments[1].endFrame
    
    for _, seg in ipairs(segments) do
        if seg.startFrame < minFrame then minFrame = seg.startFrame end
        if seg.endFrame > maxFrame then maxFrame = seg.endFrame end
    end
    
    return minFrame, maxFrame
end

--------------------------------------------------------------------------------
-- Animation Extraction from Octane Nodes
--------------------------------------------------------------------------------

---Extracts animation data from an Octane Float node
---@param node userdata Octane node (must be NT_FLOAT type)
---@return table|nil animData Animation data with times, values, rawValues, period, nodeName
---@return string|nil error Error message if extraction failed
function Helpers.extractAnimation(node)
    if not node or node.type ~= octane.NT_FLOAT then
        return nil, "Invalid node type"
    end
    
    local times, period, values, isArray, numTimes = node:getAnimator(octane.A_VALUE)
    
    if not times or #times == 0 then
        return nil, string.format("Node '%s' has no animation on A_VALUE attribute", node.name)
    end
    
    -- Extract channel 0 values for UI display
    local extractedValues = {}
    -- Keep raw values for JSON export (all 4 channels)
    local rawValues = {}
    
    for i, val in ipairs(values) do
        if type(val) == "table" then
            table.insert(extractedValues, val[1])
            -- Store full 4-component value
            rawValues[i] = {val[1] or 0, val[2] or 0, val[3] or 0, val[4] or 0}
        else
            table.insert(extractedValues, val)
            rawValues[i] = {val, 0, 0, 0}
        end
    end
    
    return {
        times = times,
        values = extractedValues,
        rawValues = rawValues,
        period = period or 0,
        nodeName = node.name,
        numKeyframes = #times,
        isArray = isArray,
        numTimes = numTimes
    }, nil
end

---Converts time array to frame range
---@param times table Array of time values in seconds
---@param fps number Frames per second
---@return number firstFrame First frame number
---@return number lastFrame Last frame number
function Helpers.timesToFrameRange(times, fps)
    if not times or #times == 0 then
        return 0, 0
    end
    
    local firstFrame = math.floor(times[1] * fps + 0.5)
    local lastFrame = math.floor(times[#times] * fps + 0.5)
    
    return firstFrame, lastFrame
end

--------------------------------------------------------------------------------
-- Formatting Utilities
--------------------------------------------------------------------------------

---Formats values array as newline-separated text for editor display
---@param values table Array of float values
---@return string text Formatted text with one value per line
function Helpers.formatValuesForEditor(values)
    if not values then
        return ""
    end
    
    local formatted = {}
    for _, val in ipairs(values) do
        table.insert(formatted, string.format("%.6f", val))
    end
    return table.concat(formatted, "\n")
end

---Formats a duration in seconds as human-readable string
---@param seconds number Duration in seconds
---@return string formatted Human-readable duration (ms, seconds, or mm:ss.ss)
function Helpers.formatDuration(seconds)
    if not seconds then
        return "0 seconds"
    end
    
    if seconds < 1 then
        return string.format("%.2f ms", seconds * 1000)
    elseif seconds < 60 then
        return string.format("%.2f seconds", seconds)
    else
        local minutes = math.floor(seconds / 60)
        local secs = seconds - (minutes * 60)
        return string.format("%d:%05.2f", minutes, secs)
    end
end

---Gets display name for interpolation type
---@param interpType number Interpolation type index
---@return string name Human-readable name
function Helpers.getInterpolationName(interpType)
    return Config.INTERPOLATION_NAMES[interpType] or "Linear"
end

return Helpers

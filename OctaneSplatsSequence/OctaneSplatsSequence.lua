----------------------------------------------------------------------------------------------------
-- Gaussian Splat Sequence Animation
--
-- @description Animates Gaussian Splat sequences with absolute paths
-- @author      Padi Frigg
-- @version     2.0
-- @script-id   OctaneRender gaussian splat animation

----------------------------------------------------------------------------------------------------
-- GUI CONTROLS
----------------------------------------------------------------------------------------------------

local splatLabel = octane.gui.createLabel{ text = "Splat Node:" }
local splatCombo = octane.gui.createComboBox{ items = { "Loading..." }, selectedIx = 1 }
local refreshButton = octane.gui.createButton("Refresh")

local fileLabel = octane.gui.createLabel{ text = "Sequence File:" }
local filePathEditor = octane.gui.createTextEditor{ width = 400, height = 20 }
local fileChooseButton = octane.gui.createButton("Browse...")

local patternLabel = octane.gui.createLabel{ text = "Pattern: (none)" }

local startFrameLabel, startFrameNum = octane.gui.createParameter(nil, "Start Frame", 0, 0, 100000, 1, true)
local endFrameLabel, endFrameNum     = octane.gui.createParameter(nil, "End Frame",  100, 0, 100000, 1, true)

local applyButton = octane.gui.createButton("Apply Animation")
local exitButton  = octane.gui.createButton("Exit")
local statusLabel = octane.gui.createLabel{ text = "Status: Ready" }

-- State
local splatNodesData = {}
local lastBrowsedFolder = nil
local hasSplats = false

----------------------------------------------------------------------------------------------------
-- FUNCTIONS
----------------------------------------------------------------------------------------------------

--- Populate the splat dropdown with available Gaussian Splat nodes.
local function populateSplatNodes()
    local sceneGraph = octane.project.getSceneGraph()
    local splatNodes = sceneGraph:findNodes(481, true) -- NT_GEO_GAUSSIAN_SPLAT = 481

    splatNodesData = {}
    local names = {}

    if #splatNodes == 0 then
        table.insert(names, "No Gaussian Splat nodes found")
        splatCombo.items = names
        splatCombo.selectedIx = 1
        hasSplats = false
        applyButton.enable = false
        return false
    end

    for i, node in ipairs(splatNodes) do
        local nodeName = node.name
        if not nodeName or nodeName == "" then
            nodeName = "Splat " .. i
        end
        table.insert(names, nodeName)
        splatNodesData[i] = node
    end

    splatCombo.items = names
    splatCombo.selectedIx = 1
    hasSplats = true
    applyButton.enable = true
    return true
end

--- Extract directory, prefix, padding width and extension from a sequence file path.
-- Returns: pattern (with %0Nd format), directory, prefix, padding, extension — or nil + error.
local function extractPathPattern(filePath)
    filePath = filePath:gsub("^%s+", ""):gsub("%s+$", ""):gsub("\\", "/")

    local dir = filePath:match("^(.+)/[^/]+$")
    if not dir then return nil, "Invalid path format" end

    local filename = filePath:match("/([^/]+)$")
    if not filename then return nil, "Invalid filename" end

    -- Try .ply then .spz (case-insensitive)
    local prefix, numStr, ext = filename:match("^(.-)(%d+)%.([pP][lL][yY])$")
    if not prefix then
        prefix, numStr, ext = filename:match("^(.-)(%d+)%.([sS][pP][zZ])$")
    end
    if not prefix then
        return nil, "No frame number found in filename (expect ..._0001.ply or ..._0001.spz)"
    end

    local padding = #numStr
    local pattern = dir .. "/" .. prefix .. "%0" .. padding .. "d." .. ext

    return pattern, nil, dir, prefix, padding, ext
end

--- Scan directory for all files matching the sequence pattern.
-- Returns sorted list of frame numbers found on disk.
local function scanSequenceFrames(dir, prefix, padding, ext)
    local ok, files = pcall(octane.file.listDirectory, dir, true, false, true, false)
    if not ok or not files then return {} end

    -- Escape prefix for use in Lua pattern
    local escapedPrefix = prefix:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    local extLower = ext:lower()
    local frames = {}

    for _, fullPath in ipairs(files) do
        -- listDirectory may return full paths — extract the filename
        local fname = octane.file.getFileName(fullPath)
        if fname then
            local fnameLower = fname:lower()
            -- Match: prefix + digits + .ext (case-insensitive via lowered comparison)
            local num = fnameLower:match("^" .. escapedPrefix:lower() .. "(%d+)%." .. extLower .. "$")
            if num then
                table.insert(frames, tonumber(num))
            end
        end
    end

    table.sort(frames)
    return frames
end

--- Update the pattern label and auto-detect frame range after a file is chosen.
local function updatePatternFromPath()
    local filePath = filePathEditor.text
    if not filePath or filePath == "" then
        patternLabel.text = "Pattern: (none)"
        return
    end

    local pattern, err, dir, prefix, padding, ext = extractPathPattern(filePath)
    if not pattern then
        patternLabel.text = "Pattern: " .. err
        return
    end

    patternLabel.text = "Pattern: " .. pattern

    -- Scan disk for matching frames
    statusLabel.text = "Status: Scanning directory..."
    octane.gui.dispatchGuiEvents(10)

    local frames = scanSequenceFrames(dir, prefix, padding, ext)

    if #frames > 0 then
        startFrameNum.value = frames[1]
        endFrameNum.value   = frames[#frames]
        statusLabel.text = string.format("Status: Found %d files (frames %d–%d)", #frames, frames[1], frames[#frames])
    else
        statusLabel.text = "Status: No matching files found in directory"
    end
end

--- Apply animation to the selected splat node.
local function applyAnimation()
    if not hasSplats then
        statusLabel.text = "Status: Error – No splat nodes available"
        return
    end

    local selectedIndex = splatCombo.selectedIx
    if selectedIndex < 1 or selectedIndex > #splatNodesData then
        statusLabel.text = "Status: Error – No valid splat selected"
        return
    end

    local node = splatNodesData[selectedIndex]

    local filePath = filePathEditor.text
    if not filePath or filePath == "" then
        statusLabel.text = "Status: Error – No file path specified"
        return
    end

    local pattern, err = extractPathPattern(filePath)
    if not pattern then
        statusLabel.text = "Status: Error – " .. err
        return
    end

    local startFrame = math.floor(startFrameNum.value)
    local endFrame   = math.floor(endFrameNum.value)

    if endFrame < startFrame then
        statusLabel.text = "Status: Error – End frame must be >= start frame"
        return
    end

    -- Validate first and last frame files exist
    local firstFile = string.format(pattern, startFrame)
    local lastFile  = string.format(pattern, endFrame)

    if not octane.file.exists(firstFile) then
        statusLabel.text = "Status: Error – First frame not found: " .. octane.file.getFileName(firstFile)
        return
    end
    if not octane.file.exists(lastFile) then
        statusLabel.text = "Status: Error – Last frame not found: " .. octane.file.getFileName(lastFile)
        return
    end

    -- Show progress
    local frameCount = endFrame - startFrame + 1
    statusLabel.text = string.format("Status: Building %d keyframes...", frameCount)
    octane.gui.dispatchGuiEvents(10)

    -- Get scene framerate
    local fps = octane.project.getProjectSettings():getAttribute(octane.A_FRAMES_PER_SECOND)

    -- Build keyframe arrays
    local times  = {}
    local values = {}

    for i = startFrame, endFrame do
        table.insert(times,  i / fps)
        table.insert(values, string.format(pattern, i))
    end

    -- Apply animator
    local okAnim, errAnim = pcall(function()
        node:setAnimator(octane.A_FILENAME, times, values, 0, true)
    end)

    if not okAnim then
        statusLabel.text = "Status: Error – setAnimator failed: " .. tostring(errAnim)
        print("setAnimator error: " .. tostring(errAnim))
        return
    end

    statusLabel.text = string.format("Status: Applied %d frames (%.3f–%.3f s) to \"%s\"",
        frameCount, startFrame / fps, endFrame / fps, node.name or "Splat")

    print(string.format("Animation created: %d frames from %.3f to %.3f seconds",
        frameCount, startFrame / fps, endFrame / fps))
    print("Pattern: " .. pattern)
end

--- File browser callback.
local function onFileBrowse(wildcard)
    local startPath = lastBrowsedFolder

    if not startPath or startPath == "" then
        local currentFile = filePathEditor.text
        if currentFile and currentFile ~= "" and octane.file.isAbsolute(currentFile) then
            startPath = octane.file.getParentDirectory(currentFile)
        end
    end

    local ret = octane.gui.showDialog{
        type      = octane.gui.dialogType.FILE_DIALOG,
        title     = "Select Sequence File",
        wildcards = wildcard,
        path      = startPath,
        save      = false,
    }

    if ret.result and ret.result ~= "" then
        filePathEditor.text = ret.result

        if octane.file.isAbsolute(ret.result) then
            lastBrowsedFolder = octane.file.getParentDirectory(ret.result)
        end

        -- Auto-detect pattern + frame range from disk
        updatePatternFromPath()
    end
end

----------------------------------------------------------------------------------------------------
-- GUI LAYOUT
----------------------------------------------------------------------------------------------------

local layout = octane.gridlayout.create()
layout:startSetup()
    local row = 1

    -- Splat selection header
    layout:addSpan(octane.gui.create{
        type = octane.componentType.TITLE_COMPONENT,
        text = "Splat Selection"
    }, 1, row, 2, row)
    row = row + 1

    -- Splat node dropdown + refresh
    layout:add(splatLabel, 1, row)
    layout:startNestedGrid(2, row, 2, row, 0, 0)
        layout:add(splatCombo, 1, 1)
        layout:add(refreshButton, 2, 1)
        layout:setColElasticity(1, 1)
        layout:setColElasticity(2, 0)
        layout:setElasticityForAllRows(0)
    layout:endNestedGrid()
    row = row + 1

    -- Sequence settings header
    layout:addSpan(octane.gui.create{
        type = octane.componentType.TITLE_COMPONENT,
        text = "Sequence Settings"
    }, 1, row, 2, row)
    row = row + 1

    -- File path + browse buttons
    layout:addSpan(fileLabel, 1, row, 2, row)
    row = row + 1

    layout:startNestedGrid(1, row, 2, row, 0, 0)
        layout:add(filePathEditor, 1, 1)
        layout:add(fileChooseButton, 2, 1)
        layout:setColElasticity(1, 1)
        layout:setColElasticity(2, 0)
        layout:setElasticityForAllRows(0)
    layout:endNestedGrid()
    row = row + 1

    -- Detected pattern
    layout:addSpan(patternLabel, 1, row, 2, row)
    row = row + 1

    -- Info note
    layout:addSpan(octane.gui.createLabel{
        text = "Browse for any PLY/SPZ file from the sequence. The script detects the naming pattern and scans for frames."
    }, 1, row, 2, row)
    row = row + 1

    -- Frame range
    layout:add(startFrameLabel, 1, row)
    layout:add(startFrameNum,   2, row)
    row = row + 1

    layout:add(endFrameLabel, 1, row)
    layout:add(endFrameNum,   2, row)
    row = row + 1

    -- Status
    layout:addSpan(statusLabel, 1, row, 2, row)
    row = row + 1

    -- Action buttons
    layout:startNestedGrid(1, row, 2, row, 0, 0)
        layout:addEmpty(1, 1)
        layout:add(applyButton, 2, 1)
        layout:add(exitButton,  3, 1)
        layout:addEmpty(4, 1)
        layout:setElasticityForAllRows(0)
        layout:setColElasticity(2, 0)
        layout:setColElasticity(3, 0)
    layout:endNestedGrid()

    layout:setColElasticity(1, 0)
    layout:setElasticityForAllRows(0)

layout:endSetup()

local window = octane.gui.createWindow{
    text       = "Gaussian Splat Sequence Animation",
    gridLayout = layout,
    width      = layout.width,
    height     = layout.height
}

----------------------------------------------------------------------------------------------------
-- EVENT HANDLERS
----------------------------------------------------------------------------------------------------

local function guiCallback(component, event)
    if component == fileChooseButton then
        onFileBrowse("*.ply;*.spz")
    elseif component == refreshButton then
        if populateSplatNodes() then
            statusLabel.text = string.format("Status: Found %d splat node(s)", #splatNodesData)
        else
            statusLabel.text = "Status: No Gaussian Splat nodes found in scene"
        end
    elseif component == applyButton then
        applyAnimation()
    elseif component == exitButton then
        window:closeWindow()
    end
end

fileChooseButton.callback   = guiCallback
refreshButton.callback       = guiCallback
applyButton.callback         = guiCallback
exitButton.callback          = guiCallback
window.callback              = guiCallback

----------------------------------------------------------------------------------------------------
-- INITIALIZATION
----------------------------------------------------------------------------------------------------

if not populateSplatNodes() then
    statusLabel.text = "Status: No Gaussian Splat nodes found in scene"
end

window:showWindow()


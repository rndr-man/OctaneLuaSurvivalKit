--[[
================================================================================
Octane Assets Per Frame Range Analyzer
================================================================================

DESCRIPTION:
    Analyzes ALL file-based assets in an OctaneRender scene to determine
    which asset files are needed for specific frame ranges. Uses dynamic
    discovery to find any node with A_FILENAME attribute, covering:
    
    - Geometry: VDB volumes, SDF volumes, Gaussian splats
    - Textures: Image textures, image sequences, UDIM tiles
    - Other: LUTs, sky presets, scatter data, local DBs, etc.
    
    Generates a JSON manifest for render farm managers to optimize asset
    distribution across render nodes.

USAGE:
    Command Line (headless):
        octane.exe --no-gui --script "OctaneAssetsPerFrameRangeAnalyzer.lua" \
            <output_directory> <start_frame> <end_frame> <chunk_size> [verbose]

    Arguments:
        output_directory : Path where JSON manifest will be saved
        start_frame      : First frame to analyze (default: 0)
        end_frame        : Last frame to analyze (default: scene end)
        chunk_size       : Frames per render node chunk (default: 1)
        verbose          : "true" for per-frame output (default: false)

    GUI Mode:
        Run in OctaneRender Script Editor without arguments — a dialog will
        prompt for settings.

OUTPUT:
    - Console summary report (verbose mode adds per-frame details)
    - JSON file: <output_directory>/octane_assets_manifest.json

EXIT CODES (CLI):
    0 = Success
    1 = Error (no scene, no nodes found, file write failure, etc.)

@author  Padi Frigg / Claude
@version 4.0
================================================================================
--]]

-- =============================================================================
-- NODE TYPE LABELS (for readable output)
-- =============================================================================

local NODE_TYPE_LABELS = {
    -- Geometry
    [octane.NT_GEO_VOLUME]          = "Volume (VDB)",
    [octane.NT_GEO_VOLUME_SDF]      = "Volume SDF",
    [octane.NT_GEO_MESH_VOLUME_SDF] = "Mesh Volume SDF",
    [octane.NT_GEO_GAUSSIAN_SPLAT]  = "Gaussian Splat",
}

--- Get human-readable label for a node type
local function getNodeTypeLabel(nodeType)
    return NODE_TYPE_LABELS[nodeType] or string.format("Unknown (%d)", nodeType)
end

-- =============================================================================
-- CONFIGURATION
-- =============================================================================

local gSettings = {
    sceneGraph      = nil,
    outputDirectory = nil,
    startFrame      = 0,
    endFrame        = nil,
    chunkSize       = 1,
    fps             = nil,
    deltaTime       = nil,
    verbose         = false,
    isHeadless      = (arg and arg[2] ~= nil),
}

-- =============================================================================
-- UTILITY FUNCTIONS
-- =============================================================================

--- Convert frame number to time in seconds using project FPS
local function frameToTime(frame)
    return frame * gSettings.deltaTime
end

--- Find which value to use at a given time from animator data
local function getValueAtTime(times, values, period, targetTime)
    if not times or #times == 0 or not values or #values == 0 then
        return nil
    end
    
    local startTime = times[1]
    if targetTime < startTime then
        return nil
    end
    
    local frameIndex
    
    if period and period > 0 then
        local timeFromStart = targetTime - startTime
        frameIndex = math.floor(timeFromStart / period + 0.5) + 1
        frameIndex = math.max(1, math.min(frameIndex, #values))
    else
        frameIndex = 1
        for i = #times, 1, -1 do
            if targetTime >= times[i] then
                frameIndex = i
                break
            end
        end
    end
    
    return values[frameIndex]
end

--- Extract unique assets from a list
local function getUniqueAssets(assetList)
    local seen = {}
    local unique = {}
    
    for _, asset in ipairs(assetList) do
        if asset and not seen[asset] then
            seen[asset] = true
            table.insert(unique, asset)
        end
    end
    
    table.sort(unique)
    return unique
end

--- Get project directory (fallback to current dir)
local function getProjectDirectory()
    local projectPath = octane.project.getCurrentProject()
    if projectPath and projectPath ~= "" then
        local dir = projectPath:match("(.+)[/\\][^/\\]+$")
        if dir and octane.file.exists(dir) then
            return dir
        end
    end
    return "."
end

-- =============================================================================
-- DYNAMIC NODE DISCOVERY
-- =============================================================================

--- Recursively collect all nodes from a graph and its sub-graphs
local function collectAllNodes(graph, collected, visited)
    collected = collected or {}
    visited = visited or {}
    
    -- Prevent infinite recursion on circular references
    local graphId = tostring(graph)
    if visited[graphId] then
        return collected
    end
    visited[graphId] = true
    
    local ok, items = pcall(function() return graph:getOwnedItems() end)
    if not ok or not items then
        return collected
    end
    
    for _, item in ipairs(items) do
        table.insert(collected, item)
        -- If item is itself a graph (sub-graph), recurse into it
        local subOk, subItems = pcall(function() return item:getOwnedItems() end)
        if subOk and subItems then
            collectAllNodes(item, collected, visited)
        end
    end
    
    return collected
end

--- Discover all nodes with A_FILENAME attribute
local function discoverFileBasedNodes(sceneGraph)
    local results = {}
    local allNodes = collectAllNodes(sceneGraph)
    
    print(string.format("Scanning %d nodes for A_FILENAME attribute...", #allNodes))
    
    for _, node in ipairs(allNodes) do
        -- Try reading A_FILENAME — not all nodes support it
        local ok, filename = pcall(function()
            return node:getAttribute(octane.A_FILENAME)
        end)
        
        if ok and filename and filename ~= "" then
            local propsOk, props = pcall(function() return node:getProperties() end)
            local nodeType = (propsOk and props) and props.type or -1
            
            table.insert(results, {
                node     = node,
                nodeType = nodeType,
                filename = filename,
            })
        end
    end
    
    return results
end

-- =============================================================================
-- GUI DIALOG (for non-headless mode)
-- =============================================================================

local function showSettingsDialog()
    local projectDir = getProjectDirectory()
    
    -- Get scene time span for default end frame
    local sceneGraph = octane.project.getSceneGraph()
    local projectSettings = octane.project.getProjectSettings()
    local fps = projectSettings:getAttribute(octane.A_FRAMES_PER_SECOND)
    local timeSpan = sceneGraph:getAnimationTimeSpan()
    local defaultEndFrame = math.max(1, math.floor(timeSpan[2] * fps))
    
    -- Create layout
    local layout = octane.gridlayout.create()
    layout:startSetup()
    
    local row = 1
    
    -- Output Directory
    local lblOutputDir = octane.gui.createLabel("Output Directory:")
    local edtOutputDir = octane.gui.create{
        type  = octane.gui.componentType.TEXT_EDITOR,
        text  = projectDir,
        width = 250,
    }
    local btnBrowse = octane.gui.createButton{
        text = "Browse...",
        width = 70,
    }
    layout:add(lblOutputDir, 1, row)
    layout:add(edtOutputDir, 2, row)
    layout:add(btnBrowse, 3, row)
    row = row + 1
    
    -- Start Frame
    local lblStartFrame, sldStartFrame = octane.gui.createParameter(
        nil, "Start Frame", 0, 0, defaultEndFrame, 1, false, 300, 24
    )
    layout:add(lblStartFrame, 1, row)
    layout:add(sldStartFrame, 2, row)
    row = row + 1
    
    -- End Frame
    local lblEndFrame, sldEndFrame = octane.gui.createParameter(
        nil, "End Frame", defaultEndFrame, 0, defaultEndFrame, 1, false, 300, 24
    )
    layout:add(lblEndFrame, 1, row)
    layout:add(sldEndFrame, 2, row)
    row = row + 1
    
    -- Chunk Size
    local lblChunkSize, sldChunkSize = octane.gui.createParameter(
        nil, "Chunk Size", 1, 1, 100, 1, false, 300, 24
    )
    layout:add(lblChunkSize, 1, row)
    layout:add(sldChunkSize, 2, row)
    row = row + 1
    
    -- Verbose checkbox
    local chkVerbose = octane.gui.create{
        type = octane.gui.componentType.CHECK_BOX,
        text = "Verbose output (per-frame details)",
        value = false,
        width = 280,
    }
    layout:add(chkVerbose, 2, row)
    row = row + 1
    
    -- Buttons
    local btnAnalyze = octane.gui.createButton{
        text = "Analyze",
        width = 90,
    }
    local btnCancel = octane.gui.createButton{
        text = "Cancel",
        width = 90,
    }
    layout:add(btnAnalyze, 2, row)
    layout:add(btnCancel, 3, row)
    
    layout:endSetup()
    
    -- Create window
    local dialog = octane.gui.createWindow{
        text   = "Octane Assets Per Frame Range Analyzer",
        width  = 520,
        height = 250,
        gridLayout = layout,
    }
    
    -- Store result
    local dialogResult = nil
    
    -- Set up callbacks
    btnBrowse.callback = function()
        local result = octane.gui.showDialog{
            type  = octane.gui.dialogType.FILE_DIALOG,
            title = "Select Output Directory",
            save  = false,
            selectDirectory = true,
        }
        if result then
            local dir = nil
            if type(result) == "string" then
                dir = result
            elseif type(result) == "table" then
                dir = result[1] or result.path or result.file or result.directory
            end
            if dir and type(dir) == "string" and dir ~= "" then
                edtOutputDir:updateProperties{text = dir}
            end
        end
    end
    
    btnAnalyze.callback = function()
        dialogResult = {
            outputDirectory = edtOutputDir.text,
            startFrame      = math.floor(sldStartFrame.value),
            endFrame        = math.floor(sldEndFrame.value),
            chunkSize       = math.floor(sldChunkSize.value),
            verbose         = chkVerbose.value,
        }
        octane.gui.closeWindow(dialog)
    end
    
    btnCancel.callback = function()
        dialogResult = nil
        octane.gui.closeWindow(dialog)
    end
    
    octane.gui.showWindow(dialog)
    
    return dialogResult
end

-- =============================================================================
-- ASSET NODE ANALYSIS
-- =============================================================================

--- Analyze a single asset node's animation
local function analyzeAssetNode(node, nodeType)
    local nodeInfo = {
        nodeName      = node.name or "Unnamed",
        nodeType      = nodeType,
        nodeTypeLabel = getNodeTypeLabel(nodeType),
        isAnimated    = false,
        keyframeCount = 0,
        assetsByFrame = {},
        uniqueAssets  = {},
    }
    
    -- Check if node is animated
    local animOk, isAnimated = pcall(function()
        return node:isAnimated(octane.A_FILENAME)
    end)
    
    if not animOk or not isAnimated then
        local staticFile = node:getAttribute(octane.A_FILENAME)
        nodeInfo.isAnimated = false
        nodeInfo.uniqueAssets = staticFile and {staticFile} or {}
        print(string.format("  [%s] '%s': Static (file: %s)", 
            nodeInfo.nodeTypeLabel, nodeInfo.nodeName, staticFile or "none"))
        return nodeInfo
    end
    
    -- Get animator data
    local getOk, times, period, values = pcall(function()
        return node:getAnimator(octane.A_FILENAME)
    end)
    
    if not getOk or not times or #times == 0 or not values or #values == 0 then
        print(string.format("  [%s] '%s': Animated but no keyframes found",
            nodeInfo.nodeTypeLabel, nodeInfo.nodeName))
        return nodeInfo
    end
    
    nodeInfo.isAnimated = true
    nodeInfo.keyframeCount = #values
    
    if period and period > 0 then
        local duration = (nodeInfo.keyframeCount - 1) * period
        print(string.format("  [%s] '%s': Period-based (%d values, period=%.6f, duration=%.3fs)",
            nodeInfo.nodeTypeLabel, nodeInfo.nodeName, #values, period, duration))
    else
        print(string.format("  [%s] '%s': Keyframe animation (%d keyframes, %.3fs to %.3fs)",
            nodeInfo.nodeTypeLabel, nodeInfo.nodeName, #times, times[1], times[#times]))
    end
    
    -- Build frame-to-asset mapping
    local allAssets = {}
    for frame = gSettings.startFrame, gSettings.endFrame do
        local frameTime = frameToTime(frame)
        local assetPath = getValueAtTime(times, values, period, frameTime)
        
        if gSettings.verbose then
            print(string.format("    Frame %d (%.6fs) -> %s", frame, frameTime, assetPath or "nil"))
        end
        
        nodeInfo.assetsByFrame[frame] = assetPath
        if assetPath then
            table.insert(allAssets, assetPath)
        end
    end
    
    nodeInfo.uniqueAssets = getUniqueAssets(allAssets)
    print(string.format("    Total unique assets: %d", #nodeInfo.uniqueAssets))
    
    return nodeInfo
end

--- Analyze all discovered asset nodes
local function analyzeAllAssetNodes(discoveredNodes)
    if #discoveredNodes == 0 then
        return nil
    end
    
    print(string.format("\nAnalyzing %d file-based node(s):", #discoveredNodes))
    
    local nodesInfo = {}
    for _, item in ipairs(discoveredNodes) do
        local nodeInfo = analyzeAssetNode(item.node, item.nodeType)
        table.insert(nodesInfo, nodeInfo)
    end
    
    return nodesInfo
end

-- =============================================================================
-- CHUNK GENERATION
-- =============================================================================

local function generateChunks(nodesInfo)
    local chunks = {}
    local chunkId = 1
    
    local frame = gSettings.startFrame
    while frame <= gSettings.endFrame do
        local chunkEndFrame = math.min(frame + gSettings.chunkSize - 1, gSettings.endFrame)
        
        local chunk = {
            chunkId        = chunkId,
            frameRange     = {frame, chunkEndFrame},
            timeRange      = {frameToTime(frame), frameToTime(chunkEndFrame)},
            requiredAssets = {},
            nodeAssets     = {},
        }
        
        local allChunkAssets = {}
        for _, nodeInfo in ipairs(nodesInfo) do
            local nodeAssets = {}
            
            if nodeInfo.isAnimated then
                for f = frame, chunkEndFrame do
                    local asset = nodeInfo.assetsByFrame[f]
                    if asset then
                        table.insert(allChunkAssets, asset)
                        table.insert(nodeAssets, asset)
                    end
                end
            else
                for _, asset in ipairs(nodeInfo.uniqueAssets) do
                    table.insert(allChunkAssets, asset)
                    table.insert(nodeAssets, asset)
                end
            end
            
            if #nodeAssets > 0 then
                chunk.nodeAssets[nodeInfo.nodeName] = getUniqueAssets(nodeAssets)
            end
        end
        
        chunk.requiredAssets = getUniqueAssets(allChunkAssets)
        
        if gSettings.verbose then
            print(string.format("  Chunk %d: Frames %d-%d (%d unique assets)",
                chunkId, frame, chunkEndFrame, #chunk.requiredAssets))
        end
        
        table.insert(chunks, chunk)
        chunkId = chunkId + 1
        frame = chunkEndFrame + 1
    end
    
    return chunks
end

-- =============================================================================
-- JSON OUTPUT
-- =============================================================================

local function generateJSONManifest(nodesInfo, chunks)
    local manifest = {
        project_info = {
            project_file = octane.project.getCurrentProject(),
            fps          = gSettings.fps,
            start_frame  = gSettings.startFrame,
            end_frame    = gSettings.endFrame,
            total_frames = gSettings.endFrame - gSettings.startFrame + 1,
            chunk_size   = gSettings.chunkSize,
            total_chunks = #chunks,
        },
        
        asset_nodes = {},
        chunks      = chunks,
        
        summary = {
            total_nodes         = #nodesInfo,
            animated_nodes      = 0,
            static_nodes        = 0,
            total_unique_assets = 0,
            nodes_by_type       = {},
        }
    }
    
    local allUniqueAssets = {}
    local typeCount = {}
    
    for _, nodeInfo in ipairs(nodesInfo) do
        local nodeData = {
            node_name          = nodeInfo.nodeName,
            node_type          = nodeInfo.nodeTypeLabel,
            node_type_id       = nodeInfo.nodeType,
            is_animated        = nodeInfo.isAnimated,
            unique_asset_count = #nodeInfo.uniqueAssets,
        }
        
        if nodeInfo.isAnimated then
            nodeData.keyframe_count = nodeInfo.keyframeCount
            manifest.summary.animated_nodes = manifest.summary.animated_nodes + 1
        else
            manifest.summary.static_nodes = manifest.summary.static_nodes + 1
        end
        
        table.insert(manifest.asset_nodes, nodeData)
        
        for _, asset in ipairs(nodeInfo.uniqueAssets) do
            table.insert(allUniqueAssets, asset)
        end
        
        typeCount[nodeInfo.nodeTypeLabel] = (typeCount[nodeInfo.nodeTypeLabel] or 0) + 1
    end
    
    manifest.summary.total_unique_assets = #getUniqueAssets(allUniqueAssets)
    manifest.summary.nodes_by_type = typeCount
    
    -- Save JSON
    local outputPath = octane.file.join(gSettings.outputDirectory, "octane_assets_manifest.json")
    local jsonString = octane.json.encode(manifest)
    
    if not octane.file.exists(gSettings.outputDirectory) then
        octane.file.createDirectory(gSettings.outputDirectory)
    end
    
    local file, err = io.open(outputPath, "w")
    if not file then
        print("ERROR: Failed to create JSON file: " .. outputPath)
        print("ERROR: " .. tostring(err))
        return false
    end
    
    file:write(jsonString)
    file:close()
    
    print(string.format("JSON manifest saved to: %s", outputPath))
    return true
end

-- =============================================================================
-- CONSOLE OUTPUT
-- =============================================================================

local function printConsoleReport(nodesInfo, chunks)
    print("\n" .. string.rep("=", 80))
    print("OCTANE ASSETS ANALYSIS REPORT")
    print(string.rep("=", 80))
    
    print(string.format("\nProject: %s", octane.project.getCurrentProject() or "Untitled"))
    print(string.format("FPS: %.2f", gSettings.fps))
    print(string.format("Frame Range: %d - %d (%d total)",
        gSettings.startFrame, gSettings.endFrame,
        gSettings.endFrame - gSettings.startFrame + 1))
    print(string.format("Chunk Size: %d frames", gSettings.chunkSize))
    print(string.format("Total Chunks: %d", #chunks))
    
    -- Group nodes by type for summary
    local byType = {}
    for _, nodeInfo in ipairs(nodesInfo) do
        local label = nodeInfo.nodeTypeLabel
        byType[label] = byType[label] or {}
        table.insert(byType[label], nodeInfo)
    end
    
    print("\n" .. string.rep("-", 80))
    print("ASSET NODES BY TYPE:")
    print(string.rep("-", 80))
    
    local typeLabels = {}
    for label, _ in pairs(byType) do
        table.insert(typeLabels, label)
    end
    table.sort(typeLabels)
    
    for _, label in ipairs(typeLabels) do
        local nodes = byType[label]
        print(string.format("\n%s (%d node%s):", label, #nodes, #nodes > 1 and "s" or ""))
        
        for _, nodeInfo in ipairs(nodes) do
            local status = nodeInfo.isAnimated 
                and string.format("Animated, %d keyframes", nodeInfo.keyframeCount)
                or "Static"
            print(string.format("  %-30s  %s  (%d unique assets)",
                nodeInfo.nodeName, status, #nodeInfo.uniqueAssets))
            
            -- Show sample assets
            if #nodeInfo.uniqueAssets > 0 then
                for i = 1, math.min(2, #nodeInfo.uniqueAssets) do
                    print(string.format("    - %s", nodeInfo.uniqueAssets[i]))
                end
                if #nodeInfo.uniqueAssets > 2 then
                    print(string.format("    ... and %d more", #nodeInfo.uniqueAssets - 2))
                end
            end
        end
    end
    
    print("\n" .. string.rep("-", 80))
    print("RENDER CHUNKS SUMMARY:")
    print(string.rep("-", 80))
    
    -- Show first few and last few chunks
    local maxShow = 5
    local showChunks = {}
    
    if #chunks <= maxShow * 2 then
        showChunks = chunks
    else
        for i = 1, maxShow do
            table.insert(showChunks, chunks[i])
        end
        table.insert(showChunks, "...")
        for i = #chunks - maxShow + 1, #chunks do
            table.insert(showChunks, chunks[i])
        end
    end
    
    for _, chunk in ipairs(showChunks) do
        if chunk == "..." then
            print("  ...")
        else
            print(string.format("  Chunk %3d: Frames %4d - %4d  (%d assets)",
                chunk.chunkId,
                chunk.frameRange[1], chunk.frameRange[2],
                #chunk.requiredAssets))
        end
    end
    
    -- Summary stats
    local totalAnimated = 0
    local totalStatic = 0
    local allAssets = {}
    
    for _, nodeInfo in ipairs(nodesInfo) do
        if nodeInfo.isAnimated then
            totalAnimated = totalAnimated + 1
        else
            totalStatic = totalStatic + 1
        end
        for _, asset in ipairs(nodeInfo.uniqueAssets) do
            table.insert(allAssets, asset)
        end
    end
    
    print("\n" .. string.rep("-", 80))
    print("SUMMARY:")
    print(string.rep("-", 80))
    print(string.format("  Total file-based nodes: %d", #nodesInfo))
    print(string.format("    Animated: %d", totalAnimated))
    print(string.format("    Static:   %d", totalStatic))
    print(string.format("  Total unique assets: %d", #getUniqueAssets(allAssets)))
    print(string.format("  Render chunks: %d", #chunks))
    
    print("\n" .. string.rep("=", 80))
end

-- =============================================================================
-- MAIN EXECUTION
-- =============================================================================

local function main()
    print("Octane Assets Per Frame Range Analyzer v4.0")
    print(string.rep("-", 50))
    
    -- Validate scene
    local sceneGraph = octane.project.getSceneGraph()
    if not sceneGraph then
        print("ERROR: No scene graph found. Is a project loaded?")
        return false
    end
    gSettings.sceneGraph = sceneGraph
    
    -- Get project settings
    local projectSettings = octane.project.getProjectSettings()
    if not projectSettings then
        print("ERROR: Could not get project settings.")
        return false
    end
    
    gSettings.fps = projectSettings:getAttribute(octane.A_FRAMES_PER_SECOND)
    gSettings.deltaTime = 1.0 / gSettings.fps
    
    -- Parse settings from CLI or GUI
    if gSettings.isHeadless then
        gSettings.outputDirectory = arg[2] or getProjectDirectory()
        gSettings.startFrame      = tonumber(arg[3]) or 0
        gSettings.endFrame        = tonumber(arg[4])
        gSettings.chunkSize       = tonumber(arg[5]) or 1
        gSettings.verbose         = (arg[6] == "true")
    else
        local result = showSettingsDialog()
        if not result then
            print("Cancelled by user.")
            return true
        end
        gSettings.outputDirectory = result.outputDirectory
        gSettings.startFrame      = result.startFrame
        gSettings.endFrame        = result.endFrame
        gSettings.chunkSize       = result.chunkSize
        gSettings.verbose         = result.verbose
    end
    
    -- Auto-detect end frame if not specified
    if not gSettings.endFrame then
        local timeSpan = sceneGraph:getAnimationTimeSpan()
        gSettings.endFrame = math.floor(timeSpan[2] * gSettings.fps)
        print(string.format("End frame auto-detected: %d", gSettings.endFrame))
    end
    
    -- Validate
    if gSettings.startFrame < 0 then
        print("ERROR: Start frame cannot be negative")
        return false
    end
    if gSettings.endFrame < gSettings.startFrame then
        print("ERROR: End frame must be >= start frame")
        return false
    end
    if gSettings.chunkSize < 1 then
        print("ERROR: Chunk size must be at least 1")
        return false
    end
    
    print(string.format("Analyzing frames %d - %d (chunk size: %d, verbose: %s)",
        gSettings.startFrame, gSettings.endFrame, gSettings.chunkSize,
        gSettings.verbose and "yes" or "no"))
    
    -- Dynamic discovery of all file-based nodes
    print("\nDiscovering file-based nodes...")
    local discoveredNodes = discoverFileBasedNodes(sceneGraph)
    
    if #discoveredNodes == 0 then
        print("ERROR: No nodes with A_FILENAME attribute found in scene.")
        return false
    end
    
    print(string.format("Found %d node(s) with A_FILENAME attribute.", #discoveredNodes))
    
    -- Analyze nodes
    local nodesInfo = analyzeAllAssetNodes(discoveredNodes)
    
    if not nodesInfo or #nodesInfo == 0 then
        print("ERROR: Failed to analyze asset nodes.")
        return false
    end
    
    -- Generate chunks
    print(string.format("\nGenerating %d-frame chunks...", gSettings.chunkSize))
    local chunks = generateChunks(nodesInfo)
    
    -- Output
    print("\nGenerating outputs...")
    printConsoleReport(nodesInfo, chunks)
    
    local jsonOk = generateJSONManifest(nodesInfo, chunks)
    if not jsonOk then
        return false
    end
    
    print("\nAnalysis complete!")
    return true
end

-- Wrap main in pcall for robust error handling
local ok, result = pcall(main)

if not ok then
    print("\n" .. string.rep("!", 80))
    print("FATAL ERROR:")
    print(tostring(result))
    print(string.rep("!", 80))
    
    if gSettings.isHeadless then
        os.exit(1)
    else
        octane.gui.showDialog{
            type    = octane.gui.dialogType.BUTTON_DIALOG,
            title   = "Error",
            text    = "Script failed:\n\n" .. tostring(result),
            buttons = {"OK"},
        }
    end
elseif result == false then
    if gSettings.isHeadless then
        os.exit(1)
    end
elseif gSettings.isHeadless then
    os.exit(0)
end
-- ============================================================================
-- TOOL:     Octane Render Scene Anvil
-- SUITE:    Padi Survival Kit
-- ============================================================================
-- @description  Combines multiple ORBX scenes and maps materials to USD geometry
-- @author       Padi Frigg (AI Assisted)
-- @version      2.0
-- @script-id    octane-render-scene-anvil
-- ============================================================================
--
-- Use with Octane command line:
-- octane.exe --no-gui --script "OctaneRenderSceneAnvil.lua" -A "C:\temp\saveAsScene.orbx" "C:\temp\destinationScene.orbx" "C:\temp\sourceScene1.orbx" "C:\temp\sourceScene2.orbx::RenderTarget2" "usd=yourTargetName.usd::mat=C:\path\to\sourceScene_mat.orbx::geo=C:\path\to\sourceScene_geo.orbx"
--
-- Arguments:
--   saveAsScene       The path where the combined scene will be saved.
--   destinationScene  The path to the destination scene file. Can contain multiple render targets.
--   sourceScenes      Source scenes with format options:
--                     - Regular scene: "C:\path\to\scene.orbx"
--                     - Scene with specific render target: "C:\path\to\scene.orbx::RenderTarget"
--                     - Scene with frame offset: "C:\path\to\scene.orbx[100]"
--                     - USD material mapping: "usd=targetName.usd::mat=path\to\source_mat.orbx::geo=path\to\source_geo.orbx"
--                     - USD with custom source node: "usd=target.usd::mat=source.orbx::geo=target.orbx::srcnode=custom_name"
--
-- Diagram of operation:
--
--  +----------------+    +----------------+
--  | Source Scene 1 |    | Source Scene 2 |
--  +--------+-------+    +--------+-------+
--           |                     |
--           v                     v
--      +----+-------+      +-----+-------+
--      | Geometry 1 |      | Geometry 2  |
--      +----+-------+      +-----+-------+
--           |                     |
--           |                     |         +------------------+  +------------------+
--           |                     |         | Source Scene 3   |  | Source Scene 3   |
--           |                     |         | (Materials)      |  | (Geometry)       |
--           |                     |         +--------+---------+  +--------+---------+
--           |                     |                  |                     |
--           |                     |                  |  Material Mapping   |
--           |                     |                  +---------+-----------+
--           |                     |                            |
--           |                     |                            v
--           |                     |                   +--------+---------+
--           |                     |                   | Mapped USD Geo   |
--           |                     |                   +--------+---------+
--           |                     |                            |
--           +---------------------+----------------------------+
--                                 |
--                                 v
--                     +-----------+------------+
--                     | Geometry Group Node    |
--                     +-----------+------------+
--                                 |
--                                 v
--            +--------------------+--------------------+
--            |          Destination Scene              |
--            |  +------------+    +------------+       |
--            |  |   Render   |    |   Render   |       |
--            |  | Target 1   |    | Target 2   |  ...  |
--            |  +------------+    +------------+       |
--            +----------------------------------------+
--                                 |
--                                 v
--                     +-----------+------------+
--                     | Combined saveAsScene   |
--                     +------------------------+

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

local Config = {
    -- Default source node name for material extraction (can be overridden via srcnode parameter)
    DEFAULT_SOURCE_NODE_NAME = "geometry.abc",
}

--------------------------------------------------------------------------------
-- Logging
--------------------------------------------------------------------------------

local Log = {}

function Log.debug(msg)
    print("[Debug] " .. tostring(msg))
end

function Log.info(msg)
    print("[Info] " .. tostring(msg))
end

function Log.warn(msg)
    print("[Warning] " .. tostring(msg))
end

function Log.error(msg)
    print("[Error] " .. tostring(msg))
end

function Log.fatal(msg)
    print("[FATAL] " .. tostring(msg))
end

--------------------------------------------------------------------------------
-- Utility Functions
--------------------------------------------------------------------------------

--- Check if a file exists (uses Octane's cross-platform file API)
-- @param filePath string: Path to check
-- @return boolean: true if file exists and is a file (not directory)
local function fileExists(filePath)
    return octane.file.isFile(filePath)
end

--- Check if a directory exists
-- @param dirPath string: Path to check
-- @return boolean: true if directory exists
local function directoryExists(dirPath)
    return octane.file.isDirectory(dirPath)
end

--- Check if we have write access to a path
-- @param filePath string: Path to check
-- @return boolean: true if writable
local function hasWriteAccess(filePath)
    return octane.file.hasWriteAccess(filePath)
end

--- Get parent directory of a path
-- @param filePath string: File path
-- @return string: Parent directory path
local function getParentDirectory(filePath)
    return octane.file.getParentDirectory(filePath)
end

--- Count entries in a table (works for non-sequential tables)
-- @param t table: Table to count
-- @return number: Number of entries
local function tableSize(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

--------------------------------------------------------------------------------
-- Scene Loading
--------------------------------------------------------------------------------

--- Load an ORBX scene file
-- @param filePath string: Path to the scene file
-- @return boolean: true if successful
local function loadScene(filePath)
    if not fileExists(filePath) then
        Log.error("File not found: " .. filePath)
        return false
    end
    
    Log.info("Loading scene: " .. filePath)
    local success, err = pcall(octane.project.load, filePath)
    
    if not success then
        Log.error("Failed to load scene: " .. tostring(err))
        return false
    end
    
    return true
end

--------------------------------------------------------------------------------
-- Argument Parsing
--------------------------------------------------------------------------------

--- Check if required command line arguments are provided
-- @param saveAsScene string: Output path
-- @param destinationScene string: Destination scene path
-- @return boolean: true if valid
local function checkRequiredArguments(saveAsScene, destinationScene)
    if not saveAsScene then
        Log.error("saveAsScene required as an -A script argument.")
        return false
    end
    
    if not destinationScene then
        Log.error("destinationScene required as an -A script argument.")
        return false
    end
    
    -- Validate destination scene exists
    if not fileExists(destinationScene) then
        Log.error("Destination scene not found: " .. destinationScene)
        return false
    end
    
    -- Validate output directory is writable
    local outputDir = getParentDirectory(saveAsScene)
    if outputDir and outputDir ~= "" then
        if not directoryExists(outputDir) then
            Log.error("Output directory does not exist: " .. outputDir)
            return false
        end
        if not hasWriteAccess(outputDir) then
            Log.error("No write access to output directory: " .. outputDir)
            return false
        end
    end
    
    return true
end

--- Parse a source scene argument
-- Supports: regular paths, paths with render target (::), paths with frame offset ([n])
-- @param sourceArg string: Raw argument string
-- @return table: Parsed argument with type and parameters
local function parseSourceArgument(sourceArg)
    -- Check if it's a USD material mapping argument
    if sourceArg:match("^usd=") then
        return { type = "usd-mapping", rawArg = sourceArg }
    end
    
    -- Parse regular scene or scene with render target
    local scenePath, renderTargetName, startFrame
    
    -- First, check for start frame in brackets if present
    local pathAndTarget, frameStr = sourceArg:match("^(.-)%[(%d+)%]$")
    if pathAndTarget then
        startFrame = tonumber(frameStr)
    else
        pathAndTarget = sourceArg
    end
    
    -- Then, check for render target using "::"
    local path, renderTarget = pathAndTarget:match("^(.-)::([^:]+)$")
    if path then
        scenePath = path
        renderTargetName = renderTarget
    else
        scenePath = pathAndTarget
    end
    
    return {
        type = "regular-scene",
        scenePath = scenePath,
        renderTargetName = renderTargetName,
        startFrame = startFrame
    }
end

--- Parse USD material mapping arguments
-- Format: "usd=targetName::mat=path::geo=path[::srcnode=name]"
-- @param rawArg string: Raw argument string
-- @return table|nil: Parsed parameters or nil on error
local function parseUsdMappingArgument(rawArg)
    -- Replace '::' with a character that doesn't appear in paths
    local cmdArg = rawArg:gsub("::", "|")
    local params = {}
    
    -- Split by the pipe character
    for part in cmdArg:gmatch("([^|]+)") do
        local key, value = part:match("^([^=]+)=(.+)$")
        if key and value then
            params[key] = value
        end
    end
    
    -- Validate required parameters
    if not params.usd then
        Log.error("USD target node name not specified (use usd=yourTargetName.usd)")
        return nil
    end
    
    if not params.mat then
        Log.error("Source material ORBX file not specified (use mat=path/to/source.orbx)")
        return nil
    end
    
    if not params.geo then
        Log.error("Target geometry ORBX file not specified (use geo=path/to/target.orbx)")
        return nil
    end
    
    -- Set default source node name if not specified
    if not params.srcnode then
        params.srcnode = Config.DEFAULT_SOURCE_NODE_NAME
    end
    
    return params
end

--------------------------------------------------------------------------------
-- Graph Operations
--------------------------------------------------------------------------------

--- Create a temporary node graph with a geometry group node
-- @return graph, node: The temporary graph and geometry group node
local function createTemporaryGraph()
    local tempGraph = octane.nodegraph.createRootGraph("TempGraph")
    local geoGroupNode = octane.node.create{
        type = octane.NT_GEO_GROUP,
        name = "Geometry group",
        graphOwner = tempGraph,
    }
    return tempGraph, geoGroupNode
end

--- Apply frame offset to a scene's animation timeline
-- @param sceneGraph graph: The scene graph to modify
-- @param startFrame number: The frame offset to apply
-- @return boolean: true if successful
local function applyFrameOffset(sceneGraph, startFrame)
    -- Clear any existing time transform first
    sceneGraph:clearTimeTransform()

    -- Get the project settings and read the FPS
    local projectSettings = octane.project.getProjectSettings()
    local FPS = projectSettings:getAttribute(octane.A_FRAMES_PER_SECOND)
    Log.info("Project frame rate: " .. FPS .. " fps")

    -- Get the current animation time span before modification
    local timeSpan = sceneGraph:getAnimationTimeSpan()
    Log.info("Original animation time span: " .. timeSpan[1] .. " to " .. timeSpan[2] .. " seconds")
    Log.info("Original frame range: " .. math.floor(timeSpan[1] * FPS) .. " to " .. math.ceil(timeSpan[2] * FPS))

    -- Calculate time offset (convert frames to time)
    local timeOffset = startFrame / FPS
    Log.info("Applying time offset of " .. timeOffset .. " seconds")

    -- Apply the linear time transform with the corrected custom interval. This might not be necessary?
    -- local customInterval = {timeSpan[1], timeSpan[2] + timeOffset}
    -- sceneGraph:setLinearTimeTransform(timeOffset, 1.0, customInterval)

    -- Apply the linear time transform
    sceneGraph:setLinearTimeTransform(timeOffset, 1.0)

    -- Force an update to make sure changes take effect
    octane.changemanager.update()

    -- Get the new animation time span and report it
    local newTimeSpan = sceneGraph:getAnimationTimeSpan()
    Log.info("New animation time span: " .. newTimeSpan[1] .. " to " .. newTimeSpan[2] .. " seconds")
    Log.info("New frame range: " .. math.floor(newTimeSpan[1] * FPS) .. " to " .. math.ceil(newTimeSpan[2] * FPS))
    Log.info("Animation timeline offset applied. Frames now start at " .. startFrame)
    
    return true
end

--------------------------------------------------------------------------------
-- Material Operations
--------------------------------------------------------------------------------

--- Get material pins from a source geometry node
-- @param node node: The geometry node to extract materials from
-- @return table: Map of material name to material node
local function getSourceMaterials(node)
    local materialMap = {}
    
    Log.debug("Getting materials from source node: " .. node.name)
    
    -- Geometry archives often have hierarchical structure
    if node.type == octane.GT_GEOMETRYARCHIVE then
        -- Process owned items (internal nodes)
        local childNodes = node:getOwnedItems()
        
        for _, childNode in ipairs(childNodes) do
            local pinCount = childNode:getPinCount()
            
            -- Check each pin on the child node
            for pinIx = 1, pinCount do
                local pinInfo = childNode:getPinInfoIx(pinIx)
                
                -- Check if the pin is a material pin
                if pinInfo.type == octane.PT_MATERIAL then
                    local connectedMaterial = childNode:getConnectedNodeIx(pinIx)
                    
                    if connectedMaterial then
                        if not (connectedMaterial.type == octane.NT_IN_MATERIAL) then
                            Log.debug("Found pin: " .. pinInfo.name .. " connected to: " .. connectedMaterial.name)
                            materialMap[connectedMaterial.name] = connectedMaterial
                        end
                    end
                end
            end
        end
    end
    
    Log.debug("Found " .. tableSize(materialMap) .. " materials in source node")
    
    return materialMap
end

--- Apply materials from source to target node by matching names
-- @param targetNode node: The target geometry node
-- @param sourceMaterials table: Map of material name to material node
-- @return number: Count of materials applied
local function applyMaterialsToTarget(targetNode, sourceMaterials)
    Log.debug("Applying materials to target node: " .. targetNode.name)
    local materialsApplied = 0
    
    -- Process each child node in the target geometry
    local childNodes = targetNode:getOwnedItems()
    for _, childNode in ipairs(childNodes) do
        if childNode.type == octane.NT_IN_MATERIAL then
            local owner = childNode.name

            -- Extract the base name without path for matching
            local baseName = owner
            local slashPos = baseName:find("/[^/]*$")
            if slashPos then
                baseName = baseName:sub(slashPos + 1)
            end
            
            for matName, sourceMaterial in pairs(sourceMaterials) do
                -- Check if material names match (ignoring case)
                if string.lower(baseName) == string.lower(matName) then
                    childNode:connectToIx(1, sourceMaterial)
                    materialsApplied = materialsApplied + 1
                    Log.debug("Applied material to pin: " .. baseName)
                    break
                end
            end
        end
    end
    
    Log.debug("Applied " .. materialsApplied .. " materials to target")
    return materialsApplied
end

--- Find a node in the scene graph by name
-- @param nodeName string: Name to search for
-- @return node|nil: The found node or nil
local function findNodeByName(nodeName)
    local sceneGraph = octane.project.getSceneGraph()
    local nodes = sceneGraph:findItemsByName(nodeName)
    
    if #nodes == 0 then
        Log.error("Node '" .. nodeName .. "' not found!")
        return nil
    end
    
    return nodes[1]
end

--------------------------------------------------------------------------------
-- Source Processing Functions
--------------------------------------------------------------------------------

--- Process a regular ORBX scene and extract its geometry
-- @param sourceArg table: Parsed source argument
-- @param geoGroupNode node: The geometry group to add to
-- @return node|nil: The copied geometry node or nil on failure
local function processRegularScene(sourceArg, geoGroupNode)
    local sourceScene = sourceArg.scenePath
    local userSelectedRenderTarget = sourceArg.renderTargetName
    
    Log.info("Opening source scene: " .. sourceScene)
    if not loadScene(sourceScene) then
        return nil
    end
    
    local sourceGraph = octane.project.getSceneGraph()
    
    -- Apply frame offset if specified
    if sourceArg.startFrame then
        Log.info("Start frame defined: " .. sourceArg.startFrame)
        applyFrameOffset(sourceGraph, sourceArg.startFrame)
    end
    
    -- Find all render targets in the source scene
    local sourceRenderTargets = sourceGraph:findNodes(octane.NT_RENDERTARGET)
    local selectedRenderTarget = nil
    
    -- If a render target name was specified, find it
    if userSelectedRenderTarget then
        for _, rt in ipairs(sourceRenderTargets) do
            if rt.name == userSelectedRenderTarget then
                selectedRenderTarget = rt
                break
            end
        end
        if not selectedRenderTarget then
            Log.warn("Render target '" .. userSelectedRenderTarget .. "' not found in '" .. sourceScene .. "'. Using first available render target.")
        end
    end
    
    -- Default to the first render target if no selection was made or found
    if not selectedRenderTarget then
        selectedRenderTarget = sourceGraph:findFirstNode(octane.NT_RENDERTARGET)
    end
    
    -- Ensure a valid render target was found
    if not selectedRenderTarget then
        Log.error("No render target found in source scene '" .. sourceScene .. "'. Skipping.")
        return nil
    end
    
    -- Extract the geometry connected to the selected render target
    local sourceGeometry = selectedRenderTarget:getConnectedNode(octane.P_MESH)
    
    if not sourceGeometry then
        Log.error("No geometry found in render target of '" .. sourceScene .. "'. Skipping.")
        return nil
    end
    
    -- Copy the geometry into the temporary graph
    local sourceGeometryCopy = geoGroupNode.graphOwner:copyFromGraph(sourceGraph, {sourceGeometry})[1]
    
    return sourceGeometryCopy
end

--- Process a USD material mapping operation
-- @param usdParams table: Parsed USD parameters
-- @return node|nil: The mapped geometry node or nil on failure
local function processUsdMapping(usdParams)
    local targetNodeName = usdParams.usd
    local sourceOrbxFile = usdParams.mat
    local targetOrbxFile = usdParams.geo
    local sourceNodeName = usdParams.srcnode
    
    Log.debug("Processing USD Material Mapping:")
    Log.debug("  Target USD Node: " .. targetNodeName)
    Log.debug("  Source ORBX: " .. sourceOrbxFile)
    Log.debug("  Target ORBX: " .. targetOrbxFile)
    Log.debug("  Source Node Name: " .. sourceNodeName)
    
    -- Step 1: Load the target ORBX file to find and copy the USD node
    if not loadScene(targetOrbxFile) then
        return nil
    end
    
    -- Find the USD node by name in the target file
    local targetUsdNode = findNodeByName(targetNodeName)
    if not targetUsdNode then
        return nil
    end
    
    -- Create a temporary copy of the USD node
    local tempGraph = octane.nodegraph.createRootGraph("TempUsdGraph")
    local targetUsdNodeCopy = tempGraph:copyItemTree(targetUsdNode)
    
    -- Step 2: Load the material source ORBX file
    if not loadScene(sourceOrbxFile) then
        tempGraph:destroy()
        return nil
    end
    
    -- Find the source node with materials
    local sourceNode = findNodeByName(sourceNodeName)
    if not sourceNode then
        tempGraph:destroy()
        return nil
    end
    
    -- Get the scene graph of the material file
    local sceneGraph = octane.project.getSceneGraph()
    
    -- Step 3: Import the copy of the USD node into the material scene
    local importedUsdNode = sceneGraph:copyItemTree(targetUsdNodeCopy)
    Log.debug("Imported USD node: " .. importedUsdNode.name)
    
    -- Step 4: Get materials from source node
    local sourceMaterials = getSourceMaterials(sourceNode)
    
    -- Step 5: Apply materials to the imported USD node
    local materialsApplied = applyMaterialsToTarget(importedUsdNode, sourceMaterials)
    
    -- Cleanup temporary graph
    tempGraph:destroy()
    
    if materialsApplied > 0 then
        Log.info("Successfully mapped " .. materialsApplied .. " materials to USD node")
        return importedUsdNode
    else
        Log.error("No materials were applied. Check if material pin names match.")
        return nil
    end
end

--- Process a USD mapping argument and return geometry for the group
-- @param sourceArg table: Parsed source argument with rawArg
-- @param geoGroupNode node: The geometry group node
-- @return node|nil: The geometry node or nil on failure
local function processUsdMappingArg(sourceArg, geoGroupNode)
    local usdParams = parseUsdMappingArgument(sourceArg.rawArg)
    if not usdParams then
        return nil
    end
    
    local mappedUsdNode = processUsdMapping(usdParams)
    if not mappedUsdNode then
        return nil
    end
    
    -- Copy the USD node with mapped materials into the temporary graph
    local mappedUsdNodeCopy = geoGroupNode.graphOwner:copyItemTree(mappedUsdNode)
    local sourceGeometryCopy = mappedUsdNodeCopy:findFirstOutputNode(octane.PT_GEOMETRY)
    
    return sourceGeometryCopy
end

--------------------------------------------------------------------------------
-- Main Processing
--------------------------------------------------------------------------------

--- Process all source scenes and combine their geometries
-- @param sourceArguments table: Array of parsed source arguments
-- @param geoGroupNode node: The geometry group to add to
-- @return boolean: true if at least one source was processed
local function processSourceScenes(sourceArguments, geoGroupNode)
    local pinIndex = 1
    
    for _, sourceArg in ipairs(sourceArguments) do
        local geometry = nil
        
        if sourceArg.type == "regular-scene" then
            geometry = processRegularScene(sourceArg, geoGroupNode)
        elseif sourceArg.type == "usd-mapping" then
            geometry = processUsdMappingArg(sourceArg, geoGroupNode)
        end
        
        if geometry then
            geoGroupNode:setAttribute(octane.A_PIN_COUNT, pinIndex, true)
            geoGroupNode:connectToIx(pinIndex, geometry)
            octane.changemanager.update()
            pinIndex = pinIndex + 1
        end
    end
    
    -- Clean up the geometry group
    geoGroupNode:deleteUnconnectedItems()
    
    return pinIndex > 1
end

--- Combine processed source scenes with the destination scene
-- @param destinationScene string: Path to destination scene
-- @param geoGroupNode node: The geometry group with combined sources
-- @return boolean: true if successful
local function combineScenes(destinationScene, geoGroupNode)
    Log.info("Opening destination scene: " .. destinationScene)
    if not loadScene(destinationScene) then
        return false
    end
    
    local destinationGraph = octane.project.getSceneGraph()
    
    -- Find all render targets in the destination scene
    local destinationRenderTargets = destinationGraph:findNodes(octane.NT_RENDERTARGET)
    
    if #destinationRenderTargets == 0 then
        Log.error("No render target found in the destination scene.")
        return false
    end
    
    -- Copy the geometry group node into the destination scene (only once)
    local destinationGeoGroupNode = destinationGraph:copyFromGraph(geoGroupNode.graphOwner, {geoGroupNode})[1]
    
    -- Table to track already processed geometries (avoid redundant group creation)
    local processedGeometryGroups = {}
    
    -- Iterate through each render target
    for _, renderTarget in ipairs(destinationRenderTargets) do
        -- Get the existing geometry connected to this render target
        local existingGeometry = renderTarget:getConnectedNode(octane.P_MESH)
        
        if not existingGeometry then
            -- No existing geometry → Directly connect destinationGeoGroupNode
            Log.info("Render Target '" .. renderTarget.name .. "' has no existing geometry. Connecting directly.")
            renderTarget:connectTo(octane.P_MESH, destinationGeoGroupNode)
            octane.changemanager.update()
        else
            Log.info("Render Target '" .. renderTarget.name .. "' has existing geometry: " .. existingGeometry.name)
            
            -- Check if this existing geometry was already processed
            local combinedGeoGroup = processedGeometryGroups[existingGeometry]
            
            if not combinedGeoGroup then
                -- If not processed, create a new geometry group
                combinedGeoGroup = octane.node.create{
                    type = octane.NT_GEO_GROUP,
                    name = "Combined Geometry Group",
                    graphOwner = destinationGraph,
                }
                
                -- Set pin count and connect geometries
                combinedGeoGroup:setAttribute(octane.A_PIN_COUNT, 2, true)
                combinedGeoGroup:connectToIx(1, destinationGeoGroupNode)
                combinedGeoGroup:connectToIx(2, existingGeometry)
                octane.changemanager.update()
                
                -- Store this group for future identical geometries
                processedGeometryGroups[existingGeometry] = combinedGeoGroup
            end
            
            -- Connect the render target to the already processed or newly created group
            renderTarget:connectTo(octane.P_MESH, combinedGeoGroup)
            octane.changemanager.update()
        end
    end
    
    return true
end

--- Clean up the scene graph and save the combined scene
-- @param saveAsScene string: Output path
local function cleanUpAndSave(saveAsScene)
    local sceneGraph = octane.project.getSceneGraph()
    
    -- Unfold to clean up the scene
    sceneGraph:unfold()
    
    Log.info("Saving combined scene as " .. saveAsScene)
    octane.project.saveAs(saveAsScene)
end

--------------------------------------------------------------------------------
-- Main Entry Point
--------------------------------------------------------------------------------

local function main()
    -- Retrieve the command line arguments
    local saveAsScene = arg[1]
    local destinationScene = arg[2]
    local sourceArgs = {table.unpack(arg, 3)}
    
    -- Check if the required arguments are provided
    if not checkRequiredArguments(saveAsScene, destinationScene) then
        return false
    end
    
    -- Check if at least one source scene is provided
    if #sourceArgs == 0 then
        Log.error("At least one source scene required as an -A script argument.")
        return false
    end
    
    -- Parse source arguments
    local sourceArguments = {}
    for _, rawArg in ipairs(sourceArgs) do
        table.insert(sourceArguments, parseSourceArgument(rawArg))
    end
    
    -- Create a temporary node graph and a geometry group node
    local tempGraph, geoGroupNode = createTemporaryGraph()
    
    -- Process each source and combine their geometries
    local sourcesProcessed = processSourceScenes(sourceArguments, geoGroupNode)
    
    if not sourcesProcessed then
        Log.error("Failed to process any source scenes. Nothing to combine.")
        tempGraph:destroy()
        return false
    end
    
    -- Combine the processed sources with the destination scene
    if not combineScenes(destinationScene, geoGroupNode) then
        Log.error("Failed to combine scenes.")
        tempGraph:destroy()
        return false
    end
    
    -- Clean up temporary graph
    tempGraph:destroy()
    
    -- Clean up the scene graph and save the combined scene
    cleanUpAndSave(saveAsScene)
    
    Log.info("OctaneRenderSceneAnvil completed successfully")
    return true
end

--------------------------------------------------------------------------------
-- Execute with Error Handling
--------------------------------------------------------------------------------

local status, result = pcall(main)
if not status then
    Log.fatal(tostring(result))
    os.exit(1)
elseif result == false then
    -- main() returned false indicating a handled error
    os.exit(1)
end

os.exit(0)
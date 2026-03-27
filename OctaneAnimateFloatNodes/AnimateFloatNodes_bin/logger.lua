--[[
================================================================================
Logger Module - Centralized Logging with Log Levels
================================================================================

@description    Provides centralized logging functionality for the Animate Float
                Nodes tool. Supports multiple log levels (DEBUG, INFO, WARN, ERROR)
                with configurable verbosity and consistent formatting.

@author         Padi Frigg (AI assisted)
@version        7.12

--------------------------------------------------------------------------------
USAGE
--------------------------------------------------------------------------------

    -- Import the logger
    local Log = Logger

    -- Log at different levels
    Log.debug("Detailed debug info: %s", someValue)
    Log.info("Operation completed")
    Log.warn("Potential issue detected")
    Log.error("Something went wrong: %s", errorMsg)

    -- Change log level at runtime
    Logger.setLevel(Logger.LEVEL.DEBUG)  -- Show all messages
    Logger.setLevel(Logger.LEVEL.WARN)   -- Only warnings and errors

--------------------------------------------------------------------------------
LOG LEVELS
--------------------------------------------------------------------------------

    DEBUG (1) - Detailed diagnostic information for debugging
    INFO  (2) - General operational messages (default)
    WARN  (3) - Warning conditions that should be reviewed
    ERROR (4) - Error conditions that need attention

================================================================================
--]]

--------------------------------------------------------------------------------
-- Module Declaration
--------------------------------------------------------------------------------

---@class Logger
---Centralized logging module with configurable log levels
Logger = {}

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

---Log level definitions
---@enum LogLevel
Logger.LEVEL = {
    DEBUG = 1,
    INFO  = 2,
    WARN  = 3,
    ERROR = 4
}

---Log level display names
local LEVEL_NAMES = {
    [1] = "DEBUG",
    [2] = "INFO",
    [3] = "WARN",
    [4] = "ERROR"
}

---Prefix for all log messages
local LOG_PREFIX = "[AnimateFloat]"

---Current log level (messages below this level are suppressed)
local currentLevel = Logger.LEVEL.INFO

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

---Sets the minimum log level to display
---@param level number Log level from Logger.LEVEL
function Logger.setLevel(level)
    if level >= Logger.LEVEL.DEBUG and level <= Logger.LEVEL.ERROR then
        currentLevel = level
    end
end

---Gets the current log level
---@return number level Current log level
function Logger.getLevel()
    return currentLevel
end

---Checks if a log level is enabled
---@param level number Log level to check
---@return boolean enabled True if messages at this level will be shown
function Logger.isEnabled(level)
    return level >= currentLevel
end

--------------------------------------------------------------------------------
-- Core Logging Function
--------------------------------------------------------------------------------

---Logs a message at the specified level
---@param level number Log level
---@param message string Message format string
---@param ... any Format arguments
local function log(level, message, ...)
    if level < currentLevel then
        return
    end
    
    local levelName = LEVEL_NAMES[level] or "UNKNOWN"
    local formattedMessage = message
    
    -- Apply string formatting if arguments provided
    if select("#", ...) > 0 then
        local success, result = pcall(string.format, message, ...)
        if success then
            formattedMessage = result
        end
    end
    
    -- Output format: [AnimateFloat] LEVEL: message
    print(string.format("%s %s: %s", LOG_PREFIX, levelName, formattedMessage))
end

--------------------------------------------------------------------------------
-- Public Logging Methods
--------------------------------------------------------------------------------

---Logs a debug message (detailed diagnostic information)
---@param message string Message format string
---@param ... any Format arguments
function Logger.debug(message, ...)
    log(Logger.LEVEL.DEBUG, message, ...)
end

---Logs an info message (general operational information)
---@param message string Message format string
---@param ... any Format arguments
function Logger.info(message, ...)
    log(Logger.LEVEL.INFO, message, ...)
end

---Logs a warning message (potential issues)
---@param message string Message format string
---@param ... any Format arguments
function Logger.warn(message, ...)
    log(Logger.LEVEL.WARN, message, ...)
end

---Logs an error message (error conditions)
---@param message string Message format string
---@param ... any Format arguments
function Logger.error(message, ...)
    log(Logger.LEVEL.ERROR, message, ...)
end

--------------------------------------------------------------------------------
-- Utility Methods
--------------------------------------------------------------------------------

---Logs a table's contents at debug level (useful for debugging)
---@param name string Name/description of the table
---@param tbl table Table to dump
---@param maxDepth number|nil Maximum depth to traverse (default: 2)
function Logger.debugTable(name, tbl, maxDepth)
    if not Logger.isEnabled(Logger.LEVEL.DEBUG) then
        return
    end
    
    maxDepth = maxDepth or 2
    
    local function dump(t, depth, indent)
        if depth > maxDepth then
            return "..."
        end
        
        if type(t) ~= "table" then
            return tostring(t)
        end
        
        local parts = {}
        for k, v in pairs(t) do
            local key = tostring(k)
            local value
            if type(v) == "table" then
                value = dump(v, depth + 1, indent .. "  ")
            else
                value = tostring(v)
            end
            table.insert(parts, indent .. "  " .. key .. " = " .. value)
        end
        
        if #parts == 0 then
            return "{}"
        end
        
        return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
    end
    
    Logger.debug("%s = %s", name, dump(tbl, 1, ""))
end

return Logger

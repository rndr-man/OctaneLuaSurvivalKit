--[[
================================================================================
Dialog Module - Standardized Dialog Functions
================================================================================

@description    Provides consistent dialog functions for user feedback.
                Centralizes all dialog creation for uniform UX and easy
                maintenance.

@author         Padi Frigg (AI assisted)
@version        7.12

@dependencies   config.lua, logger.lua must be loaded first

--------------------------------------------------------------------------------
USAGE
--------------------------------------------------------------------------------

    Dialog.info("Operation completed", "2 nodes updated")
    Dialog.warn("Large frame range may be slow")
    Dialog.error("Could not parse values", errorDetails)
    
    if Dialog.confirm("Apply animation to 5 nodes?") then
        -- proceed
    end

================================================================================
--]]

--------------------------------------------------------------------------------
-- Module Declaration
--------------------------------------------------------------------------------

---@class Dialog
---Standardized dialog functions
Dialog = {}

--------------------------------------------------------------------------------
-- Information Dialog
--------------------------------------------------------------------------------

---Shows an informational message
---@param title string Dialog title
---@param message string|nil Optional detailed message
function Dialog.info(title, message)
    local text = message or title
    local dialogTitle = message and title or "Information"
    
    octane.gui.showDialog{
        type = octane.gui.dialogType.BUTTON_DIALOG,
        title = dialogTitle,
        text = text,
        buttons = {"OK"}
    }
end

--------------------------------------------------------------------------------
-- Warning Dialog
--------------------------------------------------------------------------------

---Shows a warning message
---@param title string Dialog title
---@param message string|nil Optional detailed message
function Dialog.warn(title, message)
    local text = message or title
    local dialogTitle = message and title or "Warning"
    
    Logger.warn("%s: %s", dialogTitle, text)
    
    octane.gui.showDialog{
        type = octane.gui.dialogType.BUTTON_DIALOG,
        title = dialogTitle,
        text = text,
        buttons = {"OK"}
    }
end

--------------------------------------------------------------------------------
-- Error Dialog
--------------------------------------------------------------------------------

---Shows an error message (non-fatal)
---@param title string Dialog title
---@param message string|nil Optional detailed message
function Dialog.error(title, message)
    local text = message or title
    local dialogTitle = message and title or "Error"
    
    Logger.error("%s: %s", dialogTitle, text)
    
    octane.gui.showDialog{
        type = octane.gui.dialogType.BUTTON_DIALOG,
        title = dialogTitle,
        text = text,
        buttons = {"OK"}
    }
end

--------------------------------------------------------------------------------
-- Confirmation Dialog
--------------------------------------------------------------------------------

---Shows a Yes/No confirmation dialog
---@param message string Question to ask
---@param title string|nil Optional dialog title (default: "Confirm")
---@return boolean confirmed True if user clicked Yes
function Dialog.confirm(message, title)
    local result = octane.gui.showDialog{
        type = octane.gui.dialogType.BUTTON_DIALOG,
        title = title or "Confirm",
        text = message,
        buttons = {"Yes", "No"}
    }
    
    return result.result == 1
end

--------------------------------------------------------------------------------
-- Validation Error Dialog
--------------------------------------------------------------------------------

---Shows a validation error with consistent formatting
---@param errors string|table Single error message or array of errors
function Dialog.validationError(errors)
    local text
    
    if type(errors) == "table" then
        text = "Please fix the following:\n\n• " .. table.concat(errors, "\n• ")
    else
        text = errors
    end
    
    octane.gui.showDialog{
        type = octane.gui.dialogType.BUTTON_DIALOG,
        title = Config.STRINGS.DIALOGS.VALIDATION_ERROR,
        text = text,
        buttons = {"OK"}
    }
end

--------------------------------------------------------------------------------
-- Success Dialog
--------------------------------------------------------------------------------

---Shows a success message with optional details
---@param message string Success message
---@param details string|nil Optional details
function Dialog.success(message, details)
    local text = message
    if details then
        text = message .. "\n\n" .. details
    end
    
    octane.gui.showDialog{
        type = octane.gui.dialogType.BUTTON_DIALOG,
        title = Config.STRINGS.DIALOGS.SUCCESS,
        text = text,
        buttons = {"OK"}
    }
end

--------------------------------------------------------------------------------
-- No Selection Dialog
--------------------------------------------------------------------------------

---Shows the standard "no nodes selected" message
function Dialog.noSelection()
    octane.gui.showDialog{
        type = octane.gui.dialogType.BUTTON_DIALOG,
        title = Config.STRINGS.DIALOGS.NO_NODES,
        text = "Please select at least one Float Value node (NT_FLOAT) before running this script.\n\n" ..
               "Float nodes can be found in the Node Editor under:\n" ..
               "Basic → Float Value",
        buttons = {"OK"}
    }
end

return Dialog

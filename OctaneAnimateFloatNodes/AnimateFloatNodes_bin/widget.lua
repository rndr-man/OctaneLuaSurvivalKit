--[[
================================================================================
Widget - GUI Component Factory
================================================================================

@description    Abstraction layer for creating Octane GUI components.
                Provides a fluent interface for building UI elements with
                sensible defaults and automatic label creation.

@author         Original author (from Ol' Ready Cam project)
@version        1.0
@license        MIT

--------------------------------------------------------------------------------
OVERVIEW
--------------------------------------------------------------------------------

The widget class is used for creating gui components and appending additional
elements to existing components. There are default values built in for
each type of component so options only need to be passed when a different
value is desired. There are three calls which can be made for widgets:

    1. create()   - Instantiates a base object for holding multiple components
    2. new()      - Instantiates a component
    3. append()   - Appends a component to an existing component

--------------------------------------------------------------------------------
EXAMPLES
--------------------------------------------------------------------------------

Self-contained slider with editor:

    startFrame = widget:new('slider') {{"Start"}}
    startFrame:append('editor') {text="", width=320}

    -- References:
    --   label      = startFrame.label.text
    --   max        = startFrame.slider.maxValue
    --   editorText = startFrame.editor.text

Base widget with multiple components:

    animate           = widget:create()
    animate.samples   = animate:new('slider') {{"Samples/px"}, log=true}
    animate.path      = animate:new('button') {"Input file"}
    animate.path:append('editor') {text = ""}
    animate:append('group') { children, border=true }

    -- References:
    --   animate.samples.label.text
    --   animate.samples.slider.value
    --   animate.path.button.text
    --   animate.path.editor.text
    --   animate.group

Alternative new() syntax:

    animate.samples = animate:new('slider') {{"Samples/px"}, log=true}
    -- OR
    animate:new('slider','samples') {{"Samples/px"}, log=true}

--------------------------------------------------------------------------------
COMPONENT TYPES
--------------------------------------------------------------------------------

new('label' ) {" ",...}              Opt: width, height, x, y
new('button') {buttonText,...}       Opt: width, height, x, y, tooltip
new('slider') {label={" ",...}, ...} Opt: value, min, max, step, log, width, height, x, y
new('numeric'){label={" ",...}, ...} Opt: value, min, max, step, log, width, height, x, y
new('check')  {label={" ",...},...}  Opt: text, width, height, checked, x, y
new('combo')  {label={" ",...},items={,,,,} ...}  Opt: width, height, x, y
new('editor') {...}                  Opt: text, width, height, x, y, enable

--------------------------------------------------------------------------------
GROUPS
--------------------------------------------------------------------------------

For screen groups, the children objects are built in row and column order.
The number of items within each row of a given group must match.

Example of 3 row, 2 column screen group:

    children = {
        { animate.startFrame.label, animate.startFrame.slider },
        { animate.endFrame.label,   animate.endFrame.slider },
        { animate.step.label,       animate.step.slider }
    }
    animate:append('group'){ children, text="Frame Range", border=true}

Group options: text, border, padding, inset, center, x, y, debug

================================================================================
--]]

--------------------------------------------------------------------------------
-- Component Methods
--------------------------------------------------------------------------------

---@class WidgetMethods
---Collection of factory methods for creating GUI components
local methods = {
    
    ---Creates a label component
    ---@param self table The widget instance
    ---@param argv table Arguments: {text, width=100, height=24, x=0, y=0}
    ---@return table self The widget instance for chaining
    label = function(self, argv)
        if type(argv[1]) == "table" then
            argv = argv[1]
        end
        
        local text = ""
        if type(argv[1]) == "string" then
            text = argv[1]
        else
            argv = {}
        end
        
        self.label = octane.gui.create{
            type   = octane.gui.componentType.LABEL,
            text   = text,
            width  = argv.width or 100,
            height = argv.height or 24,
            x      = argv.x or 0,
            y      = argv.y or 0
        }
        return self
    end,

    ---Creates a button component
    ---@param self table The widget instance
    ---@param argv table Arguments: {text, width=80, height=30, tooltip="", x=0, y=0}
    ---@return table self The widget instance for chaining
    button = function(self, argv)
        local text = ""
        if type(argv[1]) == "string" then
            text = argv[1]
        end
        
        if argv.tooltip ~= nil then
            if widget.hideToolTips then
                argv.tooltip = nil
            end
        end
        
        self.button = octane.gui.create{
            type    = octane.gui.componentType.BUTTON,
            text    = argv.text or text or "",
            width   = argv.width or 80,
            height  = argv.height or 30,
            tooltip = argv.tooltip or "",
            x       = argv.x or 0,
            y       = argv.y or 0
        }
        return self
    end,

    ---Creates a slider component with optional label
    ---@param self table The widget instance
    ---@param argv table Arguments: {label={}, value=1, min=1, max=3, step=1, log=false, width=400, height=24}
    ---@return table self The widget instance for chaining
    slider = function(self, argv)
        self.slider = octane.gui.create{
            type        = octane.gui.componentType.SLIDER,
            value       = argv.value or 1,
            minValue    = argv.min or 1,
            maxValue    = argv.max or 3,
            step        = argv.step or 1,
            logarithmic = argv.log or false,
            width       = argv.width or 400,
            height      = argv.height or 24,
            x           = argv.x or 0,
            y           = argv.y or 0
        }
        
        -- Auto-create label if specified
        if argv.label then
            self:append('label'){argv.label}
        elseif type(argv[1]) == "table" then
            self:append('label')(argv)
        end
        return self
    end,

    ---Creates a numeric input box with optional label
    ---@param self table The widget instance
    ---@param argv table Arguments: {label={}, value=0, min=0, max=256000, step=100, width=100, height=24}
    ---@return table self The widget instance for chaining
    numeric = function(self, argv)
        self.numeric = octane.gui.create{
            type     = octane.gui.componentType.NUMERIC_BOX,
            width    = argv.width or 100,
            height   = argv.height or 24,
            maxValue = argv.max or 256000,
            minValue = argv.min or 0,
            step     = argv.step or 100,
            value    = argv.value or 0,
            x        = argv.x or 0,
            y        = argv.y or 0
        }
        
        if argv.label then
            self:append('label'){argv.label}
        elseif type(argv[1]) == "table" then
            self:append('label')(argv)
        end
        return self
    end,

    ---Creates a checkbox component with optional label
    ---@param self table The widget instance
    ---@param argv table Arguments: {label={}, text="", width=80, height=20, checked=false}
    ---@return table self The widget instance for chaining
    check = function(self, argv)
        self.check = octane.gui.create{
            type    = octane.gui.componentType.CHECK_BOX,
            text    = argv.text or "",
            width   = argv.width or 80,
            height  = argv.height or 20,
            checked = argv.checked or false,
            x       = argv.x or 0,
            y       = argv.y or 0
        }
        
        if argv.label then
            self:append('label'){argv.label}
        elseif type(argv[1]) == "table" then
            self:append('label')(argv)
        end
        return self
    end,

    ---Creates a combo box (dropdown) with optional label
    ---@param self table The widget instance
    ---@param argv table Arguments: {label={}, items={}, width=120, height=24}
    ---@return table self The widget instance for chaining
    combo = function(self, argv)
        self.combo = octane.gui.create{
            type       = octane.gui.componentType.COMBO_BOX,
            name       = argv.name or "",
            items      = argv.items or {},
            width      = argv.width or 120,
            height     = argv.height or 24,
            x          = argv.x or 0,
            y          = argv.y or 0,
            selectedIx = 1
        }
        
        if argv.label then
            self:append('label'){argv.label}
        elseif type(argv[1]) == "table" then
            self:append('label')(argv)
        end
        return self
    end,

    ---Creates a text editor component
    ---@param self table The widget instance
    ---@param argv table Arguments: {text="", width=400, height=30, enable=false}
    ---@return table self The widget instance for chaining
    editor = function(self, argv)
        local text = ""
        if type(argv.text) == "string" then
            text = argv.text
        end
        
        self.editor = octane.gui.create{
            type   = octane.gui.componentType.TEXT_EDITOR,
            text   = text,
            width  = argv.width or 400,
            height = argv.height or 30,
            enable = argv.enable or false,
            x      = argv.x or 0,
            y      = argv.y or 0
        }
        return self
    end,

    ---Creates a tab container
    ---@param self table The widget instance
    ---@param argv table Arguments: {headers={}, children={}}
    ---@return table self The widget instance for chaining
    tabs = function(self, argv)
        self.tabs = octane.gui.create{
            type     = octane.gui.componentType.TABS,
            children = argv.children,
            header   = argv.headers,
            x        = argv.x or 0,
            y        = argv.y or 0
        }
        return self
    end,

    ---Creates a progress bar
    ---@param self table The widget instance
    ---@param argv table Arguments: {text="", width=400, height=25}
    ---@return table self The widget instance for chaining
    progressBar = function(self, argv)
        self.bar = octane.gui.create{
            type   = octane.gui.componentType.PROGRESS_BAR,
            text   = argv.text or "",
            width  = argv.width or 400,
            height = argv.height or 25,
            x      = argv.x or 0,
            y      = argv.y or 0
        }
        return self
    end,

    ---Creates a group container for laying out child components
    ---@param self table The widget instance
    ---@param argv table Arguments: {children, text="", border=false, padding={0,0}, inset={0,0}, center=false, debug=false}
    ---@return table self The widget instance for chaining
    group = function(self, argv)
        ---Converts 2D children array to flat list with row/col counts
        ---@param guiChildren table 2D array of GUI components
        ---@return table children Flat list of components
        ---@return number rows Number of rows
        ---@return number cols Number of columns
        local function list_children(guiChildren)
            local rows = #guiChildren
            local cols = #guiChildren[1]
            local children = {}
            for _, row in pairs(guiChildren) do
                for _, col in pairs(row) do
                    table.insert(children, col)
                end
            end
            return children, rows, cols
        end
        
        local group, g_rows, g_cols = list_children(argv[1])

        self.group = octane.gui.create{
            type     = octane.gui.componentType.GROUP,
            children = group,
            rows     = g_rows,
            cols     = g_cols,
            text     = argv.text or "",
            border   = argv.border or false,
            padding  = argv.padding or {0, 0},
            inset    = argv.inset or {0, 0},
            centre   = argv.center or argv.centre or false,
            debug    = argv.debug or false,
            x        = argv.x or 0,
            y        = argv.y or 0
        }
        return self
    end
}

--------------------------------------------------------------------------------
-- Widget Class
--------------------------------------------------------------------------------

---@class Widget
---Factory class for creating GUI components with a fluent interface
widget = {
    ---When true, tooltips are suppressed on buttons
    hideToolTips = false,

    ---Internal: Sets up metatable for object inheritance
    ---@param self table The widget class
    ---@param obj table|nil Object to set up (creates new if nil)
    ---@return table obj The configured object
    setup = function(self, obj)
        obj = obj or {}
        setmetatable(obj, self)
        self.__index = self
        return obj
    end,

    ---Creates a new base widget container for holding multiple components
    ---@param self table The widget class
    ---@return table obj New widget instance with access to component methods
    create = function(self)
        local obj = self:setup()
        obj.method = methods
        return obj
    end,

    ---Creates a new component of the specified type
    ---@param self table The widget class or instance
    ---@param key string Component type: 'label', 'button', 'slider', 'numeric', 'check', 'combo', 'editor', 'tabs', 'progressBar', 'group'
    ---@param name string|nil Optional name to store component under in parent
    ---@return function Factory function that accepts component arguments
    new = function(self, key, name)
        local obj = self:create()
        if name ~= nil then
            return function(...)
                self[name] = obj.method[key](obj, ...)
                return self[name]
            end
        else
            return function(...)
                return obj.method[key](obj, ...)
            end
        end
    end,

    ---Appends a component to an existing widget
    ---@param self table The widget instance to append to
    ---@param key string Component type to append
    ---@return function Factory function that accepts component arguments
    append = function(self, key)
        return function(...)
            return self.method[key](self, ...)
        end
    end
}

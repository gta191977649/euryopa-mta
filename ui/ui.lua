loadstring(exports.dgs:dgsImportFunction())() -- load functions
CAM = exports.freecam
-- Define a class for the UI
UI = class()

-- Constructor for the UI class
function UI:init(buttonTitles, buttonWidth)
    self.font = dgsCreateFont("font/default.ttf")

    -- Button titles and their respective context menu items
    self.buttonTitles = buttonTitles or {
        {title = "File", items = {"Exit"}},
        {title = "View", items = {"Time & Weather", "Debug", "Rendering"}},
        {title = "Interior", items = {"A", "B"}},
        {title = "Debug", items = {"Tool1", "Tool2"}},
        {title = "Help", items = {"Help1", "Help2"}}
    }

    self.buttonWidth = buttonWidth or 0.05
    self.contextArea = dgsCreateImage(0, 0, 1, 0.025, nil, true, nil, tocolor(0, 0, 0, 200))

    -- Setup context menus for buttons
    self:setupContextMenus()

    -- Initialize buttons
    self:setupButtons()

    -- Centralized actions for context menu items
    self.menuActions = {
        [1] = { -- "File"
            [1] = function() outputChatBox("Exit selected from File") end
        },
        [2] = { -- "View"
            [1] = function() self:toggleTimecycDebugWindow() end -- "Time & Weather"
        },
        [3] = { -- "Interior"
            [1] = function() outputChatBox("A selected from Interior") end,
            [2] = function() outputChatBox("B selected from Interior") end
        },
        [4] = { -- "Debug"
            [1] = function() outputChatBox("Tool1 selected from Debug") end,
            [2] = function() outputChatBox("Tool2 selected from Debug") end
        },
        [5] = { -- "Help"
            [1] = function() outputChatBox("Help1 selected from Help") end,
            [2] = function() outputChatBox("Help2 selected from Help") end
        }
    }

    -- Initialize Timecyc Debug Window but hide it initially
    self:timecycDebugWindow()
    dgsSetVisible(self.timecycDebugWin, false)
    
    -- add for cursor control
    addEventHandler( "onClientKey", root, function(button,press) 
        -- Since mouse_wheel_up and mouse_wheel_down cant return a release, we dont have to check the press.
        if button == "n" and press then
            local isVisible = isCursorShowing()
            showCursor(not isVisible)
            
            playSoundFrontEnd (12)
        end
    end )

end

-- Method to setup context menus for each button
function UI:setupContextMenus()
    self.contextMenus = {}
    for i, buttonData in ipairs(self.buttonTitles) do
        local menu = dgsCreateMenu(200, 200, 200, 100, false)
        for itemIndex, item in ipairs(buttonData.items) do
            dgsMenuAddItem(menu, item, i .. "_" .. itemIndex)
        end
        self.contextMenus[i] = menu
        addEventHandler("onDgsMenuSelect", menu, function(subMenu, uniqueID)
            self:onMenuSelect(i, uniqueID)
        end)
    end
end

-- Method to handle context menu selection
function UI:onMenuSelect(buttonIndex, uniqueID)
    if self.menuActions[buttonIndex] and self.menuActions[buttonIndex][uniqueID] then
        self.menuActions[buttonIndex][uniqueID]()
    end
    dgsMenuHide(source)
end

-- Method to create and position buttons
function UI:setupButtons()
    for i, buttonData in ipairs(self.buttonTitles) do
        local posX = (i - 1) * self.buttonWidth
        local btn = dgsCreateButton(posX, 0, self.buttonWidth, 1, buttonData.title, true, self.contextArea)
        dgsSetFont(btn, self.font)
        addEventHandler("onDgsMouseClickUp", btn, function(button)
            if button == "left" then
                self:showContextMenu(i)
            end
        end)
    end

    -- Setup the author label positioned at the right side of the context area
    local authorLabel = dgsCreateLabel(0.9, 0, 0.1, 1, "SKYGFX 2.0 | Nurupo", true, self.contextArea)
    dgsSetFont(authorLabel, self.font)
    dgsSetProperty(authorLabel,"alignment",{"right", "center"})
end

-- Method to show the context menu for a specific button
function UI:showContextMenu(index)
    local menu = self.contextMenus[index]
    if menu then
        dgsMenuShow(menu)
    end
end

-- Initialize and configure the Timecyc Debug Window
function UI:timecycDebugWindow()
    self.timecycDebugWin = dgsCreateWindow(0.15, 0.33, 0.3, 0.34, "SKYGFX - DEBUG", true)
    local h, m = getTime()
    local time = h * 60 + m

    self.label_h = dgsCreateLabel(0.02, 0.04, 0.1, 0.1, "HOUR:MIN", true, self.timecycDebugWin)
    self.input_h = dgsCreateEdit(0.02, 0.1, 0.1, 0.1, math.floor(time / 60), true, self.timecycDebugWin)
    self.input_m = dgsCreateEdit(0.13, 0.1, 0.1, 0.1, time % 60, true, self.timecycDebugWin)

    self.label_oldWea = dgsCreateLabel(0.4, 0.04, 0.2, 0.1, "CURRENT WEATHER: " .. (0), true, self.timecycDebugWin)
    self.input_oldWea = dgsCreateEdit(0.4, 0.1, 0.25, 0.1, 0, true, self.timecycDebugWin)
    self.label_nextWea = dgsCreateLabel(0.7, 0.04, 0.2, 0.1, "BLEND WEATHER: " .. (0), true, self.timecycDebugWin)
    self.input_nextWea = dgsCreateEdit(0.7, 0.1, 0.25, 0.1, 0, true, self.timecycDebugWin)

    self.label_cyc = dgsCreateLabel(0.02, 0.22, 0.2, 0.1, "TIME CYCLE", true, self.timecycDebugWin)
    self.scroll_timecyc = dgsCreateScrollBar(0.02, 0.28, 0.96, 0.08, true, true, self.timecycDebugWin)
    dgsSetProperty(self.scroll_timecyc, "map", {0, 1440})

    self.label_int = dgsCreateLabel(0.02, 0.4, 0.2, 0.1, "INTERPOLATION: 0", true, self.timecycDebugWin)
    self.scroll_interp = dgsCreateScrollBar(0.02, 0.46, 0.96, 0.08, true, true, self.timecycDebugWin)
    dgsSetProperty(self.scroll_interp, "map", {0, 1})

    -- Add event handlers for UI updates
    addEventHandler("onDgsElementScroll", self.scroll_timecyc, function(source)
        local time = dgsScrollBarGetScrollPosition(source)
        setTime(math.floor(time / 60), time % 60)
        self:updateUI()
    end)

    addEventHandler("onDgsElementScroll", self.scroll_interp, function(source)
        local interp = dgsScrollBarGetScrollPosition(source)
        Weather.interpolation = interp
        self:updateUI()
    end)

    addEventHandler("onDgsTextChange", self.input_oldWea, function()
        local newOld = dgsGetText(source)
        if tonumber(newOld) then
            setWeather(tonumber(newOld))
            outputChatBox("Old weather set to: " .. newOld)
            self:updateUI()
        end
    end)

    addEventHandler("onDgsTextChange", self.input_nextWea, function()
        local nextWea = dgsGetText(source)
        if tonumber(nextWea) then
            Weather.new = tonumber(nextWea)
            outputChatBox("New weather set to: " .. nextWea)
            self:updateUI()
        end
    end)

    addEventHandler("onDgsWindowClose",self.timecycDebugWin,function() 
        cancelEvent() -- diabled window destory, we only set its visibility.
        dgsSetVisible(self.timecycDebugWin,false)
    end)
end

-- Show or hide the Timecyc debug window
function UI:toggleTimecycDebugWindow()
    local isVisible = dgsGetVisible(self.timecycDebugWin)
    dgsSetVisible(self.timecycDebugWin, not isVisible)
end

-- Method to update UI values
function UI:updateUI()
    local h, m = getTime()
    dgsSetProperty(self.label_cyc, "text", string.format("TIME CYCLE: %d:%02d", h, m))
    dgsSetProperty(self.input_h, "text", h)
    dgsSetProperty(self.input_m, "text", m)
    dgsSetProperty(self.label_int, "text", string.format("INTERPOLATION: %.2f", 0))
    dgsSetProperty(self.label_oldWea, "text", "CURRENT WEATHER: " .. (0 or 0))
    dgsSetProperty(self.label_nextWea, "text", "BLEND WEATHER: " .. (0 or 0))
end


-- CosmOS is an extensive operating system designed as a drop-in replacement for the default WarpDrive controller script.

-- Objectives:
-- 1. Make a more user-friendly interface for the WarpDrive controller with clickable buttons and a GUI that can be extended to a monitor.
-- 2. Extend the WarpDrive controller features with Autopilot, Waypoints, Jump Cancelling, A map/general navigation improvements, and Multicore
-- 3. Add hooks for other peripherals, like cloaks, radars, and shields which can be controlled from the GUI and put on specific monitors. Also, peripheral hotswap.

-- 1a. WarpDrive controller features include:
    -- Ship Name
    -- Ship Dimensions (auto dimensions?)
    -- Ship Movement
    -- Ship Jumping
    -- Hyperspace
    -- Mode Selection
    -- Ship Position
    -- Ship Energy
    -- Ship Mass
    -- Target position
    -- Distance with current energy

--- Memory Management
-- This is sort of like a very small implementation of JSON in Lua, used for persistent data across reboots.

local CosmOSMemoryPath = "CosmOS/CosmOSMemory"

local function initMemory()
    -- Check if the memory file exists, and if it doesn't, create it.
    if fs.exists(CosmOSMemoryPath) == false then
        local file = fs.open(CosmOSMemoryPath, "w")
        file.close()
    end
    -- In some cases, yes this will mean we open the file twice for no reason.
end

local function readMemory(key)
    initMemory()
    local file = fs.open(CosmOSMemoryPath, "r")
    local content = file.readAll()
    file.close()
    local object = textutils.unserialize(content, { allow_repetitions = true })
    if object == nil then
        return nil
    end
    return object[key]
end

local function writeMemory(key, value)
    initMemory()
    local object = {}
    local file = fs.open(CosmOSMemoryPath, "r")
    local content = file.readAll()
    file.close()
    if (content == "") or (content == nil) or (content == " ") then
        object[key] = value 
    else
        object = textutils.unserialize(content, { allow_repetitions = true })
        object[key] = value
    end
    local file = fs.open(CosmOSMemoryPath, "w")
    file.write(textutils.serialize(object, { allow_repetitions = true }))
    file.close()
end

---

-- Given a set of tables for the attached shipControllers and shipCores, this function will search for the master core and slave cores.
local function searchForCores(shipControllers, shipCores)
    local masterCore = nil
    local slaveCores = nil
    if (#shipControllers == 1) and (#shipCores == 0) then
        print("Only one warpdrive ship controller found, assuming primary core.")
        masterCore = shipControllers[1]
        slaveCores = nil -- Just in case this core used to be a slave core
        -- Since there is only one controller, delete the controller and core tables
        shipControllers = nil
        shipCores = nil
    elseif (#shipControllers == 0) and (#shipCores == 1) then
        print("Only one warpdrive ship controller found, assuming primary core.")
        masterCore = shipCores[1]
        slaveCores = nil -- Just in case this core used to be a slave core
        -- Since there is only one core, delete the controller and core tables
        shipControllers = nil
        shipCores = nil
    elseif (#shipControllers > 1) or (#shipCores > 1) or ((#shipControllers+#shipCores) >= 2) then
        -- Multicore detected, prompt user to select a master core
        -- Get locations of all cores
        local shipControllerLocations = {}
        for i, controller in ipairs(shipControllers) do
            local x, y, z = controller.getLocalPosition()
            shipControllerLocations[i] = {x, y, z}
        end
        local shipCoreLocations = {}
        for i, core in ipairs(shipCores) do
            local x, y, z = core.getLocalPosition()
            shipCoreLocations[i] = {x, y, z}
        end
        -- Prompt user to select a master core
        print("Multiple warpdrive ship controllers or cores found. Please select a master core.")
        print("Ship Controllers:")
        for i, location in ipairs(shipControllerLocations) do
            print("  "..i..". "..location[1], location[2], location[3])
        end
        print("Ship Cores:")
        for i, location in ipairs(shipCoreLocations) do
            print("  "..i..". "..location[1], location[2], location[3])
        end
        print("Enter the number of the core you wish to use as the master core:")
        local masterCoreInput = tonumber(read())
        if masterCoreInput == nil then
            print("Invalid input. Exiting.")
            return
        end
        if masterCoreInput <= #shipControllers then
            -- Set the master core to the selected controller
            masterCore = shipControllers[masterCoreInput]
            -- Remove it from the controller table
            table.remove(shipControllers, masterCoreInput)
        else
            -- Set the master core to the selected core
            masterCore = shipCores[masterCoreInput-#shipControllers]
            -- Remove it from the core table
            table.remove(shipCores, masterCoreInput-#shipControllers)
        end
        -- Concatinate the remaining controllers and cores into the slave core table, and delete the remaining tables
        slaveCores = shipControllers
        for i, core in ipairs(shipCores) do
            table.insert(slaveCores, core)
        end
        shipControllers = nil
        shipCores = nil
        -- All done :)
    else
        print("No warpdrive ship controllers or cores found.")
        return
    end
    -- Save the master core and slave cores to memory so we don't have to go through this check next time
    print("Saving results of search to memory.")
    writeMemory("masterCore", peripheral.getName(masterCore))
    if slaveCores == nil then
        writeMemory("slaveCores", slaveCores) -- Which will be nil
        return masterCore, slaveCores
    end
    local temp = {} -- We can't use .getName on a table of peripherals, so we have to make a new table with the names
    for i, core in ipairs(slaveCores) do
        table.insert(temp, peripheral.getName(core))
    end
    writeMemory("slaveCores", temp) -- We assume there's slave cores, because if there's only one main core, we won't get this far on startup.
    return masterCore, slaveCores
end

-- This function returns the master core and slave cores, if they exist. If they don't, it will search for them and return them.
-- It will also save the master core and slave cores to memory so we don't have to search for them again.
-- All of this would be a lot easier if we only needed one core, or wanted to use the first core we found, but we want to support multicore.
local function getCores()
    local finalMasterCore = nil
    local finalSlaveCores = nil
    local attachedShipControllers = {peripheral.find("warpdriveShipController")}
    local attachedShipCores = {peripheral.find("warpdriveShipCore")}
    local memoryCore = readMemory("masterCore")
    local memorySlaveCores = readMemory("slaveCores")
    -- First, check if the cores from memory can all be found (are in attachedShipControllers and attachedShipCores)
    -- Loop through the list of attached ship controllers and cores, and if one of them does not match one from memory, we have to search for cores.
    if memoryCore == nil and memorySlaveCores == nil then -- We have no cores in memory, this must be first time setup
        finalMasterCore, finalSlaveCores = searchForCores(attachedShipControllers, attachedShipCores)
        return finalMasterCore, finalSlaveCores
    elseif memoryCore ~= nil and memorySlaveCores == nil then -- We have a master core in memory but no slave cores
        -- Do a protected call to see if the core is still there
        local status, error = pcall(function() finalMasterCore = peripheral.wrap(readMemory("masterCore")) end)
        if not status then
            finalMasterCore, finalSlaveCores = searchForCores(attachedShipControllers, attachedShipCores)
            return finalMasterCore, finalSlaveCores
        end
    elseif memoryCore == nil and memorySlaveCores ~= nil then -- We have slave cores in memory but no master core
        finalSlaveCores = {} -- We haven't assumed there are any until now, which is why we're making a new table
        local temp = memorySlaveCores
        for i, core in ipairs(temp) do
            local status, error = pcall(function() finalSlaveCores[i] = peripheral.wrap(core) end)
            if not status then
                print("Slave core "..i.." not found. Reinitializing core search.")
                break
            end
        end
        finalMasterCore, finalSlaveCores = searchForCores(attachedShipControllers, attachedShipCores)
        return finalMasterCore, finalSlaveCores
    elseif (memorySlaveCores == nil) and ((1) == (#attachedShipControllers+#attachedShipCores)) then -- We have no slave cores in memory and there are no new cores
        finalMasterCore = peripheral.wrap(memoryCore)
        finalSlaveCores = nil
        return finalMasterCore, finalSlaveCores
    elseif (memorySlaveCores ~= nil) and ((1+#memorySlaveCores) == (#attachedShipControllers+#attachedShipCores)) then -- We have all the cores in memory and no new cores
        finalMasterCore = peripheral.wrap(memoryCore)
        finalSlaveCores = {}
        for i, core in ipairs(memorySlaveCores) do 
            finalSlaveCores[i] = peripheral.wrap(core)
        end
        return finalMasterCore, finalSlaveCores
    end
    print("New cores detected. Reinitializing core search.")
    finalMasterCore, finalSlaveCores = searchForCores(attachedShipControllers, attachedShipCores)
    return finalMasterCore, finalSlaveCores
end

-- Grabs the Faygo API, or downloads it if it doesn't exist
local function getFaygo()
    local faygo = nil
    -- Try to load the Faygo API, if it doesn't exist, download it.
    local status, error = pcall(function() local faygo = require("Faygo") end) -- This kinda sucks because it loads the API twice, but it's the only way to check if it exists
    if not status then
        print("Faygo API not found, downloading...")
        shell.run("wget https://raw.githubusercontent.com/jhammerberg/Faygo/main/Faygo.lua startup/Faygo.lua")
        faygo = require("Faygo")
    else
        faygo = require("Faygo")
    end
    return faygo
end

--- Drawing Functions
local drawnButtons = {} -- Keep track of what menu buttons are currently in use to we can delete them more easily
local function killButtons(buttons)
    for i, button in ipairs(buttons) do
        button:kill()
    end
    buttons = {}
end

local function drawStatus(button)
    return
end

local menuBorderColor, menuBackgroundColor, menuAccentColor = colors.gray, colors.lightGray, colors.orange
local menuItems = {"Status", "Config", "Move", "Navigation", "Cloak", "Radar", "Shields", "Other"}
local scrollPosition = 0
local menuCollapsed = true
local function drawMenu(gui)
    -- Make sure that there are no buttons still active by killing all that are in the drawnButtons table
    killButtons(drawnButtons)
    if menuCollapsed then
        -- The collapsed menu is just the fancy line on the left and one pixel for border and a button to expand it
        local startPoint = {x = gui.absWidth, y = 0}
        local endPoint = {x = gui.absWidth, y = gui.absHeight}
        gui:drawRectFilled(menuBorderColor, startPoint, endPoint)
        local leftLineStart = {x = startPoint.x-1, y = startPoint.y-1} -- I don't really know why the -1 is needed for the Y, but it is
        local leftLineEnd = {x = startPoint.x-1, y = endPoint.y}
        gui:drawLineText(menuBorderColor, gui.backgroundColor, "\x95", leftLineStart, leftLineEnd) -- The colors are inverted because the character we want doesn't exist, so we use it's inverse instead
        
        -- The button to expand the menu
        local buttonPos = {x = gui.absWidth, y = gui.absHeight}
        local expandButton = gui:newButton(menuAccentColor, menuBorderColor, buttonPos, {x = buttonPos.x, y = buttonPos.y}, "\xAB", function(thisButton)
            menuCollapsed = false
            drawMenu(gui)
        end)
        table.insert(drawnButtons, expandButton)

    else
        local maxMenuWidth = (#"Navigation")+3 -- the longest text on the menu, plus 2 for text padding and plus 2 for the border
        -- Draw the border
        local startPoint = {x = gui.absWidth-(maxMenuWidth), y = 0}
        local endPoint = {x = gui.absWidth, y = gui.absHeight}
        gui:drawRectFilled(menuBorderColor, startPoint, endPoint)
        -- Draw the background
        local insetStart = {x = startPoint.x+1, y = startPoint.y+1}
        local insetEnd = {x = endPoint.x-1, y = endPoint.y-1}
        gui:drawRectFilled(menuBackgroundColor, insetStart, insetEnd)
        -- Draw the left fancy line
        local leftLineStart = {x = startPoint.x-1, y = startPoint.y-1} -- I don't really know why the -1 is needed for the Y, but it is
        local leftLineEnd = {x = startPoint.x-1, y = endPoint.y}
        gui:drawLineText(menuBorderColor, gui.backgroundColor, "\x95", leftLineStart, leftLineEnd) -- The colors are inverted because the character we want doesn't exist, so we use it's inverse instead
        -- The padding line at the top
        local topPaddingLineStart = {x = insetStart.x-1, y = insetEnd.y}
        local topPaddingLineEnd = {x = insetEnd.x, y = insetEnd.y}
        gui:drawLineText(menuBackgroundColor, menuBorderColor, "\x8F", topPaddingLineStart, topPaddingLineEnd) -- The colors are inverted because the character we want doesn't exist, so we use it's inverse instead
        -- The padding line at the bottom
        local bottomPaddingLineStart = {x = insetStart.x-1, y = insetStart.y}
        local bottomPaddingLineEnd = {x = insetEnd.x, y = insetStart.y}
        gui:drawLineText(menuBorderColor, menuBackgroundColor, "\x83", bottomPaddingLineStart, bottomPaddingLineEnd) -- The colors are inverted because the character we want doesn't exist, so we use it's inverse instead
        -- New inset start and end points for the menu items, this considers the padding lines
        insetStart = {x = insetStart.x, y = insetStart.y+1}
        insetEnd = {x = insetEnd.x, y = insetEnd.y-1}

        -- The button to expand the menu
        local buttonPos = {x = startPoint.x, y = gui.absHeight} -- We only need one point because it's one character
        local collapseButton = gui:newButton(menuAccentColor, menuBorderColor, buttonPos, buttonPos, "\xBB", function(thisButton)
            menuCollapsed = true
            gui:clr()
            drawMenu(gui)
        end)
        table.insert(drawnButtons, collapseButton)

        -- Draw the scroll down button on the right side of the screen inside the gray border
        local scrollDownButtonPos = {x = insetEnd.x+1, y = insetStart.y-1}
        local scrollDownButton = gui:newButton(menuAccentColor, menuBorderColor, scrollDownButtonPos, scrollDownButtonPos, "\x19", function(thisButton)
            if scrollPosition < (#menuItems-1) then
                scrollPosition = scrollPosition+1
                drawMenu(gui)
            end
        end)
        table.insert(drawnButtons, scrollDownButton)
    
        -- Draw the scroll up button on the right side of the screen inside the gray border
        local scrollUpButtonPos = {x = insetEnd.x+1, y = insetEnd.y+1}
        local scrollUpButton = gui:newButton(menuAccentColor, menuBorderColor, scrollUpButtonPos, scrollUpButtonPos, "\x18", function(thisButton)
            if scrollPosition > 0 then
                scrollPosition = scrollPosition-1
                drawMenu(gui)
            end
        end)
        table.insert(drawnButtons, scrollUpButton)

        local availableSpace = insetEnd.y-insetStart.y
        -- Loop over every line of available space and see if we should draw a button or a divider
        for i = 1, (availableSpace+1) do
            local lineStart = {x = insetStart.x, y = insetEnd.y-(i-1)}
            local lineEnd = {x = insetEnd.x, y = lineStart.y} -- We should never need to change the Y value of lineEnd
            local item = menuItems[((i+1)/2)+scrollPosition]
            if i % 2 == 0 then -- Draw a divider
                gui:drawLineText(menuBackgroundColor, menuBorderColor, "\x8C", {x = lineStart.x-1, y = lineStart.y}, lineEnd)
            elseif item ~= nil then -- Only if the item exists, drawa button
                local button = gui:newButton(menuAccentColor, menuBackgroundColor, lineStart, lineEnd, item, function(thisButton)
                    print("Button "..item.." clicked.")
                end)
                table.insert(drawnButtons, button)
            end
        end
    end
end

local faygo = getFaygo()
local function init()
    print("Initializing CosmOS...")
    local masterCore, slaveCores = getCores()
    local mon = peripheral.find("monitor")
    local gui = faygo.newGUI(mon)
    gui:setBackgroundColor(colors.black)
    gui:clr()
    menuBorderColor, menuBackgroundColor, menuAccentColor = colors.gray, colors.cyan, colors.orange
    drawMenu(gui)
end

local function main()
    while true do
        -- Main loop
        os.sleep(1)
    end
end

init()
faygo.run(main) -- Needed for the GUI to work
faygo.cleanUp()
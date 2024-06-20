-- CosmOS is an extensive operating system designed as a drop-in replacement for the default WarpDrive controller script.

-- Objectives:
-- 1. Make a more user-friendly interface for the WarpDrive controller with clickable buttons and a GUI that can be extended to a monitor.
-- 2. Extend the WarpDrive controller features with Autopilot, Waypoints, Jump Cancelling, and Multicore
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

local faygo = nil
local function init()
    print("Initializing CosmOS...")
    -- Try to load the Faygo API, if it doesn't exist, download it.
    local status, error = pcall(function() local faygo = require("Faygo") end)
    if not status then
        print("Faygo API not found, downloading...")
        shell.run("wget https://raw.githubusercontent.com/jhammerberg/Faygo/main/Faygo.lua")
        faygo = require("Faygo")
    else
        faygo = require("Faygo")
    end

    -- Objects for the masterCore and slaveCores if more than one is attached
    -- We might be able to get away with having one huge table for all cores, but it'd make things a lot more complicated
    -- This way most of the time we can just address the masterCore, and if there are multiple attached we can deal with them separately
    local masterCore = nil
    local slaveCores = {}
    -- Find any and all attached warpdrive ship controllers and cores
    local shipControllers = {peripheral.find("warpdriveShipController")}
    local shipCores = {peripheral.find("warpdriveShipCore")}
    if (#shipControllers == 1) then
        masterCore = shipControllers[1]
        -- Since there is only one controller, delete the controller and core tables
        shipControllers = nil
        shipCores = nil
    elseif (#shipCores == 1) then
        masterCore = shipCores[1]
        -- Since there is only one controller, delete the controller and core tables
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
        masterCore = tonumber(read())
        if masterCore == nil then
            print("Invalid input. Exiting.")
            return
        end
        if masterCore <= #shipControllers then
            -- Set the master core to the selected controller
            masterCore = shipControllers[masterCore]
            -- Remove it from the controller table
            table.remove(shipControllers, masterCore)
        else
            -- Set the master core to the selected core
            masterCore = shipCores[masterCore-#shipControllers]
            -- Remove it from the core table
            table.remove(shipCores, masterCore)
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
end

local function main()
    while true do
        -- stuff
    end
end

init()
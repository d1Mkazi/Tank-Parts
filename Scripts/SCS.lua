--[[
    SCS - Self-Check System
    It checks is the mod infected.
    If it is, user gets a notification.

    Thanks to Questionable Mark for this technology!
]]--

dofile("$SURVIVAL_DATA/Scripts/util.lua")

local allowed = {} -- allowed dependencies. Put mod fileIds there
local mod = "Tank Parts" -- your mod name

function onNotInfected()
    print("[Mod Check] "..mod.." is not infected.")
end

local json = sm.json.open("$CONTENT_DATA/description.json")
if not json.dependencies or json.dependencies == {} then
    onNotInfected()
    return
end

local dependencies = json.dependencies

function onInfect()
    local msg = sm.gui.chatMessage

    msg("#ff2222".."WARNING: "..mod.." is infected!")

    msg("Please remove the following dependencies:")
    for k, dependency in pairs(dependencies) do
        msg("#ffff22".."fileId: "..dependency.fileId.." | Name: "..dependency.name)
    end
    msg("Also check your other mods!")

    msg("\nThese mods open backdoors in your game or waiting for a certain amount of people to get infected to start the payload.")
    msg("Go to steamcommunity.com/sharedfiles/filedetails/?id=*id*\nand report them as soon as you can!")

    print("[Mod Check] WARNING: "..mod.." IS INFECTED!")
    print("[Mod Check] WARNING: "..mod.." IS INFECTED!")
    print("[Mod Check] WARNING: "..mod.." IS INFECTED!")
end

function Check()
    if CHECKED then return end
    CHECKED = true

    for k, dependency in pairs(dependencies) do
        if not isAnyOf(dependency.fileId, allowed) then
            onInfect()
            return
        end
        onNotInfected()
    end
end
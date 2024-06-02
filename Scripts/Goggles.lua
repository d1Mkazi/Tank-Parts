---@class Goggles : ShapeClass
Goggles = class()
Goggles.maxParentCount = 1
Goggles.connectionInput = sm.interactable.connectionType.logic
Goggles.colorNormal = sm.color.new("d8c836ff")
Goggles.colorHighlight = sm.color.new("f0e26bff")


--[[ SERVER ]]--

function Goggles:server_onCreate()
    self:init()
end

function Goggles:server_onRefresh()
    self:init()
    print("RELOADED")
end

function Goggles:init()
    self.sv = {}
end
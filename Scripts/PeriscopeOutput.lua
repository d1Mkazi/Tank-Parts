---@class PeriscopeOutput : ShapeClass
PeriscopeOutput = class()
PeriscopeOutput.maxParentCount = 1
PeriscopeOutput.connectionInput = sm.interactable.connectionType.logic
PeriscopeOutput.colorNormal = sm.color.new("5f8cc7ff")
PeriscopeOutput.colorHighlight = sm.color.new("78a1d6ff")


--[[ SERVER ]]--

function PeriscopeOutput:server_onCreate()
    self:sv_init()
end

function PeriscopeOutput:server_onRefresh()
    self:sv_init()
    print("RELOADED")
end

function PeriscopeOutput:sv_init()
    self.sv = {}
    self.saved = {}
end

function PeriscopeOutput:server_onFixedUpdate(dt)
    local parent = self.interactable:getSingleParent()
    if parent and tostring(parent.shape.uuid) ~= "66a069ab-4512-421d-b46b-7d14fb7f3b22" then
        parent:disconnect(self.interactable)
    end
end


--[[ CLIENT ]]--

function PeriscopeOutput:client_onCreate()
    self:cl_init()
end

function PeriscopeOutput:client_onRefresh()
    self:cl_init()
end

function PeriscopeOutput:cl_init()
    self.cl = {}
end
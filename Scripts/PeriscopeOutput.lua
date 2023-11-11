---@class PeriscopeOutput : ShapeClass
PeriscopeOutput = class()
PeriscopeOutput.maxParentCount = 1
PeriscopeOutput.connectionInput = sm.interactable.connectionType.logic
PeriscopeOutput.colorNormal = sm.color.new("5f8cc7ff")
PeriscopeOutput.colorHighlight = sm.color.new("78a1d6ff")


function PeriscopeOutput:server_onFixedUpdate(dt)
    local parent = self.interactable:getSingleParent()
    if parent and tostring(parent.shape.uuid) ~= "66a069ab-4512-421d-b46b-7d14fb7f3b22" then
        parent:disconnect(self.interactable)
    end
end
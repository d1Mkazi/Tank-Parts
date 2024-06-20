---@class Viewport : ShapeClass
Viewport = class()
Viewport.maxParentCount = 1
Viewport.connectionInput = sm.interactable.connectionType.logic
Viewport.colorNormal = sm.color.new("5f8cc7ff")
Viewport.colorHighlight = sm.color.new("78a1d6ff")


function Viewport:server_onFixedUpdate(dt)
    local parent = self.interactable:getSingleParent()
    if parent and tostring(parent.shape.uuid) ~= self.data.connectableUuid then
        parent:disconnect(self.interactable)
    end
end
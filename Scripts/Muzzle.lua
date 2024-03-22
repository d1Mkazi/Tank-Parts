---@class Muzzle : ShapeClass
Muzzle = class()
Muzzle.maxParentCount = 1
Muzzle.connectionInput = sm.interactable.connectionType.power
Muzzle.colorNormal = sm.color.new("6a306bff")
Muzzle.colorHighlight = sm.color.new("a349a4ff")


function Muzzle:server_onCreate()
    self:init()
end

function Muzzle:server_onRefresh()
    self:init()
    print("Reloaded")
end

function Muzzle:init()
    self.sv = {
        hasBreech = false
    }
end

function Muzzle:server_onFixedUpdate()
    local parent = self.interactable:getSingleParent()
    if parent then
        if self.sv.hasBreech and not isAnyOf(tostring(parent.shape.uuid), BREECH_LIST) then
            print("Muzzle DISCONNETED PARENT:")
            print("hasBreech =", self.sv.hasBreech)
            print("isAnyOf =", isAnyOf(tostring(parent.shape.uuid), BREECH_LIST))
            parent:disconnect(self.interactable)
        else
            self.sv.hasBreech = true
        end
    else
        self.sv.hasBreech = false
    end
end
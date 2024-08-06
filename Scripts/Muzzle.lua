---@class Muzzle : ShapeClass
Muzzle = class()
Muzzle.maxParentCount = 1
Muzzle.connectionInput = sm.interactable.connectionType.power
Muzzle.colorNormal = sm.color.new("6a306bff")
Muzzle.colorHighlight = sm.color.new("a349a4ff")


function Muzzle:server_onCreate()
    self:init()
end

function Muzzle:client_onCreate()
    self.effect = sm.effect.createEffect("TankCannon - ShootMuzzleBrakeExhaust", self.interactable)
    self.effect:setOffsetRotation(sm.quat.angleAxis(math.rad(90), self.shape.at))
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

function Muzzle:sv_playEffect()
    self.network:sendToClients("cl_playEffect")
end

function Muzzle:cl_playEffect()
    self.effect:stop()
    self.effect:start()
end

function Muzzle:client_onRefresh()
    if self.effect:isPlaying() then
        self.effect:stopImmediate()
    end
    self.effect:destroy()
    self.effect = nil
    self:client_onCreate()
end

function Muzzle:client_onDestroy()
    if self.effect:isPlaying() then
        self.effect:stopImmediate()
    end
    self.effect:destroy()
    self.effect = nil
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
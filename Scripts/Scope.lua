dofile("$SURVIVAL_DATA/Scripts/util.lua")

---@class Scope : ShapeClass
Scope = class()
Scope.maxChildCount = -1
Scope.connectionOutput = sm.interactable.connectionType.logic
Scope.colorNormal = sm.color.new("d8c836ff")
Scope.colorHighlight = sm.color.new("f0e26bff")


--[[ SERVER ]]--

function Scope:server_onFixedUpdate(dt)
    if self.interactable.active then
        self.interactable.active = false
    end
end

function Scope:sv_setOccupied(occupied)
    self.network:setClientData({ occupied = occupied })
end

function Scope:sv_setActive(state)
    self.interactable.active = state
end


--[[ CLIENT ]]--

function Scope:client_onCreate()
    self:cl_init()
end

function Scope:client_onRefresh()
    self:cl_init()
end

function Scope:cl_init()
    self.cl = {
        occupied = false
    }
end

function Scope:client_onAction(action, state)
    if not state then return true end

    if action == 15 then -- press E
        self:cl_unlockCharacter()

    elseif action == 20 then -- zoom in
        local fov = sm.camera.getFov() - 5
        if fov <= 0 then return true end

        self.cl.fov = fov
        sm.camera.setFov(fov)

    elseif action == 21 then -- zoom out
        local fov = sm.camera.getFov() + 5
        if fov > 70 then return true end

        self.cl.fov = fov
        sm.camera.setFov(fov)

    elseif action == 19 then -- LMB
        self.network:sendToServer("sv_setActive", true)
    end

    return true
end

function Scope:client_onDestroy()
    if not self.cl.character then return end

    self.cl.character:setLockingInteractable(nil)
end

function Scope:client_onUpdate(dt)
    if self.cl.character then
        local shape = self.shape
        local pos = (shape:getInterpolatedWorldPosition() + shape.velocity * dt) + (-shape.at * 0.1)
        sm.camera.setPosition(pos)
        sm.camera.setDirection(shape.at)
    end
end

function Scope:client_onClientDataUpdate(data, channel)
    for k, v in pairs(data) do
        self.cl[k] = v
    end
end

function Scope:client_canInteract(character)
    return not self.cl.occupied
end

function Scope:client_onInteract(character, state)
    if not state then return end

    character:setLockingInteractable(self.interactable)
    self.network:sendToServer("sv_setOccupied", true)

    self.cl.character = character
    sm.camera.setCameraState(3)
    if self.cl.fov then
        sm.camera.setFov(self.cl.fov)
    end
end

function Scope:cl_unlockCharacter()
    self.cl.character:setLockingInteractable(nil)
    self.cl.character = nil
    self.network:sendToServer("sv_setOccupied", false)
    sm.camera.setFov(sm.camera.getDefaultFov())
    sm.camera.setCameraState(1)
end
dofile("$SURVIVAL_DATA/Scripts/util.lua")

---@class Scope : ShapeClass
Scope = class()


--[[ SERVER ]]--

function Scope:sv_setOccupied(occupied)
    self.network:sendToClients("cl_setOccupied", occupied)
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
        occupied = false,
        character = nil,
        fov = nil
    }
end

function Scope:client_onAction(action, state)
    if not state then return end

    if action == 15 then -- press E
        self:cl_unlockCharacter()

    elseif action == 20 then -- zoom in
        local fov = sm.camera.getFov() - 5
        if fov <= 0 then return end

        sm.camera.setFov(fov)

    elseif action == 21 then -- zoom out
        local fov = sm.camera.getFov() + 5
        if fov > 70 then return end

        sm.camera.setFov(fov)
    end
end

function Scope:client_onUpdate(dt)
    if self.cl.character then
        self:cl_updateCamera()
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
    self:cl_updateCamera()
end

function Scope:cl_setOccupied(state)
    self.cl.occupied = state
end

function Scope:cl_updateCamera()
    local scope = self.shape
    if not sm.exists(scope) then
        self:cl_unlockCharacter()
        return
    end
    local vel = scope.velocity
    local at = scope.at
    local velocityOffset = math.abs(vel.x * at.x + vel.y * at.y + vel.z * at.z)
    sm.camera.setDirection(at)
    sm.camera.setPosition(scope.worldPosition + at * 0.1 * velocityOffset)
end

function Scope:cl_unlockCharacter()
    self.cl.character:setLockingInteractable(nil)
    self.cl.character = nil
    self.network:sendToServer("sv_setOccupied", false)
    self.cl.fov = sm.camera.getFov()
    sm.camera.setFov(sm.camera.getDefaultFov())
    sm.camera.setCameraState(1)
end
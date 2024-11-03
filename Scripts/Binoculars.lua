dofile("utils.lua")

---@class Binoculars : ShapeClass
Binoculars = class()
Binoculars.maxParentCount = 1
Binoculars.maxChildCount = -1
Binoculars.connectionInput = sm.interactable.connectionType.logic
Binoculars.connectionOutput = sm.interactable.connectionType.logic + sm.interactable.connectionType.bearing
Binoculars.colorNormal = sm.color.new("d8c836ff")
Binoculars.colorHighlight = sm.color.new("f0e26bff")


local TARGET_DEVICE = sm.uuid.new("b0fb8b9e-ac99-4033-abd2-4beb598431a2")
local JOYSTICK = sm.uuid.new("3001760a-6d43-4492-a37e-5d7c649179fb")
local VIEWPORT = sm.uuid.new("84145f0d-741c-4142-9aec-edd85ce026be")

--[[ SERVER ]]--

function Binoculars:server_onCreate()
    self:init()
end

function Binoculars:server_onRefresh()
    self:init()
    print("RELOADED")
end

function Binoculars:init()
    self.sv = {
        viewport = nil, --[[@type Interactable]]
        hasDevice = false,
        hasViewport = false,
        bearings = {
            ws = {},
            ad = {}
        }
    }

    self.interactable.publicData = { hasViewport = false }
end

function Binoculars:server_onFixedUpdate(dt)
    local parent = self.interactable:getSingleParent()
    if not parent then
        self.sv.hasDevice = false
        self.network:setClientData({ hasDevice = false })
    else
        if not isAnyOf(parent.shape.uuid, { TARGET_DEVICE, JOYSTICK }) then
            parent:disconnect(self.interactable)
            return
        end

        if not self.sv.hasDevice then
            self.sv.hasDevice = true
            self.network:setClientData({ hasDevice = true })
        end
    end

    local children = self.interactable:getChildren(1)
    if #children > 0 then
        for k, child in ipairs(children) do
            if child.shape.uuid == VIEWPORT then
                if not self.sv.hasViewport then
                    self.sv.hasViewport = true
                    self.sv.viewport = child
                    self.network:setClientData({ viewport = child.shape, hasViewport = true })
                    self.interactable.publicData.hasViewport = true
                elseif self.sv.hasViewport and child ~= self.sv.viewport then
                    self.interactable:disconnect(child)
                end
            else
                self.interactable:disconnect(child)
            end
        end
    else
        self.sv.hasViewport = false
        self.sv.viewport = nil
        self.network:setClientData({ hasViewport = false })
        self.interactable.publicData.hasViewport = false
    end

    local bearings = self.interactable:getBearings()
    local ws, ad = self.sv.bearings.ws, self.sv.bearings.ad
    if #bearings ~= (#self.sv.bearings.ad + #self.sv.bearings.ws) then
        for k, bearing in ipairs(bearings) do
            if not (isAnyOfEx(bearing, ws, "id") or isAnyOfEx(bearing, ad, "id")) then
                bearing:setTargetAngle(bearing.angle * (bearing.reversed == true and 1 or -1), 5, 1000)
                if sameAxis(bearing.zAxis, self.shape.zAxis) then
                    ad[#ad+1] = bearing
                else
                    ws[#ws+1] = bearing
                end
            end
        end

        for k, bearing in pairs(ws) do
            if not isAnyOfEx(bearing, bearings, "id") then
                ws[k] = nil
            end
        end
        for k, bearing in pairs(ad) do
            if not isAnyOfEx(bearing, bearings, "id") then
                ad[k] = nil
            end
        end
    elseif #bearings == 0 then
        self.sv.bearings = { ws = {}, ad = {} }
    end
end

---@param occupied boolean
function Binoculars:sv_setOccupied(occupied)
    self.network:setClientData({ occupied = occupied })
end

---@param to number
function Binoculars:sv_applyImpulseWS(to)
    local bearings = self.sv.bearings.ws
    if to ~= 0 then
        for k, bearing in pairs(bearings) do
            bearing:setMotorVelocity(1 * to, 100)
        end
    else
        for k, bearing in pairs(bearings) do
            bearing:setTargetAngle(bearing.angle * (bearing.reversed == true and 1 or -1), 5, 100)
        end
    end
end

---@param to number
function Binoculars:sv_applyImpulseAD(to)
    local bearings = self.sv.bearings.ad
    if to ~= 0 then
        for k, bearing in pairs(bearings) do
            bearing:setMotorVelocity(1 * to, 100)
        end
    else
        for k, bearing in pairs(bearings) do
            bearing:setTargetAngle(bearing.angle * (bearing.reversed == true and 1 or -1), 5, 100)
        end
    end
end

function Binoculars:sv_e_updateCamera(client)
    self.network:sendToClient(client, "cl_e_updateCamera")
end


--[[ CLIENT ]]--

function Binoculars:client_onCreate()
    self.cl = {
        character = nil, --[[@type Character]]
        viewport = nil, --[[@type Shape]]
        hasDevice = false,
        hasViewport = false,
        occupied = false,
        fov = sm.camera.getDefaultFov()
    }
end

function Binoculars:client_onDestroy()
    if self.cl.character == nil then return end

    self:cl_unlockCharacter()
end

function Binoculars:client_onUpdate(dt)
    if self.cl.character ~= nil then
        local viewport = self.cl.viewport --[[@as Shape]]
        if viewport == nil or not sm.exists(viewport) then
            self:cl_unlockCharacter()
        end
        local pos = (viewport:getInterpolatedWorldPosition() + viewport.velocity * dt) + viewport.at * 0.125
        sm.camera.setPosition(pos)
        sm.camera.setDirection(viewport.at)
    end
end

function Binoculars:client_onAction(action, state)
    if state then
        if action == 15 then -- Use (E)
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

        elseif action == 1 or action == 2 then
            local args = {
                [1] = -1, -- left
                [2] = 1, -- right
            }

            self.network:sendToServer("sv_applyImpulseAD", args[action])

        elseif action == 3 or action == 4 then
            local args = {
                [3] = -1, -- forward
                [4] = 1, -- backward
            }

            self.network:sendToServer("sv_applyImpulseWS", args[action])
        end
    else
        if action == 1 or action == 2 then
            self.network:sendToServer("sv_applyImpulseAD", 0)

        elseif action == 3 or action == 4 then

            self.network:sendToServer("sv_applyImpulseWS", 0)
        end
    end

    return true
end

function Binoculars:client_onClientDataUpdate(data)
    for k, v in pairs(data) do
        self.cl[k] = v
    end
end

function Binoculars:client_canInteract(character)
    return not self.cl.occupied and self.cl.hasViewport
end

function Binoculars:client_onInteract(character, state)
    if not state then return end

    character:setLockingInteractable(self.interactable)
    self.network:sendToServer("sv_setOccupied", true)

    self.cl.character = character
    sm.camera.setCameraState(3)
    sm.camera.setFov(self.cl.fov)
end

function Binoculars:cl_unlockCharacter()
    self.cl.character:setLockingInteractable(nil)
    self.cl.character = nil
    self.network:sendToServer("sv_setOccupied", false)

    sm.camera.setFov(sm.camera.getDefaultFov())
    sm.camera.setCameraState(1)
end

---@param dt number deltaTime
function Binoculars:cl_e_updateCamera(dt)
    if not self.cl.hasViewport then return end

    local viewport = self.cl.viewport --[[@as Shape]]
    local pos = (viewport:getInterpolatedWorldPosition() + viewport.velocity * dt) + viewport.at * 0.125
    sm.camera.setPosition(pos)
    sm.camera.setDirection(viewport.at)
end
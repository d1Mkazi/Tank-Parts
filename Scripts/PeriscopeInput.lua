dofile("$SURVIVAL_DATA/Scripts/util.lua")

---@class PeriscopeInput : ShapeClass
PeriscopeInput = class()
PeriscopeInput.maxChildCount = -1
PeriscopeInput.connectionOutput = sm.interactable.connectionType.logic + sm.interactable.connectionType.bearing
PeriscopeInput.colorNormal = sm.color.new("5f8cc7ff")
PeriscopeInput.colorHighlight = sm.color.new("78a1d6ff")


--[[ SERVER ]]--

function PeriscopeInput:server_onCreate()
    self:sv_init()
end

function PeriscopeInput:server_onRefresh()
    self:sv_init()
    print("RELOADED")
end

function PeriscopeInput:sv_init()
    self.sv = {
        bearings = {
            ws = {},
            ad = {}
        }
    }
    self.saved = {}
end

function PeriscopeInput:server_onFixedUpdate(dt)
    local children = self.interactable:getChildren()
    if #children > 0 then
        for k, child in pairs(children) do
            if tostring(child.shape.uuid) == "66a069ab-4512-421d-b46b-7d14fb7f3b23" and (not self.sv.sight or self.sv.sight == child.shape) then
                self.sv.sight = child.shape
            else
                self.interactable:disconnect(child)
            end
        end
    else
        self.sv.sight = nil
    end

    if self.sv.sight ~= self.sv.sightOld then
        print("SIGHT UPDATE")
        self.network:sendToClients("cl_setSight", self.sv.sight)
        self.sv.sightOld = self.sv.sight
    end

    local bearings = self.interactable:getBearings()
    if bearings then
        for k, bearing in pairs(bearings) do
            if bearing.zAxis == self.shape.zAxis then
                table.insert(self.sv.bearings.ad, bearing)
            else
                table.insert(self.sv.bearings.ws, bearing)
            end
        end
    else
        self.sv.bearings = {}
    end
end

function PeriscopeInput:sv_setCharacter(character)
    self.sv.player = character ~= nil and character:getPlayer() or nil
    self.network:sendToClients("cl_setOccupied", character ~= nil and true or false)
end

---@param turn number
function PeriscopeInput:sv_turnWS(turn)
    for k, bearing in ipairs(self.sv.bearings.ws) do
        bearing:setTargetAngle(math.rad(15) * turn, 1, 25)
    end
    self.network:sendToClients("cl_setVerticalAnimation", turn)
end

---@param turn number
function PeriscopeInput:sv_turnAD(turn)
    for k, bearing in ipairs(self.sv.bearings.ad) do
        bearing:setTargetAngle(math.rad(20) * turn, 2, 25)
    end
    self.network:sendToClients("cl_setHorizontalAnimation", turn)
end

function PeriscopeInput:sv_resetAnimation(animation)
    self.network:sendToClients("cl_resetAnimation", animation)
end


--[[ CLIENT ]]--

function PeriscopeInput:client_onCreate()
    self:cl_init()
end

function PeriscopeInput:client_onRefresh()
    self:cl_init()
end

function PeriscopeInput:cl_init()
    self.cl = {
        verticalAnim = 0,
        horizontalAnim = 0,

        verticalProgress = 0.5,
        horizontalProgress = 0.5,

        verticalReset = false,
        horizontalReset = false
    }

    self.interactable:setAnimEnabled("RotVertical", true) -- 15
    self.interactable:setAnimProgress("RotVertical", 0.5)
    self.interactable:setAnimEnabled("RotHorizontal", true) -- 20
    self.interactable:setAnimProgress("RotHorizontal", 0.5)
end

function PeriscopeInput:client_onUpdate(dt)
    if self.cl.character then
        self:cl_updateCamera()
    end

    if self.cl.verticalAnim then
        self:cl_updateVerticalAnimation(dt)
    end
    if self.cl.horizontalAnim then
        self:cl_updateHorizontalAnimation(dt)
    end
end

function PeriscopeInput:client_onAction(action, state)
    if state then
        if action == 15 then
            self.cl.character:setLockingInteractable(nil)
            self.cl.character = nil
            self.network:sendToServer("sv_setCharacter", nil)

            self.network:sendToServer("sv_turnWS", 0)
            self.network:sendToServer("sv_turnAD", 0)
            self.network:sendToServer("sv_resetAnimation", "vertical")
            self.network:sendToServer("sv_resetAnimation", "horizontal")

            sm.camera.setCameraState(1)

        elseif action >= 1 and action <= 4 then
            local actions = {
                [1] = "sv_turnAD", -- left
                [2] = "sv_turnAD", -- right
                [3] = "sv_turnWS", -- forward
                [4] = "sv_turnWS", -- backward
            }
            local args = {
                [1] = -1, -- left
                [2] = 1, -- right
                [3] = -1, -- forward
                [4] = 1, -- backward
            }

            self.network:sendToServer(actions[action], args[action])
        end
    else
        if action >= 1 and action <= 4 then
            local actions = {
                [1] = "sv_turnAD", -- left
                [2] = "sv_turnAD", -- right
                [3] = "sv_turnWS", -- forward
                [4] = "sv_turnWS", -- backward
            }
            local animations = {
                [1] = "horizontal",
                [2] = "horizontal",
                [3] = "vertical",
                [4] = "vertical"
            }

            self.network:sendToServer(actions[action], 0)
            self.network:sendToServer("sv_resetAnimation", animations[action])
        end
    end

    return true
end

function PeriscopeInput:client_canInteract(character)
    return not self.cl.occupied and self.cl.sight ~= nil
end

function PeriscopeInput:client_onInteract(character, state)
    if not state then return end

    character:setLockingInteractable(self.interactable)
    self.network:sendToServer("sv_setCharacter", character)

    self.cl.character = character
    sm.camera.setCameraState(2)
    self:cl_updateCamera()
end

function PeriscopeInput:cl_setOccupied(state)
    self.cl.occupied = state
end

function PeriscopeInput:cl_resetAnimation(animation)
    self.cl[animation.."Reset"] = true

    if self.cl[animation.."Progress"] ~= 0.5 then
        self.cl[animation.."Anim"] = self.cl[animation.."Progress"] > 0.5 and -3 or 3
    end
end

function PeriscopeInput:cl_updateCamera()
    local sight = self.cl.sight
    sm.camera.setDirection(sight.at)
    sm.camera.setPosition(sight.worldPosition + sight.at * 0.0025)
end

function PeriscopeInput:cl_setVerticalAnimation(turn) self.cl.verticalAnim = -3 * turn end

function PeriscopeInput:cl_setHorizontalAnimation(turn) self.cl.horizontalAnim = -3 * turn end

function PeriscopeInput:cl_updateVerticalAnimation(dt)
    if self.cl.verticalAnim then
        local progress = self.cl.verticalProgress + self.cl.verticalAnim * dt

        if self.cl.verticalReset then
            if progress > 1 then
                progress = 1
                self.cl.verticalAnim = -self.cl.verticalAnim
            elseif progress < 0 then
                progress = 0
                self.cl.verticalAnim = -self.cl.verticalAnim
            end

            if (self.cl.verticalProgress > 0.5 and progress <= 0.5) or (self.cl.verticalProgress < 0.5 and progress >= 0.5) then
                progress = 0.5
                self.cl.verticalReset = false
                self.cl.verticalAnim = 0
            end
        else
            if progress >= 1 then
                progress = 1
                self.cl.verticalAnim = 0
            elseif progress <= 0 then
                progress = 0
                self.cl.verticalAnim = 0
            end
        end

        self.interactable:setAnimProgress("RotVertical", progress)

        self.cl.verticalProgress = progress
    end
end

function PeriscopeInput:cl_updateHorizontalAnimation(dt)
    if self.cl.horizontalAnim then
        local progress = self.cl.horizontalProgress + self.cl.horizontalAnim * dt

        if self.cl.horizontalReset then
            if progress >= 1 then
                progress = 1
                self.cl.horizontalAnim = -self.cl.horizontalAnim
            elseif progress <= 0 then
                progress = 0
                self.cl.horizontalAnim = -self.cl.horizontalAnim
            end

            if (self.cl.horizontalProgress > 0.5 and progress <= 0.5) or (self.cl.horizontalProgress < 0.5 and progress >= 0.5) then
                progress = 0.5
                self.cl.horizontalReset = false
                self.cl.horizontalAnim = 0
            end
        else
            if progress >= 1 then
                progress = 1
                self.cl.horizontalAnim = 0
            elseif progress <= 0 then
                progress = 0
                self.cl.horizontalAnim = 0
            end
        end

        self.interactable:setAnimProgress("RotHorizontal", progress)

        self.cl.horizontalProgress = progress
    end
end

function PeriscopeInput:cl_setSight(sight)
    self.cl.sight = sight
end
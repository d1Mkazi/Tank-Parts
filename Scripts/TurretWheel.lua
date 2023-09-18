dofile("utils.lua")

---@class TurretWheel : ShapeClass
TurretWheel = class()
TurretWheel.maxChildCount = -1
TurretWheel.connectionOutput = sm.interactable.connectionType.bearing
TurretWheel.colorNormal = sm.color.new("af730dff")
TurretWheel.colorHighlight = sm.color.new("afa63eff")


function TurretWheel:server_onCreate()
    self:init()
end

function TurretWheel:server_onRefresh()
    self:init()
    print("RELOADED")
end

function TurretWheel:init()
    self.saved = self.storage:load() or {
        slider = 1,
        velocity = 100,
        impulse = 1
    }

    self:sv_updateClientData()
end

function TurretWheel:sv_updateClientData()
    self.network:setClientData({ slider = self.saved.slider, velocity = self.saved.velocity, impulse = self.saved.impulse })
end

---@param character? Character
function TurretWheel:sv_setCharacter(character) self.network:sendToClients("cl_setCharacter", character) end

---@param value number
function TurretWheel:sv_setAnimation(value) self.network:sendToClients("cl_setAnimation", value) end

function TurretWheel:sv_setSteer(value)
    self.saved.slider = value

    local baseVelocity = 100
    local baseImpulse = 1

    self.saved.velocity = baseVelocity / value
    self.saved.impulse = baseImpulse * value

    self:sv_updateClientData()
    self.storage:save(self.saved)
end

---@param to number set 1 to turn right, set -1 to turn left and 0 to stop
function TurretWheel:sv_applyImpulse(to)
    local bearings = self.interactable:getBearings()
    for k, bearing in ipairs(bearings) do
        bearing:setMotorVelocity(self.cl.velocity * to, self.cl.impulse)
    end
end

function TurretWheel:client_onCreate()
    self.cl = {
        animUpdate = 0,
        animProgress = 0,
        gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/TurretSteer.layout")
    }
    self.cl.gui:createHorizontalSlider("steerSlider", 100, 1, "cl_changeSlider", false)
    self.interactable:setAnimEnabled("Rotation", true)
end

function TurretWheel:client_onUpdate(dt)
    self:cl_updateAnimation(dt)
end

function TurretWheel:client_onAction(action, state)
    local functions = {
        [1] = self.cl_turnLeft, -- left
        [2] = self.cl_turnRight, -- right
    }

    if state then
        if action == 15 then
            self:cl_unlockCharacter()
        end
    else
        self.network:sendToServer("sv_applyImpulse", 0)
        self.network:sendToServer("sv_setAnimation", 0)
    end

    if not hasIndex(functions, action) then return false end
    functions[action](self, state)

    return true
end

function TurretWheel:client_onClientDataUpdate(data, channel)
    for k, v in pairs(data) do
        self.cl[k] = v
    end
end

function TurretWheel:client_canInteract(character)
    return self.cl.character == nil and true or false
end

function TurretWheel:client_onInteract(character, state)
    if not state then return end

    self:cl_lockCharacter(character)
end

function TurretWheel:client_canTinker(character)
    local settings = GetLocalization("base_Settings", sm.gui.getCurrentLanguage())
    sm.gui.setInteractionText("", sm.gui.getKeyBinding("Tinker", true), settings)
    return self.cl.character == nil and true or false
end

function TurretWheel:client_onTinker(character, state)
    if not state then return end
    if not self.cl.gui:isActive() then self.cl.gui:close() end

    local title = GetLocalization("steer_GuiTitle", sm.gui.getCurrentLanguage())
    self.cl.gui:setText("steerTitle", title)
    local speed = GetLocalization("steer_GuiSpeed", sm.gui.getCurrentLanguage())
    self.cl.gui:setText("steerSpeed", speed)
    local power = GetLocalization("steer_GuiPower", sm.gui.getCurrentLanguage())
    self.cl.gui:setText("steerPower", power)
    self.cl.gui:open()
    self.cl.gui:setSliderPosition("steerSlider", self.cl.slider - 1)
end

---@param turn boolean set true to start rotation and false to stop
function TurretWheel:cl_turnRight(turn)
    local bearings = self.interactable:getBearings()

    if turn then
        self.network:sendToServer("sv_applyImpulse", 1)
        self.network:sendToServer("sv_setAnimation", 0.6)
    else
        for k, bearing in ipairs(bearings) do
            bearing:setMotorVelocity(0, self.cl.impulse / 3 * 2)
        end
    end
end

---@param turn boolean set true to start rotation and false to stop
function TurretWheel:cl_turnLeft(turn)
    local bearings = self.interactable:getBearings()

    if turn then
        self.network:sendToServer("sv_applyImpulse", -1)
        self.network:sendToServer("sv_setAnimation", -0.6)
    else
        for k, bearing in ipairs(bearings) do
            bearing:setMotorVelocity(0, self.cl.impulse / 3 * 2)
        end
    end
end

---@param character Character
function TurretWheel:cl_lockCharacter(character)
    character:setLockingInteractable(self.interactable)
    self.network:sendToServer("sv_setCharacter", character)
end

function TurretWheel:cl_unlockCharacter()
    self.cl.character:setLockingInteractable(nil)
    self.network:sendToServer("sv_setCharacter", nil)

    for k, func in pairs({self.cl_turnLeft, self.cl_turnRight}) do
        func(self, false)
    end

    self.cl.animUpdate = 0
end

function TurretWheel:cl_updateAnimation(dt)
    if not self.cl.animUpdate then return end

    local progress = self.cl.animProgress + self.cl.animUpdate * dt

    local step = 1 -- DEBUG
    if progress >= 1 then
        progress = progress - step
    elseif progress <= 0 then
        progress = progress + step
    end

    self.interactable:setAnimProgress("Rotation", progress)
    self.cl.animProgress = progress
end

function TurretWheel:cl_setAnimation(value) self.cl.animUpdate = value end

function TurretWheel:cl_changeSlider(value) self.network:sendToServer("sv_setSteer", value + 1) end

---@param character? Character
function TurretWheel:cl_setCharacter(character) self.cl.character = character end
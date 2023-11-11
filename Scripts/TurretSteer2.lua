dofile("utils.lua")
dofile("localization.lua")

---@class TurretSteer2 : ShapeClass
TurretSteer2 = class()
TurretSteer2.maxChildCount = -1
TurretSteer2.connectionOutput = sm.interactable.connectionType.bearing
TurretSteer2.colorNormal = sm.color.new("af730dff")
TurretSteer2.colorHighlight = sm.color.new("afa63eff")


function TurretSteer2:server_onCreate()
    self:init()
end

function TurretSteer2:server_onRefresh()
    self:init()
    print("RELOADED")
end

function TurretSteer2:init()
    self.sv = {
        to = 0
    }

    self.saved = self.storage:load() or {
        slider = 0,
        maxSpeed = 0.1
    }

    self:sv_applyImpulse({ to = 0 })
    self.network:setClientData({ slider = self.saved.slider, speed = self.saved.maxSpeed})
end

---@param character? Character
function TurretSteer2:sv_setCharacter(character) self.network:sendToClients("cl_setCharacter", character) end

function TurretSteer2:sv_setSteer(slider)
    self.saved.slider = slider
    self.saved.maxSpeed = (slider + 1) / 10

    self:sv_applyImpulse({ to = 0 })

    self.network:setClientData({ slider = slider, speed = self.saved.maxSpeed })
    self.storage:save(self.saved)
end

---@param args table to: set 1 to turn right, set -1 to turn left and 0 to stop\nspeed - rotation speed
function TurretSteer2:sv_applyImpulse(args)
    local to, speed = args.to or self.sv.to, args.speed ~= nil and args.speed or 0
    local bearings = self.interactable:getBearings()
    if to ~= 0 then
        for k, bearing in ipairs(bearings) do
            bearing:setMotorVelocity(speed * to, 1000)
        end
    else
        for k, bearing in ipairs(bearings) do
            bearing:setTargetAngle(bearing.angle * (bearing.reversed == true and 1 or -1), 5, 1000)
        end
    end

    self.sv.to = to
    self.network:sendToClients("cl_setAnimation", { to = to, speed = speed })
end

function TurretSteer2:client_onCreate()
    self.cl = {
        animUpdate = 0,
        animProgress = 0,
        gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/TurretSteer.layout")
    }

    self.cl.gui:createHorizontalSlider("steerSlider", 10, 1, "cl_changeSlider", true)
    self.interactable:setAnimEnabled("Rotation", true)
end

function TurretSteer2:client_onDestroy()
    if not self.cl.character then return end

    self.cl.character:setLockingInteractable(nil)
end

function TurretSteer2:client_onUpdate(dt)
    self:cl_updateAnimation(dt)
end

function TurretSteer2:client_onAction(action, state)
    if state then
        if action == 15 then -- Use (E)
            self.cl.character:setLockingInteractable(nil)
            self.network:sendToServer("sv_setCharacter", nil)
            self.network:sendToServer("sv_applyImpulse", { to = 0 })

            local text = GetLocalization("steer_MsgExit", sm.gui.getCurrentLanguage())
            sm.gui.displayAlertText(text, 2)

        elseif action >= 1 and action <= 4 then
            local args = {
                [1] = -1, -- left
                [2] = 1, -- right
            }

            self.network:sendToServer("sv_applyImpulse", { to = args[action], speed = self.cl.speed })

        elseif action == 5 or action == 6 then
            local speedUpdate = {
                [5] = 1,
                [6] = -1
            }
            local multiplier = speedUpdate[action]

            local speed = self.cl.speed + 0.1 * multiplier

            local maxSpeed = (self.cl.slider + 1) / 10
            if speed < 0.1 then
                speed = 0.1
            elseif speed >= maxSpeed then
                speed = maxSpeed
            end
            speed = math.floor(speed * 10) / 10

            self.cl.speed = speed
            local text = GetLocalization("steer_MsgRotSpeed", sm.gui.getCurrentLanguage())
            sm.gui.displayAlertText(text.." "..tostring(speed * 10), 2)
            self.network:sendToServer("sv_applyImpulse", { speed = speed })
        end
    else
        if action ~= 5 and action ~= 6 then
            self.network:sendToServer("sv_applyImpulse", { to = 0 })
        end
    end

    return true
end

function TurretSteer2:client_onClientDataUpdate(data)
    for k, v in pairs(data) do
        self.cl[k] = v
    end
end

function TurretSteer2:client_canInteract(character)
    return not self.cl.character
end

function TurretSteer2:client_onInteract(character, state)
    if not state then return end

    character:setLockingInteractable(self.interactable)
    self.network:sendToServer("sv_setCharacter", character)

    local text = GetLocalization("steer_MsgEnter", sm.gui.getCurrentLanguage())
    sm.gui.displayAlertText(text, 2)
end

function TurretSteer2:client_canTinker(character)
    local settings = GetLocalization("base_Settings", sm.gui.getCurrentLanguage())
    sm.gui.setInteractionText("", sm.gui.getKeyBinding("Tinker", true), settings)
    return true
end

function TurretSteer2:client_onTinker(character, state)
    if not state then return end
    if not self.cl.gui:isActive() then self.cl.gui:close() end

    local title = GetLocalization("steer_GuiTitle", sm.gui.getCurrentLanguage())
    self.cl.gui:setText("steerTitle", title)
    self.cl.gui:open()
    self.cl.gui:setSliderPosition("steerSlider", self.cl.slider)
end

function TurretSteer2:cl_updateAnimation(dt)
    if not self.cl.animUpdate then return end

    local progress = self.cl.animProgress + self.cl.animUpdate * dt

    if progress >= 1 then
        progress = progress - 1
    elseif progress <= 0 then
        progress = progress + 1
    end

    self.interactable:setAnimProgress("Rotation", progress)
    self.cl.animProgress = progress
end

function TurretSteer2:cl_setAnimation(args)
    self.cl.animUpdate = args.speed * args.to
end

function TurretSteer2:cl_changeSlider(value) self.network:sendToServer("sv_setSteer", value) end

---@param character? Character
function TurretSteer2:cl_setCharacter(character) self.cl.character = character end
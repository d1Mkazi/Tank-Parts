dofile("utils.lua")
dofile("localization.lua")

---@class TurretSteer2 : ShapeClass
TurretSteer2 = class()
TurretSteer2.maxChildCount = -1
TurretSteer2.connectionOutput = sm.interactable.connectionType.bearing + sm.interactable.connectionType.power
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
        maxSpeed = 0.1,
        WSmode = false
    }

    self:sv_applyImpulse({ to = 0 })
    self.network:setClientData({ slider = self.saved.slider, speed = self.saved.maxSpeed, WSmode = self.saved.WSmode })
end

function TurretSteer2:server_onFixedUpdate(dt)
    local bearings = self.interactable:getBearings()
    if #bearings > 0 then
        self.interactable.power = -math.floor((math.deg(bearings[1].angle) + 0.5) * 100) * 0.01
    else
        self.interactable.power = 0
    end
end

---@param occupied boolean
function TurretSteer2:sv_setOccupied(occupied)
    self.network:setClientData({ occupied = occupied })
end

function TurretSteer2:sv_setSteer(slider)
    self.saved.slider = slider
    self.saved.maxSpeed = (slider + 1) / 10

    self:sv_applyImpulse({ to = 0 })

    self.network:setClientData({ slider = slider, speed = self.saved.maxSpeed })
    self.storage:save(self.saved)
end

---@param args table to: set 1 to turn right, set -1 to turn left and 0 to stop\nspeed: rotation speed
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
    self.network:sendToClients("cl_playSound", { play = to ~= 0 and true or false, speed = speed })
end

function TurretSteer2:sv_stopSound()
    self.network:sendToClients("cl_playSound", { play = false })
end

function TurretSteer2:sv_setMode(mode)
    self.saved.WSmode = mode
    self.network:setClientData({ WSmode = mode })
    self.storage:save(self.saved)
end

function TurretSteer2:client_onCreate()
    self.cl = {
        animUpdate = 0,
        animProgress = 0,
        gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/TurretSteer.layout"),
        effect = sm.effect.createEffect("Steer - Rotation", self.interactable),
        occupied = false
    }

    self.cl.gui:createHorizontalSlider("steerSlider", 10, 1, "cl_changeSlider", true)
    self.cl.gui:setButtonCallback("steerMode", "cl_changeMode")
    self.interactable:setAnimEnabled("Rotation", true)
end

function TurretSteer2:client_onDestroy()
    if not self.cl.character then return end

    self.cl.character:setLockingInteractable(nil)
end

function TurretSteer2:client_onUpdate(dt)
    self:cl_updateAnimation(dt)
    self:cl_updateSound()
end

function TurretSteer2:client_onAction(action, state)
    if state then
        if action == 15 then -- Use (E)
            self.cl.character:setLockingInteractable(nil)
            self.network:sendToServer("sv_setOccupied", false)
            self.network:sendToServer("sv_applyImpulse", { to = 0 })

            local text = GetLocalization("steer_MsgExit", sm.gui.getCurrentLanguage())
            sm.gui.displayAlertText(text, 2)

        elseif (action == 1 or action == 2) and not self.cl.WSmode then
            local args = {
                [1] = -1, -- left
                [2] = 1, -- right
            }

            self.network:sendToServer("sv_applyImpulse", { to = args[action], speed = self.cl.speed })

        elseif (action == 3 or action == 4) and self.cl.WSmode then
            local args = {
                [3] = -1, -- left
                [4] = 1, -- right
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
            elseif speed > maxSpeed then
                speed = maxSpeed
            end
            speed = math.floor(speed * 10 + 0.4) / 10

            self.cl.speed = speed
            local text = GetLocalization("steer_MsgRotSpeed", sm.gui.getCurrentLanguage())
            sm.gui.displayAlertText(text.." "..tostring(speed * 10), 2)
            self.network:sendToServer("sv_stopSound")
            self.network:sendToServer("sv_applyImpulse", { speed = speed })
        end
    else
        if action >= 1 and action <= 4 then
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
    return not self.cl.occupied
end

function TurretSteer2:client_onInteract(character, state)
    if not state then return end

    character:setLockingInteractable(self.interactable)
    self.cl.character = character
    self.network:sendToServer("sv_setOccupied", true)

    local text = GetLocalization("steer_MsgEnter", sm.gui.getCurrentLanguage())
    sm.gui.displayAlertText(text, 2)
end

function TurretSteer2:client_canTinker(character)
    sm.gui.setInteractionText("", sm.gui.getKeyBinding("Tinker", true), GetLocalization("base_Settings", sm.gui.getCurrentLanguage()))
    return not self.cl.occupied
end

function TurretSteer2:client_onTinker(character, state)
    if not state then return end
    if not self.cl.gui:isActive() then self.cl.gui:close() end

    self.cl.gui:setText("steerTitle", GetLocalization("steer_GuiTitle", sm.gui.getCurrentLanguage()))
    self.cl.gui:setText("steerPower", GetLocalization("steer_GuiMaxSpeed", sm.gui.getCurrentLanguage()))
    self.cl.gui:setText("steerSpeed", GetLocalization("steer_GuiMinSpeed", sm.gui.getCurrentLanguage()))
    self.cl.gui:setText("steerMode_text", GetLocalization("steer_GuiMode", sm.gui.getCurrentLanguage()))
    self.cl.gui:setText("steerMode", self.cl.WSmode == true and "WS" or "AD")
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

function TurretSteer2:cl_changeSlider(value)
    self.network:sendToServer("sv_setSteer", value)
end

function TurretSteer2:cl_playSound(args)
    local play, speed = args.play, args.speed or 0
    if play then
        local effect = self.cl.effect
        effect:setParameter("CAE_Pitch", speed * 4)
        effect:start()

        self.cl.effectPlay = true
    else
        self.cl.effect:stop()
        self.cl.effectPlay = false
    end
end

function TurretSteer2:cl_updateSound()
    if self.cl.effectPlay and self.cl.effect:isDone() then
        self.cl.effect:start()
    end
end

function TurretSteer2:cl_changeMode()
    self.network:sendToServer("sv_setMode", not self.cl.WSmode)
    self.cl.gui:setText("steerMode", self.cl.WSmode ~= true and "WS" or "AD")
end
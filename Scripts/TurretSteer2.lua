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
        maxSpeed = 1,
        WSmode = false
    }

    self.interactable.publicData = { smart_values = { ["Angle"] = 0 } }

    self.network:setClientData({ speed = self.saved.maxSpeed, maxSpeed = self.saved.maxSpeed, WSmode = self.saved.WSmode })
end

function TurretSteer2:server_onFixedUpdate(dt)
    local bearings = self.interactable:getBearings()
    if #bearings > 0 then
        self.interactable.publicData.smart_values["Angle"] = -math.floor((math.deg(bearings[getFirstIndex(bearings)].angle) + 0.5) * 100) * 0.01
    end
end

---@param occupied boolean
function TurretSteer2:sv_setOccupied(occupied)
    self.network:setClientData({ occupied = occupied })
end

function TurretSteer2:sv_setSteer(value)
    value = value + 1
    self.saved.maxSpeed = value

    self:sv_applyImpulse({ to = 0 })

    self.network:setClientData({ speed = value, maxSpeed = value })
    self.storage:save(self.saved)
end

---@param args table to: set 1 to turn right, set -1 to turn left and 0 to stop\nspeed: rotation speed
function TurretSteer2:sv_applyImpulse(args)
    local to, speed = args.to or self.sv.to, (args.speed ~= nil and args.speed or 0) * 0.1
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
        maxSpeed = 1,
        speed = 1,
        effect = sm.effect.createEffect("Steer - Rotation", self.interactable),
        occupied = false,
        WSmode = false
    }

    local gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/TurretSteer.layout")
    gui:createHorizontalSlider("ts_speed_slider", 10, 1, "cl_changeSpeed")
    gui:setIconImage("ts_icon", self.shape.uuid)

    gui:setButtonCallback("ts_mode_ws", "cl_setMode")
    gui:setButtonCallback("ts_mode_ad", "cl_setMode")

    self.cl.gui = gui

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

            local speed = self.cl.speed + 1 * multiplier

            local maxSpeed = self.cl.maxSpeed
            if speed < 1 then
                speed = 1
            elseif speed > maxSpeed then
                speed = maxSpeed
            end

            self.cl.speed = speed
            sm.gui.displayAlertText(GetLocalization("steer_MsgRotSpeed", getLang()):format(speed), 2)
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

    local gui = self.cl.gui
    gui:setText("ts_title", GetLocalization("base_Settings", getLang()))
    gui:setText("ts_name", sm.shape.getShapeTitle(self.shape.uuid))
    gui:setText("ts_speed_header", GetLocalization("ts_GuiSpeed", getLang()))
    gui:setSliderPosition("ts_speed_slider", self.cl.maxSpeed - 1)
    self.cl.gui:setText("ts_speed_display", GetLocalization("td_GuiDisplay", getLang()):format(self.cl.maxSpeed))
    gui:setText("ts_mode_header", GetLocalization("ts_GuiMode", getLang()))
    gui:setButtonState("ts_mode_ws", self.cl.WSmode)
    gui:setButtonState("ts_mode_ad", not self.cl.WSmode)
    gui:setText("ts_mode_ws", sm.gui.getKeyBinding("Forward")..sm.gui.getKeyBinding("Backward"))
    gui:setText("ts_mode_ad", sm.gui.getKeyBinding("StrafeLeft")..sm.gui.getKeyBinding("StrafeRight"))
    gui:open()
end

function TurretSteer2:cl_updateAnimation(dt)
    if not self.cl.animUpdate then return end

    local progress = self.cl.animProgress + self.cl.animUpdate * dt

    self.interactable:setAnimProgress("Rotation", progress)
    self.cl.animProgress = progress
end

function TurretSteer2:cl_setAnimation(args)
    self.cl.animUpdate = args.speed * args.to
end

function TurretSteer2:cl_changeSpeed(value)
    self.cl.gui:setText("ts_speed_display", GetLocalization("td_GuiDisplay", getLang()):format(value + 1))
    self.network:sendToServer("sv_setSteer", value)
end

function TurretSteer2:cl_playSound(args)
    local play, speed = args.play, args.speed or 0
    if play then
        local effect = self.cl.effect
        effect:setParameter("CAE_Pitch", speed * 4)
        effect:setAutoPlay(true)

        self.cl.effectPlay = true
    else
        self.cl.effect:setAutoPlay(false)
        self.cl.effect:stop()
        self.cl.effectPlay = false
    end
end

function TurretSteer2:cl_setMode(button, state)
    local gui = self.cl.gui
    local WSmode = button == "ts_mode_ws"

    gui:setButtonState("ts_mode_ws", WSmode)
    gui:setButtonState("ts_mode_ad", not WSmode)

    self.network:sendToServer("sv_setMode", WSmode)
end
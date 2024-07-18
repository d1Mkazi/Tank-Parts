---@diagnostic disable: lowercase-global
dofile("utils.lua")
dofile("localization.lua")

---@class TargetDevice : ShapeClass
TargetDevice = class()
TargetDevice.maxChildCount = -1
TargetDevice.connectionOutput = sm.interactable.connectionType.bearing + sm.interactable.connectionType.power + sm.interactable.connectionType.logic
TargetDevice.colorNormal = sm.color.new("af730dff")
TargetDevice.colorHighlight = sm.color.new("afa63eff")


local BINOCULARS = sm.uuid.new("e98eecc3-2665-49a6-9a15-86e591ab4e5a")

--[[ SERVER ]]--

function TargetDevice:server_onCreate()
    self:init()
end

function TargetDevice:server_onRefresh()
    self:init()
    print("RELOADED")
end

function TargetDevice:init()
    self.sv = {
        bearings = {
            ---@type Joint[]
            ws = {},
            ---@type Joint[]
            ad = {}
        },
        turnDirection = {
            ws = 0,
            ad = 0
        },
        sound = {
            ws = false,
            ad = false
        },
        active = {
            left = false,
            right= false
        },

        binoculars = nil,
        hasBinoculars = false
    }

    self.saved = self.storage:load() or {
        maxSpeed = 10,
        swap = {
            vertical = false,
            horizontal = false,
            global = false
        },
        secondary = {
            RMB = true,
            button = true
        }
    }

    self.interactable.publicData = { smart_values = { ["Vertical Angle"] = 0, ["Horizontal Angle"] = 0, ["Left Mouse"] = false, ["Secondary Action"] = false } }

    self.network:setClientData({ maxSpeed = self.saved.maxSpeed, swap = self.saved.swap, secondary = self.saved.secondary })
end

function TargetDevice:server_onFixedUpdate(dt)
    ---@type Interactable[]
    local children = self.interactable:getChildren(1) -- sm.interactable.connectionType.logic
    if #children > 0 then
        for k, child in ipairs(children) do
            if child.shape.uuid == BINOCULARS then
                if self.sv.binoculars and child ~= self.sv.binoculars then
                    self.interactable:disconnect(child)
                elseif not self.sv.binoculars then
                    self.sv.binoculars = child
                    self.network:setClientData({ binoculars = child })
                end
            end
        end
    end

    local binoculars = self.cl.binoculars
    if binoculars ~= nil and sm.exists(binoculars) then
        local hasBinoculars = binoculars.publicData.hasViewport

        if hasBinoculars ~= self.sv.hasBinoculars then
            self.sv.hasBinoculars = hasBinoculars
            self.network:setClientData({ hasBinoculars = hasBinoculars })
        end
    end

    if not isAnyOf(self.sv.binoculars, children) then
        self.sv.binoculars = nil
        self.network:setClientData({ hasBinoculars = false })
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

    if #ws > 0 then
        local angle = math.floor(ws[getFirstIndex(ws)].angle * 100) * 0.01
        if angle ~= self.interactable.publicData.smart_values["Vertical Angle"] then
            self.interactable.publicData.smart_values["Vertical Angle"] = angle
        end
    end
    if #ad > 0 then
        local angle = math.floor(ad[getFirstIndex(ad)].angle * 100) * 0.01
        if angle ~= self.interactable.publicData.smart_values["Horizontal Angle"] then
            self.interactable.publicData.smart_values["Horizontal Angle"] = angle
        end
    end
end

---@param occupied boolean
function TargetDevice:sv_setOccupied(occupied)
    self.network:setClientData({ occupied = occupied })
end

---@param args table to: set 1 to turn right, set -1 to turn left and 0 to stop\nspeed: rotation speed
function TargetDevice:sv_applyImpulseWS(args)
    local to, speed = args.to or self.sv.turnDirection.ws, (args.speed ~= nil and args.speed or 0) * 0.1
    local bearings = self.sv.bearings.ws
    if to ~= 0 then
        self.sv.sound.ws = true
        for k, bearing in pairs(bearings) do
            local modifier = self.saved.swap.vertical == true and 1 or -1
            bearing:setMotorVelocity(speed * to * modifier, 1000)
        end
        self.network:sendToClients("cl_setAnimation", { anim = "RotVertical", target = to == -1 and 0 or 1})
        if not self.sv.sound.ad then
            self.network:sendToClients("cl_playSound", { play = true, speed = speed })
        end
    else
        self.sv.sound.ws = false
        for k, bearing in pairs(bearings) do
            bearing:setTargetAngle(bearing.angle * (bearing.reversed == true and 1 or -1), 5, 1000)
        end
        self.network:sendToClients("cl_setAnimation", { anim = "RotVertical", target = 0.5})
        if not self.sv.sound.ad then
            self.network:sendToClients("cl_playSound", { play = false })
        end
    end

    self.sv.turnDirection.ws = to
end

---@param args table `to`: set 1 to turn right, set -1 to turn left and 0 to stop `speed`: rotation speed
function TargetDevice:sv_applyImpulseAD(args)
    local to, speed = args.to or self.sv.turnDirection.ad, (args.speed ~= nil and args.speed or 0) * 0.1
    local bearings = self.sv.bearings.ad
    if to ~= 0 then
        self.sv.sound.ad = true
        for k, bearing in pairs(bearings) do
            local modifier = self.saved.swap.vertical == false and 1 or -1
            bearing:setMotorVelocity(speed * to * modifier, 1000)
        end
        self.network:sendToClients("cl_setAnimation", { anim = "RotHorizontal", target = to == -1 and 0 or 1})
        if not self.sv.sound.ws then
            self.network:sendToClients("cl_playSound", { play = true, speed = speed })
        end
    else
        self.sv.sound.ad = false
        for k, bearing in pairs(bearings) do
            bearing:setTargetAngle(bearing.angle * (bearing.reversed == true and 1 or -1), 5, 1000)
        end
        self.network:sendToClients("cl_setAnimation", { anim = "RotHorizontal", target = 0.5})
        if not self.sv.sound.ws then
            self.network:sendToClients("cl_playSound", { play = false })
        end
    end

    self.sv.turnDirection.ad = to
end

---@param args table possible keys: `button: string (Left|Right)`, `state: boolean`
function TargetDevice:sv_pressButton(args)
    local smart_value
    if args.button == "Left" then
        self.interactable.active = args.state
        smart_value = "Left Mouse"
    else
        smart_value = "Secondary Action"
    end
    self.interactable.publicData.smart_values[smart_value] = args.state


    self.network:sendToClients("cl_setAnimation", { anim = "Press"..args.button, target = args.state == true and 1 or 0 })
end

function TargetDevice:sv_setMaxSpeed(value)
    self.saved.maxSpeed = value
    self.network:setClientData({ maxSpeed = value, speed = value })
    self.storage:save(self.saved)
end

function TargetDevice:sv_setSpeed(value)
    if self.sv.turnDirection.ws ~= 0 then
        self:sv_applyImpulseWS({ to = self.sv.turnDirection.ws, speed = value })
    end

    if self.sv.turnDirection.ad ~= 0 then
        self:sv_applyImpulseAD({ to = self.sv.turnDirection.ad, speed = value })
    end
end

function TargetDevice:sv_stopSound()
    self.sv.sound = { ws = false, ad = false }
    self.network:sendToClients("cl_playSound", { play = false })
end

---@param args table possible keys: `controls: string`, `state: boolean`
function TargetDevice:sv_swapControls(args)
    self.saved.swap[args.controls] = args.state
    self.network:setClientData({ swap = self.saved.swap })
    self.storage:save(self.saved)
end

function TargetDevice:sv_setSecondary(rmb)
    self.saved.secondary.RMB = rmb
    self.network:setClientData({ secondary = self.saved.secondary })
    self.storage:save(self.saved)
end

function TargetDevice:sv_setButton(button)
    self.saved.secondary.button = button
    self.network:setClientData({ secondary = self.saved.secondary })
    self.storage:save(self.saved)
end


--[[ CLIENT ]]--

function TargetDevice:client_onCreate()
    self.cl = {
        effect = sm.effect.createEffect("TargetDevice - Loop", self.interactable),
        effectPlay = false,
        effectTimer = 0,
        occupied = false,
        secondaryActive = false,
        speed = 10,
        maxSpeed = 10,
        isAiming = false,
        binoculars = nil,
        fov = sm.camera.getDefaultFov(),
        anims = {
            RotHorizontal = {
                progress = 0,
                update = true,
                target = 0.5
            },
            RotVertical = {
                progress = 0,
                update = true,
                target = 0.5
            },
            PressRight = {
                progress = 0,
                update = false,
                target = 0
            },
            PressLeft = {
                progress = 0,
                update = false,
                target = 0
            }
        },
        swap = {
            vertical = false,
            horizontal = false,
            global = false
        },
        secondary = {
            RMB = true,
            button = true
        }
    }

    local gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/TargetDevice.layout")
    gui:createHorizontalSlider("td_speed_slider", 20, 0, "cl_onSpeedChange")
    gui:setIconImage("td_icon", self.shape.uuid)

    gui:setButtonCallback("td_controls_swap", "cl_swapControls")
    gui:setButtonCallback("td_controls_verticalSwap", "cl_invertControls")
    gui:setButtonCallback("td_controls_horizontalSwap", "cl_invertControls")

    gui:setButtonCallback("td_secondary_button_rmb", "cl_setSecondary")
    gui:setButtonCallback("td_secondary_button_space", "cl_setSecondary")

    gui:setButtonCallback("td_secondary_mode_button", "cl_setButton")
    gui:setButtonCallback("td_secondary_mode_toggle", "cl_setButton")

    self.cl.gui = gui

    self.interactable:setAnimEnabled("RotHorizontal", true)
    self.interactable:setAnimEnabled("RotVertical", true)
    self.interactable:setAnimEnabled("PressRight", true)
    self.interactable:setAnimEnabled("PressLeft", true)
end

function TargetDevice:client_onDestroy()
    if not self.cl.character then return end

    self.cl.character:setLockingInteractable(nil)
end

function TargetDevice:client_onUpdate(dt)
    local anims = self.cl.anims
    for anim, _ in pairs(anims) do
        if anims[anim].update then
            self:cl_updateAnimation(anim, dt)
        end
    end

    if self.cl.isAiming then
        self:cl_updateCamera(dt)
    end
end

function TargetDevice:client_onFixedUpdate(dt)
    local timer = self.cl.effectTimer
    if timer > 0 then
        timer = timer - dt
        if timer <= 0 then
            timer = 0

            self.cl.effect:setAutoPlay(true)
        end
        self.cl.effectTimer = timer
    end
end

function TargetDevice:client_onAction(action, state)
    local swap = self.cl.swap
    if state then
        if action == 15 then -- Use (E)
            self.cl.character:setLockingInteractable(nil)
            self.network:sendToServer("sv_setOccupied", false)
            self.network:sendToServer("sv_applyImpulseWS", { to = 0 })
            self.network:sendToServer("sv_applyImpulseAD", { to = 0 })
            self.network:sendToServer("sv_pressButton", { button = "Right", state = false })
            self.network:sendToServer("sv_pressButton", { button = "Left", state = false })
            self.cl.secondaryActive = false
            self.cl.isAiming = false
            sm.camera.setCameraState(1)
            sm.camera.setFov(sm.camera.getDefaultFov())

            local text = GetLocalization("steer_MsgExit", sm.gui.getCurrentLanguage())
            sm.gui.displayAlertText(text, 2)

        elseif (swap.global and (action == 3 or action == 4)) or (not swap.global and (action == 1 or action == 2)) then -- A/D
            local args = {
                [1] = -1, -- A
                [2] = 1, -- D
                [3] = 1, -- W
                [4] = -1, -- S
            }

            self.network:sendToServer("sv_applyImpulseAD", { to = args[action] * (self.cl.swap.horizontal == true and -1 or 1), speed = self.cl.speed })

        elseif (swap.global and (action == 1 or action == 2)) or (not swap.global and (action == 3 or action == 4)) then -- W/S
            local args = {
                [1] = -1, -- A
                [2] = 1, -- D
                [3] = 1, -- W
                [4] = -1, -- S
            }

            self.network:sendToServer("sv_applyImpulseWS", { to = args[action]  * (self.cl.swap.vertical == true and -1 or 1), speed = self.cl.speed })

        elseif action == 5 or action == 6 then -- 1/2
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
            self.network:sendToServer("sv_setSpeed", speed)

        elseif (action == 18 and self.cl.secondary.RMB) or (action == 16 and not self.cl.secondary.RMB) then -- RMB
            if not self.cl.secondary.button then
                self.cl.secondaryActive = not self.cl.secondaryActive
                self.network:sendToServer("sv_pressButton", { button = "Right", state = self.cl.secondaryActive })
            else
                self.network:sendToServer("sv_pressButton", { button = "Right", state = true })
            end

        elseif (action == 18 and not self.cl.secondary.RMB) or (action == 16 and self.cl.secondary.RMB) then -- SPACE (aim)
            if not self.cl.hasBinoculars then return true end

            self.cl.isAiming = not self.cl.isAiming
            if self.cl.isAiming then
                sm.camera.setFov(self.cl.fov)
                sm.camera.setCameraState(3)
            else
                sm.camera.setFov(sm.camera.getDefaultFov())
                sm.camera.setCameraState(1)
            end

        elseif action == 19 then -- LMB
            self.network:sendToServer("sv_pressButton", { button = "Left", state = true })

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
        end
    else
        if (swap.global and (action == 3 or action == 4)) or (not swap.global and (action == 1 or action == 2)) then -- A/D
            self.network:sendToServer("sv_applyImpulseAD", { to = 0 })

        elseif (swap.global and (action == 1 or action == 2)) or (not swap.global and (action == 3 or action == 4)) then -- W/S
            self.network:sendToServer("sv_applyImpulseWS", { to = 0 })

        elseif self.cl.secondary.button and ((action == 18 and self.cl.secondary.RMB) or (action == 16 and not self.cl.secondary.RMB)) then -- RMB
            self.network:sendToServer("sv_pressButton", { button = "Right", state = false })

        elseif action == 19 then -- LMB
            self.network:sendToServer("sv_pressButton", { button = "Left", state = false })
        end
    end

    return true
end

function TargetDevice:client_onClientDataUpdate(data)
    for k, v in pairs(data) do
        self.cl[k] = v
    end
end

function TargetDevice:client_canInteract(character)
    return not self.cl.occupied
end

function TargetDevice:client_onInteract(character, state)
    if not state then return end

    character:setLockingInteractable(self.interactable)
    self.cl.character = character
    self.network:sendToServer("sv_setOccupied", true)

    local text = GetLocalization("steer_MsgEnter", sm.gui.getCurrentLanguage())
    sm.gui.displayAlertText(text, 2)
end

function TargetDevice:client_canTinker()
    sm.gui.setInteractionText("", sm.gui.getKeyBinding("Tinker", true), GetLocalization("base_Settings", sm.gui.getCurrentLanguage()))
    return not self.cl.occupied
end

function TargetDevice:client_onTinker(character, state)
    if not state then return end
    if not self.cl.gui:isActive() then self.cl.gui:close() end

    local gui = self.cl.gui
    gui:setText("td_title", GetLocalization("base_Settings", getLang()))
    gui:setText("td_name", sm.shape.getShapeTitle(self.shape.uuid))

    gui:setText("td_controls_header", GetLocalization("td_GuiControls", getLang()))
    local ws = self.cl.swap.global == false and sm.gui.getKeyBinding("Forward")..sm.gui.getKeyBinding("Backward") or sm.gui.getKeyBinding("StrafeLeft")..sm.gui.getKeyBinding("StrafeRight")
    local ad = self.cl.swap.global == false and sm.gui.getKeyBinding("StrafeLeft")..sm.gui.getKeyBinding("StrafeRight") or sm.gui.getKeyBinding("Forward")..sm.gui.getKeyBinding("Backward")
    --sm.gui.getKeyBinding("Forward")..sm.gui.getKeyBinding("Backward") or sm.gui.getKeyBinding("Backward")..sm.gui.getKeyBinding("Forward"), sm.gui.getKeyBinding("StrafeLeft")..sm.gui.getKeyBinding("StrafeRight")
    gui:setText("td_controls_vertical", GetLocalization("td_GuiVertical", getLang()):format(ws))
    gui:setText("td_controls_horizontal", GetLocalization("td_GuiHorizontal", getLang()):format(ad))
    gui:setText("td_controls_swap", GetLocalization("td_GuiSwapControls", getLang()))

    gui:setText("td_speed_header", GetLocalization("td_GuiSpeed", getLang()))
    gui:setSliderPosition("td_speed_slider", self.cl.maxSpeed - 1)
    gui:setText("td_speed_display", GetLocalization("td_GuiDisplay", getLang()):format(self.cl.maxSpeed))

    gui:setText("td_secondary_header", GetLocalization("td_GuiSecondary", getLang()))
    gui:setText("td_secondary_button_text", GetLocalization("td_GuiButton", getLang()))
    gui:setText("td_secondary_button_rmb", sm.gui.getKeyBinding("Attack"):upper())
    gui:setButtonState("td_secondary_button_rmb", self.cl.secondary.RMB)
    gui:setText("td_secondary_button_space", sm.gui.getKeyBinding("Jump"):upper())
    gui:setButtonState("td_secondary_button_space", not self.cl.secondary.RMB)
    gui:setText("td_secondary_mode_text", GetLocalization("ts_GuiMode", getLang()))
    gui:setText("td_secondary_mode_button", GetLocalization("td_GuiButtonMode", getLang()))
    gui:setButtonState("td_secondary_mode_button", self.cl.secondary.button)
    gui:setText("td_secondary_mode_toggle", GetLocalization("td_GuiToggleMode", getLang()))
    gui:setButtonState("td_secondary_mode_toggle", not self.cl.secondary.button)

    gui:open()
end

function TargetDevice:cl_updateAnimation(anim, dt)
    local animation = self.cl.anims[anim]
    local progress = animation.progress
    local target = animation.target

    local modifier = target > progress and 5 or -5
    progress = progress + dt * modifier

    if (animation.progress > target and progress <= target) or (animation.progress < target and progress >= target) then
        progress = target
        animation.update = false
    end

    self.interactable:setAnimProgress(anim, progress)
    animation.progress = progress
end

---@param args table Possible keys are `anim: string` `target: number`
function TargetDevice:cl_setAnimation(args)
    self.cl.anims[args.anim].target = args.target
    self.cl.anims[args.anim].update = true
end

function TargetDevice:cl_playSound(args)
    if args.play then
        if not self.cl.effectPlay then
            sm.effect.playHostedEffect("TargetDevice - Start", self.interactable)
            local effect = self.cl.effect
            effect:setAutoPlay(true)
            self.cl.effectTimer = 0.5
        end

        self.cl.effectPlay = true
    else
        self.cl.effect:setAutoPlay(false)
        self.cl.effect:stop()

        self.cl.effectTimer = 0

        if self.cl.effectPlay then
            sm.effect.playHostedEffect("TargetDevice - End", self.interactable)
        end

        self.cl.effectPlay = false
    end
end

function TargetDevice:cl_onSpeedChange(value)
    self.cl.gui:setText("td_speed_display", GetLocalization("td_GuiDisplay", getLang()):format(value + 1))
    self.network:sendToServer("sv_setMaxSpeed", value + 1)
end

---@param button string
function TargetDevice:cl_invertControls(button)
    local swap = button:sub(13, #button - 4)
    local state = not self.cl.swap[swap]

    self.cl.swap[swap] = state
    self.cl.gui:setButtonState(button, state)
    self.network:sendToServer("sv_swapControls", { controls = swap, state = state })
end

function TargetDevice:cl_swapControls()
    local state = not self.cl.swap.global
    self.cl.swap.global = state
    self.network:sendToServer("sv_swapControls", { controls = "global", state = state })

    local ws = state == false and sm.gui.getKeyBinding("Forward")..sm.gui.getKeyBinding("Backward") or sm.gui.getKeyBinding("StrafeLeft")..sm.gui.getKeyBinding("StrafeRight")
    local ad = state == false and sm.gui.getKeyBinding("StrafeLeft")..sm.gui.getKeyBinding("StrafeRight") or sm.gui.getKeyBinding("Forward")..sm.gui.getKeyBinding("Backward")
    self.cl.gui:setText("td_controls_vertical", GetLocalization("td_GuiVertical", getLang()):format(ws))
    self.cl.gui:setText("td_controls_horizontal", GetLocalization("td_GuiHorizontal", getLang()):format(ad))
end

function TargetDevice:cl_setSecondary(button)
    local rmb = button:sub(21) == "rmb"
    self.network:sendToServer("sv_setSecondary", rmb)

    self.cl.gui:setButtonState("td_secondary_button_rmb", rmb)
    self.cl.gui:setButtonState("td_secondary_button_space", not rmb)
end

function TargetDevice:cl_setButton(button)
    local mode = button:sub(19) == "button"
    self.network:sendToServer("sv_setButton", mode)

    self.cl.gui:setButtonState("td_secondary_mode_button", mode)
    self.cl.gui:setButtonState("td_secondary_mode_toggle", not mode)
end

function TargetDevice:cl_updateCamera(dt)
    if not self.cl.hasBinoculars then
        self.cl.isAiming = false
        sm.camera.setCameraState(1)
        sm.camera.setFov(sm.camera.getDefaultFov())
        return
    end

    sm.event.sendToInteractable(self.cl.binoculars, "cl_e_updateCamera", dt)
end

---@param speed number the rotation speed
---@return number target the animation target
function getAnimTarget(speed)
    return speed
end
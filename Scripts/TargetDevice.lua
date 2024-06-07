dofile("utils.lua")
dofile("localization.lua")

---@class TargetDevice : ShapeClass
TargetDevice = class()
TargetDevice.maxChildCount = -1
TargetDevice.connectionOutput = sm.interactable.connectionType.bearing + sm.interactable.connectionType.power + sm.interactable.connectionType.logic
TargetDevice.colorNormal = sm.color.new("af730dff")
TargetDevice.colorHighlight = sm.color.new("afa63eff")

local Z = sm.vec3.new(0, 0, 1)


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

        goggles = nil
    }

    self.saved = self.storage:load() or {
        maxSpeed = 10,
        swap = {
            vertical = false,
            horizontal = false,
            global = false
        }
    }

    self:sv_applyImpulseWS({ to = 0 })
    self:sv_applyImpulseAD({ to = 0 })

    self.network:setClientData({ maxSpeed = self.saved.maxSpeed, swap = copyTable(self.saved.swap) })
end

function TargetDevice:server_onFixedUpdate(dt)
    ---@type Interactable[]
    local children = self.interactable:getChildren(1) -- sm.interactable.connectionType.logic
    if #children > 0 then
        for k, child in ipairs(children) do
            local uuid = tostring(child.shape.uuid)
            if uuid == "e98eecc3-2665-49a6-9a15-86e591ab4e5a" then
                if self.sv.goggles and child ~= self.sv.goggles then
                    self.interactable:disconnect(child)
                elseif not self.sv.goggles then
                    self.sv.goggles = child
                end
            end
        end
    end

    local bearings = self.interactable:getBearings()
    local ws, ad = self.sv.bearings.ws, self.sv.bearings.ad
    if #bearings ~= (#self.sv.bearings.ad + #self.sv.bearings.ws) then
        for k, bearing in ipairs(bearings) do
            if not (isAnyOf(bearing, ws) or isAnyOf(bearing, ad)) then
                bearing:setTargetAngle(bearing.angle * (bearing.reversed == true and 1 or -1), 5, 1000)
                if sameAxis(bearing.zAxis, Z) then
                    ad[#ad+1] = bearing
                else
                    ws[#ws+1] = bearing
                end
            end
        end

        for k, bearing in pairs(ws) do
            if not isAnyOf(bearing, bearings) then
                ws[k] = nil
            end
        end
        for k, bearing in pairs(ad) do
            if not isAnyOf(bearing, bearings) then
                ad[k] = nil
            end
        end
    elseif #bearings == 0 then
        self.sv.bearings = { ws = {}, ad = {} }
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
        for k, bearing in ipairs(bearings) do
            local modifier = xor(bearing.reversed, self.saved.swapVertical) == true and 1 or -1
            bearing:setMotorVelocity(speed * to * modifier, 1000)
        end
        self.network:sendToClients("cl_setAnimation", { anim = "RotVertical", target = to == -1 and 0 or 1})
        if not self.sv.sound.ad then
            self.network:sendToClients("cl_playSound", { play = true, speed = speed })
        end
    else
        self.sv.sound.ws = false
        for k, bearing in ipairs(bearings) do
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
        for k, bearing in ipairs(bearings) do
            local modifier = bearing.reversed == false and 1 or -1
            bearing:setMotorVelocity(speed * to * modifier, 1000)
        end
        self.network:sendToClients("cl_setAnimation", { anim = "RotHorizontal", target = to == -1 and 0 or 1})
        if not self.sv.sound.ws then
            self.network:sendToClients("cl_playSound", { play = true, speed = speed })
        end
    else
        self.sv.sound.ad = false
        for k, bearing in ipairs(bearings) do
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
    if args.button == "Left" then
        self.interactable.active = args.state
    end

    self.network:sendToClients("cl_setAnimation", { anim = "Press"..args.button, target = args.state == true and 1 or 0 })
end

function TargetDevice:sv_setMaxSpeed(value)
    self.saved.maxSpeed = value
    self.network:setClientData({ maxSpeed = value, speed = value })
    self.storage:save(self.saved)
end

function TargetDevice:sv_setSpeed(value)
    self:sv_stopSound()

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
    self.network:setClientData({ swap = copyTable(self.saved.swap) })
    self.storage:save(self.saved)
end


--[[ CLIENT ]]--

function TargetDevice:client_onCreate()
    self.cl = {
        effect = sm.effect.createEffect("Steer - Rotation", self.interactable),
        occupied = false,
        speed = 10,
        maxSpeed = 10,
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
        }
    }

    local gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/TargetDevice.layout")
    gui:createHorizontalSlider("td_speed_slider", 20, 0, "cl_onSpeedChange")
    gui:setIconImage("td_icon", self.shape.uuid)

    gui:setButtonCallback("td_controls_swap", "cl_swapControls")
    gui:setButtonCallback("td_controls_verticalSwap", "cl_invertControls")
    gui:setButtonCallback("td_controls_horizontalSwap", "cl_invertControls")

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
end

function TargetDevice:client_onAction(action, state)
    local swap = self.cl.swap
    if state then
        if action == 15 then -- Use (E)
            self.cl.character:setLockingInteractable(nil)
            self.network:sendToServer("sv_setOccupied", false)
            self.network:sendToServer("sv_applyImpulseWS", { to = 0 })
            self.network:sendToServer("sv_applyImpulseAD", { to = 0 })

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

        elseif action == 18 then -- RMB
            self.network:sendToServer("sv_pressButton", { button = "Right", state = true })

        elseif action == 19 then -- LMB
            self.network:sendToServer("sv_pressButton", { button = "Left", state = true })
        end
    else
        if (swap.global and (action == 3 or action == 4)) or (not swap.global and (action == 1 or action == 2)) then -- A/D
            self.network:sendToServer("sv_applyImpulseAD", { to = 0 })

        elseif (swap.global and (action == 1 or action == 2)) or (not swap.global and (action == 3 or action == 4)) then -- W/S
            self.network:sendToServer("sv_applyImpulseWS", { to = 0 })

        elseif action == 18 then -- RMB
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
    gui:setSliderPosition("td_speed_slider", self.cl.maxSpeed - 1)
    gui:setText("td_controls_header", GetLocalization("td_GuiControls", getLang()))
    local ws = self.cl.swap.global == false and sm.gui.getKeyBinding("Forward")..sm.gui.getKeyBinding("Backward") or sm.gui.getKeyBinding("StrafeLeft")..sm.gui.getKeyBinding("StrafeRight")
    local ad = self.cl.swap.global == false and sm.gui.getKeyBinding("StrafeLeft")..sm.gui.getKeyBinding("StrafeRight") or sm.gui.getKeyBinding("Forward")..sm.gui.getKeyBinding("Backward")
    --sm.gui.getKeyBinding("Forward")..sm.gui.getKeyBinding("Backward") or sm.gui.getKeyBinding("Backward")..sm.gui.getKeyBinding("Forward"), sm.gui.getKeyBinding("StrafeLeft")..sm.gui.getKeyBinding("StrafeRight")
    gui:setText("td_controls_vertical", GetLocalization("td_GuiVertical", getLang()):format(ws))
    gui:setText("td_controls_horizontal", GetLocalization("td_GuiHorizontal", getLang()):format(ad))
    gui:setText("td_controls_swap", GetLocalization("td_GuiSwapControls", getLang()))
    gui:setText("td_speed_header", GetLocalization("td_GuiSpeed", getLang()))
    gui:setText("td_speed_display", GetLocalization("td_GuiDisplay", getLang()):format(self.cl.maxSpeed))
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
        local effect = self.cl.effect
        effect:setParameter("CAE_Pitch", args.speed * 4)
        effect:setAutoPlay(true)

        self.cl.effectPlay = true
    else
        self.cl.effect:setAutoPlay(false)
        self.cl.effect:stop()
        self.cl.effectPlay = false
    end
end

function TargetDevice:cl_onSpeedChange(value)
    self.cl.gui:setText("td_speed_display", GetLocalization("td_GuiDisplay", getLang()):format(value + 1))
    self.network:sendToServer("sv_setMaxSpeed", value + 1)
end

function TargetDevice:cl_invertControls(button)
    local _tmp = { td_controls_verticalSwap = "vertical", td_controls_horizontalSwap = "horizontal" }
    local swap = _tmp[button]
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

---@param speed number the rotation speed
---@return number target the animation target
function getAnimTarget(speed)
    return speed
end
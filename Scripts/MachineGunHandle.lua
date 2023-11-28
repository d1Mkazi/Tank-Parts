dofile("$SURVIVAL_DATA/Scripts/util.lua")
dofile("localization.lua")

---@class Handle : ShapeClass
Handle = class()
Handle.maxChildCount = -1
Handle.connectionOutput = sm.interactable.connectionType.logic + sm.interactable.connectionType.bearing
Handle.colorNormal = sm.color.new("fecc39ff")
Handle.colorHighlight = sm.color.new("ffd760ff")
Handle.poseWeightCount = 1


function Handle:server_onCreate()
    self:init()
end

function Handle:server_onRefresh()
    self:init()
    print("RELOADED")
end

function Handle:init()
    self.sv = {
        bearings = {
            ws = {},
            ad = {}
        }
    }
end


function Handle:server_onFixedUpdate(dt)
    local bearings = self.interactable:getBearings()
    if bearings then
        for k, bearing in ipairs(bearings) do
            if bearing.zAxis == self.shape.zAxis then
                table.insert(self.sv.bearings.ad, bearing)
            else
                table.insert(self.sv.bearings.ws, bearing)
            end
        end
    else
        self.sv.bearings = { ws = {}, ad = {} }
    end
end

function Handle:sv_setOccupied(occupied)
    self.network:sendToClients("cl_setOccupied", occupied)
end

---@param args table to: set 1 to turn right, set -1 to turn left and 0 to stop\nspeed: rotation speed
function Handle:sv_applyImpulseWS(args)
    local bearings = self.sv.bearings.ws

    local to, speed = args.to or self.sv.wsto, args.speed ~= nil and args.speed or 0
    for _, bearing in ipairs(bearings) do
        bearing:setMotorVelocity(speed * to, 2)
    end
    self.sv.wsto = to
end

---@param args table to: set 1 to turn right, set -1 to turn left and 0 to stop\nspeed: rotation speed
function Handle:sv_applyImpulseAD(args)
    local bearings = self.sv.bearings.ad

    local to, speed = args.to or self.sv.adto, args.speed ~= nil and args.speed or 0
    for _, bearing in ipairs(bearings) do
        bearing:setMotorVelocity(speed * to, 2)
    end
    self.sv.adto = to
end

function Handle:sv_setActive(active)
    self.interactable.active = active
    self.network:sendToClients("cl_setPose", active == true and 1 or 0)
end


--[[ CLIENT ]]--

function Handle:client_onCreate()
    self:cl_init()
end

function Handle:client_onRefresh()
    self:cl_init()
    print("CLIENT RELOADED")
end

function Handle:cl_init()
    self.cl = {
        occupied = false,
        speed = 0.5
    }
end


function Handle:client_onUpdate(dt)
    if self.cl.updateAim then
        local offset = -self.shape.at * 0.2 + self.shape.up * 0.25
        sm.camera.setPosition(self.shape.worldPosition + offset)
        sm.camera.setDirection(self.shape.at)
    end
end

function Handle:client_onAction(action, state)
    if state then
        if action == 15 then -- Use (E)
            self.cl.character:setLockingInteractable(nil)
            self.network:sendToServer("sv_setOccupied", false)
            self.network:sendToServer("sv_applyImpulseWS", { to = 0 })
            self.network:sendToServer("sv_applyImpulseAD", { to = 0 })

            self.cl.updateAim = false
            sm.camera.setCameraState(1)

            local text = GetLocalization("steer_MsgExit", sm.gui.getCurrentLanguage())
            sm.gui.displayAlertText(text, 2)

        elseif action == 1 or action == 2 then
            local args = {
                [1] = -1, -- left
                [2] = 1, -- right
            }

            self.network:sendToServer("sv_applyImpulseAD", { to = args[action], speed = self.cl.speed })

        elseif action == 3 or action == 4 then
            local args = {
                [3] = 1, -- forward
                [4] = -1, -- backward
            }

            self.network:sendToServer("sv_applyImpulseWS", { to = args[action], speed = self.cl.speed })

        elseif action == 5 or action == 6 then
            local speedUpdate = {
                [5] = 1,
                [6] = -1
            }
            local multiplier = speedUpdate[action]

            local speed = self.cl.speed + 0.1 * multiplier

            if speed < 0.1 then
                speed = 0.1
            elseif speed > 0.5 then
                speed = 0.5
            end
            speed = math.floor(speed * 10 + 0.4) / 10

            self.cl.speed = speed
            local text = GetLocalization("mghandle_AimSpeed", sm.gui.getCurrentLanguage())
            sm.gui.displayAlertText(text.." "..tostring(speed * 10), 2)
            self.network:sendToServer("sv_applyImpulseWS", { speed = speed })
            self.network:sendToServer("sv_applyImpulseAD", { speed = speed })

        elseif action == 18 then
            self.cl.updateAim = not self.cl.updateAim
            if self.cl.updateAim then
                sm.camera.setCameraState(3)
                sm.camera.setFov(80)
            else
                sm.camera.setCameraState(1)
            end

        elseif action == 19 then
            self.network:sendToServer("sv_setActive", true)
        end
    else
        if action == 5 and action == 6 then
            return true
        elseif action == 1 or action == 2 then
            self.network:sendToServer("sv_applyImpulseAD", { to = 0 })
        elseif action == 3 or action == 4 then
            self.network:sendToServer("sv_applyImpulseWS", { to = 0 })
        elseif action == 19 then
            self.network:sendToServer("sv_setActive", false)
        end
    end

    return true
end

function Handle:client_onClientDataUpdate(data, channel)
    for k, v in pairs(data) do
        self.cl[k] = v
    end
end

function Handle:client_canInteract(character)
    return not self.cl.occupied
end

function Handle:client_onInteract(character, state)
    if not state then return end

    character:setLockingInteractable(self.interactable)
    self.network:sendToServer("sv_setOccupied", true)
    self.cl.character = character

    local text = GetLocalization("steer_MsgEnter", sm.gui.getCurrentLanguage())
    sm.gui.displayAlertText(text, 2)
end

function Handle:cl_setOccupied(occupied)
    self.cl.occupied = occupied
end

function Handle:cl_setPose(weight)
    self.interactable:setPoseWeight(0, weight)
end
dofile("$SURVIVAL_DATA/Scripts/util.lua")
dofile("shellDB.lua")
dofile("utils.lua")
dofile("localization.lua")

---@class Breech : ShapeClass
Breech = class()
Breech.maxParentCount = 1
--Breech.maxChildCount = 1
Breech.connectionInput = sm.interactable.connectionType.logic
Breech.connectionOutput = sm.interactable.connectionType.logic
Breech.colorNormal = sm.color.new("6a306bff")
Breech.colorHighlight = sm.color.new("a349a4ff")

-- constants
local EMPTY = 1
local LOADED = 2
local FIRED = 3


function Breech:server_onCreate()
    self:init()
end

function Breech:server_onRefresh()
    self:init()
    print("[DEBUG: Breech] Reloaded")
end

function Breech:init()
    self.sv = { animProgress = 0, lastActive = false }

    self.saved = self.storage:load() or {
        loaded = nil,
        shootDistance = 0,
        status = EMPTY
    }
    if self.saved.loaded then self:sv_loadShell() end

    self:sv_updateClientData()

    local size = sm.vec3.new(0.125, 0.25, 0.25)
    local offset = sm.vec3.new(self.data.areaOffsetX, self.data.areaOffsetY, self.data.areaOffsetZ)
    local filter = sm.areaTrigger.filter.staticBody + sm.areaTrigger.filter.dynamicBody

    self.sv.areaTrigger = sm.areaTrigger.createAttachedBox(self.interactable, size, offset, sm.quat.identity(), filter)
    self.sv.areaTrigger:bindOnEnter("trigger_onEnter")
end

function Breech:server_onFixedUpdate(timeStep)
    local parent = self.interactable:getSingleParent()

    if self.saved.status == FIRED and self.sv.animProgress == 1 then
        self:sv_dropCase()
    end

    if parent and parent.active and not self.sv.lastActive then
        if self.saved.status == LOADED and self.sv.animProgress == 0 then
            self:sv_shoot()
        elseif self.saved.status == FIRED then
            self.network:sendToClients("cl_open")
        end
    end

    if parent then
        self.sv.lastActive = parent.active
    else
        self.sv.lastActive = nil
    end
end

function Breech:server_onMelee()
    if self.saved.status ~= LOADED then return end
    self:sv_shoot()
end

function Breech:trigger_onEnter(trigger, results)
    if self.saved.status ~= EMPTY then return end

    for _, content in ipairs(results) do
        for _, shape in ipairs(content:getShapes()) do
            if shape.body ~= self.shape.body then
                if self.saved.status ~= EMPTY then return end
                if isAnyOf(tostring(shape.uuid), AllowedShells[self.data.type]) then
                    self:sv_loadShell(shape)
                    shape:destroyPart(0)
                end
            end
        end
    end
end

---@param shape? Shape The shell
function Breech:sv_loadShell(shape)
    if not shape then
        self.interactable.active = true
        self.network:sendToClients("cl_loadShell")
        return
    end

    self.saved.loaded = {}
    self.saved.loaded.shape = shape
    self.saved.loaded.uuid = shape:getShapeUuid()

    self.interactable.active = true

    self.network:sendToClients("cl_loadShell")
    self.saved.status = LOADED
    self:sv_updateClientData()
    self.storage:save(self.saved)
end

function Breech:sv_updateState(value) self.sv.animProgress = value end

function Breech:sv_shoot()
    local pos = self.shape.worldPosition
    local at = self.shape.at
    local offset = self.saved.shootDistance / 2

    local shell = getTableByValue(tostring(self.saved.loaded.uuid), ShellDB, "shellUUID") --[[@as table]] -- I hate yellow underscores
    ShellProjectile:sv_createShell(shell, pos + at * offset + self.shape.up * 0.125, at * shell.initialSpeed)

    --sm.physics.applyImpulse(self.shape.body, -at * shell.initialSpeed^2, true)

    self.network:sendToClients("cl_shoot")
    self.saved.loaded = nil
    self.saved.status = FIRED
    self:sv_updateClientData()
    self.storage:save(self.saved)
end

function Breech:sv_dropCase()
    local pos = self.shape.worldPosition + self.shape.right * -0.125
    local at = self.shape.at

    local offset = self.data.areaOffsetY - 0.88

    sm.shape.createPart(sm.uuid.new("cc19cdbf-865e-401c-9c5e-f111ccc25800"), pos + at * offset, self.shape.worldRotation)
    self.network:sendToClients("cl_open")

    self.saved.status = EMPTY
    self:sv_updateClientData()
    self.storage:save(self.saved)
end

---@param distance number shoot distance offset (barrel length)
function Breech:sv_setBreech(distance)
    self.saved.shootDistance = distance
    self:sv_updateClientData()
    self.storage:save(self.saved)
end

---@param container Container Player carry container
function Breech:sv_unload(container)
    self.saved.status = EMPTY
    sm.container.beginTransaction()
    sm.container.collect(container, sm.uuid.new("cc19cdbf-865e-401c-9c5e-f111ccc25800"), 1)
    sm.container.endTransaction()
    self.network:sendToClients("cl_open")
    self:sv_updateClientData()
    self.storage:save(self.saved)
end

function Breech:sv_updateClientData()
    self.network:setClientData({ shootDistance = self.saved.shootDistance, status = self.saved.status })
end

function Breech:client_onCreate()
    self.cl = {
        animUpdate = 0,
        animProgress = 0,
        gui  = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/Breech.layout")
    }
    self.cl.gui:createHorizontalSlider("breechSlider", 20, 1, "cl_changeSlider", true)

    self.interactable:setAnimEnabled("Opening", true)
    self:cl_open()
end

function Breech:client_onClientDataUpdate(data)
    for key, value in pairs(data) do
        self.cl[key] = value
    end
end

function Breech:client_canInteract(character)
    if self.cl.status ~= FIRED then return false end

    local takeCase = GetLocalization("breech_TakeCase", sm.gui.getCurrentLanguage())
    sm.gui.setCenterIcon("Use")
    sm.gui.setInteractionText("", sm.gui.getKeyBinding("Use", true), takeCase)
    return true
end

function Breech:client_onInteract(character, state)
    if not state then return end

    self.cl.carry = character:getPlayer():getCarry()
    self:cl_open()
end

function Breech:client_canTinker(character)
    local settings = GetLocalization("base_Settings", sm.gui.getCurrentLanguage())
    sm.gui.setInteractionText("", sm.gui.getKeyBinding("Tinker", true), settings)
    return true
end

function Breech:client_onTinker(character, state)
    if not state then return end
    if not self.cl.gui:isActive() then self.cl.gui:close() end

    local title = GetLocalization("breech_GuiTitle", sm.gui.getCurrentLanguage())
    self.cl.gui:setText("steerTitle", title)
    self.cl.gui:open()
    self.cl.gui:setSliderPosition("breechSlider", self.cl.shootDistance)
end

function Breech:client_onUpdate(dt)
    self:cl_updateAnimation(dt)
    self:cl_carryCase()
end

function Breech:cl_loadShell()
    -- load animation
    self:cl_close()

    -- load sound
    if not sm.dlm_injected then return end
    sm.effect.playEffect("Breech - Load", self.shape.worldPosition)
end

function Breech:cl_shoot()
    local pos = self.shape.worldPosition + self.shape.at * self.cl.shootDistance / 2 + sm.vec3.new(0, 0, 0.25)
    if sm.dlm_injected then
        sm.effect.playEffect("TankCannon - Shoot", pos, nil, nil, nil, {DLM_Volume = 40, DLM_Pitch = 0.95})
    else
        sm.effect.playEffect("PropaneTank", pos)
    end
end

function Breech:cl_changeSlider(value) self.network:sendToServer("sv_setBreech", value) end

function Breech:cl_carryCase()
    if self.cl.carry ~= nil and self.cl.animProgress == 1 then
        self.network:sendToServer("sv_unload", self.cl.carry)
        self.cl.carry = nil
    end
end

function Breech:cl_updateAnimation(dt)
    if self.cl.animUpdate == 0 then return end

    local progress = self.cl.animProgress + dt * self.cl.animUpdate

    if progress >= 1 then
        self.network:sendToServer("sv_updateState", 1)
        progress = 1
        self.cl.animUpdate = 0
    elseif progress <= 0 then
        self.network:sendToServer("sv_updateState", 0)
        progress = 0
        self.cl.animUpdate = 0
    end

    self.interactable:setAnimProgress("Opening", progress)
    self.cl.animProgress = progress
end

function Breech:cl_open() self.cl.animUpdate = 4 end
function Breech:cl_close() self.cl.animUpdate = -2 end
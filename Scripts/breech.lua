dofile("$SURVIVAL_DATA/Scripts/util.lua")
dofile("shellDB.lua")
dofile("utils.lua")
dofile("localization.lua")

---@class Breech : ShapeClass
Breech = class()
Breech.maxParentCount = 1
Breech.maxChildCount = 2
Breech.connectionInput = sm.interactable.connectionType.logic
Breech.connectionOutput = sm.interactable.connectionType.logic + sm.interactable.connectionType.power
Breech.colorNormal = sm.color.new("6a306bff")
Breech.colorHighlight = sm.color.new("a349a4ff")

-- constants
local EMPTY = 1
local LOADED = 2
local FIRED = 3
local SHELLED = 4

-- status lists
local GateOpened = { EMPTY, SHELLED }
local GateClosed = { LOADED, FIRED }


function Breech:server_onCreate()
    self:init()
end

function Breech:server_onRefresh()
    self:init()
    print("[DEBUG: Breech] Reloaded")
end

function Breech:init()
    self.sv = {
        animProgress = 0,
        dropping = false,
        lastActive = false,
        hasMuzzle = false,
    }

    self.saved = self.storage:load() or {
        loaded = nil,
        shootDistance = 0,
        status = EMPTY,
        offset = 1
    }
    local status
    if isAnyOf(status, GateClosed) then
        self.network:sendToClients("cl_close")
        if status == LOADED then
            self.interactable.active = true
        end
    else
        self.network:sendToClients("cl_open")
    end

    self.network:setClientData({ shootDistance = self.saved.shootDistance, status = self.saved.status })

    local data = self.data
    local size = sm.vec3.new(data.areaSizeX, data.areaSizeY, data.areaSizeZ)
    local offset = sm.vec3.new(data.areaOffsetX, data.areaOffsetY, data.areaOffsetZ)
    local filter = sm.areaTrigger.filter.staticBody + sm.areaTrigger.filter.dynamicBody

    self.sv.areaTrigger = sm.areaTrigger.createAttachedBox(self.interactable, size, offset, sm.quat.identity(), filter)
    self.sv.areaTrigger:bindOnEnter("trigger_onEnter")
    self.sv.areaTrigger:setShapeDetection(true)
end

function Breech:server_onFixedUpdate(dt)
    local parent = self.interactable:getSingleParent()
    local children = self.interactable:getChildren(2) -- power
    local status = self.saved.status

    if status == FIRED and self.sv.animProgress == 1 and self.sv.dropping then
        self:sv_dropCase()
        self.sv.dropping = false
    end

    if parent and parent.active and not self.sv.lastActive then
        if status == LOADED and self.sv.animProgress == 0 then
            self:sv_shoot()
        elseif status == FIRED then
            self.network:sendToClients("cl_open")
            self.sv.dropping = true
        end
    end

    if parent then
        self.sv.lastActive = parent.active
    else
        self.sv.lastActive = nil
    end

    if #children > 0 then
        local child = children[1] --[[@as Interactable]]
        if self.sv.hasMuzzle and tostring(child.shape.uuid) ~= "244358e7-f529-42ab-96c8-fd27e8480a9a" then
            print("BREECH DISCONNETED CHILD")
            self.interactable:disconnect(child)
        else
            self:sv_setMuzzle(true)
        end
    else
        self:sv_setMuzzle(false)
    end
end

function Breech:server_onMelee()
    if self.saved.status ~= LOADED or self.sv.animProgress ~= 0 then return end
    self:sv_shoot()
end

function Breech:trigger_onEnter(trigger, results)
    if isAnyOf(self.saved.status, GateClosed) then return end

    local shellTable = ShellList[self.data.caliber][self.data.loading]
    local shapes = trigger:getShapes()
    for _, shapeData in ipairs(shapes) do
        for k, shape in pairs(shapeData) do
            if k == "shape" then
                if shape.body ~= self.shape.body then
                    local status = self.saved.status
                    if isAnyOf(status, GateClosed) then return end

                    local uuid = tostring(shape.uuid)
                    local table = getTableByValue(uuid, shellTable, "shellUuid")
                    if self.data.loading == "unitary" then
                        if table then
                            self:sv_loadShell(shape, table)
                            shape:destroyPart(0)
                        end
                    else
                        if status == EMPTY then
                            if table then
                                self:sv_loadSeparated(shape.uuid, table)
                                shape:destroyPart(0)
                            end
                        else
                            if uuid == self.saved.loaded.data.caseUuid then
                                self:sv_loadSeparated(shape.uuid)
                                shape:destroyPart(0)
                            elseif uuid == "66a069ab-4512-421d-b46b-7d14fb7f3d09" then
                                local case = shape.interactable.publicData.case
                                if case == self.saved.loaded.data.caseUuid then
                                    self:sv_loadSeparated(case)
                                    sm.event.sendToInteractable(shape.interactable, "sv_removeCase")
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

---@param shape Shape The shell
---@param dataTable table
function Breech:sv_loadShell(shape, dataTable)
    local loaded = {}
    loaded.data = dataTable
    loaded.shell = shape.uuid

    self.interactable.active = true

    self.saved.loaded = loaded
    self.network:sendToClients("cl_loadShell")
    self.saved.status = LOADED
    self:sv_updateClientData()
    self.storage:save(self.saved)
end

---@param uuid Uuid The shell
---@param dataTable? table
function Breech:sv_loadSeparated(uuid, dataTable)
    local status = self.saved.status
    local loaded = {}
    if status == EMPTY then
        loaded.data = dataTable
        loaded.shell = uuid
        self.saved.loaded = loaded

        self.interactable.active = true
        status = SHELLED
    else
        self.saved.loaded.case = uuid

        self.interactable.active = true
        status = LOADED
    end

    self.saved.status = status
    self.network:sendToClients("cl_loadSeparated", status == LOADED and true or false)
    self:sv_updateClientData()
    self.storage:save(self.saved)
end

function Breech:sv_updateState(value) self.sv.animProgress = value end

function Breech:sv_shoot()
	self.interactable.active = false

    local at = self.shape.at
    local size = sm.item.getShapeSize(self.shape.uuid)
    local offset = (size.y + self.saved.shootDistance) * 0.25

    local pos, rot
    if self.sv.hasMuzzle then
        local muzzle = self.interactable:getChildren(2--[[power]])[1].shape
        pos = muzzle.worldPosition + at * 0.25
        rot = sm.vec3.getRotation(sm.vec3.new(0, 0, 1), muzzle.at)
    else
        pos = self.shape.worldPosition + at * offset + self.shape.up * 0.125 * ((size.z % 2 == 0 and self.saved.offset or 0))
        rot = sm.vec3.getRotation(sm.vec3.new(0, 0, 1), self.shape.at)
    end

    local shell = self.saved.loaded.data.shellData

    sm.event.sendToTool(ShellProjectile.tool, "sv_createShell", { data = { caliber = self.data.caliber, loading = self.data.loading, shellUuid = self.saved.loaded.data.shellUuid }, pos = pos, vel = at * shell.initialSpeed })

    local recoil = shell.initialSpeed * (shell.mass or 0) * (self.sv.hasMuzzle == true and 0.65 or 1)
    sm.physics.applyImpulse(self.shape.body, -at * recoil, true)

    self.network:sendToClients("cl_shoot", { pos = pos, rot = rot })
    self.saved.status = FIRED
    self:sv_updateClientData()
    self.storage:save(self.saved)
end

function Breech:sv_dropCase()
    local pos = self.shape.worldPosition + self.shape.right * -0.125
    local at = self.shape.at
    local caseSize = sm.item.getShapeSize(sm.uuid.new(self.saved.loaded.data.usedUuid)).y
    local offset = ((sm.item.getShapeSize(self.shape.uuid).y * 0.5) + (caseSize)) * 0.25

    sm.shape.createPart(sm.uuid.new(self.saved.loaded.data.usedUuid), pos - at * offset, self.shape.worldRotation)

    self.saved.status = EMPTY
    self.saved.loaded = nil
    self:sv_updateClientData()
    self.storage:save(self.saved)
end

---@param args table Possible keys are `distance`, `offset`
function Breech:sv_setBreech(args)
    if args.distance then
        self.saved.shootDistance = args.distance
    end
    if args.offset then
        self.saved.offset = args.offset
    end
    self:sv_updateClientData()
    self.storage:save(self.saved)
end

---@param container Container Player carry container
function Breech:sv_unload(container)
    sm.container.beginTransaction()
    sm.container.collect(container, sm.uuid.new(self.saved.loaded.data.usedUuid), 1)
    sm.container.endTransaction()

    self.saved.status = EMPTY
    self.saved.loaded = nil
    self:sv_updateClientData()
    self.storage:save(self.saved)
end

function Breech:sv_updateClientData()
    self.network:setClientData({ shootDistance = self.saved.shootDistance, status = self.saved.status, offset = self.saved.offset })
end

function Breech:sv_open()
    self.network:sendToClients("cl_open")
end

function Breech:sv_setMuzzle(state)
    if self.sv__hasMuzzle == state then return end

    self.sv.hasMuzzle = state
    self.sv__hasMuzzle = state
    self.network:sendToClients("cl_setMuzzle", state)
end


--[[ CLIENT ]]--

function Breech:client_onCreate()
    self.cl = {
        animUpdate = 0,
        animProgress = 0,
        hasMuzzle = false,
        offset = 1
    }
    local gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/Breech.layout")
    gui:createHorizontalSlider("breech_barrelLength_slider", 30, 0, "cl_changeSlider")
    gui:setIconImage("breech_icon", self.shape.uuid)
    gui:setButtonCallback("breech_offset_upper", "cl_onOffsetChange")
    gui:setButtonCallback("breech_offset_lower", "cl_onOffsetChange")

    gui:setVisible("breech_offset", sm.item.getShapeSize(self.shape.uuid).z % 2 == 0 and true or false)

    self.cl.gui = gui

    self.interactable:setAnimEnabled("Opening", true)
end

function Breech:client_onClientDataUpdate(data)
    for key, value in pairs(data) do
        self.cl[key] = value
    end
end

function Breech:client_canInteract()
    if self.cl.status ~= FIRED then return false end

    local takeCase = GetLocalization("breech_TakeCase", getLang())
    sm.gui.setCenterIcon("Use")
    sm.gui.setInteractionText("", sm.gui.getKeyBinding("Use", true), takeCase)
    return true
end

function Breech:client_onInteract(character, state)
    if not state then return end

    self.cl.carry = character:getPlayer():getCarry()
    self.network:sendToServer("sv_open")
end

function Breech:client_canTinker(character)
    local settings = GetLocalization("base_Settings", getLang())
    sm.gui.setInteractionText("", sm.gui.getKeyBinding("Tinker", true), settings)
    return true
end

function Breech:client_onTinker(character, state)
    if not state then return end
    if not self.cl.gui:isActive() then self.cl.gui:close() end

    local gui = self.cl.gui
    gui:setText("breech_title", GetLocalization("base_Settings", getLang()))
    gui:setText("breech_barrelLength_header", GetLocalization("breech_GuiLength", getLang()))
    gui:setSliderPosition("breech_barrelLength_slider", self.cl.shootDistance)
    gui:setText("breech_barrelLength_display", GetLocalization("breech_GuiDisplay", getLang()):format(self.cl.shootDistance + 1))
    gui:setButtonState("breech_offset_upper", self.cl.offset == 1)
    gui:setText("breech_offset_upper", GetLocalization("breech_GuiUpper", getLang()))
    gui:setButtonState("breech_offset_lower", self.cl.offset == -1)
    gui:setText("breech_offset_lower", GetLocalization("breech_GuiLower", getLang()))
    gui:setText("breech_name", sm.shape.getShapeTitle(self.shape.uuid))
    gui:setText("breech_offset_header", GetLocalization("breech_GuiOffset", getLang()))
    gui:open()
end

function Breech:client_onUpdate(dt)
    self:cl_updateAnimation(dt)
    self:cl_carryCase()
end

function Breech:cl_loadShell()
    -- load animation
    self:cl_close()

    -- load sound
    if not sm.cae_injected then return end
    sm.effect.playEffect("Breech - Load", self.shape.worldPosition)
end

---@param final boolean should it be loaded or not
function Breech:cl_loadSeparated(final)
    if final then self:cl_close() end -- load animation

    -- load sound
    if not sm.cae_injected then return end
    sm.effect.playEffect("Breech - Load", self.shape.worldPosition)
end

function Breech:cl_shoot(args)
    if sm.cae_injected then
        if self.cl.hasMuzzle then
            sm.effect.playEffect("TankCannon - MuzzleBrake Shoot", args.pos, nil, args.rot)
        else
            sm.effect.playEffect(getFireSound(self.data.caliber), args.pos, nil, args.rot)
        end
    else
        if self.cl.hasMuzzle then
            sm.effect.playEffect("TankCannon - MuzzleBrake Smoke", args.pos, nil, args.rot)
        else
            sm.effect.playEffect("TankCannon - Smoke", args.pos, nil, args.rot)
        end
    end
end

function Breech:cl_changeSlider(value)
    self.cl.gui:setText("breech_barrelLength_display", GetLocalization("breech_GuiDisplay", getLang()):format(value + 1))

    self.network:sendToServer("sv_setBreech", { distance = value })
end

---@param button string
---@param state boolean
function Breech:cl_onOffsetChange(button, state)
    print("HEY")
    if button:sub(15) == "upper" then
        self.cl.gui:setButtonState("breech_offset_upper", true)
        self.cl.gui:setButtonState("breech_offset_lower", false)
        self.network:sendToServer("sv_setBreech", { offset = 1 })
    else
        self.cl.gui:setButtonState("breech_offset_upper", false)
        self.cl.gui:setButtonState("breech_offset_lower", true)
        self.network:sendToServer("sv_setBreech", { offset = -1 })
    end
end

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

function Breech:cl_open()
    self.cl.animUpdate = 4
end

function Breech:cl_close()
    self.cl.animUpdate = -2
end

function Breech:cl_setMuzzle(state)
    print("set muzzle", state)
    self.cl.hasMuzzle = state

    self.cl.gui:setVisible("breech_barrelLength", not state)
end

---@param caliber number the caliber
---@return string -- effect name
function getFireSound(caliber)
    local special = {
        [152] = "TankCannon - Howitzer Fire"
    }

    return special[caliber] or "TankCannon - Shoot"
end
dofile("shellDB.lua")
dofile("utils.lua")
dofile("localization.lua")

---@class ShapeClass
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
--local GateOpened = { EMPTY, SHELLED }
local GateClosed = { LOADED, FIRED }

local HOLDERS = {
    sm.uuid.new("74fb410d-b51f-4deb-9f2a-cb4429151f9e"), -- ammo rack 3
    sm.uuid.new("622fcd8f-2314-4bf5-b65d-930e12a32b5f"), -- ammo rack 4
    sm.uuid.new("13eb855c-74e8-4c53-8c03-917930e5f389") -- ammo rack 5
}


---@param caliber number the caliber
---@return string -- effect name
local function getFireSound(caliber)
    local special = {
        [152] = "TankCannonSound - ShootLarge",
        ["m5"] = "TankCannonSound - ShootSmall"
    }

    return special[caliber] or "TankCannonSound - ShootMedium"
end

---@param caliber number the caliber
---@return string -- effect name
local function getFireSmoke(caliber)
    local special = {
        [152] = "TankCannon - ShootSmokeLarge",
        ["m5"] = "TankCannon - ShootSmokeSmall"
    }

    return special[caliber] or "TankCannon - ShootSmokeMedium"
end

---@param caliber number the caliber
---@return table|nil -- parameter list
local function getEffectParameters(caliber)
    local special = {
        [152] = { shakeStrength = 1.2, shakeRadius = 180 },
        ["kwk44"] = { shakeStrength = 1, shakeRadius = 140 },
        ["d25t"] = { shakeStrength = 0.6, shakeRadius = 90 },
        ["m5"] = { shakeStrength = 0.05, shakeRadius = 15 }
    }

    return special[caliber] or nil
end


function Breech:server_onCreate()
    self:init()
end

function Breech:server_onRefresh()
    self:init()
    print("[DEBUG: Breech] Reloaded")
end

function Breech:init()
    self.sv = {
        loaded = {
            shell = nil,
            case = nil
        },
        status = EMPTY,
        animProgress = 0,
        dropping = false,
        lastActive = false,
        hasMuzzle = false,
        expectedCases = nil,
    }

    self.saved = self.storage:load() or {
        shootDistance = 0,
        offset = 1
    }

    self.network:sendToClients("cl_open")

    self.network:setClientData({ shootDistance = self.saved.shootDistance, status = EMPTY })

    local area = self.data.areaTrigger
    self.sv.areaTrigger = sm.areaTrigger.createAttachedBox(self.interactable,
        sm.vec3.new(area[1], area[2], area[3]),
        sm.vec3.new(area[4], area[5], area[6]),
        sm.quat.identity(),
        sm.areaTrigger.filter.staticBody + sm.areaTrigger.filter.dynamicBody
    )
    self.sv.areaTrigger:bindOnEnter("trigger_onEnter")
    self.sv.areaTrigger:setShapeDetection(true)
end

function Breech:server_onFixedUpdate(dt)
    local parent = self.interactable:getSingleParent()
    local children = self.interactable:getChildren(2) -- power
    local status = self.sv.status

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
    if self.sv.status ~= LOADED or self.sv.animProgress ~= 0 then return end
    self:sv_shoot()
end

function Breech:trigger_onEnter(trigger, results)
    local status = self.sv.status
    if (status == LOADED) or (status == FIRED) then
        return
    end

    local bullets = self.data.bullets
    local cases = self.data.cases
    local expected = self.sv.expectedCases

    local shapes = trigger:getShapes()
    for _, shapeData in ipairs(shapes) do
        for k, shape in pairs(shapeData) do
            if (k == "shape") and (shape.interactable) and (shape.interactable.publicData) then
                if shape.body ~= self.shape.body then
                    status = self.sv.status
                    if (status == LOADED) or (status == FIRED) then
                        return
                    end

                    local publicData = shape.interactable.publicData

                    if publicData.claimed or publicData.emptyCase then
                        return
                    end
                    publicData.claimed = true

                    if publicData.hold then
                        local uuid = publicData.hold
                        if uuid and isAnyOf(uuid, bullets) or isAnyOf(uuid, cases) then
                            if self:sv_load(uuid) then
                                sm.event.sendToInteractable(shape.interactable, "sv_removeHold")
                            end
                        end
                        publicData.claimed = nil
                    else
                        local uuid = shape.uuid

                        if isAnyOf(uuid, bullets) or isAnyOf(uuid, cases) then
                            if self:sv_load(uuid) then
                                shape:destroyPart(0)
                            else
                                publicData.claimed = nil
                            end
                        else
                            publicData.claimed = nil
                        end
                    end
                end
            end
        end
    end
end

function Breech:sv_receiveLoad(args)
    sm.container.beginTransaction()
    sm.container.spend(args.container, args.uuid, 1)
    sm.container.endTransaction()

    self:sv_load(args.uuid)
end

---@param uuid Uuid
function Breech:sv_load(uuid)
    local query = sm.TankParts.query(uuid)

    if query.shell then
        if self.sv.status ~= EMPTY then
            return false
        end

        self.sv.loaded.shell = query.shell
        self.sv.expectedCases = query.shell.cases
        self.sv.status = SHELLED
    end

    if query.case then
        if self.sv.status ~= SHELLED then
            return false
        end

        self.sv.loaded.case = query.case
        self.interactable.active = true
        self.network:sendToClients("cl_loadShell")
        self.sv.status = LOADED
    end

    self:sv_updateClientData()

    return true
end

function Breech:sv_updateState(value)
    self.sv.animProgress = value
end

function Breech:sv_shoot()
	self.interactable.active = false

    local at = self.shape.at

    local pos, rot, offset
    if self.sv.hasMuzzle then
        local muzzle = self.interactable:getChildren(2--[[power]])[1].shape
        pos = muzzle.worldPosition + at * 0.25
        rot = sm.vec3.getRotation(sm.vec3.new(0, 0, 1), muzzle.at)
        offset = (self.shape.worldPosition - pos):length()

        -- Tell the muzzle to play an effect
        sm.event.sendToInteractable(muzzle.interactable, "sv_playEffect")
    else
        local size = sm.item.getShapeSize(self.shape.uuid)
        offset = ((size.y + self.saved.shootDistance) * 0.25)
        pos = self.shape.worldPosition + at * offset + self.shape.up * 0.125 * ((size.z % 2 == 0 and self.saved.offset or 0))
        rot = sm.vec3.getRotation(sm.vec3.new(0, 0, 1), self.shape.at)
    end

    --[[
    local shell = self.sv.loaded

    local shellData = sm.TankParts.query(self.sv.loaded.shell).data
    sm.event.sendToTool(ShellTool.tool, "sv_createShell", { ammoData = shellData, pos = pos, vel = at * shellData.initialSpeed })

    if shell.sabot then
        shrapnelExplosion(pos, at * shell.initialSpeed, 3, 30, 20, true)
    end

    local recoil = shell.initialSpeed * (shell.mass or 0) * (self.sv.hasMuzzle == true and 0.65 or 1)
    sm.physics.applyImpulse(self.shape.body, -at * recoil, true)
    ]]

    self.network:sendToClients("cl_shoot", { pos = pos, rot = rot, offset = offset })
    self.sv.status = FIRED
    self:sv_updateClientData()
    --self.storage:save(self.saved)
end

function Breech:sv_dropCase()
    local size = sm.item.getShapeSize(self.shape.uuid)
    local pos = self.shape.worldPosition + self.shape.right * -0.125 + self.shape.up * -0.125 -- fuck sm
    local at = self.shape.at
    local caseUuid = sm.uuid.new(self.sv.loaded.case.empty)
    local offset = ((size.y * 0.5) + (sm.item.getShapeSize(caseUuid).y)) * 0.25

    local shape = sm.shape.createPart(caseUuid, pos - at * offset, self.shape.worldRotation)
    self.network:setClientData({ ejectedCase = shape }, 2)

    self.sv.status = EMPTY
    self.sv.loaded = {}
    self:sv_updateClientData()
    --self.storage:save(self.saved)
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
    sm.container.collect(container, sm.uuid.new(self.sv.loaded.case.empty), 1)
    sm.container.endTransaction()

    self.sv.status = EMPTY
    self.sv.loaded = {}
    self:sv_updateClientData()
    --self.storage:save(self.saved)
end

function Breech:sv_updateClientData()
    self.network:setClientData({ shootDistance = self.saved.shootDistance, status = self.sv.status, offset = self.saved.offset })
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
        offset = 1,
        ejectedCase = nil,
        shellCasingSmokeTrail = sm.effect.createEffect("Shell - CasingSmokeTrail"),
        smokeTrailCountdown = 200,
        endOfGunSmoke = sm.effect.createEffect("TankCannon - SmokeAftermath", self.interactable)
    }
    local gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/Breech.layout")
    gui:createHorizontalSlider("breech_barrelLength_slider", 30, 0, "cl_changeSlider")
    gui:setIconImage("breech_icon", self.shape.uuid)
    gui:setButtonCallback("breech_offset_upper", "cl_onOffsetChange")
    gui:setButtonCallback("breech_offset_lower", "cl_onOffsetChange")

    gui:setVisible("breech_offset", sm.item.getShapeSize(self.shape.uuid).z % 2 == 0 and true or false)

    self.cl.gui = gui

    self.interactable:setAnimEnabled("Opening", true)

    if false then -- DEBUG
        local _a = self.data.insertArea
        self._effect = sm.effect.createEffect("ShapeRenderable", self.shape)
        self._effect:setParameter("uuid", sm.uuid.new("5f41af56-df4c-4837-9b3c-10781335757f")) -- glass
        self._effect:setScale(sm.vec3.new(_a[1], _a[2], _a[3]))
        self._effect:setOffsetPosition(sm.vec3.new(_a[4], _a[5], _a[6]))
        self._effect:start()
    end
end



function Breech:client_onFixedUpdate(dt)

    local effect, part = self.cl.shellCasingSmokeTrail, self.cl.ejectedCase

    if part and sm.exists(part) and self.cl.smokeTrailCountdown >= 0 then
        -- set effect's position
        effect:setPosition(part.worldPosition)

        -- count the delay before we stop tracking
        self.cl.smokeTrailCountdown = self.cl.smokeTrailCountdown - 1

        -- start playing if isn't already
        if not effect:isPlaying() then
            effect:start()
        end
    else
        -- stop tracking the part
        self.cl.ejectedCase = nil

        -- reset the countdown
        self.cl.smokeTrailCountdown = 200

        -- stop the effect
        if effect:isPlaying() then
            effect:stop()
        end
    end
end

function Breech:client_onClientDataUpdate(data)
    for key, value in pairs(data) do
        self.cl[key] = value
    end
end

function Breech:client_canInteract()
    if self.cl.status ~= FIRED then return false end

    local takeCase = GetLocalization("breech_TakeCase", getLang())
    --sm.gui.setCenterIcon("Use")
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

function Breech:client_onDestroy()
    -- prevent the breech from turning into a lag machine
    if self.cl.shellCasingSmokeTrail:isPlaying() then
        self.cl.shellCasingSmokeTrail:stopImmediate()
    end
    self.cl.shellCasingSmokeTrail:destroy()
    self.cl.shellCasingSmokeTrail = nil

    self._effect:destroy()
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
    local caliber = self.data.caliber
    -- play base shooting particle
    sm.effect.playEffect("TankCannon - BaseExplosion", args.pos, nil, args.rot, nil, getEffectParameters(caliber))

    -- play either a custom or a vanilla sound
    if sm.cae_injected then
        sm.effect.playEffect(getFireSound(caliber), args.pos, nil, args.rot)
    else
        sm.effect.playEffect("TankCannonSound - ShootExplosion", args.pos, nil, args.rot)
    end

    -- play either a muzzle brake smoke or the one for the appropriate caliber
    if self.cl.hasMuzzle then
        sm.effect.playEffect("TankCannon - ShootSmokeMuzzleBrake", args.pos, nil, args.rot)
    else
        sm.effect.playEffect(getFireSmoke(caliber), args.pos, nil, args.rot)
    end

    self.cl.endOfGunSmoke:setOffsetPosition(sm.vec3.new(0, args.offset, 0))
    self.cl.endOfGunSmoke:stop()
    self.cl.endOfGunSmoke:start()
end

function Breech:cl_changeSlider(value)
    self.cl.gui:setText("breech_barrelLength_display", GetLocalization("breech_GuiDisplay", getLang()):format(value + 1))

    self.network:sendToServer("sv_setBreech", { distance = value })
end

---@param button string
---@param state boolean
function Breech:cl_onOffsetChange(button, state)
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

        -- play effect here because it need to play even when you take out the shell manually and yes I acknowledge that this is fucking stupid
        local size = sm.item.getShapeSize(self.shape.uuid)
        local pos = self.shape.worldPosition + self.shape.right * ((size.x % 2 == 0 and -0.125 or 0))
        local at = self.shape.at
        local ejectEffectOffset = (size.y * 0.5) * 0.25
        sm.effect.playEffect("Breech - EjectShell", pos - at * ejectEffectOffset, nil, sm.vec3.getRotation(sm.vec3.new(0, 0, 1), -self.shape.at))
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

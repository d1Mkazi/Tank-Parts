dofile("localization.lua")

---@class ShellHolder : ShapeClass
ShellHolder = class()
ShellHolder.maxChildCount = -1
ShellHolder.maxParentCount = 1
ShellHolder.connectionInput = sm.interactable.connectionType.logic
ShellHolder.connectionOutput = sm.interactable.connectionType.logic
ShellHolder.colorNormal = sm.color.new("ffd82b")
ShellHolder.colorHighlight = sm.color.new("ffdd47")

-- contains every thing uuid which it can hold
local HOLDABLES = {}

local cartridges = sm.json.open("$CONTENT_DATA/Objects/Database/ShapeSets/cartridges.jsonc").partList
for k, cartridge in ipairs(cartridges) do
    HOLDABLES[#HOLDABLES+1] = cartridge.uuid
end
local shells = sm.json.open("$CONTENT_DATA/Objects/Database/ShapeSets/shells.jsonc").partList
for k, shell in ipairs(shells) do
    HOLDABLES[#HOLDABLES+1] = shell.uuid
end
local bullets = sm.json.open("$CONTENT_DATA/Objects/Database/ShapeSets/bullets.jsonc").partList
for k, bullet in ipairs(bullets) do
    HOLDABLES[#HOLDABLES+1] = bullet.uuid
end


function ShellHolder:server_onCreate()
    self:init()
end

function ShellHolder:server_onRefresh()
    self:init()
    print("RELOADED")
end

function ShellHolder:init()
    self.saved = self.storage:load() or {}
    self.sv = {
        holding = self.saved.hold ~= nil and true or false
    }

    local height = sm.item.getShapeSize(self.shape.uuid).y
    local size = sm.vec3.new(0.25, 0.25, 0.25)
    local offset = sm.vec3.new(0, (height * 0.5 - (height % 2 == 0 and 1 or 0.5)) * 0.25, 0)
    local filter = sm.areaTrigger.filter.staticBody + sm.areaTrigger.filter.dynamicBody

    self.sv.areaTrigger = sm.areaTrigger.createAttachedBox(self.interactable, size, offset, sm.quat.identity(), filter)
    self.sv.areaTrigger:bindOnEnter("trigger_onEnter")
    self.sv.areaTrigger:setShapeDetection(true)

    if self.sv.holding then
        local uuid = self.saved.hold
        self.saved.hold = uuid
        self.sv.holding = true
        self.interactable.active = true
        self.storage:save(self.saved)
        self.interactable.publicData = { hold = uuid }

        local scripted = sm.item.getFeatureData(sm.uuid.new(self.saved.hold))
        if scripted.classname == "Shell" then
            self.sv.explode = true
            self.sv.scripted = scripted.data
        end

        self.network:setClientData({ holding = true, hold = uuid, showData = scripted.classname ~= "EmptyCase" })
    end
end

function ShellHolder:server_onFixedUpdate(dt)
    local parent = self.interactable:getSingleParent()

    if parent and parent.active and self.sv.holding then
        self:sv_dropHold()
    end
end

function ShellHolder:server_onProjectile()
    self:sv_explode()
end

function ShellHolder:server_onExplosion()
    self:sv_explode()
end

function ShellHolder:sv_explode()
    if not self.sv.explode then return end

    local pos = self.shape.worldPosition
    local data = self.sv.scripted
    sm.physics.explode(pos, data.explosionLevel, data.explosionRadius, data.impulseRadius, data.impulseLevel, "PropaneTank - ExplosionSmall")
    shrapnelExplosion(pos, self.shape.at * 50, 5, 360, 100)
    self.shape:destroyPart(0)
end

function ShellHolder:trigger_onEnter(trigger, results)
    if self.sv.holding then return end

    local shapes = trigger:getShapes()
    for _, shapeData in ipairs(shapes) do
        for k, shape in pairs(shapeData) do
            if k == "shape" then
                if self.sv.holding or not sm.exists(shape) then return end

                local uuid = tostring(shape.uuid)
                if shape.body ~= self.shape.body and isAnyOf(uuid, HOLDABLES) and sm.item.getShapeSize(shape.uuid).y <= sm.item.getShapeSize(self.shape.uuid).y then
                    if shape.interactable.publicData.claimed then return end
                    shape.interactable.publicData.claimed = true

                    self:sv_holdShell(shape)
                end
            end
        end
    end
end

---@param shell Shape
function ShellHolder:sv_holdShell(shell)
    local uuid = tostring(shell.uuid)
    self.saved.hold = uuid
    self.sv.holding = true
    self.interactable.active = true
    self.storage:save(self.saved)
    self.interactable.publicData = { hold = uuid }

    local scripted = sm.item.getFeatureData(shell.uuid)
    if scripted.classname == "Shell" then
        self.sv.explode = true
        self.sv.scripted = scripted.data
        self.interactable.publicData.isShell = true
    end

    self.network:setClientData({ holding = true, hold = uuid, showData = scripted.classname ~= "EmptyCase" })
    shell:destroyPart(0)
end

---@param container Container
function ShellHolder:sv_takeShell(container)
    sm.container.beginTransaction()
    sm.container.collect(container, sm.uuid.new(self.saved.hold), 1)
    sm.container.endTransaction()

    self.saved.hold = nil
    self.sv.holding = false
    self.interactable.active = false
    self.network:setClientData({ holding = false })
    self.storage:save(self.saved)
    self.interactable.publicData = {}
end

function ShellHolder:sv_removeHold()
    self.saved.hold = nil
    self.sv.holding = false
    self.interactable.active = false
    self.network:setClientData({ holding = false })
    self.storage:save(self.saved)
    self.interactable.publicData = {}
end

function ShellHolder:sv_dropHold()
    local size = sm.item.getShapeSize(self.shape.uuid)
    local pos = self.shape.worldPosition + self.shape.right * -0.125 + self.shape.up * -0.125 -- fuck sm
    local at = self.shape.at
    local uuid = sm.uuid.new(self.saved.hold)
    local holdSize = sm.item.getShapeSize(uuid).y
    local offset = -((size.y * 0.5) + (holdSize)) * 0.25 + (holdSize - 1) * 0.25
    sm.shape.createPart(uuid, pos - at * offset, self.shape.worldRotation)

    self:sv_removeHold()
end


--[[ CLIENT ]]--

function ShellHolder:client_onCreate()
    self:cl_init()
end

function ShellHolder:client_onRefresh()
    self:cl_init()
end

function ShellHolder:cl_init()
    self.cl = {
        hold = "",
        holding = false,
        showData = false
    }
end

function ShellHolder:client_onClientDataUpdate(data)
    for k, v in pairs(data) do
        self.cl[k] = v
    end

    if self.cl.holding then
        self:cl_createShell()
    else
        if self.cl.effect and self.cl.effect:isPlaying() then
            self.cl.effect:destroy()
            self.cl.effect = nil
        end
    end
end

function ShellHolder:client_onUpdate(dt)
    local effect = self.cl.effect
    if self.cl.holding and effect and not effect:isPlaying() then
        effect:start()
    end
end

function ShellHolder:client_canInteract(character)
    if self.cl.holding and self.cl.showData then
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("Use", true), GetLocalization("rack_take", getLang()):format(sm.shape.getShapeTitle(sm.uuid.new(self.cl.hold))))
    elseif self.cl.holding and not self.cl.showData then
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("Use", true), GetLocalization("breech_TakeCase", getLang()))
    end
    return self.cl.holding
end

function ShellHolder:client_onInteract(character, state)
    if not state then return end

    self.network:sendToServer("sv_takeShell", sm.localPlayer.getPlayer():getCarry())
end

function ShellHolder:cl_createShell()
    local effect = sm.effect.createEffect("ShapeRenderable", self.interactable)
    local uuid = sm.uuid.new(self.cl.hold)
    effect:setParameter("uuid", uuid)
    local height = sm.item.getShapeSize(uuid).y
    local offset = (sm.item.getShapeSize(self.shape.uuid).y - height) * 0.25 / 2
    effect:setOffsetPosition(sm.vec3.new(0, offset, 0))
    effect:setOffsetRotation(sm.quat.fromEuler(sm.vec3.new(0, 0, 180)))
    effect:setScale(sm.vec3.new(0.235, 0.25, 0.235))
    effect:start()

    self.cl.effect = effect
end
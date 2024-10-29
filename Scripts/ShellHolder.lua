dofile("localization.lua")

---@class ShellHolder : ShapeClass
ShellHolder = class()
ShellHolder.maxChildCount = -1
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
        hasShell = self.saved.shell ~= nil and true or false
    }

    local height = sm.item.getShapeSize(self.shape.uuid).y
    local size = sm.vec3.new(0.25, 0.25, 0.25)
    local offset = sm.vec3.new(0, (height * 0.5 - (height % 2 == 0 and 1 or 0.5)) * 0.25, 0)
    local filter = sm.areaTrigger.filter.staticBody + sm.areaTrigger.filter.dynamicBody

    self.sv.areaTrigger = sm.areaTrigger.createAttachedBox(self.interactable, size, offset, sm.quat.identity(), filter)
    self.sv.areaTrigger:bindOnEnter("trigger_onEnter")
    self.sv.areaTrigger:setShapeDetection(true)

    self.network:setClientData({ hasShell = self.sv.hasShell, shell = self.saved.shell })
    self.interactable.publicData = { shell = self.saved.shell }
end

function ShellHolder:trigger_onEnter(trigger, results)
    if self.sv.hasShell then return end

    local shapes = trigger:getShapes()
    for _, shapeData in ipairs(shapes) do
        for k, shape in pairs(shapeData) do
            if k == "shape" then
                if self.sv.hasShell then return end

                local uuid = tostring(shape.uuid)
                if shape.body ~= self.shape.body and isAnyOf(uuid, HOLDABLES) and sm.item.getShapeSize(shape.uuid).y <= sm.item.getShapeSize(self.shape.uuid).y then
                    self.saved.shell = uuid
                    self.sv.hasShell = true
                    self.interactable.active = true
                    self.network:setClientData({ hasShell = true, shell = uuid })
                    self.interactable.publicData = { hold = uuid }
                    shape:destroyPart(0)
                end
            end
        end
    end
end

---@param container Container
function ShellHolder:sv_takeShell(container)
    sm.container.beginTransaction()
    sm.container.collect(container, sm.uuid.new(self.saved.shell), 1)
    sm.container.endTransaction()

    self.saved.shell = nil
    self.sv.hasShell = false
    self.interactable.active = false
    self.storage:save(self.saved)
    self.network:setClientData({ hasShell = false })
    self.interactable.publicData = {}
end

function ShellHolder:sv_removeHold()
    print("removing hold")
    self.saved.shell = nil
    self.sv.hasShell = false
    self.interactable.active = false
    self.storage:save(self.saved)
    self.network:setClientData({ hasShell = false }, 2)
    self.interactable.publicData = {}
end


--[[ CLIENT ]]--

function ShellHolder:client_onCreate()
    self:cl_init()
end

function ShellHolder:client_onRefresh()
    self:cl_init()
end

function ShellHolder:cl_init()
    self.cl = {}
end

function ShellHolder:client_onClientDataUpdate(data)
    for k, v in pairs(data) do
        self.cl[k] = v
        print(("[%s] = %s"):format(k, v))
    end

    if self.cl.hasShell then
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
    if self.cl.hasShell and effect and not effect:isPlaying() then
        effect:start()
    end
end

function ShellHolder:client_canInteract(character)
    return self.cl.hasShell
end

function ShellHolder:client_onInteract(character, state)
    if not state then return end

    self.network:sendToServer("sv_takeShell", sm.localPlayer.getPlayer():getCarry())
end

function ShellHolder:cl_createShell()
    local effect = sm.effect.createEffect("ShapeRenderable", self.interactable)
    local uuid = sm.uuid.new(self.cl.shell)
    effect:setParameter("uuid", uuid)
    local height = sm.item.getShapeSize(uuid).y
    local offset = (0.5 - (0.5 * ((height * 0.5) % 2 == 0 and height * 0.5 or height * 0.5 - 1)) - 0.05) * 0.25
    effect:setOffsetPosition(sm.vec3.new(0, offset, 0))
    effect:setOffsetRotation(sm.quat.fromEuler(sm.vec3.new(0, 0, 0)))
    effect:setScale(sm.vec3.new(0.25, 0.25, 0.25))
    effect:start()

    self.cl.effect = effect
end
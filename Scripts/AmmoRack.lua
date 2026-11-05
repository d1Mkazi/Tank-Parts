dofile("localization.lua")

---@class ShellHolder : ShapeClass
AmmoRack = class()
AmmoRack.maxChildCount = -1
AmmoRack.maxParentCount = 1
AmmoRack.connectionInput = sm.interactable.connectionType.logic
AmmoRack.connectionOutput = sm.interactable.connectionType.logic
AmmoRack.colorNormal = sm.color.new("ffd82b")
AmmoRack.colorHighlight = sm.color.new("ffdd47")


function AmmoRack:server_onCreate()
    self:init()
end

function AmmoRack:server_onRefresh()
    self:init()
    print("RELOADED")
end

function AmmoRack:init()
    self.saved = self.storage:load() or {}
    self.sv = {
        holding = (self.saved.hold ~= nil) and (true) or (false),
        burning = 0,
        maxburn = math.random(3, 6),
        maxLength = sm.item.getShapeSize(self.shape.uuid).y,
    }

    local height = sm.item.getShapeSize(self.shape.uuid).y
    local size = sm.vec3.new(0.25, 0.25, 0.25)
    local offset = sm.vec3.new(0, (height * 0.5 - (height % 2 == 0 and 1 or 0.5)) * 0.25, 0)
    local filter = sm.areaTrigger.filter.staticBody + sm.areaTrigger.filter.dynamicBody

    self.sv.areaTrigger = sm.areaTrigger.createAttachedBox(self.interactable, size, offset, sm.quat.identity(), filter)
    self.sv.areaTrigger:bindOnEnter("trigger_onEnter")
    self.sv.areaTrigger:setShapeDetection(true)

    self.interactable.publicData = {}

    if self.sv.holding then
        self:sv_storeShell(self.saved.hold)
    end
end

function AmmoRack:server_onFixedUpdate(dt)
    if (not self.interactable.active) and self.sv.holding then
        self.interactable.active = true
    end

    local parent = self.interactable:getSingleParent()

    if parent and parent.active and self.sv.holding then
        self:sv_dropHold()
    end

    if self.shape:getBurning() and self.sv.holding then
        self.sv.burning = self.sv.burning + dt

        if self.sv.burning >= self.sv.maxburn then
            self:sv_explode()
        end
    else
        self.sv.burning = 0
    end
end

function AmmoRack:server_onProjectile()
    self:sv_explode()
end

function AmmoRack:server_onExplosion()
    self:sv_explode()
end

function AmmoRack:sv_explode()
    if not self.sv.explode then
        return
    end

    local pos = self.shape.worldPosition
    local data = self.sv.scripted
    sm.physics.explode(pos, data.explosionLevel, data.explosionRadius, data.impulseRadius, data.impulseLevel, "PropaneTank - ExplosionSmall")
    shrapnelExplosion(pos, self.shape.at * 50, 5, 360, 100)
    sm.fire.igniteSphere(pos, data.explosionRadius, true)
    self.shape:destroyPart(0)
end

function AmmoRack:trigger_onEnter(trigger, results)
    if self.sv.holding then
        return
    end

    local shapes = trigger:getShapes()
    for _, shapeData in ipairs(shapes) do
        for k, shape in pairs(shapeData) do
            if k == "shape" then
                if self.sv.holding or not sm.exists(shape) then
                    return
                end

                local uuid = shape.uuid
                if shape.body ~= self.shape.body and sm.TankParts.rackInfo(uuid) <= self.sv.maxLength then
                    if shape.interactable.publicData.claimed then
                        return
                    end
                    shape.interactable.publicData.claimed = true

                    self:sv_storeShell(uuid)
                    shape:destroyShape(0)
                end
            end
        end
    end
end

function AmmoRack:sv_receiveLoad(args)
    sm.container.beginTransaction()
    sm.container.spend(args.container, args.uuid, 1)
    sm.container.endTransaction()

    self:sv_storeShell(args.uuid)
end

---@param uuid Uuid
function AmmoRack:sv_storeShell(uuid)
    local scripted = sm.item.getFeatureData(uuid)
    if scripted.classname == "Shell" then
        self.sv.explode = true
        self.sv.scripted = scripted.data
        self.interactable.publicData.isShell = true
    end

    self.saved.hold = uuid
    self.sv.holding = true
    self.interactable.active = true
    self.interactable.publicData.hold = uuid

    self.storage:save(self.saved)
    self.network:setClientData({ holding = true, hold = uuid, showData = scripted.classname ~= "EmptyCase" })
end

---@param container Container
function AmmoRack:sv_grabShell(container)
    sm.container.beginTransaction()
    sm.container.collect(container, sm.uuid.new(self.saved.hold), 1)
    sm.container.endTransaction()

    self:sv_removeHold()
end

function AmmoRack:sv_dropHold()
    local size = sm.item.getShapeSize(self.shape.uuid)
    local pos = self.shape.worldPosition + self.shape.right * -0.125 + self.shape.up * -0.125 -- fuck sm
    local at = self.shape.at
    local uuid = sm.uuid.new(self.saved.hold)
    local holdSize = sm.item.getShapeSize(uuid).y
    local offset = -((size.y * 0.5) + (holdSize)) * 0.25 + (holdSize - 1) * 0.25
    sm.shape.createPart(uuid, pos - at * offset, self.shape.worldRotation)

    self:sv_removeHold()
end

function AmmoRack:sv_removeHold()
    self.saved.hold = nil
    self.sv.explode = false
    self.sv.holding = false
    self.interactable.active = false
    self.network:setClientData({ holding = false })
    self.storage:save(self.saved)
    self.interactable.publicData = {}
end


--[[ CLIENT ]]--

function AmmoRack:client_onCreate()
    self:cl_init()
end

function AmmoRack:client_onRefresh()
    self:cl_init()
end

function AmmoRack:cl_init()
    self.cl = {
        hold = "",
        holding = false,
        showData = false
    }
end

function AmmoRack:client_onClientDataUpdate(data)
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

function AmmoRack:client_onUpdate(dt)
    local effect = self.cl.effect
    if self.cl.holding and effect and not effect:isPlaying() then
        effect:start()
    end
end

function AmmoRack:client_canInteract(character)
    if self.cl.holding and self.cl.showData then
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("Use", true), GetLocalization("rack_take", getLang()):format(sm.shape.getShapeTitle(sm.uuid.new(self.cl.hold))))
    elseif self.cl.holding and not self.cl.showData then
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("Use", true), GetLocalization("breech_TakeCase", getLang()))
    end
    return self.cl.holding
end

function AmmoRack:client_onInteract(character, state)
    if not state then return end

    self.network:sendToServer("sv_grabShell", sm.localPlayer.getPlayer():getCarry())
end

function AmmoRack:cl_createShell()
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

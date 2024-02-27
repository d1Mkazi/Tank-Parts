---@class Holder : ShapeClass
Holder = class()
Holder.maxChildCount = -1
Holder.connectionOutput = sm.interactable.connectionType.logic
Holder.colorNormal = sm.color.new("ffd82b")
Holder.colorHighlight = sm.color.new("ffdd47")


function Holder:server_onCreate()
    self:init()
end

function Holder:server_onRefresh()
    self:init()
    print("RELOADED")
end

function Holder:init()
    self.saved = self.storage:load() or {}
    self.sv = {
        hasCase = self.saved.case ~= nil and true or false
    }

    local size = sm.vec3.new(0.25, 0.25, 0.25)
    local offset = sm.vec3.new(0, 0, 0.25)
    local filter = sm.areaTrigger.filter.staticBody + sm.areaTrigger.filter.dynamicBody

    self.sv.areaTrigger = sm.areaTrigger.createAttachedBox(self.interactable, size, offset, sm.quat.identity(), filter)
    self.sv.areaTrigger:bindOnEnter("trigger_onEnter")
    self.sv.areaTrigger:setShapeDetection(true)

    self.network:setClientData({ hasCase = self.sv.hasCase, case = self.saved.case })
    self.interactable.publicData = { case = self.saved.case }
end

function Holder:server_onFixedUpdate(dt)
    self.interactable.active = self.sv.hasCase
end

function Holder:trigger_onEnter(trigger, results)
    if self.sv.hasCase then return end

    local shapes = trigger:getShapes()
    for _, shapeData in ipairs(shapes) do
        for k, shape in pairs(shapeData) do
            if k == "shape" then
                if self.sv.hasCase then return end

                local uuid = tostring(shape.uuid)
                if shape.body ~= self.shape.body and isAnyOf(uuid, CASE_LIST) then
                    self.saved.case = uuid
                    self.sv.hasCase = true
                    self.network:setClientData({ hasCase = true, case = uuid })
                    self.interactable.publicData = { case = uuid }
                    shape:destroyPart(0)
                end
            end
        end
    end
end

---@param container Container
function Holder:sv_takeCase(container)
    sm.container.beginTransaction()
    sm.container.collect(container, sm.uuid.new(self.saved.case), 1)
    sm.container.endTransaction()

    self.saved.case = nil
    self.sv.hasCase = false
    self.storage:save(self.saved)
    self.network:setClientData({ hasCase = false })
    self.interactable.publicData = {}
end

function Holder:sv_removeCase()
    self.saved.case = nil
    self.sv.hasCase = false
    self.storage:save(self.saved)
    self.network:setClientData({ hasCase = false })
    self.interactable.publicData = {}
end


--[[ CLIENT ]]--

function Holder:client_onCreate()
    self:cl_init()
end

function Holder:client_onRefresh()
    self:cl_init()
end

function Holder:cl_init()
    self.cl = {}
end

function Holder:client_onClientDataUpdate(data)
    for k, v in pairs(data) do
        self.cl[k] = v
    end

    if self.cl.hasCase then
        self:cl_createCase()
    else
        if self.cl.effect and self.cl.effect:isPlaying() then
            self.cl.effect:destroy()
            self.cl.effect = nil
        end
    end
end

function Holder:client_onUpdate(dt)
    local effect = self.cl.effect
    if self.cl.hasCase and effect and not effect:isPlaying() then
        effect:start()
    end
end

function Holder:client_canInteract(character)
    return self.cl.hasCase
end

function Holder:client_onInteract(character, state)
    if not state then return end

    self.network:sendToServer("sv_takeCase", sm.localPlayer.getPlayer():getCarry())
end

function Holder:cl_createCase()
    local effect = sm.effect.createEffect("ShapeRenderable", self.interactable)
    local uuid = sm.uuid.new(self.cl.case)
    effect:setParameter("uuid", uuid)
    local height = sm.item.getShapeSize(uuid).y
    print("height:", height)
    local offset = (0.5 - (0.5 * ((height * 0.5) % 2 == 0 and height * 0.5 or height * 0.5 - 1)) - 0.05) * 0.25
    effect:setOffsetPosition(sm.vec3.new(0, 0, -offset))
    effect:setOffsetRotation(sm.quat.fromEuler(sm.vec3.new(90, 0, 0)))
    effect:setScale(sm.vec3.new(0.25, 0.25, 0.25))
    effect:start()

    self.cl.effect = effect
end
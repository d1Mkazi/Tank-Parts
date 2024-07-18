---@class Binoculars : ShapeClass
Binoculars = class()
Binoculars.maxParentCount = 1
Binoculars.maxChildCount = 1
Binoculars.connectionInput = sm.interactable.connectionType.logic
Binoculars.connectionOutput = sm.interactable.connectionType.logic
Binoculars.colorNormal = sm.color.new("d8c836ff")
Binoculars.colorHighlight = sm.color.new("f0e26bff")


local TARGET_DEVICE = sm.uuid.new("b0fb8b9e-ac99-4033-abd2-4beb598431a2")
local VIEWPORT = sm.uuid.new("84145f0d-741c-4142-9aec-edd85ce026be")

--[[ SERVER ]]--

function Binoculars:server_onCreate()
    self:init()
end

function Binoculars:server_onRefresh()
    self:init()
    print("RELOADED")
end

function Binoculars:init()
    self.sv = {
        hasDevice = false,
        hasViewport = false,
    }

    self.interactable.publicData = { hasViewport = false }
end

function Binoculars:server_onFixedUpdate(dt)
    local parent = self.interactable:getSingleParent()
    if not parent then
        self.sv.hasDevice = false
        self.network:setClientData({ hasDevice = false })
    else
        if parent.shape.uuid ~= TARGET_DEVICE then
            parent:disconnect(self.interactable)
            return
        end

        if not self.sv.hasDevice then
            self.sv.hasDevice = true
            self.network:setClientData({ hasDevice = true })
        end
    end

    local child = self.interactable:getChildren()[1] --[[@as Interactable]]
    if not child then
        self.sv.hasViewport = false
        self.network:setClientData({ hasViewport = false })
        self.interactable.publicData.hasViewport = false
    else
        if child.shape.uuid ~= VIEWPORT then
            self.interactable:disconnect(child)
            return
        end

        if not self.sv.hasViewport then
            self.sv.hasViewport = true
            self.network:setClientData({ viewport = child.shape, hasViewport = true })
            self.interactable.publicData.hasViewport = true
        end
    end
end

---@param occupied boolean
function Binoculars:sv_setOccupied(occupied)
    self.network:setClientData({ occupied = occupied })
end


--[[ CLIENT ]]--

function Binoculars:client_onCreate()
    self.cl = {
        character = nil, --[[@type Character]]
        viewport = nil, --[[@type Shape]]
        hasDevice = false,
        hasViewport = false,
        occupied = false,
        fov = sm.camera.getDefaultFov()
    }

    local gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/Binoculars.layout")
    gui:setIconImage("bino_icon", self.shape.uuid)

    self.cl.gui = gui
end

function Binoculars:client_onDestroy()
    if self.cl.character == nil then return end

    self:cl_unlockCharacter()
end

function Binoculars:client_onUpdate(dt)
    if self.cl.character ~= nil then
        local viewport = self.cl.viewport --[[@as Shape]]
        if viewport == nil or not sm.exists(viewport) then
            self:cl_unlockCharacter()
        end
        local pos = (viewport:getInterpolatedWorldPosition() + viewport.velocity * dt) + viewport.at * 0.125
        sm.camera.setPosition(pos)
        sm.camera.setDirection(viewport.at)
    end
end

function Binoculars:client_onAction(action, state)
    if state then
        if action == 15 then -- Use (E)
            self:cl_unlockCharacter()

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
    end

    return true
end

function Binoculars:client_onClientDataUpdate(data)
    for k, v in pairs(data) do
        self.cl[k] = v
    end
end

function Binoculars:client_canInteract(character)
    return not self.cl.occupied and self.cl.hasViewport
end

function Binoculars:client_onInteract(character, state)
    if not state then return end

    character:setLockingInteractable(self.interactable)
    self.network:sendToServer("sv_setOccupied", true)

    self.cl.character = character
    sm.camera.setCameraState(3)
    sm.camera.setFov(self.cl.fov)
end

function Binoculars:client_canTinker(character)
    sm.gui.setInteractionText("", sm.gui.getKeyBinding("Tinker", true), GetLocalization("base_Settings", sm.gui.getCurrentLanguage()))
    return not self.cl.occupied
end

function Binoculars:client_onTinker(character, state)
    if not state then return end
    if not self.cl.gui:isActive() then self.cl.gui:close() end

    local gui = self.cl.gui
    gui:setText("bino_title", GetLocalization("base_Settings", getLang()))
    gui:setText("bino_name", sm.shape.getShapeTitle(self.shape.uuid))

    gui:open()
end

function Binoculars:cl_unlockCharacter()
    self.cl.character:setLockingInteractable(nil)
    self.cl.character = nil
    self.network:sendToServer("sv_setOccupied", false)

    sm.camera.setFov(sm.camera.getDefaultFov())
    sm.camera.setCameraState(1)
end

---@param dt number deltaTime
function Binoculars:cl_e_updateCamera(dt)
    if not self.cl.hasViewport then return end

    local viewport = self.cl.viewport --[[@as Shape]]
    local pos = (viewport:getInterpolatedWorldPosition() + viewport.velocity * dt) + viewport.at * 0.125
    sm.camera.setPosition(pos)
    sm.camera.setDirection(viewport.at)
end
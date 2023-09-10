dofile("localization.lua")

---@class Fixer : ShapeClass
Fixer = class()
Fixer.colorNormal = sm.color.new("fd11aa")
Fixer.colorHighlight = sm.color.new("fd00af")
Fixer.connectionInput = sm.interactable.connectionType.logic


function Fixer:server_onCreate()
    self:init()
end

function Fixer:server_onRefresh()
    print("RELOADED")
    self:init()
end

function Fixer:init()
    self.sv = { character = nil, offset = nil }
end

function Fixer:server_onFixedUpdate(dt)
    if not self.sv.character then return end

    local character = self.sv.character --[[@as Character]]
    local offset = self.sv.offset
    character:setWorldPosition(self.shape.worldPosition +
                               self.shape.at * offset.at +
                               self.shape.right * offset.right +
                               self.shape.up * offset.up)
end

---@param character? Character
function Fixer:sv_onClick(character)
    self.sv.character = character
    if character then
        local offset = character.worldPosition - self.shape.worldPosition
        local isAt, isRight, isUp = offset:dot(self.shape.at) > 0, offset:dot(self.shape.right) > 0, offset:dot(self.shape.up) > 0
        self.sv.offset = {
            at = (self.shape.at * offset):length() * (isAt == true and 1 or -1),
            right = (self.shape.right * offset):length() * (isRight == true and 1 or -1),
            up = (self.shape.up * offset):length() * (isUp == true and 1 or -1)
        }
    end
end

function Fixer:client_onCreate()
    self.cl = {}
end

function Fixer:client_canInteract(character)
    if not self.cl.character then
        local sit = GetLocalization("fixer_Sit", sm.gui.getCurrentLanguage())
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("Use", true), sit)
        return true
    else
        local standUp = GetLocalization("fixer_StandUp", sm.gui.getCurrentLanguage())
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("Use", true), standUp)
        return self.cl.character == character
    end
end

function Fixer:client_onInteract(character, state)
    if not state then return end

    local _character = self.cl.character == nil and character or nil
    self.cl.character = _character
    self.network:sendToServer("sv_onClick", _character)
end
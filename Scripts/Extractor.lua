dofile("$SURVIVAL_DATA/Scripts/util.lua")
dofile("shellDB.lua")
dofile("utils.lua")
dofile("localization.lua")

---@class Extractor : ShapeClass
Extractor = class()
Extractor.maxParentCount = 1
Extractor.maxChildCount = -1
Extractor.connectionInput = sm.interactable.connectionType.logic + sm.interactable.connectionType.power
Extractor.connectionOutput = sm.interactable.connectionType.logic + sm.interactable.connectionType.power
Extractor.colorNormal = sm.color.new("6a306bff")
Extractor.colorHighlight = sm.color.new("a349a4ff")


--[[ SERVER ]]--

function Extractor:server_onCreate()
    self:init()
end

function Extractor:server_onRefresh()
    self:init()
    print("[DEBUG: Extractor] Reloaded")
end

function Extractor:init()
    self.sv = {
        connected = false,
        extractions = {}
    }
    self.saved = self.storage:load() or {
        extract = nil
    }
end

function Extractor:server_onFixedUpdate(dt)
    local parent = self.interactable:getSingleParent()
    if not parent then
        self.sv.connected = false
        --print("NOT CONNECTED")
        return
    end

    if not parent.publicData or not parent.publicData.smart_values then
        parent:disconnect(self.interactable)
        --print("DISCONNECTED parent")
        return
    end

    local smart_values = parent.publicData.smart_values
    local value = smart_values[self.saved.extract]
    if value ~= self.sv.value then
        self:sv_updateValue(value)
    end

    if not self.sv.connected then
        local extractions = {}
        for k, _ in pairs(smart_values) do
            extractions[#extractions+1] = k
        end
        self.network:setClientData({ extractions = extractions })
        local extract = (not isAnyOf(self.saved.extract, extractions)) and extractions[1] or self.saved.extract
        self.saved.extract = extract
        self:sv_onValueSelect(extract)
        self.sv.connected = true
        --print("CONNECTED")
    end
end

function Extractor:sv_onValueSelect(selected)
    self.saved.extract = selected
    self.network:setClientData({ extract = selected }, 2)
    self.storage:save(self.saved)
end

---@param value number|boolean
function Extractor:sv_updateValue(value)
    if type(value) == "boolean" then
        self.interactable.active = value
    elseif type(value) == "number" then
        self.interactable.power = value
    end
    print("UPD VAL", value)

    self.sv.value = value
end


--[[ CLIENT ]]--

function Extractor:client_onCreate()
    self.cl = {
        extract = nil,
        extractions = {}
    }
end

function Extractor:client_onClientDataUpdate(data)
    for k, v in pairs(data) do
        self.cl[k] = v
    end
end

function Extractor:client_canInteract(character)
    return self.interactable:getSingleParent() ~= nil
end

function Extractor:client_onInteract(character, state)
    if not state then return end

    local gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/Extractor.layout", true)
    gui:setIconImage("ext_icon", self.shape.uuid)

    gui:setText("ext_title", GetLocalization("base_Settings", getLang()))
    gui:setText("ext_name", sm.shape.getShapeTitle(self.shape.uuid))

    gui:setText("ext_values_header", GetLocalization("ext_GuiValues", getLang()))
    gui:setText("ext_values_text", GetLocalization("ext_GuiOutput", getLang()))

    gui:createDropDown("ext_values_dropdown", "cl_onValueSelect", self.cl.extractions)
    if isAnyOf(self.cl.extract, self.cl.extractions) then
        gui:setSelectedDropDownItem("ext_values_dropdown", self.cl.extract)
    end

    gui:open()
end

function Extractor:cl_onValueSelect(selected)
    self.network:sendToServer("sv_onValueSelect", selected)
end
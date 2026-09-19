if _G["EffectManager"] == nil then
    sm.log.error("[TANK PARTS] Not hooked")
	return
end
sm.TankParts.hooked = true
print("Tank Parts hooked")


dofile("$SURVIVAL_DATA/Scripts/game/tools/CarryTool.lua")


local function showInsertInteraction()
	local keyBindingText = sm.gui.getKeyBinding( "Create", true )
	sm.gui.setInteractionText( "", keyBindingText, "#{INTERACTION_INSERT}" )
end


local _onEquip = CarryTool.client_onEquip
---@diagnostic disable-next-line: duplicate-set-field
function CarryTool:client_onEquip(animate)
    local query = sm.TankParts.query(sm.container.itemUuid(sm.localPlayer.getCarry())[1])
    if query and query.breechlist then
        self.cl.tpBreechlist = query.breechlist
    end

    return _onEquip(self, animate)
end

---@diagnostic disable-next-line: duplicate-set-field
function CarryTool:client_onEquippedUpdate(primary, secondary)
	local playerCarry = sm.localPlayer.getCarry()
	local playerCarryColor = sm.localPlayer.getCarryColor()
	local carryUuid = sm.container.itemUuid(playerCarry)[1]
	local characterShape = sm.item.getCharacterShape(carryUuid)
	local character = self.tool:getOwner().character

    if self.cl.tpInsert then
        local hit, raycastResult = sm.localPlayer.getRaycast(2)
    end

    self:cl_tryTumbleDrop(character, playerCarry, carryUuid, characterShape, playerCarryColor)

    if primary == sm.tool.interactState.start and characterShape or secondary == sm.tool.interactState.start  then
        local consumeInput = self:cl_tryDrop(primary, secondary, playerCarry, carryUuid, characterShape, playerCarryColor)
        return consumeInput, consumeInput
    elseif self:cl_tryInsert(character, primary, playerCarry, carryUuid, playerCarryColor) then
        return true, true
    end

	return false, false
end

local _client_onUpdate = CarryTool.client_onUpdate
---@diagnostic disable-next-line: duplicate-set-field
function CarryTool:client_onUpdate(dt)
    if self.cl.tpInsert then
        sm.gui.setProgressFraction(self.cl.tpInsertProgress)
        self.cl.tpInsertProgress = self.cl.tpInsertProgress + dt

        if self.cl.tpInsertProgress >= 1 then
            local carry = sm.localPlayer.getCarry()
            self.network:sendToServer("sv_sendInsertShell", { interactable = self.cl.tpInsert.interactable, container = carry, uuid = sm.container.itemUuid(carry)[1] })

            self.cl.tpInsert = nil
            self.cl.tpInsertProgress = nil
            self.cl.tpBreechlist = nil
        end
    end

    return _client_onUpdate(self, dt)
end

local _cl_tryInsert = CarryTool.cl_tryInsert
---@diagnostic disable-next-line: duplicate-set-field
function CarryTool:cl_tryInsert(character, primary, carry, carryUuid, color)
    if self.cl.tpBreechlist then
        local hit, raycastResult = sm.localPlayer.getRaycast(2)

        if self.cl.tpInsert and not (hit and (raycastResult.type == "body") and (raycastResult:getShape() == self.cl.tpInsert)) then
            self.cl.tpInsert = nil
            self.cl.tpInsertProgress = nil
        elseif hit and (raycastResult.type == "body") then
            local uuid = raycastResult:getShape().uuid

            if isAnyOf(uuid, self.cl.tpBreechlist) then
                showInsertInteraction()

                if (primary == sm.tool.interactState.start) or (primary == sm.tool.interactState.hold) then
                    if not self.cl.tpInsert then
                        self.cl.tpInsert = raycastResult:getShape()
                        self.cl.tpInsertProgress = 0
                    end
                else
                    self.cl.tpInsert = nil
                    self.cl.tpInsertProgress = nil
                end
            end

            return true
        end

        return false
    end

    return _cl_tryInsert(self, character, primary, carry, carryUuid, color)
end

function CarryTool:sv_sendInsertShell(args)
    sm.event.sendToInteractable(args.interactable, "sv_receiveLoad", { container = args.container, uuid = args.uuid })
end

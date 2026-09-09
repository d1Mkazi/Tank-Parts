if _G["EffectManager"] == nil then
	print("[TANK PARTS] Not hooked")
	return
end
sm.TankParts.hooked = true
print("[TANK PARTS] Hooked")


dofile("$SURVIVAL_DATA/Scripts/game/tools/CarryTool.lua")


--print("[TANK PARTS] CarryTool status:")
--print(CarryTool)
--print(CarryTool.client_onEquippedUpdate)

function CarryTool:client_onEquippedUpdate(primaryState, secondaryState)
	local playerCarry = sm.localPlayer.getCarry()
	local playerCarryColor = sm.localPlayer.getCarryColor()
	local carryUuid = sm.container.itemUuid(playerCarry)[1]
	local characterShape = sm.item.getCharacterShape(carryUuid)
	local character = self.tool:getOwner().character

    print("----------------------------------------")
    print("client_onEquippedUpdate =>", playerCarry)
    print("client_onEquippedUpdate =>", playerCarryColor)
    print("client_onEquippedUpdate =>", carryUuid, "| Name:", sm.shape.getShapeTitle(carryUuid))
    print("client_onEquippedUpdate =>", characterShape)
    print("client_onEquippedUpdate =>", character)

	self:cl_tryTumbleDrop(character, playerCarry, carryUuid, characterShape, playerCarryColor)

    if primaryState == sm.tool.interactState.start and characterShape or secondaryState == sm.tool.interactState.start  then
        local consumeInput = self:cl_tryDrop(primaryState, secondaryState, playerCarry, carryUuid, characterShape, playerCarryColor)
        return consumeInput, consumeInput
    elseif self:cl_tryInsert(character, primaryState, playerCarry, carryUuid, playerCarryColor) then
        return true, true
    end

	return false, false
end

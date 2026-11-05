if _G["EffectManager"] == nil then
    sm.log.error("[TANK PARTS] Not hooked")
	return
end
sm.TankParts.hooked = true
print("Tank Parts hooked")


---@param any any
---@param of table
---@param sub string|number key of `of` table: `of[sub]`
function isAnyOfSub(any, of, sub)
    for k, v in pairs(of) do
        if any == v[sub] then
            return true
        end
    end
    return false
end

---@param value any
---@param t table
---@param sub string|number
function getTableBySubValue(value, t, sub)
    for k, v in pairs(t) do
        if value == v[sub] then
            return v
        end
    end
    return nil
end

---@param pos Vec3
---@param center Vec3
---@param dx number
---@param dy number
---@param dz number
function isInBoxCentered(pos, center, dx, dy, dz)
    return
        ((math.abs(center.x - pos.x)) <= dx) and
        ((math.abs(center.y - pos.y)) <= dy) and
        ((math.abs(center.z - pos.z)) <= dz)
end


dofile("$SURVIVAL_DATA/Scripts/game/tools/CarryTool.lua")


local function showInsertInteraction()
	local keyBindingText = sm.gui.getKeyBinding( "Create", true )
	sm.gui.setInteractionText( "", keyBindingText, "#{INTERACTION_INSERT}" )
end


local _onEquip = CarryTool.client_onEquip
---@diagnostic disable-next-line: duplicate-set-field
function CarryTool:client_onEquip(animate)
    local query = sm.TankParts.query(sm.container.itemUuid(sm.localPlayer.getCarry())[1])
    if query and query.receivers then
        self.cl.tpReceivers = query.receivers
        print("RECEIVERS:", self.cl.tpReceivers)
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
        self.cl.tpInsertProgress = self.cl.tpInsertProgress + dt
        sm.gui.setProgressFraction(self.cl.tpInsertProgress)

        if self.cl.tpInsertProgress >= 1 then
            local carry = sm.localPlayer.getCarry()
            self.network:sendToServer("sv_sendInsertShell", { interactable = self.cl.tpInsert.interactable, container = carry, uuid = sm.container.itemUuid(carry)[1] })

            self.cl.tpInsert = nil
            self.cl.tpInsertProgress = nil
        end
    end

    return _client_onUpdate(self, dt)
end

local _cl_tryInsert = CarryTool.cl_tryInsert
---@diagnostic disable-next-line: duplicate-set-field
function CarryTool:cl_tryInsert(character, primary, carry, carryUuid, color)
    if self.cl.tpReceivers then
        local hit, raycastResult = sm.localPlayer.getRaycast(2)

        if self.cl.tpInsert and not (hit and (raycastResult.type == "body") and (raycastResult:getShape() == self.cl.tpInsert) and (true)) then
            self.cl.tpInsert = nil
            self.cl.tpInsertProgress = nil
        elseif hit and (raycastResult.type == "body") then
            local shape = raycastResult:getShape()
            if not shape.interactable then
                return false
            end

            if isAnyOfSub(shape.uuid, self.cl.tpReceivers, 1) then
                showInsertInteraction()

                if (primary == sm.tool.interactState.start) or (primary == sm.tool.interactState.hold) then
                    if not self.cl.tpInsert then
                        self.cl.tpInsert = raycastResult:getShape()
                        self.cl.tpInsertProgress = 0
                    end
                else
                    self.cl.tpInsert = nil
                    self.cl.tpInsertProgress = nil

                    return false
                end
            end


            local pos = shape.worldPosition
            local area = getTableBySubValue(shape.uuid, self.cl.tpReceivers, 1)
            if not area then
                return false
            end
            area = area[2]

            pos = pos + shape.right * area[4] + shape.at * area[5] + shape.up * area[6]
            --[[
            local diff = pos - raycastResult.pointWorld
            print(("DIFF:   { %g %g %g }"):format(diff.x * 4, diff.y * 4, diff.z * 4))
            print(("VALID:  { %g %g %g }"):format(area[1] * 4, area[2] * 4, area[3] * 4))
            print(("AVAIL:  { %g %g %g }"):format((area[1] - math.abs(diff.x)) * 4, (area[2] - math.abs(diff.y)) * 4, (area[3] - math.abs(diff.z)) * 4))
            --]]

            if not isInBoxCentered(raycastResult.pointWorld, pos, area[1], area[2], area[3]) then
                self.cl.tpInsert = nil
                self.cl.tpInsertProgress = nil
                return false
            end

            return true
        end

        return false
    end

    return _cl_tryInsert(self, character, primary, carry, carryUuid, color)
end

local _client_onUnequip = CarryTool.client_onUnequip
---@diagnostic disable-next-line: duplicate-set-field
function CarryTool:client_onUnequip(animate)
    self.cl.tpInsert = nil
    self.cl.tpInsertProgress = nil

    --[[
    if self._effect then
        self._effect:destroy()
        self._effect = nil
    end
    ]]

    return _client_onUnequip(self, animate)
end


function CarryTool:sv_sendInsertShell(args)
    sm.event.sendToInteractable(args.interactable, "sv_receiveLoad", { container = args.container, uuid = args.uuid })
end

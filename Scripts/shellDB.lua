dofile("utils.lua")

ShellDB = {
    --[[     -----------------------------------DEPRECATED AND I AM TOO LAZY TO CHANGE THAT--------------------------------------------------------------------------
        template:
        Shell = {
            type (string)
            UUID (string) -- uuid of bullet to render
            initialSpeed = (number)
            friction = (number) -- percentage of speed reduction per block (0.001 = 1%)
            penetrationCapacity (number) -- the maximum sum of blocks durability shell can break
            maxDurability (number) -- the maximum durability of a block shell can break
            fuseSensitivity (number) -- the minimum sum of blocks durability shell must break to explode
            onHit (function(shelldata))
        }
    ]]
    AP = {
        type = "armor-piercing",
        shellUUID = "ec19cdbf-865e-401c-9c5e-f111bad25840",
        bulletUUID = "ec19cdbf-865e-401c-9c5e-f122bed25800",
        initialSpeed = 140,
        friction = 0.003,
        penetrationCapacity = 12,
        maxDurability = 7,
        fuseSensitivity = 5,
        onHit = function(data)
            local vel = data.vel
            print("shell velocity:", vel)
            local dir = vel:normalize() / 4
            print("shell direction:", dir)

            local r = data.penetrationCapacity / 100 * 15
            data.penetrationCapacity = math.random(data.penetrationCapacity - r, data.penetrationCapacity + r)
            local toughness = 0
            local raycast = sm.physics.raycast
            local dt = data.dt
            local hit, result = true, data.hit
            print("\nnormalLocal =", result.normalLocal, "\nnormalWorld =", result.normalWorld)
            local point = nil
            while hit do
                point = result.pointWorld

                if result.type == "character" then
                    print("char")
                    sm.event.sendToPlayer(result:getCharacter():getPlayer(), "sv_e_receiveDamage", {damage = 100})

                elseif result.type == "terrainSurface" or result.type == "terrainAsset" then
                    sm.physics.explode(point, 7, 1, 2, 70, "PropaneTank - ExplosionSmall")
                    return false

                elseif result.type == "body" then
                    if true then
                        data.vel = data.vel  * result.normalWorld
                        return true
                    end

                    local shape = result:getShape()
                    local durability = sm.item.getQualityLevel(shape.uuid)

                    if durability > data.maxDurability or durability > data.penetrationCapacity then
                        sm.physics.explode(point, 1, 1, 2, 70, "PropaneTank - ExplosionSmall")
                        shrapnelExplosion(point, vel, 10, 120, 85)
                        return false
                    end
                    if shape.isBlock then
                        local targetLocalPosition = shape:getClosestBlockLocalPosition( point )
                        shape:destroyBlock(targetLocalPosition)
                    else
                        if getTableByValue(tostring(shape.uuid), ShellDB, "shellUUID") then
                            sm.event.sendToInteractable(shape.interactable, "sv_explode")
                        else
                            shape:destroyPart(0)
                        end
                    end
                    point = shape.worldPosition
                    data.penetrationCapacity = data.penetrationCapacity - durability
                    toughness = toughness + durability

                elseif result.type == "joint" then
                    local joint = result:getJoint()
                    point = joint.worldPosition
                    data.penetrationCapacity = data.penetrationCapacity - 1
                    toughness = toughness + 1

                elseif result.type == "harvestable" then
                    local harvestable = result:getHarvestable()
                    point = harvestable.worldPosition
                    harvestable:destroy()
                    data.penetrationCapacity = data.penetrationCapacity - 3
                    toughness = toughness + 3
                end

                hit, result = raycast(point, point + dir)
            end

            local pos = point + dir
            print("Difference:", pos - point)
            shrapnelExplosion(pos, vel, 3, 120, 35)
            if data.fuseSensitivity > toughness then return true end
            shrapnelExplosion(pos, vel, 10, 120, 85)

            return false
        end
    },
    HE = {
        type = "high-explosive",
        shellUUID = "ec19cdbf-865e-401c-9c5e-f111bad25841",
        bulletUUID = "ec19cdbf-865e-401c-9c5e-f122bed25800",
        initialSpeed = 80,
        friction = 0.005,
        onHit = function (data)
            local vel = data.vel
            local pos = data.hit.pointWorld

            sm.physics.explode(pos, 4, 2.5, 6, 140, "PropaneTank - ExplosionBig")
            shrapnelExplosion(pos, vel, 20, 360, 70)

            return false
        end
    }
    --[[UUIDs = {
        HEATShell = "ec19cdbf-865e-401c-9c5e-f111bad25842",
        AShell = "ec19cdbf-865e-401c-9c5e-f111bad25843",
        SCShell = "ec19cdbf-865e-401c-9c5e-f111bad25844"
    }]]
}

AllowedShells = {
    --[[
        template:
        type = {
            -- allowed shells (string) 
        }
    ]]
    ww2 = {
        "ec19cdbf-865e-401c-9c5e-f111bad25840", -- AP shell
        "ec19cdbf-865e-401c-9c5e-f111bad25841", -- HE shell
        "", -- HEAT shell
        "" -- SC shell
    },
    artillery = {
    },
    modern = {
    }
}
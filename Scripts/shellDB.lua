dofile("utils.lua")

---@param result RaycastResult
---@return number
local function getAngle(result)
    local angle = math.deg(math.acos(result.directionWorld:dot(result.normalWorld) / result.directionWorld:length() * result.normalLocal:length()))
    while angle > 90 do angle = angle - 90 end
    return math.floor(angle + 0.5)
end

---@param base number base durability of the block/shape
---@param angle number hit angle
---@return number
local function getDurability(base, angle)
    -- idk how to call them so...
    local x = math.floor(angle * 100 / 90)
    local y = (100 - x) * 0.85
    local z = base / 100
    return base + z * y
end

---@param vel Vec3 velocity (direction)
---@param normal Vec3 Normal (world)
---@return Vec3
local function doRicochet(vel, normal)
    return -vel:rotate(math.rad(180), normal) --[[@as Vec3]]
end

ShellDB = {
    --[[
        template:
        Shell = {
            type (string)
            shellUUID (string) -- uuid of the shell
            bulletUUID (string) -- uuid of the bullet
            initialSpeed = (number)
            friction = (number) -- percentage of speed reduction per frame / 1000
            penetrationCapacity (number) -- the maximum sum of block durabilities shell can break
            penetrationLoss (number)
            maxDurability (number) -- the maximum durability of a block shell can break
            fuseSensitivity (number) -- the minimum sum of block durabilities shell must break to explode
            maxAngle (number) -- the angle the projectile ricochets at
            onHit (function(shelldata))

            -- you may not set "penetrationCapacity", "penetrationLoss", "maxDurability", "fuseSensitivity" if they are not used
        }
    ]]
    --[[ 85mm ]]--
    AP_85 = {
        type = "armor-piercing",
        shellUUID = "ec19cdbf-865e-401c-9c5e-f111bad25840",
        bulletUUID = "ec19cdbf-865e-401c-9c5e-f122bed25800",
        initialSpeed = 240,
        friction = 0.003,
        penetrationCapacity = 20,
        penetrationLoss = 2.5,
        maxDurability = 7.6,
        fuseSensitivity = 5,
        maxAngle = 18,
        onHit = function(data)
            local vel = data.vel
            local dir = vel:normalize() / 4

            local capacity = data.penetrationCapacity
            local random = capacity * 0.15
            data.penetrationCapacity = capacity - math.random(random, -random)

            local toughness = 0
            local raycast = sm.physics.raycast
            local hit, result = true, data.hit

            local angle = getAngle(result)

            local point = nil
            while hit do
                point = result.pointWorld

                if result.type == "character" then
                    sm.event.sendToPlayer(result:getCharacter():getPlayer(), "sv_e_receiveDamage", { damage = 100 }) -- why don't you work?

                elseif result.type == "terrainSurface" or result.type == "terrainAsset" then
                    sm.physics.explode(point, 7, 1, 2, 70, "PropaneTank - ExplosionSmall")
                    return false

                elseif result.type == "body" then
                    local shape = result:getShape()
                    local durability = sm.item.getQualityLevel(shape.uuid)
                    if angle <= data.maxAngle then
                        data.vel = doRicochet(vel, result.normalWorld)
                        data.penetrationCapacity = data.penetrationCapacity - durability * 0.2
                        return true
                    end
                    durability = getDurability(durability, angle)

                    if durability > data.maxDurability or durability > data.penetrationCapacity then
                        sm.physics.explode(point, 1, 1, 2, 70, "PropaneTank - ExplosionSmall")
                        shrapnelExplosion(point, vel, 10, 120, 85)
                        return false
                    end
                    if shape.isBlock then
                        local targetLocalPosition = shape:getClosestBlockLocalPosition(point)
                        shape:destroyBlock(targetLocalPosition)
                    else
                        shape:destroyPart(0)
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
            shrapnelExplosion(pos, vel, 3, 120, 35)
            if data.fuseSensitivity > toughness then return true end
            shrapnelExplosion(pos, vel, 10, 120, 85)

            return false
        end
    },
    HE_85 = {
        type = "high-explosive",
        shellUUID = "ec19cdbf-865e-401c-9c5e-f111bad25841",
        bulletUUID = "ec19cdbf-865e-401c-9c5e-f122bed25801",
        initialSpeed = 120,
        friction = 0.005,
        onHit = function(data)
            local vel = data.vel
            local pos = data.hit.pointWorld

            sm.physics.explode(pos, 4, 2.5, 6, 140, "PropaneTank - ExplosionBig")
            shrapnelExplosion(pos, sm.vec3.new(0, 65, 0), 20, 360, 70)

            return false
        end
    },

    --[[ 122mm ]]--

    --[[ 152mm ]]--
    HE_152 = {
        type = "high_explosive",
        shellUUID = "ec19cdbf-865e-401c-9c5e-f122bed25802",
        bulletUUID = "ec19cdbf-865e-401c-9c5e-f122bed25802",
        initialSpeed = 150,
        friction = 0.01,
        onHit = function(data)
            local vel = data.vel
            local pos = data.hit.pointWorld

            sm.physics.explode(pos, 7, 4, 6, 250, "Shell - Howitzer Hit", nil, { DLM_Volume = 30, DLM_Pitch = 0.9 })
            shrapnelExplosion(pos, sm.vec3.new(0, 65, 0), 35, 360, 100)

            return false
        end
    }

    --HEATShell = "ec19cdbf-865e-401c-9c5e-f111bad25842",
    --AShell = "ec19cdbf-865e-401c-9c5e-f111bad25843", -- DEPRECATED
    --SCShell = "ec19cdbf-865e-401c-9c5e-f111bad25844"
}

ShellList = {
    [85] = {
        unitary = {
            "ec19cdbf-865e-401c-9c5e-f111bad25840", -- AP shell
            "ec19cdbf-865e-401c-9c5e-f111bad25841" -- HE Shell
        },
        separated = {
        },
        cartridges = {
        }
    },
    [122] = {
        unitary = {
        },
        separated = {
        },
        cartridges = {
        }
    },
    [152] = {
        unitary = {
        },
        separated = {
            "ec19cdbf-865e-401c-9c5e-f122bed25802", -- HE Bullet
        },
        cartridges = {
            "cc19cdbf-865e-401c-9c5e-f111ccc25801" -- regular
        }
    }

    -- DEPRECATED --
    --unitary = {
    --    "ec19cdbf-865e-401c-9c5e-f111bad25840", -- AP shell
    --    "ec19cdbf-865e-401c-9c5e-f111bad25841" -- HE Shell
    --},
    --separated = {
    --    "ec19cdbf-865e-401c-9c5e-f122bed25801", -- HE Bullet
    --    "cc19cdbf-865e-401c-9c5e-f111ccc25801", -- WW2 cartridge
    --}
}

CartridgeList = {
    --[[
    template:
        name = {
            original (string) -- UUID of the original (filled) case
            used (string) -- UUID of the used (empty) case
        }
    ]]
    regular152 = {
        original = "cc19cdbf-865e-401c-9c5e-f111ccc25801",
        used = "ec19cdbf-865e-401c-9c5e-f111ccc25801"
    }
}
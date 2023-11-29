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

-- Hit functions

function __hit_ap(data)
    local vel = data.vel
    local dir = vel:normalize() / 4

    local capacity = data.penetrationCapacity
    local random = capacity * 0.15
    data.penetrationCapacity = capacity - math.random(random, -random)

    local toughness = 0
    local raycast = sm.physics.raycast
    local hit, result = true, data.hit

    local angle = getAngle(result)

    local point = result.pointWorld
    while hit do
        point = result.pointWorld

        if result.type == "terrainSurface" or result.type == "terrainAsset" then
            return false

        elseif result.type == "character" then
            sm.event.sendToPlayer(result:getCharacter():getPlayer(), "sv_e_receiveDamage", { damage = 100 }) -- why don't you work?

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
                shrapnelExplosion(point, vel, 3, 10, 35)
                return false
            end

            if shape.isBlock then
                local targetLocalPosition = shape:getClosestBlockLocalPosition(point)
                shape:destroyBlock(targetLocalPosition, sm.vec3.one())
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

    --pos = point + dir / 4
    shrapnelExplosion(point, vel, 3, 120, 35)
    if data.fuseSensitivity > toughness then return true end
    shrapnelExplosion(point, vel, 15, 120, 85)

    return false
end

function __hit_he(data)
    local pos = data.hit.pointWorld

    sm.physics.explode(pos, data.explosion.strength, 1, 5, data.explosion.impulse, "PropaneTank - ExplosionBig")
    shrapnelExplosion(pos, data.vel:normalize() * 30, data.explosion.shrapnel, 360, 80)

    return false
end

function __hit_he_howitzer(data)
    local pos = data.hit.pointWorld

    --if sm.cae_injected then
    --    sm.physics.explode(pos, 7, 3, 6, 250, "Shell - Howitzer Hit", nil, { CAE_Volume = 30, CAE_Pitch = 0.9 })
    --else
    --    sm.physics.explode(pos, 7, 3, 6, 250, "PropaneTank - ExplosionBig")
    --end

    sm.physics.explode(pos, 7, 3, 6, 250, "PropaneTank - ExplosionBig")
    shrapnelExplosion(pos, sm.vec3.new(0, 70, 0), 80, 360, 100)

    return false
end

function __hit_heat(data)
    local vel = data.vel
    local dir = vel:normalize() / 4

    local capacity = data.penetrationCapacity
    local random = capacity * 0.15
    data.penetrationCapacity = capacity - math.random(random, -random)

    local raycast = sm.physics.raycast
    local explode = sm.physics.explode
    local hit, result = true, data.hit

    local angle = getAngle(result)

    local point = nil
    while capacity do
        point = result.pointWorld

        if result.type == "character" then
            sm.event.sendToPlayer(result:getCharacter():getPlayer(), "sv_e_receiveDamage", { damage = 100 }) -- why don't you work?

        elseif result.type == "body" then
            local shape = result:getShape()
            local durability = sm.item.getQualityLevel(shape.uuid)
            durability = getDurability(durability, angle)

            if durability > data.maxDurability or durability > data.penetrationCapacity then
                shrapnelExplosion(point, vel, 3, 10, 35)
                return false
            end

            if shape.isBlock then
                local targetLocalPosition = shape:getClosestBlockLocalPosition(point)
                shape:destroyBlock(targetLocalPosition, sm.vec3.one())
            else
                shape:destroyPart(0)
            end
            point = shape.worldPosition
            data.penetrationCapacity = data.penetrationCapacity - durability

        elseif result.type == "joint" then
            local joint = result:getJoint()
            point = joint.worldPosition
            data.penetrationCapacity = data.penetrationCapacity - 1

        elseif result.type == "harvestable" then
            local harvestable = result:getHarvestable()
            point = harvestable.worldPosition
            return false

        else
            capacity = capacity - 8
        end

        hit, result = raycast(point, point + dir)
    end

    --pos = point + dir / 4
    shrapnelExplosion(point, vel, 5, 25, 100)

    return false
end

ShellDB = {
    --[[ 85mm ]]--
    AP_85 = {
        bulletUUID = "ec19cdbf-865e-401c-9c5e-f122bed25800",
        initialSpeed = 550,
        penetrationCapacity = 20,
        penetrationLoss = 2.5,
        maxDurability = 7.6,
        fuseSensitivity = 5,
        maxAngle = 18,
        onHit = __hit_ap
    },
    HE_85 = {
        bulletUUID = "ec19cdbf-865e-401c-9c5e-f122bed25801",
        initialSpeed = 460,
        explosion = {
            strength = 3,
            impulse = 100,
            shrapnel = 40
        },
        onHit = __hit_he
    },

    --[[ 122mm ]]--
    AP_122 = {
        bulletUUID = "ec19cdbf-865e-122c-9c5e-f122bed25800",
        initialSpeed = 620,
        mass = 20,
        penetrationCapacity = 35,
        penetrationLoss = 2.8,
        maxDurability = 8.5,
        fuseSensitivity = 5,
        maxAngle = 22,
        onHit = __hit_ap
    },
    HE_122 = {
        bulletUUID = "ec19cdbf-865e-122c-9c5e-f122bed25801",
        initialSpeed = 500,
        mass = 25,
        explosion = {
            strength = 4,
            impulse = 200,
            shrapnel = 55
        },
        onHit = __hit_he
    }
}


--[[ CALIBERS ]]--

-- 2 - british
-- 4 - american
-- 5 - soviet
-- 6 - howitzer -- CLASS
-- 7 - german
-- 9 - modern -- CLASS

------------------

ShellList = {
    [75] = {
        unitary = {
            {
                shellUuid = "ec19cdbf-865e-401c-9c5e-f111bad25840", -- AP shell
                caseUuid = nil,
                shellData = ShellDB.AP_85,
                usedUuid = "cc19cdbf-865e-401c-9c5e-f111ccc25800"
            },
            {
                shellUuid = "ec19cdbf-865e-401c-9c5e-f111bad25841", -- HE Shell
                caseUuid = nil,
                shellData = ShellDB.HE_85,
                usedUuid = "cc19cdbf-865e-401c-9c5e-f111ccc25800"
            }
        },
        separated = {
        }
    },
    [76] = {
        unitary = {
            {
                shellUuid = "ec19cdbf-865e-401c-9c5e-f111bad25840", -- AP shell
                caseUuid = nil,
                shellData = ShellDB.AP_85,
                usedUuid = "cc19cdbf-865e-401c-9c5e-f111ccc25800"
            },
            {
                shellUuid = "ec19cdbf-865e-401c-9c5e-f111bad25841", -- HE Shell
                caseUuid = nil,
                shellData = ShellDB.HE_85,
                usedUuid = "cc19cdbf-865e-401c-9c5e-f111ccc25800"
            }
        },
        separated = {
        }
    },
    [88] = {
        unitary = {
            { -- AP Shell
                shellUuid = "ec18cdbf-865e-122c-9c5e-f111bad25840",
                caseUuid = nil,
                shellData = ShellDB.AP_122,
                usedUuid = "cc19cdbf-865e-122c-9c5e-f111ccc25800"
            },
            { -- HE Shell
                shellUuid = "ec18cdbf-865e-122c-9c5e-f111bad25841",
                caseUuid = nil,
                shellData = ShellDB.HE_122,
                usedUuid = "cc19cdbf-865e-122c-9c5e-f111ccc25800"
            },
        },
        separated = {
        }
    },
    [152] = {
        unitary = {
        },
        separated = {
            {
                shellUuid = "ec19cdbf-865e-401c-9c5e-f122bed25802", -- HE Bullet
                caseUuid = "cc19cdbf-865e-401c-9c5e-f111ccc25801",
                shellData = {
                    bulletUUID = "ec19cdbf-865e-401c-9c5e-f122bed25802",
                    initialSpeed = 250,
                    mass = 35,
                    onHit = __hit_he_howitzer
                },
                usedUuid = "ec19cdbf-865e-401c-9c5e-f111ccc25801"
            }
        }
    }
}
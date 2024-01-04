dofile("utils.lua")

local explode = sm.physics.explode


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
    local result = data.hit
    local pos = result.pointWorld

    if not data.lastAngle then
        data.lastAngle = getAngle(result)
    end
    local angle = data.lastAngle

    local vel = data.vel
    if not data.dir then
        data.dir = vel:normalize() / 4
    end
    local dir = data.dir

    local fuse = data.fuse
    local durability = 0

    local raycastTarget = result.type
    if raycastTarget == "terrainSurface" or raycastTarget == "terrainAsset" then
        print("[TANK PARTS] HIT TERRAIN")
        explode(pos, 1, 0.1, 1, 1, nil --[[ Dirt explosion ]])
        data.alive = false
        return

    elseif raycastTarget == "body" then
        print("[TANK PARTS] HIT BODY")
        local shape = result:getShape()
        print("[TANK PARTS] getShape() ->", shape, "NAME:", sm.shape.getShapeTitle(shape.uuid))
        if not sm.exists(shape) then
            print("[TANK PARTS] SHAPE DOESN'T EXIST")
            data.alive = true
            return
        else
            durability = sm.item.getQualityLevel(shape.uuid) or 1
            if angle <= data.maxAngle then
                data.vel = doRicochet(vel, result.normalWorld)
                data.penetrationCapacity = data.penetrationCapacity - durability * 0.2
                data.alive = true
                return
            end
            durability = getDurability(durability, angle)
            print("[TANK PARTS] DURALITY:", durability, "/", data.maxDurability, "| Capacity:", data.penetrationCapacity)

            if durability > data.maxDurability or durability > data.penetrationCapacity or durability == 0 then
                print("[TANK PARTS] TOO DURAB BLOCK HIT")
                shrapnelExplosion(pos, vel, 3, 0, 35, true)
                data.alive = false
                return
            else
                if shape.isBlock then
                    local targetLocalPosition = shape:getClosestBlockLocalPosition(pos)
                    shape:destroyBlock(targetLocalPosition, sm.vec3.one())
                else
                    shape:destroyPart(0)
                end
            end

            pos = shape.worldPosition
        end

    elseif raycastTarget == "joint" then
        local joint = result:getJoint()

        local shapeA = joint.shapeA
        local body = shapeA.body
        local uuid = shapeA.uuid
        local _pos = shapeA:getClosestBlockLocalPosition(pos)
        pos = shapeA.worldPosition

        if shapeA.isBlock then
            shapeA:destroyBlock(_pos, sm.vec3.one())

            body:createBlock(uuid, sm.vec3.one(), _pos)
        else
            local xAxis = shapeA.xAxis
            local zAxis = shapeA.zAxis

            shapeA:destroyPart(0)

            body:createPart(uuid, _pos, zAxis, xAxis)
        end

        durability = 0.5

    elseif raycastTarget == "character" then

    elseif raycastTarget == "harvestable" then

    end

    data.penetrationCapacity = data.penetrationCapacity - durability
    data.fuse = (fuse or 0) + durability

    data.pos = pos

    data.alive = true
end

function __hit_he(data)
    local pos = data.hit.pointWorld
    local shrapnelVelocity = data.vel:normalize() * 30
    local explosionData = data.explosion

    if data.hit.type == "body" and sm.item.getQualityLevel(data.hit:getShape().uuid) > explosionData.strength then
        sm.physics.explode(pos, explosionData.strength, 1, 5, explosionData.impulse, "PropaneTank - ExplosionBig")
        shrapnelVelocity = -shrapnelVelocity --[[@as Vec3]]
    else
        sm.physics.explode(pos, 1, 0.1, 5, explosionData.impulse, "PropaneTank - ExplosionBig")
    end

    shrapnelExplosion(pos, shrapnelVelocity, explosionData.shrapnel, 360, 80)

    data.alive = false
end

function __hit_he_howitzer(data)
    local pos = data.hit.pointWorld

    sm.physics.explode(pos, 7, 3, 6, 250, "Shell - Howitzer Hit")
    shrapnelExplosion(pos, sm.vec3.new(0, 70, 0), 80, 360, 100)

    data.alive = false
end

-- Explosion functions

function __exp_ap(data)
    shrapnelExplosion(data.pos, data.vel, 15, 80, 85)
end



ShellList = {
    --[[ template:
        breech = {
            unitary = {
                {
                }
            },
            separated = {
                {
                }
            }
        }
    ]]--

    --[[ SOVIET ]]--

    -- soviet 76mm
    zis5 = {
        unitary = {
            { -- AP Shell
                shellUuid = "ec19cdbf-865e-401c-9c5e-f111bad25840",
                caseUuid = nil,
                shellData = {
                    bulletUUID = "ec19cdbf-865e-401c-9c5e-f122bed25800",
                    initialSpeed = 655,
                    mass = 6.5,
                    penetrationCapacity = 24,
                    penetrationLoss = 2.5,
                    maxDurability = 7.6,
                    fuseSensitivity = 5,
                    maxAngle = 20,
                    onHit = __hit_ap,
                    explode = __exp_ap
                },
                usedUuid = "cc19cdbf-865e-401c-9c5e-f111ccc25800"
            },
            { -- HE Shell
                shellUuid = "ec19cdbf-865e-401c-9c5e-f111bad25841",
                caseUuid = nil,
                shellData = {
                    bulletUUID = "ec19cdbf-865e-401c-9c5e-f122bed25801",
                    initialSpeed = 680,
                    mass = 6.2,
                    explosion = {
                        strength = 3,
                        impulse = 100,
                        shrapnel = 40
                    },
                    onHit = __hit_he,
                },
                usedUuid = "cc19cdbf-865e-401c-9c5e-f111ccc25800"
            }
        }
    },

    -- soviet 76mm
    f34 = {
        unitary = {
            { -- AP Shell
                shellUuid = "ec19cdbf-865e-401c-9c5e-f111bad25840",
                caseUuid = nil,
                shellData = {
                    bulletUUID = "ec19cdbf-865e-401c-9c5e-f122bed25800",
                    initialSpeed = 655,
                    mass = 6.5,
                    penetrationCapacity = 24,
                    penetrationLoss = 2.5,
                    maxDurability = 7.6,
                    fuseSensitivity = 5,
                    maxAngle = 20,
                    onHit = __hit_ap,
                    explode = __exp_ap
                },
                usedUuid = "cc19cdbf-865e-401c-9c5e-f111ccc25800"
            },
            { -- HE Shell
                shellUuid = "ec19cdbf-865e-401c-9c5e-f111bad25841",
                caseUuid = nil,
                shellData = {
                    bulletUUID = "ec19cdbf-865e-401c-9c5e-f122bed25801",
                    initialSpeed = 680,
                    mass = 6.2,
                    explosion = {
                        strength = 3,
                        impulse = 100,
                        shrapnel = 40
                    },
                    onHit = __hit_he
                },
                usedUuid = "cc19cdbf-865e-401c-9c5e-f111ccc25800"
            }
        }
    },

    -- soviet 152mm howitzer
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
    },

    -- soviet 122mm
    d25t = {
        separated = {
            { -- AP Shell
                shellUuid = "ec19cdbf-865e-401c-9c5e-f122bed25803",
                caseUuid = "ec19cdbf-865e-401c-9c5e-f111ccc25802",
                shellData = {
                    bulletUUID = "ec19cdbf-865e-401c-9c5e-f122bed25803",
                    initialSpeed = 795,
                    mass = 25,
                    penetrationCapacity = 44,
                    penetrationLoss = 2.5,
                    maxDurability = 8.8,
                    fuseSensitivity = 5,
                    maxAngle = 20,
                    onHit = __hit_ap,
                    explode = __exp_ap
                },
                usedUuid = "ec19cdbf-865e-401c-9c5e-f111ccc25803"
            },
            { -- HE Shell
                shellUuid = "ec19cdbf-865e-401c-9c5e-f122bed25804",
                caseUuid = "ec19cdbf-865e-401c-9c5e-f111ccc25802",
                shellData = {
                    bulletUUID = "ec19cdbf-865e-401c-9c5e-f122bed25804",
                    initialSpeed = 795,
                    mass = 25,
                    explosion = {
                        strength = 4,
                        impulse = 120,
                        shrapnel = 55
                    },
                    onHit = __hit_he
                },
                usedUuid = "ec19cdbf-865e-401c-9c5e-f111ccc25803"
            }
        }
    },

    --[[ GERMAN ]]--

    -- german 75mm
    kwk37 = {
        unitary = {
            { -- AP Shell
                shellUuid = "ec19cdbf-865e-401c-9c5e-f111bad25840",
                caseUuid = nil,
                shellData = {
                    bulletUUID = "ec19cdbf-865e-401c-9c5e-f122bed25800",
                    initialSpeed = 385,
                    mass = 6.78,
                    penetrationCapacity = 15,
                    penetrationLoss = 2.5,
                    maxDurability = 7.2,
                    fuseSensitivity = 5,
                    maxAngle = 20,
                    onHit = __hit_ap,
                    explode = __exp_ap
                },
                usedUuid = "cc19cdbf-865e-401c-9c5e-f111ccc25800"
            },
            { -- HE Shell
                shellUuid = "ec19cdbf-865e-401c-9c5e-f111bad25841",
                caseUuid = nil,
                shellData = {
                    bulletUUID = "ec19cdbf-865e-401c-9c5e-f122bed25801",
                    initialSpeed = 420,
                    mass = 5.74,
                    explosion = {
                        strength = 3,
                        impulse = 100,
                        shrapnel = 40
                    },
                    onHit = __hit_he
                },
                usedUuid = "cc19cdbf-865e-401c-9c5e-f111ccc25800"
            }
        }
    },

    -- german 88mm
    kwk36_88 = {
        unitary = {
            { -- AP Shell
                shellUuid = "ec18cdbf-865e-122c-9c5e-f111bad25840",
                caseUuid = nil,
                shellData = {
                    bulletUUID = "ec19cdbf-865e-122c-9c5e-f122bed25800",
                    initialSpeed = 773,
                    mass = 10.2,
                    penetrationCapacity = 32,
                    penetrationLoss = 2.5,
                    maxDurability = 8.5,
                    fuseSensitivity = 5,
                    maxAngle = 25,
                    onHit = __hit_ap,
                    explode = __exp_ap
                },
                usedUuid = "cc19cdbf-865e-122c-9c5e-f111ccc25800"
            },
            { -- HE Shell
                shellUuid = "ec18cdbf-865e-122c-9c5e-f111bad25841",
                caseUuid = nil,
                shellData = {
                    bulletUUID = "ec19cdbf-865e-122c-9c5e-f122bed25801",
                    initialSpeed = 820,
                    mass = 9,
                    explosion = {
                        strength = 4,
                        impulse = 200,
                        shrapnel = 55
                    },
                    onHit = __hit_he
                },
                usedUuid = "cc19cdbf-865e-122c-9c5e-f111ccc25800"
            },
        }
    },

    -- german 75mm
    kwk42 = {
        unitary = {
            { -- AP Shell
                shellUuid = "ec18cdbf-865e-122c-9c5e-f111bad25840",
                caseUuid = nil,
                shellData = {
                    bulletUUID = "ec19cdbf-865e-122c-9c5e-f122bed25800",
                    initialSpeed = 935,
                    mass = 6.8,
                    penetrationCapacity = 38,
                    penetrationLoss = 2.5,
                    maxDurability = 8.8,
                    fuseSensitivity = 5,
                    maxAngle = 20,
                    onHit = __hit_ap,
                    explode = __exp_ap
                },
                usedUuid = "cc19cdbf-865e-122c-9c5e-f111ccc25800"
            },
            { -- HE Shell
                shellUuid = "ec18cdbf-865e-122c-9c5e-f111bad25841",
                caseUuid = nil,
                shellData = {
                    bulletUUID = "ec19cdbf-865e-122c-9c5e-f122bed25801",
                    initialSpeed = 700,
                    mass = 5.74,
                    explosion = {
                        strength = 4,
                        impulse = 200,
                        shrapnel = 55
                    },
                    onHit = __hit_he
                },
                usedUuid = "cc19cdbf-865e-122c-9c5e-f111ccc25800"
            },
        }
    },
}
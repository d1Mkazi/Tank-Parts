---@diagnostic disable: lowercase-global
dofile("utils.lua")

local explode = sm.physics.explode

local _killPlayerVec3 = sm.vec3.new(0.5, 0, 0)
local _shrapnelVec3 = sm.vec3.new(0, 70, 0)
local _dynarmorUuid = sm.uuid.new("20c1cd64-f44b-4022-9f67-502254caec69")


---@param result RaycastResult
---@return number
local function getAngle(result)
    return math.floor((math.deg(math.acos(result.directionWorld:dot(result.normalWorld) / result.directionWorld:length() * result.normalLocal:length())) % 90) + 0.5)
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

---@param character Character the player character
---@param vel Vec3 velocity (direction)
local function killPlayer(character, vel)
    shrapnelExplosion(character.worldPosition - ((vel:normalize() + _killPlayerVec3) * 0.25), vel, 2, 0, 1000, true)
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
        if shape.interactable and shape.interactable.publicData and shape.interactable.publicData.isShell then
            print("[TANK PARTS] HIT SHELL")
            sm.event.sendToInteractable(shape.interactable, "sv_explode")
            data.alive = false
            return
        end
        durability = sm.item.getQualityLevel(shape.uuid) or 1
        if angle <= data.maxAngle then
            print("[TANK PARTS] RICOCHET")
            data.vel = doRicochet(vel, result.normalWorld)
            data.dir = data.vel:normalize() / 4
            data.penetrationCapacity = data.penetrationCapacity - durability * 0.2
            data.alive = true
            explode(pos, 1, 0.1, 1, 1, "Shell - NoPenetration", nil, { CAE_Volume = 4, CAE_Pitch = 5 })
            return
        end
        durability = getDurability(durability, angle)
        print("[TANK PARTS] DURALITY:", durability, "/", data.maxDurability, "| Capacity:", data.penetrationCapacity)

        if durability > data.maxDurability or durability > data.penetrationCapacity then
            print("[TANK PARTS] TOO DURAB BLOCK HIT")
            shrapnelExplosion(pos - dir * 0.5, vel, 5, 5, 35, true)
            explode(pos, 1, 0.1, 1, 1, "Shell - NoPenetration", nil, { CAE_Volume = 6, CAE_Pitch = 0.7 })
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

    elseif raycastTarget == "joint" then
        local joint = result:getJoint()

        local shapeA = joint.shapeA
        local body = shapeA.body
        local uuid = shapeA.uuid
        local _pos = shapeA:getClosestBlockLocalPosition(pos)

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
        print("SENDING DAMAGE TO player", result:getCharacter():getPlayer().name)
        killPlayer(result:getCharacter(), vel)
        data.alive = false
        return

    elseif raycastTarget == "harvestable" then
        local harvestable = result:getHarvestable()
        point = harvestable.worldPosition
        explode(pos, 1, 0.1, 1, 1, nil --[[ Dirt explosion ]])
        durability = 3
    end

    data.penetrationCapacity = data.penetrationCapacity - durability
    data.fuse = (data.fuse or 0) + durability

    data.pos = pos

    data.alive = true
end

function __hit_heat(data)
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
        local uuid = shape.uuid
        if shape.interactable and shape.interactable.publicData then
            if shape.interactable.publicData.isShell then
                print("[TANK PARTS] HIT SHELL")
                sm.event.sendToInteractable(shape.interactable, "sv_explode")
                data.alive = false
                return
            elseif shape.interactable.publicData.isDA then
                print("[TANK PARTS] HIT DYNAMIC ARMOR")
                sm.event.sendToInteractable(shape.interactable, "sv_explode")
                data.alive = false
                return
            end
        end

        durability = sm.item.getQualityLevel(uuid) or 1
        durability = getDurability(durability, angle)
        print("[TANK PARTS] DURALITY:", durability, "/ INF", "| Capacity:", data.penetrationCapacity)

        if durability > data.penetrationCapacity then
            print("[TANK PARTS] TOO DURAB BLOCK HIT")
            shrapnelExplosion(pos - dir * 0.5, vel, 5, 5, 35, true)
            explode(pos, 1, 0.1, 1, 1, "Shell - NoPenetration", nil, { CAE_Volume = 6, CAE_Pitch = 0.7 })
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

    elseif raycastTarget == "joint" then
        local joint = result:getJoint()

        local shapeA = joint.shapeA
        local body = shapeA.body
        local uuid = shapeA.uuid
        local _pos = shapeA:getClosestBlockLocalPosition(pos)

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
        print("SENDING DAMAGE TO player", result:getCharacter():getPlayer().name)
        killPlayer(result:getCharacter(), vel)

    elseif raycastTarget == "harvestable" then
        explode(pos, 1, 0.1, 1, 1, nil --[[ Dirt explosion ]])
        durability = 3
        data.alive = false
        return
    else
        print("[TANK PARTS] HEAT HIT AIR")
        durability = 10
        print("[TANK PARTS] DURALITY:", durability, "/ INF", "| Capacity:", data.penetrationCapacity)
    end

    data.penetrationCapacity = data.penetrationCapacity - durability
    data.fuse = (data.fuse or 0) + durability

    data.pos = pos

    data.alive = data.penetrationCapacity > 0
end

function __hit_he(data)
    local pos = data.hit.pointWorld
    local shrapnelVelocity = data.vel:normalize() * 30
    local explosionData = data.explosion

    if data.hit.type == "body" and sm.item.getQualityLevel(data.hit:getShape().uuid) > explosionData.strength then
        explode(pos, explosionData.strength, 1, 5, explosionData.impulse, "PropaneTank - ExplosionBig")
        shrapnelVelocity = -shrapnelVelocity --[[@as Vec3]]
    else
        explode(pos, 1, 0.1, 5, explosionData.impulse, "PropaneTank - ExplosionBig")
    end

    shrapnelExplosion(pos, shrapnelVelocity, explosionData.shrapnel, 360, 80)

    data.alive = false
end

function __hit_he_howitzer(data)
    local pos = data.hit.pointWorld

    -- play sound
    if sm.cae_injected then
        sm.effect.playEffect("Shell - HowitzerHit", pos)
    else
        sm.effect.playEffect("Shell - HowitzerHitVanilla", pos)
    end

    -- explode
    explode(pos, 7, 3, 6, 250, "Shell - HowitzerExplosion")
    shrapnelExplosion(pos, _shrapnelVec3, 80, 360, 100)

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
                shellData = {
                    bulletUUID = "ec19cdbf-865e-401c-9c5e-f122bed25800",
                    initialSpeed = 655,
                    mass = 6.5,
                    penetrationCapacity = 24,
                    penetrationLoss = 1.5,
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
                shellData = {
                    bulletUUID = "ec19cdbf-865e-401c-9c5e-f122bed25800",
                    initialSpeed = 655,
                    mass = 6.5,
                    penetrationCapacity = 24,
                    penetrationLoss = 1.5,
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
            },
            { -- HEAT Shell
                shellUuid = "c6c071b9-eb8b-4fea-af79-27781272aebb",
                shellData = {
                    bulletUUID = "c6c071b9-eb8b-4fea-af79-27781272aabb",
                    initialSpeed = 335,
                    mass = 3.94,
                    penetrationCapacity = 22,
                    onHit = __hit_heat,
                    isHEAT = true
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
                    penetrationLoss = 1.5,
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
                        shrapnel = 60
                    },
                    onHit = __hit_he
                },
                usedUuid = "ec19cdbf-865e-401c-9c5e-f111ccc25803"
            }
        }
    },

    -- russian 125mm
    ["2a46m"] = {
        separated = {
            { -- APFSDS Shell
                shellUuid = "9a261482-b89a-490d-9ac9-fb827b54d47a",
                caseUuid = "e64cb1bd-f23f-4f5c-beac-527a3fb8a5ee",
                shellData = {
                    bulletUUID = "eefe50e3-db7f-4a0e-bfa0-6afd29805d35",
                    initialSpeed = 1660,
                    mass = 5.12,
                    penetrationCapacity = 115,
                    penetrationLoss = 1.5,
                    maxDurability = 9.6,
                    maxAngle = 25,
                    onHit = __hit_ap
                },
                usedUuid = "25eb1652-5709-4072-b585-8af149e58565"
            },
            { -- HEATFS Shell
                shellUuid = "a01b60fd-7d77-4c20-a1d3-d19cce0a5216",
                caseUuid = "e64cb1bd-f23f-4f5c-beac-527a3fb8a5ee",
                shellData = {
                    bulletUUID = "db68b0e4-4091-4cf9-a39a-2516118d0005",
                    initialSpeed = 905,
                    mass = 19,
                    penetrationCapacity = 100,
                    onHit = __hit_heat,
                    isHEAT = true
                },
                usedUuid = "25eb1652-5709-4072-b585-8af149e58565"
            },
            { -- HEFS Shell
                shellUuid = "804c66ee-ca5f-49c0-a09e-c2c43f142787",
                caseUuid = "e64cb1bd-f23f-4f5c-beac-527a3fb8a5ee",
                shellData = {
                    bulletUUID = "804c66ee-ca5f-49c0-a09e-c2c43f142787",
                    initialSpeed = 850,
                    mass = 23,
                    explosion = {
                        strength = 4,
                        impulse = 200,
                        shrapnel = 65
                    },
                    onHit = __hit_he
                },
                usedUuid = "25eb1652-5709-4072-b585-8af149e58565"
            }
        }
    },

    --[[ GERMAN ]]--

    -- german 75mm
    kwk37 = {
        unitary = {
            { -- AP Shell
                shellUuid = "ec19cdbf-865e-401c-9c5e-f111bad25840",
                shellData = {
                    bulletUUID = "ec19cdbf-865e-401c-9c5e-f122bed25800",
                    initialSpeed = 385,
                    mass = 6.78,
                    penetrationCapacity = 15,
                    penetrationLoss = 1.5,
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
                shellData = {
                    bulletUUID = "ec19cdbf-865e-122c-9c5e-f122bed25800",
                    initialSpeed = 773,
                    mass = 10.2,
                    penetrationCapacity = 32,
                    penetrationLoss = 1.5,
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
            { -- HEAT Shell
                shellUuid = "ec18cdbf-865e-122c-5c2e-f111bad25842",
                shellData = {
                    bulletUUID = "ec19cdbf-865e-401c-5c2e-f122bed25805",
                    initialSpeed = 600,
                    mass = 7.64,
                    penetrationCapacity = 28,
                    onHit = __hit_heat,
                    isHEAT = true
                },
                usedUuid = "cc19cdbf-865e-122c-9c5e-f111ccc25800"
            },
        }
    },

    -- german 75mm
    kwk42 = {
        unitary = {
            { -- AP Shell
                shellUuid = "58f3b1cd-187d-4d61-bcaf-a69a53d1e57b",
                shellData = {
                    bulletUUID = "0f198808-999d-41fa-80e4-ee91dcdfd9e6",
                    initialSpeed = 935,
                    mass = 6.8,
                    penetrationCapacity = 38,
                    penetrationLoss = 1.5,
                    maxDurability = 8.8,
                    fuseSensitivity = 5,
                    maxAngle = 20,
                    onHit = __hit_ap,
                    explode = __exp_ap
                },
                usedUuid = "922a09d0-0c62-45c6-8152-10e3418fd17d"
            },
            { -- HE Shell
                shellUuid = "58f3b1cd-187d-4d61-bcaf-a69a53d1e57c",
                shellData = {
                    bulletUUID = "40e59811-ff73-4902-a30e-7bf5b0f2dc0e",
                    initialSpeed = 700,
                    mass = 5.74,
                    explosion = {
                        strength = 4,
                        impulse = 200,
                        shrapnel = 55
                    },
                    onHit = __hit_he
                },
                usedUuid = "922a09d0-0c62-45c6-8152-10e3418fd17d"
            },
            { -- APCR Shell
                shellUuid = "87d27add-3284-4005-8648-f84f404350ca",
                shellData = {
                    bulletUUID = "aabd945c-f1b2-4603-82ef-889c59a407d9",
                    initialSpeed = 1120,
                    mass = 4.75,
                    penetrationCapacity = 45,
                    penetrationLoss = 3,
                    maxDurability = 9,
                    maxAngle = 25,
                    onHit = __hit_ap
                },
                usedUuid = "922a09d0-0c62-45c6-8152-10e3418fd17d"
            },
        }
    },

    --[[ AMERICAN ]]--

    -- american 37mm
    m5 = {
        unitary = {
            { -- AP Shell
                shellUuid = "ec18cdbf-865e-122c-9c5e-f111bad25842",
                shellData = {
                    bulletUUID = "ec19cdbf-865e-401c-9c5e-f122bed25805",
                    initialSpeed = 884,
                    mass = 0.87,
                    penetrationCapacity = 21,
                    penetrationLoss = 1.5,
                    maxDurability = 7.2,
                    maxAngle = 20,
                    onHit = __hit_ap
                },
                usedUuid = "ec19cdbf-865e-401c-9c5e-f111ccc25804"
            }
        }
    },

    -- american 105mm
    ["m68a1"] = {
        unitary = {
            { -- APFSDS Shell
                shellUuid = "6ac63e27-89a2-4259-b102-3cf3324711da",
                shellData = {
                    bulletUUID = "97223124-8714-4901-9887-ea341a2018ae",
                    initialSpeed = 1509,
                    mass = 3.4,
                    penetrationCapacity = 55,
                    penetrationLoss = 1.5,
                    maxDurability = 9.5,
                    maxAngle = 25,
                    onHit = __hit_ap
                },
                usedUuid = "71e7eacc-7b16-4606-8660-e04d80eaab58"
            },
            { -- HEATFS Shell
                shellUuid = "31660af8-ec14-4c3b-8590-559315937018",
                shellData = {
                    bulletUUID = "e17ea55b-7506-4881-b4b9-93fe53b26615",
                    initialSpeed = 1174,
                    mass = 10.5,
                    penetrationCapacity = 60,
                    onHit = __hit_heat,
                    isHEAT = true
                },
                usedUuid = "71e7eacc-7b16-4606-8660-e04d80eaab58"
            }
        },
    },

    -- american 90mm
    ["m54"] = {
        unitary = {
            { -- AP Shell
                shellUuid = "bb01be63-7a2c-4671-a434-d06f8c231bd1",
                shellData = {
                    bulletUUID = "161b35eb-10fd-4843-9f0f-89a38db060cb",
                    initialSpeed = 853,
                    mass = 10.91,
                    penetrationCapacity = 35,
                    penetrationLoss = 1.5,
                    maxDurability = 8,
                    fuseSensitivity = 5,
                    maxAngle = 25,
                    onHit = __hit_ap,
                    explode = __exp_ap
                },
                usedUuid = "cc19cdbf-865e-122c-9c5e-f111ccc25800"
            },
            { -- HE Shell
                shellUuid = "ad36f078-7d06-47a7-b7ea-5c9bfa61a8f2",
                shellData = {
                    bulletUUID = "8c1f90bd-cdf6-40d5-98dc-e6f3d57267f6",
                    initialSpeed = 823,
                    mass = 10.55,
                    explosion = {
                        strength = 4,
                        impulse = 200,
                        shrapnel = 40
                    },
                    onHit = __hit_he
                },
                usedUuid = "cc19cdbf-865e-122c-9c5e-f111ccc25800"
            },
            { -- APCR Shell
                shellUuid = "f0bb7ce9-f6c8-4182-8fa6-a04602a06bc8",
                shellData = {
                    bulletUUID = "b0790545-2d49-4c1c-b5bf-e7702358c870",
                    initialSpeed = 1165,
                    mass = 5.7,
                    penetrationCapacity = 55,
                    penetrationLoss = 3,
                    maxDurability = 9,
                    maxAngle = 25,
                    onHit = __hit_ap
                },
                usedUuid = "cc19cdbf-865e-122c-9c5e-f111ccc25800"
            }
        },
    }
}
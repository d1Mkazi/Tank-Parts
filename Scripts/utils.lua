local shrapnel = sm.uuid.new("5e8eeaae-b5c1-4992-bb21-dec5254ce111")
local shrapnelWeak = sm.uuid.new("5e8eeaae-b5c1-4992-bb21-dec5254ce222")

-- Use to spawn shrapnel
---@param position Vec3
---@param velocity Vec3
---@param count number number of projectiles
---@param spread number spread angle
---@param damage number
---@param weak? boolean
function shrapnelExplosion(position, velocity, count, spread, damage, weak)
    local _shrapnel = weak == true and shrapnelWeak or shrapnel

    for i = 1, count do
        local dir = sm.noise.gunSpread(velocity, spread)
        sm.projectile.projectileAttack(_shrapnel, damage, position, dir, HOST_PLAYER, nil, nil, 0)
    end
end

-- Use to search a table that has the value inside of another table
---@param search any the search value
---@param where table the first table
---@param special string the value id
---@return table
function getTableByValue(search, where, special)
    for k, t in pairs(where) do
        if t[special] then
            for k_, v in pairs(t) do
                if k_ == special and v == search then
                    return t
                end
            end
        end
    end
end

---@param original table
function copyTable(original)
    local new = {}
    for k, v in pairs(original) do
        new[k] = type(v) == "table" and copyTable(v) or v
    end

    return new
end

---@param table table
---@param index string|number
function hasIndex(table, index)
    for k, v in pairs(table) do
        if k == index then
            return true
        end
    end
    return false
end

---@param message string message to be shown
function errorMsg(message)
    print("[Tank Parts]", "-------------------[ ERROR CATCHED ]-------------------")
    print("[Tank Parts]", message)
    print("[Tank Parts]", "-------------------------------------------------------")
end


function getCases()
    if LOADED_CASES then return end
    LOADED_CASES = true

    CASE_LIST = {}

    local cartridges = sm.json.open("$CONTENT_DATA/Objects/Database/ShapeSets/cartridges.jsonc").partList
    for k, cartridge in ipairs(cartridges) do
        CASE_LIST[#CASE_LIST+1] = cartridge.uuid
    end
end


function getBreech()
    if LOADED_BREECH then return end
    LOADED_BREECH = true

    BREECH_LIST = {}

    local cartridges = sm.json.open("$CONTENT_DATA/Objects/Database/ShapeSets/breeches.jsonc").partList
    for k, cartridge in ipairs(cartridges) do
        BREECH_LIST[#BREECH_LIST+1] = cartridge.uuid
    end
end
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

    host = sm.player.getAllPlayers()[1]
    for i = 1, count do
        local dir = sm.noise.gunSpread(velocity, spread)
        sm.projectile.projectileAttack(_shrapnel, damage, position, dir, host, nil, nil, 0)
    end
end

-- Use to search a table that has the value inside of another table
---@param search any the search value
---@param where table the first table
---@param special string the value id
---@return table table can be nil if not found
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

---@param ... table
---@return table
function uniteTables(...)
    local new = {}
    for _, t in pairs{...} do
        for k, v in pairs(t) do
            new[k] = type(v) == "table" and copyTable(v) or v
        end
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

---@param a Vec3
---@param b Vec3
---@return boolean
function sameAxis(a, b)
    return math.abs(a:dot(b)) == 1
end

---@param ... boolean
function xor(...)
    local res = false
    for k, stm in pairs{...} do
        res = res ~= stm
    end
    return res
end

---@param any table
---@param of table
---@param ex string subkey to compare
---@return boolean
function isAnyOfEx(any, of, ex)
    for k, v in pairs(of) do
        if v[ex] == any[ex] then
            return true
        end
    end
    return false
end

---@param t table
---@return integer --(at least supposed to)
function getFirstIndex(t)
    for k, _ in pairs(t) do
        return k
    end
end
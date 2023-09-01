local shrapnel = sm.uuid.new("5e8eeaae-b5c1-4992-bb21-dec5254ce722")

-- Use to spawn shrapnel
---@param position Vec3
---@param velocity Vec3
---@param count number number of projectiles
---@param spread number spread angle
---@param damage number
function shrapnelExplosion(position, velocity, count, spread, damage)
    local host = sm.player.getAllPlayers()[1]
    for i = 1, count do
        local dir = sm.noise.gunSpread(velocity, spread)
        sm.projectile.projectileAttack(shrapnel, damage, position, dir, host, nil, nil, 0)
    end
end

-- Use to search a table that has the value inside of another table
---@param search any the search value
---@param where table the first table
---@param special string the value id
---@return table|nil
function getTableByValue(search, where, special)
    for k, t in pairs(where) do
        if t[special] then
            for i, v in pairs(t) do
                if i == special and v == search then
                    return t
                end
            end
        end
    end
    return nil
end
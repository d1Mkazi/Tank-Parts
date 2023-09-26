dofile("utils.lua")
dofile("SCS.lua")

---@class ShellProjectile : ToolClass
ShellProjectile = class()
ShellProjectile.projectiles = {}
ShellProjectile.queue = {}

-- function aliases
local raycast = sm.physics.raycast

-- constants
local g = nil
local yAxis = sm.vec3.new(0, 1, 0)

function ShellProjectile:server_onCreate()
    g = sm.physics.getGravity()
end

function ShellProjectile:server_onRefresh()
    g = sm.physics.getGravity()
end

--[[  SERVER  ]]--

---@param data table table with shell data from shellDB.lua
---@param vel Vec3 velocity
function ShellProjectile:sv_createShell(data, pos, vel)
    local newShell = copyTable(data)
    newShell.pos = pos
    newShell.vel = vel
    table.insert(ShellProjectile.queue, newShell)
end

function ShellProjectile:server_onFixedUpdate(dt)
    for k, proj in pairs(ShellProjectile.projectiles) do
        if proj.hit then
            if not proj:onHit() then
                self:destroyShell(proj, k)
            end
            proj.hit = nil
        end
    end
end

--[[  CLIENT  ]]--

function ShellProjectile:client_onCreate()
    check() -- Check is the mod infected
end

---@param shell table
function ShellProjectile:cl_createShell(shell)
    local effect = sm.effect.createEffect("ShapeRenderable")
    effect:setParameter("uuid", sm.uuid.new(shell.bulletUUID))
    effect:setPosition(shell.pos)
    effect:setScale(sm.vec3.new(0.25, 0.25, 0.25))
    effect:start()
    shell.effect = effect

    table.insert(ShellProjectile.projectiles, shell)
end

function ShellProjectile:client_onUpdate(dt)
    for k, shell in pairs(ShellProjectile.queue) do
        self:cl_createShell(shell)
        ShellProjectile.queue[k] = nil
    end

    for k, proj in pairs(ShellProjectile.projectiles) do
        if not proj.effect:isPlaying() then
            proj.effect:setParameter("uuid", proj.bulletUUID)
            proj.effect:start()
        end

        local pos = proj.pos
        local vel = proj.vel

        if pos.z < -50 then
            self:destroyShell(proj, k)
            return
        end

        local hit, result = raycast(pos, pos + vel * dt * 1.2)
        if hit then
            proj.hit = result
        else
            proj.effect:setPosition(pos)
            proj.effect:setRotation(sm.vec3.getRotation(yAxis, vel))
        end

        vel = vel * (1 - proj.friction) - sm.vec3.new(0, 0, g * dt)
        pos = pos + vel * dt
        proj.pos = pos
        proj.vel = vel

        if proj.penetrationLoss then
            proj.penetrationCapacity = proj.penetrationCapacity - proj.penetrationCapacity * (proj.penetrationLoss * dt)
        end


        proj.dt = dt
    end
end


---@param key? number
function ShellProjectile:destroyShell(shell, key)
    local effect = shell.effect
    effect:destroy()

    if key then
        ShellProjectile.projectiles[key] = nil
        return
    end

    for k, proj in pairs(ShellProjectile.projectiles) do
        if proj == shell then
            ShellProjectile.projectiles[k] = nil
            return
        end
    end
end
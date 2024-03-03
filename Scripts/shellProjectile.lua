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
local MINIMAL_HEIGHT = -50

function ShellProjectile:server_onCreate()
    self:init()
end

function ShellProjectile:server_onRefresh()
    self:init()
end

function ShellProjectile:init()
    g = sm.physics.getGravity()
end

--[[  SERVER  ]]--

---@param data table
function ShellProjectile:sv_createShell(data)
    local newShell = copyTable(data.data)
    newShell.pos = data.pos
    newShell.vel = data.vel
    table.insert(ShellProjectile.queue, newShell)
end

function ShellProjectile:server_onFixedUpdate(dt)
    for k, proj in pairs(ShellProjectile.projectiles) do
        if proj.hit then
            local lastHit = proj.hit
            if not proj.lastAngle then -- first hit
                print("[TANK PARTS] CALCULATING FIRST HIT")
                local success, res = pcall(proj.onHit, proj)
                if not success then
                    errorMsg(("onHit function: %s"):format(tostring(res)))
                    proj.pos.z = MINIMAL_HEIGHT - 1 -- to delete shell
                    return
                end
                if not proj.alive then
                    print("[TANK PARTS] SHELL DIED")

                    proj.hit = nil
                    proj.lastAngle = nil
                    proj.fuse = nil

                    proj.pos.z = MINIMAL_HEIGHT - 1 -- to delete shell
                end
            else -- not first hit
                print("[TANK PARTS] CALCULATING SECOND HIT")
                local alive = proj.alive
                if alive then -- alive 1
                    local hit, result = raycast(lastHit.pointWorld - proj.dir, lastHit.pointWorld + proj.dir * 2)
                    proj.hit = result
                    print("[TANK PARTS] IF HIT?")
                    if not hit and not proj.isHEAT then -- raycast 0 & HEAT 0
                        print("[TANK PARTS] NO HIT AFTER HIT")
                        if proj.fuse and proj.explode and proj.fuse >= proj.fuseSensitivity then
                            print("[TANK PARTS] SHELL FUSED")
                            proj:explode()

                            proj.pos.z = MINIMAL_HEIGHT - 1 -- to delete shell
                        else
                            print("[TANK PARTS] SHELL NOT FUSED")

                            proj.hit = nil
                            proj.lastAngle = nil
                            proj.fuse = nil
                            proj.pos = result.pointWorld

                            shrapnelExplosion(proj.pos, proj.vel, 3, 20, 85, true)
                        end
                    elseif ((result.type == "body" and lastHit.type == "body")
                           and (lastHit:getShape() and result:getShape()) and (lastHit:getShape().worldPosition ~= result:getShape().worldPosition))
                           or result.type ~= "body" then -- raycast 1 || HEAT 1
                        print("[TANK PARTS] HIT AFTER HIT")
                        local success, res = pcall(proj.onHit, proj)
                        if not success then
                            errorMsg(("onHit function: %s"):format(tostring(res)))
                            proj.pos.z = MINIMAL_HEIGHT - 1 -- to delete shell
                            return
                        end
                    else
                        print("[TANK PARTS] HIT SAME SHAPE")

                        proj.hit = nil
                        proj.lastAngle = nil
                        proj.fuse = nil
                        proj.pos = result.pointWorld
                    end
                else -- alive 0
                    print("[TANK PARTS] SHELL DIED")

                    proj.hit = nil
                    proj.lastAngle = nil
                    proj.fuse = nil

                    proj.pos.z = MINIMAL_HEIGHT - 1 -- to delete shell
                end
            end
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
            proj.effect:start()
        end

        if proj.pos.z < MINIMAL_HEIGHT then
            self:destroyShell(proj, k)
        elseif not proj.hit then
            local pos = proj.pos

            local vel = proj.vel
            vel = vel - sm.vec3.new(0, 0, g^2 * dt)
            local newPos = pos + vel * dt
            local hit, result = raycast(pos, newPos)
            if hit then
                proj.hit = result
                newPos = result.pointWorld
            else
                proj.effect:setPosition(newPos)
                proj.effect:setRotation(sm.vec3.getRotation(yAxis, vel))
            end

            proj.pos = newPos
            proj.vel = vel

            if proj.penetrationLoss then
                proj.penetrationCapacity = proj.penetrationCapacity - proj.penetrationCapacity * (proj.penetrationLoss * dt)
            end
        end
    end
end


---@param key? number
function ShellProjectile:destroyShell(shell, key)
    local effect = shell.effect
    effect:destroy()

    if key then
        ShellProjectile.projectiles[key] = nil
    else
        for k, proj in pairs(ShellProjectile.projectiles) do
            if proj == shell then
                ShellProjectile.projectiles[k] = nil
                return
            end
        end
    end
end
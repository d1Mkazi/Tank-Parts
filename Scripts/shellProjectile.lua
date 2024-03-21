dofile("shellDB.lua")
dofile("utils.lua")
dofile("SCS.lua")

---@class ShellProjectile : ToolClass
ShellProjectile = class()


--[[  SERVER  ]]--

function ShellProjectile:server_onCreate()
    self:init()
end

function ShellProjectile:server_onRefresh()
    self:init()
    print("[TANK PARTS] (SERVER) ShellProjectile reloaded")
end

function ShellProjectile:init()
    raycast = sm.physics.raycast
    getGravity = sm.physics.getGravity
    g = 10
    ShellProjectile.tool = self.tool

    self.projectiles = {}

    HOST_PLAYER = sm.player.getAllPlayers()[1]
    getCases()

    _LOADED_FEATURES = true
end

---@param data table
function ShellProjectile:sv_createShell(data)
    local shellData = data.data
    local newShell = copyTable(getTableByValue(shellData.shellUuid, ShellList[shellData.caliber][shellData.loading], "shellUuid").shellData)
    newShell.pos = data.pos
    newShell.vel = data.vel
    local k = #self.projectiles+1
    self.projectiles[k] = newShell
    self.network:sendToClients("cl_createShell", { shell = newShell, key = k })
end

function ShellProjectile:server_onFixedUpdate(dt)
    local _g = getGravity()
    if g ~= _g then
        self.network:sendToClients("cl_setGravity", _g)
    end
    g = _g

    local projectiles = self.projectiles
    if projectiles ~= nil then
        for k, proj in pairs(projectiles) do
            if proj.hit ~= nil then
                local lastHit = proj.hit
                if not proj.lastAngle then -- first hit
                    print("[TANK PARTS] CALCULATING FIRST HIT")
                    local success, res = pcall(proj.onHit, proj)
                    if not success then
                        errorMsg(("onHit function: %s"):format(tostring(res)))
                        print("[TANK PARTS] DESTROYING SHELL")
                        self.network:sendToClients("cl_updateShell", { key = k })
                        return
                    end
                    if not proj.alive then
                        print("[TANK PARTS] SHELL DIED")
                        proj.hit = nil
                        proj.lastAngle = nil
                        proj.fuse = nil
                        print("[TANK PARTS] DESTROYING SHELL")
                        self.network:sendToClients("cl_updateShell", { key = k })
                    end
                else -- not first hit
                    print("[TANK PARTS] CALCULATING SECOND HIT")
                    if proj.alive then -- alive 1
                        local raycastDestination = lastHit.pointWorld + proj.dir * 2
                        local hit, result = raycast(lastHit.pointWorld - proj.dir, raycastDestination)
                        proj.hit = result
                        print("[TANK PARTS] IF HIT?")
                        if not hit and not proj.isHEAT then -- raycast 0 & HEAT 0
                            print("[TANK PARTS] NO HIT AFTER HIT")
                            if proj.fuse and proj.explode and proj.fuse >= proj.fuseSensitivity then
                                print("[TANK PARTS] SHELL FUSED")
                                proj:explode()
                                print("[TANK PARTS] DESTROYING SHELL")
                                self.network:sendToClients("cl_updateShell", { key = k })
                            else
                                print("[TANK PARTS] SHELL NOT FUSED")
                                proj.hit = nil
                                proj.lastAngle = nil
                                proj.fuse = nil
                                --proj.pos = raycastDestination
                                shrapnelExplosion(proj.pos, proj.vel, 3, 20, 85, true)
                                self.network:sendToClients("cl_updateShell", { shelldata = { pos = proj.pos, vel = proj.vel }, key = k })
                            end
                        elseif ((result.type == "body" and lastHit.type == "body")
                                and (lastHit:getShape() and result:getShape()) and (lastHit:getShape().worldPosition ~= result:getShape().worldPosition))
                                or result.type ~= "body" then -- raycast 1 || HEAT 1
                            print("[TANK PARTS] HIT AFTER HIT")
                            local success, res = pcall(proj.onHit, proj)
                            if not success then
                                errorMsg(("onHit function: %s"):format(tostring(res)))
                                print("[TANK PARTS] DESTROYING SHELL")
                                self.network:sendToClients("cl_updateShell", { key = k })
                                return
                            end
                        elseif not result:getShape():isBlock() then
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
                        print("[TANK PARTS] DESTROYING SHELL")
                        self.network:sendToClients("cl_updateShell", { key = k })
                    end
                end
            end
        end
    end
end


--[[  CLIENT  ]]--

function ShellProjectile:client_onCreate()
    check() -- Check is the mod infected
    self:cl_init()
end

function ShellProjectile:client_onReload()
    self:cl_init()
    print("[TANK PARTS] (CLIENT) ShellProjectile reloaded")
end

function ShellProjectile:cl_init()
    raycast = sm.physics.raycast
    MINIMAL_HEIGHT = -50
    yAxis = sm.vec3.new(0, 1, 0)
    g = 10

    self.projectiles = {}
end

function ShellProjectile:cl_createShell(data)
    local k = data.key
    local shell = self.projectiles[k] or data.shell
    local effect = sm.effect.createEffect("ShapeRenderable")
    effect:setParameter("uuid", sm.uuid.new(shell.bulletUUID))
    effect:setPosition(shell.pos)
    effect:setScale(sm.vec3.one() * 0.25)
    effect:start()
    if self.projectiles[k] then
        self.projectiles[k].effect = effect
    else
        shell.effect = effect
        self.projectiles[k] = shell
    end
end

function ShellProjectile:client_onUpdate(dt)
    if self.projectiles ~= nil then
        for k, proj in pairs(self.projectiles) do
            if proj.effect then
                if not proj.effect:isPlaying() then
                    proj.effect:start()
                end

                proj.effect:setPosition(proj.pos)
                proj.effect:setRotation(sm.vec3.getRotation(yAxis, proj.vel))
            end
        end
    end
end

function ShellProjectile:client_onFixedUpdate(dt)
    if self.projectiles ~= nil then
        for k, proj in pairs(self.projectiles) do
            if proj.pos.z < MINIMAL_HEIGHT then
                self:cl_destroyShell(k)
            elseif not proj.hit then
                local pos = proj.pos

                local vel = proj.vel
                vel = vel - sm.vec3.new(0, 0, g^2 * dt)
                local newPos = pos + vel * dt
                local hit, result = raycast(pos, newPos)
                if hit then
                    proj.hit = result
                    newPos = result.pointWorld
                end

                proj.pos = newPos
                proj.vel = vel

                if proj.penetrationLoss then
                    proj.penetrationCapacity = proj.penetrationCapacity - proj.penetrationCapacity * (proj.penetrationLoss * dt)
                end
            end
        end
    end
end

---@param key? number
function ShellProjectile:cl_destroyShell(key)
    if self.projectiles[key].effect then
        self.projectiles[key].effect:destroy()
    end

    self.projectiles[key] = nil
end

function ShellProjectile:cl_getShell(data)
    self.projectiles[data.key] = data.shell
end

function ShellProjectile:cl_setGravity(gravity)
    g = gravity
end

function ShellProjectile:cl_updateShell(data)
    local shelldata = data.shelldata

    if not shelldata then
        self:cl_destroyShell(data.key)
        return
    end

    local key = data.key
    local shell = self.projectiles[key]
    shell.pos = shelldata.pos
    shell.vel = shelldata.vel

    self.projectiles[key] = shell
end
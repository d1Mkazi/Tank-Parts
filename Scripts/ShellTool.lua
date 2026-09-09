dofile("shellDB.lua")
dofile("utils.lua")
dofile("SCS.lua")

ShellTool = class()


sm.TankParts = sm.TankParts or {
    hooked = false
}

local raycast = sm.physics.raycast
local getGravity = sm.physics.getGravity
local g


--[[  SERVER  ]]--

function ShellTool:server_onCreate()
    self:init()
end

function ShellTool:server_onRefresh()
    self:init()
    print("[TANK PARTS] (SERVER) ShellTool reloaded")
end

function ShellTool:init()
    --ShellTool.tool = self.tool

    self.projectiles = {}
    getCases()
    getBreech()

    g = getGravity()
    g = g * g
end

---@param data table
function ShellTool:sv_createShell(data)
    local shellData = data.data
    local newShell = copyTable(getTableByValue(shellData.shellUuid, ShellList[shellData.caliber][shellData.loading], "shellUuid").shellData)
    newShell.pos = data.pos
    newShell.vel = data.vel
    local k = #self.projectiles+1
    self.projectiles[k] = newShell
    self.network:sendToClients("cl_createShell", { shell = newShell, key = k })
end

function ShellTool:server_onFixedUpdate(dt)
    local _g = getGravity()
    if g ~= _g then
        self.network:sendToClients("cl_setGravity", _g * _g)
    end
    g = _g * _g

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
                        -- IN THE NAME OF GOD, PLEASE WORK
                        --print("[TANK PARTS] HIT INFO:")
                        --print(("[TANK PARTS] result.type = %s | lastHit.type = %s"):format(result.type, lastHit.type))
                        --print("[TANK PARTS] ----------------------------------------------------")
                        --print(("[TANK PARTS] result:getShape()  -> %s"):format(result:getShape()))
                        --print(("[TANK PARTS] lastHit:getShape() -> %s"):format(lastHit:getShape()))
                        --print("[TANK PARTS] ----------------------------------------------------")
                        --if result:getShape() and lastHit:getShape() then
                        --    print("[TANK PARTS] ----------------------------------------------------")
                        --    print(("[TANK PARTS] result:getShape().worldPosition  = %s"):format(result:getShape().worldPosition))
                        --    print(("[TANK PARTS] lastHit:getShape().worldPosition = %s"):format(lastHit:getShape().worldPosition))
                        --    print("[TANK PARTS] ----------------------------------------------------")
                        --else
                        --    print("[TANK PARTS] NO GETSHAPE() FOUND")
                        --end
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
                                and (lastHit:getShape() and result:getShape()))-- and (lastHit:getShape().worldPosition ~= result:getShape().worldPosition))
                                or result.type ~= "body" or proj.isHEAT then -- raycast 1 || HEAT 1
                            print("[TANK PARTS] HIT AFTER HIT")
                            local success, res = pcall(proj.onHit, proj)
                            if not success then
                                errorMsg(("onHit function: %s"):format(tostring(res)))
                                print("[TANK PARTS] DESTROYING SHELL")
                                self.network:sendToClients("cl_updateShell", { key = k })
                                return
                            end
                        elseif not result:getShape().isBlock then
                            print("[TANK PARTS] HIT SAME SHAPE")
                            sm.log.warning("[TANK PARTS] HIT SAME SHAPE")
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

function ShellTool:client_onCreate()
    check() -- Check is the mod infected
    self:cl_init()
end

function ShellTool:client_onReload()
    self:cl_init()
    print("[TANK PARTS] (CLIENT) ShellTool reloaded")
end

function ShellTool:cl_init()
    raycast = sm.physics.raycast
    MINIMAL_HEIGHT = -50
    yAxis = sm.vec3.new(0, 1, 0)
    g = 10 * 10

    self.projectiles = {}
end

function ShellTool:cl_createShell(data)
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

function ShellTool:client_onUpdate(dt)
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

function ShellTool:client_onFixedUpdate(dt)
    if self.projectiles ~= nil then
        for k, proj in pairs(self.projectiles) do
            if proj.pos.z < MINIMAL_HEIGHT then
                self:cl_destroyShell(k)
            elseif not proj.hit then
                local pos = proj.pos
                local vel = proj.vel

                local newVel = vel + sm.vec3.new(0, 0, -(g * dt))
                local newPos = pos + (vel * dt) + sm.vec3.new(0, 0, -(g * dt * dt * 0.5))

                local hit, result = raycast(pos, newPos)
                if hit then
                    proj.hit = result
                    newPos = result.pointWorld
                end

                proj.pos = newPos
                proj.vel = newVel

                if proj.penetrationLoss then
                    proj.penetrationCapacity = proj.penetrationCapacity - proj.penetrationCapacity * (proj.penetrationLoss * dt)
                end
            end
        end
    end
end

---@param key? number
function ShellTool:cl_destroyShell(key)
    if self.projectiles[key].effect then
        self.projectiles[key].effect:destroy()
    end

    ---@diagnostic disable-next-line: need-check-nil
    self.projectiles[key] = nil
end

function ShellTool:cl_getShell(data)
    self.projectiles[data.key] = data.shell
end

function ShellTool:cl_setGravity(gravity)
    g = gravity
end

function ShellTool:cl_updateShell(data)
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


-- HOOK

print("[TANK PARTS] Hooking")
local _uuidNew = sm.uuid.new
sm.uuid.new = function(uuid)
    if not sm.TankParts.hooked then
        dofile("$CONTENT_88ba8635-775e-4759-9a69-3df71f653f19/Scripts/Hook.lua")
    end

    return _uuidNew(uuid)
end

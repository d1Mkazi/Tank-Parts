dofile("TankParts.lua")
dofile("$SURVIVAL_DATA/Scripts/util.lua")
dofile("shellDB.lua")
dofile("utils.lua")
dofile("SCS.lua")


---@class ToolClass
ShellTool = class()


local raycast = sm.physics.raycast
local getGravity = sm.physics.getGravity
local g

local yAxis -- client
local vec025 -- client


--[[  SERVER  ]]--

function ShellTool:server_onCreate()
    self:sv_init()
end

function ShellTool:server_onRefresh()
    self:sv_init()
    print("[TANK PARTS] (SERVER) ShellTool reloaded")
end

function ShellTool:sv_init()
    ShellTool.tool = self.tool

    --self.projectiles = {}
    getCases()
    getBreech()

    --sm.TankParts.fetch()

    --self.network:setClientData({ g = g })
    --self.network:sendToClients("cl_setGravity", g)
end

---@alias AmmoType
---| "ap"
---| "he"
---| "heat"
---| "apcr"
---| "rocket"

---@class AmmoData
---@field resistance number resistance coefficient
---@field onHit string OnHit function name
---@field caliber number
---@field type AmmoType
---@field area number cross section area
---@field mass number
---@field bullet Uuid

---@class ShellData
---@field ammoData AmmoData
---@field pos Vec3
---@field vel Vec3

---@param data ShellData
function ShellTool:sv_createShell(data)
    local ammo = data.ammoData
    local id = #self.projectiles + 1

    local shellData = {
        onHit = OnHit[ammo.onHit],
        pos = data.pos,
        vel = data.vel,
        mass = ammo.mass,
        area = ammo.area,
        type = ammo.type,
        caliber = ammo.caliber,
        resistance = ammo.resistance,
    }

    self.projectiles[id] = shellData

    self.network:sendToClients("cl_createShell", { shellData = shellData, id = id, bullet = ammo.bullet })
end

function ShellTool:server_onFixedUpdate(dt)
    local _g = getGravity()
    _g = _g * _g
    if g ~= _g then
        sm.log.info(("[TANK PARTS] SET NEW GRAVITY (%g => %g)"):format(g or -1, _g))
        g = _g
        self.network:sendToClients("cl_setGravity", g)
    end


    --local projectiles = self.projectiles
    if self.projectiles ~= nil then
        for k, proj in pairs(self.projectiles) do
            if proj.hit ~= nil then
                local lastHit = proj.hit
                if not proj.lastAngle then -- first hit
                    print("[TANK PARTS] CALCULATING FIRST HIT")
                    local success, res = pcall(proj.onHit, proj)
                    if not success then
                        sm.log.error("[TANK PARTS] onHit fail:", res)
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
                                sm.log.error("[TANK PARTS] onHit fail:", res)
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
    check() -- Check if the mod is infected
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

    self.projectiles = {}

    vec025 = sm.vec3.new(0.25, 0.25, 0.25)

    sm.TankParts.fetch()
end

function ShellTool:cl_createShell(data)
    local id = data.id
    local shellData = data.shellData

    print("Bullet =", data.bullet)

    local effect = sm.effect.createEffect("ShapeRenderable")
    effect:setParameter("uuid", sm.uuid.new(data.bullet))
    effect:setPosition(shellData.pos)
    effect:setScale(vec025)
    effect:start()
    shellData.effect = effect

    if self.projectiles[id] then
        self.projectiles[id].effect = effect
    else
        self.projectiles[id] = shellData
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
    dt = dt / 100
    if self.projectiles ~= nil then
        for k, proj in pairs(self.projectiles) do
            if proj.pos.z < MINIMAL_HEIGHT then
                self:cl_destroyShell(k)
            elseif not proj.hit then

                local newPos = proj.pos + proj.vel * dt
                local hit, result = raycast(proj.pos, newPos)
                if hit then
                    proj.hit = result
                    newPos = result.pointWorld
                end
                proj.pos = newPos

                local dragForce = proj.vel * -0.5 * 1.225 * proj.resistance * proj.vel:length()
                local downForce = sm.vec3.new(0, 0, proj.mass * g * dt)
                local totalForce = dragForce + downForce
                local acceleration = totalForce / proj.mass

                proj.vel = proj.vel + acceleration * dt
                --[[

                    Definitions:
                        Velocity(U) = speed * direction
                        Diameter(d) = caliber

                        Mass(m)
                        Force(F)
                        Acceleration(a) = F / m

                        Mach(M) = U / c

                        Volume(V)
                        Density(p) = m / V


                        Measures:
                            Force           Newtons
                            Speed           m/s
                            Acceleration    m/s^2
                            Mass            kg
                            Area            m^2
                            Volume          m^3

                        Assumptions:
                            T = 20C = 293K
                            p(air) = 1.225 kg/m^3


                    Fdrag = -0.5 * p * Cx * S * |Urel| * Urel

                        p    = air density
                        Cx   = resistance coefficient   // SHOULD BE PRECALCULATED
                        S    = Pi * r^2 = Pi * d^2 / 4  // SHOULD BE PRECALCULATED
                        Urel = Ushell - Uwind

                    Cx = 0.05 + 0.18/i + 0.08 * r  // referenced as Cx0

                        i = L / d
                        r = r / d  // if there's flat area on the head. Otherwise, =1


                    Cx(Mach > 0.8) = Cx0 * (1 + k * Mach)  // simplified

                        k = ?


                    Cx(Math > 1) = (0.8 / (i * sqrt(M^2 - 1))) + Cx0


                    c = sqrt(y * R * T) = sqrt(yR * T)  // speed of sound

                        y = 1.4
                        R = 287.053 J/(kg * K)

                        yR = 401.8742


                    A bullet is affected by:
                        drag force Fdrag
                        down force Fdown

                --]]

            end
        end
    end
end

---@param key number
function ShellTool:cl_destroyShell(key)
    if self.projectiles[key].effect then
        self.projectiles[key].effect:destroy()
    end

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


--[[ HOOK ]]--

sm.uuid.new = function(uuid)
    if not sm.TankParts.hooked then
        dofile("$CONTENT_88ba8635-775e-4759-9a69-3df71f653f19/Scripts/Hook.lua")
    else
        sm.uuid.new = sm.TankParts.uuidNew -- restore old behavior
    end

    return sm.TankParts.uuidNew(uuid)
end

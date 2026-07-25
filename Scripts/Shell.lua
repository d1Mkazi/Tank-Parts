Shell = class()


local safeProjectiles = {
    sm.uuid.new("2c3fc640-1a2e-4328-a872-f6d3f92d0fea"), -- water
    sm.uuid.new("5610b246-774e-4c1c-9adc-f87b4d993c43"), -- fertilizer
    sm.uuid.new("46292783-af41-49a5-91ef-092f22dfae91"), -- chemical
    sm.uuid.new("fb75426d-a8b4-4d0e-9600-1b782f54d02c"), -- oil
    sm.uuid.new("bdd04d53-2103-4c17-a3cb-ddbbae934ebb"), -- glowstick
    sm.uuid.new("0215fed5-239b-4f4d-b6a5-4982f5ae9b96"), -- glowstick_detach
    sm.uuid.new("d8cf518c-0c4b-4db8-972a-10f05d4eaaaf"), -- foam
    sm.uuid.new("0ab670bb-5969-4ab4-87a3-435795392d5a"), -- clay
}


--[[ SERVER ]]--

function Shell:server_onCreate()
    self:sv_init()
end

function Shell:server_onRefresh()
    self:sv_init()
end

function Shell:sv_init()
    self.sv = {
        burning = 0,
        maxburn = math.random(2, 4),
    }

    self.interactable.publicData = { isShell = true, claimed = false }
end

function Shell:server_onFixedUpdate(dt)
    if self.shape:getBurning() then
        self.sv.burning = self.sv.burning + dt

        if self.sv.burning >= self.sv.maxburn then
            self:sv_explode()
        end
    else
        self.sv.burning = 0
    end
end

function Shell:server_onProjectile(position, airTime, velocity, projectileName, shooter, damage, customData, normal, uuid, mass)
    if isAnyOf(uuid, safeProjectiles) then
        return
    end

    self:sv_explode()
end

function Shell:server_onExplosion()
    self:sv_explode()
end

function Shell:sv_explode()
    if self.data.noExplode then return end

    local pos = self.shape.worldPosition
    sm.physics.explode(pos, self.data.explosionLevel, self.data.explosionRadius, self.data.impulseRadius, self.data.impulseLevel, "PropaneTank - ExplosionSmall")
    shrapnelExplosion(pos, self.shape.at * 50, 5, 360, 100)
    sm.fire.igniteSphere(pos, self.data.explosionRadius, true)
    self.shape:destroyPart(0)
end

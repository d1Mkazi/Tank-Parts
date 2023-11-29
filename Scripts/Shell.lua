dofile("utils.lua")

---@class Shell : ShapeClass
Shell = class()

function Shell:server_onProjectile()
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
    self.shape:destroyPart(0)
end
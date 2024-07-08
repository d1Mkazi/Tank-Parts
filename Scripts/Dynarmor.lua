---@class DynamicArmor : ShapeClass
DynamicArmor = class()


--[[ SERVER ]]--

function DynamicArmor:server_onCreate()
    self.interactable.publicData = { isDA = true }
end

function DynamicArmor:server_onProjectile(position, airTime, velocity, projectileName, shooter, damage, customData, normal, uuid)
    if velocity:length() > 20 or damage > 80 then
        self:sv_explode()
    end
end

function DynamicArmor:sv_explode()
    self.network:sendToClients("cl_explode")
    sm.physics.explode(self.shape.worldPosition + self.shape.up * -0.25, 2, 0.5, 0.5, 10, nil, self.shape)
    self.shape:destroyPart(0)
end


--[[ CLIENT ]]--

function DynamicArmor:cl_explode()
    sm.effect.playEffect("DynamicArmor - Explosion", self.shape.worldPosition, sm.vec3.zero(), sm.vec3.getRotation(sm.vec3.new(0, 0, 1), self.shape.up))
end
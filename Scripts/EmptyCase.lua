dofile("utils.lua")

---@class EmptyCase : ShapeClass
EmptyCase = class()


--[[ SERVER ]]--

function EmptyCase:server_onCreate()
    self.interactable.publicData = { claimed = false }
end
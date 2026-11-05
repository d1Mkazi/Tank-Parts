local ammodb = {}
local holdables = {}


sm.TankParts = {
    version = 20260919,

    -- hook
    hooked = false,
    uuidNew = sm.uuid.new,

    -- fetch Breech and Shell data from JSON files
    fetch = function()
        local REQUIRED_SHELL_FIELDS = {
            type = "string",
            initialSpeed = "number", -- temporary
            mass = "number",
            caliber = "number",
            headCurve = "number",
            density = "number"
        }

        local shapedb = sm.json.open("$CONTENT_88ba8635-775e-4759-9a69-3df71f653f19/Objects/Database/shapesets.shapedb")
        local shapeSetList = shapedb.shapeSetList
        for i = 1, #shapeSetList - 2 do
            print("shapeSetList =", shapeSetList)
            print("i =", i)
            local shapeset = shapeSetList[i]
            print("shapeset =", shapeset)

            local ammoTypes = sm.json.open("$CONTENT_88ba8635-775e-4759-9a69-3df71f653f19/ammoTypes.json")

            if shapeset:sub(-9, -6) ~= "misc" then
                print("OPEN [", shapeset, "]")
                local breechset = sm.json.open(shapeset)

                local breeches = {}
                for _, part in pairs(breechset.partList) do
                    if part.type == "breech" then
                        breeches[#breeches + 1] = {
                            part.uuid,
                            part.insertArea
                        }
                        print("Added breech \""..part.name.."\"")
                    elseif part.type == "shell" then
                        local shellData = part.scripted.data.shellData
                        local caseData = part.scripted.data.caseData

                        if type(shellData) ~= "table" then
                            sm.log.error("Field \"shellData\" is missing or incorrect type in shell "..part.name)
                        else
                            local correct = true
                            for key, ftype in pairs(REQUIRED_SHELL_FIELDS) do
                                if type(shellData[key]) ~= ftype then
                                    sm.log.error("Necessary field \""..key.."\" is missing or incorrect type in shell "..part.name)
                                    correct = false
                                end
                            end

                            if correct then
                                shellData.onHit = ammoTypes.bullets[shellData.type].onHit
                                ammodb[tostring(part.uuid)] = {
                                    breechlist = breeches,
                                    shell = shellData,
                                    case = caseData
                                }
                                print("Added shell \""..part.name.."\"")
                            end
                        end

                        holdables[tostring(part.uuid)] = part.cylinder.depth
                    elseif part.type == "case" then
                        local caseData = part.scripted.data.caseData

                        local correct = true

                        if correct then
                            ammodb[tostring(part.uuid)] = {
                                breechlist = breeches,
                                case = caseData
                            }
                            print("Added shell \""..part.name.."\"")
                        end

                        holdables[tostring(part.uuid)] = part.cylinder.depth
                    elseif part.type == "empty" then
                        holdables[tostring(part.uuid)] = part.cylinder.depth
                    else
                        print("Ignoring unhandled type \""..part.type.."\" of \""..part.name.."\"")
                    end
                end
            end
        end
    end,

    ---@class ShellData
    ---@field type string
    ---@field mass number
    ---@field caliber number
    ---@field bullet Uuid
    ---@field cases table<Uuid>

    ---@class CaseData
    ---@field force number
    ---@field power string
    ---@field empty Uuid

    ---@class AmmoDBEntry
    ---@field breechlist table<Uuid>
    ---@field shell ShellData?
    ---@field case CaseData?

    -- Requires sm.TankParts.fetch() first
    -- Returns shell data from ammodb
    ---@param uuid Uuid uuid of ammo (bullet, case, rocket)
    ---@return AmmoDBEntry
    query = function(uuid)
        return ammodb[tostring(uuid)]
    end,

    ---@param uuid Uuid
    ---@return number # length
    rackInfo = function(uuid)
        return holdables[tostring(uuid)]
    end
}

sm.log.info("Tank Parts version:", sm.TankParts.version)

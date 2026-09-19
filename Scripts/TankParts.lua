local ammodb = {}


sm.TankParts = {
    version = 20260919,

    -- hook
    hooked = false,
    uuidNew = sm.uuid.new,

    -- fetch Breech and Shell data from JSON files
    fetch = function()
        local REQUIRED_SHELL_FIELDS = {
            type = "string",
            initialSpeed = "number",
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

            if shapeset:sub(-9, -6) ~= "misc" then
                print("OPEN [", shapeset, "]")
                local breechset = sm.json.open(shapeset)

                local breeches = {}
                for _, part in pairs(breechset.partList) do
                    if part.type == "breech" then
                        breeches[#breeches + 1] = part.uuid
                        print("Added breech \""..part.name.."\"")
                    elseif part.type == "shell" then
                        local shellData = part.scripted.data.shellData

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
                                ammodb[tostring(part.uuid)] = {
                                    breechlist = breeches,
                                    data = shellData
                                }
                                print("Added shell \""..part.name.."\"")
                            end
                        end
                    end
                end
            end
        end
    end,

    -- Requires sm.TankParts.fetch() first
    -- Returns shell data from ammodb
    ---@param uuid Uuid
    ---@return table breeches table of breeches
    query = function(uuid)
        return ammodb[tostring(uuid)]
    end
}

sm.log.info("Tank Parts version:", sm.TankParts.version)

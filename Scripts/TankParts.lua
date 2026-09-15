local ammodb = {}


sm.TankParts = {
    version = 20260910,

    -- hook
    hooked = false,
    uuidNew = sm.uuid.new,

    log = function(...)
        sm.log.info("[TANK PARTS]", ...)
    end,
    warning = function(...)
        sm.log.warning("[TANK PARTS]", ...)
    end,
    error = function(...)
        sm.log.error("[TANK PARTS]", ...)
    end,

    -- fetch Breech and Shell data from JSON files
    fetch = function()
        local shapedb = sm.json.open("$CONTENT_88ba8635-775e-4759-9a69-3df71f653f19/Objects/Database/shapesets.shapedb")
        for _, shapeset in pairs(shapedb.shapeSetList) do
            if shapeset:sub(-9, -6) ~= "misc" then
                print("OPEN [", shapeset, "]")
                local breechset = sm.json.open(shapeset)

                local breeches = {}
                for _, part in pairs(breechset.partList) do
                    if part.type == "breech" then
                        breeches[#breeches + 1] = part.uuid
                        print(("Added breech \"%s\""):format(part.name))
                    elseif part.type == "shell" then
                        print("Shell", part.name, "with breeches", breeches)
                        ammodb[tostring(part.uuid)] = {
                            breechlist = breeches,
                            data = part.scripted.data.shellData
                        }
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

sm.TankParts.log("version:", sm.TankParts.version)

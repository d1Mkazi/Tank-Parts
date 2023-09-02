local languages = {
    --[[
    template:
        key = {
            Language = "text"
            -- IMPORTANT: English localization is required.
            -- available languages: Brazilian | Chinese | English | French | German | Italian | Japanese | Korean | Polish | Russian | Spanish
            -- do NOT add language if it doesn't have a localization. If a language doesn't have a localization, English text will be used.
        }
    ]]
    -- Interaction texts
    TakeCase = {
        English = "Take case",
        Russian = "Взять гильзу"
    },
    Settings = {
        English = "Settings",
        Russian = "Настройки"
    },

    -- GUI
    GuiTitle = {
        English = "Barrel Length",
        Russian = "Длина ствола"
    }
}

---@param key string
---@param language string
function GetLocalization(key, language)
    if not languages[key] then return "NO KEY \""..key.."\" FOUND" end

    return languages[key][language] or languages[key].English
end
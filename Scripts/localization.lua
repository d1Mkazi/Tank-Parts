local languages = {
    --[[
    template:
        key = {
            Language = "text"
            -- IMPORTANT: English localization is required.
            -- available languages: Brazilian | Chinese | English | French | German | Italian | Japanese | Korean | Polish | Russian | Spanish
            -- English is default language. It means if there is no localization for your language, English localization is used.
        }
    ]]
    -- Interaction texts
    breech_TakeCase = {
        English = "Take case",
        Russian = "Взять гильзу"
    },
    breech_Settings = {
        English = "Settings",
        Russian = "Настройки"
    },
    fixer_Sit = {
        English = "Mount character",
        Russian = "Закрепиться"
    },
    fixer_StandUp = {
        English = "Dismount character",
        Russian = "Спешиться"
    },

    -- GUI
    breech_GuiTitle = {
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
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
    base_Settings = {
        English = "Settings",
        Russian = "Настройки"
    },
    base_Outdated = {
        English = "This part is outdated. DO NOT USE",
        Russian = "Этот элемент устарел. НЕ ИСПОЛЬЗУЙТЕ ЕГО"
    },

    breech_TakeCase = {
        English = "Take case",
        Russian = "Взять гильзу"
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
    },

    steer_GuiTitle = {
        English = "Max Speed",
        Russian = "Скорость"
    },
    steer_GuiMaxSpeed = {
        English = "Max",
        Russian = "Макс.",
    },
    steer_GuiMinSpeed = {
        English = "Min",
        Russian = "Мин.",
    },
    steer_GuiMode = {
        English = "Mode:",
        Russian = "Режим:"
    },

    -- Alerts
    steer_MsgExit = {
        English = "You are no longer aiming",
        Russian = "Вы вышли из режима наведения"
    },
    steer_MsgEnter = {
        English = "You are aiming now",
        Russian = "Вы вошли в режим наведения"
    },
    steer_MsgRotSpeed = {
        English = "Rotation speed is",
        Russian = "Скорость вращения:"
    },

    mghandle_AimSpeed = {
        English = "Aiming speed is",
        Russian = "Скорость наведения:"
    }
}

---@param key string
---@param language string
function GetLocalization(key, language)
    if not languages[key] then return "NO KEY \""..key.."\" FOUND" end

    return languages[key][language] or languages[key].English
end
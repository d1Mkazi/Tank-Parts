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
    breech_GuiLength = {
        English = "Barrel Length",
        Russian = "Длина ствола"
    },
    breech_GuiDisplay = {
        English = "%s blk",
        Russian = "%s блк"
    },
    breech_GuiOffset = {
        English = "Offset",
        Russian = "Выстрел"
    },
    breech_GuiUpper = {
        English = "UPPER",
        Russian = "ВЫШЕ"
    },
    breech_GuiLower = {
        English = "LOWER",
        Russian = "НИЖЕ"
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

    td_GuiControls = {
        English = "Controls",
        Russian = "Наведение"
    },
    td_GuiBinds = {
        English = "Vertical: %s\nHorizontal: %s",
        Russian = "Верт.: %s\nГориз.: %s"
    },
    td_GuiSwapControls = {
        English = "SWAP",
    },
    td_GuiSwapVertical = {
        English = "SWAP VERT",
    },
    td_GuiSpeed = {
        English = "Speed",
        Russian = "Скорость"
    },
    td_GuiDisplay = {
        English = "Max Speed: %s",
        Russian = "Макс.\nскорость: %s"
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
        English = "Rotation speed is %s",
        Russian = "Скорость вращения: %s"
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

getLang = sm.gui.getCurrentLanguage
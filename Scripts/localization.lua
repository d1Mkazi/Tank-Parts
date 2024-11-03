---@diagnostic disable: lowercase-global
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
    rack_take = {
        English = "Take %s",
        Russian = "Взять %s"
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

    ts_GuiSpeed = {
        English = "Max Speed",
        Russian = "Скорость"
    },
    ts_GuiMaxSpeed = {
        English = "Max",
        Russian = "Макс.",
    },
    ts_GuiMinSpeed = {
        English = "Min",
        Russian = "Мин.",
    },
    ts_GuiMode = {
        English = "Mode",
        Russian = "Режим"
    },

    td_GuiControls = {
        English = "Controls",
        Russian = "Управление"
    },
    td_GuiVertical = {
        English = "Vertical: %s",
        Russian = "Вертикаль: %s"
    },
    td_GuiHorizontal = {
        English = "Horizontal: %s",
        Russian = "Горизонт: %s"
    },
    td_GuiSwapControls = {
        English = "SWAP",
    },
    td_GuiSpeed = {
        English = "Speed",
        Russian = "Скорость"
    },
    td_GuiDisplay = {
        English = "Max Speed: %s",
        Russian = "Макс.\nскорость: %s"
    },
    td_GuiSecondary = {
        English = "Secondary",
        Russian = "Втор. действие"
    },
    td_GuiButton = {
        English = "Button",
        Russian = "Кнопка"
    },
    td_GuiButtonMode = {
        English = "BUTTON",
        Russian = "КНОПКА"
    },
    td_GuiToggleMode = {
        English = "TOGGLE",
        Russian = "ПЕРЕКЛ"
    },

    ext_GuiValues = {
        English = "Output",
        Russian = "Вывод"
    },
    ext_GuiOutput = {
        English = "Select output value",
        Russian = "Выберите значения для вывода"
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
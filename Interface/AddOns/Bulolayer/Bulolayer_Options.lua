-- Bulolayer_Options.lua
-- Enhanced options panel for Bulolayer addon

-- Store category reference for opening options
local Bulolayer_SettingsCategory = nil
local optionsPanel = nil

-- Create the options panel
function Bulolayer_CreateOptions()
    if optionsPanel then return end -- Already created

    optionsPanel = CreateFrame("Frame", "Bulolayer_Options")
    optionsPanel.name = "Bulolayer"

    -- Register with Settings API (TBC Anniversary 2.5.5+)
    if Settings and Settings.RegisterCanvasLayoutCategory then
        Bulolayer_SettingsCategory = Settings.RegisterCanvasLayoutCategory(optionsPanel, optionsPanel.name)
        Settings.RegisterAddOnCategory(Bulolayer_SettingsCategory)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(optionsPanel)
    end

    -- Scroll frame for content
    local scrollFrame = CreateFrame("ScrollFrame", nil, optionsPanel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(550, 900)
    scrollFrame:SetScrollChild(content)

    local yOffset = 0

    -- ============================================
    -- HEADER
    -- ============================================
    yOffset = CreateHeader(content, yOffset, "|cffff306fBulolayer|r v" .. (Bulolayer.VERSION or "2.0"))
    yOffset = yOffset + 10

    -- ============================================
    -- GENERAL SETTINGS
    -- ============================================
    yOffset = CreateSectionHeader(content, yOffset, "General Settings")

    -- Enable addon checkbox
    yOffset = CreateCheckbox(content, yOffset, "enabled", "Enable Addon",
        "Master toggle to enable/disable the addon")

    -- Verbose mode checkbox
    yOffset = CreateCheckbox(content, yOffset, "verbose", "Verbose Notifications",
        "Show all notifications (invites sent, accepted, etc.)")

    yOffset = yOffset + 10

    -- ============================================
    -- INVITE SETTINGS
    -- ============================================
    yOffset = CreateSectionHeader(content, yOffset, "Invite Settings")

    -- Invite message
    yOffset = CreateEditBox(content, yOffset, "message", "Invite Message",
        "Message that triggers layer swap", false)

    -- Channel name
    yOffset = CreateEditBox(content, yOffset, "channel", "Channel Name",
        "Custom channel for layer swap (e.g., 'layer')", false)

    -- Cooldown
    yOffset = CreateEditBox(content, yOffset, "delay", "Cooldown (seconds)",
        "Time before same player can be invited again", true)

    -- Invite threshold dropdown
    yOffset = CreateDropdown(content, yOffset, "inviteThreshold", "Party Threshold",
        "Only invite if party has fewer members", {0, 1, 2, 3, 4, 5})

    yOffset = yOffset + 10

    -- ============================================
    -- INVITE SOURCES
    -- ============================================
    yOffset = CreateSectionHeader(content, yOffset, "Invite Sources")

    yOffset = CreateCheckbox(content, yOffset, "guild", "Guild Chat",
        "Listen for layer requests in guild chat")

    yOffset = CreateCheckbox(content, yOffset, "whisper", "Whispers",
        "Listen for layer requests via whisper")

    yOffset = CreateCheckbox(content, yOffset, "inviteInRaid", "Allow in Raid",
        "Allow invites while in a raid group")

    yOffset = yOffset + 10

    -- ============================================
    -- RESTRICTIONS
    -- ============================================
    yOffset = CreateSectionHeader(content, yOffset, "Restrictions")

    yOffset = CreateCheckbox(content, yOffset, "guildOnly", "Guild Only",
        "Only accept invites from guild members")

    yOffset = CreateCheckbox(content, yOffset, "friendsOnly", "Friends/Guild Only",
        "Only accept invites from friends or guild")

    yOffset = yOffset + 10

    -- ============================================
    -- AUTO-LEAVE SETTINGS
    -- ============================================
    yOffset = CreateSectionHeader(content, yOffset, "Auto-Leave")

    yOffset = CreateCheckbox(content, yOffset, "autoLeave", "Enable Auto-Leave",
        "Automatically leave party after layer swap")

    yOffset = CreateSlider(content, yOffset, "autoLeaveDelay", "Leave Delay",
        "Seconds to wait before auto-leaving", 1, 10, 1)

    yOffset = yOffset + 10

    -- ============================================
    -- RATE LIMITING
    -- ============================================
    yOffset = CreateSectionHeader(content, yOffset, "Rate Limiting")

    yOffset = CreateSlider(content, yOffset, "rateLimitInvites", "Max Invites/Min",
        "Maximum invites per minute", 1, 20, 1)

    yOffset = CreateSlider(content, yOffset, "rateLimitBroadcast", "Broadcast Cooldown",
        "Seconds between broadcasts", 5, 60, 5)

    yOffset = yOffset + 10

    -- ============================================
    -- MINIMAP
    -- ============================================
    yOffset = CreateSectionHeader(content, yOffset, "Minimap Button")

    local hideMinimap = CreateFrame("CheckButton", "BulolayerHideMinimapCheck", content, "ChatConfigCheckButtonTemplate")
    hideMinimap:SetPoint("TOPLEFT", 10, -yOffset)
    _G[hideMinimap:GetName() .. "Text"]:SetText("Hide Minimap Button")
    hideMinimap:SetChecked(BulolayerDB.minimap and BulolayerDB.minimap.hide)
    hideMinimap:SetScript("OnClick", function(self)
        BulolayerDB.minimap = BulolayerDB.minimap or {}
        BulolayerDB.minimap.hide = self:GetChecked()
        if Bulolayer_MinimapButton_UpdateVisibility then
            Bulolayer_MinimapButton_UpdateVisibility()
        end
    end)
    yOffset = yOffset + 30

    yOffset = yOffset + 10

    -- ============================================
    -- STATISTICS
    -- ============================================
    yOffset = CreateSectionHeader(content, yOffset, "Statistics")

    local statsText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statsText:SetPoint("TOPLEFT", 10, -yOffset)
    statsText:SetJustifyH("LEFT")
    statsText:SetWidth(500)

    local function UpdateStats()
        local stats = Bulolayer:GetStats()
        local cooldowns = Bulolayer:GetBlacklistCount()
        local favCount = BulolayerDB.favorites and #BulolayerDB.favorites or 0

        local text = string.format(
            "Total Swaps: |cffffffff%d|r\n" ..
            "Today's Swaps: |cffffffff%d|r\n" ..
            "Active Cooldowns: |cffffffff%d|r\n" ..
            "Favorites: |cffffffff%d|r",
            stats.totalSwaps or 0,
            stats.todaySwaps or 0,
            cooldowns,
            favCount
        )
        statsText:SetText(text)
    end
    UpdateStats()
    yOffset = yOffset + 70

    -- Refresh stats button
    local refreshBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    refreshBtn:SetPoint("TOPLEFT", 10, -yOffset)
    refreshBtn:SetSize(100, 22)
    refreshBtn:SetText("Refresh")
    refreshBtn:SetScript("OnClick", function()
        UpdateStats()
    end)
    yOffset = yOffset + 30

    yOffset = yOffset + 10

    -- ============================================
    -- ACTIONS
    -- ============================================
    yOffset = CreateSectionHeader(content, yOffset, "Actions")

    -- Clear cooldowns button
    local clearBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    clearBtn:SetPoint("TOPLEFT", 10, -yOffset)
    clearBtn:SetSize(140, 22)
    clearBtn:SetText("Clear Cooldowns")
    clearBtn:SetScript("OnClick", function()
        Bulolayer:ClearBlacklist()
        UpdateStats()
    end)

    -- Reset to defaults button
    local resetBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    resetBtn:SetPoint("TOPLEFT", 160, -yOffset)
    resetBtn:SetSize(140, 22)
    resetBtn:SetText("Reset Defaults")
    resetBtn:SetScript("OnClick", function()
        StaticPopup_Show("BULOLAYER_RESET_CONFIRM")
    end)
    yOffset = yOffset + 35

    -- Clear stats button
    local clearStatsBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    clearStatsBtn:SetPoint("TOPLEFT", 10, -yOffset)
    clearStatsBtn:SetSize(140, 22)
    clearStatsBtn:SetText("Clear Statistics")
    clearStatsBtn:SetScript("OnClick", function()
        BulolayerDB.stats = Bulolayer.DEFAULTS.stats
        UpdateStats()
        Bulolayer:Print("Statistics cleared.", "SUCCESS")
    end)

    -- Clear favorites button
    local clearFavBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    clearFavBtn:SetPoint("TOPLEFT", 160, -yOffset)
    clearFavBtn:SetSize(140, 22)
    clearFavBtn:SetText("Clear Favorites")
    clearFavBtn:SetScript("OnClick", function()
        BulolayerDB.favorites = {}
        UpdateStats()
        Bulolayer:Print("Favorites cleared.", "SUCCESS")
    end)
    yOffset = yOffset + 40

    -- ============================================
    -- HELP TEXT
    -- ============================================
    yOffset = CreateSectionHeader(content, yOffset, "Commands")

    local helpText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    helpText:SetPoint("TOPLEFT", 10, -yOffset)
    helpText:SetJustifyH("LEFT")
    helpText:SetWidth(500)
    helpText:SetText(
        "|cffffd700/l|r or |cffffd700/layer|r - Find layer swap group\n" ..
        "|cffffd700/layerconfig|r - Open this panel\n" ..
        "|cffffd700/layerclear|r - Clear all cooldowns\n" ..
        "|cffffd700/layerstats|r - Show statistics\n" ..
        "|cffffd700/layerfav [name]|r - Toggle player as favorite\n" ..
        "|cffffd700/layerhelp|r - Show all commands"
    )

    -- Confirmation dialog for reset
    StaticPopupDialogs["BULOLAYER_RESET_CONFIRM"] = {
        text = "Reset all Bulolayer settings to defaults?",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            BulolayerDB.settings = nil
            Bulolayer:InitDB()
            ReloadUI()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
end

-- ============================================
-- UI HELPER FUNCTIONS
-- ============================================

function CreateHeader(parent, yOffset, text)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 10, -yOffset)
    header:SetText(text)
    return yOffset + 25
end

function CreateSectionHeader(parent, yOffset, text)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 10, -yOffset)
    header:SetTextColor(1, 0.82, 0)
    header:SetText("--- " .. text .. " ---")
    return yOffset + 20
end

function CreateCheckbox(parent, yOffset, settingKey, label, tooltip)
    local check = CreateFrame("CheckButton", "Bulolayer_" .. settingKey .. "_Check", parent, "ChatConfigCheckButtonTemplate")
    check:SetPoint("TOPLEFT", 10, -yOffset)
    _G[check:GetName() .. "Text"]:SetText(label)

    check:SetChecked(Bulolayer:GetSetting(settingKey))
    check:SetScript("OnClick", function(self)
        Bulolayer:SetSetting(settingKey, self:GetChecked())
    end)

    if tooltip then
        check:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltip, nil, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        check:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    return yOffset + 25
end

function CreateEditBox(parent, yOffset, settingKey, label, tooltip, numeric)
    local labelText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    labelText:SetPoint("TOPLEFT", 10, -yOffset)
    labelText:SetText(label .. ":")

    local editBox = CreateFrame("EditBox", "Bulolayer_" .. settingKey .. "_Edit", parent, "InputBoxTemplate")
    editBox:SetPoint("TOPLEFT", 160, -yOffset + 3)
    editBox:SetSize(150, 20)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(numeric and 6 or 30)

    if numeric then
        editBox:SetNumeric(true)
    end

    local value = Bulolayer:GetSetting(settingKey)
    editBox:SetText(value ~= nil and tostring(value) or "")
    editBox:SetCursorPosition(0)

    editBox:SetScript("OnTextChanged", function(self, userInput)
        if not userInput then return end
        local text = self:GetText()
        if numeric then
            Bulolayer:SetSetting(settingKey, tonumber(text) or 0)
        else
            Bulolayer:SetSetting(settingKey, text)
        end
    end)

    editBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)

    if tooltip then
        editBox:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltip, nil, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        editBox:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    return yOffset + 30
end

function CreateSlider(parent, yOffset, settingKey, label, tooltip, minVal, maxVal, step)
    local labelText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    labelText:SetPoint("TOPLEFT", 10, -yOffset)
    labelText:SetText(label .. ":")

    local slider = CreateFrame("Slider", "Bulolayer_" .. settingKey .. "_Slider", parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 160, -yOffset)
    slider:SetSize(150, 17)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)

    local currentVal = Bulolayer:GetSetting(settingKey) or minVal
    slider:SetValue(currentVal)

    _G[slider:GetName() .. "Low"]:SetText(tostring(minVal))
    _G[slider:GetName() .. "High"]:SetText(tostring(maxVal))
    _G[slider:GetName() .. "Text"]:SetText(tostring(currentVal))

    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        Bulolayer:SetSetting(settingKey, value)
        _G[self:GetName() .. "Text"]:SetText(tostring(value))
    end)

    if tooltip then
        slider:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltip, nil, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        slider:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    return yOffset + 35
end

function CreateDropdown(parent, yOffset, settingKey, label, tooltip, values)
    local labelText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    labelText:SetPoint("TOPLEFT", 10, -yOffset)
    labelText:SetText(label .. ":")

    local dropdown = CreateFrame("Frame", "Bulolayer_" .. settingKey .. "_Dropdown", parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", 140, -yOffset + 5)
    UIDropDownMenu_SetWidth(dropdown, 80)

    local currentVal = Bulolayer:GetSetting(settingKey)
    UIDropDownMenu_SetText(dropdown, tostring(currentVal))

    UIDropDownMenu_Initialize(dropdown, function(self, level, menuList)
        for _, val in ipairs(values) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = tostring(val)
            info.value = val
            info.checked = (val == Bulolayer:GetSetting(settingKey))
            info.func = function(self)
                Bulolayer:SetSetting(settingKey, self.value)
                UIDropDownMenu_SetText(dropdown, tostring(self.value))
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    return yOffset + 35
end

-- Function to open options panel
function Bulolayer_OpenOptions()
    if Settings and Settings.OpenToCategory and Bulolayer_SettingsCategory then
        Settings.OpenToCategory(Bulolayer_SettingsCategory:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(Bulolayer_Options)
        InterfaceOptionsFrame_OpenToCategory(Bulolayer_Options)
    end
end

-- Slash command to open options
SLASH_BULOLAYERCONFIG1 = "/layerconfig"
SLASH_BULOLAYERCONFIG2 = "/lconfig"
SlashCmdList["BULOLAYERCONFIG"] = Bulolayer_OpenOptions

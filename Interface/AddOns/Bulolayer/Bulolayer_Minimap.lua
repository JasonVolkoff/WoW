-- Bulolayer_Minimap.lua
-- Minimap button for Bulolayer addon (no external libraries)

local BUTTON_RADIUS = 80
local BUTTON_SIZE = 32

-- Create minimap button frame
local MinimapButton = CreateFrame("Button", "BulolayerMinimapButton", Minimap)
MinimapButton:SetSize(BUTTON_SIZE, BUTTON_SIZE)
MinimapButton:SetFrameStrata("MEDIUM")
MinimapButton:SetFrameLevel(8)
MinimapButton:SetClampedToScreen(true)
MinimapButton:SetMovable(true)
MinimapButton:RegisterForDrag("LeftButton")
MinimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
MinimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

-- Button textures
local overlay = MinimapButton:CreateTexture(nil, "OVERLAY")
overlay:SetSize(53, 53)
overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
overlay:SetPoint("TOPLEFT", 0, 0)

local icon = MinimapButton:CreateTexture(nil, "BACKGROUND")
icon:SetSize(20, 20)
icon:SetPoint("CENTER", 0, 0)
-- Use a simple icon texture (group icon)
icon:SetTexture("Interface\\Icons\\Spell_Nature_Invisibilty")
MinimapButton.icon = icon

-- Status indicator (small colored dot)
local statusDot = MinimapButton:CreateTexture(nil, "OVERLAY")
statusDot:SetSize(8, 8)
statusDot:SetPoint("BOTTOMRIGHT", -4, 4)
statusDot:SetColorTexture(0, 1, 0, 1) -- Green by default
MinimapButton.statusDot = statusDot

-- Update button position based on angle
local function UpdatePosition()
    if not BulolayerDB or not BulolayerDB.minimap then return end
    local angle = math.rad(BulolayerDB.minimap.position or 225)
    local x = math.cos(angle) * BUTTON_RADIUS
    local y = math.sin(angle) * BUTTON_RADIUS
    MinimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- Calculate angle from cursor position
local function GetAngleFromCursor()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    cx, cy = cx / scale, cy / scale
    return math.deg(math.atan2(cy - my, cx - mx))
end

-- Dragging handlers
MinimapButton:SetScript("OnDragStart", function(self)
    self.isDragging = true
    self:SetScript("OnUpdate", function(self)
        if not BulolayerDB then return end
        BulolayerDB.minimap = BulolayerDB.minimap or {}
        BulolayerDB.minimap.position = GetAngleFromCursor()
        UpdatePosition()
    end)
end)

MinimapButton:SetScript("OnDragStop", function(self)
    self.isDragging = false
    self:SetScript("OnUpdate", nil)
end)

-- Click handlers
MinimapButton:SetScript("OnClick", function(self, button)
    if button == "LeftButton" then
        -- Open options panel
        if Bulolayer_OpenOptions then
            Bulolayer_OpenOptions()
        end
    elseif button == "RightButton" then
        -- Toggle enabled state
        if Bulolayer and Bulolayer.SetSetting and Bulolayer.GetSetting then
            local enabled = not Bulolayer:GetSetting("enabled")
            Bulolayer:SetSetting("enabled", enabled)
            Bulolayer:Print("Addon " .. (enabled and "enabled" or "disabled"), enabled and "SUCCESS" or "WARNING")
            MinimapButton:UpdateStatus()
        end
    end
end)

-- Tooltip
MinimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("|cffff306fBulolayer|r v" .. (Bulolayer.VERSION or "2.0"))
    GameTooltip:AddLine(" ")

    -- Status
    local enabled = Bulolayer and Bulolayer:GetSetting("enabled")
    if enabled then
        GameTooltip:AddLine("Status: |cff00ff00Enabled|r")
    else
        GameTooltip:AddLine("Status: |cffff0000Disabled|r")
    end

    -- Stats
    if Bulolayer and Bulolayer.GetStats then
        local stats = Bulolayer:GetStats()
        GameTooltip:AddLine("Today's swaps: " .. (stats.todaySwaps or 0))
        GameTooltip:AddLine("Total swaps: " .. (stats.totalSwaps or 0))
    end

    -- Cooldowns
    if Bulolayer and Bulolayer.GetBlacklistCount then
        local count = Bulolayer:GetBlacklistCount()
        GameTooltip:AddLine("Active cooldowns: " .. count)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cffffffffLeft-click:|r Open options")
    GameTooltip:AddLine("|cffffffffRight-click:|r Toggle enable")
    GameTooltip:AddLine("|cffffffffDrag:|r Move button")

    GameTooltip:Show()
end)

MinimapButton:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)

-- Update status indicator
function MinimapButton:UpdateStatus()
    if not Bulolayer or not Bulolayer.GetSetting then
        self.statusDot:SetColorTexture(0.5, 0.5, 0.5, 1) -- Gray
        return
    end

    local enabled = Bulolayer:GetSetting("enabled")
    if not enabled then
        self.statusDot:SetColorTexture(1, 0, 0, 1) -- Red - disabled
    elseif Bulolayer.pendingAutoLeave then
        self.statusDot:SetColorTexture(1, 1, 0, 1) -- Yellow - pending action
    else
        local cooldowns = Bulolayer:GetBlacklistCount()
        if cooldowns > 0 then
            self.statusDot:SetColorTexture(1, 0.5, 0, 1) -- Orange - has cooldowns
        else
            self.statusDot:SetColorTexture(0, 1, 0, 1) -- Green - ready
        end
    end
end

-- Show/hide button
function MinimapButton:UpdateVisibility()
    if BulolayerDB and BulolayerDB.minimap and BulolayerDB.minimap.hide then
        self:Hide()
    else
        self:Show()
        UpdatePosition()
    end
end

-- Initialize on load
function MinimapButton:Initialize()
    self:UpdateVisibility()
    self:UpdateStatus()
end

-- Public functions for other files
function Bulolayer_MinimapButton_UpdateStatus()
    MinimapButton:UpdateStatus()
end

function Bulolayer_MinimapButton_UpdateVisibility()
    MinimapButton:UpdateVisibility()
end

function Bulolayer_MinimapButton_Initialize()
    MinimapButton:Initialize()
end

-- Update position after DB is loaded
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
    C_Timer.After(1, function()
        MinimapButton:Initialize()
    end)
end)

local _G = getfenv(0)

local function SyncStyle(footer, parent)
    if not footer or not parent then return end
    
    -- Copy Backdrop
    if parent.GetBackdrop then
        footer:SetBackdrop(parent:GetBackdrop())
    end
    
    -- Copy Color
    if parent.GetBackdropColor then
        local r, g, b, a = parent:GetBackdropColor()
        footer:SetBackdropColor(r, g, b, a)
    end
    
    -- Copy Border
    if parent.GetBackdropBorderColor then
        local r, g, b, a = parent:GetBackdropBorderColor()
        footer:SetBackdropBorderColor(r, g, b, a)
    end
end

-- checkbox frame
local function CreateBiSToggleFrame()
    local parentFrame = _G["AtlasLoot_GUI-Frame"]
    if not parentFrame then return end
    
    -- Prevent duplicate
    if _G["AtlasLoot_BiS_Footer"] then return end

    -- Create Footer
    local footer = CreateFrame("Frame", "AtlasLoot_BiS_Footer", parentFrame, _G.BackdropTemplateMixin and "BackdropTemplate" or nil)
    footer:SetPoint("TOPLEFT", parentFrame, "BOTTOMLEFT", 0, 0)
    footer:SetPoint("TOPRIGHT", parentFrame, "BOTTOMRIGHT", 0, 0)
    footer:SetHeight(24)
    
    -- Apply Style
    SyncStyle(footer, parentFrame)

    -- Create a container
    local centerGroup = CreateFrame("Frame", nil, footer)
    centerGroup:SetHeight(44)
    centerGroup:SetPoint("CENTER", 0, 5)

    -- Create Checkbox
    local check = CreateFrame("CheckButton", nil, centerGroup, "UICheckButtonTemplate")
    check:SetSize(20, 20)
    check:SetScale(1.5)
    check:SetPoint("BOTTOMLEFT", centerGroup, "BOTTOMLEFT", 0, 0)
    if _G.ExoLinkDB then
        check:SetChecked(_G.ExoLinkDB.showBiS == 1)
    end
    check:SetScript("OnClick", function(self)
        _G.ExoLinkDB.showBiS = self:GetChecked() and 1 or 0
    end)

    -- Text
    local text = centerGroup:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("LEFT", check, "RIGHT", 2, 1)
    text:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE") 
    text:SetText("Show TBC Phase 1 BiS in Tooltips")
    text:SetTextColor(1, 0.82, 0) 

    -- Create Checkbox
    local classCheck = CreateFrame("CheckButton", nil, centerGroup, "UICheckButtonTemplate")
    classCheck:SetSize(20, 20)
    classCheck:SetScale(1.5)
    classCheck:SetPoint("LEFT", text, "RIGHT", 15, -1) -- 15px gap
    if _G.ExoLinkDB then
        classCheck:SetChecked(_G.ExoLinkDB.showOnlyMyClass == 1)
    end
    classCheck:SetScript("OnClick", function(self)
        _G.ExoLinkDB.showOnlyMyClass = self:GetChecked() and 1 or 0
    end)

    -- my Class
    local classText = centerGroup:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    classText:SetPoint("LEFT", classCheck, "RIGHT", 2, 1)
    classText:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    classText:SetText("My Class only")
    classText:SetTextColor(1, 0.82, 0)

    -- Instructions
    local newText = centerGroup:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    newText:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    newText:SetPoint("BOTTOM", centerGroup, "TOP", 10, -15) -- Offset slightly to balance icon
    newText:SetText("To view TBC Items, click on the WoW classic Icon in the top center and select the TBC Icon!")
    newText:SetTextColor(1, 0.82, 0)

    -- Icon
    local icon = centerGroup:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetTexture("Interface/AddOns/AtlasLootClassic/notification.tga")
    icon:SetPoint("RIGHT", newText, "LEFT", -4, 0)

    -- Recalculate Width
    local width1 = (20 * 1.5) + 2 + text:GetStringWidth()
    local width2 = 15 + (20 * 1.5) + 2 + classText:GetStringWidth()
    centerGroup:SetWidth(width1 + width2)
end

-- Hook
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    if _G.AtlasLoot and _G.AtlasLoot.GUI then
        hooksecurefunc(_G.AtlasLoot.GUI, "Create", CreateBiSToggleFrame)
        hooksecurefunc(_G.AtlasLoot.GUI, "RefreshMainFrame", function()
            local footer = _G["AtlasLoot_BiS_Footer"]
            local parent = _G["AtlasLoot_GUI-Frame"]
            if footer and parent then
                SyncStyle(footer, parent)
            end
        end)
        if _G["AtlasLoot_GUI-Frame"] then
            CreateBiSToggleFrame()
        end
    end
end)
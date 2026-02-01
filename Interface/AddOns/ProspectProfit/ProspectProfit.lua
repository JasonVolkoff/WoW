-- ProspectProfit.lua
-- Shows expected prospecting profit for configured ores using Auctionator cached prices.
-- Adds a one-click "Prospect" button that appears ONLY on Auctionator's Shopping tab by
-- parenting it to AuctionatorShoppingFrame (Legacy/Classic AH).
--
-- IMPORTANT: This version includes AH deposit cost in the profitability calculation.
-- Assumption (conservative): you LOSE the 12-hour deposit once per gem sold
-- (i.e., 1 failed/expired listing per gem).
--
-- IMPORTANT (search behavior): Uses Auctionator.API.v1.MultiSearchExact to avoid unrelated
-- items with the same words in the name (e.g., "Aquamarine Pendant of the Tiger").
-- Auctionator rejects search terms containing ; or ^ or wrapped in ".

local ADDON_NAME = ...
local CALLER_ID = ADDON_NAME

ProspectProfitDB = ProspectProfitDB or {}

-- ----------------------------
-- Config
-- ----------------------------
local AH_CUT = 0.05
local DEPOSIT_MULTIPLIER_12H = 0.15

-- ----------------------------
-- Auctionator price provider
-- ----------------------------
local function GetAuctionatorPriceByItemID(itemID)
  if not (Auctionator and Auctionator.API and Auctionator.API.v1) then
    return nil
  end
  return Auctionator.API.v1.GetAuctionPriceByItemID(CALLER_ID, itemID) -- copper or nil
end

-- ----------------------------
-- Helpers
-- ----------------------------
local function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffProspectProfit:|r " .. tostring(msg))
end

local function MoneyString(copper)
  if copper == nil then return "?" end
  copper = math.floor(tonumber(copper) + 0.5)

  local g = math.floor(copper / 10000)
  local s = math.floor((copper % 10000) / 100)
  local c = copper % 100

  if g > 0 then
    return ("%dg %ds %dc"):format(g, s, c)
  elseif s > 0 then
    return ("%ds %dc"):format(s, c)
  else
    return ("%dc"):format(c)
  end
end

-- Return vendor sell price (in copper) from GetItemInfo if cached.
-- In Classic/TBC: GetItemInfo(...) returns vendorPrice as the 11th value.
local function GetVendorPriceCopper(itemID)
  local vendorPrice = select(11, GetItemInfo(itemID))
  if vendorPrice == nil then
    return nil
  end
  return tonumber(vendorPrice)
end

-- Auctionator API rejects terms containing ; or ^ or wrapped in ".
-- Item names generally won't include these, but sanitize defensively anyway.
local function SanitizeSearchTerm(name)
  name = tostring(name or "")
  name = name:gsub('"', ""):gsub(";", ""):gsub("%^", "")
  -- trim
  name = name:gsub("^%s+", ""):gsub("%s+$", "")
  return name
end

-- ----------------------------
-- Prospecting tables (EDIT ME)
-- ----------------------------
local ORES = {
  -- Copper Ore (2770)
  [2770] = {
    label = "Copper Ore",
    size = 5,
    gems = {
      [774]  = 0.50, -- Malachite
      [818]  = 0.50, -- Tigerseye
      [1210] = 0.10, -- Shadowgem (rare roll)
    },
  },

  -- Tin Ore (2771)
  [2771] = {
    label = "Tin Ore",
    size = 5,
    gems = {
      [1705] = 0.38,   -- Lesser Moonstone
      [1206] = 0.38,   -- Moss Agate
      [1210] = 0.38,   -- Shadowgem
      [7909] = 0.0333, -- Aquamarine (rare roll)
      [3864] = 0.0333, -- Citrine (rare roll)
      [1529] = 0.0333, -- Jade (rare roll)
    },
  },

  -- Iron Ore (2772)
  [2772] = {
    label = "Iron Ore",
    size = 5,
    gems = {
      [1705] = 0.35, -- Lesser Moonstone
      [3864] = 0.35, -- Citrine
      [1529] = 0.35, -- Jade
      [7910] = 0.05, -- Star Ruby (rare roll)
      [7909] = 0.05, -- Aquamarine (rare roll)
    },
  },

  -- Mithril Ore (3858)
  [3858] = {
    label = "Mithril Ore",
    size = 5,
    gems = {
      [7910]  = 0.35,  -- Star Ruby
      [7909]  = 0.35,  -- Aquamarine
      [3864]  = 0.35,  -- Citrine
      [12361] = 0.025, -- Blue Sapphire (rare roll)
      [12799] = 0.025, -- Large Opal (rare roll)
      [12800] = 0.025, -- Azerothian Diamond (rare roll)
      [12364] = 0.025, -- Huge Emerald (rare roll)
    },
  },

  -- Thorium Ore (10620)
  [10620] = {
    label = "Thorium Ore",
    size = 5,
    gems = {
      [7910]  = 0.30, -- Star Ruby
      [12364] = 0.16, -- Huge Emerald
      [12800] = 0.16, -- Azerothian Diamond
      [12361] = 0.16, -- Blue Sapphire
      [12799] = 0.16, -- Large Opal
      -- Pre-patch: keep TBC gems commented out
      -- [23077] = 0.0166, -- Blood Garnet
      -- [23079] = 0.0166, -- Deep Peridot
      -- [21929] = 0.0166, -- Flame Spessarite
      -- [23112] = 0.0166, -- Golden Draenite
      -- [23107] = 0.0166, -- Shadow Draenite
      -- [23117] = 0.0166, -- Azure Moonstone
    },
  },

  -- Fel Iron Ore (23424)
  [23424] = {
    label = "Fel Iron Ore",
    size = 5,
    gems = {
      [23077] = 0.18,  -- Blood Garnet
      [23079] = 0.18,  -- Deep Peridot
      [21929] = 0.18,  -- Flame Spessarite
      [23112] = 0.18,  -- Golden Draenite
      [23107] = 0.18,  -- Shadow Draenite
      [23117] = 0.18,  -- Azure Moonstone
      [23439] = 0.013, -- Noble Topaz (rare roll)
      [23440] = 0.013, -- Dawnstone (rare roll)
      [23436] = 0.013, -- Living Ruby (rare roll)
      [23441] = 0.013, -- Nightseye (rare roll)
      [23438] = 0.013, -- Star of Elune (rare roll)
      [23437] = 0.013, -- Talasite (rare roll)
    },
  },

  -- Adamantite Ore (23425)
  [23425] = {
    label = "Adamantite Ore",
    size = 5,
    gems = {
      [23077] = 0.18, -- Blood Garnet
      [23079] = 0.18, -- Deep Peridot
      [21929] = 0.18, -- Flame Spessarite
      [23112] = 0.18, -- Golden Draenite
      [23107] = 0.18, -- Shadow Draenite
      [23117] = 0.18, -- Azure Moonstone
      [23439] = 0.04, -- Noble Topaz (rare roll)
      [23440] = 0.04, -- Dawnstone (rare roll)
      [23436] = 0.04, -- Living Ruby (rare roll)
      [23441] = 0.04, -- Nightseye (rare roll)
      [23438] = 0.04, -- Star of Elune (rare roll)
      [23437] = 0.04, -- Talasite (rare roll)
    },
  },
}

-- ----------------------------
-- EV / Profit calc (includes AH cut + deposit losses)
-- ----------------------------
-- local function ComputeProspectProfit(oreItemID)
--   local ore = ORES[oreItemID]
--   if not ore then return nil, "Ore not configured" end

--   local orePrice = GetAuctionatorPriceByItemID(oreItemID)
--   if not orePrice then
--     return nil, "No Auctionator price for ore (run refresh)"
--   end

--   local ev = 0
--   local expectedDepositLoss = 0

--   for gemID, expected in pairs(ore.gems) do
--     local gemPrice = GetAuctionatorPriceByItemID(gemID)
--     if not gemPrice then
--       return nil, ("Missing Auctionator price for gemID %d (run refresh)"):format(gemID)
--     end
--     ev = ev + expected * gemPrice

--     local vendorPrice = GetVendorPriceCopper(gemID)
--     if vendorPrice == nil then
--       return nil, ("Vendor price not cached for gemID %d (hover it once)"):format(gemID)
--     end

--     -- Conservative assumption: lose one 12h deposit per gem sold.
--     expectedDepositLoss = expectedDepositLoss + expected * (vendorPrice * DEPOSIT_MULTIPLIER_12H)
--   end

--   local cost = ore.size * orePrice
--   local evAfterCut = ev * (1 - AH_CUT)

--   local profitAfterCut = evAfterCut - cost
--   local profitAfterCutAndDeposit = profitAfterCut - expectedDepositLoss

--   return {
--     orePrice = orePrice,
--     cost = cost,
--     ev = ev,
--     evAfterCut = evAfterCut,
--     expectedDepositLoss = expectedDepositLoss,
--     profitAfterCut = profitAfterCut,
--     profitAfterCutAndDeposit = profitAfterCutAndDeposit,
--   }
-- end
local function ComputeProspectProfit(oreItemID)
    local ore = ORES[oreItemID]
    if not ore then return nil, "Ore not configured" end
  
    local orePrice = GetAuctionatorPriceByItemID(oreItemID)
    if not orePrice then return nil, "No ore price" end
  
    local ev, expectedDepositLoss = 0, 0
  
    for gemID, expected in pairs(ore.gems) do
      local gemPrice = GetAuctionatorPriceByItemID(gemID)
      if not gemPrice then return nil, "Missing gem price" end
  
      ev = ev + expected * gemPrice
  
      local vendor = GetVendorPriceCopper(gemID)
      if not vendor then return nil, "Missing vendor price" end
  
      expectedDepositLoss = expectedDepositLoss + expected * (vendor * DEPOSIT_MULTIPLIER_12H)
    end
  
    local cost = ore.size * orePrice
    local evAfterCut = ev * (1 - AH_CUT)
    local net = evAfterCut - cost - expectedDepositLoss
  
    return {
      orePrice = orePrice,
      cost = cost,
      evAfterCut = evAfterCut,
      expectedDepositLoss = expectedDepositLoss,
      net = net,
    }
  end
-- ----------------------------
-- Tooltip integration (hover ore -> show EV)
-- ----------------------------
-- local function AddProspectLinesToTooltip(tip, oreItemID)
--   local ore = ORES[oreItemID]
--   if not ore then return end

--   local res, err = ComputeProspectProfit(oreItemID)

--   tip:AddLine(" ")
--   tip:AddLine("|cff66ccffProspecting (Auctionator cached):|r")

--   if not res then
--     tip:AddLine("|cffff6666" .. (err or "Need price data") .. "|r")
--     tip:AddLine("|cffffcc00Go to Auctionator > Shopping tab and click 'Prospect'.|r")
--     return
--   end

--   local status = (res.profitAfterCutAndDeposit > 0) and "|cff00ff00PROFITABLE|r" or "|cffff0000NOT PROFITABLE|r"

--   tip:AddLine(("Ore price: %s each"):format(MoneyString(res.orePrice)))
--   tip:AddLine(("Cost / prospect (x%d): %s"):format(ore.size, MoneyString(res.cost)))
--   tip:AddLine(("EV (after 5%% AH cut): %s"):format(MoneyString(res.evAfterCut)))
--   tip:AddLine(("Expected 12h deposit loss: %s"):format(MoneyString(res.expectedDepositLoss)))
--   tip:AddLine(("Result (cut+deposit): %s (%s)"):format(status, MoneyString(res.profitAfterCutAndDeposit)))
--   tip:AddLine("|cffffcc00Deposit model: assumes 1 failed 12h listing per gem (deposit lost).|r")
-- end
local function AddProspectLinesToTooltip(tip, oreItemID)
    local res, err = ComputeProspectProfit(oreItemID)
  
    tip:AddLine(" ")
    tip:AddLine("|cff66ccffProspecting (Auctionator cached)|r")
  
    if not res then
      tip:AddLine("|cffff6666" .. err .. "|r")
      return
    end
  
    tip:AddLine(("Cost per prospect (5 ore): %s"):format(MoneyString(res.cost)))
    tip:AddLine(("EV after AH cut: %s"):format(MoneyString(res.evAfterCut)))
    tip:AddLine(("Expected 12h deposit loss: %s"):format(MoneyString(res.expectedDepositLoss)))
  
    if res.net >= 0 then
      tip:AddLine(
        ("|cff00ff00Net profit per prospect: +%s|r")
          :format(MoneyString(res.net))
      )
    else
      tip:AddLine(
        ("|cffff0000Net loss per prospect: −%s|r")
          :format(MoneyString(res.net))
      )
    end
  end
  
  GameTooltip:HookScript("OnTooltipSetItem", function(tip)
    local _, link = tip:GetItem()
    if not link then return end
    local itemID = tonumber(link:match("item:(%d+)"))
    if ORES[itemID] then
      AddProspectLinesToTooltip(tip, itemID)
      tip:Show()
    end
  end)

-- GameTooltip:HookScript("OnTooltipSetItem", function(tip)
--   local _, link = tip:GetItem()
--   if not link then return end
--   local itemID = tonumber(link:match("item:(%d+)"))
--   if not itemID then return end
--   if not ORES[itemID] then return end

--   AddProspectLinesToTooltip(tip, itemID)
--   tip:Show()
-- end)

-- ----------------------------
-- Refresh ALL prices (ores + gems) with one click
-- ----------------------------
local function BuildGlobalProspectingItemIDSet()
  local ids = {}
  for oreID, oreData in pairs(ORES) do
    ids[oreID] = true
    for gemID, _ in pairs(oreData.gems or {}) do
      ids[gemID] = true
    end
  end
  return ids
end

local function BuildSearchTermsFromItemIDs(idSet)
  local terms, missing = {}, {}
  for itemID, _ in pairs(idSet) do
    local name = GetItemInfo(itemID)
    if name then
      name = SanitizeSearchTerm(name)
      if name ~= "" then
        table.insert(terms, name)
      end
    else
      table.insert(missing, itemID)
    end
  end
  table.sort(terms)
  return terms, missing
end

local function RefreshAllProspectingPrices()
  if not (Auctionator and Auctionator.API and Auctionator.API.v1) then
    Print("Auctionator API not available.")
    return
  end

  local idSet = BuildGlobalProspectingItemIDSet()
  local terms, missing = BuildSearchTermsFromItemIDs(idSet)

  if #terms == 0 then
    Print("No item names cached yet. Hover/search at least one ore/gem once, then try again.")
    return
  end

  Print(("Refreshing ALL prospecting prices (%d searches)..."):format(#terms))

  -- Use MultiSearchExact to avoid unrelated items containing the gem name.
  if Auctionator.API.v1.MultiSearchExact then
    Auctionator.API.v1.MultiSearchExact(CALLER_ID, terms)
  else
    -- Fallback if older Auctionator doesn't have MultiSearchExact.
    Auctionator.API.v1.MultiSearch(CALLER_ID, terms)
    Print("Note: MultiSearchExact not available; searches may include partial-name matches.")
  end

  if #missing > 0 then
    Print(("Note: %d items missing names (client hasn't cached them). Hover/search them once to cache names."):format(#missing))
  end
end

-- ----------------------------
-- Button on Auctionator Shopping tab only
-- ----------------------------
local function GetAuctionatorShoppingFrame()
  return _G["AuctionatorShoppingFrame"]
end

local function CreateShoppingOnlyRefreshButton()
  if ProspectProfitRefreshButton then return true end

  local shoppingFrame = GetAuctionatorShoppingFrame()
  if not shoppingFrame then
    return false -- not created yet
  end

  local btn = CreateFrame("Button", "ProspectProfitRefreshButton", shoppingFrame, "UIPanelButtonTemplate")
  btn:SetSize(90, 22)
  btn:SetText("Prospect")

  -- Anchor inside the Shopping frame so it only appears on that tab.
  btn:SetPoint("TOPRIGHT", shoppingFrame, "TOPRIGHT", -30, 2)

  btn:SetScript("OnClick", function()
    RefreshAllProspectingPrices()
  end)

  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Prospect")
    GameTooltip:AddLine("Refreshes Auctionator prices for every ore+gem in ProspectProfit.")
    GameTooltip:AddLine("Uses exact-match searches to avoid unrelated items.", 1, 0.8, 0)
    GameTooltip:AddLine("Profit calc includes AH cut + expected 12h deposit loss.", 1, 0.8, 0)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", GameTooltip_Hide)

  Print("Shopping prospect button created.")
  return true
end

-- Retry creation because Auctionator may create AuctionatorShoppingFrame after AH show.
local function EnsureButtonCreatedWithRetries(maxTries, delaySeconds)
  local tries = 0
  local function tick()
    tries = tries + 1
    if CreateShoppingOnlyRefreshButton() then
      return
    end
    if tries >= maxTries then
      Print("Could not find AuctionatorShoppingFrame. Click Auctionator's Shopping tab once, then /reload.")
      return
    end
    C_Timer.After(delaySeconds, tick)
  end
  tick()
end

-- ----------------------------
-- Events
-- ----------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")

eventFrame:SetScript("OnEvent", function(_, event, name)
  if event == "ADDON_LOADED" and name == ADDON_NAME then
    Print("Loaded. Open AH -> Auctionator -> Shopping tab to see the Prospect button.")
  elseif event == "AUCTION_HOUSE_SHOW" then
    EnsureButtonCreatedWithRetries(20, 0.2) -- ~4 seconds total
  end
end)

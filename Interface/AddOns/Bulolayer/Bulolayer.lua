-- Bulolayer.lua
-- Core addon logic for layer swapping

-- Local state variables
local readyForInvite = false
local outgoingInvite = nil
local joinedViaBulolayer = false  -- Track if we joined via addon (for auto-leave)
local addonLoaded = false

-- Main event frame
local frame = CreateFrame("Frame", "BulolayerFrame")

-- Event handler
local function OnEvent(self, event, arg1, arg2, arg3, arg4, ...)
    -- Addon loaded - initialize
    if event == "ADDON_LOADED" and arg1 == "Bulolayer" then
        Bulolayer:InitDB()
        addonLoaded = true
        C_ChatInfo.RegisterAddonMessagePrefix(Bulolayer.ADDON_PREFIX)

        -- Delayed init for minimap and options
        C_Timer.After(0.5, function()
            if Bulolayer_CreateOptions then
                Bulolayer_CreateOptions()
            end
            if Bulolayer_MinimapButton_Initialize then
                Bulolayer_MinimapButton_Initialize()
            end
        end)
        return
    end

    -- Skip if not loaded or disabled
    if not addonLoaded then return end
    if not Bulolayer:GetSetting("enabled") then return end

    -- Handle addon messages
    if event == "CHAT_MSG_ADDON" then
        if arg1 == Bulolayer.ADDON_PREFIX then
            local sender = Bulolayer:StripRealm(arg4)
            if arg3 == "WHISPER" then
                -- Received cooldown info from another player
                local cooldownTime = tonumber(arg2)
                if cooldownTime and cooldownTime > 0 then
                    Bulolayer:AddToBlacklist(sender, cooldownTime)
                end
                return
            end
            -- Guild or channel broadcast
            HandleInviteRequest(sender, false)
        end
        return
    end

    -- Handle channel messages
    if event == "CHAT_MSG_CHANNEL" then
        local message = arg1
        local sender = Bulolayer:StripRealm(arg2)
        local channelName = arg4

        local configChannel = Bulolayer:GetSetting("channel")
        local configMessage = Bulolayer:GetSetting("message")

        if strfind(channelName, configChannel) and strlower(message) == strlower(configMessage) then
            HandleInviteRequest(sender, false)
        end
        return
    end

    -- Handle whispers
    if event == "CHAT_MSG_WHISPER" then
        local message = arg1
        local sender = Bulolayer:StripRealm(arg2)
        local configMessage = Bulolayer:GetSetting("message")

        if Bulolayer:GetSetting("whisper") and strlower(message) == strlower(configMessage) then
            HandleInviteRequest(sender, true)
        end
        return
    end

    -- Handle party invite request
    if event == "PARTY_INVITE_REQUEST" then
        local inviter = Bulolayer:StripRealm(arg1)
        HandlePartyInvite(inviter)
        return
    end

    -- Handle group roster update
    if event == "GROUP_ROSTER_UPDATE" then
        HandleGroupUpdate()
        return
    end
end

-- Handle incoming invite request (someone wants to join us)
function HandleInviteRequest(playerName, isWhisper)
    -- Self-request when not in group
    if playerName == UnitName("player") and not IsInGroup() then
        readyForInvite = true
        Bulolayer:PrintVerbose("Ready to accept layer swap invite.", "INFO")
        return
    end

    -- Check if we can invite
    if not CanPlayerInvite() then return end
    if not IsGroupThresholdMet() then return end

    -- Check restrictions
    if Bulolayer:GetSetting("guildOnly") and not Bulolayer:IsInGuild(playerName) then
        return
    end
    if Bulolayer:GetSetting("friendsOnly") and not Bulolayer:IsFriend(playerName) and not Bulolayer:IsInGuild(playerName) then
        return
    end

    -- Check rate limit
    if not Bulolayer:CanSendInvite() then
        Bulolayer:PrintVerbose("Rate limit reached, skipping invite.", "WARNING")
        return
    end

    -- Check cooldown (whispers bypass if from favorite)
    local isFav = Bulolayer:IsFavorite(playerName)
    if not isWhisper and not isFav then
        if not Bulolayer:CanInvite(playerName) then
            local remaining = Bulolayer:GetBlacklistTime(playerName)
            Bulolayer:PrintVerbose(playerName .. " on cooldown: " .. Bulolayer:FormatTime(remaining), "WARNING")
            return
        end
    end

    -- Send invite (C_PartyInfo for TBC Anniversary)
    C_PartyInfo.InviteUnit(playerName)
    outgoingInvite = playerName
    Bulolayer:RecordInviteSent()
    Bulolayer:PrintVerbose("Invited " .. playerName .. " for layer swap.", "SUCCESS")
end

-- Handle incoming party invite (someone invited us)
function HandlePartyInvite(inviterName)
    if not readyForInvite then return end

    -- Check restrictions
    if Bulolayer:GetSetting("guildOnly") and not Bulolayer:IsInGuild(inviterName) then
        Bulolayer:PrintVerbose("Declined invite from " .. inviterName .. " (not in guild).", "WARNING")
        C_PartyInfo.DeclineInvite()
        StaticPopup_Hide("PARTY_INVITE")
        return
    end

    if Bulolayer:GetSetting("friendsOnly") and not Bulolayer:IsFriend(inviterName) and not Bulolayer:IsInGuild(inviterName) then
        Bulolayer:PrintVerbose("Declined invite from " .. inviterName .. " (not friend/guild).", "WARNING")
        C_PartyInfo.DeclineInvite()
        StaticPopup_Hide("PARTY_INVITE")
        return
    end

    -- Check cooldown (favorites bypass)
    local isFav = Bulolayer:IsFavorite(inviterName)
    local remaining = Bulolayer:GetBlacklistTime(inviterName)

    if remaining and not isFav then
        C_PartyInfo.DeclineInvite()
        StaticPopup_Hide("PARTY_INVITE")
        -- Send cooldown info back
        C_ChatInfo.SendAddonMessage(Bulolayer.ADDON_PREFIX, tostring(math.floor(remaining)), "WHISPER", inviterName)
        Bulolayer:Print("Declined " .. inviterName .. " (cooldown: " .. Bulolayer:FormatTime(remaining) .. ")", "WARNING")
        return
    end

    -- Accept the invite
    C_PartyInfo.AcceptInvite()
    StaticPopup_Hide("PARTY_INVITE")

    -- Add to blacklist and record stats
    Bulolayer:AddToBlacklist(inviterName)
    Bulolayer:RecordSwap(inviterName)

    readyForInvite = false
    joinedViaBulolayer = true

    Bulolayer:PrintVerbose("Accepted layer swap from " .. inviterName, "SUCCESS")

    -- Update minimap status
    if Bulolayer_MinimapButton_UpdateStatus then
        Bulolayer_MinimapButton_UpdateStatus()
    end
end

-- Handle group roster update
function HandleGroupUpdate()
    -- Add all group members to blacklist
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name = UnitName("raid" .. i)
            if name and name ~= UnitName("player") then
                Bulolayer:AddToBlacklist(name)
            end
        end
    elseif IsInGroup() then
        for i = 1, GetNumGroupMembers() - 1 do
            local name = UnitName("party" .. i)
            if name then
                Bulolayer:AddToBlacklist(name)
            end
        end

        -- Schedule auto-leave if enabled and joined via addon
        if joinedViaBulolayer then
            Bulolayer:ScheduleAutoLeave()
            joinedViaBulolayer = false
        end
    else
        -- Left group - cancel any pending auto-leave
        Bulolayer:CancelAutoLeave()
    end

    -- Update minimap
    if Bulolayer_MinimapButton_UpdateStatus then
        Bulolayer_MinimapButton_UpdateStatus()
    end
end

-- Check if player can invite others
function CanPlayerInvite()
    if not IsInGroup() then
        return true
    end
    return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

-- Check if group size allows more invites
function IsGroupThresholdMet()
    local members = GetNumGroupMembers()
    local threshold = Bulolayer:GetSetting("inviteThreshold")

    if IsInRaid() then
        return members < 40 and Bulolayer:GetSetting("inviteInRaid")
    elseif IsInGroup() then
        return members < threshold
    else
        return threshold ~= 0
    end
end

-- Find a layer group (broadcast)
function Bulolayer_FindGroup()
    if not Bulolayer:GetSetting("enabled") then
        Bulolayer:Print("Addon is disabled.", "WARNING")
        return
    end

    -- Check broadcast rate limit
    if not Bulolayer:CanBroadcast() then
        Bulolayer:Print("Please wait before broadcasting again.", "WARNING")
        return
    end

    local message = Bulolayer:GetSetting("message")
    local channel = Bulolayer:GetSetting("channel")

    -- Send to guild
    if Bulolayer:GetSetting("guild") then
        C_ChatInfo.SendAddonMessage(Bulolayer.ADDON_PREFIX, "I", "GUILD")
        Bulolayer:PrintVerbose("Sent layer request to guild.", "INFO")
    end

    -- Send to channel
    if channel and channel ~= "" then
        for i = 1, 15 do
            local id, name = GetChannelName(i)
            if name and strlower(name) == strlower(channel) then
                SendChatMessage(message, "CHANNEL", nil, id)
                Bulolayer:PrintVerbose("Sent '" .. message .. "' to channel " .. name, "INFO")
                break
            end
        end
    end

    Bulolayer:RecordBroadcast()
    readyForInvite = true
end

-- Check if target is the one we invited
function TargetIsInvited(name)
    return name == outgoingInvite
end

-- Register events
frame:SetScript("OnEvent", OnEvent)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("PARTY_INVITE_REQUEST")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("CHAT_MSG_CHANNEL")
frame:RegisterEvent("CHAT_MSG_WHISPER")

-- Slash commands
SLASH_BULOLAYER1 = "/l"
SLASH_BULOLAYER2 = "/layer"
SlashCmdList["BULOLAYER"] = Bulolayer_FindGroup

SLASH_BULOLAYERCLEAR1 = "/layerclear"
SlashCmdList["BULOLAYERCLEAR"] = function()
    Bulolayer:ClearBlacklist()
end

SLASH_BULOLAYERSTATS1 = "/layerstats"
SlashCmdList["BULOLAYERSTATS"] = function()
    Bulolayer:PrintStats()
end

SLASH_BULOLAYERFAV1 = "/layerfav"
SlashCmdList["BULOLAYERFAV"] = function(msg)
    local name = strtrim(msg or "")
    if name == "" then
        -- List favorites
        if not BulolayerDB.favorites or #BulolayerDB.favorites == 0 then
            Bulolayer:Print("No favorites set.", "INFO")
        else
            Bulolayer:Print("Favorites: " .. table.concat(BulolayerDB.favorites, ", "), "INFO")
        end
    else
        -- Toggle favorite
        Bulolayer:ToggleFavorite(name)
    end
end

SLASH_BULOLAYERHELP1 = "/layerhelp"
SlashCmdList["BULOLAYERHELP"] = function()
    Bulolayer:Print("=== Bulolayer Commands ===", "INFO")
    Bulolayer:Print("/l or /layer - Find layer swap group", "INFO")
    Bulolayer:Print("/layerconfig - Open settings", "INFO")
    Bulolayer:Print("/layerclear - Clear cooldowns", "INFO")
    Bulolayer:Print("/layerstats - Show statistics", "INFO")
    Bulolayer:Print("/layerfav [name] - List or toggle favorites", "INFO")
    Bulolayer:Print("/layerhelp - Show this help", "INFO")
end

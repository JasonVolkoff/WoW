-- Bulolayer_Utils.lua
-- Helper functions and constants for Bulolayer addon

-- Addon namespace
Bulolayer = Bulolayer or {}

-- Version
Bulolayer.VERSION = "2.0"
Bulolayer.ADDON_NAME = "Bulolayer"
Bulolayer.ADDON_PREFIX = "Bulolayer"

-- Colors for chat messages
Bulolayer.COLORS = {
    PREFIX = "|cffff306f",      -- Pink (addon title color)
    SUCCESS = "|cff00ff00",     -- Green
    ERROR = "|cffff0000",       -- Red
    WARNING = "|cffffff00",     -- Yellow
    INFO = "|cffffffff",        -- White
    RESET = "|r"
}

-- Default settings
Bulolayer.DEFAULTS = {
    settings = {
        enabled = true,
        message = "layer",
        delay = 1800,           -- 30 minutes
        channel = "layer",
        guild = true,
        whisper = true,
        inviteThreshold = 4,
        inviteInRaid = false,
        autoLeave = false,
        autoLeaveDelay = 3,     -- seconds
        verbose = false,
        guildOnly = false,
        friendsOnly = false,
        rateLimitInvites = 5,   -- max invites per minute
        rateLimitBroadcast = 10 -- seconds between broadcasts
    },
    stats = {
        totalSwaps = 0,
        todaySwaps = 0,
        lastSwapTime = 0,
        lastSwapDate = "",
        partners = {}           -- { ["PlayerName"] = count }
    },
    blacklist = {},             -- { ["PlayerName"] = expireTime }
    favorites = {},             -- { "PlayerName1", "PlayerName2", ... }
    minimap = {
        hide = false,
        position = 225          -- angle in degrees
    }
}

-- Initialize database with defaults
function Bulolayer:InitDB()
    -- Global DB (account-wide)
    if not BulolayerDB then
        BulolayerDB = {}
    end

    -- Per-character DB
    if not BulolayerCharDB then
        BulolayerCharDB = {}
    end

    -- Merge defaults with saved data
    for section, defaults in pairs(self.DEFAULTS) do
        if type(defaults) == "table" then
            BulolayerDB[section] = BulolayerDB[section] or {}
            for key, value in pairs(defaults) do
                if BulolayerDB[section][key] == nil then
                    BulolayerDB[section][key] = value
                end
            end
        end
    end

    -- Cleanup expired blacklist entries
    self:CleanupBlacklist()

    -- Reset daily stats if new day
    self:CheckDailyReset()
end

-- Get setting value
function Bulolayer:GetSetting(key)
    if BulolayerDB and BulolayerDB.settings then
        return BulolayerDB.settings[key]
    end
    return self.DEFAULTS.settings[key]
end

-- Set setting value
function Bulolayer:SetSetting(key, value)
    if BulolayerDB and BulolayerDB.settings then
        BulolayerDB.settings[key] = value
    end
end

-- Print message to chat
function Bulolayer:Print(msg, msgType)
    msgType = msgType or "INFO"
    local color = self.COLORS[msgType] or self.COLORS.INFO
    local prefix = self.COLORS.PREFIX .. "[Bulolayer]" .. self.COLORS.RESET .. " "
    print(prefix .. color .. msg .. self.COLORS.RESET)
end

-- Print only if verbose mode enabled
function Bulolayer:PrintVerbose(msg, msgType)
    if self:GetSetting("verbose") then
        self:Print(msg, msgType)
    end
end

-- Add player to blacklist with expiration
function Bulolayer:AddToBlacklist(playerName, duration)
    if not BulolayerDB.blacklist then
        BulolayerDB.blacklist = {}
    end
    duration = duration or self:GetSetting("delay")
    BulolayerDB.blacklist[playerName] = GetTime() + duration
end

-- Check if player is on blacklist (returns remaining time or nil)
function Bulolayer:GetBlacklistTime(playerName)
    if not BulolayerDB.blacklist or not BulolayerDB.blacklist[playerName] then
        return nil
    end
    local remaining = BulolayerDB.blacklist[playerName] - GetTime()
    if remaining <= 0 then
        BulolayerDB.blacklist[playerName] = nil
        return nil
    end
    return remaining
end

-- Check if player can be invited (not on cooldown)
function Bulolayer:CanInvite(playerName)
    return self:GetBlacklistTime(playerName) == nil
end

-- Cleanup expired blacklist entries
function Bulolayer:CleanupBlacklist()
    if not BulolayerDB.blacklist then return end
    local now = GetTime()
    for name, expireTime in pairs(BulolayerDB.blacklist) do
        if expireTime <= now then
            BulolayerDB.blacklist[name] = nil
        end
    end
end

-- Clear entire blacklist
function Bulolayer:ClearBlacklist()
    BulolayerDB.blacklist = {}
    self:Print("Blacklist cleared.", "SUCCESS")
end

-- Get blacklist count
function Bulolayer:GetBlacklistCount()
    if not BulolayerDB.blacklist then return 0 end
    local count = 0
    local now = GetTime()
    for name, expireTime in pairs(BulolayerDB.blacklist) do
        if expireTime > now then
            count = count + 1
        end
    end
    return count
end

-- Add to favorites
function Bulolayer:AddFavorite(playerName)
    if not BulolayerDB.favorites then
        BulolayerDB.favorites = {}
    end
    -- Check if already in favorites
    for i, name in ipairs(BulolayerDB.favorites) do
        if name == playerName then
            return false -- Already exists
        end
    end
    table.insert(BulolayerDB.favorites, playerName)
    return true
end

-- Remove from favorites
function Bulolayer:RemoveFavorite(playerName)
    if not BulolayerDB.favorites then return false end
    for i, name in ipairs(BulolayerDB.favorites) do
        if name == playerName then
            table.remove(BulolayerDB.favorites, i)
            return true
        end
    end
    return false
end

-- Check if player is favorite
function Bulolayer:IsFavorite(playerName)
    if not BulolayerDB.favorites then return false end
    for i, name in ipairs(BulolayerDB.favorites) do
        if name == playerName then
            return true
        end
    end
    return false
end

-- Toggle favorite status
function Bulolayer:ToggleFavorite(playerName)
    if self:IsFavorite(playerName) then
        self:RemoveFavorite(playerName)
        self:Print(playerName .. " removed from favorites.", "INFO")
        return false
    else
        self:AddFavorite(playerName)
        self:Print(playerName .. " added to favorites.", "SUCCESS")
        return true
    end
end

-- Increment swap stats
function Bulolayer:RecordSwap(partnerName)
    if not BulolayerDB.stats then
        BulolayerDB.stats = self.DEFAULTS.stats
    end

    BulolayerDB.stats.totalSwaps = (BulolayerDB.stats.totalSwaps or 0) + 1
    BulolayerDB.stats.todaySwaps = (BulolayerDB.stats.todaySwaps or 0) + 1
    BulolayerDB.stats.lastSwapTime = GetTime()
    BulolayerDB.stats.lastSwapDate = date("%Y-%m-%d")

    -- Track partner frequency
    if partnerName then
        BulolayerDB.stats.partners = BulolayerDB.stats.partners or {}
        BulolayerDB.stats.partners[partnerName] = (BulolayerDB.stats.partners[partnerName] or 0) + 1
    end
end

-- Check and reset daily stats
function Bulolayer:CheckDailyReset()
    if not BulolayerDB.stats then return end
    local today = date("%Y-%m-%d")
    if BulolayerDB.stats.lastSwapDate ~= today then
        BulolayerDB.stats.todaySwaps = 0
    end
end

-- Get stats summary
function Bulolayer:GetStats()
    if not BulolayerDB.stats then
        return self.DEFAULTS.stats
    end
    return BulolayerDB.stats
end

-- Format time (seconds to human readable)
function Bulolayer:FormatTime(seconds)
    if not seconds or seconds <= 0 then
        return "0s"
    end
    local mins = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    if mins > 0 then
        return string.format("%dm %ds", mins, secs)
    else
        return string.format("%ds", secs)
    end
end

-- Strip realm name from player name
function Bulolayer:StripRealm(name)
    if not name then return nil end
    local stripped = strsplit("-", name)
    return stripped
end

-- Check if player is in guild
function Bulolayer:IsInGuild(playerName)
    local numMembers = GetNumGuildMembers()
    for i = 1, numMembers do
        local name = GetGuildRosterInfo(i)
        if name then
            name = self:StripRealm(name)
            if name == playerName then
                return true
            end
        end
    end
    return false
end

-- Check if player is a friend
function Bulolayer:IsFriend(playerName)
    local numFriends = C_FriendList.GetNumFriends()
    for i = 1, numFriends do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        if info and info.name then
            local name = self:StripRealm(info.name)
            if name == playerName then
                return true
            end
        end
    end
    return false
end

-- Rate limiting
Bulolayer.rateLimit = {
    invites = {},       -- timestamps of recent invites
    lastBroadcast = 0
}

function Bulolayer:CanSendInvite()
    local now = GetTime()
    local limit = self:GetSetting("rateLimitInvites") or 5

    -- Clean old entries (older than 60 seconds)
    local newInvites = {}
    for i, timestamp in ipairs(self.rateLimit.invites) do
        if now - timestamp < 60 then
            table.insert(newInvites, timestamp)
        end
    end
    self.rateLimit.invites = newInvites

    -- Check if under limit
    return #self.rateLimit.invites < limit
end

function Bulolayer:RecordInviteSent()
    table.insert(self.rateLimit.invites, GetTime())
end

function Bulolayer:CanBroadcast()
    local now = GetTime()
    local cooldown = self:GetSetting("rateLimitBroadcast") or 10
    return (now - self.rateLimit.lastBroadcast) >= cooldown
end

function Bulolayer:RecordBroadcast()
    self.rateLimit.lastBroadcast = GetTime()
end

-- Auto-leave timer
Bulolayer.autoLeaveTimer = nil
Bulolayer.pendingAutoLeave = false

function Bulolayer:ScheduleAutoLeave()
    if not self:GetSetting("autoLeave") then return end
    if self.autoLeaveTimer then return end -- Already scheduled

    local delay = self:GetSetting("autoLeaveDelay") or 3
    self.pendingAutoLeave = true

    self.autoLeaveTimer = C_Timer.NewTimer(delay, function()
        Bulolayer:ExecuteAutoLeave()
    end)
end

function Bulolayer:CancelAutoLeave()
    if self.autoLeaveTimer then
        self.autoLeaveTimer:Cancel()
        self.autoLeaveTimer = nil
    end
    self.pendingAutoLeave = false
end

function Bulolayer:ExecuteAutoLeave()
    self.autoLeaveTimer = nil
    self.pendingAutoLeave = false

    -- Safety check: don't leave if group has 3+ members
    local members = GetNumGroupMembers()
    if members >= 3 then
        self:PrintVerbose("Auto-leave cancelled: group has " .. members .. " members.", "WARNING")
        return
    end

    -- Don't leave raid
    if IsInRaid() then
        self:PrintVerbose("Auto-leave cancelled: in raid.", "WARNING")
        return
    end

    -- Leave party (C_PartyInfo for TBC Anniversary)
    if IsInGroup() then
        C_PartyInfo.LeaveParty()
        self:PrintVerbose("Auto-left group after layer swap.", "INFO")
    end
end

-- Print stats to chat
function Bulolayer:PrintStats()
    local stats = self:GetStats()
    self:Print("=== Bulolayer Statistics ===", "INFO")
    self:Print("Total swaps: " .. (stats.totalSwaps or 0), "INFO")
    self:Print("Today's swaps: " .. (stats.todaySwaps or 0), "INFO")
    self:Print("Active cooldowns: " .. self:GetBlacklistCount(), "INFO")

    -- Top partners
    if stats.partners and next(stats.partners) then
        local sorted = {}
        for name, count in pairs(stats.partners) do
            table.insert(sorted, {name = name, count = count})
        end
        table.sort(sorted, function(a, b) return a.count > b.count end)

        self:Print("Top partners:", "INFO")
        for i = 1, math.min(3, #sorted) do
            self:Print("  " .. sorted[i].name .. ": " .. sorted[i].count .. " swaps", "INFO")
        end
    end
end

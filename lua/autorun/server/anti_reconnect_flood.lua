-- ============================================================
--  Anti Reconnect Flood
--  Blocks players who reconnect too many times in a short period
--
--  Commands: af_status | af_window | af_max | af_cooldown |
--            af_log | af_unblock | af_unblock_all | af_list | af_reset
-- ============================================================

if CLIENT then return end

--  Default configuration
local CFG = {
    window   = 30,   -- Time window in seconds to track attempts
    max      = 3,    -- Max connection attempts allowed in the window
    cooldown = 120,  -- Block duration in seconds after flood detected
    log      = true, -- Print logs to server console
}

--  Config persistence (data/anti_flood.json)
local DATA_FILE = "anti_flood.json"

local function SaveConfig()
    file.Write(DATA_FILE, util.TableToJSON(CFG, true))
end

local function LoadConfig()
    if file.Exists(DATA_FILE, "DATA") then
        local raw     = file.Read(DATA_FILE, "DATA")
        local decoded = util.JSONToTable(raw)
        if decoded then
            for k, v in pairs(decoded) do
                if CFG[k] ~= nil then CFG[k] = v end
            end
        end
    end
end

LoadConfig()

--  Runtime data
local attempts     = {} -- attempts[steamID64]     = { t1, t2, ... }
local blockedUntil = {} -- blockedUntil[steamID64] = CurTime() + cooldown

local function cleanupOld(list, now)
    for i = #list, 1, -1 do
        if now - list[i] > CFG.window then
            table.remove(list, i)
        end
    end
end

-- runs before the player spawns
hook.Add("CheckPassword", "AntiReconnectFlood_CheckPassword",
function(steamID64, ipAddress, svPassword, clPassword, name)
    local now = CurTime()

    if blockedUntil[steamID64] and blockedUntil[steamID64] > now then
        local remaining = math.ceil(blockedUntil[steamID64] - now)
        return false, "Connection temporarily blocked. Try again in " .. remaining .. "s."
    end

    attempts[steamID64] = attempts[steamID64] or {}
    local list = attempts[steamID64]
    table.insert(list, now)
    cleanupOld(list, now)

    if #list > CFG.max then
        blockedUntil[steamID64] = now + CFG.cooldown
        attempts[steamID64]     = {}
        if CFG.log then
            print(("[ANTI-FLOOD] Blocked %s (%s) for %ds — too many connections.")
                :format(tostring(name), tostring(steamID64), CFG.cooldown))
        end
        return false, "Too many connections. Wait " .. CFG.cooldown .. "s."
    end
end)

--  prevents tables from growing indefinitely
timer.Create("AntiReconnectFlood_Cleanup", 60, 0, function()
    local now = CurTime()
    for sid, untilTime in pairs(blockedUntil) do
        if untilTime <= now then blockedUntil[sid] = nil end
    end
    for sid, list in pairs(attempts) do
        cleanupOld(list, now)
        if #list == 0 then attempts[sid] = nil end
    end
end)

-- ============================================================
--  Console commands
-- ============================================================

-- DO NOT TOUCH THIS
local function ServerOnly(ply)
    return IsValid(ply)
end

-- af_status — display current configuration
concommand.Add("af_status", function(ply)
    if ServerOnly(ply) then return end
    print("========= Anti-Flood Status =========")
    print("  af_window   : " .. CFG.window   .. "s  (analysis window)")
    print("  af_max      : " .. CFG.max      .. "   (max attempts)")
    print("  af_cooldown : " .. CFG.cooldown .. "s  (block duration)")
    print("  af_log      : " .. tostring(CFG.log) .. "   (console logging)")
    print("  Blocked now : " .. table.Count(blockedUntil) .. " player(s)")
    print("=====================================")
end)

-- af_window <seconds> — set the analysis time window
concommand.Add("af_window", function(ply, _, args)
    if ServerOnly(ply) then return end
    local v = tonumber(args[1])
    if not v or v < 1 then
        print("[ANTI-FLOOD] Usage: af_window <seconds>") return
    end
    CFG.window = v
    SaveConfig()
    print("[ANTI-FLOOD] Analysis window set to " .. v .. "s.")
end)

-- af_max <number> — set max allowed attempts
concommand.Add("af_max", function(ply, _, args)
    if ServerOnly(ply) then return end
    local v = tonumber(args[1])
    if not v or v < 1 then
        print("[ANTI-FLOOD] Usage: af_max <number>") return
    end
    CFG.max = v
    SaveConfig()
    print("[ANTI-FLOOD] Max attempts set to " .. v .. ".")
end)

-- af_cooldown <seconds> — set block duration
concommand.Add("af_cooldown", function(ply, _, args)
    if ServerOnly(ply) then return end
    local v = tonumber(args[1])
    if not v or v < 1 then
        print("[ANTI-FLOOD] Usage: af_cooldown <seconds>") return
    end
    CFG.cooldown = v
    SaveConfig()
    print("[ANTI-FLOOD] Cooldown set to " .. v .. "s.")
end)

-- af_log <0|1> — toggle console logging
concommand.Add("af_log", function(ply, _, args)
    if ServerOnly(ply) then return end
    local v = args[1]
    if v == "1" or v == "true" then
        CFG.log = true
    elseif v == "0" or v == "false" then
        CFG.log = false
    else
        print("[ANTI-FLOOD] Usage: af_log <0|1>") return
    end
    SaveConfig()
    print("[ANTI-FLOOD] Logging " .. (CFG.log and "enabled." or "disabled."))
end)

-- af_unblock <steamID64> — manually unblock a specific player
concommand.Add("af_unblock", function(ply, _, args)
    if ServerOnly(ply) then return end
    local sid = args[1]
    if not sid then
        print("[ANTI-FLOOD] Usage: af_unblock <steamID64>") return
    end
    if blockedUntil[sid] then
        blockedUntil[sid] = nil
        attempts[sid]     = nil
        print("[ANTI-FLOOD] Unblocked: " .. sid)
    else
        print("[ANTI-FLOOD] Player is not blocked: " .. sid)
    end
end)

-- af_unblock_all — unblock everyone immediately
concommand.Add("af_unblock_all", function(ply)
    if ServerOnly(ply) then return end
    local count  = table.Count(blockedUntil)
    blockedUntil = {}
    attempts     = {}
    print("[ANTI-FLOOD] " .. count .. " player(s) unblocked.")
end)

-- af_list — list currently blocked players and remaining time
concommand.Add("af_list", function(ply)
    if ServerOnly(ply) then return end
    local now   = CurTime()
    local count = 0
    print("======= Blocked Players =======")
    for sid, untilTime in pairs(blockedUntil) do
        if untilTime > now then
            print(("  %s  →  %ds remaining"):format(sid, math.ceil(untilTime - now)))
            count = count + 1
        end
    end
    if count == 0 then print("  (none)") end
    print("===============================")
end)

-- af_reset — restore default configuration
concommand.Add("af_reset", function(ply)
    if ServerOnly(ply) then return end
    CFG.window   = 30
    CFG.max      = 3
    CFG.cooldown = 120
    CFG.log      = true
    SaveConfig()
    print("[ANTI-FLOOD] Configuration reset to defaults.")
end)

print("[ANTI-FLOOD] Loaded. Type 'af_status' to view current settings.")

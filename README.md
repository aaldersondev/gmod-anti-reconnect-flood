# gmod-anti-reconnect-flood
The addon tracks connection attempts per SteamID64 within a configurable time window. If a player connects too many times in that window, they are blocked for a configurable cooldown period and receive a clear rejection message with the remaining wait time.

af_status              → Show current configuration and number of blocked players
af_window  <seconds>  → Set the analysis time window          (default: 30)
af_max     <number>   → Set max connection attempts allowed   (default: 3)
af_cooldown <seconds> → Set block duration after flood        (default: 120)
af_log     <0|1>      → Enable or disable console logging     (default: 1)
af_unblock <steamID64>→ Manually unblock a specific player
af_unblock_all        → Immediately unblock all players
af_list               → List currently blocked players and remaining time
af_reset              → Restore all settings to default values

Workshop Version : https://steamcommunity.com/sharedfiles/filedetails/?id=3672322607

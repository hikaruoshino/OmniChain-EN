-- =============================================================================
-- OmniChain.lua : auto-skillchain addon for all 22 jobs and all 14 weapon types (v7.4.6 - per-chain limit starts over with each fight)
-- =============================================================================

_addon.name     = "OmniChain"
_addon.author   = "hikaruoshino"
_addon.version  = "7.4.6"
_addon.commands = {"omni", "omnichain"}

require("luau")
local config  = require("config")
local texts   = require("texts")
local res     = require("resources")
local packets = require("packets")
local sc_dict = require("sc_dict")

-- Number cast that never fails (prevents string-vs-number comparison errors)
local function safe_num(v, default_val)
    if type(v) == "number" then return v end
    if type(v) == "string" then
        local n = tonumber(v)
        if n then return n end
    end
    return default_val or 0
end

-- Safe comparison helpers
local function safe_gte(a, b) return safe_num(a, 0) >= safe_num(b, 0) end
local function safe_gt(a, b)  return safe_num(a, 0) >  safe_num(b, 0) end
local function safe_lte(a, b) return safe_num(a, 0) <= safe_num(b, 0) end
local function safe_lt(a, b)  return safe_num(a, 0) <  safe_num(b, 0) end

-- Chat output helper
local function chat_msg(msg, color)
    windower.add_to_chat(color or 207, tostring(msg))
end

-- Default settings (data/settings.xml)
local defaults = {}
defaults.enabled = true
defaults.show_hud = false -- HUD hidden on first start
defaults.debug_logging = true -- write the debug log file
defaults.min_tp = 1000
defaults.party_sync = true     -- unused (nothing reads it; kept so existing settings.xml files stay valid)
defaults.auto_mode = "flexible" -- "flexible": fire the top WS even when nothing connects in a window / anything else ("strict"): hold. "lead_only" is not implemented and acts like "strict"
defaults.wait_delay = 1.2
defaults.start_mode = "auto"  -- "auto": the first WS is also automatic / "manual": you open the chain yourself (the addon continues someone else's opener)
defaults.follow_wait = 6.0    -- manual: seconds to wait after the previous WS lands before the auto WS (leaves room for others to interject)
defaults.open_player = 3.3    -- when the previous WS was yours or a party member's (not a trust), seconds until the chain window is treated as open (for testing; trusts stay at 3.3)
defaults.focus_people = 3     -- when this many people (including you) target the same enemy, use the max-power WS (with only 2, a normal skillchain is stronger)
defaults.focus_tp = 1500       -- TP at which the max-power WS is used
defaults.focus_max = true      -- when the whole party targets the same enemy, skip chains/tosses and use the strongest WS
defaults.toss = true          -- predict a party member's next WS and, when it is close, pick a WS whose property lets them chain
defaults.ws_reach = 3.5       -- distance at which melee WS (range 2) may be used: the number shown by distanceplus (enemy size is not subtracted)
defaults.min_follow = 4.0     -- minimum seconds after the previous WS (anyone's) lands before the next auto WS (waits for the chain window to open)
-- Trusts that skillchain on their own (Iroha, Noillurie, Gilgamesh, Ark GK; Tenzen is not waited for)
defaults.trust_solo = true        -- when such a trust uses its trigger ability, do not auto-WS until their solo chain is over
defaults.solo_start_wait = 12.0   -- seconds to wait for the first WS after the ability (give up waiting if none comes)
defaults.solo_gap = 11.0          -- seconds to wait from one trust WS to the next (past this, the solo chain counts as over; measured: Iroha is about 10 s apart)
defaults.sphere_hold_sec = 20     -- seconds of no auto WS after the area-sphere warning (the Moogle's line in Ambuscade chapter 1) (0-60; 0 = off)
defaults.pos = {x = 500, y = 350}
defaults.text = {font = "Consolas", size = 11, alpha = 255}
defaults.bg = {alpha = 180, red = 10, green = 10, blue = 15}
defaults.padding = 6

-- Default weapon type and WS priority list per job (overridden by omnichain_config.json if present)
-- Not saved to settings.xml: the config library reads numbered XML nodes such as <1> as strings,
-- so a list longer than the default would mix numeric and string keys and error on the next load/save
local profiles = {
    ['WAR'] = { weapon = "Great Axe", ws_priority = {"Disaster", "Upheaval", "Ukko's Fury", "King's Justice", "Fell Cleave", "Sturmwind", "Armor Break", "Keen Edge", "Weapon Break"} },
    ['PLD'] = { weapon = "Sword", ws_priority = {"Imperator", "Savage Blade", "Chant du Cygne", "Vorpal Blade", "Atonement"} },
    ['SAM'] = { weapon = "Great Katana", ws_priority = {"Tachi: Mumei", "Tachi: Fudo", "Tachi: Shoha", "Tachi: Kasha"} },
    ['THF'] = { weapon = "Dagger", ws_priority = {"Ruthless Stroke", "Rudra's Storm", "Evisceration", "Aeolian Edge"} },
    ['DRK'] = { weapon = "Scythe", ws_priority = {"Origin", "Cross Reaper", "Entropy", "Catastrophe", "Shadow of Death", "Spinning Scythe", "Vorpal Scythe"} },
    ['RNG'] = { weapon = "Archery", ws_priority = {"Sarv", "Jishnu's Radiance", "Apex Arrow", "Namas Arrow", "Sidewinder"} },
    ['NIN'] = { weapon = "Katana", ws_priority = {"Zesho Meppo", "Blade: Shun", "Blade: Hi", "Blade: Jin", "Blade: Yu"} },
    ['DRG'] = { weapon = "Polearm", ws_priority = {"Diarmuid", "Impulse Drive", "Camlann's Torment", "Stardiver", "Skewer"} },
    ['MNK'] = { weapon = "Hand-to-Hand", ws_priority = {"Maru Kala", "Victory Smite", "Shijin Spiral", "Asuran Fists"} },
    ['RDM'] = { weapon = "Sword", ws_priority = {"Imperator", "Savage Blade", "Chant du Cygne", "Death Blossom", "Sanguine Blade"} },
    ['BLU'] = { weapon = "Sword", ws_priority = {"Imperator", "Savage Blade", "Chant du Cygne", "Requiescat"} },
    ['COR'] = { weapon = "Marksmanship", ws_priority = {"Terminus", "Leaden Salute", "Last Stand", "Wildfire", "Blast Shot", "Heavy Shot", "Numbing Shot"} },
    ['DNC'] = { weapon = "Dagger", ws_priority = {"Ruthless Stroke", "Pyrrhic Kleos", "Rudra's Storm", "Evisceration"} },
    ['RUN'] = { weapon = "Great Sword", ws_priority = {"Fimbulvetr", "Dimidiation", "Torcleaver", "Resolution", "Crescent Moon", "Sickle Moon", "Herculean Slash"} },
    ['BST'] = { weapon = "Axe", ws_priority = {"Blitz", "Ruinator", "Decimation", "Cloudsplitter", "Raging Axe", "Smash Axe", "Gale Axe", "Spinning Axe", "Bora Axe"} },
    ['BRD'] = { weapon = "Dagger", ws_priority = {"Ruthless Stroke", "Rudra's Storm", "Mordant Rime", "Aeolian Edge"} },
    ['PUP'] = { weapon = "Hand-to-Hand", ws_priority = {"Maru Kala", "Victory Smite", "String Shredder", "Bone Crusher", "Armor Shatterer"} },
    ['SCH'] = { weapon = "Staff", ws_priority = {"Oshala", "Garland of Bliss", "Myrkr", "Cataclysm", "Shell Crusher", "Full Swing", "Gate of Tartarus"} },
    ['GEO'] = { weapon = "Club", ws_priority = {"Dagda", "Black Halo", "Realmrazer", "Flash Nova", "Skullbreaker", "True Strike"} },
    ['WHM'] = { weapon = "Club", ws_priority = {"Dagda", "Hexa Strike", "Black Halo", "Realmrazer", "Skullbreaker", "True Strike"} },
    ['BLM'] = { weapon = "Staff", ws_priority = {"Oshala", "Vidohunir", "Myrkr", "Cataclysm", "Shell Crusher", "Full Swing", "Gate of Tartarus"} },
    ['SMN'] = { weapon = "Staff", ws_priority = {"Volt Strike", "Flaming Crush", "Predator Claws", "Garland of Bliss", "Shell Crusher", "Full Swing", "Gate of Tartarus"} }
}

local settings = config.load(defaults)

-- Clamp a numeric setting to its range. Anything that is not a number (text, nil, NaN) goes back to the default
local DEFAULT_WAIT_DELAY, DEFAULT_MIN_TP = 1.2, 1000
local function clamp_setting(v, lo, hi, default)
    local n = tonumber(v)
    if not n or n ~= n then return default end
    if n < lo then return lo elseif n > hi then return hi end
    return n
end
local function clamp_wait_delay(v) return clamp_setting(v, 1.0, 10.0, DEFAULT_WAIT_DELAY) end
local function clamp_min_tp(v) return clamp_setting(v, 1000, 3000, DEFAULT_MIN_TP) end
-- One table for the cancel, the limits and the area-sphere hold (the main chunk is close to Lua 5.1's limit of 200 locals).
-- Made here because the settings clamp below uses it; most of its contents are added further down
local limit = {}
-- Area-sphere hold seconds: 0-60 (0 = off). Anything that is not a number (text, nil, NaN, a table) or is negative goes back
-- to the default of 20 s, not to 0 (off). Above 60 becomes 60. config reads the settings.xml value as a number: text that is
-- not decimal is read as hex (e.g. abc is 2748, so the hold becomes 60 s). Text that is not hex either (e.g. zz) leaves
-- config's default of 20
limit.SPHERE_DEFAULT_SEC = 20
function limit.clamp_sphere_hold(v)
    if type(v) ~= "number" or v ~= v or v < 0 then return limit.SPHERE_DEFAULT_SEC end
    if v > 60 then return 60 end
    return v
end

-- Fix ranges and types after every load (at start and whenever config re-reads settings.xml)
local function sanitize_settings()
    settings.wait_delay = clamp_wait_delay(settings.wait_delay)
    settings.min_tp = clamp_min_tp(settings.min_tp)
    settings.sphere_hold_sec = limit.clamp_sphere_hold(settings.sphere_hold_sec)
end
sanitize_settings()
if config.register then config.register(settings, sanitize_settings) end

-- Color code decoration (DirectWrite UTF-8)
local function color_text(str, r, g, b)
    return string.format("\\cs(%d,%d,%d)%s\\cr",safe_num(r, 255), safe_num(g, 255), safe_num(b, 255), tostring(str or ""))
end

-- -----------------------------------------------------------------------------
-- Logging (omnichain_debug.log)
--   - Lines are buffered in memory and written in batches every few seconds (avoids opening/closing the file each time)
--   - Past 1 MB the log is moved to omnichain_debug.old.log
--   - ERROR / WARN are also shown in chat immediately (identical messages are grouped for 10 s)
--   - Recent events are also kept in memory and can be shown with //omni log tail
-- -----------------------------------------------------------------------------
local log_file_path = windower.addon_path .. "omnichain_debug.log"
local old_log_path  = windower.addon_path .. "omnichain_debug.old.log"
local LOG_MAX_BYTES = 1024 * 1024
local LOG_FLUSH_SEC = 2.0
local RECENT_MAX    = 200
local THROTTLE_MAX  = 200

local monitor = {
    buffer = {},          -- lines not yet written to the file
    last_flush = 0,
    recent = {},          -- recent events {time, level, cat, msg}
    counts = {ERROR = 0, WARN = 0, INFO = 0},
    throttle = {},        -- chat throttling: key -> {time, suppressed}
}

local LEVEL_CHAT_COLORS = {ERROR = 167, WARN = 159}

-- Most lines kept in memory while the file cannot be written (past this, the older half is dropped and the count is logged once writing works again)
local LOG_BUFFER_MAX = 1000
-- After the log file fails to open, do not try again for this many seconds (a failing open on every line would stall the game)
local LOG_RETRY_SEC = 30

local function push_log_line(line)
    local buf = monitor.buffer
    if #buf >= LOG_BUFFER_MAX then
        local keep, half = {}, math.floor(LOG_BUFFER_MAX / 2)
        for i = #buf - half + 1, #buf do keep[#keep + 1] = buf[i] end
        monitor.dropped = (monitor.dropped or 0) + (#buf - half)
        monitor.buffer = keep
        buf = keep
    end
    buf[#buf + 1] = line
end

local function flush_log(force)
    local buf = monitor.buffer
    local clock = os.clock()
    monitor.last_flush = clock
    if #buf == 0 then return end
    if not settings.debug_logging then
        monitor.buffer = {}
        return
    end
    if clock < (monitor.open_retry_at or 0) then return end
    local f = io.open(log_file_path, "a")
    if not f then
        monitor.open_retry_at = clock + LOG_RETRY_SEC
        return
    end
    monitor.open_retry_at = nil
    if (monitor.dropped or 0) > 0 then
        f:write(string.format("[%s] [WARN] [LOG] dropped %d lines that piled up while the log file could not be written", os.date("%Y-%m-%d %H:%M:%S"), monitor.dropped), "\n")
        monitor.dropped = 0
    end
    f:write(table.concat(buf, "\n"), "\n")
    local size = f:seek("end") or 0
    f:close()
    monitor.buffer = {}
    if size > LOG_MAX_BYTES then
        os.remove(old_log_path)
        os.rename(log_file_path, old_log_path)
    end
end

-- Trim a UTF-8 string by characters (keeps an overlay line short)
local function utf8_trim(str, max_chars)
    local count, out = 0, {}
    for ch in str:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        count = count + 1
        if count > max_chars then
            out[#out + 1] = "…"
            break
        end
        out[#out + 1] = ch
    end
    return table.concat(out)
end

local function log_event(level, category, message)
    level = level or "INFO"
    category = tostring(category)
    message = tostring(message)
    monitor.counts[level] = (monitor.counts[level] or 0) + 1

    local is_alert = (level == "ERROR" or level == "WARN")
    if is_alert then
        -- If the same message repeats within 10 s, skip both log and chat and attach the count next time
        local key = level .. category .. message
        local t = monitor.throttle[key]
        local clock = os.clock()
        if t and clock - t.time < 10 then
            t.suppressed = t.suppressed + 1
            return false
        end
        if t and t.suppressed > 0 then
            message = message .. string.format(" (%d more in the last 10 s)", t.suppressed)
        end
        if not t then
            -- Keys grow with each distinct message, so rebuild past the limit (only the throttle history is lost)
            monitor.throttle_n = (monitor.throttle_n or 0) + 1
            if monitor.throttle_n > THROTTLE_MAX then
                monitor.throttle = {}
                monitor.throttle_n = 1
            end
        end
        monitor.throttle[key] = {time = clock, suppressed = 0}
    end

    push_log_line(string.format("[%s] [%s] [%s] %s", os.date("%Y-%m-%d %H:%M:%S"), level, category, message))

    local recent = monitor.recent
    recent[#recent + 1] = {time = os.date("%H:%M:%S"), level = level, cat = category, msg = message}
    if #recent > RECENT_MAX then table.remove(recent, 1) end

    if is_alert then
        -- Flush error-level entries immediately so the cause is not lost
        flush_log(true)
        chat_msg(string.format("[OmniChain:%s] %s: %s", level, category, utf8_trim(message, 120)), LEVEL_CHAT_COLORS[level])
    elseif #monitor.buffer >= 50 then
        flush_log(true)
    end
    return true
end

-- Backwards-compatible call (INFO)
local function log_debug(category, message)
    log_event("INFO", category, message)
end

-- Wrap event handlers in xpcall and log errors with their stack trace
local traceback = (debug and debug.traceback) or tostring
local function guarded(name, fn)
    return function(...)
        local args, n = {...}, select("#", ...)
        local ok, err = xpcall(function() return fn(unpack(args, 1, n)) end, traceback)
        if not ok then
            local first_line = tostring(err):match("^[^\n]*") or tostring(err)
            -- Keep the trace in the file only (so it does not flood chat)
            if log_event("ERROR", name, first_line) then
                push_log_line(tostring(err))
                flush_log(true)
            end
        end
    end
end

-- For events without arguments (prerender): avoids creating a table and closures every frame
local function guarded0(name, fn)
    return function()
        local ok, err = xpcall(fn, traceback)
        if not ok and log_event("ERROR", name, tostring(err):match("^[^\n]*") or tostring(err)) then
            push_log_line(tostring(err))
            flush_log(true)
        end
    end
end

-- Action message ID -> failure reason (main ones, in short English)
local FAIL_MESSAGES = {
    [4]   = "target out of range",
    [5]   = "cannot see target",
    [12]  = "claimed by someone else",
    [71]  = "cannot perform that action",
    [78]  = "target too far away",
    [89]  = "cannot use weapon skills",
    [90]  = "cannot use weapon skills",
    [190] = "cannot use that WS (wrong weapon / not learned)",
    [191] = "cannot use weapon skills in this state",
    [192] = "not enough TP",
    [193] = "cannot use on that target",
    [216] = "no ranged weapon equipped",
    [217] = "cannot see target",
    [218] = "moved and lost the stance",
    [219] = "cannot see target",
    [316] = "cannot use in this area",
    [328] = "target too far away",
    [446] = "invalid target",
}


-- Normalize the WS priority list to an array of strings (an invalid type becomes an empty array)
-- Entries of settings.xml <1>...<n> beyond the defaults stay as string keys such as "5", so convert them to numbers and re-sort
local function sanitize_ws_list(list)
    local result = {}
    if type(list) ~= "table" then return result end
    local indexed = {}
    for k, name in pairs(list) do
        local idx = tonumber(k)
        if idx and type(name) == "string" and name ~= "" then
            table.insert(indexed, {idx = idx, name = name})
        end
    end
    table.sort(indexed, function(a, b) return a.idx < b.idx end)
    for _, item in ipairs(indexed) do
        table.insert(result, item.name)
    end
    return result
end

-- Apply the JSON contents. Each field is type-checked; entries of the wrong shape are skipped
-- (returns the number of skipped profiles)
local function apply_json_config(obj)
    if obj.min_tp ~= nil then
        settings.min_tp = clamp_min_tp(obj.min_tp)
    end
    if obj.wait_delay ~= nil then
        settings.wait_delay = clamp_wait_delay(obj.wait_delay)
    end
    local skipped = 0
    if type(obj.profiles) == "table" then
        for job, data in pairs(obj.profiles) do
            local weapon = type(data) == "table" and data.weapon or nil
            local ws_list = type(data) == "table" and sanitize_ws_list(data.ws_priority) or {}
            if type(job) == "string" and type(weapon) == "string" and weapon ~= "" and #ws_list > 0 then
                profiles[job] = {
                    weapon = weapon,
                    ws_priority = ws_list,
                    opener_only = data.opener_only == true
                }
            else
                skipped = skipped + 1
            end
        end
    end
    return skipped
end

-- Auto-load the file exported by the Web Config Editor (omnichain_config.json)
-- Returns: "ok", path read / "none" (no file) / "error", reason
local function load_external_json_config()
    local json_paths = {
        windower.addon_path .. "omnichain_config.json",
        windower.addon_path .. "data/omnichain_config.json",
    }

    local last_err
    for _, path in ipairs(json_paths) do
        local f = io.open(path, "r")
        if f then
            local content = f:read("*all")
            f:close()
            if content and content ~= "" then
                local jok, json = pcall(require, "json")
                if not (jok and type(json) == "table" and json.parse) then
                    log_event("WARN", "CONFIG", "Could not load the json library: " .. path)
                    return "error", "could not load the json library"
                end
                -- Windower's libs/json.lua uses parse, not decode (on failure: nil, error text)
                local parse_ok, res_obj, parse_err = pcall(json.parse, content)
                if not parse_ok or type(res_obj) ~= "table" then
                    last_err = string.format("%s: %s", path, tostring(parse_ok and parse_err or res_obj))
                    log_event("WARN", "CONFIG", "JSON parse failed (" .. last_err .. ")")
                else
                    local apply_ok, skipped = pcall(apply_json_config, res_obj)
                    if not apply_ok then
                        last_err = string.format("%s: %s", path, tostring(skipped))
                        log_event("WARN", "CONFIG", "Could not apply the JSON config (" .. last_err .. ")")
                        return "error", last_err
                    end
                    if skipped > 0 then
                        log_event("WARN", "CONFIG", string.format("Skipped %d malformed entries under profiles (%s)", skipped, path))
                    end
                    log_debug("CONFIG", "Loaded external JSON config successfully from: " .. path)
                    return "ok", path
                end
            end
        end
    end
    if last_err then return "error", last_err end
    return "none"
end

local state = {
    active_job = "WAR",
    active_weapon = "Great Axe",
    ws_priority = {"Disaster", "Upheaval", "Ukko's Fury"},

    sc_active = false,
    sc_property = nil,   -- for display (e.g. "Fragmentation/Scission")
    sc_props = nil,      -- property array used for matching (opener WS: {A1, A2, A3}; after a chain: {the chain that occurred})
    sc_expiration = 0,
    sc_starter = "",
    sc_target = nil,        -- ID of the enemy that has the skillchain (not treated as a window while fighting a different enemy)
    sc_start_time = 0,      -- time the opener/chain WS landed (start of the manual wait)
    sc_step = 0,            -- number of chains in the current window (opener = 0); the window gets shorter as it grows
    sc_aeonic = false,      -- whether the opener of the current window is your own aeonic WS (with the Light/Darkness aftermath property)
    last_chain_name = nil,  -- so the same chain is not handled twice (packet and chat)
    last_chain_time = 0,
    last_packet_sc_time = -100,  -- time the chain state was last updated from a packet (stops late chat lines from overwriting it)

    last_ws_time = 0,
    pending_ws = nil,       -- waiting for the result of an auto-executed WS {name, time, tp}
    player_id = nil,

    solos = {},             -- trusts waiting on a solo chain: [trust ID] = {name = display name, ability = trigger, until_time = deadline, count = WS count}
                            -- several can exist at once if you have several trusts; auto WS stays stopped while any remains

    ws_fail_count = 0,      -- how many auto WS in a row the game refused (0x029 failure messages); reset by a WS going off or //omni on
    ws_fail_until = 0,      -- after a refusal, send nothing until this time
    auto_halted = false,    -- auto WS is stopped after too many refusals in a row (//omni on resumes)

    gen = 0,                -- generation number. Bumped by OFF, disengaging, a target change, a job change, incapacitation, zoning, etc. so stale pending results are never used
    run_count = 0,          -- auto /ws sent in the current chain (limit AUTO_MAX_WS)
    run_start = nil,        -- time of the first auto /ws of the current chain (limit AUTO_MAX_SEC)
    run_idle_since = nil,   -- time the window and the pending WS were gone (limit.run_idle resets the per-chain count after RUN_RESET_SEC seconds)
    last_sent = nil,        -- the last auto /ws sent {id, target, time, done} (a landing that arrives after the pending wait still counts as the auto WS)
                            -- done: its landing, a refusal or an interrupted stance has arrived (the result is known)
    sent_hold_until = 0,    -- if a cancel left a /ws without a result, send nothing until this time (limit.LAND_SEC seconds after it was sent)
    own_out_id = nil,       -- WS ID of the auto /ws just sent (so its outgoing 0x01A counts once as our own send)
    own_out_target = nil,   -- target id of the auto /ws just sent (the same WS used by hand on another target counts as manual)
    own_out_until = 0,      -- an outgoing 0x01A for the same WS before this time is treated as the auto send
    manual_ws_until = 0,    -- after seeing a manual WS (an outgoing 0x01A that is not the auto send), send no auto WS until this time
    sphere_hold_until = 0,  -- after reading the area-sphere warning (the Moogle's line or the boss's SP move ID), send no auto WS until this time (0 = no hold)
    sphere_line_time = nil, -- when the last warning was accepted (a repeat within 1 s does not extend the hold)
}

-- The player and <t> for the current frame. Read once at the start of prerender and dropped at the end of the frame.
-- Outside a frame (packets, commands) they are read fresh each time
local frame = {active = false, player = nil, t = nil, me = nil}
local function cur_player()
    if frame.active then return frame.player end
    return windower.ffxi.get_player()
end
local function cur_target()
    if frame.active then return frame.t end
    return windower.ffxi.get_mob_by_target('t')
end
local function cur_me()
    if not frame.active then return windower.ffxi.get_mob_by_target('me') end
    if frame.me == nil then frame.me = windower.ffxi.get_mob_by_target('me') or false end
    return frame.me or nil
end

-- The WS choice is reused for CHOICE_CACHE_SEC seconds (shared by the auto WS and the HUD).
-- Bumping choice_version (packets, commands, chain state changes) forces a fresh choice
local CHOICE_CACHE_SEC = 0.15
local choice_version = 0
local function invalidate_choice() choice_version = choice_version + 1 end

local function clear_sc_state()
    state.sc_active = false
    state.sc_property = nil
    state.sc_props = nil
    state.sc_expiration = 0
    state.sc_starter = ""
    state.sc_target = nil
    state.sc_step = 0
    state.sc_aeonic = false
    state.sc_self_only = false
    choice_version = choice_version + 1   -- drop the cached WS choice
end

-- Cancel the reservation and the chain progress (OFF, disengaging, a target change, a job change, incapacitation,
-- a failure (refusal, interrupted stance, no response), a limit, zoning, logout, unload). The generation number is bumped, so a pending result from before the cancel is ignored when it arrives.
-- The per-chain count (run_count) and the total record are not reset here (//omni on, zoning, logout and unload reset them;
-- limit.run_idle also resets the per-chain count when a fight ends)
-- The back-off after a refusal (ws_fail_until) is not reset here either, so a target change, disengaging or incapacitation
-- does not skip it (only a WS that goes off, //omni on, zoning, logout and unload reset it)
-- If the result of the last /ws sent has not arrived yet, nothing is sent until limit.LAND_SEC seconds after it was sent (sent_hold_until)
-- (the main chunk is close to Lua 5.1's limit of 200 locals, so the cancel and the limits live in one table, limit;
-- the table is made next to the settings clamp)
function limit.cancel()
    state.gen = safe_num(state.gen, 0) + 1
    local sent = state.last_sent
    if type(sent) == "table" and not sent.done then
        local hold = safe_num(sent.time, 0) + safe_num(limit.LAND_SEC, 8.0)
        if hold > safe_num(state.sent_hold_until, 0) then state.sent_hold_until = hold end
    end
    clear_sc_state()
    state.pending_ws = nil
    state.chainbound = nil
    state.solos = {}
    state.solo_done = nil
    state.unseen_until = 0
    state.last_chain_name = nil
    state.last_chain_time = 0
    state.sc_last_kind = nil
    state.text_sc_name = nil
    state.text_sc_until = 0
end
-- The result of the last /ws sent (landing, refusal or interrupted stance) has arrived: the hold after a cancel (sent_hold_until) is not needed
function limit.sent_done()
    local sent = state.last_sent
    if type(sent) == "table" then sent.done = true end
    state.sent_hold_until = 0
end

-- Clear an expired chain window. Runs at the start of every frame and whenever a chain result arrives,
-- whether or not the HUD is shown (with the HUD hidden, an expired window used to linger and feed stale properties into the next chain)
local function expire_sc_window(now)
    if state.sc_active and not safe_lt(now, safe_num(state.sc_expiration, 0)) then
        clear_sc_state()
    end
end

-- Warn if an auto-executed WS gets no response within this many seconds (wrong WS name, not learned, input error, etc.).
-- Until then the WS counts as pending and no other WS is sent
local PENDING_WS_TIMEOUT = 4.0

-- When the game keeps refusing the auto WS: wait the listed seconds after refusals 1-4, and stop on refusal WS_FAIL_LIMIT
local WS_FAIL_LIMIT = 5
local WS_FAIL_BACKOFF = {2, 4, 8, 16}
-- Statuses that leave you unable to act (res/buffs.lua: sleep 2, 19 / petrification 7 / stun 10 / charm 14, 17 / amnesia 16 / terror 28).
-- Nothing is sent while one of them is on
local INCAPACITATED_BUFFS = {[2] = true, [19] = true, [7] = true, [10] = true, [14] = true, [17] = true, [16] = true, [28] = true}

local function is_incapacitated(player)
    local buffs = player and player.buffs
    if type(buffs) ~= "table" then return false end
    for _, b in pairs(buffs) do
        if INCAPACITATED_BUFFS[b] then return true end
    end
    return false
end

local function reset_ws_fail()
    state.ws_fail_count = 0
    state.ws_fail_until = 0
    state.auto_halted = false
end

-- The auto WS failed (refused, stance interrupted or no response): cancel the reservation and the chain progress (limit.cancel),
-- back off, and after WS_FAIL_LIMIT failures in a row stop sending and say so.
-- The cancel covers the same things as limit.cancel: the chain window, the pending result, chainbound and the trusts' solo-chain waits (solos).
-- A window, chainbound or solo-chain wait that a party member started while the result was pending is cleared too
-- (by design, following the rule "a failure cancels the reservation and the progress"; it never makes more WS go out).
-- After the cancel the next send is an opener, but that send does not restart the per-chain count (fail_keep_run), so failures
-- in between cannot dodge the per-chain limit
local function note_ws_fail(now, reason)
    state.ws_fail_count = safe_num(state.ws_fail_count, 0) + 1
    local n = state.ws_fail_count
    limit.cancel()
    state.fail_keep_run = true
    if n >= WS_FAIL_LIMIT then
        state.auto_halted = true
        log_event("WARN", "WS_HALT", string.format("The auto WS failed %d times in a row (last: %s). Auto WS stopped", n, tostring(reason)))
        chat_msg(string.format("[OmniChain] Auto WS stopped: the auto WS failed %d times in a row (last: %s). //omni on resumes it.", n, tostring(reason)), 167)
    else
        state.ws_fail_until = now + WS_FAIL_BACKOFF[n]
    end
end

-- Limits on auto WS (the same idea as AutoSkillchain; only the total count is higher than in AutoSkillchain):
--   one chain sends at most AUTO_MAX_WS /ws within AUTO_MAX_SEC seconds; in total at most AUTO_TOTAL_MAX /ws per AUTO_TOTAL_SEC seconds.
--   The per-chain count starts with the first auto /ws and is reset when your own manual opener (not an auto WS) arrives after
--   the chain window closed, when a fight ends (limit.run_idle: disengaging, the enemy defeated, RUN_RESET_SEC seconds after the window closed),
--   when an auto opener is sent (an auto /ws with no window and no Chainbound),
--   and by //omni on, zoning, logout and unload. A party member's opener arriving does not reset it.
--   The total record is cleared by //omni on (only when going from OFF to ON). Reaching a limit stops auto WS and cancels the progress (//omni on resumes)
limit.AUTO_MAX_WS = 6
limit.AUTO_MAX_SEC = 75
limit.AUTO_TOTAL_MAX = 36
limit.AUTO_TOTAL_SEC = 300
limit.total = {}   -- times of the auto /ws sent
limit.VERIFY_HOLD_SEC = 0.5   -- when the check right before sending fails, look again after this many seconds (do not re-read gear and the WS list every frame)
limit.LAND_SEC = 8.0          -- your own same WS arriving within this many seconds of sending still counts as the auto WS, even after the pending wait ended
function limit.total_clear()
    local total = limit.total
    for i = #total, 1, -1 do total[i] = nil end
end
function limit.total_count(now)
    local total = limit.total
    for i = #total, 1, -1 do
        if now - total[i] >= limit.AUTO_TOTAL_SEC then table.remove(total, i) end
    end
    return #total
end
function limit.reset_run()
    state.fail_keep_run = nil   -- once the count restarts, the mark left by a failure is not needed
    state.run_count = 0
    state.run_start = nil
    state.run_idle_since = nil
end
-- When a fight ends, reset the per-chain count (run_count, run_start). The total record (limit.total) is not reset
--   Reset at once: you disengage, the enemy on <t> is defeated, or <t> changes and the previous enemy is defeated (or gone)
--   Reset after RUN_RESET_SEC seconds: no chain window, no Chainbound, no pending WS and no /ws without a result for that long
--   (so the count is reset after the window expires and before the next auto opener; while a window or a pending WS exists it keeps counting)
-- Called every frame. Does nothing before counting starts (run_start is nil)
limit.RUN_RESET_SEC = 3.0
function limit.dead_mob(m)
    return type(m) == "table" and type(m.hpp) == "number" and m.hpp <= 0
end
function limit.run_idle(now, engaged, t, prev_t_id)
    if not state.run_start then
        state.run_idle_since = nil
        return
    end
    local ended = not engaged or limit.dead_mob(t)
    if not ended and prev_t_id ~= nil and (t and t.id) ~= prev_t_id then
        -- look up the previous enemy only when <t> changed (not every frame)
        local old = windower.ffxi.get_mob_by_id(prev_t_id)
        ended = old == nil or limit.dead_mob(old)
    end
    if ended then
        limit.reset_run()
        return
    end
    local pending = state.pending_ws
    local sent = state.last_sent
    local cb = state.chainbound
    if state.sc_active
        or (type(cb) == "table" and now < safe_num(cb.until_time, 0))
        or (type(pending) == "table" and now - safe_num(pending.time, now) <= PENDING_WS_TIMEOUT)
        or (type(sent) == "table" and not sent.done and now - safe_num(sent.time, now) < safe_num(limit.LAND_SEC, 8.0))
        or now < safe_num(state.sent_hold_until, 0) then
        state.run_idle_since = nil
        return
    end
    local since = state.run_idle_since
    if type(since) ~= "number" or since ~= since or since > now then
        state.run_idle_since = now
    elseif now - since >= limit.RUN_RESET_SEC then
        limit.reset_run()
    end
end
-- If a limit is reached, stop and return true
function limit.reached(now)
    local msg
    if limit.total_count(now) >= limit.AUTO_TOTAL_MAX then
        msg = string.format("the total limit (%d times in %d s)", limit.AUTO_TOTAL_MAX, limit.AUTO_TOTAL_SEC)
    elseif state.run_start and (safe_num(state.run_count, 0) >= limit.AUTO_MAX_WS
        or now - safe_num(state.run_start, now) >= limit.AUTO_MAX_SEC) then
        msg = string.format("the per-chain limit (%d times / %d s)", limit.AUTO_MAX_WS, limit.AUTO_MAX_SEC)
    else
        return false
    end
    limit.cancel()
    state.auto_halted = true
    log_event("WARN", "WS_HALT", "Reached " .. msg .. ". Auto WS stopped")
    chat_msg(string.format("[OmniChain] Auto WS stopped: reached %s. //omni on resumes it.", msg), 167)
    return true
end

-- Is it in sc_dict? (find_ws_info also returns PUP / SMN moves, so check WEAPON_WS separately)
local function ws_in_dict(ws_name)
    for _, ws_list in pairs(sc_dict.WEAPON_WS) do
        for _, info in ipairs(ws_list) do
            if info.en == ws_name then return true end
        end
    end
    return sc_dict.PUP_WS_DATABASE[ws_name] ~= nil or sc_dict.SMN_BP_DATABASE[ws_name] ~= nil
end

-- WS name -> res WS ID
local ws_id_cache = {}
local function ws_id_by_name(ws_name)
    if ws_id_cache[ws_name] ~= nil then return ws_id_cache[ws_name] or nil end
    local found = false
    if res and res.weapon_skills then
        for id, ws in pairs(res.weapon_skills) do
            if ws.en == ws_name then found = id break end
        end
    end
    ws_id_cache[ws_name] = found
    return found or nil
end

-- Can the WS reach? Do not use it when out of range (it would just fail with "too far away").
-- Melee WS (range 2): when the distance shown by distanceplus is at most settings.ws_reach (default 3.5) (a rule of thumb from the author).
-- A big enemy (model_size above 2) widens the melee reach by the amount above 2.
-- Other ranges use the same formula as distanceplus: distance < enemy model_size + range x multiplier + your model_size (range index is res range)
local WS_RANGE_MULT = {
    [2] = 1.55, [3] = 1.490909, [4] = 1.44, [5] = 1.377778, [6] = 1.30, [7] = 1.15,
    [8] = 1.25, [9] = 1.377778, [10] = 1.45, [11] = 1.454545454545455, [12] = 1.666666666666667,
}
local WS_RANGE_MARGIN = 0.2   -- stay slightly inside the real reach so a late input at the boundary does not whiff
-- Returns: true if it reaches; otherwise false plus (distance, reach).
-- When the distance cannot be read (no target, distance is not a number, or no model_size for ranges other than 2) it returns false
-- (nothing is sent; the next frame looks again). When the range index is not in the table, it returns true as long as the distance is known
local function ws_in_range(ws_name)
    local t = cur_target()
    if not t or type(t.distance) ~= "number" then return false end
    local id = ws_id_by_name(ws_name)
    local ws = id and res and res.weapon_skills and res.weapon_skills[id]
    local mult = ws and WS_RANGE_MULT[ws.range]
    if not mult then return true end
    if ws.range == 2 then
        local melee_reach = safe_num(settings.ws_reach, 3.5)
        local d = math.sqrt(safe_num(t.distance, 0))
        -- A big enemy can be hit from farther away: widen the allowed distance by the amount its model_size is above 2
        -- (small and normal enemies keep the fixed value. 2026-10-24 Awoken Gorgimera: a manual WS landed at distance 4.5 but the fixed 3.5 stopped the auto WS)
        if t.model_size then
            local extra = safe_num(t.model_size, 0) - 2.0
            if extra > 0 then melee_reach = melee_reach + extra end
        end
        return d <= melee_reach, d, melee_reach
    end
    local me = cur_me() or cur_player()
    if type(t.model_size) ~= "number" then return false end
    local my_size = safe_num(me and me.model_size, 0)
    local dist = math.sqrt(safe_num(t.distance, 0))
    local reach = t.model_size + ws.range * mult + my_size - WS_RANGE_MARGIN
    return dist <= reach, dist, reach
end

-- English names of the equipped weapons {main=, range=}. The HUD calls this every frame, so reuse the result for 1 s
local weapon_cache = {time = -1, names = {}}
local function equipped_weapon_names()
    local now = os.clock()
    if now - weapon_cache.time < 1.0 then return weapon_cache.names end
    weapon_cache.time = now
    local names = {}
    local eq = windower.ffxi.get_items('equipment')
    for _, slot in ipairs({'main', 'range'}) do
        local index = eq and eq[slot]
        if index and index ~= 0 then
            local item = windower.ffxi.get_items(eq[slot .. '_bag'], index)
            local info = item and res and res.items and res.items[item.id]
            names[slot] = info and info.en
        end
    end
    weapon_cache.names = names
    return names
end

-- Level 3 property (Light/Darkness) added when you use that WS with an aeonic weapon. nil if not applicable
-- Your WS is used at TP 1000+, so aftermath is always on at that point (the property also applies to the WS that triggers it)
local function aeonic_prop(ws_en)
    local a = ws_en and sc_dict.AEONIC_WS[ws_en]
    if not a then return nil end
    return equipped_weapon_names()[a.slot or 'main'] == a.weapon and a.prop or nil
end

-- Is aftermath active? (Aftermath: Lv.1-3 = 270-272, Aftermath = 273)
local function has_aftermath()
    local player = cur_player()
    for _, buff in pairs(player and player.buffs or {}) do
        if buff >= 270 and buff <= 273 then return true end
    end
    return false
end

-- Set of WS IDs usable with the current weapon/job (windower.ffxi.get_abilities)
-- The HUD calls this every frame, so reuse the result for 1 s. nil if the list cannot be read or is empty (= do not judge)
local usable_cache = {time = -1, set = nil}
local function usable_ws_set()
    local now = os.clock()
    if now - usable_cache.time < 1.0 then return usable_cache.set end
    usable_cache.time = now
    usable_cache.set = nil
    local ok, abil = pcall(windower.ffxi.get_abilities)
    if not ok or type(abil) ~= "table" or type(abil.weapon_skills) ~= "table" then return nil end
    local set = {}
    for k, v in pairs(abil.weapon_skills) do
        if type(v) == "number" then set[v] = true elseif v == true then set[k] = true end
    end
    if next(set) == nil then return nil end
    usable_cache.set = set
    return set
end

-- Warn if a WS is not in the dictionary / not in res / not usable right now (returns true if it can be sent with /ws).
-- Not being in the dictionary is only a warning and does not decide the send (as in v7.4.3). Such a WS is never picked to
-- continue a chain, for chainbound or for a toss, but it may be used as an opener, and as the top WS when nothing connects
-- in a window (auto_mode "flexible")
local function is_pet_skill(ws_name)
    return sc_dict.PUP_WS_DATABASE[ws_name] ~= nil or sc_dict.SMN_BP_DATABASE[ws_name] ~= nil
end

local function check_ws_usable(ws_name, category)
    if is_pet_skill(ws_name) then
        log_event("WARN", category, string.format("%s is a pet skill and cannot be used with /ws", ws_name))
        return false
    end
    local good = true
    if not ws_in_dict(ws_name) then
        log_event("WARN", category, string.format("WS not in sc_dict: %s (never picked to continue a chain; it may still be used as an opener or as the top WS when nothing connects)", ws_name))
    end
    local id = ws_id_by_name(ws_name)
    if not id then
        log_event("WARN", category, string.format("WS name not in res: %s (possible spelling difference)", ws_name))
        return false
    end
    local set = usable_ws_set()
    if set and not set[id] then
        log_event("WARN", category, string.format("WS not usable right now: %s (wrong weapon, not learned or not enough skill)", ws_name))
        good = false
    end
    return good
end

-- Check the whole priority list and report problem WS in one line
local function check_priority_list(silent_ok)
    local not_dict, not_res, not_usable, pet = {}, {}, {}, {}
    local set = usable_ws_set()
    for _, ws_name in ipairs(state.ws_priority or {}) do
        if is_pet_skill(ws_name) then
            table.insert(pet, ws_name)
        else
            if not ws_in_dict(ws_name) then table.insert(not_dict, ws_name) end
            local id = ws_id_by_name(ws_name)
            if not id then
                table.insert(not_res, ws_name)
            elseif set and not set[id] then
                table.insert(not_usable, ws_name)
            end
        end
    end
    local problems = 0
    if #pet > 0 then problems = problems + 1 log_event("WARN", "CHECK", "Pet skills cannot be used with /ws: " .. table.concat(pet, ", ")) end
    if #not_dict > 0 then problems = problems + 1 log_event("WARN", "CHECK", "WS not in sc_dict: " .. table.concat(not_dict, ", ")) end
    if #not_res > 0 then problems = problems + 1 log_event("WARN", "CHECK", "WS name not in res: " .. table.concat(not_res, ", ")) end
    if #not_usable > 0 then
        problems = problems + 1
        log_event("WARN", "CHECK", string.format("WS not usable on %s right now: %s", state.active_job, table.concat(not_usable, ", ")))
    end
    if problems == 0 and not silent_ok then
        log_event("INFO", "CHECK", string.format("All %d WS in the %s priority list are usable", #(state.ws_priority or {}), state.active_job))
    end
    return problems == 0
end

local hud = texts.new("", settings)
-- The last body and visibility set on the HUD (text / show / hide are skipped when nothing changed). nil = not set yet
local hud_cache = {text = nil, shown = nil}

-- Resize marker "◢": a separate text drawn over the HUD's bottom-right corner (no background, not movable)
local GRIP_COLOR     = {150, 150, 150}  -- normal
local GRIP_COLOR_HOT = {255, 220, 100}  -- cursor is on the corner / resizing
local grip = texts.new("◢", {
    pos = {x = 0, y = 0},
    text = {font = "Consolas", size = 10, alpha = 230, red = GRIP_COLOR[1], green = GRIP_COLOR[2], blue = GRIP_COLOR[3]},
    bg = {visible = false},
    flags = {draggable = false},
    padding = 0,
})
local grip_hot = false

-- Place the marker on the HUD's bottom-right corner (font size is proportional to the HUD)
local function update_grip()
    if not hud:visible() then
        grip:hide()
        return
    end
    local size = math.max(8, math.floor(safe_num(hud:size(), 11) * 0.9 + 0.5))
    if grip:size() ~= size then grip:size(size) end
    local c = grip_hot and GRIP_COLOR_HOT or GRIP_COLOR
    grip:color(c[1], c[2], c[3])
    local px, py = hud:pos()
    local w, h = hud:extents()
    local gw, gh = grip:extents()
    if px and py and w and h and gw and gh then
        grip:pos(px + w - gw, py + h - gh)
    end
    grip:show()
end

-- -----------------------------------------------------------------------------
-- HUD resizing (mouse): same controls as MBReadyTimer
--   - Wheel over the HUD: change the font size by 1
--   - Click and drag the bottom-right corner: resize (dragging elsewhere moves the HUD as before)
-- -----------------------------------------------------------------------------
local MOUSE_MOVE, MOUSE_LEFT_DOWN, MOUSE_LEFT_UP, MOUSE_WHEEL = 0, 1, 2, 10
local SIZE_MIN, SIZE_MAX = 6, 40
local RESIZE_HANDLE_PX = 18      -- area treated as the bottom-right corner (px)

local resize = nil               -- state while dragging to resize
-- The original "drag to move" setting. libs/texts draggable() writes settings.flags.draggable itself, so the original
-- value lives in this variable and is never confused with the temporary false used for the corner check.
-- When config re-reads settings.xml (login / logout), it is taken again from the re-read value
local move_allowed = settings.flags == nil or settings.flags.draggable ~= false
if config.register then
    config.register(settings, function()
        move_allowed = settings.flags == nil or settings.flags.draggable ~= false
        resize = nil
        hud_cache.text, hud_cache.shown = nil, nil   -- the reload may rebuild the text object, so set it again next frame
    end)
end

local function current_size()
    return safe_num(hud:size(), safe_num(settings.text and settings.text.size, 11))
end

local function set_size(size)
    size = math.max(SIZE_MIN, math.min(SIZE_MAX, math.floor(size + 0.5)))
    if size ~= current_size() then
        hud:size(size)
    end
    return size
end

-- Every settings save goes through here: restore the "drag to move" paused for the corner check, then save
-- (saving without restoring left draggable = false in data/settings.xml and the HUD could no longer be moved)
local function save_settings()
    if hud:draggable() ~= move_allowed then hud:draggable(move_allowed) end
    config.save(settings)
end

local function in_resize_handle(x, y)
    if not hud:visible() then return false end
    local px, py = hud:pos()
    local w, h = hud:extents()
    if not (px and py and w and h) then return false end
    return x >= px + w - RESIZE_HANDLE_PX and x <= px + w and y >= py + h - RESIZE_HANDLE_PX and y <= py + h
end

-- Returns the JSON load result (same as load_external_json_config: "ok", path / "none" / "error", reason)
local function update_job_profile()
    -- Set your own ID before touching the JSON, so your own actions and refusals are still recognized if the JSON breaks
    local player = cur_player()
    if player then state.player_id = player.id end
    invalidate_choice()

    local ok, status, detail = pcall(load_external_json_config)
    if not ok then
        status, detail = "error", tostring(status)
        log_event("WARN", "CONFIG", "Error while loading the JSON config: " .. detail)
    end

    if player and player.main_job then
        state.active_job = tostring(player.main_job)
        local prof = profiles[state.active_job]
        if prof then
            state.active_weapon = tostring(prof.weapon or "Sword")
            state.ws_priority = sanitize_ws_list(prof.ws_priority)
            state.opener_only = prof.opener_only == true
        else
            -- A job with no profile: do not keep the previous job's weapon and list (nothing is used)
            state.active_weapon = ""
            state.ws_priority = {}
            state.opener_only = false
        end
        log_debug("PROFILE", string.format("Job Profile Updated: %s (Weapon: %s)", state.active_job, state.active_weapon))
    end
    return status, detail
end

-- Does the WS only target yourself? True when res "targets" lacks Enemy (0x20): Dagan, Myrkr, Starlight, Moonlight.
-- Raw res data holds a number; after libs/resources it is a set ({Enemy = true}), so both forms are handled
local function is_self_target_ws(id)
    local ws = id and res and res.weapon_skills and res.weapon_skills[id]
    local tg = ws and ws.targets
    if type(tg) == "number" then return math.floor(tg / 32) % 2 == 0 end
    if type(tg) == "table" then return rawget(tg, "Enemy") == nil end
    return false
end

-- Can it be used with /ws right now? Excludes pet skills, names not in res, WS not learned / wrong weapon,
-- and self-target WS (they cannot be used on <t>)
local function is_executable_ws(ws_name, usable)
    if is_pet_skill(ws_name) then return false end
    local id = ws_id_by_name(ws_name)
    if not id then return not (res and res.weapon_skills) end
    if is_self_target_ws(id) then return false end
    return usable == nil or usable[id] == true
end

-- Chain window length. Manual mode waits for others to interject, so it looks up to the full window (BG-Wiki: 3-10 s)
-- Estimated chain window (from the previous hit until it closes). It shrinks by 1 s with each chain.
-- Measured (2026-10-10 to 11; seconds from the WS packet to the next auto WS input; it lands about 0.7 s later):
--   chained even 9-12 s after the opener / 6.0 s after the 2nd chain = chained / 6.0 s after the 3rd = sometimes /
--   6.0 s after the 4th or 5th = did not chain
--   5.8 s after the 3rd (margin 1.2 s) = 2 chained, 1 did not (evening of 2026-10-11) -> margin widened to 2.0 s
local SC_WINDOW_BASE_SEC = 10.0
local SC_WINDOW_MIN_SEC = 4.0
local SC_LAND_MARGIN_SEC = 2.0   -- margin between input and landing (input this many seconds before the window closes)
local SC_OPEN_SEC = 3.3          -- seconds until the window opens (a WS earlier than this does not chain)
-- Level 3 chain produced from a Level 2 property when used on chainbound (BG-Wiki Chainbound; Fragmentation stays Fragmentation)
local CHAINBOUND_LV3 = {["Fusion"] = "Light", ["Gravitation"] = "Darkness", ["Distortion"] = "Darkness"}
local function sc_window_sec(step)
    return math.max(SC_WINDOW_MIN_SEC, SC_WINDOW_BASE_SEC - safe_num(step, 0))
end

-- Seconds left until the auto WS may be used.
--   - The window opens about 3 s after the previous hit. A WS earlier than that does not chain and also cuts the other player's chain
--     (measured 2026-10-10: a Kasha used 2.9 s after Iroha's Gachirin did not chain; 3.0-3.1 s did).
--   - While a window exists, wait min_follow seconds. When the window has shrunk after several chains,
--     shorten the wait so it lands before the window closes (minimum SC_OPEN_SEC).
--   - Manual mode also waits follow_wait seconds (until 2 s before the window closes).
--   - Right after Chainbound the same wait applies. A WS landing within 2 s of the chainbound did not chain and the chainbound was lost
--     (measured 2026-10-11: 4 of 4 did not chain at 0-2 s, 2 of 2 chained at 3 s).
-- If every WS since the opener is yours (no one else's chain) and TP is full (3000),
-- use it as soon as the window opens (SC_OPEN_SEC) without waiting min_follow: no one needs to be waited for and no TP is wasted
local FULL_TP = 3000
local MIN_FOLLOW_FLOOR = 4.0   -- lower limit of min_follow (set by the author)
local function open_sec()
    local k = state.sc_last_kind
    if k == "self" or k == "player" then
        return math.min(SC_OPEN_SEC, math.max(0, safe_num(settings.open_player, SC_OPEN_SEC)))
    end
    return SC_OPEN_SEC
end
local function follow_wait_left(now, tp)
    local left = 0
    local cb = state.chainbound
    if cb and safe_lt(now, safe_num(cb.until_time, 0)) then
        -- Only a chainbound on your current enemy counts (one on another enemy does not shorten the wait).
        -- That chainbound is waiting for an ally's WS (Ark GK also uses it when out of TP), so use it as soon as the window opens.
        -- The earlier chain state was overwritten by the chainbound, so in that case the chain-window wait is not used
        local ct = cur_target()
        if ct and ct.id == cb.target then
            return math.max(0, safe_num(cb.start_time, 0) + SC_OPEN_SEC - now)
        end
    end
    local window_on_other = false
    if state.sc_active and state.sc_target then
        -- If the enemy with the skillchain differs from the current one (moved on to another enemy, etc.), do not wait for that chain
        local t = cur_target()
        window_on_other = t and t.id ~= state.sc_target or false
    end
    if state.sc_active and not window_on_other and safe_lt(now, safe_num(state.sc_expiration, 0)) then
        local window = sc_window_sec(state.sc_step)
        local wait = math.max(open_sec(), math.min(math.max(MIN_FOLLOW_FLOOR, safe_num(settings.min_follow, MIN_FOLLOW_FLOOR)), window - SC_LAND_MARGIN_SEC))
        if settings.start_mode == "manual" then
            wait = math.max(wait, math.min(safe_num(settings.follow_wait, 6.0), math.max(3.0, window - 2.0)))
        end
        if tp and state.sc_self_only and safe_gte(tp, FULL_TP) then wait = open_sec() end
        left = math.max(left, safe_num(state.sc_start_time, 0) + wait - now)
    end
    return math.max(0, left)
end

-- Seconds left until a trust's solo chain ends (0 if not waiting). Expired entries are cleaned up here
-- Returns: seconds left (for the trust that waits longest), and that trust's display name
local function solo_wait_left(now)
    if next(state.solos) == nil then return 0 end
    if settings.trust_solo == false then
        state.solos = {}
        return 0
    end
    local longest, name = 0, nil
    -- Drop the wait of a trust that is no longer in the party (released or defeated). The roster is checked once a second (not every frame)
    local roster = now - safe_num(state.solo_roster_time, -100) >= 1.0
    if roster then state.solo_roster_time = now end
    for actor_id, solo in pairs(state.solos) do
        local left = safe_num(solo.until_time, 0) - now
        local mob = roster and windower.ffxi.get_mob_by_id(actor_id)
        if roster and not (mob and (mob.in_party or mob.in_alliance)) then
            log_debug("TRUST_SOLO", string.format("Wait over: %s (not in the party)", tostring(solo.name)))
            state.solos[actor_id] = nil
        elseif left <= 0 then
            log_debug("TRUST_SOLO", string.format("Wait over: %s (%s)", solo.name,
                solo.count > 0 and string.format("no next WS after %d WS", solo.count) or "no WS came"))
            state.solos[actor_id] = nil
        elseif left > longest then
            longest, name = left, solo.name
        end
    end
    return longest, name
end

local function find_base_ws_from_priority()
    if not state.ws_priority or #state.ws_priority == 0 then return nil end

    local now = safe_num(os.clock(), 0)
    local sc_exp = safe_num(state.sc_expiration, 0)
    local is_sc_window = state.sc_active and safe_lt(now, sc_exp) and state.sc_property
    -- If the enemy with the skillchain differs from the current one (defeated and moved on, etc.), the chain cannot continue, so start from an opener
    if is_sc_window and state.sc_target then
        local t = cur_target()
        if t and t.id ~= state.sc_target then is_sc_window = false end
    end

    -- The top usable WS (used as the opener / continuation when there is no chain; a WS not in sc_dict counts too)
    local usable = usable_ws_set()
    local first_idx, first_ws
    for idx, ws_name in ipairs(state.ws_priority) do
        if is_executable_ws(ws_name, usable) then first_idx, first_ws = idx, ws_name break end
    end
    if not first_ws then return nil end

    -- Chainbound is on your enemy: the next WS chains regardless of the previous property.
    -- The result depends on the WS's property (BG-Wiki Chainbound): a WS with Light/Darkness = that Light/Darkness (ends there) /
    -- Fusion = Light; Gravitation, Distortion = Darkness (can be continued again) / Fragmentation = Fragmentation / Lv.1 = that property.
    -- Order: continuable Light/Darkness > final Light/Darkness > Lv.2 > Lv.1; ties go to the higher entry in the priority list
    local cb = state.chainbound
    if cb and safe_lt(now, safe_num(cb.until_time, 0)) then
        local t = cur_target()
        if t and t.id == cb.target then
            local aftermath = has_aftermath()
            local best
            for idx, ws_name in ipairs(state.ws_priority) do
                local info = is_executable_ws(ws_name, usable) and sc_dict.find_ws_info(ws_name, state.active_weapon)
                if info and info.sc and info.sc[1] then
                    local result, score   -- always set by one of the three branches below
                    local lv3 = aftermath and aeonic_prop(info.en)
                    for _, prop in ipairs(info.sc) do
                        if prop == "Light" or prop == "Darkness" then lv3 = lv3 or prop end
                    end
                    if lv3 then
                        result, score = lv3, 3
                    elseif CHAINBOUND_LV3[info.sc[1]] then
                        result, score = CHAINBOUND_LV3[info.sc[1]], 4
                    else
                        result = info.sc[1]
                        score = (sc_dict.SC_ELEMENTS[result] and sc_dict.SC_ELEMENTS[result].level or 1) >= 2 and 2 or 1
                    end
                    if not best or score > best.score then
                        best = {ws = ws_name, result = result, score = score, idx = idx}
                    end
                end
            end
            if best then
                return {
                    ws = best.ws,
                    result_sc = best.result,
                    priority = best.idx,
                    reason = string.format("P%d [chainbound -> %s (%s)]", best.idx, best.result, best.ws)
                }
            end
        end
    end

    if is_sc_window then
        -- opener_only: the first WS is for openers only. During a chain, look at the 2nd and later entries first and fall back to the first only if none connects
        -- The Light/Darkness of an aeonic WS exists only during aftermath. If aftermath is not active, do not count it.
        -- A chain that relies on aftermath is chosen in priority order only when continuing from your own aeonic WS (Tachi: Shoha -> Tachi: Shoha = Radiance).
        -- When closing a Light/Darkness from a trust or other player, or one made by a chain, prefer a WS that natively has Light/Darkness (Tachi: Fudo, etc.)
        local aftermath = has_aftermath()
        local fallback = nil
        for pass = 1, (state.opener_only and 2 or 1) do
            for priority_idx, ws_name in ipairs(state.ws_priority) do
                local skip = state.opener_only and pass == 1 and priority_idx == first_idx
                local ws_info = not skip and is_executable_ws(ws_name, usable) and sc_dict.find_ws_info(ws_name, state.active_weapon)
                local lv3 = ws_info and aftermath and aeonic_prop(ws_info.en)
                local native = ws_info
                if lv3 then
                    ws_info = { en = ws_info.en, sc = { lv3, unpack(ws_info.sc) } }
                end
                if ws_info then
                    local eval = sc_dict.evaluate_ws_for_sc(ws_info, state.sc_props or state.sc_property)
                    if eval then
                        local choice = {
                            ws = ws_name,
                            result_sc = eval.result,
                            priority = priority_idx,
                            reason = string.format("P%d [%s -> %s (%s)]", priority_idx, state.sc_property, eval.result, ws_name)
                        }
                        -- If it would make the same chain without the aftermath property, it does not depend on it
                        local plain = lv3 and sc_dict.evaluate_ws_for_sc(native, state.sc_props or state.sc_property)
                        local needs_aftermath = lv3 and not (plain and plain.result == eval.result)
                        if not needs_aftermath or state.sc_aeonic then
                            return choice
                        end
                        choice.reason = choice.reason .. " (relies on aftermath)"
                        fallback = fallback or choice
                    end
                end
            end
        end
        if fallback then return fallback end

        -- Nothing connects in the window: "flexible" fires the top WS (first_ws), even when it is not in sc_dict
        if settings.auto_mode == "flexible" then
            return {
                ws = first_ws,
                result_sc = "none",
                priority = first_idx,
                reason = string.format("P%d [opener/continue: %s]", first_idx, first_ws)
            }
        end
        return nil
    elseif settings.start_mode == "manual" then
        return nil  -- you open the first chain yourself (wait for someone's opener)
    else
        return {
            ws = first_ws,
            result_sc = "opener",
            priority = first_idx,
            reason = string.format("P%d [skillchain opener: %s]", first_idx, first_ws)
        }
    end
end

-- ---------------------------------------------------------------------------
-- Tossing to party members: predict the next WS of a party member (not trusts) who tends to use a fixed WS and,
-- when it is close, pick a WS whose property lets that WS continue (toss is preferred only when it is close).
-- The prediction uses "the most common of the last 8 WS (60% or more) and the median interval between them".
-- ---------------------------------------------------------------------------
local PT_HIST_KEEP = 8
local PT_HIST_AGE = 120.0       -- someone who has not used a WS for this many seconds is not used for prediction
-- The toss is not about success rate (author's policy: the other player has their own timing to use a WS. Offering the toss is what matters; whether they use it is up to them.
-- It is a toss to deal as much damage to the enemy as possible).
local TOSS_NEAR_MIN = 2.5       -- the next WS is at least this many seconds away...
local TOSS_NEAR_MAX = 8.0       -- ...and within this many seconds counts as "near"
local pt_hist = {}              -- [actor_id] = {name=, times={}, names={}}

local function record_pt_ws(actor_id, actor_name, ws_name)
    -- Forget people who have not used a WS for a long time here (when a move arrives), never inside the WS choice
    local now = safe_num(os.clock(), 0)
    for id, old in pairs(pt_hist) do
        local n = #old.times
        if n == 0 or now - old.times[n] > PT_HIST_AGE then pt_hist[id] = nil end
    end
    local h = pt_hist[actor_id]
    if not h then
        h = {name = actor_name, times = {}, names = {}}
        pt_hist[actor_id] = h
    end
    h.times[#h.times + 1] = safe_num(os.clock(), 0)
    h.names[#h.names + 1] = ws_name
    if #h.times > PT_HIST_KEEP then
        table.remove(h.times, 1)
        table.remove(h.names, 1)
    end
end

local function ws_props_by_name(ws_name)
    local id = ws_id_by_name(ws_name)
    local ws = id and res and res.weapon_skills and res.weapon_skills[id]
    if not ws then return nil end
    local props = {}
    for _, key in ipairs({"skillchain_a", "skillchain_b", "skillchain_c"}) do
        local en = ws[key]
        if en and en ~= "" then props[#props + 1] = sc_dict.SC_ALIAS[en] or en end
    end
    return #props > 0 and props or nil
end

-- List of WS that party members are likely to use soon {actor=, ws=, props=, eta=}
local function predicted_pt_ws(now)
    local list = {}
    for _, h in pairs(pt_hist) do
        local n = #h.times
        if n >= 3 and now - h.times[n] <= PT_HIST_AGE then   -- skip stale entries (record_pt_ws removes them)
            local cnt, best, best_n = {}, nil, 0
            for _, name in ipairs(h.names) do
                cnt[name] = (cnt[name] or 0) + 1
                if cnt[name] > best_n then best, best_n = name, cnt[name] end
            end
            if best_n / n >= 0.6 then
                local gaps = {}
                for i = 2, n do gaps[#gaps + 1] = h.times[i] - h.times[i - 1] end
                table.sort(gaps)
                local gap = math.min(25, math.max(4, gaps[math.ceil(#gaps / 2)]))
                local nxt, guard = h.times[n] + gap, 0
                while nxt < now - 1 and guard < 4 do nxt = nxt + gap; guard = guard + 1 end
                local eta = nxt - now
                local props = ws_props_by_name(best)
                if props and eta >= TOSS_NEAR_MIN and eta <= TOSS_NEAR_MAX then
                    list[#list + 1] = {actor = h.name, ws = best, props = props, eta = eta}
                end
            end
        end
    end
    return list
end

-- Can any predicted WS continue the properties (array) produced by your WS?
local function toss_target(result_props, preds)
    for _, pr in ipairs(preds) do
        if sc_dict.evaluate_ws_for_sc({sc = pr.props}, result_props) then return pr end
    end
    return nil
end

-- If base (the result of the usual selection) is not already a toss, pick a WS that is. nil if none (= keep base)
local function toss_override(base)
    if settings.toss == false or not base then return nil end
    local now = safe_num(os.clock(), 0)
    local preds = predicted_pt_ws(now)
    if #preds == 0 then return nil end

    local win = state.sc_active and safe_lt(now, safe_num(state.sc_expiration, 0)) and state.sc_property
    if win and state.sc_target then
        local t = cur_target()
        if t and t.id ~= state.sc_target then win = false end
    end
    local prev = win and (state.sc_props or state.sc_property) or nil

    local usable = usable_ws_set()
    local first_idx
    for idx, name in ipairs(state.ws_priority) do
        if is_executable_ws(name, usable) then first_idx = idx break end
    end

    -- If base itself is already a toss, keep it
    local base_info = sc_dict.find_ws_info(base.ws, state.active_weapon)
    local base_props = (win and base.result_sc and base.result_sc ~= "none" and base.result_sc ~= "opener")
        and {base.result_sc} or (base_info and base_info.sc)
    if base_props and toss_target(base_props, preds) then return nil end

    for idx, name in ipairs(state.ws_priority) do
        if name ~= base.ws and is_executable_ws(name, usable) and not (win and state.opener_only and idx == first_idx) then
            local info = sc_dict.find_ws_info(name, state.active_weapon)
            if info and info.sc then
                local after, result
                if win then
                    local ev = sc_dict.evaluate_ws_for_sc(info, prev)
                    if ev then
                        local first_prev = type(prev) == "table" and prev[1] or prev
                        if not sc_dict.is_terminal_chain(first_prev, ev.result) then
                            after, result = {ev.result}, ev.result
                        end
                    end
                else
                    after, result = info.sc, "opener"
                end
                local pr = after and toss_target(after, preds)
                if pr then
                    return {
                        ws = name,
                        result_sc = result,
                        priority = idx,
                        reason = string.format("P%d [toss: easy to follow %s's %s (in about %.0f s) with %s]", idx, pr.actor, pr.ws, pr.eta, tostring(result))
                    }
                end
            end
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- When everyone targets the same enemy (author's policy): tosses and chains are hard, so use the strongest WS.
--   Selection (set by the author): a prime weapon uses its prime WS (BG-Wiki Prime Weapon),
--   an empyrean weapon its empyrean WS, otherwise the empyrean WS learned through the Kupofried quest (the per-weapon-type table
--   on BG-Wiki). Only Dojikiri Yasutsuna = Tachi: Shoha is an individual choice of the author.
--   If none is usable (WS not usable, weapon type unknown), the top of the priority list. No waiting; used if TP is at least min_tp.
-- "Many people target the same enemy" = among party and alliance members (p1-p5, a10-a15, a20-a25; trusts excluded),
--   the number targeting the same enemy as you, including you, is at least settings.focus_people (default 3). People on other enemies are still counted.
--   Targets are read from mob.target_index
-- ---------------------------------------------------------------------------
local FOCUS_WS_BY_WEAPON = {          -- individual choices of the author (English weapon names)
    ["Dojikiri Yasutsuna"] = "Tachi: Shoha",
}
local FOCUS_PRIME_BY_ITEM = {         -- prime weapon (English name) -> prime WS
    ["Varga Purnikawa"] = "Maru Kala",        ["Mpu Gandring"] = "Ruthless Stroke",
    ["Caliburnus"] = "Imperator",          ["Helheim"] = "Fimbulvetr",
    ["Spalirisos"] = "Blitz",              ["Laphria"] = "Disaster",
    ["Foenaria"] = "Origin",          ["Gae Buide"] = "Diarmuid",
    ["Dokoku"] = "Zesho Meppo",                      ["Kusanagi"] = "Tachi: Mumei",
    ["Lorg Mor"] = "Dagda",                  ["Opashoro"] = "Oshala",
    ["Pinaka"] = "Sarv",                    ["Earp"] = "Terminus",
}
local FOCUS_EMPYREAN_BY_TYPE = {      -- weapon type -> empyrean WS (the WS learned through the Kupofried quest)
    ["Hand-to-Hand"] = "Victory Smite", ["Dagger"] = "Rudra's Storm",   ["Sword"] = "Chant du Cygne",
    ["Great Sword"] = "Torcleaver",   ["Axe"] = "Cloudsplitter", ["Great Axe"] = "Ukko's Fury",
    ["Scythe"] = "Quietus",       ["Polearm"] = "Camlann's Torment",       ["Katana"] = "Blade: Hi",
    ["Great Katana"] = "Tachi: Fudo",
    ["Archery"] = "Jishnu's Radiance",     ["Marksmanship"] = "Wildfire",
    -- Club (Dagan) and Staff (Myrkr) are left out: both target only yourself (res targets = 1), so the top of the priority list is used instead
}
local focus_cache = {time = -1, value = false}
local FOCUS_PARTY_KEYS = {"p1", "p2", "p3", "p4", "p5", "a10", "a11", "a12", "a13", "a14", "a15",
    "a20", "a21", "a22", "a23", "a24", "a25"}

local function all_same_target()
    local now = safe_num(os.clock(), 0)
    if now - focus_cache.time < 0.5 then return focus_cache.value end
    focus_cache.time = now
    local value, desc = false, "no target"
    local t = cur_target()
    local party = windower.ffxi.get_party()
    local me = cur_player()
    if t and t.index and t.spawn_type == 16 and party and me then
        local same, other, unknown = 0, 0, 0
        for _, key in ipairs(FOCUS_PARTY_KEYS) do
            local m = party[key]
            local mob = m and m.mob
            if mob and not mob.is_npc and mob.id ~= me.id then
                local ti = mob.target_index
                if ti == nil then
                    unknown = unknown + 1
                elseif ti > 0 then
                    local tm = windower.ffxi.get_mob_by_index(ti)
                    if tm and tm.spawn_type == 16 then
                        if ti == t.index then same = same + 1 else other = other + 1 end
                    end
                end
            end
        end
        value = same + 1 >= math.max(2, safe_num(settings.focus_people, 3))
        desc = string.format("same enemy: %d (%d including you) / other enemy: %d / unknown: %d", same, same + 1, other, unknown)
    end
    if value ~= focus_cache.value then
        -- Not logged inside the WS choice; process_auto_skillchain writes it (flush_focus_log)
        focus_cache.log_msg = string.format("Many people on the same enemy: %s (%s)", value and "yes" or "no", desc)
    end
    focus_cache.value = value
    return value
end

local function flush_focus_log()
    if focus_cache.log_msg then
        log_debug("FOCUS", focus_cache.log_msg)
        focus_cache.log_msg = nil
    end
end

local function focus_choice()
    if settings.focus_max == false then return nil end
    if not all_same_target() then return nil end
    local usable = usable_ws_set()
    local names = equipped_weapon_names()
    -- Archery / Marksmanship WS depend on the weapon in the ranged slot
    local slot = (state.active_weapon == "Archery" or state.active_weapon == "Marksmanship") and "range" or "main"
    local main = names[slot]
    local candidates = {
        FOCUS_WS_BY_WEAPON[main or ""],
        FOCUS_PRIME_BY_ITEM[names[slot] or ""],
        FOCUS_EMPYREAN_BY_TYPE[state.active_weapon or ""],
    }
    local ws
    for i = 1, 3 do
        if candidates[i] and is_executable_ws(candidates[i], usable) then ws = candidates[i] break end
    end
    if not ws then
        for _, name in ipairs(state.ws_priority or {}) do
            if is_executable_ws(name, usable) then ws = name break end
        end
    end
    if not ws then return nil end
    return {
        ws = ws,
        result_sc = "none",
        priority = 0,
        no_wait = true,
        min_tp = math.max(safe_num(settings.min_tp, 1000), safe_num(settings.focus_tp, 1500)),   -- use it once TP reaches this
        reason = string.format("many on the same enemy: max power (%s)", tostring(main or "unknown weapon"))
    }
end

-- Is there a chain window or a chainbound on your current enemy? (decides whether manual mode may fire)
local function has_window_on_target(now)
    local t = cur_target()
    if state.sc_active and safe_lt(now, safe_num(state.sc_expiration, 0)) and state.sc_property
        and not (state.sc_target and t and t.id ~= state.sc_target) then
        return true
    end
    local cb = state.chainbound
    return cb ~= nil and safe_lt(now, safe_num(cb.until_time, 0)) and t ~= nil and t.id == cb.target
end

-- Order in which the WS is chosen (earlier wins; decided here only):
--   1. manual (//omni start manual): nothing is used while there is no window (chainbound included), not even the max-power WS
--   2. max-power WS (many people on the same enemy)
--   3. priority list (chainbound, chain continuation, opener) and tosses to party members
local function find_best_ws_from_priority()
    if settings.start_mode == "manual" and not has_window_on_target(safe_num(os.clock(), 0)) then return nil end
    local focus = focus_choice()
    if focus then return focus end
    local base = find_base_ws_from_priority()
    local tossed = toss_override(base)
    return tossed or base
end

-- Reuse the choice for CHOICE_CACHE_SEC seconds (one choice per frame for the auto WS and the HUD).
-- A different target or a state change (choice_version) forces a fresh choice
local choice_cache = {time = -100, value = nil, t_id = nil, version = -1}
local function current_choice(now)
    local t = cur_target()
    local t_id = t and t.id or false
    local c = choice_cache
    if c.version == choice_version and c.t_id == t_id and now >= c.time and now - c.time < CHOICE_CACHE_SEC then
        return c.value
    end
    c.value = find_best_ws_from_priority()
    c.time, c.t_id, c.version = now, t_id, choice_version
    return c.value
end

-- Auto-skillchain decision and automatic WS execution (runs whether or not the HUD is shown)
local function process_auto_skillchain()
    flush_focus_log()
    local player = cur_player()
    local now = safe_num(os.clock(), 0)
    -- On the frame you disengage, change target or become unable to act, cancel the reservation and the progress (only on the change, not every frame)
    local engaged = player ~= nil and safe_num(player.status, 0) == 1
    local cur_t = cur_target()
    local t_id = cur_t and cur_t.id or nil
    local incap = is_incapacitated(player)
    local prev_t_id = state.watch_t_id
    if (state.watch_engaged and not engaged) or (prev_t_id ~= nil and t_id ~= prev_t_id)
        or (incap and not state.watch_incap) then
        limit.cancel()
    end
    -- Area-sphere hold: lift it when the time is up or you disengage (one notice, when it is lifted)
    if safe_num(state.sphere_hold_until, 0) > 0 then
        if now >= safe_num(state.sphere_hold_until, 0) then
            limit.sphere_end("time is up")
        elseif state.watch_engaged and not engaged then
            limit.sphere_end("disengaged")
        end
    end
    state.watch_engaged, state.watch_t_id, state.watch_incap = engaged, t_id, incap
    -- When a fight ends, reset the per-chain count (also on frames where you are not engaged)
    limit.run_idle(now, engaged, cur_t, prev_t_id)
    if not engaged then return end

    -- Send nothing while: stopped (repeated refusals, a limit) / the previous WS is pending / backing off after a refusal /
    -- holding for a /ws whose result had not arrived when it was cancelled / unable to act / holding after a failed check right before sending
    if state.auto_halted then return end
    local pending = state.pending_ws
    if pending and now - safe_num(pending.time, now) <= PENDING_WS_TIMEOUT then return end
    if now < safe_num(state.ws_fail_until, 0) then return end
    if now < safe_num(state.sent_hold_until, 0) then return end
    if incap then return end
    if now < safe_num(state.verify_until, 0) then return end
    -- Send nothing right after you used a WS by hand (sending during your own WS gets it refused and wastes TP)
    if now < safe_num(state.manual_ws_until, 0) then return end
    -- Send nothing after the area-sphere warning (the Moogle's line or the boss's SP move ID) while melee players move away (the only send is further below)
    if now < safe_num(state.sphere_hold_until, 0) then return end
    -- Send nothing when TP is not a number
    local tp = player.vitals and player.vitals.tp
    if type(tp) ~= "number" then return end
    local min_tp = clamp_min_tp(settings.min_tp)
    local wait_delay = clamp_wait_delay(settings.wait_delay)
    local last_ws = safe_num(state.last_ws_time, 0)

    if settings.enabled and safe_gte(tp, min_tp) and safe_gt(now - last_ws, wait_delay) then
        local choice = current_choice(now)
        -- Do not interrupt while a trust is doing a solo chain (use the WS after it ends)
        if choice and (choice.no_wait or follow_wait_left(now, tp) <= 0) and solo_wait_left(now) <= 0
            and not (choice.min_tp and not safe_gte(tp, choice.min_tp)) then
            -- Wait 2 s right after the game refuses with "cannot see target" (since 2026-10-24 valid_target is no longer used as a pre-check:
            -- on big enemies such as Awoken Hakenmann or Morbol Emperor it stayed false, or flipped between true and false, and the auto WS stopped even though a manual WS worked)
            if now < safe_num(state.unseen_until, 0) then return end
            -- <t> must be a living enemy (spawn_type 16, hpp > 0). When that cannot be told (no target, no hpp), send nothing
            local target = cur_target()
            if not (target and target.spawn_type == 16 and safe_num(target.hpp, 0) > 0) then
                if now - safe_num(state.target_log_time, 0) >= 3.0 then
                    state.target_log_time = now
                    log_debug("TARGET", string.format("Not using %s: the target is not a living enemy (%s)", choice.ws,
                        target and string.format("spawn_type %s / hpp %s", tostring(target.spawn_type), tostring(target.hpp)) or "no target"))
                end
                return
            end
            local in_range, dist, reach = ws_in_range(choice.ws)
            if not in_range then
                -- Do not use it until it reaches. The log line is limited to every 3 s
                if now - safe_num(state.range_log_time, 0) >= 3.0 then
                    state.range_log_time = now
                    log_debug("RANGE", string.format("%s is too far, not using it (distance %.1f / reach %.1f)", choice.ws, safe_num(dist, -1), safe_num(reach, -1)))
                end
                return
            end
            -- Check right before sending (the HUD caches are not used): re-read the gear and the usable WS list, choose the WS again and make sure it is the same.
            -- If something cannot be read, changed or is not usable, send nothing and look again after VERIFY_HOLD_SEC seconds (not every frame)
            weapon_cache.time = -1
            usable_cache.time = -1
            local eq = windower.ffxi.get_items('equipment')
            local fresh = type(eq) == "table" and type(eq.main) == "number" and usable_ws_set() and find_best_ws_from_priority()
            if not fresh or fresh.ws ~= choice.ws or not check_ws_usable(fresh.ws, "EXECUTE") then
                state.verify_until = now + limit.VERIFY_HOLD_SEC
                invalidate_choice()
                log_debug("EXECUTE", string.format("Not using %s: the check right before sending (gear, usable WS list, fresh choice) did not match", choice.ws))
                return
            end
            choice = fresh
            -- An auto opener (sent when the target has no window to continue and no Chainbound) starts a new chain count,
            -- even if the window closed less than 3 s ago. A continuation step does not reset it, and the total is never reset
            -- The first send after a failure cancel (note_ws_fail) does not restart it (the mark is used up here)
            if state.fail_keep_run then
                state.fail_keep_run = nil
            elseif not has_window_on_target(now) then
                limit.reset_run()
            end
            -- Stop if a limit (per chain, total) is reached
            if limit.reached(now) then return end
            state.last_ws_time = now
            if not state.run_start then state.run_start, state.run_count = now, 0 end
            state.run_count = safe_num(state.run_count, 0) + 1
            limit.total[#limit.total + 1] = now
            local ws_id = ws_id_by_name(choice.ws)
            state.pending_ws = {name = choice.ws, id = ws_id, target = target.id, time = now, tp = tp, gen = state.gen}
            state.last_sent = {id = ws_id, target = target.id, time = now, done = false}
            invalidate_choice()
            log_debug("EXECUTE", string.format("Executing WS: %s (%s) [TP: %d / AM: %s / after chain #%d / %.1f s since previous WS / #%d in this chain]", choice.ws, choice.reason, tp,
                has_aftermath() and "yes" or "no", safe_num(state.sc_step, 0), now - safe_num(state.sc_start_time, now), state.run_count))
            chat_msg(string.format("[OmniChain] Auto WS: %s (%s)", choice.ws, choice.reason), 158)
            -- Mark this send so its outgoing 0x01A is not mistaken for a manual WS
            state.own_out_id, state.own_out_target, state.own_out_until = ws_id, target.id, now + limit.OWN_OUT_SEC
            -- Send the command to the game
            windower.send_command(string.format('input /ws "%s" <t>', choice.ws))
        end
    end
end

-- prerender event (main routine)
local function check_pending_ws(now)
    local p = state.pending_ws
    if p and now - safe_num(p.time, now) > PENDING_WS_TIMEOUT then
        state.pending_ws = nil
        log_event("WARN", "WS_TIMEOUT", string.format("%s was sent but did not fire within %.0f s (check the WS name, distance, incapacitation, etc.)", p.name, PENDING_WS_TIMEOUT))
        note_ws_fail(now, "no response")   -- no response counts as a refusal too (WS_FAIL_LIMIT in a row stops auto WS)
    end
end

-- Body of prerender (defined once as a function so no closure is created every frame)
local function prerender_body()
        -- Read the player and <t> once for this frame (the caller clears frame.active when the frame ends)
        frame.player = windower.ffxi.get_player()
        frame.t = windower.ffxi.get_mob_by_target('t')
        frame.me = nil
        frame.active = true

        -- Clear an expired chain window (also when the HUD is hidden)
        expire_sc_window(safe_num(os.clock(), 0))

        -- Background auto-skillchain decision
        process_auto_skillchain()

        -- Draw the HUD overlay (hide / text are called only when the state or the body changes)
        if not settings.show_hud then
            if hud_cache.shown ~= false then
                hud:hide()
                grip:hide()
                hud_cache.shown = false
            end
            return
        end

        local now = safe_num(os.clock(), 0)
        local sc_exp = safe_num(state.sc_expiration, 0)
        local min_tp = safe_num(settings.min_tp, 1000)

        local lines = {}
        local status_str = settings.enabled and color_text("[ON]", 100, 255, 100) or color_text("[OFF]", 255, 100, 100)
        table.insert(lines, string.format("=== [ OmniChain v%s ] %s ===", _addon.version, status_str))
        table.insert(lines, string.format("Job / Weapon: %s / %s", color_text(state.active_job, 255, 220, 100), color_text(state.active_weapon, 0, 210, 255)))

        local prio_str_list = {}
        for idx, name in ipairs(state.ws_priority) do
            if safe_lte(idx, 3) then
                table.insert(prio_str_list, string.format("P%d:%s", idx, name))
            end
        end
        table.insert(lines, string.format("WS priority: %s", color_text(table.concat(prio_str_list, " > "), 200, 255, 200)))
        if state.auto_halted then
            table.insert(lines, color_text("Auto WS stopped (repeated refusals, a limit, etc.; //omni on resumes)", 255, 120, 120))
        end

        if state.sc_active and safe_lt(now, sc_exp) then
            local rem_time = math.max(0.0, sc_exp - now)
            table.insert(lines, string.format("Active chain: %s (%.1fs left / %s)", color_text(state.sc_property, 255, 200, 50), rem_time, state.sc_starter))
        elseif state.text_sc_name and safe_lt(now, safe_num(state.text_sc_until, 0)) then
            -- A chain seen in chat (the enemy and the user are unknown, so it is shown only; auto WS does not use it)
            table.insert(lines, string.format("Chain window: %s (chat chain %s, for reference)", color_text("waiting (Idle)", 180, 180, 180), state.text_sc_name))
        else
            table.insert(lines, string.format("Chain window: %s", color_text("waiting (Idle)", 180, 180, 180)))
        end

        local player = cur_player()
        if player and safe_num(player.status, 0) == 1 then
            local tp = safe_num(player.vitals and player.vitals.tp, 0)
            table.insert(lines, string.format("TP: %s / min %d", color_text(tostring(tp), safe_gte(tp, min_tp) and 50 or 255, 255, 100), min_tp))

            local solo_left, solo_name = solo_wait_left(now)
            if solo_left > 0 then
                table.insert(lines, string.format("Waiting on solo chain: %s (%.1fs left)", color_text(tostring(solo_name), 255, 160, 220), solo_left))
            end

            local choice = current_choice(now)
            if choice then
                local wait_left = math.max(choice.no_wait and 0 or follow_wait_left(now, tp), solo_left)
                local wait_str = wait_left > 0 and string.format(" (%.1fs left)", wait_left) or ""
                table.insert(lines, string.format("Next WS: %s%s", color_text(choice.ws, 100, 255, 150), wait_str))
                table.insert(lines, string.format("Reason: %s", color_text(choice.reason, 200, 200, 255)))
            elseif settings.start_mode == "manual" then
                table.insert(lines, string.format("Next WS: %s", color_text("waiting for an opener (first WS is manual)", 255, 200, 120)))
            end
        else
            table.insert(lines, string.format("Status: %s", color_text("not engaged (Idle)", 180, 180, 180)))
        end

        -- Assigning to the texts object (hud.text = ...) sets the ${text} variable, so set the body with the method
        local body = table.concat(lines, string.char(10))
        if body ~= hud_cache.text then
            hud:text(body)
            hud_cache.text = body
        end
        if hud_cache.shown ~= true then
            hud:show()
            hud_cache.shown = true
        end
        update_grip()
end

windower.register_event("prerender", guarded0("PRERENDER", function()
    local frame_start = os.clock()

    -- WS response timeout / periodic log flush
    check_pending_ws(frame_start)
    if frame_start - monitor.last_flush > LOG_FLUSH_SEC then flush_log() end

    local ok, err = xpcall(prerender_body, traceback)
    frame.active = false   -- outside a frame (packets, commands) the player and <t> are read fresh
    frame.player, frame.t, frame.me = nil, nil, nil

    if not ok then
        -- The same error would appear every frame, so chat is grouped every 10 s on the log_event side
        -- Only when it was recorded (not throttled) is the trace also written to the file
        if log_event("ERROR", "PRERENDER", tostring(err):match("^[^\n]*") or tostring(err)) then
            push_log_line(tostring(err))
            flush_log(true)
        end
    end
end))

-- HUD mouse handling (returning true keeps the click from the game; guarded drops return values, so it is not used here)
local function on_mouse(mtype, x, y, delta, blocked)
    if blocked or not settings.show_hud then return end

    if mtype == MOUSE_MOVE then
        if resize then
            -- Change the font size by whichever of width/height grew more during the drag
            local rx = (resize.w + (x - resize.x)) / math.max(resize.w, 1)
            local ry = (resize.h + (y - resize.y)) / math.max(resize.h, 1)
            set_size(resize.size * math.max(rx, ry))
            update_grip()
            return true
        end
        -- Over the corner, pause libs/texts "drag to move" so this code receives the click
        local on_handle = in_resize_handle(x, y)
        if move_allowed then
            local want = not on_handle
            if hud:draggable() ~= want then hud:draggable(want) end
        end
        -- Highlight the marker when the cursor is on the corner
        if on_handle ~= grip_hot then
            grip_hot = on_handle
            update_grip()
        end

    elseif mtype == MOUSE_LEFT_DOWN then
        if in_resize_handle(x, y) then
            local w, h = hud:extents()
            resize = {x = x, y = y, w = w, h = h, size = current_size()}
            return true
        end

    elseif mtype == MOUSE_LEFT_UP then
        if resize then
            resize = nil
            save_settings()
            return true
        end

    elseif mtype == MOUSE_WHEEL then
        if hud:hover(x, y) then
            local step = safe_num(delta, 0) > 0 and 1 or -1
            set_size(current_size() + step)
            save_settings()
            update_grip()
            return true
        end
    end
end

windower.register_event("mouse", function(...)
    local args, n = {...}, select("#", ...)
    local ok, result = xpcall(function() return on_mouse(unpack(args, 1, n)) end, traceback)
    if ok then return result end
    resize = nil
    log_event("ERROR", "MOUSE", tostring(result):match("^[^\n]*") or tostring(result))
end)

-- Look up the skill resource by action category (3: WS / 11: TP moves (automaton etc.) / 13: pet moves (blood pacts etc.))
local CATEGORY_RESOURCES = {
    [3]  = "weapon_skills",
    [11] = "monster_abilities",
    [13] = "job_abilities",
}

-- Is it a party/alliance member or their pet? (so enemy skills do not open a chain window)
local function is_party_actor(mob)
    if not mob then return false end
    if mob.in_party or mob.in_alliance then return true end
    local party = windower.ffxi.get_party()
    if not party then return false end
    for _, member in pairs(party) do
        if type(member) == "table" and member.mob and member.mob.pet_index and member.mob.pet_index == mob.index then
            return true
        end
    end
    return false
end

-- Added-effect message ID -> skillchain that occurred (res/action_messages.lua: 288-301 damage / 385-398 healing / 767-770 Radiance/Umbra)
local SKILLCHAIN_MESSAGES = {}
do
    local order = {"Light", "Darkness", "Gravitation", "Fragmentation", "Distortion", "Fusion", "Compression", "Liquefaction", "Induration", "Reverberation", "Transfixion", "Scission", "Detonation", "Impaction"}
    for i, name in ipairs(order) do
        SKILLCHAIN_MESSAGES[287 + i] = name
        SKILLCHAIN_MESSAGES[384 + i] = name
    end
    SKILLCHAIN_MESSAGES[767] = "Radiance"; SKILLCHAIN_MESSAGES[769] = "Radiance"
    SKILLCHAIN_MESSAGES[768] = "Umbra"; SKILLCHAIN_MESSAGES[770] = "Umbra"
end

-- The chat line "Skillchain: <name>" can arrive several seconds (measured 4-7 s) after the packet.
-- After updating the chain state from a packet, chat is ignored for this many seconds and used only as a fallback when a packet is missed
local TEXT_SC_IGNORE_SEC = 10.0

-- A chain occurred: for the next step only the chain that occurred is A1 (wiki: from the 3rd chain on, the other properties of the previous WS are ignored)
-- close_reason: when it is known that the chain cannot be continued, the reason (the chain ends and the next one starts from an opener)
-- actor_id: the user of the move that made the chain (packets only). A closing chain ends only that user's solo chain wait
local function apply_chain_result(sc_name, starter, source, target_id, close_reason, actor_id)
    local now = safe_num(os.clock(), 0)
    if source == "TEXT_SC" and safe_lt(now, safe_num(state.last_packet_sc_time, -100) + TEXT_SC_IGNORE_SEC) then
        log_debug(source, string.format("Ignored (packet is newer): %s", sc_name))
        return
    end
    if source == "TEXT_SC" then
        -- A chat line tells neither the enemy nor who used the move, so it is only shown on the HUD (not a chain window, not a condition for auto WS)
        state.text_sc_name = sc_name
        state.text_sc_until = now + sc_window_sec(0)
        log_debug(source, string.format("Chain (shown only, not used for auto WS): %s", sc_name))
        return
    end
    -- The same chain arrives by both packet and chat, so ignore an immediate duplicate
    if state.last_chain_name == sc_name and safe_lt(now, safe_num(state.last_chain_time, 0) + 1.5) then return end
    -- Never use an expired window's property as the "previous property" of this chain
    expire_sc_window(now)

    -- Does this continue the current window (same enemy)? If not, do not carry over the previous window's property or chain count
    local continuing = state.sc_active and (target_id == nil or state.sc_target == nil or state.sc_target == target_id)
    -- A Light/Darkness WS stacked on an opener's Light/Darkness (aeonic) also ends as Light->Light / Darkness->Darkness (confirmed in game)
    local prev = continuing and state.sc_props and state.sc_props[1] or nil
    state.last_chain_name = sc_name
    state.last_chain_time = now
    if source == "PACKET_SC" then state.last_packet_sc_time = now end

    -- A chain made by the last move of a trust's solo chain does not chain even if you stack your own WS
    -- (measured 2026-10-10: Fudo used 3.2 s and 5 s after the Light from Iroha's Gachirin did not chain either time).
    -- So the chain ends here and the next one is rebuilt from an opener (the caller passes close_reason only for the packet of that move)
    if close_reason then
        clear_sc_state()
        log_debug(source, string.format("Chain closed: %s (%s; starting over from an opener)", sc_name, close_reason))
        return
    end

    if sc_dict.is_terminal_chain(prev, sc_name) then
        -- After Light->Light / Darkness->Darkness, or after Radiance/Umbra, no WS chains
        clear_sc_state()
        -- The solo chain of the trust that made this chain ends here (a closing chain by someone else does not drop other trusts' waits)
        if actor_id ~= nil and state.solos[actor_id] then state.solos[actor_id] = nil end
        log_debug(source, string.format("Chain closed: %s (prev: %s)", sc_name, tostring(prev)))
        return
    end

    if not continuing then state.sc_step = 0 end
    state.sc_active = true
    state.sc_props = { sc_name }
    state.sc_property = sc_name
    state.sc_step = safe_num(state.sc_step, 0) + 1
    state.sc_aeonic = false
    state.sc_expiration = now + sc_window_sec(state.sc_step)
    state.sc_start_time = now
    if starter then state.sc_starter = starter end
    if target_id then state.sc_target = target_id end
    log_debug(source, string.format("Chain: %s (prev: %s)", sc_name, tostring(prev)))
end

-- Action category names
local CATEGORY_NAMES = {[3] = "WS", [7] = "WS ready", [11] = "TP move", [13] = "pet move"}
local WS_READY_INTERRUPT = 28787
-- Action messages meaning it did not hit (188/189: WS miss / no effect; 323/324: move no effect / miss)
local NO_HIT_MESSAGES = {[31] = true, [188] = true, [189] = true, [323] = true, [324] = true}   -- 31: removed by a shadow (Utsusemi)
-- Action messages for an ability's result (100: just used / 102: HP recovery / 110, 317: damage / 158, 324: miss / 323: no effect)
-- Result messages of a normal attack (1: hit / 15: miss / 67: critical / 352-354, 576, 577: ranged attack).
-- Some trust normal attacks arrive in category 11, the same as special moves (Ashera's #3455-3460). They are not WS, so they do not count toward a chain
local AUTO_ATTACK_MESSAGES = {[1] = true, [15] = true, [67] = true, [352] = true, [353] = true, [354] = true, [576] = true, [577] = true}
local JA_RESULT_MESSAGES = {[100] = true, [102] = true, [110] = true, [158] = true, [317] = true, [323] = true, [324] = true}
-- Action message meaning an enemy became chainbound (Chainbound), and the number of seconds the chainbound is assumed to last
local CHAINBOUND_MESSAGE = 529
local CHAINBOUND_SEC = 10.0
-- Seconds to ignore the same trust's trigger right after its solo chain ended by reaching the move count (max_ws) (Ark GK may use Hagakure after the 2nd)
local SOLO_DONE_IGNORE_SEC = 6.0

local function ability_name(cat, id)
    local key = CATEGORY_RESOURCES[cat == 7 and 3 or cat]
    local t = key and res and res[key]
    local a = t and t[id]
    return a and a.en or ("#" .. tostring(id))
end

-- -----------------------------------------------------------------------------
-- Waiting for a trust's solo chain
--   When a trust that skillchains on its own (sc_dict.TRUST_SOLO) uses a trigger ability (Meditate, Hagakure, Sekkanoki),
--   do not auto-WS until the solo chain is over.
--   End conditions: the last move, if known / the chain closed as Light->Light or Darkness->Darkness /
--                   no trust WS for solo_gap seconds / no WS for solo_start_wait seconds after the ability
-- -----------------------------------------------------------------------------
local JOB_ABILITY_CATEGORY = 6

-- 0x028 category 6: a trust used an ability
local function handle_trust_ability(p)
    if settings.trust_solo == false then return end
    local actor_id = p["Actor"]
    if state.player_id ~= nil and actor_id == state.player_id then return end
    local mob = windower.ffxi.get_mob_by_id(actor_id)
    if not mob or not (mob.in_party or mob.in_alliance) then return end
    local def = sc_dict.find_trust_solo(mob.name)
    if not def then return end

    local ability = res and res.job_abilities and res.job_abilities[safe_num(p["Param"], 0)]
    local ability_en = ability and ability.en
    for _, trigger in ipairs(def.abilities) do
        if trigger == ability_en then
            local now = safe_num(os.clock(), 0)
            local done = state.solo_done and state.solo_done[actor_id]
            if done and now - done < SOLO_DONE_IGNORE_SEC then
                log_debug("TRUST_SOLO", string.format("Ignoring trigger: %s used %s (just after a solo chain ended)", def.name or tostring(mob.name), ability_en))
                return
            end
            local wait_until = now + safe_num(settings.solo_start_wait, 12.0)
            local solo = state.solos[actor_id]
            if solo then
                -- Another trigger was used partway through a solo chain (Meditate -> WS -> Hagakure, etc.): keep the count and extend the wait
                solo.until_time = math.max(safe_num(solo.until_time, 0), wait_until)
                log_debug("TRUST_SOLO", string.format("Wait extended: %s used %s (after %d WS)", solo.name, ability_en, solo.count))
                return
            end
            solo = {
                name = def.name or tostring(mob.name), ability = ability_en,
                until_time = wait_until, count = 0, last_ws = def.last_ws, max_ws = def.max_ws,
            }
            state.solos[actor_id] = solo
            log_debug("TRUST_SOLO", string.format("Wait started: %s used %s (auto WS is paused until the solo chain ends)", solo.name, ability_en))
            return
        end
    end
end

-- A trust in a solo chain used a WS: wait solo_gap seconds for the next one. Stop waiting if it was the last move
-- Returns true if this move was the last move of the solo chain. The caller closes a chain made by this very packet;
-- nothing is kept in state (a kept flag used to close an unrelated later chain when the last move missed)
local function track_trust_solo_ws(actor_id, ws_name)
    local solo = state.solos[actor_id]
    if not solo then return false end
    solo.count = solo.count + 1
    for _, last in ipairs(solo.last_ws or {}) do
        if last == ws_name then
            log_debug("TRUST_SOLO", string.format("Wait over: %s's solo chain reached its last move %s (%d WS)", solo.name, ws_name, solo.count))
            state.solos[actor_id] = nil
            return true
        end
    end
    if solo.max_ws and solo.count >= solo.max_ws then
        log_debug("TRUST_SOLO", string.format("Wait over: %s's solo chain ended at WS #%d %s", solo.name, solo.count, ws_name))
        state.solos[actor_id] = nil
        state.solo_done = state.solo_done or {}
        state.solo_done[actor_id] = safe_num(os.clock(), 0)
        return
    end
    solo.until_time = safe_num(os.clock(), 0) + safe_num(settings.solo_gap, 11.0)
    log_debug("TRUST_SOLO", string.format("%s solo chain WS #%d: %s", solo.name, solo.count, ws_name))
end

-- Match your own WS result against the auto-execution record.
-- The pending wait is released only when the WS (name or ID), the target and the generation match it (an unconfirmed result never moves things on).
-- Returns true if this move is your auto WS (it matches the pending wait, or it is the same WS and target sent within limit.LAND_SEC seconds)
local function track_own_action(p, cat)
    local pending = state.pending_ws
    local target_id = p["Target 1 ID"]
    if cat == 3 then
        local ws_id = safe_num(p["Param"], 0)
        local msg = safe_num(p["Target 1 Action 1 Message"], 0)
        local dmg = safe_num(p["Target 1 Action 1 Param"], 0)
        local name = ability_name(3, ws_id)
        local result = (msg == 188 and "miss") or (msg == 189 and "no effect") or string.format("%d damage", dmg)
        local level = (msg == 188 or msg == 189) and "WARN" or "INFO"
        local matched = pending ~= nil and pending.gen == state.gen and pending.target == target_id
            and (pending.id == ws_id or pending.name == name)
        local sent = state.last_sent
        local auto = matched or (sent ~= nil and sent.id == ws_id and sent.target == target_id
            and safe_num(os.clock(), 0) - safe_num(sent.time, -100) < limit.LAND_SEC)
        log_event(level, "WS_RESULT", string.format("[%s] %s → %s", auto and "auto" or "manual", name, result))
        if auto then limit.sent_done() end
        if matched then
            state.pending_ws = nil
            -- A WS went off (even a miss means the input was accepted), so the refusal count starts over
            -- (resuming after a stop, such as a limit, is only by //omni on)
            state.ws_fail_count = 0
            state.ws_fail_until = 0
        elseif pending then
            log_event("WARN", "WS_RESULT", string.format("A WS that does not match the pending %s fired (%s, target %s). Still waiting", pending.name, name, tostring(target_id)))
        end
        return auto
    elseif cat == 7 and safe_num(p["Param"], 0) == WS_READY_INTERRUPT and pending and pending.gen == state.gen
        and pending.target == target_id then
        log_event("WARN", "WS_FAIL", string.format("%s was interrupted", pending.name))
        state.pending_ws = nil
        limit.sent_done()
        note_ws_fail(safe_num(os.clock(), 0), "stance interrupted")   -- an interrupt counts as a failure too (WS_FAIL_LIMIT in a row stops auto WS)
    end
end

local function handle_action_packet(data)
    local p = packets.parse("incoming", data)
    if not p then
        log_event("WARN", "PACKET", "Failed to parse 0x028")
        return
    end
    local cat = safe_num(p["Category"], 0)
    -- Area-sphere warning: the boss's SP (category 11) is a warning too (some SPs come with no Moogle line)
    if cat == limit.SPHERE_TP_CATEGORY then limit.sphere_tp(p) end
    -- Chainbound (msg 529 "is chainbound"): the next WS always chains.
    -- Recorded only when you or a party member (pets included) used it on the enemy you are targeting
    if safe_num(p["Target 1 Action 1 Message"], 0) == CHAINBOUND_MESSAGE then
        local who = windower.ffxi.get_mob_by_id(p["Actor"])
        local cb_target = p["Target 1 ID"]
        local t = windower.ffxi.get_mob_by_target("t")
        local by_us = (state.player_id ~= nil and p["Actor"] == state.player_id) or is_party_actor(who)
        if t and t.id == cb_target and by_us then
            local cb_now = safe_num(os.clock(), 0)
            state.chainbound = {target = cb_target, start_time = cb_now, until_time = cb_now + CHAINBOUND_SEC}
            log_debug("PACKET_SC", string.format("Chainbound: %s used Chainbound (the first WS from about 3 s later will chain)", tostring(who and who.name or p["Actor"])))
        else
            log_debug("PACKET_SC", string.format("Chainbound not recorded: %s (%s)", tostring(who and who.name or p["Actor"]),
                by_us and "not your enemy" or "not a party member"))
        end
        return
    end
    if cat == JOB_ABILITY_CATEGORY then
        handle_trust_ability(p)
        return
    end
    if not CATEGORY_NAMES[cat] then return end

    -- A move carrying a skillchain counts as "seen in a packet" even when it is dropped below (other enemy, outside the party, ...),
    -- so the "Skillchain: <name>." chat line that arrives seconds later does not bring the dropped chain back
    if p["Target 1 Action 1 Has Added Effect"] and SKILLCHAIN_MESSAGES[safe_num(p["Target 1 Action 1 Added Effect Message"], 0)] then
        state.last_packet_sc_time = safe_num(os.clock(), 0)
    end

    -- Some abilities such as jumps arrive in category 3, the same as WS (the number is the ability's).
    -- Reading it as a WS number would give another move and create a false opener, so it is not treated as a WS
    if cat == 3 and JA_RESULT_MESSAGES[safe_num(p["Target 1 Action 1 Message"], 0)] then
        return
    end

    local is_self = state.player_id ~= nil and p["Actor"] == state.player_id
    local own_auto = false
    if is_self then own_auto = track_own_action(p, cat) end

    local actor_mob = windower.ffxi.get_mob_by_id(p["Actor"])
    if not actor_mob then return end
    -- Only moves by you and your party / alliance members (and their pets) open or move the chain window (the condition for auto WS).
    -- Moves by people outside the party and enemy moves (category 11) never do (auto WS never starts from a move whose user cannot be confirmed)
    local outsider = not is_self and not is_party_actor(actor_mob)
    if outsider then
        return
    elseif cat == 3 or cat == 11 or cat == 13 then
        -- Even you or a party member (pet moves, category 13, included): a move on an enemy different from the one you are targeting does not affect the chain
        -- (in places like Limbus where many enemies are linked and killed one by one, your allies are fighting other enemies).
        -- With no target of your own it is unknown which enemy the chain is on, so the move is not used either
        local t = windower.ffxi.get_mob_by_target("t")
        if not t or t.id ~= p["Target 1 ID"] then
            state.other_mob_ignored = safe_num(state.other_mob_ignored, 0) + 1
            return
        end
    end
    local actor_name = tostring(actor_mob.name or "")
    local param = safe_num(p["Param"], 0)

    -- Did this move cause a skillchain? (judged by the added-effect message)
    local add_msg = p["Target 1 Action 1 Has Added Effect"] and safe_num(p["Target 1 Action 1 Added Effect Message"], 0) or 0
    local chain = SKILLCHAIN_MESSAGES[add_msg]

    local res_table = CATEGORY_RESOURCES[cat] and res and res[CATEGORY_RESOURCES[cat]]
    if not res_table then return end

    -- A normal attack that arrives in category 11 is not a WS. It counts toward neither chains, chainbound, nor solo chains
    -- (measured 2026-10-11: reading Ashera's normal attack as a WS cleared the chainbound, and in 3 of 5 tries the WS matched to the chainbound could not be used)
    if cat == 11 and AUTO_ATTACK_MESSAGES[safe_num(p["Target 1 Action 1 Message"], 0)] then return end

    -- Count the WS of a trust in a solo chain (if the chain closes, apply_chain_result ends the wait)
    -- Healing / buff moves (238: HP recovery / 194: buff / 159: status cure) are not counted as solo chain moves
    local solo_msg = safe_num(p["Target 1 Action 1 Message"], 0)
    local solo_last = false
    if not is_self and not (solo_msg == 238 or solo_msg == 194 or solo_msg == 159) then
        solo_last = track_trust_solo_ws(p["Actor"], ability_name(cat, param))
    end

    local target_id = p["Target 1 ID"]
    local landed = not NO_HIT_MESSAGES[solo_msg]
    local ws_def = res_table[param]

    -- Chainbound ends when the next WS lands. That WS chains regardless of the previous property.
    -- A Light/Darkness made from a WS that has Light/Darkness cannot be continued (Chainbound -> Fudo (Light) -> Fudo (no chain), BG-Wiki)
    local close_reason = nil
    local cb = state.chainbound
    if cb and cb.target == target_id and landed then
        state.chainbound = nil
        if safe_lt(safe_num(os.clock(), 0), safe_num(cb.until_time, 0)) and (chain == "Light" or chain == "Darkness") and ws_def then
            local lv3 = is_self and cat == 3 and aeonic_prop(ws_def.en)
            for _, key in ipairs({"skillchain_a", "skillchain_b", "skillchain_c"}) do
                if ws_def[key] == "Light" or ws_def[key] == "Darkness" then lv3 = true end
            end
            if lv3 then close_reason = "Light/Darkness WS on chainbound" end
        end
        -- A WS that lands before the chainbound window opens (within about 3 s of it being applied) does not chain and the chainbound is lost.
        -- That WS does not become an opener either (measured 2026-10-11 19:48:17: the next Shoha did not chain on a Shoha that landed at 0 s)
        if not chain and safe_lt(safe_num(os.clock(), 0), safe_num(cb.until_time, 0)) then
            clear_sc_state()
            state.last_packet_sc_time = safe_num(os.clock(), 0)
            log_debug("PACKET_SC", string.format("Chainbound wasted: %s %s (%.1f s after the chainbound; not counted as an opener)", actor_name,
                ability_name(cat, param), safe_num(os.clock(), 0) - safe_num(cb.start_time, 0)))
            return
        end
    end

    -- Moves after which your WS is known not to chain (sc_dict.NO_FOLLOW): do not continue the chain, start over from an opener
    if not is_self and landed and not (solo_msg == 238 or solo_msg == 194 or solo_msg == 159)
        and sc_dict.is_no_follow(actor_mob.name, ws_def and ws_def.en) then
        clear_sc_state()
        state.last_packet_sc_time = safe_num(os.clock(), 0)
        log_debug("PACKET_SC", string.format("No follow: %s %s%s (not continuing after this move; starting over from an opener)", actor_name, ability_name(cat, param),
            chain and (" = " .. chain) or ""))
        return
    end

    local kind = is_self and "self" or ((actor_mob and actor_mob.spawn_type == 14) and "trust" or "player")
    if kind == "player" and cat == 3 and landed then
        record_pt_ws(p["Actor"], actor_name, ability_name(cat, param))
    end

    if chain then
        local self_only = state.sc_self_only and is_self
        if solo_last then close_reason = close_reason or "last move of a trust's solo chain" end
        apply_chain_result(chain, actor_name, "PACKET_SC", target_id, close_reason, p["Actor"])
        state.sc_self_only = self_only   -- once someone else's WS is included, this chain is no longer yours alone
        state.sc_last_kind = kind
        return
    end

    -- A miss / no-effect move does not become a chain opener (the current window is kept)
    local hit_msg = safe_num(p["Target 1 Action 1 Message"], 0)
    if NO_HIT_MESSAGES[hit_msg] then
        log_debug("PACKET_SC", string.format("No opener: %s %s (msg %d)", actor_name, ability_name(cat, param), hit_msg))
        return
    end

    -- A move that did not chain becomes the new opener. Keep all its properties in priority order (a, b, c)
    local ability = res_table[param]
    local props = {}
    if ability then
        for _, key in ipairs({"skillchain_a", "skillchain_b", "skillchain_c"}) do
            local en = ability[key]
            if en and en ~= "" then table.insert(props, sc_dict.SC_ALIAS[en] or en) end
        end
        -- Fill in trust moves whose chain properties are missing from res
        if #props == 0 and cat == 11 and not is_self then
            for _, prop in ipairs(sc_dict.TRUST_WS_EXTRA[ability.en] or {}) do table.insert(props, prop) end
        end
    end
    -- Your own aeonic WS gains the aftermath Light/Darkness (other players' weapons are unknown, so only yours)
    local lv3 = is_self and cat == 3 and ability and aeonic_prop(ability.en)
    if lv3 then table.insert(props, 1, lv3) end
    -- A move without chain properties opens no window (and the previous properties are not reused)
    if #props > 0 then
        -- Your own manual opener (not an auto WS) after the window closed starts the per-chain count over (a party member's opener does not)
        if is_self and not own_auto and not (state.sc_active and safe_lt(safe_num(os.clock(), 0), safe_num(state.sc_expiration, 0))) then
            limit.reset_run()
        end
        state.sc_active = true
        state.sc_target = target_id
        state.last_packet_sc_time = safe_num(os.clock(), 0)
        state.sc_props = props
        state.sc_property = table.concat(props, "/")
        state.sc_step = 0
        state.sc_aeonic = lv3 and true or false
        state.sc_expiration = safe_num(os.clock(), 0) + sc_window_sec(0)
        state.sc_start_time = safe_num(os.clock(), 0)
        state.sc_starter = actor_name
        state.sc_self_only = is_self   -- if the opener is yours, this chain is yours alone from here
        state.sc_last_kind = kind
        log_debug("PACKET_SC", string.format("Opener: %s from %s (Category: %d / Param: %d)", state.sc_property, actor_name, cat, param))
    end
end

-- 0x029 action message: the reason one of your actions failed (out of range, not enough TP, etc.)
local function handle_message_packet(data)
    if not state.player_id then return end
    local p = packets.parse("incoming", data)
    if not p or (p["Actor"] ~= state.player_id and p["Target"] ~= state.player_id) then return end
    local msg = safe_num(p["Message"], 0)
    -- Release the pending wait only for a refusal aimed at the pending target (or at you), not at some other target
    local pending = state.pending_ws
    if FAIL_MESSAGES[msg] and pending and p["Actor"] == state.player_id and pending.gen == state.gen
        and (p["Target"] == pending.target or p["Target"] == state.player_id) then
        log_event("WARN", "WS_FAIL", string.format("%s: %s (msg %d)", state.pending_ws.name, FAIL_MESSAGES[msg], msg))
        state.pending_ws = nil
        limit.sent_done()
        note_ws_fail(safe_num(os.clock(), 0), FAIL_MESSAGES[msg])
        -- The cancel (limit.cancel) clears unseen_until, so set it afterwards
        if FAIL_MESSAGES[msg] == "cannot see target" then state.unseen_until = safe_num(os.clock(), 0) + 2.0 end
    end
end

-- incoming chunk packet hook
-- Called for every packet, so packets we do not handle create no table or closure and are not parsed.
-- The 0x028 (action) category is bits 2-5 of byte 0x0A, 0-based (Category = 0A:2 in libs/packets/fields.lua).
-- Lua 5.1 has no bit operators, so it is taken out with division and modulo.
-- Dropped categories: 1 melee / 2 ranged / 4 magic / 5, 9 items / 8 casting start / 12 ranged start
-- (they flood in during big fights and none of them is used here)
local ACTION_DROP = {[1] = true, [2] = true, [4] = true, [5] = true, [8] = true, [9] = true, [12] = true}
local floor = math.floor
local guarded_action  = guarded("PACKET", handle_action_packet)
local guarded_message = guarded("PACKET", handle_message_packet)
-- Check the length before parsing and drop short packets (the cached choice is not touched either). Lengths from libs/packets/fields.lua:
--   0x028: the first target starts at bit 150. After ID 32 + action count 4 + the 85-bit body of action 1, bit 271 is "has added effect"
--          and bit 272 is "has spike effect" = 35 bytes. With an added effect, its 37-bit body makes it 39 bytes
--   0x029: Message is at 0x18-0x19 = 26 bytes
limit.ACTION_MIN_LEN = 35
limit.ACTION_MIN_LEN_ADDED = 39
limit.MESSAGE_MIN_LEN = 26
windower.register_event("incoming chunk", function(id, data)
    if id == 0x028 then
        if type(data) ~= "string" or #data < limit.ACTION_MIN_LEN then return end
        if not ACTION_DROP[floor(data:byte(11) / 4) % 16] then
            -- bit 271 = the top bit of byte 34 (1-based)
            if #data < limit.ACTION_MIN_LEN_ADDED and floor(data:byte(34) / 128) % 2 == 1 then return end
            guarded_action(data)
            invalidate_choice()   -- the chain state may have changed, so choose the WS again next frame
        end
    elseif id == 0x029 then
        if type(data) ~= "string" or #data < limit.MESSAGE_MIN_LEN then return end
        guarded_message(data)
        invalidate_choice()
    end
end)

-- Watch your own manual WS and hold the auto WS for a few seconds after it.
-- Outgoing 0x01A (action) is only read: never changed or blocked (the handler returns nothing).
-- Layout from libs/packets/fields.lua outgoing[0x01A]: Target 0x04-0x07, Category 0x0A-0x0B (enums.action 0x07 = Weaponskill usage),
-- Param 0x0C-0x0D (the WS ID), little-endian. Only for 0x01A, a few bytes are read without building a table
-- The auto send (input /ws) also leaves as 0x01A, so the first one for the same WS and the same target after the send mark
-- (own_out_id, own_out_target, own_out_until) is not counted (the same WS on another target is manual; a mix-up only adds a hold, never a send)
limit.OUT_ACTION_MIN_LEN = 14   -- up to Param (0x0C-0x0D)
limit.OUT_WS_CATEGORY = 7
limit.OWN_OUT_SEC = 2.0         -- a 0x01A for the same WS within this many seconds of the auto send is the auto send
limit.MANUAL_HOLD_SEC = 3.0     -- after a manual WS, no auto WS for this many seconds
function limit.note_outgoing_ws(ws_id, target_id)
    local now = safe_num(os.clock(), 0)
    if now < safe_num(state.own_out_until, 0) and (state.own_out_id == nil or state.own_out_id == ws_id)
        and state.own_out_target == target_id then
        state.own_out_until = 0   -- use up the mark (one send is counted once)
        return
    end
    state.manual_ws_until = now + limit.MANUAL_HOLD_SEC
    log_debug("MANUAL", string.format("Saw a manual WS (ID %d, target %s): no auto WS for %.1f s", ws_id, tostring(target_id), limit.MANUAL_HOLD_SEC))
end
limit.guarded_outgoing_ws = guarded("PACKET", limit.note_outgoing_ws)
windower.register_event("outgoing chunk", function(id, original, modified, injected, blocked)
    if id ~= 0x01A or blocked == true then return end
    if type(original) ~= "string" or #original < limit.OUT_ACTION_MIN_LEN then return end
    if original:byte(11) + original:byte(12) * 256 ~= limit.OUT_WS_CATEGORY then return end
    limit.guarded_outgoing_ws(original:byte(13) + original:byte(14) * 256,
        original:byte(5) + original:byte(6) * 256 + original:byte(7) * 65536 + original:byte(8) * 16777216)
end)

-- Chat modes of player speech (incoming / outgoing in res/chat.lua; 200 = system message is excluded).
-- A "Skillchain:" inside someone's speech is not a skillchain (same reading as SkillUp: the low 8 bits of the mode). Built on first use
local speech_modes = nil
local function is_speech_mode(mode)
    local m = tonumber(mode)
    if not m then return false end
    if not speech_modes then
        speech_modes = {}
        local ok, rows = pcall(function() return res.chat end)
        for _, row in pairs(ok and type(rows) == "table" and rows or {}) do
            if type(row) == "table" then
                if type(row.incoming) == "number" and row.incoming ~= 200 then speech_modes[row.incoming] = true end
                if type(row.outgoing) == "number" then speech_modes[row.outgoing] = true end
            end
        end
    end
    return speech_modes[m % 256] == true
end

-- Hold the auto WS on the area-sphere warning.
-- When the Ambuscade chapter 1 boss uses its two-hour ability, the allied Moogle says a line, and about 10 s later an
-- area sphere (HP -1000 every 3 s) appears. Melee players move away, so after reading the warning line in zone 183 or 287, no auto WS is sent
-- for sphere_hold_sec seconds (this only sends less; manual WS and commands are not stopped).
-- The line is "Moogle : <line>" (combat log of 2026-11-16). Only the speaker Moogle counts (not Nomad Moogle and the like),
-- and only the two warning lines (the walk line and the Mog House cheer are not warnings). Chat modes are not filtered
-- (the mode of NPC lines is not confirmed in game).
-- The lines were seen on the Japanese client only, so they are kept as the Japanese text (UTF-8 bytes below).
-- The English client's lines are not known, so they are not matched.
limit.SPHERE_SPEAKER = "Moogle : "
limit.SPHERE_LINES = {
    "\229\130\190\230\179\168\227\130\175\227\131\157\239\188\129\227\128\128\229\133\168\229\147\161\233\155\134\229\144\136\227\130\175\227\131\157\239\188\129\239\188\129",
    "\227\129\191\227\130\147\227\129\170\227\131\188\239\188\129\227\128\128\233\155\134\227\129\190\227\130\139\227\130\175\227\131\157\239\188\129\239\188\129",
}
limit.SPHERE_DUP_SEC = 1.0   -- a warning within this many seconds of the accepted one does not extend the hold
-- raw: the line as it arrived (Shift-JIS). What comes before the speaker is checked on these bytes, before any conversion
-- (when the second byte of a color code is 0x80 or above, the conversion can swallow the next character and break "Moogle").
-- Only the line part is converted to UTF-8 for the comparison, and only for a line that has "Moogle : "
function limit.is_sphere_line(raw)
    local p = raw:find(limit.SPHERE_SPEAKER, 1, true)
    if not p then return false end
    -- Only color codes (0x1E, 0x1F, 0x7F and the next byte), spaces and control characters may come before the speaker
    if p > 1 and (raw:sub(1, p - 1):gsub("[\30\31\127].", ""):gsub("[%c%s]", "")) ~= "" then return false end
    local body = raw:sub(p + #limit.SPHERE_SPEAKER)
    if windower.from_shift_jis then
        local conv_ok, converted = pcall(windower.from_shift_jis, body)
        if conv_ok and type(converted) == "string" then body = converted end
    end
    for _, line in ipairs(limit.SPHERE_LINES) do
        if body:find(line, 1, true) then return true end
    end
    return false
end
-- The boss's SP move ID is a warning too (in a real fight, 2 of 14 SPs came with no Moogle line).
-- 0x028 category 11 = an enemy's TP move finished (enums.action_in [11] = 'NPC TP finish' in libs/packets/fields.lua),
-- Param = the move ID. 688 Mighty Strikes, 689 Benediction, 690 Hundred Fists,
-- 691 Manafont, 692 Chainspell, 693 Perfect Dodge.
-- Only in zones 183 and 287 (Maquette Abdhaljs-LegionA/LegionB), only when the user (as get_mob_by_id returns it) is an
-- enemy (spawn_type 16, not in the party or alliance) and its name contains SPHERE_BOSS_NAME (Ambuscade chapter 1's
-- Moogle fight only; the name comes from real fight logs). No name means no hold.
-- Your own target does not matter (an SP is caught even while you target an add, a party member or nothing)
limit.SPHERE_TP_CATEGORY = 11
limit.SPHERE_TP_IDS = {[688] = true, [689] = true, [690] = true, [691] = true, [692] = true, [693] = true}
limit.SPHERE_ZONES = {[183] = true, [287] = true}
limit.SPHERE_BOSS_NAME = "Bozzetto Voyager Moogle"
-- Whether the current zone is 183 or 287 (false when it cannot be read)
function limit.in_sphere_zone()
    local info = windower.ffxi.get_info()
    return type(info) == "table" and limit.SPHERE_ZONES[info.zone] == true
end
function limit.sphere_tp(p)
    local id = p["Param"]
    if not limit.SPHERE_TP_IDS[id] then return end
    if not limit.in_sphere_zone() then return end
    local mob = windower.ffxi.get_mob_by_id(p["Actor"])
    if type(mob) ~= "table" or mob.spawn_type ~= 16 or mob.in_party or mob.in_alliance then return end
    local name = mob.name
    if type(name) ~= "string" or not name:find(limit.SPHERE_BOSS_NAME, 1, true) then return end
    limit.sphere_start(safe_num(os.clock(), 0), string.format("the boss's SP, move ID %d", id))
end
-- source: what kind of warning, for the log (the Moogle's line when left out). The chat line is the same for both kinds
function limit.sphere_start(now, source)
    local sec = limit.clamp_sphere_hold(settings.sphere_hold_sec)
    if sec <= 0 then return end   -- 0 = off
    if now - safe_num(state.sphere_line_time, -1000) < limit.SPHERE_DUP_SEC then return end
    state.sphere_line_time = now
    local extending = now < safe_num(state.sphere_hold_until, 0)
    state.sphere_hold_until = now + sec
    invalidate_choice()
    source = source or "the Moogle's line"
    if extending then
        log_event("INFO", "SPHERE", string.format("Read the area-sphere warning (%s) again: the hold now runs %g s from now", source, sec))
        return
    end
    log_event("INFO", "SPHERE", string.format("Read the area-sphere warning (%s): no auto WS for %g s", source, sec))
    chat_msg(string.format("[OmniChain] Area-sphere warning: no auto WS for %g s.", sec), 159)
end
-- Lift the hold (time is up, disengage, zone change, logout, unload, //omni sphere off). Does nothing when there is no hold
function limit.sphere_end(reason)
    state.sphere_line_time = nil
    if safe_num(state.sphere_hold_until, 0) <= 0 then return end
    state.sphere_hold_until = 0
    invalidate_choice()
    log_event("INFO", "SPHERE", "Lifted the area-sphere hold (" .. tostring(reason) .. ")")
    chat_msg(string.format("[OmniChain] Area-sphere hold lifted (%s).", tostring(reason)))
end

-- incoming text message hook
windower.register_event("incoming text", guarded("TEXT", function(original, modified, mode, modified_mode, blocked)
    if type(original) ~= "string" then return end
    local text = original
    -- The area-sphere warning is checked before the speech-mode filter (modes are not filtered; the unconverted line is passed).
    -- As with the move ID, only in zone 183 or 287 (the Ambuscade chapter 1 fight; the zone is read only when the line matches)
    if limit.is_sphere_line(original) and limit.in_sphere_zone() then limit.sphere_start(safe_num(os.clock(), 0)) end
    if not text:find("Skillchain: ", 1, true) then return end
    if is_speech_mode(mode) then return end

    -- Compare directly against the known skillchain names.
    -- (the trailing period keeps "Skillchain: Light." from matching "Skillchain: Radiance.", so the order does not matter)
    for sc_name in pairs(sc_dict.SC_ELEMENTS) do
        if text:find("Skillchain: " .. sc_name .. ".", 1, true) then
            apply_chain_result(sc_name, nil, "TEXT_SC")
            break
        end
    end
end))

-- Right after a job change the usable WS list may not be updated yet, so wait a little before checking
local function schedule_priority_check()
    if coroutine and coroutine.schedule then
        coroutine.schedule(guarded("CHECK", function() check_priority_list(true) end), 5)
    end
end

-- res.items (res/items.lua, about 5 MB) is loaded whole the first time it is touched, freezing the screen for about 0.2 s.
-- That used to happen at the first WS choice in combat (looking up the weapon name), so load it early outside combat.
-- If engaged, look again 10 s later
local function schedule_res_warmup(delay)
    if not (coroutine and coroutine.schedule) then return end
    coroutine.schedule(guarded("WARMUP", function()
        if rawget(res, "items") then return end
        local player = windower.ffxi.get_player()
        if player and safe_num(player.status, 0) == 1 then
            schedule_res_warmup(10)
            return
        end
        local start = os.clock()
        local _ = res.items
        log_debug("SYSTEM", string.format("Preloaded res.items (%.0fms)", (os.clock() - start) * 1000))
    end), delay)
end

windower.register_event("load", guarded("LOAD", function()
    update_job_profile()
    log_debug("SYSTEM", "OmniChain v" .. _addon.version .. " Loaded")
    schedule_priority_check()
    schedule_res_warmup(3)
end))
windower.register_event("login", guarded("LOGIN", function()
    update_job_profile()
    schedule_priority_check()
    schedule_res_warmup(3)
end))
windower.register_event("job change", guarded("JOB", function()
    limit.cancel()   -- do not leave the previous job's window, pending wait or waits as a condition for the next job
    update_job_profile()
    schedule_priority_check()
end))
-- On zone change and logout, drop everything that belongs to the fight in progress
-- (so properties, chainbound and timers from the previous area are not used)
-- (the per-chain count is reset too; the total limit record is not: only //omni on from OFF to ON clears it)
local function reset_battle_state()
    limit.cancel()   -- drop the window, the pending wait, chainbound and solo chain waits, and bump the generation
    limit.reset_run()
    pt_hist = {}
    state.last_sent = nil
    state.ws_fail_until = 0      -- the back-off after a refusal (a cancel keeps it; this, //omni on and a WS that goes off reset it)
    state.sent_hold_until = 0    -- the hold for a /ws without a result (after zoning, the old /ws's result never arrives)
    state.own_out_until, state.manual_ws_until = 0, 0   -- the send mark and the hold after a manual WS
    limit.sphere_end("zone change, logout or unload")   -- the area-sphere hold
    state.last_packet_sc_time = -100
    state.watch_engaged, state.watch_t_id, state.watch_incap = nil, nil, nil
    -- (the refusal count and the stop stay until a WS goes off or //omni on)
    -- End a HUD resize in progress and restore the "drag to move" paused for the corner check
    resize = nil
    if hud:draggable() ~= move_allowed then hud:draggable(move_allowed) end
end
windower.register_event("zone change", guarded("ZONE", function()
    reset_battle_state()
    flush_log()
end))
windower.register_event("logout", guarded("LOGOUT", function()
    reset_battle_state()
    state.player_id = nil
    flush_log()
end))
-- Unload cleanup. Even if a step fails, the final log flush always runs
local function unload_body()
    reset_battle_state()   -- clear the reservation and the progress
    if hud then
        if hud:draggable() ~= move_allowed then hud:draggable(move_allowed) end
        hud:hide()
    end
    if grip then grip:destroy() end
end
windower.register_event("unload", function()
    local ok, err = pcall(unload_body)
    if not ok then
        local line = tostring(err):match("^[^\n]*") or tostring(err)
        push_log_line(string.format("[%s] [ERROR] [UNLOAD] %s", os.date("%Y-%m-%d %H:%M:%S"), line))
    end
    log_debug("SYSTEM", "OmniChain Unloaded")
    flush_log(true)
end)

local function on_off_arg(arg, current)
    if arg == "on" then return true elseif arg == "off" then return false end
    return not current
end

windower.register_event("addon command", guarded("CMD", function(cmd, ...)
    invalidate_choice()   -- a setting may change, so choose the WS again next frame
    local args = {...}
    cmd = cmd and cmd:lower()
    local sub = args[1] and args[1]:lower()

    if cmd == "enable" or cmd == "on" then
        -- Clear the total limit record only when going from OFF to ON (//omni on while already ON keeps it, as in AutoSkillchain)
        if not settings.enabled then limit.total_clear() end
        settings.enabled = true
        reset_ws_fail()   -- also resumes the auto WS after it stopped on repeated refusals or a limit
        limit.reset_run()
        save_settings()
        chat_msg("[OmniChain] Auto skillchain: ON")
        log_debug("CMD", "Auto SC Enabled")

    elseif cmd == "disable" or cmd == "off" then
        settings.enabled = false
        limit.cancel()   -- cancel the reservation and the progress (so an old window is not used after turning it back ON)
        state.fail_keep_run = nil   -- and the mark left by a failure
        save_settings()
        chat_msg("[OmniChain] Auto skillchain: OFF")
        log_debug("CMD", "Auto SC Disabled")

    elseif cmd == "hud" or cmd == "gui" then
        settings.show_hud = on_off_arg(sub, settings.show_hud)
        save_settings()
        chat_msg(string.format("[OmniChain] HUD display: %s", settings.show_hud and "ON" or "OFF"))
        log_debug("CMD", "HUD Toggled: " .. tostring(settings.show_hud))

    elseif cmd == "size" and tonumber(sub) then
        local size = set_size(tonumber(sub))
        save_settings()
        chat_msg(string.format("[OmniChain] HUD font size set to %d.", size))

    elseif cmd == "log" then
        if sub == "clear" then
            monitor.buffer = {}
            local f = io.open(log_file_path, "w")
            if f then f:write("") f:close() end
            chat_msg("[OmniChain] Debug log cleared.")
        elseif sub == "on" or sub == "off" then
            settings.debug_logging = (sub == "on")
            save_settings()
            chat_msg(string.format("[OmniChain] Debug log file recording: %s", settings.debug_logging and "ON" or "OFF"))
        elseif sub == "tail" or sub == "err" then
            -- Show recent events in chat (err = ERROR/WARN only)
            local n = math.max(1, math.min(30, tonumber(args[2]) or 10))
            local picked = {}
            for i = #monitor.recent, 1, -1 do
                local e = monitor.recent[i]
                if sub == "tail" or e.level == "ERROR" or e.level == "WARN" then
                    table.insert(picked, 1, e)
                    if #picked >= n then break end
                end
            end
            chat_msg(string.format("=== OmniChain last %d entries (%s) ===", #picked, sub == "err" and "errors/warnings" or "all"))
            for _, e in ipairs(picked) do
                chat_msg(string.format("%s [%s][%s] %s", e.time, e.level, e.cat, utf8_trim(e.msg, 120)), LEVEL_CHAT_COLORS[e.level] or 207)
            end
        else
            flush_log(true)
            chat_msg(string.format("[OmniChain] Debug log: %s (file: %s)", settings.debug_logging and "ON" or "OFF", log_file_path))
            chat_msg(string.format("[OmniChain] Counts since load ERROR:%d WARN:%d INFO:%d",
                monitor.counts.ERROR or 0, monitor.counts.WARN or 0, monitor.counts.INFO or 0))
        end

    elseif cmd == "check" then
        if check_priority_list(false) then
            chat_msg(string.format("[OmniChain] All %d WS in the %s priority list are usable.", #state.ws_priority, state.active_job))
        end

    elseif cmd == "start" then
        if sub == "manual" or sub == "auto" then
            settings.start_mode = sub
            save_settings()
        end
        chat_msg(settings.start_mode == "manual"
            and string.format("[OmniChain] Opener: manual (you open the first chain. The auto WS follows %.1f s after someone's opener)", safe_num(settings.follow_wait, 6.0))
            or "[OmniChain] Opener: auto (the first WS is also automatic)")
        log_debug("CMD", "Start mode: " .. tostring(settings.start_mode))

    elseif cmd == "wait" then
        local sec = tonumber(sub)
        if sec and sec >= 0 and sec <= 9 then
            settings.follow_wait = sec
            save_settings()
        elseif sub then
            chat_msg("[OmniChain] Wait must be 0-9 seconds (the chain window is at most 10 s).")
        end
        chat_msg(string.format("[OmniChain] Manual opener wait: %.1f s", safe_num(settings.follow_wait, 6.0)))

    elseif cmd == "minfollow" then
        -- Minimum seconds from the previous WS to the next auto WS: //omni minfollow <seconds>
        local sec = tonumber(sub)
        if sec and sec >= MIN_FOLLOW_FLOOR and sec <= 8 then
            settings.min_follow = sec
            save_settings()
        elseif sub then
            chat_msg("[OmniChain] Seconds must be 4-8 (e.g. //omni minfollow 4).")
        end
        chat_msg(string.format("[OmniChain] Minimum from the previous WS to the next auto WS: %.1f s", math.max(MIN_FOLLOW_FLOOR, safe_num(settings.min_follow, MIN_FOLLOW_FLOOR))))
        log_debug("CMD", "Min follow: " .. tostring(settings.min_follow))

    elseif cmd == "focuspeople" then
        -- Number of people (including you) for the max-power WS: //omni focuspeople <number>
        local v = tonumber(sub)
        if v and v >= 2 and v <= 18 then
            settings.focus_people = math.floor(v)
            save_settings()
        elseif sub then
            chat_msg("[OmniChain] Number must be 2-18 (e.g. //omni focuspeople 3).")
        end
        chat_msg(string.format("[OmniChain] Max-power WS when %d or more people (including you) target the same enemy", safe_num(settings.focus_people, 3)))
        log_debug("CMD", "Focus people: " .. tostring(settings.focus_people))

    elseif cmd == "focustp" then
        -- TP at which the max-power WS is used: //omni focustp <TP>
        local v = tonumber(sub)
        if v and v >= 1000 and v <= 3000 then
            settings.focus_tp = v
            save_settings()
        elseif sub then
            chat_msg("[OmniChain] TP must be 1000-3000 (e.g. //omni focustp 1500).")
        end
        chat_msg(string.format("[OmniChain] Max-power WS at TP %d or more", safe_num(settings.focus_tp, 1500)))
        log_debug("CMD", "Focus TP: " .. tostring(settings.focus_tp))

    elseif cmd == "focus" then
        -- Max-power WS when many people target the same enemy: //omni focus [on|off]
        if sub == "on" or sub == "off" then
            settings.focus_max = (sub == "on")
            save_settings()
        end
        chat_msg(string.format("[OmniChain] Max-power WS when everyone is on the same enemy: %s (prime weapon: its WS; otherwise the empyrean WS. Dojikiri Yasutsuna uses Tachi: Shoha)",
            settings.focus_max ~= false and "ON" or "OFF"))
        log_debug("CMD", "Focus: " .. tostring(settings.focus_max))

    elseif cmd == "toss" then
        -- Tossing to party members: //omni toss [on|off]
        if sub == "on" or sub == "off" then
            settings.toss = (sub == "on")
            save_settings()
        end
        chat_msg(string.format("[OmniChain] Toss to party members: %s (only when close: predicts their next WS and matches the property)",
            settings.toss ~= false and "ON" or "OFF"))
        log_debug("CMD", "Toss: " .. tostring(settings.toss))

    elseif cmd == "reach" then
        -- Distance at which melee WS may be used (the number shown by distanceplus): //omni reach <distance>
        local d = tonumber(sub)
        if d and d >= 1 and d <= 8 then
            settings.ws_reach = d
            save_settings()
        elseif sub then
            chat_msg("[OmniChain] Distance must be 1-8 (e.g. //omni reach 3.5).")
        end
        chat_msg(string.format("[OmniChain] Melee WS used at distance %.1f or less (the distanceplus number)", safe_num(settings.ws_reach, 3.5)))
        log_debug("CMD", "WS reach: " .. tostring(settings.ws_reach))

    elseif cmd == "solo" then
        -- Waiting for trusts' solo chains: //omni solo [on|off] / start <seconds> / gap <seconds>
        local sec = tonumber(args[2])
        if sub == "start" or sub == "gap" then
            if sec and sec >= 1 and sec <= 30 then
                if sub == "start" then settings.solo_start_wait = sec else settings.solo_gap = sec end
                save_settings()
            else
                chat_msg("[OmniChain] Seconds must be 1-30 (e.g. //omni solo gap 6).")
            end
        elseif sub == "on" or sub == "off" then
            settings.trust_solo = (sub == "on")
            if not settings.trust_solo then state.solos = {} end
            save_settings()
        end
        chat_msg(string.format("[OmniChain] Wait for trusts' solo chains: %s (%.1f s after the ability / %.1f s between WS)",
            settings.trust_solo ~= false and "ON" or "OFF", safe_num(settings.solo_start_wait, 12.0), safe_num(settings.solo_gap, 11.0)))
        log_debug("CMD", "Trust solo wait: " .. tostring(settings.trust_solo))

    elseif cmd == "sphere" then
        -- Seconds of no auto WS after the area-sphere warning (the Moogle's line): //omni sphere <seconds|off|on>
        local sec = tonumber(sub)
        if sec and sec >= 0 and sec <= 60 then
            settings.sphere_hold_sec = sec
            save_settings()
        elseif sub == "off" then
            settings.sphere_hold_sec = 0
            save_settings()
        elseif sub == "on" then
            if limit.clamp_sphere_hold(settings.sphere_hold_sec) <= 0 then settings.sphere_hold_sec = limit.SPHERE_DEFAULT_SEC end
            save_settings()
        elseif sub then
            chat_msg("[OmniChain] Seconds must be 0-60 (0 or off turns it off; e.g. //omni sphere 20).")
        end
        local hold = limit.clamp_sphere_hold(settings.sphere_hold_sec)
        if hold <= 0 then limit.sphere_end("//omni sphere off") end
        chat_msg(hold > 0 and string.format("[OmniChain] No auto WS after the area-sphere warning for: %g s", hold)
            or "[OmniChain] Hold on the area-sphere warning: OFF")
        log_debug("CMD", "Sphere hold: " .. tostring(settings.sphere_hold_sec))

    elseif cmd == "reload" or cmd == "load" then
        local status, detail = update_job_profile()
        local weapon = state.active_weapon ~= "" and state.active_weapon or "not set"
        if status == "ok" then
            chat_msg(string.format("[OmniChain] Settings file reloaded (%s). (Job: %s / Weapon: %s)", tostring(detail), state.active_job, weapon))
        elseif status == "none" then
            chat_msg(string.format("[OmniChain] No omnichain_config.json found; using the built-in profiles. (Job: %s / Weapon: %s)", state.active_job, weapon))
        else
            chat_msg(string.format("[OmniChain] Failed to load omnichain_config.json: %s (Job: %s / Weapon: %s)", tostring(detail), state.active_job, weapon), 167)
        end

    elseif cmd == "status" then
        chat_msg("=== OmniChain settings ===")
        chat_msg(string.format("Status: %s / Min TP: %d / HUD: %s", settings.enabled and "ON" or "OFF", safe_num(settings.min_tp, 1000), settings.show_hud and "ON" or "OFF"))
        chat_msg(string.format("Opener: %s", settings.start_mode == "manual"
            and string.format("manual (wait %.1f s)", safe_num(settings.follow_wait, 6.0)) or "auto"))
        chat_msg(string.format("Wait for trusts' solo chains: %s (%.1f s after the ability / %.1f s between WS)",
            settings.trust_solo ~= false and "ON" or "OFF", safe_num(settings.solo_start_wait, 12.0), safe_num(settings.solo_gap, 11.0)))
        chat_msg(string.format("Current job: %s / Weapon type: %s", state.active_job, state.active_weapon))
        chat_msg(string.format("WS priority: %s", table.concat(state.ws_priority, " > ")))

    else
        chat_msg("=== OmniChain command help ===")
        chat_msg("//omni enable / disable       : turn auto skillchain ON / OFF (on also resumes a stopped auto WS)")
        chat_msg("//omni start manual / auto    : open the first chain yourself / let the addon do it")
        chat_msg("//omni wait <sec>             : in manual-opener mode, seconds to wait before the auto WS (0-9, default 6)")
        chat_msg("//omni minfollow <sec>        : minimum seconds from the previous WS to the next auto WS (4-8, default 4)")
        chat_msg("//omni solo [on|off]          : wait for trusts' solo chains to finish (tune with start <sec> / gap <sec>, 1-30)")
        chat_msg("//omni focus [on|off]         : max-power WS when many people target the same enemy (default ON)")
        chat_msg("//omni focuspeople <n>        : people (you included) needed for the max-power WS (2-18, default 3)")
        chat_msg("//omni focustp <TP>           : TP for the max-power WS (1000-3000, default 1500)")
        chat_msg("//omni toss [on|off]          : pick a WS a party member can follow with their next WS (default ON)")
        chat_msg("//omni reach <distance>       : distance for melee WS (1-8, default 3.5)")
        chat_msg("//omni sphere <sec|off|on>    : seconds of no auto WS after the area-sphere warning (the Moogle's line; 0-60, default 20)")
        chat_msg("//omni hud [on|off]           : show / hide the HUD overlay")
        chat_msg("//omni size <n>               : HUD font size (6-40). Also by mouse wheel over the HUD / dragging its bottom-right corner")
        chat_msg("//omni log [on|off|clear]     : toggle / clear the log file")
        chat_msg("//omni log tail [n] / err [n] : show recent entries / errors and warnings in chat")
        chat_msg("//omni check                  : check that the WS in the priority list are usable")
        chat_msg("//omni reload                 : reload the JSON config file")
        chat_msg("//omni status                 : show the current settings")
        chat_msg("See addons/OmniChain/COMMANDS.txt for details")
    end
end))

-- =============================================================================
-- OmniChain.lua : auto-skillchain addon for all 22 jobs and all 14 weapon types (v7.4.2 - max-power WS when many people target the same enemy)
-- =============================================================================

_addon.name     = "OmniChain"
_addon.author   = "hikaruoshino"
_addon.version  = "7.4.2"
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
defaults.party_sync = true
defaults.auto_mode = "flexible" -- "flexible", "strict", "lead_only"
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

local monitor = {
    buffer = {},          -- lines not yet written to the file
    last_flush = 0,
    recent = {},          -- recent events {time, level, cat, msg}
    counts = {ERROR = 0, WARN = 0, INFO = 0},
    throttle = {},        -- chat throttling: key -> {time, suppressed}
}

local LEVEL_CHAT_COLORS = {ERROR = 167, WARN = 159}

local function flush_log(force)
    local buf = monitor.buffer
    monitor.last_flush = os.clock()
    if #buf == 0 then return end
    if not settings.debug_logging then
        monitor.buffer = {}
        return
    end
    local f = io.open(log_file_path, "a")
    if not f then return end
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
        monitor.throttle[key] = {time = clock, suppressed = 0}
    end

    monitor.buffer[#monitor.buffer + 1] = string.format("[%s] [%s] [%s] %s", os.date("%Y-%m-%d %H:%M:%S"), level, category, message)

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
                monitor.buffer[#monitor.buffer + 1] = tostring(err)
                flush_log(true)
            end
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

-- Auto-load the file exported by the Web Config Editor (omnichain_config.json)
local function load_external_json_config()
    local json_paths = {
        windower.addon_path .. "omnichain_config.json",
        windower.addon_path .. "data/omnichain_config.json",
    }

    for _, path in ipairs(json_paths) do
        local f = io.open(path, "r")
        if f then
            local content = f:read("*all")
            f:close()
            if content and content ~= "" then
                local jok, json = pcall(require, "json")
                if jok and json and json.parse then
                    -- Windower's libs/json.lua uses parse, not decode (on failure: nil, error text)
                    local parse_ok, res_obj, parse_err = pcall(json.parse, content)
                    if not parse_ok or type(res_obj) ~= "table" then
                        log_event("WARN", "CONFIG", string.format("JSON parse failed (%s): %s", path, tostring(parse_ok and parse_err or res_obj)))
                    else
                        if res_obj.min_tp ~= nil then
                            settings.min_tp = safe_num(res_obj.min_tp, 1000)
                        end
                        if res_obj.wait_delay ~= nil then
                            settings.wait_delay = safe_num(res_obj.wait_delay, 1.2)
                        end
                        if res_obj.profiles and type(res_obj.profiles) == "table" then
                            for job, data in pairs(res_obj.profiles) do
                                local ws_list = type(data) == "table" and sanitize_ws_list(data.ws_priority) or {}
                                if data.weapon and #ws_list > 0 then
                                    profiles[job] = {
                                        weapon = tostring(data.weapon),
                                        ws_priority = ws_list,
                                        opener_only = data.opener_only == true
                                    }
                                end
                            end
                        end
                        log_debug("CONFIG", "Loaded external JSON config successfully from: " .. path)
                        return true
                    end
                end
            end
        end
    end
    return false
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
}

-- Warn if an auto-executed WS gets no response within this many seconds (wrong WS name, not learned, input error, etc.)
local PENDING_WS_TIMEOUT = 4.0

-- Is it in sc_dict? (find_ws_info returns a default even for unknown WS, so check separately)
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
-- Returns: true if it reaches; otherwise false plus (distance, reach). Returns true when it cannot be determined
local function ws_in_range(ws_name)
    local id = ws_id_by_name(ws_name)
    local ws = id and res and res.weapon_skills and res.weapon_skills[id]
    local mult = ws and WS_RANGE_MULT[ws.range]
    if not mult then return true end
    local t = windower.ffxi.get_mob_by_target('t')
    if ws.range == 2 then
        if not t or not t.distance then return true end
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
    local me = windower.ffxi.get_mob_by_target('me') or windower.ffxi.get_player()
    if not t or not t.distance or not t.model_size then return true end
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
    local player = windower.ffxi.get_player()
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

-- Warn if a WS is not in the dictionary / not in res / not usable right now (returns true if there is no problem)
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
        log_event("WARN", category, string.format("WS not in sc_dict: %s (skillchain matching will use defaults)", ws_name))
        good = false
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
local move_allowed = settings.flags == nil or settings.flags.draggable ~= false  -- original "drag to move" setting

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

-- Restore the "drag to move" that was paused for the corner check, then save
local function save_hud_settings()
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

local function update_job_profile()
    load_external_json_config()

    local player = windower.ffxi.get_player()
    if player then state.player_id = player.id end
    if player and player.main_job then
        state.active_job = tostring(player.main_job)
        if profiles[state.active_job] then
            state.active_weapon = tostring(profiles[state.active_job].weapon or "Sword")
            state.ws_priority = sanitize_ws_list(profiles[state.active_job].ws_priority)
            state.opener_only = profiles[state.active_job].opener_only == true
        end
        log_debug("PROFILE", string.format("Job Profile Updated: %s (Weapon: %s)", state.active_job, state.active_weapon))
    end
end

-- Can it be used with /ws right now? Excludes pet skills, names not in res, and WS not learned / wrong weapon
local function is_executable_ws(ws_name, usable)
    if is_pet_skill(ws_name) then return false end
    local id = ws_id_by_name(ws_name)
    if not id then return not (res and res.weapon_skills) end
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
        -- Chainbound is waiting for an ally's WS (Ark GK also uses it when out of TP), so use it as soon as the window opens.
        -- The earlier chain state was overwritten by the chainbound, so the chain-window wait is not used
        return math.max(0, safe_num(cb.start_time, 0) + SC_OPEN_SEC - now)
    end
    local window_on_other = false
    if state.sc_active and state.sc_target then
        -- If the enemy with the skillchain differs from the current one (moved on to another enemy, etc.), do not wait for that chain
        local t = windower.ffxi.get_mob_by_target('t')
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
    for actor_id, solo in pairs(state.solos) do
        local left = safe_num(solo.until_time, 0) - now
        if left <= 0 then
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
        local t = windower.ffxi.get_mob_by_target('t')
        if t and t.id ~= state.sc_target then is_sc_window = false end
    end

    -- The top usable WS (used as the opener / continuation when there is no chain)
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
        local t = windower.ffxi.get_mob_by_target('t')
        if t and t.id == cb.target then
            local aftermath = has_aftermath()
            local best
            for idx, ws_name in ipairs(state.ws_priority) do
                local info = is_executable_ws(ws_name, usable) and sc_dict.find_ws_info(ws_name, state.active_weapon)
                if info and info.sc and info.sc[1] then
                    local result, score = nil, 0
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
    for actor_id, h in pairs(pt_hist) do
        local n = #h.times
        if n == 0 or now - h.times[n] > PT_HIST_AGE then
            pt_hist[actor_id] = nil
        elseif n >= 3 then
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
        local t = windower.ffxi.get_mob_by_target('t')
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
    ["Great Katana"] = "Tachi: Fudo",   ["Club"] = "Dagan",         ["Staff"] = "Myrkr",
    ["Archery"] = "Jishnu's Radiance",     ["Marksmanship"] = "Wildfire",
}
local focus_cache = {time = -1, value = false}
local FOCUS_PARTY_KEYS = {"p1", "p2", "p3", "p4", "p5", "a10", "a11", "a12", "a13", "a14", "a15",
    "a20", "a21", "a22", "a23", "a24", "a25"}

local function all_same_target()
    local now = safe_num(os.clock(), 0)
    if now - focus_cache.time < 0.5 then return focus_cache.value end
    focus_cache.time = now
    local value, desc = false, "no target"
    local t = windower.ffxi.get_mob_by_target('t')
    local party = windower.ffxi.get_party()
    local me = windower.ffxi.get_player()
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
        log_debug("FOCUS", string.format("Many people on the same enemy: %s (%s)", value and "yes" or "no", desc))
    end
    focus_cache.value = value
    return value
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

local function find_best_ws_from_priority()
    local focus = focus_choice()
    if focus then return focus end
    local base = find_base_ws_from_priority()
    local tossed = toss_override(base)
    return tossed or base
end

-- Auto-skillchain decision and automatic WS execution (runs whether or not the HUD is shown)
local function process_auto_skillchain()
    local player = windower.ffxi.get_player()
    if not player or safe_num(player.status, 0) ~= 1 then return end

    local now = safe_num(os.clock(), 0)
    local tp = safe_num(player.vitals and player.vitals.tp, 0)
    local min_tp = safe_num(settings.min_tp, 1000)
    local wait_delay = safe_num(settings.wait_delay, 1.2)
    local last_ws = safe_num(state.last_ws_time, 0)

    if settings.enabled and safe_gte(tp, min_tp) and safe_gt(now - last_ws, wait_delay) then
        local choice = find_best_ws_from_priority()
        -- Do not interrupt while a trust is doing a solo chain (use the WS after it ends)
        if choice and (choice.no_wait or follow_wait_left(now, tp) <= 0) and solo_wait_left(now) <= 0
            and not (choice.min_tp and not safe_gte(tp, choice.min_tp)) then
            -- Wait 2 s right after the game refuses with "cannot see target" (since 2026-10-24 valid_target is no longer used as a pre-check:
            -- on big enemies such as Awoken Hakenmann or Morbol Emperor it stayed false, or flipped between true and false, and the auto WS stopped even though a manual WS worked)
            if now < safe_num(state.unseen_until, 0) then return end
            local in_range, dist, reach = ws_in_range(choice.ws)
            if not in_range then
                -- Do not use it until it reaches. The log line is limited to every 3 s
                if now - safe_num(state.range_log_time, 0) >= 3.0 then
                    state.range_log_time = now
                    log_debug("RANGE", string.format("%s is too far, not using it (distance %.1f / reach %.1f)", choice.ws, dist, reach))
                end
                return
            end
            state.last_ws_time = now
            state.pending_ws = {name = choice.ws, time = now, tp = tp}
            check_ws_usable(choice.ws, "EXECUTE")
            log_debug("EXECUTE", string.format("Executing WS: %s (%s) [TP: %d / AM: %s / after chain #%d / %.1f s since previous WS]", choice.ws, choice.reason, tp,
                has_aftermath() and "yes" or "no", safe_num(state.sc_step, 0), now - safe_num(state.sc_start_time, now)))
            chat_msg(string.format("[OmniChain] Auto WS: %s (%s)", choice.ws, choice.reason), 158)
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
    end
end

windower.register_event("prerender", guarded("PRERENDER", function()
    local frame_start = os.clock()

    -- WS response timeout / periodic log flush
    check_pending_ws(frame_start)
    if frame_start - monitor.last_flush > LOG_FLUSH_SEC then flush_log() end

    local ok, err = xpcall(function()
        -- Background auto-skillchain decision
        process_auto_skillchain()

        -- Draw the HUD overlay
        if not settings.show_hud then
            hud:hide()
            grip:hide()
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

        if state.sc_active and safe_lt(now, sc_exp) then
            local rem_time = math.max(0.0, sc_exp - now)
            table.insert(lines, string.format("Active chain: %s (%.1fs left / %s)", color_text(state.sc_property, 255, 200, 50), rem_time, state.sc_starter))
        else
            state.sc_active = false
            table.insert(lines, string.format("Chain window: %s", color_text("waiting (Idle)", 180, 180, 180)))
        end

        local player = windower.ffxi.get_player()
        if player and safe_num(player.status, 0) == 1 then
            local tp = safe_num(player.vitals and player.vitals.tp, 0)
            table.insert(lines, string.format("TP: %s / min %d", color_text(tostring(tp), safe_gte(tp, min_tp) and 50 or 255, 255, 100), min_tp))

            local solo_left, solo_name = solo_wait_left(now)
            if solo_left > 0 then
                table.insert(lines, string.format("Waiting on solo chain: %s (%.1fs left)", color_text(tostring(solo_name), 255, 160, 220), solo_left))
            end

            local choice = find_best_ws_from_priority()
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
        hud:text(table.concat(lines, string.char(10)))
        hud:show()
        update_grip()
    end, traceback)

    if not ok then
        -- The same error would appear every frame, so chat is grouped every 10 s on the log_event side
        -- Only when it was recorded (not throttled) is the trace also written to the file
        if log_event("ERROR", "PRERENDER", tostring(err):match("^[^\n]*") or tostring(err)) then
            monitor.buffer[#monitor.buffer + 1] = tostring(err)
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
            save_hud_settings()
            return true
        end

    elseif mtype == MOUSE_WHEEL then
        if hud:hover(x, y) then
            local step = safe_num(delta, 0) > 0 and 1 or -1
            set_size(current_size() + step)
            save_hud_settings()
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

local function clear_sc_state()
    state.sc_active = false
    state.sc_property = nil
    state.sc_props = nil
    state.sc_expiration = 0
    state.sc_starter = ""
    state.sc_target = nil
    state.sc_step = 0
    state.sc_aeonic = false
    state.solo_just_ended = false
    state.sc_self_only = false
end

-- The chat line "Skillchain: <name>" can arrive several seconds (measured 4-7 s) after the packet.
-- After updating the chain state from a packet, chat is ignored for this many seconds and used only as a fallback when a packet is missed
local TEXT_SC_IGNORE_SEC = 10.0

-- A chain occurred: for the next step only the chain that occurred is A1 (wiki: from the 3rd chain on, the other properties of the previous WS are ignored)
-- close_reason: when it is known that the chain cannot be continued, the reason (the chain ends and the next one starts from an opener)
local function apply_chain_result(sc_name, starter, source, target_id, close_reason)
    local now = safe_num(os.clock(), 0)
    if source == "TEXT_SC" and safe_lt(now, safe_num(state.last_packet_sc_time, -100) + TEXT_SC_IGNORE_SEC) then
        log_debug(source, string.format("Ignored (packet is newer): %s", sc_name))
        return
    end
    -- The same chain arrives by both packet and chat, so ignore an immediate duplicate
    if state.last_chain_name == sc_name and safe_lt(now, safe_num(state.last_chain_time, 0) + 1.5) then return end

    -- A Light/Darkness WS stacked on an opener's Light/Darkness (aeonic) also ends as Light->Light / Darkness->Darkness (confirmed in game)
    local prev = state.sc_active and state.sc_props and state.sc_props[1] or nil
    state.last_chain_name = sc_name
    state.last_chain_time = now
    if source == "PACKET_SC" then state.last_packet_sc_time = now end

    -- A chain made by the last move of a trust's solo chain does not chain even if you stack your own WS
    -- (measured 2026-10-10: Fudo used 3.2 s and 5 s after the Light from Iroha's Gachirin did not chain either time).
    -- So the chain ends here and the next one is rebuilt from an opener
    if state.solo_just_ended then close_reason = close_reason or "last move of a trust's solo chain" end
    if close_reason then
        clear_sc_state()
        log_debug(source, string.format("Chain closed: %s (%s; starting over from an opener)", sc_name, close_reason))
        return
    end

    if sc_dict.is_terminal_chain(prev, sc_name) then
        -- After Light->Light / Darkness->Darkness, or after Radiance/Umbra, no WS chains
        clear_sc_state()
        state.solos = {}   -- the trusts' solo chains end here as well
        log_debug(source, string.format("Chain closed: %s (prev: %s)", sc_name, tostring(prev)))
        return
    end

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
local function track_trust_solo_ws(actor_id, ws_name)
    local solo = state.solos[actor_id]
    if not solo then return end
    solo.count = solo.count + 1
    for _, last in ipairs(solo.last_ws or {}) do
        if last == ws_name then
            log_debug("TRUST_SOLO", string.format("Wait over: %s's solo chain reached its last move %s (%d WS)", solo.name, ws_name, solo.count))
            state.solos[actor_id] = nil
            state.solo_just_ended = true   -- do not continue the chain made by this move (apply_chain_result closes it)
            return
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

-- Match your own WS result against the auto-execution record
local function track_own_action(p, cat)
    local pending = state.pending_ws
    if cat == 3 then
        local ws_id = safe_num(p["Param"], 0)
        local msg = safe_num(p["Target 1 Action 1 Message"], 0)
        local dmg = safe_num(p["Target 1 Action 1 Param"], 0)
        local name = ability_name(3, ws_id)
        local result = (msg == 188 and "miss") or (msg == 189 and "no effect") or string.format("%d damage", dmg)
        local level = (msg == 188 or msg == 189) and "WARN" or "INFO"
        local src = pending and "auto" or "manual"
        log_event(level, "WS_RESULT", string.format("[%s] %s → %s", src, name, result))
        if pending and pending.name ~= name and ws_id_by_name(pending.name) ~= ws_id then
            log_event("WARN", "WS_RESULT", string.format("A different WS fired (%s) than the one sent (%s)", name, pending.name))
        end
        state.pending_ws = nil
    elseif cat == 7 and safe_num(p["Param"], 0) == WS_READY_INTERRUPT then
        log_event("WARN", "WS_FAIL", string.format("%s was interrupted", pending and pending.name or "WS"))
        state.pending_ws = nil
    end
end

local function handle_action_packet(data)
    local p = packets.parse("incoming", data)
    if not p then
        log_event("WARN", "PACKET", "Failed to parse 0x028")
        return
    end
    local cat = safe_num(p["Category"], 0)
    -- Chainbound (msg 529 "is chainbound"): the next WS always chains
    if safe_num(p["Target 1 Action 1 Message"], 0) == CHAINBOUND_MESSAGE then
        local who = windower.ffxi.get_mob_by_id(p["Actor"])
        local cb_now = safe_num(os.clock(), 0)
        state.chainbound = {target = p["Target 1 ID"], start_time = cb_now, until_time = cb_now + CHAINBOUND_SEC}
        log_debug("PACKET_SC", string.format("Chainbound: %s used Chainbound (the first WS from about 3 s later will chain)", tostring(who and who.name or p["Actor"])))
        return
    end
    if cat == JOB_ABILITY_CATEGORY then
        handle_trust_ability(p)
        return
    end
    if not CATEGORY_NAMES[cat] then return end

    -- Some abilities such as jumps arrive in category 3, the same as WS (the number is the ability's).
    -- Reading it as a WS number would give another move and create a false opener, so it is not treated as a WS
    if cat == 3 and JA_RESULT_MESSAGES[safe_num(p["Target 1 Action 1 Message"], 0)] then
        return
    end

    local is_self = state.player_id ~= nil and p["Actor"] == state.player_id
    if is_self then track_own_action(p, cat) end

    local actor_mob = windower.ffxi.get_mob_by_id(p["Actor"])
    local outsider = not is_party_actor(actor_mob)
    if outsider then
        -- Even someone outside the party: a move used on the enemy you are targeting affects the chain (enemies fought together with outsiders)
        local t = (cat == 3 or cat == 11) and actor_mob and windower.ffxi.get_mob_by_target("t")
        if not (t and t.id == p["Target 1 ID"] and t.id ~= p["Actor"]) then return end
    elseif not is_self and (cat == 3 or cat == 11) then
        -- Even a party member: a move on an enemy different from the one you are targeting does not affect the chain
        -- (in places like Limbus where many enemies are linked and killed one by one, your allies are fighting other enemies)
        local t = windower.ffxi.get_mob_by_target("t")
        if t and t.id ~= p["Target 1 ID"] then
            state.other_mob_ignored = safe_num(state.other_mob_ignored, 0) + 1
            return
        end
    end
    local actor_name = (outsider and "(outside PT) " or "") .. tostring(actor_mob.name or "")
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
    if not is_self and not (solo_msg == 238 or solo_msg == 194 or solo_msg == 159) then
        track_trust_solo_ws(p["Actor"], ability_name(cat, param))
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
        apply_chain_result(chain, actor_name, "PACKET_SC", target_id, close_reason)
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
        state.sc_active = true
        state.sc_target = target_id
        state.last_packet_sc_time = safe_num(os.clock(), 0)
        state.sc_props = props
        state.sc_property = table.concat(props, "/")
        state.sc_step = 0
        state.sc_aeonic = lv3 and true or false
        state.solo_just_ended = false
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
    if FAIL_MESSAGES[msg] and state.pending_ws and p["Actor"] == state.player_id then
        log_event("WARN", "WS_FAIL", string.format("%s: %s (msg %d)", state.pending_ws.name, FAIL_MESSAGES[msg], msg))
        state.pending_ws = nil
        if FAIL_MESSAGES[msg] == "cannot see target" then state.unseen_until = safe_num(os.clock(), 0) + 2.0 end
    end
end

-- incoming chunk packet hook
windower.register_event("incoming chunk", guarded("PACKET", function(id, data, modified, injected, blocked)
    id = safe_num(id, 0)
    if id == 0x028 then
        handle_action_packet(data)
    elseif id == 0x029 then
        handle_message_packet(data)
    end
end))

-- incoming text message hook
windower.register_event("incoming text", guarded("TEXT", function(original, modified, mode, modified_mode, blocked)
    if not original then return end
    local text = original
    if not text:find("Skillchain: ", 1, true) then return end

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

windower.register_event("load", guarded("LOAD", function()
    update_job_profile()
    log_debug("SYSTEM", "OmniChain v" .. _addon.version .. " Loaded")
    schedule_priority_check()
end))
windower.register_event("login", guarded("LOGIN", function()
    update_job_profile()
    schedule_priority_check()
end))
windower.register_event("job change", guarded("JOB", function()
    update_job_profile()
    schedule_priority_check()
end))
-- Discard the chain window on zone change (so properties from the previous area are not used)
windower.register_event("zone change", guarded("ZONE", function()
    clear_sc_state()
    pt_hist = {}
    state.pending_ws = nil
    state.solos = {}
    flush_log()
end))
windower.register_event("logout", guarded("LOGOUT", function()
    clear_sc_state()
    pt_hist = {}
    state.pending_ws = nil
    state.solos = {}
    state.player_id = nil
    flush_log()
end))
windower.register_event("unload", function()
    if hud then
        if hud:draggable() ~= move_allowed then hud:draggable(move_allowed) end
        hud:hide()
    end
    if grip then grip:destroy() end
    log_debug("SYSTEM", "OmniChain Unloaded")
    flush_log(true)
end)

local function on_off_arg(arg, current)
    if arg == "on" then return true elseif arg == "off" then return false end
    return not current
end

windower.register_event("addon command", guarded("CMD", function(cmd, ...)
    local args = {...}
    cmd = cmd and cmd:lower()
    local sub = args[1] and args[1]:lower()

    if cmd == "enable" or cmd == "on" then
        settings.enabled = true
        config.save(settings)
        chat_msg("[OmniChain] Auto skillchain: ON")
        log_debug("CMD", "Auto SC Enabled")

    elseif cmd == "disable" or cmd == "off" then
        settings.enabled = false
        config.save(settings)
        chat_msg("[OmniChain] Auto skillchain: OFF")
        log_debug("CMD", "Auto SC Disabled")

    elseif cmd == "hud" or cmd == "gui" then
        settings.show_hud = on_off_arg(sub, settings.show_hud)
        config.save(settings)
        chat_msg(string.format("[OmniChain] HUD display: %s", settings.show_hud and "ON" or "OFF"))
        log_debug("CMD", "HUD Toggled: " .. tostring(settings.show_hud))

    elseif cmd == "size" and tonumber(sub) then
        local size = set_size(tonumber(sub))
        save_hud_settings()
        chat_msg(string.format("[OmniChain] HUD font size set to %d.", size))

    elseif cmd == "log" then
        if sub == "clear" then
            monitor.buffer = {}
            local f = io.open(log_file_path, "w")
            if f then f:write("") f:close() end
            chat_msg("[OmniChain] Debug log cleared.")
        elseif sub == "on" or sub == "off" then
            settings.debug_logging = (sub == "on")
            config.save(settings)
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
            config.save(settings)
        end
        chat_msg(settings.start_mode == "manual"
            and string.format("[OmniChain] Opener: manual (you open the first chain. The auto WS follows %.1f s after someone's opener)", safe_num(settings.follow_wait, 6.0))
            or "[OmniChain] Opener: auto (the first WS is also automatic)")
        log_debug("CMD", "Start mode: " .. tostring(settings.start_mode))

    elseif cmd == "wait" then
        local sec = tonumber(sub)
        if sec and sec >= 0 and sec <= 9 then
            settings.follow_wait = sec
            config.save(settings)
        elseif sub then
            chat_msg("[OmniChain] Wait must be 0-9 seconds (the chain window is at most 10 s).")
        end
        chat_msg(string.format("[OmniChain] Manual opener wait: %.1f s", safe_num(settings.follow_wait, 6.0)))

    elseif cmd == "minfollow" then
        -- Minimum seconds from the previous WS to the next auto WS: //omni minfollow <seconds>
        local sec = tonumber(sub)
        if sec and sec >= MIN_FOLLOW_FLOOR and sec <= 8 then
            settings.min_follow = sec
            config.save(settings)
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
            config.save(settings)
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
            config.save(settings)
        elseif sub then
            chat_msg("[OmniChain] TP must be 1000-3000 (e.g. //omni focustp 1500).")
        end
        chat_msg(string.format("[OmniChain] Max-power WS at TP %d or more", safe_num(settings.focus_tp, 1500)))
        log_debug("CMD", "Focus TP: " .. tostring(settings.focus_tp))

    elseif cmd == "focus" then
        -- Max-power WS when many people target the same enemy: //omni focus [on|off]
        if sub == "on" or sub == "off" then
            settings.focus_max = (sub == "on")
            config.save(settings)
        end
        chat_msg(string.format("[OmniChain] Max-power WS when everyone is on the same enemy: %s (prime weapon: its WS; otherwise the empyrean WS. Dojikiri Yasutsuna uses Tachi: Shoha)",
            settings.focus_max ~= false and "ON" or "OFF"))
        log_debug("CMD", "Focus: " .. tostring(settings.focus_max))

    elseif cmd == "toss" then
        -- Tossing to party members: //omni toss [on|off]
        if sub == "on" or sub == "off" then
            settings.toss = (sub == "on")
            config.save(settings)
        end
        chat_msg(string.format("[OmniChain] Toss to party members: %s (only when close: predicts their next WS and matches the property)",
            settings.toss ~= false and "ON" or "OFF"))
        log_debug("CMD", "Toss: " .. tostring(settings.toss))

    elseif cmd == "reach" then
        -- Distance at which melee WS may be used (the number shown by distanceplus): //omni reach <distance>
        local d = tonumber(sub)
        if d and d >= 1 and d <= 8 then
            settings.ws_reach = d
            config.save(settings)
        elseif sub then
            chat_msg("[OmniChain] Distance must be 1-8 (e.g. //omni reach 3.5).")
        end
        chat_msg(string.format("[OmniChain] Melee WS used at distance %.1f or less (the distanceplus number)", safe_num(settings.ws_reach, 3.5)))
        log_debug("CMD", "WS reach: " .. tostring(settings.ws_reach))

    elseif cmd == "openpt" then
        -- Seconds until the window opens when the previous WS was yours or a party member's (for testing): //omni openpt <seconds>
        local sec = tonumber(sub)
        if sec and sec >= 0.5 and sec <= 3.3 then
            settings.open_player = sec
            config.save(settings)
        elseif sub then
            chat_msg("[OmniChain] Seconds must be 0.5-3.3 (3.3 = as before).")
        end
        chat_msg(string.format("[OmniChain] Window after a player's (you / party) WS: %.1f s (trusts: 3.3 s)", safe_num(settings.open_player, SC_OPEN_SEC)))
        log_debug("CMD", "Open player: " .. tostring(settings.open_player))

    elseif cmd == "solo" then
        -- Waiting for trusts' solo chains: //omni solo [on|off] / start <seconds> / gap <seconds>
        local sec = tonumber(args[2])
        if sub == "start" or sub == "gap" then
            if sec and sec >= 1 and sec <= 30 then
                if sub == "start" then settings.solo_start_wait = sec else settings.solo_gap = sec end
                config.save(settings)
            else
                chat_msg("[OmniChain] Seconds must be 1-30 (e.g. //omni solo gap 6).")
            end
        elseif sub == "on" or sub == "off" then
            settings.trust_solo = (sub == "on")
            if not settings.trust_solo then state.solos = {} end
            config.save(settings)
        end
        chat_msg(string.format("[OmniChain] Wait for trusts' solo chains: %s (%.1f s after the ability / %.1f s between WS)",
            settings.trust_solo ~= false and "ON" or "OFF", safe_num(settings.solo_start_wait, 12.0), safe_num(settings.solo_gap, 11.0)))
        log_debug("CMD", "Trust solo wait: " .. tostring(settings.trust_solo))

    elseif cmd == "reload" or cmd == "load" then
        update_job_profile()
        chat_msg(string.format("[OmniChain] Settings file reloaded. (Job: %s / Weapon: %s)", state.active_job, state.active_weapon))

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
        chat_msg("//omni enable / disable       : turn auto skillchain ON / OFF")
        chat_msg("//omni start manual / auto    : open the first chain yourself / let the addon do it")
        chat_msg("//omni wait <sec>             : in manual-opener mode, seconds to wait before the auto WS (default 6)")
        chat_msg("//omni solo [on|off]          : wait for trusts' solo chains to finish (tune with start <sec> / gap <sec>)")
        chat_msg("//omni hud [on|off]           : show / hide the HUD overlay")
        chat_msg("//omni size <n>               : HUD font size (6-40). Also by mouse wheel over the HUD / dragging its bottom-right corner")
        chat_msg("//omni log [on|off|clear]     : toggle / clear the log file")
        chat_msg("//omni log tail [n] / err [n] : show recent entries / errors and warnings in chat")
        chat_msg("//omni check                  : check that the WS in the priority list are usable")
        chat_msg("See addons/OmniChain/COMMANDS.txt for details")
        chat_msg("//omni reload                 : reload the JSON config file")
        chat_msg("//omni status                 : show the current settings")
    end
end))

local FrameMeter = {}

local history = { p1 = {}, p2 = {} }
local hitboxes_cache = {}
local cns_cache = {}

FrameMeter.idle_ticks = 0
FrameMeter.p1_attacking = false
FrameMeter.p2_attacking = false

local function resolvePath(base_path, relative_path)
    relative_path = relative_path:gsub("\\", "/")
    base_path = base_path:gsub("\\", "/")
    if relative_path:match("^chars/") or relative_path:match("^data/") then return relative_path end
    local dir = base_path:match("^(.*[/\\])") or ""
    return dir .. relative_path
end

local function parseAirFile(filepath)
    local f = io.open(filepath, "r")
    if not f then return nil end
    local anim_data = {}
    local current_anim = nil
    local current_elem = 0
    local default_clsn1 = false
    local next_clsn1 = false
    local next_clsn1_set = false
    for line in f:lines() do
        local comment_pos = line:find(";")
        if comment_pos then line = line:sub(1, comment_pos - 1) end
        line = line:match("^%s*(.-)%s*$")
        local lower_line = line:lower()
        local anim_id = lower_line:match("^%[begin action (%d+)%]")
        if anim_id then
            current_anim = tonumber(anim_id)
            anim_data[current_anim] = {}
            current_elem = 0
            default_clsn1 = false
            next_clsn1 = false
            next_clsn1_set = false
        elseif current_anim then
            local clsn1_def = lower_line:match("^clsn1default:%s*(%d+)")
            if clsn1_def then default_clsn1 = (tonumber(clsn1_def) > 0) end
            local clsn1_spec = lower_line:match("^clsn1:%s*(%d+)")
            if clsn1_spec then
                next_clsn1 = (tonumber(clsn1_spec) > 0)
                next_clsn1_set = true
            end
            if line:match("^[-%w]+,%s*[-%w]+,%s*[-%w]+,%s*[-%w]+,%s*[-%w]+") then
                current_elem = current_elem + 1
                local has_box = false
                if next_clsn1_set then
                    has_box = next_clsn1
                else
                    has_box = default_clsn1
                end
                anim_data[current_anim][current_elem] = has_box
                next_clsn1 = false
                next_clsn1_set = false
            end
        end
    end
    f:close()
    return anim_data
end

local function findCharFiles(char_name, p)
    if start and start.p and start.p[p] and start.p[p].t_selected and start.p[p].t_selected[1] then
        local ref = start.p[p].t_selected[1].ref
        local char_data = start.f_getCharData(ref)
        if char_data then
            local def_path = char_data.def
            local dir = char_data.dir or ""
            if dir ~= "" and not dir:match("[/\\]$") then
                dir = dir .. "/"
            end
            if not def_path and dir ~= "" then
                local files = getDirectoryFiles(dir)
                if type(files) == "table" then
                    for _, f in ipairs(files) do
                        if f:lower():match("%.def$") then
                            def_path = dir .. f
                            break
                        end
                    end
                end
            end
            
            if def_path then
                local air_file = nil
                local cns_files = {}
                local f = io.open(def_path, "r")
                if f then
                    local in_files = false
                    for line in f:lines() do
                        local comment_pos = line:find(";")
                        if comment_pos then line = line:sub(1, comment_pos - 1) end
                        local lower_line = line:lower()
                        if lower_line:match("^%s*%[info%]") then in_files = false end
                        if lower_line:match("^%s*%[files%]") then in_files = true end
                        
                        if in_files then
                            local k, v = line:match("^%s*(%w+)%s*=%s*(.-)%s*$")
                            if k and v then
                                k = k:lower()
                                if k == "anim" then
                                    air_file = v
                                elseif k == "cns" or k == "cmd" or k:match("^st%d*$") then
                                    table.insert(cns_files, v)
                                end
                            end
                        end
                    end
                    f:close()
                    local air_path = air_file and resolvePath(def_path, air_file) or nil
                    local cns_paths = {}
                    for _, cns in ipairs(cns_files) do
                        table.insert(cns_paths, resolvePath(def_path, cns))
                    end
                    return air_path, cns_paths
                end
            end
        end
    end
    return nil, {}
end

local function parseCnsFiles(paths)
    local state_data = {}
    for _, filepath in ipairs(paths) do
        local f = io.open(filepath, "r")
        if f then
            local current_state = nil
            local in_hitdef = false
            for line in f:lines() do
                local comment_pos = line:find(";")
                if comment_pos then line = line:sub(1, comment_pos - 1) end
                local lower_line = line:lower()
                
                local state_match = lower_line:match("^%s*%[statedef%s+([%-%d]+)")
                if state_match then
                    current_state = tonumber(state_match)
                    in_hitdef = false
                else
                    if lower_line:match("^%s*%[state%s+") then
                        in_hitdef = false
                    end
                    if current_state then
                        if lower_line:match("^%s*type%s*=%s*hitdef") then
                            in_hitdef = true
                            if not state_data[current_state] then
                                state_data[current_state] = { attr = "", guardflag = "" }
                            end
                        end
                        if in_hitdef and state_data[current_state] then
                            local attr = lower_line:match("^%s*attr%s*=%s*(.-)%s*$")
                            if attr and state_data[current_state].attr == "" then
                                state_data[current_state].attr = attr:upper()
                            end
                            local guardflag = lower_line:match("^%s*guardflag%s*=%s*(.-)%s*$")
                            if guardflag and state_data[current_state].guardflag == "" then
                                state_data[current_state].guardflag = guardflag:upper()
                            end
                        end
                    end
                end
            end
            f:close()
        end
    end
    return state_data
end

local function cachePlayerHitboxes(char_name, p)
    if hitboxes_cache[char_name] then return end
    hitboxes_cache[char_name] = {}
    cns_cache[char_name] = {}
    
    local air_path, cns_paths = findCharFiles(char_name, p)
    if air_path then
        local data = parseAirFile(air_path)
        if data then hitboxes_cache[char_name] = data end
    end
    if cns_paths and #cns_paths > 0 then
        local data = parseCnsFiles(cns_paths)
        if data then cns_cache[char_name] = data end
    end
end
local MAX_FRAMES = 80
local p1_proj_active = 0
local p2_proj_active = 0
local box_w = 8
local box_h = 18
local spacing = 1

local STATE_IDLE = 0
local STATE_STARTUP = 1
local STATE_ACTIVE = 2
local STATE_RECOVERY = 3
local STATE_TRANSITION = 4
local STATE_BLOCKSTUN = 5
local STATE_HITSTUN = 6
local STATE_UNACTIONABLE = 7

local colors = {
    [STATE_IDLE]       = {128, 128, 128, 255}, -- Grey
    [STATE_STARTUP]    = {0, 255, 0, 255},     -- Green
    [STATE_ACTIVE]     = {255, 0, 0, 255},     -- Red
    [STATE_RECOVERY]   = {0, 0, 255, 255},     -- Blue
    [STATE_TRANSITION] = {128, 0, 128, 255},   -- Purple
    [STATE_HITSTUN]    = {255, 128, 0, 255},   -- Orange
    [STATE_BLOCKSTUN]  = {255, 255, 0, 255},   -- Yellow
    [STATE_UNACTIONABLE]= {0, 255, 255, 255}   -- Cyan
}

function FrameMeter.init()
    history.p1 = {}
    history.p2 = {}
end

local function getPlayerFrameState(p)
    local oldid = id()
    if not player(p) then 
        playerid(oldid)
        return STATE_IDLE 
    end

    local s = stateno()
    local m = movetype()
    local hp = hitpausetime()
    local a = anim()
    local at = animtime()
    local en = animelemno(0)
    local et = animelemtime(en)
    local char_name = name()
    local has_ctrl = (ctrl() == true or ctrl() == 1)
    
    local nh = numhelper()
    local np = numproj()
    local proj_spawned = false
    
    cachePlayerHitboxes(char_name, p)
    
    if p == 1 then
        if nh ~= (FrameMeter.p1_helpers or 0) or np > (FrameMeter.p1_projs or 0) then proj_spawned = true end
        FrameMeter.p1_helpers = nh
        FrameMeter.p1_projs = np
    else
        if nh ~= (FrameMeter.p2_helpers or 0) or np > (FrameMeter.p2_projs or 0) then proj_spawned = true end
        FrameMeter.p2_helpers = nh
        FrameMeter.p2_projs = np
    end

    local atk_type = ""
    if cns_cache[char_name] and cns_cache[char_name][s] then
        local data = cns_cache[char_name][s]
        if data.attr:match("T$") then
            atk_type = "THROW"
        elseif data.attr:match("P$") then
            atk_type = "PROJ"
        else
            if data.guardflag:match("H") and not data.guardflag:match("L") then
                atk_type = "OVERHEAD"
            elseif data.guardflag:match("L") and not data.guardflag:match("H") then
                atk_type = "LOW"
            elseif data.guardflag ~= "" then
                atk_type = "MID"
            end
        end
    end
    
    if m == 'A' and atk_type ~= "" then 
        FrameMeter["p"..p.."_atk_type"] = atk_type
    end

    playerid(oldid)

    -- Hitstun & Blockstun
    if m == 'H' then
        if p == 1 then FrameMeter.p1_attacking = false end
        if p == 2 then FrameMeter.p2_attacking = false end
        
        if s >= 120 and s <= 155 then
            return STATE_BLOCKSTUN
        end
        return STATE_HITSTUN
    end

    -- Persistent Attack Tracking
    local is_attacking = false
    if p == 1 then
        if m == 'A' then FrameMeter.p1_attacking = true end
        
        if has_ctrl then 
            if FrameMeter.p1_attacking or FrameMeter.p1_unactionable then 
                FrameMeter.p1_just_recovered = true 
            end
            FrameMeter.p1_attacking = false 
            FrameMeter.p1_unactionable = false
        end
        is_attacking = FrameMeter.p1_attacking
        if FrameMeter.p1_just_recovered then
            FrameMeter.p1_just_recovered = false
            return STATE_TRANSITION
        end
    else
        if m == 'A' then FrameMeter.p2_attacking = true end
        
        if has_ctrl then 
            if FrameMeter.p2_attacking or FrameMeter.p2_unactionable then 
                FrameMeter.p2_just_recovered = true 
            end
            FrameMeter.p2_attacking = false 
            FrameMeter.p2_unactionable = false
        end
        is_attacking = FrameMeter.p2_attacking
        if FrameMeter.p2_just_recovered then
            FrameMeter.p2_just_recovered = false
            return STATE_TRANSITION
        end
    end

    -- Attacking Logic
    if is_attacking then
        if hp > 0 then
            return STATE_ACTIVE
        end
        
        local data = hitboxes_cache[char_name]
        
        -- Exact parse logic
        if data and data[a] then
            local first_active = 9999
            local last_active = 0
            for e, hb in pairs(data[a]) do
                if hb then
                    if e < first_active then first_active = e end
                    if e > last_active then last_active = e end
                end
            end
            
            if first_active ~= 9999 then
                local has_box = data[a][en]
                if has_box then
                    return STATE_ACTIVE
                elseif en < first_active then
                    if m ~= 'A' then return STATE_RECOVERY end
                    return STATE_STARTUP
                else
                    return STATE_RECOVERY
                end
            else
                -- Move has NO physical hitboxes (e.g. Projectiles, Teleports, Buffs)
                if proj_spawned then
                    if p == 1 then p1_proj_active = 2 else p2_proj_active = 2 end
                end
                
                local active_timer = (p == 1 and p1_proj_active) or (p == 2 and p2_proj_active)
                if active_timer > 0 then
                    if p == 1 then p1_proj_active = p1_proj_active - 1 else p2_proj_active = p2_proj_active - 1 end
                    return STATE_ACTIVE
                end
                
                -- Tail Recovery: MoveType changed but character still lacks control
                if m ~= 'A' then return STATE_RECOVERY end
                
                -- If we haven't spawned anything, it's startup. Otherwise recovery.
                if (p == 1 and (FrameMeter.p1_helpers or 0) > 0) or (p == 2 and (FrameMeter.p2_helpers or 0) > 0) then
                    return STATE_RECOVERY
                else
                    return STATE_STARTUP
                end
            end
        end
    end

    -- Catch-all for neutral/movement
    if not has_ctrl then
        if p == 1 then FrameMeter.p1_unactionable = true else FrameMeter.p2_unactionable = true end
        return STATE_UNACTIONABLE
    end
    
    return STATE_IDLE
end


function FrameMeter.update()
    local oldid = id()
    local engine_frozen = false
    
    local c1, t1, s1_raw, hp1, sp1, c2, t2, s2_raw, hp2, sp2
    if player(1) then 
        c1 = (ctrl() == true or ctrl() == 1)
        t1 = time()
        s1_raw = stateno()
        hp1 = hitpausetime()
        playerid(oldid) 
    end
    if player(2) then 
        c2 = (ctrl() == true or ctrl() == 1)
        t2 = time()
        s2_raw = stateno()
        hp2 = hitpausetime()
        playerid(oldid) 
    end

    if not engine_frozen then
        local p1_frozen = (t1 == FrameMeter.last_t1 and s1_raw == FrameMeter.last_s1_raw and hp1 == 0)
        local p2_frozen = (t2 == FrameMeter.last_t2 and s2_raw == FrameMeter.last_s2_raw and hp2 == 0)
        if (p1_frozen and p2_frozen) or (hp1 and hp1 > 0) or (hp2 and hp2 > 0) then
            engine_frozen = true
        end
    end
    
    FrameMeter.last_t1 = t1
    FrameMeter.last_s1_raw = s1_raw
    FrameMeter.last_t2 = t2
    FrameMeter.last_s2_raw = s2_raw

    FrameMeter.match_time = (FrameMeter.match_time or 0) + 1
    
    if engine_frozen then
        return
    end
    
    local s1 = getPlayerFrameState(1)
    local s2 = getPlayerFrameState(2)
    
    if s1 == STATE_IDLE and (history.p1[#history.p1] or STATE_IDLE) ~= STATE_IDLE then
        FrameMeter.p1_end_time = FrameMeter.match_time
    end
    if s2 == STATE_IDLE and (history.p2[#history.p2] or STATE_IDLE) ~= STATE_IDLE then
        FrameMeter.p2_end_time = FrameMeter.match_time
    end
    
    if FrameMeter.p1_attacking_last and s1 == STATE_IDLE and s2 == STATE_IDLE then
        FrameMeter.adv_display = (FrameMeter.p2_end_time or 0) - (FrameMeter.p1_end_time or 0)
        FrameMeter.p1_attacking_last = false
    end
    if FrameMeter.p2_attacking_last and s2 == STATE_IDLE and s1 == STATE_IDLE then
        FrameMeter.adv_display = (FrameMeter.p1_end_time or 0) - (FrameMeter.p2_end_time or 0)
        FrameMeter.p2_attacking_last = false
    end
    
    if s1 == STATE_STARTUP and (history.p1[#history.p1] or STATE_IDLE) ~= STATE_STARTUP then
        FrameMeter.p1_attacking_last = true
        FrameMeter.p2_attacking_last = false
    end
    if s2 == STATE_STARTUP and (history.p2[#history.p2] or STATE_IDLE) ~= STATE_STARTUP then
        FrameMeter.p2_attacking_last = true
        FrameMeter.p1_attacking_last = false
    end
    
    if s1 == STATE_IDLE then
        FrameMeter.p1_idle_ticks = (FrameMeter.p1_idle_ticks or 0) + 1
    else
        FrameMeter.p1_idle_ticks = 0
    end
    
    if FrameMeter.p1_idle_ticks == 0 and (FrameMeter.prev_p1_idle_ticks or 0) > 45 then
        history.p1 = {}
        history.p2 = {}
    end
    FrameMeter.prev_p1_idle_ticks = FrameMeter.p1_idle_ticks
    
    if FrameMeter.p1_idle_ticks > 45 then
        return
    end

    table.insert(history.p1, s1)
    table.insert(history.p2, s2)
    
    if #history.p1 > MAX_FRAMES then table.remove(history.p1, 1) end
    if #history.p2 > MAX_FRAMES then table.remove(history.p2, 1) end
end

local function drawBox(x, y, w, h, r, g, b, a)
    if fillRect then
        local src = a or 255
        local dst = 255 - src
        fillRect(x, y, w, h, r, g, b, src, dst)
    end
end

function FrameMeter.draw()
    local screen_w = main.SP_Localcoord[1] or 320
    local screen_h = main.SP_Localcoord[2] or 240
    
    local total_w = (box_w + spacing) * MAX_FRAMES
    local start_x = (screen_w - total_w) / 2
    local start_y = screen_h - (box_h * 2 + spacing * 4) - 20
    
    if not FrameMeter.txt_pool then FrameMeter.txt_pool = {} end
    local txt_idx = 1
    local function drawTextNum(txt_str, x, y, r, g, b, font_str, align, height)
        font_str = font_str or "f-6x9.def"
        align = align or 0
        height = height or -1
        if not text or not text.create then return end
        if not FrameMeter.txt_pool[txt_idx] then
            FrameMeter.txt_pool[txt_idx] = text:create({font = font_str, bank = 0, align = align, r = r, g = g, b = b, height = height})
        end
        FrameMeter.txt_pool[txt_idx]:update({text = tostring(txt_str), x = math.floor(x), y = math.floor(y), r = r, g = g, b = b, font = font_str, align = align, height = height})
        FrameMeter.txt_pool[txt_idx]:draw()
        txt_idx = txt_idx + 1
    end
    
    local p1_startup, p1_active, p1_recovery = 0, 0, 0
    local phase = 0
    for i = #history.p1, 1, -1 do
        local state = history.p1[i]
        if phase == 0 then
            if state == STATE_RECOVERY or state == STATE_TRANSITION then
                phase = 1; p1_recovery = p1_recovery + 1
            elseif state == STATE_ACTIVE then
                phase = 2; p1_active = p1_active + 1
            elseif state == STATE_STARTUP then
                phase = 3; p1_startup = p1_startup + 1
            end
        elseif phase == 1 then
            if state == STATE_RECOVERY or state == STATE_TRANSITION then p1_recovery = p1_recovery + 1
            elseif state == STATE_ACTIVE then phase = 2; p1_active = p1_active + 1
            elseif state == STATE_STARTUP then phase = 3; p1_startup = p1_startup + 1
            elseif state ~= STATE_IDLE then break end
        elseif phase == 2 then
            if state == STATE_ACTIVE then p1_active = p1_active + 1
            elseif state == STATE_STARTUP then phase = 3; p1_startup = p1_startup + 1
            elseif state ~= STATE_IDLE then break end
        elseif phase == 3 then
            if state == STATE_STARTUP then p1_startup = p1_startup + 1
            elseif state ~= STATE_IDLE then break end
        end
    end
    
    local has_stats = (p1_startup > 0 or p1_active > 0 or p1_recovery > 0)
    if has_stats then
        FrameMeter.last_p1_startup = p1_startup
        FrameMeter.last_p1_active = p1_active
        FrameMeter.last_p1_recovery = p1_recovery
    else
        p1_startup = FrameMeter.last_p1_startup or 0
        p1_active = FrameMeter.last_p1_active or 0
        p1_recovery = FrameMeter.last_p1_recovery or 0
    end
    
    local display_startup = p1_startup > 0 and (p1_startup + 1) or 0
    local total_duration = p1_startup + p1_active + p1_recovery
    local adv = FrameMeter.adv_display or 0
    
    local p1_type = FrameMeter.p1_atk_type or ""
    local stats_str
    if p1_type ~= "" then
        stats_str = string.format("Start: %d  Active: %d  Recov: %d  Total: %d  Adv: %+d  Type: %s", 
            display_startup, p1_active, p1_recovery, total_duration, adv, p1_type)
    else
        stats_str = string.format("Start: %d  Active: %d  Recov: %d  Total: %d  Adv: %+d", 
            display_startup, p1_active, p1_recovery, total_duration, adv)
    end
        
    drawTextNum(stats_str, screen_w / 2, start_y - 45, 255, 255, 255, "name14.def", 0, 13)
    
    drawBox(start_x - 2, start_y - 2, total_w + 2, (box_h * 2) + (spacing * 4), 0, 0, 0, 150)
    
    local function getGroup(state)
        if state == STATE_TRANSITION then return STATE_RECOVERY end
        return state
    end
    
    local current_group = nil
    local count = 0
    local start_i = 1
    
    for i, state in ipairs(history.p1) do
        local c = colors[state] or colors[STATE_IDLE]
        local x = start_x + (i-1)*(box_w + spacing)
        drawBox(x, start_y, box_w, box_h, c[1], c[2], c[3], c[4])
        
        local grp = getGroup(state)
        if grp ~= current_group then
            if current_group ~= nil then
                local center_i = start_i + (count - 1) / 2
                local txt_x = start_x + (center_i - 1) * (box_w + spacing) + (box_w / 2)
                drawTextNum(count, txt_x, start_y - 14, 255, 255, 255, "f-6x9.def", 0, 16)
            end
            current_group = grp
            count = 1
            start_i = i
        else
            count = count + 1
        end
    end
    if current_group ~= nil then
        local center_i = start_i + (count - 1) / 2
        local txt_x = start_x + (center_i - 1) * (box_w + spacing) + (box_w / 2)
        drawTextNum(count, txt_x, start_y - 14, 255, 255, 255, "f-6x9.def", 0, 16)
    end
    
    local p2_current_group = nil
    local p2_count = 0
    local p2_start_i = 1
    
    for i, state in ipairs(history.p2) do
        local c = colors[state] or colors[STATE_IDLE]
        local x = start_x + (i-1)*(box_w + spacing)
        drawBox(x, start_y + box_h + spacing*2, box_w, box_h, c[1], c[2], c[3], c[4])
        
        local grp = getGroup(state)
        if grp ~= p2_current_group then
            if p2_current_group ~= nil then
                local center_i = p2_start_i + (p2_count - 1) / 2
                local txt_x = start_x + (center_i - 1) * (box_w + spacing) + (box_w / 2)
                drawTextNum(p2_count, txt_x, start_y + (box_h * 2) + (spacing * 2) + 4, 255, 255, 255, "f-6x9.def", 0, 16)
            end
            p2_current_group = grp
            p2_count = 1
            p2_start_i = i
        else
            p2_count = p2_count + 1
        end
    end
    if p2_current_group ~= nil then
        local center_i = p2_start_i + (p2_count - 1) / 2
        local txt_x = start_x + (center_i - 1) * (box_w + spacing) + (box_w / 2)
        drawTextNum(p2_count, txt_x, start_y + (box_h * 2) + (spacing * 2) + 4, 255, 255, 255, "f-6x9.def", 0, 16)
    end
    
    local adv = FrameMeter.adv_display or 0
    local adv_str = adv >= 0 and ("+" .. adv) or tostring(adv)
    local adv_color_r = adv >= 0 and 0 or 255
    local adv_color_g = adv >= 0 and 255 or 100
    local adv_color_b = adv >= 0 and 255 or 100
    drawTextNum(adv_str, start_x + total_w + 15, start_y + 4, adv_color_r, adv_color_g, adv_color_b)
end

return FrameMeter

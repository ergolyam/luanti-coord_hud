local DEFAULT_POS = { x = 0.5, y = 0.05 }
local DEFAULT_OFFSET = { x = 0, y = 0 }
local DEFAULT_ALIGN = { x = 0, y = 0 }
local DEFAULT_COLOR = 0xFFFFFF
local DEFAULT_TEXT_SCALE = 1.0

local hud_state = {}

local function pname(player)
    return player:get_player_name()
end

local function load_settings(player)
    local meta = player:get_meta()
    local pos_x = tonumber(meta:get_string("coord_hud:pos_x")) or DEFAULT_POS.x
    local pos_y = tonumber(meta:get_string("coord_hud:pos_y")) or DEFAULT_POS.y
    local size = tonumber(meta:get_string("coord_hud:size")) or DEFAULT_TEXT_SCALE
    local enabled_str = meta:get_string("coord_hud:enabled")
    local enabled = enabled_str == "" and true or (enabled_str == "true")
    return {
        position = { x = pos_x, y = pos_y },
        offset = DEFAULT_OFFSET,
        align = DEFAULT_ALIGN,
        color = DEFAULT_COLOR,
        size = size,
        enabled = enabled
    }
end

local function save_settings(player, s)
    local meta = player:get_meta()
    meta:set_string("coord_hud:pos_x", tostring(s.position.x))
    meta:set_string("coord_hud:pos_y", tostring(s.position.y))
    meta:set_string("coord_hud:size", tostring(s.size))
    meta:set_string("coord_hud:enabled", s.enabled and "true" or "false")
end

local function add_hud(player, s)
    local id = player:hud_add({
        hud_elem_type = "text",
        position = s.position,
        offset = s.offset,
        alignment = s.align,
        number = s.color,
        text = "",
        size = { x = s.size, y = 0 },
        z_index = 100
    })
    return id
end

local function apply_visual(player, id, s)
    if not id then return end
    player:hud_change(id, "position", s.position)
    player:hud_change(id, "offset", s.offset)
    player:hud_change(id, "alignment", s.align)
    player:hud_change(id, "number", s.color)
    player:hud_change(id, "size", { x = s.size, y = 0 })
end

local function update_text(player, id)
    local st = hud_state[pname(player)]
    if not st then return end

    local pos = player:get_pos()
    if not pos then return end

    local x = math.floor(pos.x + 0.5)
    local y = math.floor(pos.y + 0.5)
    local z = math.floor(pos.z + 0.5)

    if st.last_x == x and st.last_y == y and st.last_z == z then
        return
    end

    st.last_x, st.last_y, st.last_z = x, y, z
    local txt = ("X: %d  Y: %d  Z: %d"):format(x, y, z)

    if st.last_text ~= txt then
        st.last_text = txt
        player:hud_change(id, "text", txt)
    end
end

local function show_config(player)
    local name = pname(player)
    local s = hud_state[name].settings
    local x_val = math.floor(s.position.x * 1000 + 0.5)
    local y_val = math.floor(s.position.y * 1000 + 0.5)
    local fs = table.concat({
        "formspec_version[4]",
        "size[12,7,true]",
        "label[0.6,0.5;Move the sliders to place the HUD text.]",
        "checkbox[0.6,0.9;cohud_enabled;Enabled;", s.enabled and "true" or "false", "]",
        "label[0.6,1.6;Horizontal position]",
        "scrollbar[0.6,2.0;10.8,0.5;horizontal;cohud_x;", tostring(x_val), "]",
        "label[0.6,2.9;Vertical position]",
        "scrollbar[0.6,3.3;10.8,0.5;horizontal;cohud_y;", tostring(y_val), "]",
        "field[0.6,4.0;4,1;cohud_size_field;;", string.format("%.2f", s.size), "]",
        "label[5.0,4.5;Text size (0.5–3.0)]",
        "button[0.6,5.6;3,1;cohud_reset;Reset]",
        "button_exit[8.4,5.6;3,1;cohud_close;Close]"
    })
    minetest.show_formspec(name, "coord_hud:config", fs)
end

local function handle_scroll(player, fields)
    local name = pname(player)
    local s = hud_state[name].settings
    local id = hud_state[name].id
    if fields.cohud_x then
        local e = minetest.explode_scrollbar_event(fields.cohud_x)
        if e and e.type == "CHG" then
            s.position.x = math.min(1, math.max(0, e.value / 1000))
            apply_visual(player, id, s)
            save_settings(player, s)
        end
    end
    if fields.cohud_y then
        local e = minetest.explode_scrollbar_event(fields.cohud_y)
        if e and e.type == "CHG" then
            s.position.y = math.min(1, math.max(0, e.value / 1000))
            apply_visual(player, id, s)
            save_settings(player, s)
        end
    end
end

minetest.register_on_joinplayer(function(player)
    local name = pname(player)
    local settings = load_settings(player)
    local id = nil
    if settings.enabled then
        id = add_hud(player, settings)
    end
    hud_state[name] = { id = id, settings = settings }
end)

minetest.register_on_leaveplayer(function(player)
    hud_state[pname(player)] = nil
end)

local accum = 0
minetest.register_globalstep(function(dt)
    accum = accum + dt
    if accum < 0.2 then return end
    accum = 0
    for _, player in ipairs(minetest.get_connected_players()) do
        local st = hud_state[pname(player)]
        if st and st.id then
            update_text(player, st.id)
        end
    end
end)

minetest.register_chatcommand("coords", {
    description = "Configure position and size of your coordinate HUD",
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if not player then return false, "Player not found." end
        if not hud_state[name] then
            local settings = load_settings(player)
            local id = nil
            if settings.enabled then
                id = add_hud(player, settings)
            end
            hud_state[name] = { id = id, settings = settings }
        end
        show_config(player)
        return true, "Coordinate HUD config opened."
    end
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= "coord_hud:config" then
        return false
    end
    handle_scroll(player, fields)
    if fields.cohud_enabled ~= nil then
        local name = pname(player)
        local st = hud_state[name]
        local new_enabled = minetest.is_yes(fields.cohud_enabled)
        st.settings.enabled = new_enabled
        save_settings(player, st.settings)
        if new_enabled and not st.id then
            st.id = add_hud(player, st.settings)
            st.last_text = nil
            apply_visual(player, st.id, st.settings)
        elseif (not new_enabled) and st.id then
            player:hud_remove(st.id)
            st.id = nil
        end
    end
    if fields.cohud_size_field then
        local name = pname(player)
        local st = hud_state[name]
        if st then
            local n = tonumber(fields.cohud_size_field)
            if n then
                if n < 0.5 then n = 0.5 end
                if n > 3.0 then n = 3.0 end
                st.settings.size = n
                apply_visual(player, st.id, st.settings)
                save_settings(player, st.settings)
            else
                minetest.chat_send_player(name, "[coord_hud] Size must be a number, e.g. 1.0")
            end
        end
    end
    if fields.cohud_reset then
        local name = pname(player)
        local s = hud_state[name].settings
        s.position = { x = DEFAULT_POS.x, y = DEFAULT_POS.y }
        s.size = DEFAULT_TEXT_SCALE
        apply_visual(player, hud_state[name].id, s)
        save_settings(player, s)
        show_config(player)
    end
    return false
end)


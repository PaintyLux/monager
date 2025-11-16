require 'tables'

local recorded_swings = {
    regular = {},
    critical = {},
}

local attack_swing_str =
[[
-----
Attack Swings:
-----
${swing_data}
]]

--- table:flatten() uses ipairs which doesn't work here as keys are indexed by damage number, not from 1
local function flatten_swing_table()
    local regular_keys = {}
    local critical_keys = {}

    local idx = 1
    for k, _  in pairs( recorded_swings.regular ) do
        regular_keys[idx] = k
        idx = idx + 1
    end

    table.sort(regular_keys)

    idx = 1
    for k, _  in pairs( recorded_swings.critical ) do
        critical_keys[idx] = k
        idx = idx + 1
    end

    table.sort(critical_keys)

    local result = {}
    idx = 1

    for _, swing_value in ipairs( regular_keys ) do
        result[idx] = string.format( "\\cs(255,192,192,192)[R] {%d} {~%d} : %d\\cr", swing_value, math.floor(swing_value * 1.05), recorded_swings.regular[swing_value] )
        idx = idx + 1
    end

    for _, swing_value in ipairs( critical_keys ) do
        result[idx] = string.format( "\\cs(255,  0,192,192)[C] {%d} {~%d} : %d\\cr", swing_value, math.floor(swing_value * 1.05), recorded_swings.critical[swing_value] )
        idx = idx + 1
    end

    return result
end

local function parse_combat_action_0X28( packet_raw )
    local packet_data = PACKETS.parse( "incoming", packet_raw )

    if packet_data['Actor'] ~= windower.ffxi.get_player().id then
        return
    end

    for action_message_index = 1, packet_data["Target 1 Action Count"] do
        if packet_data["Target 1 Action " .. action_message_index .. " Message"] == 0x01 then
            local hit_dmg = packet_data["Target 1 Action " .. action_message_index .. " Param"]

            if recorded_swings.regular[hit_dmg] == nil then
                recorded_swings.regular[hit_dmg] = 1
            else
                recorded_swings.regular[hit_dmg] = recorded_swings.regular[hit_dmg] + 1
            end
        end
        if packet_data["Target 1 Action " .. action_message_index .. " Message"] == 0x43 then
            local hit_dmg = packet_data["Target 1 Action " .. action_message_index .. " Param"]

            if recorded_swings.critical[hit_dmg] == nil then
                recorded_swings.critical[hit_dmg] = 1
            else
                recorded_swings.critical[hit_dmg] = recorded_swings.critical[hit_dmg] + 1
            end
        end
    end

    local str = ""

    for k,v in pairs( flatten_swing_table() ) do
        str = str .. v .. "\n"
    end

    ATTACK_SWING_TEXT.swing_data = str
end

local incoming_chunk_fn = function( type_id, packet_raw, modified, injected, blocked )
    if injected or blocked then return end

    if type_id == 0x28 then
        parse_combat_action_0X28( packet_raw )
    end
end

local addon_command_fn = function(command, ...)
    local params = L{...}

    if command == nil then return end

    if command == 'hide' then
        if params[1] == 'swings' then
            ATTACK_SWING_TEXT:hide()
        end
    end

    if command == 'show' then
        if params[1] == 'swings' then
            ATTACK_SWING_TEXT:show()
        end
    end

    if command == 'reload' and params[1] == 'swings' then
        recorded_swings.regular = {}
        recorded_swings.critical = {}
        ATTACK_SWING_TEXT.swing_data = ""
    end
end

local zone_change_fn = function ()
    recorded_swings.regular = {}
    recorded_swings.critical = {}

    ATTACK_SWING_TEXT.swing_data = ""
end

LOAD_FNS = LOAD_FNS or {}
LOAD_FNS['swings'] = function()
    LOADED_ADDONS = LOADED_ADDONS or {}

    ATTACK_SWING_TEXT = ATTACK_SWING_TEXT or TEXTS.new(attack_swing_str)
    TEXTS.font( ATTACK_SWING_TEXT, 'Consolas' )

    LOADED_ADDONS['swings'] = {
        windower.register_event( 'addon command', addon_command_fn ),
        windower.register_event( 'incoming chunk', incoming_chunk_fn ),
        windower.register_event( 'zone change', zone_change_fn ),
    }
end
local base_dmg_data = {
    level       = 0,
    str         = 0,
    fSTR_MIN    = 0,
    fSTR_MAX    = 0,
}

local base_dmg_str =
[[
-----
LVL[${level|0|%3d}]
STR[${str|0|%3d}]
-----
fSTR
MIN = ${fSTR_MIN|0|%4d}[${fSTR_MIN_REQ|0|%4d}]
MAX = ${fSTR_MAX|0|%4d}[${fSTR_MAX_REQ|0|%4d}]
-----
Base DMG?:
+ 2 [${DMG_2}] = [${level}] + [${fSTR_MAX|0|%4d}] + [2]
+10 [${DMG_10}] = [${level}] + [${fSTR_MAX|0|%4d}] + [10]
+11 [${DMG_11}] = [${level}] + [${fSTR_MAX|0|%4d}] + [11]
-----
Expected Damage (2.0 pDIF cap)
+ 2 [${Damage_2_pDIF_2_min} ~ ${Damage_2_pDIF_2_max}]    (crit)[${Damage_2_pDIF_2_min_crit} ~ ${Damage_2_pDIF_2_max_crit}]
+10 [${Damage_10_pDIF_2_min} ~ ${Damage_10_pDIF_2_max}]    (crit)[${Damage_10_pDIF_2_min_crit} ~ ${Damage_10_pDIF_2_max_crit}]
+11 [${Damage_11_pDIF_2_min} ~ ${Damage_11_pDIF_2_max}]    (crit)[${Damage_11_pDIF_2_min_crit} ~ ${Damage_11_pDIF_2_max_crit}]
-----
Expected Damage (4.0 pDIF cap)
+ 2 [${Damage_2_pDIF_4_min} ~ ${Damage_2_pDIF_4_max}]    (crit)[${Damage_2_pDIF_4_min_crit} ~ ${Damage_2_pDIF_4_max_crit}]
+10 [${Damage_10_pDIF_4_min} ~ ${Damage_10_pDIF_4_max}]    (crit)[${Damage_10_pDIF_4_min_crit} ~ ${Damage_10_pDIF_4_max_crit}]
+11 [${Damage_11_pDIF_4_min} ~ ${Damage_11_pDIF_4_max}]    (crit)[${Damage_11_pDIF_4_min_crit} ~ ${Damage_11_pDIF_4_max_crit}]
-----
Expected Damage (8.0 pDIF cap)
+ 2 [${Damage_2_pDIF_8_min} ~ ${Damage_2_pDIF_8_max}]    (crit)[${Damage_2_pDIF_8_min_crit} ~ ${Damage_2_pDIF_8_max_crit}]
+10 [${Damage_10_pDIF_8_min} ~ ${Damage_10_pDIF_8_max}]    (crit)[${Damage_10_pDIF_8_min_crit} ~ ${Damage_10_pDIF_8_max_crit}]
+11 [${Damage_11_pDIF_8_min} ~ ${Damage_11_pDIF_8_max}]    (crit)[${Damage_11_pDIF_8_min_crit} ~ ${Damage_11_pDIF_8_max_crit}]
]]

local function parse_stat_packet_0X61( packet_raw )
    if windower.ffxi.get_player().main_job_id ~= 0x17 then
        return
    end

    local packet_data = PACKETS.parse( "incoming", packet_raw )

    local species_id = windower.ffxi.get_mjob_data().species

    if species_id == nil then
        return
    end

    base_dmg_data.level          = windower.ffxi.get_player().main_job_level
    base_dmg_data.str = packet_data["Base STR"] + packet_data["Added STR"]

    base_dmg_data.fSTR_MIN       = - 2 * math.floor(1 + base_dmg_data.level / 5)
    base_dmg_data.fSTR_MAX       = 5 + math.floor(base_dmg_data.level / 5)

    base_dmg_data.fSTR_MAX_REQ   = base_dmg_data.fSTR_MAX * 4 + 4
    base_dmg_data.fSTR_MIN_REQ   = base_dmg_data.fSTR_MIN * 4 - 9

    base_dmg_data.DMG            = base_dmg_data.level + base_dmg_data.fSTR_MAX
    base_dmg_data.DMG_2          = base_dmg_data.DMG + 2
    base_dmg_data.DMG_10         = base_dmg_data.DMG + 10
    base_dmg_data.DMG_11         = base_dmg_data.DMG + 11

    for _, dmg in ipairs( {"2", "10", "11"} ) do
        for _, pdif in ipairs( {2, 4, 8 } ) do
            base_dmg_data["Damage_" .. dmg .. "_pDIF_" .. pdif .. "_min" ] = math.floor((base_dmg_data["DMG_" .. dmg] * pdif))
            base_dmg_data["Damage_" .. dmg .. "_pDIF_" .. pdif .. "_max" ] = math.floor((base_dmg_data["DMG_" .. dmg] * pdif) * 1.05)
            base_dmg_data["Damage_" .. dmg .. "_pDIF_" .. pdif .. "_min_crit" ] = math.floor((base_dmg_data["DMG_" .. dmg] * (pdif + 1)))
            base_dmg_data["Damage_" .. dmg .. "_pDIF_" .. pdif .. "_max_crit" ] = math.floor((base_dmg_data["DMG_" .. dmg] * (pdif + 1)) * 1.05)
        end
    end
end

windower.register_event( 'load', function()
    BASE_DMG_TEXT = TEXTS.new(base_dmg_str)
    TEXTS.font( BASE_DMG_TEXT, 'Consolas' )
end )

windower.register_event( 'prerender', function()
    BASE_DMG_TEXT:update( base_dmg_data )
end)

windower.register_event( 'incoming chunk', function( type_id, packet_raw, modified, injected, blocked )
    if injected or blocked then return end

    if type_id == 0x061 then
        parse_stat_packet_0X61( packet_raw )
    end
end )
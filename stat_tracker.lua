local config = require("config")
local PACKETS = require("PACKETS")
local res = require("resources")

local saved_stats = config.load( "data/monster_stats.xml", T{} )

local function get_sorted_integer_keys( table_to_sort )
    local keys = {}
    for key, _ in pairs( table_to_sort ) do
        table.insert(keys, tonumber(key))
    end

    table_to_sort.sort( keys )
    return keys
end

local function export_markdown()
    local file_name = windower.addon_path .. 'exported/exported.md'

    local f = io.open( file_name, 'w+' )

    if f == nil then
        print( string.format( 'Error opening export file "%s"', file_name ) )
        return
    end

    f:write( [[# Stat Tables

_The following stats have been obtained as-is from the game._
_Unfortunately merit points affect monster stats and are included in the listed values, but all merit point categories are at the maximum and will affect all stats consistently._

]])

    for _, species_key in ipairs( get_sorted_integer_keys( saved_stats ) ) do
        local species_data = saved_stats[ tostring(species_key) ]

        f:write( string.format( "### %s\n\n", species_data.species ))
        f:write( "|Level| HP  | MP  | STR | DEX | VIT | AGI | INT | MND | CHR |\n" )
        f:write( "|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|\n" )

        for _, level in ipairs( get_sorted_integer_keys( species_data.level_data ) ) do
            level = tostring(level)
            local stats = species_data.level_data[level]
            f:write( string.format( "| %d | %d | %d | %d | %d | %d | %d | %d | %d | %d |\n",
                level, stats.hp, stats.mp, stats.str, stats.dex, stats.vit, stats.agi, stats.int, stats.mnd, stats.chr ) )
        end

        f:write( "\n\n" )
    end

    print( string.format( "Exported markdown @ %s", file_name ) )
end

local function export_lua()
    local file_name = windower.addon_path .. 'exported/exported.lua'

    local f = io.open( file_name, 'w+' )

    if f == nil then
        print( string.format( 'Error opening export file "%s"', file_name ) )
        return
    end

    f:write( 'return {\n' )

    for _, species_key in ipairs( get_sorted_integer_keys( saved_stats ) ) do
        local species_data = saved_stats[ tostring(species_key) ]

        f:write( string.format( '\t[%s] = {\n', species_data.id ) )

        f:write( string.format( '\t\t["species_id"] = %s,\n', tostring(species_data.id) ) )
        f:write( string.format( '\t\t["species"] = "%s",\n', species_data.species ) )

        for _, key in ipairs( get_sorted_integer_keys( species_data.level_data ) ) do
            key = tostring(key)
            f:write( string.format( '\t\t[%2s] = { ', key ) )

            for stat, stat_val in pairs( species_data.level_data[key] ) do
                if stat == 'hp' or stat == 'mp' then
                    f:write( string.format( '%3s = %5d, ', stat, stat_val ) )
                else
                    f:write( string.format( '%3s = %3d, ', stat, stat_val ) )
                end
            end
            f:write( ' },\n' )
        end

        f:write( '\t},\n')
    end

    f:write( '}' )
    f:close()

    print( string.format( "Exported lua @ %s", file_name ) )
end

local function export_sql()
    local file_name = windower.addon_path .. 'exported/exported.sql'

    local f = io.open( file_name, 'w+' )

    if f == nil then
        print( string.format( 'Error opening export file "%s"', file_name ) )
        return
    end

    f:write('INSERT INTO\n')
    f:write('\t`monster_stats_per_level` ( `species_id`, `species`, `level`, `hp`, `mp`, `str`, `dex`, `vit`, `agi`, `int`, `mnd`, `chr` ) \n')
    f:write('VALUES\n')

    for _, species_key in ipairs( get_sorted_integer_keys( saved_stats ) ) do
        local species_data = saved_stats[ tostring( species_key ) ]

        for _, level_key in ipairs( get_sorted_integer_keys( species_data.level_data ) ) do
            level_key = tostring(level_key)

            f:write( string.format(
                "\t( %3d, %2s, %5d, %5d, %3d, %3d, %3d, %3d, %3d, %3d, %3d, %s ),\n",
                species_data.id,
                level_key,
                species_data.level_data[level_key].hp,
                species_data.level_data[level_key].mp,
                species_data.level_data[level_key].str,
                species_data.level_data[level_key].dex,
                species_data.level_data[level_key].vit,
                species_data.level_data[level_key].agi,
                species_data.level_data[level_key].int,
                species_data.level_data[level_key].mnd,
                species_data.level_data[level_key].chr,
                '"' .. species_data.species .. '"'
            ) )
        end
    end

    f:write("\t(0, \"-\", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 )\n")
    f:write("ON DUPLICATE KEY UPDATE\n")
    f:write("\t`species_id` = VALUES(`species_id`),\n")
    f:write("\t`species` = VALUES(`species`),\n")
    f:write("\t`level` = VALUES(`level`),\n")
    f:write("\t`hp` = VALUES(`hp`),\n")
    f:write("\t`mp` = VALUES(`mp`),\n")
    f:write("\t`str` = VALUES(`str`),\n")
    f:write("\t`dex` = VALUES(`dex`),\n")
    f:write("\t`agi` = VALUES(`agi`),\n")
    f:write("\t`int` = VALUES(`int`),\n")
    f:write("\t`mnd` = VALUES(`mnd`),\n")
    f:write("\t`chr` = VALUES(`chr`);")

    f:close()

    print( string.format( "Exported sql @ %s", file_name ) )
end

local function stat_scraper( packet_id, packet_raw )
    if packet_id == 0x061 then
        if windower.ffxi.get_player().main_job_id ~= 0x17 then
            return
        end

        local packet_data = PACKETS.parse( "incoming", packet_raw )

        local player_level_key = tostring( windower.ffxi.get_player().main_job_level )
        local species_id = windower.ffxi.get_mjob_data().species

        if species_id == nil then
            return
        end

        local species_id_key = tostring( species_id )

        if saved_stats[species_id_key] == nil then
            saved_stats[species_id_key] = {
                id = species_id,
                species = RES.monstrosity[species_id].en,
                level_data = {},
            }
        end

        saved_stats[species_id_key].level_data[player_level_key] = {
            ["hp"] = packet_data["Maximum HP"],
            ["mp"] = packet_data["Maximum MP"],
            ["str"] = packet_data["Base STR"],
            ["dex"] = packet_data["Base DEX"],
            ["vit"] = packet_data["Base VIT"],
            ["agi"] = packet_data["Base AGI"],
            ["int"] = packet_data["Base INT"],
            ["mnd"] = packet_data["Base MND"],
            ["chr"] = packet_data["Base CHR"],
        }

        config.save( saved_stats )
    end
end

local function command_handler( command, ... )
    local params = {...}
    if command == "e" or command == "export" then
        export_lua()
        export_markdown()
        export_sql()
    end
end

LOAD_FNS = LOAD_FNS or {}
LOAD_FNS['stats'] = function()
    LOADED_ADDONS = LOADED_ADDONS or {}

    if LOADED_ADDONS['stats'] == nil then
        print("Loading stat submodule")
        LOADED_ADDONS['stats'] = {
            windower.register_event( "incoming chunk", stat_scraper ),
            windower.register_event( "addon command", command_handler ),
        }
    else
        print( "Module 'stats' already loaded.")
    end
end
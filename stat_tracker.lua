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

local function get_monster_entry_for_sheets( level, monster_id )
    local monster_key = tostring(monster_id)

    if not saved_stats[tostring( monster_id )] then
        return { hp = '', mp = '', str = '', dex = '', vit = '', agi = '', int = '', mnd = '', chr = '' }
    end

    local level_key = tostring(level)

    if not saved_stats[monster_key]['level_data'][level_key] then
        return { hp = '', mp = '', str = '', dex = '', vit = '', agi = '', int = '', mnd = '', chr = '' }
    end

    return saved_stats[monster_key]['level_data'][level_key]
end

local function export_sheets()
    local file_name = windower.addon_path .. 'exported/exported.txt'

    local f = io.open( file_name, 'w+' )

    if f == nil then
        print( string.format( 'Error opening export file "%s"', file_name ) )
        return
    end

    local valid_monster_ids = {}

    local stats = { 'hp', 'mp', 'str', 'dex', 'vit', 'agi', 'int', 'mnd', 'chr' }

    for idx = 1, 511 do
        if RES.monstrosity[idx] then
            table.insert( valid_monster_ids, idx )
        end
    end

    do
        local id_line = "Monster ID\t"
        local species_line = "Level\t"
        local stat_line = "Stat\t"

        for _, stat in ipairs( stats ) do
            for _, idx in pairs( valid_monster_ids ) do
                local monster_name = string.gsub( RES.monstrosity[idx].en, " %(.*%)", "")
                id_line = id_line .. idx .. "\t"
                species_line = species_line .. monster_name .. "\t"
                stat_line = stat_line .. string.upper( stat ) .. "\t"
            end
        end

        f:write( string.format( "%s\n%s\n%s\n", stat_line, id_line, species_line ) )
    end

    local strings = {}

    for level = 1, 99 do
        strings['hp'] = ""
        strings['mp'] = ""
        strings['str'] = ""
        strings['dex'] = ""
        strings['vit'] = ""
        strings['agi'] = ""
        strings['int'] = ""
        strings['mnd'] = ""
        strings['chr'] = ""

        for _, monster_id in ipairs( valid_monster_ids ) do
            local result = get_monster_entry_for_sheets( level, monster_id )

            for _, stat in ipairs( stats ) do
                strings[stat] = strings[stat] .. result[stat] .. '\t'
            end
        end

        f:write( string.format("%d\t%s%s%s%s%s%s%s%s%s\n",
            level,
            strings['hp'],
            strings['mp'],
            strings['str'],
            strings['dex'],
            strings['vit'],
            strings['agi'],
            strings['int'],
            strings['mnd'],
            strings['chr']
        ) )
    end

    f:close()

    print( string.format( "Exported sheets compatible txt @ %s", file_name ) )
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

local SQL_SETUP_STRING_MONSTER_STATS =
[[CREATE TABLE IF NOT EXISTS `monster_stats_per_level` (
	`species_id` SMALLINT UNSIGNED,
	`level` TINYINT UNSIGNED,
	`hp` SMALLINT UNSIGNED,
	`mp` SMALLINT UNSIGNED,
	`str` SMALLINT UNSIGNED,
	`dex` SMALLINT UNSIGNED,
	`vit` SMALLINT UNSIGNED,
	`agi` SMALLINT UNSIGNED,
	`int` SMALLINT UNSIGNED,
	`mnd` SMALLINT UNSIGNED,
	`chr` SMALLINT UNSIGNED,
	PRIMARY KEY (`species_id`, `level`)
);

INSERT INTO
    `monster_stats_per_level` ( `species_id`, `level`, `hp`, `mp`, `str`, `dex`, `vit`, `agi`, `int`, `mnd`, `chr` )
VALUES
]]

local SQL_TEARDOWN_STRING_MONSTER_STATS =
[[
    (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 )
ON DUPLICATE KEY UPDATE
    `species_id` = VALUES(`species_id`),
    `level` = VALUES(`level`),
    `hp` = VALUES(`hp`),
    `mp` = VALUES(`mp`),
    `str` = VALUES(`str`),
    `dex` = VALUES(`dex`),
    `agi` = VALUES(`agi`),
    `int` = VALUES(`int`),
    `mnd` = VALUES(`mnd`),
    `chr` = VALUES(`chr`);]]

local SQL_SETUP_STRING_MONSTER_SPECIES =
[[CREATE TABLE IF NOT EXISTS `monster_species` (
	`species_id` SMALLINT UNSIGNED,
	`species` VARCHAR(32),
	PRIMARY KEY (`species_id`)
);

INSERT INTO
    `monster_species` ( `species_id`, `species` )
VALUES
]]

local SQL_TEARDOWN_STRING_MONSTER_SPECIES =
[[
    (0, "-" )
ON DUPLICATE KEY UPDATE
    `species_id` = VALUES(`species_id`),
    `species` = VALUES(`species`);]]

local function export_monster_species_list_sql()
    local file_name = windower.addon_path .. 'exported/monster_species.sql'

    local f = io.open( file_name, 'w+' )

    if f == nil then
        print( string.format( 'Error opening export file "%s"', file_name ) )
        return
    end

    f:write( SQL_SETUP_STRING_MONSTER_SPECIES )

    for idx = 1, 511 do
        local species_name = RES.monstrosity[idx] and RES.monstrosity[idx].en or '-'
        f:write( string.format(
            "\t( %3d, \"%s\" ),\n",
            idx,
            species_name
        ))
    end

    f:write( SQL_TEARDOWN_STRING_MONSTER_SPECIES )

    f:close()

    print( string.format( "Exported sql @ %s", file_name ) )
end

local function export_sql()
    export_monster_species_list_sql()
    local file_name = windower.addon_path .. 'exported/exported.sql'

    local f = io.open( file_name, 'w+' )

    if f == nil then
        print( string.format( 'Error opening export file "%s"', file_name ) )
        return
    end


    f:write( SQL_SETUP_STRING_MONSTER_STATS )

    for _, species_key in ipairs( get_sorted_integer_keys( saved_stats ) ) do
        local species_data = saved_stats[ tostring( species_key ) ]

        for _, level_key in ipairs( get_sorted_integer_keys( species_data.level_data ) ) do
            level_key = tostring(level_key)

            f:write( string.format(
                "\t( %3d, %2s, %5d, %5d, %3d, %3d, %3d, %3d, %3d, %3d, %3d ),\n",
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
                species_data.level_data[level_key].chr
            ) )
        end
    end

    f:write( SQL_TEARDOWN_STRING_MONSTER_STATS )

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

        windower.add_to_chat( 1, string.format("Got stats for [%s] @ LV%s", RES.monstrosity[species_id].en, player_level_key))

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

local function validate_imported_table( file_path )
    local imported_data = config.load( file_path )

    local stat_keys = { "agi", "chr", "dex", "hp", "int", "mnd", "mp", "str", "vit" }

    for monster_key, monster_table in pairs( imported_data ) do
        if tostring(monster_key) ~= tostring(monster_table.id) then
            print( string.format( "Malformed/missing monster id [%s] in imported table.", tostring(monster_key)))
            return nil
        end

        if tonumber(monster_key) < 1 or tonumber(monster_key) > 512 then
            print( string.format( "Out-of-bounds monster id [%s] in imported table.", tostring(monster_key)))
            return nil
        end

        if monster_table.species == nil or type(monster_table.species) ~= "string" then
            print( string.format( "Malformed/missing species name for monster id [%s]", tostring(monster_key) ) )
            return nil
        end

        if monster_table.level_data == nil then
            print( string.format( "No level data for monster id [%s], continuing", tostring(monster_key)))
        elseif type(monster_table.level_data) ~= "table" then
            print( string.format( "Malformed level data (not a table) for monster id [%s]", tostring(monster_key)))
            return nil
        end

        for level_key, level_data in pairs( monster_table.level_data ) do
            local converted_level = tonumber(level_key)

            if converted_level == nil then
               print( string.format( "Malformed level entry [LV%s] for monster id [%s]", level_key, monster_key))
               return nil
            end
            if converted_level < 1 or converted_level > 99 then
               print( string.format( "Out-of-bounds level entry [LV%s] for monster id [%s]", level_key, monster_key))
               return nil
            end

            for _, stat_key in pairs( stat_keys ) do
                if level_data[stat_key] == nil then
                    print( string.format( "Missing entry for stat [%s] in level [LV%s] for monster id [%s]", stat_key, level_key, monster_key))
                    return nil
                end

                if type(level_data[stat_key]) ~= "number" or level_data[stat_key] < 0 then
                    print( string.format( "Malformed entry for stat [%s] in level [LV%s] for monster id [%s]", stat_key, level_key, monster_key))
                    return nil
                end
            end
        end
    end

    return imported_data
end

local function try_import( file_path )
    if not windower.file_exists( windower.addon_path .. file_path ) then
        print( string.format( "File '%s' does not exist.", file_path ) )
        return
    end

    local imported_data = validate_imported_table( file_path )

    if imported_data == nil then
        return
    end

    for species_id_key, monster_table in pairs( imported_data ) do
        local species_id = tonumber(species_id_key)

        if saved_stats[species_id_key] == nil then
            saved_stats[species_id_key] = {
                id = species_id,
                species = RES.monstrosity[species_id].en,
                level_data = {},
            }
        end

        for level_key, level_data in pairs( monster_table.level_data ) do
            if saved_stats[species_id_key]['level_data'][level_key] == nil then
                saved_stats[species_id_key]['level_data'][level_key] = level_data
            else
                for stat_key, stat_value in pairs(level_data) do
                    if saved_stats[species_id_key]['level_data'][level_key][stat_key] ~= stat_value then
                        print( string.format( "Non-matching stat data for '%s' @ monster id [%s] [LV%s]", stat_key, species_id_key, level_key))
                    end
                end
            end
        end
    end

    print("Import successful.")
end

local function import_handler( file_name )
    local suffix = string.sub(file_name, -4, -4)

    if suffix == ".xml" then
        try_import( "data/" .. file_name )
    else
        try_import( "data/" .. file_name .. ".xml" )
    end
end

local function command_handler( command, ... )
    local params = {...}
    if command == "e" or command == "export" then
        export_lua()
        export_markdown()
        export_sql()
        export_sheets()
    end

    if command == "i" or command == "import" then
        import_handler( params[1] )
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
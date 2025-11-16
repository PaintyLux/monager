local monster_jobs = require("monster_jobs")

local LAST_CHAR_UPDATE_PACKET = {}
local BASELINE_STATS = {}

local IS_SEARCHING = false
local BASE_ATK = 0
local CURRENT_COEFF_CHECKING = 0
local UNIQUE_RESULT_IF_ATK_MATCHES = 0
local UNIQUE_COEFFICIENT_TERMS = {}
local FALSE_POSITIVES = {}

function reset_globals()
    IS_SEARCHING = false
    BASE_ATK = 0
    CURRENT_COEFF_CHECKING = 0
    UNIQUE_RESULT_IF_ATK_MATCHES = 0
    UNIQUE_COEFFICIENT_TERMS = {}
    FALSE_POSITIVES = {}
end

local combat_skill_values = {
    [1] = 6,    [2] = 9,    [3] = 12,   [4] = 15,   [5] = 18,   [6] = 21,   [7] = 24,   [8] = 27,   [9] = 30,   [10] = 33,
    [11] = 36,  [12] = 39,  [13] = 42,  [14] = 45,  [15] = 48,  [16] = 51,  [17] = 54,  [18] = 57,  [19] = 60,  [20] = 63,
    [21] = 66,  [22] = 69,  [23] = 72,  [24] = 75,  [25] = 78,  [26] = 81,  [27] = 84,  [28] = 87,  [29] = 90,  [30] = 93,
    [31] = 96,  [32] = 99,  [33] = 102, [34] = 105, [35] = 108, [36] = 111, [37] = 114, [38] = 117, [39] = 120, [40] = 123,
    [41] = 126, [42] = 129, [43] = 132, [44] = 135, [45] = 138, [46] = 141, [47] = 144, [48] = 147, [49] = 150, [50] = 153,
    [51] = 158, [52] = 163, [53] = 168, [54] = 173, [55] = 178, [56] = 183, [57] = 188, [58] = 193, [59] = 198, [60] = 203,
    [61] = 207, [62] = 212, [63] = 217, [64] = 222, [65] = 227, [66] = 232, [67] = 236, [68] = 241, [69] = 246, [70] = 251,
    [71] = 256, [72] = 261, [73] = 266, [74] = 271, [75] = 276, [76] = 281, [77] = 286, [78] = 291, [79] = 296, [80] = 301,
    [81] = 307, [82] = 313, [83] = 319, [84] = 325, [85] = 331, [86] = 337, [87] = 343, [88] = 349, [89] = 355, [90] = 361,
    [91] = 368, [92] = 375, [93] = 382, [94] = 389, [95] = 396, [96] = 403, [97] = 410, [98] = 417, [99] = 424,
}

local attack_increase_loadouts = {
    [1] =  { ['Instinct 1'] = 0xFFFF, ['Instinct 2'] = 0xFFFF, ['Instinct 3'] = 0xFFFF, ['Instinct 4'] =    768, ['Instinct 5'] = 0xFFFF, ['Instinct 6'] = 0xFFFF, },
    [2] =  { ['Instinct 1'] = 0xFFFF, ['Instinct 2'] = 0xFFFF, ['Instinct 3'] = 0xFFFF, ['Instinct 4'] =    768, ['Instinct 5'] =    773, ['Instinct 6'] = 0xFFFF, },
    [5] =  { ['Instinct 1'] = 0xFFFF, ['Instinct 2'] =    132, ['Instinct 3'] = 0xFFFF, ['Instinct 4'] = 0xFFFF, ['Instinct 5'] = 0xFFFF, ['Instinct 6'] = 0xFFFF, },
    [6] =  { ['Instinct 1'] = 0xFFFF, ['Instinct 2'] =    132, ['Instinct 3'] = 0xFFFF, ['Instinct 4'] =    768, ['Instinct 5'] = 0xFFFF, ['Instinct 6'] = 0xFFFF, },
    [7] =  { ['Instinct 1'] = 0xFFFF, ['Instinct 2'] =    132, ['Instinct 3'] = 0xFFFF, ['Instinct 4'] =    768, ['Instinct 5'] =    773, ['Instinct 6'] = 0xFFFF, },
    [10] = { ['Instinct 1'] =     24, ['Instinct 2'] = 0xFFFF, ['Instinct 3'] = 0xFFFF, ['Instinct 4'] = 0xFFFF, ['Instinct 5'] = 0xFFFF, ['Instinct 6'] = 0xFFFF, },
    [11] = { ['Instinct 1'] =     24, ['Instinct 2'] = 0xFFFF, ['Instinct 3'] = 0xFFFF, ['Instinct 4'] =    768, ['Instinct 5'] = 0xFFFF, ['Instinct 6'] = 0xFFFF, },
    [12] = { ['Instinct 1'] =     24, ['Instinct 2'] = 0xFFFF, ['Instinct 3'] = 0xFFFF, ['Instinct 4'] =    768, ['Instinct 5'] =    773, ['Instinct 6'] = 0xFFFF, },
    [15] = { ['Instinct 1'] =     24, ['Instinct 2'] =    132, ['Instinct 3'] = 0xFFFF, ['Instinct 4'] = 0xFFFF, ['Instinct 5'] = 0xFFFF, ['Instinct 6'] = 0xFFFF, },
    [16] = { ['Instinct 1'] =     24, ['Instinct 2'] =    132, ['Instinct 3'] = 0xFFFF, ['Instinct 4'] =    768, ['Instinct 5'] = 0xFFFF, ['Instinct 6'] = 0xFFFF, },
    [17] = { ['Instinct 1'] =     24, ['Instinct 2'] =    132, ['Instinct 3'] = 0xFFFF, ['Instinct 4'] =    768, ['Instinct 5'] =    773, ['Instinct 6'] = 0xFFFF, },
    [20] = { ['Instinct 1'] =     24, ['Instinct 2'] = 0xFFFF, ['Instinct 3'] =      3, ['Instinct 4'] = 0xFFFF, ['Instinct 5'] = 0xFFFF, ['Instinct 6'] = 0xFFFF, },
    [21] = { ['Instinct 1'] =     24, ['Instinct 2'] = 0xFFFF, ['Instinct 3'] =      3, ['Instinct 4'] =    768, ['Instinct 5'] = 0xFFFF, ['Instinct 6'] = 0xFFFF, },
    [22] = { ['Instinct 1'] =     24, ['Instinct 2'] = 0xFFFF, ['Instinct 3'] =      3, ['Instinct 4'] =    768, ['Instinct 5'] =    773, ['Instinct 6'] = 0xFFFF, },
    [25] = { ['Instinct 1'] =     24, ['Instinct 2'] =    132, ['Instinct 3'] =      3, ['Instinct 4'] = 0xFFFF, ['Instinct 5'] = 0xFFFF, ['Instinct 6'] = 0xFFFF, },
    [26] = { ['Instinct 1'] =     24, ['Instinct 2'] =    132, ['Instinct 3'] =      3, ['Instinct 4'] =    768, ['Instinct 5'] = 0xFFFF, ['Instinct 6'] = 0xFFFF, },
    [27] = { ['Instinct 1'] =     24, ['Instinct 2'] =    132, ['Instinct 3'] =      3, ['Instinct 4'] =    768, ['Instinct 5'] =    773, ['Instinct 6'] = 0xFFFF, },
    [30] = { ['Instinct 1'] = 0xFFFF, ['Instinct 2'] = 0xFFFF, ['Instinct 3'] = 0xFFFF, ['Instinct 4'] = 0xFFFF, ['Instinct 5'] = 0xFFFF, ['Instinct 6'] =    778, },
    [31] = { ['Instinct 1'] = 0xFFFF, ['Instinct 2'] = 0xFFFF, ['Instinct 3'] = 0xFFFF, ['Instinct 4'] =    768, ['Instinct 5'] = 0xFFFF, ['Instinct 6'] =    778, },
    [32] = { ['Instinct 1'] = 0xFFFF, ['Instinct 2'] = 0xFFFF, ['Instinct 3'] = 0xFFFF, ['Instinct 4'] =    768, ['Instinct 5'] =    773, ['Instinct 6'] =    778, },
    [35] = { ['Instinct 1'] = 0xFFFF, ['Instinct 2'] =    132, ['Instinct 3'] = 0xFFFF, ['Instinct 4'] = 0xFFFF, ['Instinct 5'] = 0xFFFF, ['Instinct 6'] =    778, },
    [36] = { ['Instinct 1'] = 0xFFFF, ['Instinct 2'] =    132, ['Instinct 3'] = 0xFFFF, ['Instinct 4'] =    768, ['Instinct 5'] = 0xFFFF, ['Instinct 6'] =    778, },
    [37] = { ['Instinct 1'] = 0xFFFF, ['Instinct 2'] =    132, ['Instinct 3'] = 0xFFFF, ['Instinct 4'] =    768, ['Instinct 5'] =    773, ['Instinct 6'] =    778, },
    [40] = { ['Instinct 1'] =     24, ['Instinct 2'] = 0xFFFF, ['Instinct 3'] = 0xFFFF, ['Instinct 4'] = 0xFFFF, ['Instinct 5'] = 0xFFFF, ['Instinct 6'] =    778, },
    [41] = { ['Instinct 1'] =     24, ['Instinct 2'] = 0xFFFF, ['Instinct 3'] = 0xFFFF, ['Instinct 4'] =    768, ['Instinct 5'] = 0xFFFF, ['Instinct 6'] =    778, },
    [42] = { ['Instinct 1'] =     24, ['Instinct 2'] = 0xFFFF, ['Instinct 3'] = 0xFFFF, ['Instinct 4'] =    768, ['Instinct 5'] =    773, ['Instinct 6'] =    778, },
    [45] = { ['Instinct 1'] =     24, ['Instinct 2'] =    132, ['Instinct 3'] = 0xFFFF, ['Instinct 4'] =    768, ['Instinct 5'] = 0xFFFF, ['Instinct 6'] = 0xFFFF, },
    [46] = { ['Instinct 1'] =     24, ['Instinct 2'] =    132, ['Instinct 3'] = 0xFFFF, ['Instinct 4'] =    768, ['Instinct 5'] = 0xFFFF, ['Instinct 6'] =    778, },
    [47] = { ['Instinct 1'] =     24, ['Instinct 2'] =    132, ['Instinct 3'] = 0xFFFF, ['Instinct 4'] =    768, ['Instinct 5'] =    773, ['Instinct 6'] =    778, },
    [50] = { ['Instinct 1'] =     24, ['Instinct 2'] = 0xFFFF, ['Instinct 3'] =      3, ['Instinct 4'] = 0xFFFF, ['Instinct 5'] = 0xFFFF, ['Instinct 6'] =    778, },
    [51] = { ['Instinct 1'] =     24, ['Instinct 2'] = 0xFFFF, ['Instinct 3'] =      3, ['Instinct 4'] =    768, ['Instinct 5'] = 0xFFFF, ['Instinct 6'] =    778, },
    [52] = { ['Instinct 1'] =     24, ['Instinct 2'] = 0xFFFF, ['Instinct 3'] =      3, ['Instinct 4'] =    768, ['Instinct 5'] =    773, ['Instinct 6'] =    778, },
    [55] = { ['Instinct 1'] =     24, ['Instinct 2'] =    132, ['Instinct 3'] =      3, ['Instinct 4'] =    778, ['Instinct 5'] = 0xFFFF, ['Instinct 6'] = 0xFFFF, },
    [56] = { ['Instinct 1'] =     24, ['Instinct 2'] =    132, ['Instinct 3'] =      3, ['Instinct 4'] =    768, ['Instinct 5'] = 0xFFFF, ['Instinct 6'] =    778, },
    [57] = { ['Instinct 1'] =     24, ['Instinct 2'] =    132, ['Instinct 3'] =      3, ['Instinct 4'] =    768, ['Instinct 5'] =    773, ['Instinct 6'] =    778, },
}

local attack_instincts = {
    [3] = 10,
    [24] = 10,
    [132] = 5,
    [768] = 1,
    [773] = 1,
    [778] = 30,
}

local function inject_fake_inventory_open_packet()
    PACKETS.inject( PACKETS.new( "outgoing", 0x061, {}) )
end

local function reset_instincts()
    if windower.ffxi.get_player().main_job_id ~= 0x17 then
        print( "Cannot equip instincts while on a non-MON job." )
        return
    end

    local zone = RES.zones[ windower.ffxi.get_info().zone ]

    if not zone or zone.en ~= "Feretory" then
        print( "Cannot equip instincts outside of the Feretory." )
        return
    end

    local packet_data = {
        ["Main Job"] = 0x17,
        ["Sub Job"] = 0,
        ["Flag"] = 4,
        ["Species"] = 2,
        ["_unknown2"] = 2,
        ["Name 1"] = 80,
        ["Name 2"] = 80,
    }

    for slot, v in pairs( windower.ffxi.get_mjob_data().instincts ) do
        if tonumber(v) ~= 0 and tonumber(slot) < 13 then
            packet_data["Instinct " .. slot ] = 65535
        end
    end

    PACKETS.inject( PACKETS.new( "outgoing", 0x102, packet_data ) )
end

local function calculate_attack_bonus_trait()
    for _, trait_id in pairs(windower.ffxi.get_abilities().job_traits) do
        if trait_id == 3 then
            local level = windower.ffxi.get_player().main_job_level
            local species_id = windower.ffxi.get_mjob_data().species
            local jobs = monster_jobs[species_id]

            local attack_bonus = 0

            for _, job in pairs( jobs ) do
                if job == "WAR" then
                    if level >= 91 then
                        attack_bonus = math.max( attack_bonus, 35 )
                    elseif level >= 65 then
                        attack_bonus = math.max( attack_bonus, 22 )
                    elseif level >= 30 then
                        attack_bonus = math.max( attack_bonus, 10 )
                    end
                end

                if job == "DRK" then
                    if level == 99 then
                        attack_bonus = math.max( attack_bonus, 96 )
                    elseif level >= 91 then
                        attack_bonus = math.max( attack_bonus, 84 )
                    elseif level >= 83 then
                        attack_bonus = math.max( attack_bonus, 72 )
                    elseif level >= 76 then
                        attack_bonus = math.max( attack_bonus, 60 )
                    elseif level >= 70 then
                        attack_bonus = math.max( attack_bonus, 48 )
                    elseif level >= 50 then
                        attack_bonus = math.max( attack_bonus, 35 )
                    elseif level >= 30 then
                        attack_bonus = math.max( attack_bonus, 22 )
                    elseif level >= 10 then
                        attack_bonus = math.max( attack_bonus, 10 )
                    end
                end

                if job == "DRG" then
                    if level >= 91 then
                        attack_bonus = math.max( attack_bonus, 22 )
                    elseif level >= 10 then
                        attack_bonus = math.max( attack_bonus, 10 )
                    end
                end
            end

            print( string.format("Monster has +%d Attack Bonus from job traits", attack_bonus))

            return attack_bonus
        end
    end

    return 0
end

local function calculate_potential_coefficients( base_atk, target_atk, coarse_coeff)
    coarse_coeff = math.floor( coarse_coeff ) - 1

    local valid_results = {}
    local res = base_atk * (1 + coarse_coeff / 1024)

    while math.floor( res ) <= target_atk do
        if math.floor( res ) == target_atk then
            valid_results[coarse_coeff] = coarse_coeff
        end

        coarse_coeff = coarse_coeff + 1
        res = base_atk * (1 + coarse_coeff / 1024)
    end

    return valid_results
end

local function calculate_divergence( base_atk, coeff_table )
    local unique_results = {}

    local atk_increase = 1

    while atk_increase < 57 do
        local check_collisions = {}
        local scratch_results = {}

        for _, coeff in pairs( coeff_table ) do
            local atk_val = math.floor((base_atk + atk_increase) * (1 + coeff/1024))
            scratch_results[coeff] = atk_val

            if check_collisions[atk_val] == nil then
                check_collisions[atk_val] = 1
            else
                check_collisions[atk_val] = check_collisions[atk_val] + 1
            end
        end

        for atk_result, count in pairs( check_collisions ) do
            if count == 1 then
                for coeff, atk_val in pairs( scratch_results ) do
                    if atk_val == atk_result then
                        unique_results[atk_increase] = coeff
                    end
                end
            end
        end
        atk_increase = atk_increase + 1
    end

    return unique_results
end

local function get_term()
    for bonus_atk, coeff in pairs( UNIQUE_COEFFICIENT_TERMS ) do
        return bonus_atk, coeff
    end
end

local function run_search()
    local bonus_atk, coeff = get_term()

    if bonus_atk == nil then
        print( "Could not find a way to positively isolate correct ATK" )

        for coeff, false_positives in pairs(FALSE_POSITIVES) do
            if false_positives == 0 then
                print( string.format("Coefficient [%d/1024] had zero false positives", coeff) )
            end
        end

        reset_globals()
        return
    end

    UNIQUE_COEFFICIENT_TERMS[bonus_atk] = nil

    if not attack_increase_loadouts[bonus_atk] then
        run_search()
        return
    end

    UNIQUE_RESULT_IF_ATK_MATCHES = math.floor((BASE_ATK + bonus_atk) * (1 + coeff / 1024))
    CURRENT_COEFF_CHECKING = coeff

    print( string.format("Checking to see if +%dATK matches unique result for [%d/1024]: [%d]", bonus_atk, CURRENT_COEFF_CHECKING, UNIQUE_RESULT_IF_ATK_MATCHES))

    local packet_data = {
        ["Main Job"] = 0x17,
        ["Sub Job"] = 0,
        ["Flag"] = 4,
        ["Species"] = 2,
        ["_unknown2"] = 2,
        ["Name 1"] = 80,
        ["Name 2"] = 80,
    }

    for slot, v in pairs( attack_increase_loadouts[bonus_atk] ) do
        packet_data[slot] = v
    end

    PACKETS.inject( PACKETS.new( "outgoing", 0x102, packet_data ) )
end

local function calculate_attack()
    BASELINE_STATS = LAST_CHAR_UPDATE_PACKET
    local target_attack = BASELINE_STATS["Attack"]

    print( string.format( "Solving for target attack [%d]", target_attack ) )

    local atk_from_skill = combat_skill_values[ windower.ffxi.get_player().main_job_level ]
    local atk_from_str = math.floor( BASELINE_STATS["Base STR"] / 2 )

    BASE_ATK = 8 + atk_from_skill + atk_from_str + calculate_attack_bonus_trait()

    local coarse_mult = (target_attack / BASE_ATK)
    local coarse_coeff = (coarse_mult - 1) * 1024

    print( string.format( "Base ATK: %s", BASE_ATK ) )
    print( string.format( "Rough ATK Multiplier: [%f] .. approx [%f/1024]", coarse_mult, coarse_coeff ))

    local potential_coeffs = calculate_potential_coefficients( BASE_ATK, target_attack, coarse_coeff )

    FALSE_POSITIVES = {}

    for _, coeff in pairs(potential_coeffs) do
        FALSE_POSITIVES[coeff] = 0
        print( string.format("[%d/1024]:  %f", coeff, BASE_ATK * (1 + coeff/1024) ))
    end

    UNIQUE_COEFFICIENT_TERMS = calculate_divergence( BASE_ATK, potential_coeffs )

    run_search()

    IS_SEARCHING = true
end

local function init_calc_attack()
    inject_fake_inventory_open_packet()
    reset_instincts()
    calculate_attack:schedule( 2, false )
end

local incoming_chunk_fn = function( id, packet_raw )
    if id == 0x061 then
        local packet_data = PACKETS.parse( "incoming", packet_raw )

        LAST_CHAR_UPDATE_PACKET = packet_data

        if IS_SEARCHING then
            if packet_data["Attack"] == UNIQUE_RESULT_IF_ATK_MATCHES then
                print( string.format( "Matched unique attack value [%d]", UNIQUE_RESULT_IF_ATK_MATCHES ) )
                print( string.format( "This creature has a %d/1024 ATK Bonus.", CURRENT_COEFF_CHECKING ) )

                reset_globals()
            else
                print( string.format( "Received Attack value [%d]", packet_data["Attack"]))
                FALSE_POSITIVES[CURRENT_COEFF_CHECKING] = FALSE_POSITIVES[CURRENT_COEFF_CHECKING] + 1
                run_search:schedule(0.5, false)
            end
        end
    end
end


local addon_command_fn = function(command, ...)
    local params = L{...}

    if command == nil then return end

    if command == 'solve' or command == 's' then
        if params[1] == 'atk' or params[1] == 'a' then
            init_calc_attack()
        end
    end

    if command == 'unequip' then
        reset_instincts()
    end
end

LOAD_FNS = LOAD_FNS or {}
LOAD_FNS['atk'] = function()
    LOADED_ADDONS = LOADED_ADDONS or {}

    if LOADED_ADDONS['atk'] == nil then
        print( "Loading 'attack solver' submodule")
        LOADED_ADDONS['atk'] = {
            windower.register_event( 'addon command', addon_command_fn ),
            windower.register_event( 'incoming chunk', incoming_chunk_fn ),
        }
    else
        print( "Module 'attack solver' already loaded.")
    end
end
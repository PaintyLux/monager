--[[
Copyright © 2025, PaintyLux
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of MONager nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL PaintyLux BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]

_addon.name = 'MONager'
_addon.author = 'PaintyLux'
_addon.version = '0.0.0.1'
_addon.commands = { 'mon', 'monager' }

require 'logger'
require 'pack'
require 'tables'

TEXTS       = require 'texts'
PACKETS     = require 'packets'
RES         = require 'resources'

require 'attack_swing_tracker'

PERSISTENT_DATA = {
    species_levels = {},
    unlocked_instincts = {},
    variants = {}
}

CURRENT_DATA = {
    species = nil,
    title = {},
    instincts = {}
}

local function unpack_bitfields( payload )
    local result = {}
    
    for string_offset = 0, #payload do
        local bit_0, bit_1, bit_2, bit_3, bit_4, bit_5, bit_6, bit_7 = string.unpack( payload, 'q1q1q1q1q1q1q1q1', string_offset + 1 )
        
        result[8 * string_offset + 0] = bit_0
        result[8 * string_offset + 1] = bit_1
        result[8 * string_offset + 2] = bit_2
        result[8 * string_offset + 3] = bit_3
        result[8 * string_offset + 4] = bit_4
        result[8 * string_offset + 5] = bit_5
        result[8 * string_offset + 6] = bit_6
        result[8 * string_offset + 7] = bit_7
    end
    
    return result
end

local function parse_monstrosity_persistent_data_0X63( packet_raw )
    local data = PACKETS.parse( 'incoming', packet_raw )

    if data.Order == 3 then
        PERSISTENT_DATA.monster_rank = data['Mon. Rank']
        PERSISTENT_DATA.infamy = data['Infamy']

        CURRENT_DATA.species = data['Species']

        local learned_instincts = unpack_bitfields( data['Instinct Bitfield 1'] )

        for key, unlocked in pairs( learned_instincts ) do
            if unlocked then
                PERSISTENT_DATA.unlocked_instincts[key] = true
            end
        end

        for species_index = 0x00, 0x7F do
            local species_level = string.unpack( data['Monster Level Char field'], 'C', 1 + species_index )

            if species_level > 0 then
                PERSISTENT_DATA.species_levels[ species_index ] = species_level
            else
                PERSISTENT_DATA.species_levels[ species_index ] = nil
            end
        end
    end

    if data.Order == 4 then
        if data['Slime Level'] > 0 then
            PERSISTENT_DATA.species_levels[254] = data['Slime Level']
        end
        if data['Spriggan Level'] > 0 then
            PERSISTENT_DATA.species_levels[255] = data['Spriggan Level']
        end

        local learned_instincts = unpack_bitfields( data['Instinct Bitfield 3'] )

        for key, unlocked in pairs( learned_instincts ) do
            if unlocked then
                PERSISTENT_DATA.unlocked_instincts[ 0x300 + key ] = true
            end
        end

        local available_variants = unpack_bitfields( data['Variants Bitfield'] )

        for key, unlocked in pairs( available_variants ) do
            if unlocked then
                PERSISTENT_DATA.variants[key] = true
            end
        end
    end
end

local function parse_monstrosity_exdata_0X44( packet_raw )
    local data = PACKETS.parse( 'incoming', packet_raw )

    -- Job ID 0x17 is for Monipulators.
    if data.Job ~= 0x17 then
        return
    end

    do
        local equipped_instincts = {}

        for slot = 1,12 do
            equipped_instincts[slot] = data[ 'Instinct ' .. slot ]
        end

        CURRENT_DATA.instincts = equipped_instincts
    end

    CURRENT_DATA.species = data['Species']
    CURRENT_DATA.title = { data['Monstrosity Name 1'], data['Monstrosity Name 2'] }
end

windower.register_event( 'incoming chunk', function( type_id, packet_raw, modified, injected, blocked )
    if injected or blocked then return end

    if type_id == 0x44 then
        parse_monstrosity_exdata_0X44( packet_raw )
    end
    
    if type_id == 0x63 then
        parse_monstrosity_persistent_data_0X63( packet_raw )
    end
end )

windower.register_event( 'addon command', function(command, ...)
    local params = L{...}
    
    if command == nil then return end

    if command == 'reequip' then
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
            ["Main Job"] = 23,
            ["Sub Job"] = 0,
            ["Flag"] = 4,
            ["Species"] = 2,
            ["_unknown2"] = 2,
            ["Name 1"] = 80,
            ["Name 2"] = 80,
        }

        if command == 'reequip' then
            packet_data["Instinct 1"] = 3
            packet_data["Instinct 2"] = 4
            packet_data["Instinct 3"] = 22
            packet_data["Instinct 4"] = 132
            packet_data["Instinct 5"] = 183
            packet_data["Instinct 6"] = 768
            packet_data["Instinct 7"] = 773
            packet_data["Instinct 8"] = 769
            packet_data["Instinct 9"] = 774
            packet_data["Instinct 10"] = 778
            packet_data["Instinct 11"] = 783
            packet_data["Instinct 12"] = 785
        end

        PACKETS.inject( PACKETS.new( 'outgoing', 0x102, packet_data ) )
    end

    if command == 'traits' or command == 't' then
        for _, trait_id in ipairs( windower.ffxi.get_abilities().job_traits ) do
            print( RES.job_traits[trait_id].en )
        end
    end
    
    if command == 'print' then
        table.vprint( PERSISTENT_DATA )
    end

    if command == 'hide' then
        if params[1] == 'dmg' then
            BASE_DMG_TEXT:hide()
        end
    end

    if command == 'show' then
        if params[1] == 'dmg' then
            BASE_DMG_TEXT:show()
        end
    end
end )
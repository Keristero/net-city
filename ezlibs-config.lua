--[[
    This lua file is a configuration for ezlibs
    We use SCREAMING_SNAKE_CASE to make it easier to distinguish configuration from code
--]]
local CONFIG = {
    --==Feature flags==--
    EZFARMS_ENABLED = false,
    EZCHRISTMAS_ENABLED = false,


    --==Global configs==--
    


    --==Plugin settings==--
    --ezencounters settings
    ENCOUNTERS_PATH = "encounters/",

    --eznpcs settings
    NPC_ASSET_FOLDER = '/server/assets/ezlibs-assets/eznpcs/',
    NPC_EVENTS_SCRIPT_PATH = 'scripts/events/eznpcs_events',

    --ezfarms settings
    FARM_MAP_ID = 'farm',--map ids are the file name by default
    FARM_TIMESCALE = 1.0, --1.0 is real time, 0.5 is double speed, 2.0 would be half speed

    --ezmemory settings
    PLAYERS_PATH = './memory/players',
    ITEMS_PATH = './memory/items',
    AREA_PATH_FOLDER = './memory/area/',
    PLAYER_PATH_FOLDER = './memory/player/'
}
return CONFIG
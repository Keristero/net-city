local helpers = require('scripts/ezlibs-scripts/helpers')
local ezmemory = require('scripts/ezlibs-scripts/ezmemory')
local HomePage = require("scripts/ezlibs-custom/HomePage")
local home_page_decorations = require("scripts/ezlibs-custom/home_page_decorations")
local loaded_homepages_by_safe_secret = {}
local loaded_homepages_by_area_id = {}

--TODO
--Dont use safe_secret for homepage area id, not safe :(
--Allocate player home page apartment warps (random?)
--Allow selection of tiles / 

local function get_homepage_of_player(player_id)
    local safe_secret = helpers.get_safe_player_secret(player_id)
    local player_memory = ezmemory.get_player_memory(safe_secret)
    if loaded_homepages_by_safe_secret[safe_secret] then
        return loaded_homepages_by_safe_secret[safe_secret]
    else
        local homepage = HomePage:new(player_id)
        loaded_homepages_by_safe_secret[safe_secret] = homepage
        loaded_homepages_by_area_id[homepage.area_id] = homepage
        if player_memory.home_page_data then
            homepage:Initialize_from_memory()
        else
            homepage:Initialize_from_template(home_page_decorations.base_homepage_map_id)
        end
        return homepage
    end
end

Net:on("player_request", function(event)
    if event.data == "" then
        local homepage = get_homepage_of_player(event.player_id)
        homepage:Transfer_player(event.player_id)
    end
end)

Net:on("tile_interaction", function(event)
    local area_id = Net.get_player_area(event.player_id)
    if loaded_homepages_by_area_id[area_id] then
        loaded_homepages_by_area_id[area_id]:Handle_tile_interaction(event)
    end
end)

Net:on("player_area_transfer",function (event)
    local area_id = Net.get_player_area(event.player_id)
    if loaded_homepages_by_area_id[area_id] then
        loaded_homepages_by_area_id[area_id]:Handle_player_area_transfer(event)
    end
end)

Net:on("player_disconnect",function (event)
    local area_id = Net.get_player_area(event.player_id)
    if loaded_homepages_by_area_id[area_id] then
        loaded_homepages_by_area_id[area_id]:Handle_player_disconnect(event)
    end
end)

Net:on("object_interaction", function(event)
    local area_id = Net.get_player_area(event.player_id)
    if loaded_homepages_by_area_id[area_id] then
        loaded_homepages_by_area_id[area_id]:Handle_object_interaction(event)
    end
end)

Net:on("tick", function(event)
    for _, homepage in pairs(loaded_homepages_by_area_id) do
        homepage:Handle_tick(event)
    end
end)

Net:on("custom_warp", function(event)
    local area_id = Net.get_player_area(event.player_id)
    if loaded_homepages_by_area_id[area_id] then
        loaded_homepages_by_area_id[area_id]:Handle_custom_warp(event)
    end
end)
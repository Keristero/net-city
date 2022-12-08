local helpers = require('scripts/ezlibs-scripts/helpers')
local ezmemory = require('scripts/ezlibs-scripts/ezmemory')
local HomePage = require("scripts/ezlibs-custom/HomePage")
local home_page_helpers = require("scripts/ezlibs-custom/home_page_helpers")

--TODO
--Dont use safe_secret for homepage area id, not safe :(
--Allocate player home page apartment warps (random?)

Net:on("player_request", function(event)
    home_page_helpers.transfer_player_to_correct_homepage(event.player_id,event.data)
end)

Net:on("tile_interaction", function(event)
    local area_id = Net.get_player_area(event.player_id)
    if home_page_helpers.loaded_homepages_by_area_id[area_id] then
        home_page_helpers.loaded_homepages_by_area_id[area_id]:Handle_tile_interaction(event)
    end
end)

Net:on("player_area_transfer",function (event)
    local area_id = Net.get_player_area(event.player_id)
    if home_page_helpers.loaded_homepages_by_area_id[area_id] then
        home_page_helpers.loaded_homepages_by_area_id[area_id]:Handle_player_area_transfer(event)
    end
end)

Net:on("player_disconnect",function (event)
    local area_id = Net.get_player_area(event.player_id)
    if home_page_helpers.loaded_homepages_by_area_id[area_id] then
        home_page_helpers.loaded_homepages_by_area_id[area_id]:Handle_player_disconnect(event)
    end
end)

Net:on("object_interaction", function(event)
    local area_id = Net.get_player_area(event.player_id)
    if home_page_helpers.loaded_homepages_by_area_id[area_id] then
        home_page_helpers.loaded_homepages_by_area_id[area_id]:Handle_object_interaction(event)
    end
end)

Net:on("tick", function(event)
    for _, homepage in pairs(home_page_helpers.loaded_homepages_by_area_id) do
        homepage:Handle_tick(event)
    end
end)

Net:on("custom_warp", function(event)
    local area_id = Net.get_player_area(event.player_id)
    if home_page_helpers.loaded_homepages_by_area_id[area_id] then
        home_page_helpers.loaded_homepages_by_area_id[area_id]:Handle_custom_warp(event)
    end
end)
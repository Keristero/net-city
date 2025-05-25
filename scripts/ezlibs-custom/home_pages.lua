local helpers = require('scripts/ezlibs-scripts/helpers')
local ezmemory = require('scripts/ezlibs-scripts/ezmemory')
local ezmenus = require('scripts/ezlibs-scripts/ezmenus')
local HomePage = require("scripts/ezlibs-custom/HomePage")
local home_page_helpers = require("scripts/ezlibs-custom/home_page_helpers")

local visit_menu_color = {r=100,g=150,b=120}

--TODO
--Dont use safe_secret for homepage area id, not safe :(
--Allocate player home page apartment warps (random?)

Net:on("player_request", function(event)
    local safe_secret = helpers.get_safe_player_secret(event.player_id)
    local player_name = Net.get_player_name(event.player_id)
    ezmemory.update_player_list(safe_secret,player_name)
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
    local object = Net.get_object_by_id(area_id,event.object_id)
    if object.class == "Homepage Warp" then
        home_page_helpers.transfer_player_to_correct_homepage(event.player_id,"FromNetCity")
        return
    end
    if home_page_helpers.loaded_homepages_by_area_id[area_id] then
        home_page_helpers.loaded_homepages_by_area_id[area_id]:Handle_object_interaction(event)
    end
end)

function visit_public_homepage(player_id)
    return async(function ()
        local bbs_options = {}
        --iterate over all public homepages
        for area_id, public_data in pairs(home_page_helpers.public_homepages_by_area_id) do
            local title = public_data.title
            local author = public_data.author
            local option = {id=area_id, title=title,read=true,author=author}
            table.insert(bbs_options, option)
        end
        --Open the menu and wait for a selection
        local menu = ezmenus.open_menu(player_id,"Visit",visit_menu_color,bbs_options)
        local post_id = await(menu.selection_once())
        if post_id == nil then
            return nil
        end
        await(menu.close_async())
        home_page_helpers.transfer_player_to_correct_homepage(player_id,post_id)
    end)
end

Net:on("object_interaction", function(event)
    local area_id = Net.get_player_area(event.player_id)
    local object = Net.get_object_by_id(area_id,event.object_id)
    if object.class == "Apartment Entry" then
        visit_public_homepage(event.player_id)
        return
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
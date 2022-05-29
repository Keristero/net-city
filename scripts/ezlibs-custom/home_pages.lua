local helpers = require('scripts/ezlibs-scripts/helpers')
local ezmemory = require('scripts/ezlibs-scripts/ezmemory')
local urlencode = require('scripts/ezlibs-scripts/urlencode')
local loaded_homepages = {}
local players_editing = {}
local base_homepage_map_id = 'base_homepage'
local net_city_map_id = 'default'
local test_net_city_homepage_exit_id = 2193
local hps = {}

--TODO
--Dont use safe_secret for homepage area id, not safe :(
--Allocate player home page apartment warps (random?)
--Allow selection of tiles / 

Net:on("player_request", function(event)
    local safe_secret = helpers.get_safe_player_secret(event.player_id)
    local player_memory = ezmemory.get_player_memory(safe_secret)
    local homepage_info = nil
    if player_memory.home_page_data then
        homepage_info = hps.create_home_page_instance(safe_secret,player_memory.home_page_data)
        print('loaded home page from memory')
    else
        homepage_info = hps.create_home_page_instance(safe_secret)
        local player_name_safe = urlencode.string(Net.get_player_name(event.player_id))
        local new_area_name = player_name_safe.." HP"
        Net.set_area_name(safe_secret,new_area_name)
        player_memory.home_page_data = Net.map_to_string(safe_secret)
        ezmemory.save_player_memory(safe_secret)
        print('generated new home page from base_homepage.tmx')
    end
    --transfer player to their homepage
    local x = homepage_info.home_warp_object.x+1
    local y = homepage_info.home_warp_object.y+1
    local z = homepage_info.home_warp_object.z
    local direction = homepage_info.home_warp_object.custom_properties.direction
    Net.transfer_player(event.player_id, safe_secret, true, x,y,z,direction)
end)

Net:on("tile_interaction", function(event)
    local safe_secret = helpers.get_safe_player_secret(event.player_id)
    local player_area = Net.get_player_area(event.player_id)
    local player_in_homepage = safe_secret == player_area
    if player_in_homepage then
        hps.open_hp_menu(event.player_id)
    end
end)

Net:on("custom_warp", function(event)
    -- { player_id: string, object_id: number }
    print(event.player_id, event.object_id)
    local player_area = Net.get_player_area(event.player_id)
    local object = Net.get_object_by_id(player_area,event.object_id)
    local hp_object_type = object.custom_properties["hp_object_type"]
    if hp_object_type == "home_warp" then
        Net.kick_player(event.player_id, "leaving", false)
    elseif hp_object_type == "city_warp" then
        --transfer player to their homepage
        local exit_object = Net.get_object_by_id(net_city_map_id,test_net_city_homepage_exit_id)
        local x = exit_object.x
        local y = exit_object.y
        local z = exit_object.z
        local direction = exit_object.custom_properties.direction
        Net.transfer_player(event.player_id, net_city_map_id, true, x,y,z,direction)
    end
end)

function hps.open_hp_menu(player_id)
    return async(function ()
        local res = await(Async.question_player(player_id, "Edit Homepage?"))
        if res == 1 then
            await(Async.message_player(player_id, "You are now in edit mode"))
        end
    end)
end

function hps.scan_homepage(home_page_id)
    local object_ids = Net.list_objects(home_page_id)
    local homepage_info = {
        home_warp_object=nil,
        city_warp_object=nil,
    }
    for index, object_id in ipairs(object_ids) do
        local object = Net.get_object_by_id(home_page_id, object_id)
        if object.custom_properties["hp_object_type"] then
            if object.custom_properties["hp_object_type"] == "home_warp" then
                homepage_info.home_warp_object = object
            end
            if object.custom_properties["hp_object_type"] == "city_warp" then
                homepage_info.city_warp_object = object
            end
        end
    end
    return homepage_info
end

function hps.create_home_page_instance(home_page_id,home_page_data)
    if loaded_homepages[home_page_id] then
        return loaded_homepages[home_page_id]
    end
    Net.clone_area(base_homepage_map_id, home_page_id)
    if home_page_data then
        Net.update_area(home_page_id, home_page_data)
    end
    local homepage_info = hps.scan_homepage(home_page_id)
    loaded_homepages[home_page_id] = homepage_info
    print('created homepage instance',homepage_info)
    return homepage_info
end
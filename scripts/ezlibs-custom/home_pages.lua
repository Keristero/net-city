local helpers = require('scripts/ezlibs-scripts/helpers')
local ezmemory = require('scripts/ezlibs-scripts/ezmemory')
local urlencode = require('scripts/ezlibs-scripts/urlencode')
local Direction = require("scripts/ezlibs-scripts/direction")
local loaded_homepages = {}
local players_editing = {}
local moving_info = {}
local base_homepage_map_id = 'base_homepage'
local net_city_map_id = 'default'
local test_net_city_homepage_exit_id = 2193
local hps = {}

--TODO
--Dont use safe_secret for homepage area id, not safe :(
--Allocate player home page apartment warps (random?)
--Allow selection of tiles / 

Net:on("player_request", function(event)
    local homepage_id = helpers.get_safe_player_secret(event.player_id)
    local homepage_info = hps.load_home_page(event.player_id,homepage_id)
    --transfer player to their homepage
    local x = homepage_info.home_warp_object.x+1
    local y = homepage_info.home_warp_object.y+1
    local z = homepage_info.home_warp_object.z
    local direction = homepage_info.home_warp_object.custom_properties.direction
    Net.transfer_player(event.player_id, homepage_id, true, x,y,z,direction)
end)

Net:on("tile_interaction", function(event)
    local safe_secret = helpers.get_safe_player_secret(event.player_id)
    local player_area = Net.get_player_area(event.player_id)
    local player_in_homepage = safe_secret == player_area
    local L_press = event.button == 1
    local A_press = event.button == 0
    if player_in_homepage and L_press then
        hps.open_hp_menu(event.player_id,player_area)
    end

    local player_moving_object = moving_info[event.player_id] ~= nil
    if A_press and player_moving_object then
        hps.finish_moving_object(event.player_id,player_area,event.object_id)
        moving_info[event.player_id] = nil
    end
end)

Net:on("player_area_transfer",function (event)
    local safe_secret = helpers.get_safe_player_secret(event.player_id)
    hps.cancel_editing(event.player_id,safe_secret)
end)

Net:on("player_disconnect",function (event)
    local safe_secret = helpers.get_safe_player_secret(event.player_id)
    hps.cancel_editing(event.player_id,safe_secret)
end)


Net:on("object_interaction", function(event)
    print(event.player_id, event.object_id, event.button)
    local player_area_id = Net.get_player_area(event.player_id)
    local A_press = event.button == 0
    local player_moving_object = moving_info[event.player_id] ~= nil
    if A_press and players_editing[event.player_id] then
        if not player_moving_object then
            local temp_object_id = hps.start_moving_object(event.player_id,player_area_id,event.object_id)
            moving_info[event.player_id] = {temp_object_id=temp_object_id, object_id=event.object_id}
        end
    end
end)

Net:on("tick", function(event)
    -- { delta_time: number (seconds) }
    for player_id, moving_object_info in pairs(moving_info) do
        local player_area_id = Net.get_player_area(player_id)
        local player_position = Net.get_player_position(player_id)
        local player_facing = Net.get_player_direction(player_id)
        local temp_object_id = moving_object_info.temp_object_id
        --local temp_object_info = Net.get_object_by_id(player_area_id,temp_object_id)
        local direction_offset = Direction.to_vector(player_facing)
        --local object_off_x = temp_object_info.width/2
        --local object_off_y = temp_object_info.height/2
        local new_x = player_position.x + direction_offset.x
        local new_y = player_position.y + direction_offset.y
        local new_z = player_position.z
        Net.move_object(player_area_id,temp_object_id,new_x,new_y,new_z)
    end
end)

Net:on("custom_warp", function(event)
    local player_editing = players_editing[event.player_id]
    -- { player_id: string, object_id: number }
    print(event.player_id, event.object_id)
    local player_area = Net.get_player_area(event.player_id)
    local object = Net.get_object_by_id(player_area,event.object_id)
    local hp_object_type = object.custom_properties["hp_object_type"]
    if hp_object_type == "home_warp" then
        Net.kick_player(event.player_id, "logging out", true)
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

function hps.open_hp_menu(player_id,home_page_id)
    return async(function ()
        local in_edit_mode = players_editing[player_id]
        if in_edit_mode then
            local res = await(Async.question_player(player_id, "Finish Editing?"))
            if res == 1 then
                hps.finish_editing(player_id,home_page_id)
                await(Async.message_player(player_id, "Finished editing"))
                local res = await(Async.question_player(player_id, "Save changes?"))
                local safe_secret = helpers.get_safe_player_secret(player_id)
                if res == 1 then
                    hps.save_home_page(player_id,safe_secret)
                else
                    hps.load_home_page(player_id,safe_secret,true)
                end
            end
        else
            local res = await(Async.question_player(player_id, "Edit Homepage?"))
            if res == 1 then
                hps.start_editing(player_id,home_page_id)
                await(Async.message_player(player_id, "You are now in edit mode"))
            end
        end
    end)
end

function hps.start_editing(player_id,home_page_id)
    players_editing[player_id] = true
    local home_page_info = loaded_homepages[home_page_id]
    Net.set_object_class(home_page_id, home_page_info.home_warp_object.id, "Disabled")
    Net.set_object_class(home_page_id, home_page_info.city_warp_object.id, "Disabled")
end

function hps.finish_editing(player_id,home_page_id)
    players_editing[player_id] = true
    local home_page_info = loaded_homepages[home_page_id]
    Net.set_object_class(home_page_id, home_page_info.home_warp_object.id, "Custom Warp")
    Net.set_object_class(home_page_id, home_page_info.city_warp_object.id, "Custom Warp")
end

function hps.cancel_editing(player_id,home_page_id)
    --finishes and discards changes
    hps.cancel_moving_object(player_id)
    players_editing[player_id] = nil
    hps.finish_editing(player_id,home_page_id)
    hps.load_home_page(player_id,home_page_id,true)
end

function hps.start_moving_object(player_id,area_id,object_id)
    local original_object_info = Net.get_object_by_id(area_id, object_id)
    print('started moving object')
    local temporary_object_id = Net.create_object(area_id, original_object_info)
    return temporary_object_id
end

function hps.cancel_moving_object(player_id)
    print('canceled moving object')
    if moving_info[player_id] then
        local temp_object_id = moving_info[player_id].temp_object_id
        local player_area_id = Net.get_player_area(player_id)
        Net.remove_object(player_area_id, temp_object_id)
        moving_info[player_id] = nil
    end
end

function hps.finish_moving_object(player_id,area_id)
    print('finished moving object')
    local temp_object_id = moving_info[player_id].temp_object_id
    local object_id = moving_info[player_id].object_id
    local temp_object_info = Net.get_object_by_id(area_id, temp_object_id)
    Net.remove_object(area_id, temp_object_id)
    Net.move_object(area_id,object_id,temp_object_info.x,temp_object_info.y,temp_object_info.z)
    moving_info[player_id] = nil
end

function hps.scan_homepage(home_page_id)
    --parses the homepage to extract all the key objects used
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

function hps.create_home_page_instance(home_page_id,home_page_data,force_reload)
    if loaded_homepages[home_page_id] and not force_reload then
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

function hps.save_home_page(player_id,home_page_id)
    local safe_secret = helpers.get_safe_player_secret(player_id)
    local player_memory = ezmemory.get_player_memory(safe_secret)
    player_memory.home_page_data = Net.map_to_string(home_page_id)
    ezmemory.save_player_memory(safe_secret)
    local homepage_info = hps.scan_homepage(home_page_id)
    loaded_homepages[home_page_id] = homepage_info
end

function hps.load_home_page(player_id,home_page_id,force_reload)
    local safe_secret = helpers.get_safe_player_secret(player_id)
    local player_memory = ezmemory.get_player_memory(safe_secret)
    local homepage_info = nil
    if player_memory.home_page_data then
        homepage_info = hps.create_home_page_instance(safe_secret,player_memory.home_page_data,force_reload)
        print('loaded home page from memory')
    else
        homepage_info = hps.create_home_page_instance(safe_secret)
        local player_name_safe = urlencode.string(Net.get_player_name(player_id))
        local new_area_name = player_name_safe.." HP"
        homepage_info.area_id = home_page_id
        Net.set_area_name(home_page_id,new_area_name)
        hps.save_home_page(safe_secret,home_page_id)
        print('generated new home page from base_homepage.tmx')
    end
    return homepage_info
end
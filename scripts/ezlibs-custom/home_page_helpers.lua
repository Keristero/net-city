--This script creates a list of decorations by loading the default map, then removing all the objects with names and saving their information.

local ezmemory = require('scripts/ezlibs-scripts/ezmemory')
local helpers = require('scripts/ezlibs-scripts/helpers')

local home_page_helpers = {}
home_page_helpers.base_homepage_map_id = 'base_homepage'
home_page_helpers.gid = {}
home_page_helpers.tiles = {}
home_page_helpers.objects = {}
home_page_helpers.name_to_gid = {}
home_page_helpers.loaded_homepages_by_safe_secret = {}
home_page_helpers.loaded_homepages_by_area_id = {}

local objects = {}

local function load_home_page_helpers()
    async(function ()
        --Janky work around to wait until area memory has been loaded by ezmemory
        await(Async.sleep(0.5))
        --Load page warps
        home_page_helpers.homepage_map_memory = ezmemory.get_area_memory(home_page_helpers.base_homepage_map_id)

        if not home_page_helpers.homepage_map_memory.warp_codes then
            home_page_helpers.homepage_map_memory.warp_codes = {}
            ezmemory.save_area_memory(home_page_helpers.base_homepage_map_id)
        end

        objects = Net.list_objects(home_page_helpers.base_homepage_map_id)
        for index, object_id in ipairs(objects) do
            local object = Net.get_object_by_id(home_page_helpers.base_homepage_map_id, object_id)
            local first_gid = home_page_helpers.get_objects_first_gid(object)
            if object.name ~= "" then
                local new_item_id = ezmemory.create_or_update_item(object.name,"",false)
                local decoration_info = {
                    gid= first_gid,
                    default_gid = object.data.gid,
                    name = object.name,
                    class = object.class,
                    custom_properties = object.custom_properties,
                    itemized_id = new_item_id,
                    width = object.width,
                    height = object.height
                }
                home_page_helpers.gid[first_gid] = decoration_info
                home_page_helpers.name_to_gid[object.name] = first_gid
                --also save the decorations to a list of tiles and objects
                if object.custom_properties.is_tile == "true" then
                    home_page_helpers.tiles[first_gid] = decoration_info
                    print("[home_page_decorations] Found tile decoration: " .. object.name.. " (" .. first_gid..")")
                else
                    home_page_helpers.objects[first_gid] = decoration_info
                    print("[home_page_decorations] Found object decoration: " .. object.name.. " (" .. first_gid..")")
                end
                Net.remove_object(home_page_helpers.base_homepage_map_id, object_id)
            end
        end
    end)
end

home_page_helpers.get_objects_first_gid = function(object)
    local tileset = Net.get_tileset_for_tile(home_page_helpers.base_homepage_map_id, object.data.gid)
    return tileset.first_gid
end

home_page_helpers.create_object_from_gid = function(area_id, object_gid, x, y, z)
    local decoration_info = home_page_helpers.gid[object_gid]
    local temporary_object_info = {
        name="",
        class=decoration_info.class,
        visible=true,
        x=x,
        y=y,
        z=z,
        width=decoration_info.width,
        height=decoration_info.height,
        rotation=0,
        data={
            type = "tile",
            gid = decoration_info.default_gid,
            flipped_horizontally = false,
            flipped_vertically = false,
            rotated = false
        },
        custom_properties = decoration_info.custom_properties
    }
    print(temporary_object_info)
    local temporary_object_id = Net.create_object(area_id, temporary_object_info)
    return temporary_object_id
end

home_page_helpers.get_homepage_of_player = function(player_id)
    local safe_secret = helpers.get_safe_player_secret(player_id)
    return home_page_helpers.get_homepage_by_safe_secret(safe_secret)
end

home_page_helpers.get_homepage_by_safe_secret = function(safe_secret)
    local player_memory = ezmemory.get_player_memory(safe_secret)
    if home_page_helpers.loaded_homepages_by_safe_secret[safe_secret] then
        return home_page_helpers.loaded_homepages_by_safe_secret[safe_secret]
    else
        local homepage = HomePage:new(safe_secret)
        home_page_helpers.loaded_homepages_by_safe_secret[safe_secret] = homepage
        home_page_helpers.loaded_homepages_by_area_id[homepage.area_id] = homepage
        if player_memory.home_page_data then
            homepage:Initialize_from_memory()
        else
            homepage:Initialize_from_template(home_page_helpers.base_homepage_map_id)
        end
        return homepage
    end
end

home_page_helpers.transfer_player_to_correct_homepage = function (player_id,request_data)
    if request_data == "" or request_data == nil then
        local homepage = home_page_helpers.get_homepage_of_player(player_id)
        homepage:Transfer_player(player_id)
    elseif request_data == "FromNetCity" then
        local homepage = home_page_helpers.get_homepage_of_player(player_id)
        homepage:Transfer_player(player_id,homepage.city_warp_object.id)
    elseif home_page_helpers.homepage_map_memory.warp_codes[request_data] then
        --TODO right now the area id IS safe secret, change this later
        local warp_code_info = home_page_helpers.homepage_map_memory.warp_codes[request_data]
        local homepage = home_page_helpers.get_homepage_by_safe_secret(warp_code_info.area_id)
        homepage:Transfer_player(player_id,warp_code_info.object_id)
    end
end

load_home_page_helpers()

return home_page_helpers
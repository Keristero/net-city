--This script creates a list of decorations by loading the default map, then removing all the objects with names and saving their information.

local ezmemory = require('scripts/ezlibs-scripts/ezmemory')
local home_page_decorations = {}
home_page_decorations.base_homepage_map_id = 'base_homepage'
home_page_decorations.gid = {}
home_page_decorations.tiles = {}
home_page_decorations.objects = {}
home_page_decorations.name_to_gid = {}

local objects = Net.list_objects(home_page_decorations.base_homepage_map_id)
for index, object_id in ipairs(objects) do
    local object = Net.get_object_by_id(home_page_decorations.base_homepage_map_id, object_id)
    if object.name ~= "" then
        local new_item_id = ezmemory.create_or_update_item(object.name,"",false)
        local decoration_info = {
            gid= object.data.gid,
            name = object.name,
            class = object.class,
            custom_properties = object.custom_properties,
            itemized_id = new_item_id,
            width = object.width,
            height = object.height
        }
        home_page_decorations.gid[object.data.gid] = decoration_info
        home_page_decorations.name_to_gid[object.name] = object.data.gid
        --also save the decorations to a list of tiles and objects
        if object.custom_properties.is_tile == "true" then
            home_page_decorations.tiles[object.data.gid] = decoration_info
            print("[home_page_decorations] Found tile decoration: " .. object.name.. " (" .. object.data.gid..")")
        else
            home_page_decorations.objects[object.data.gid] = decoration_info
            print("[home_page_decorations] Found object decoration: " .. object.name.. " (" .. object.data.gid..")")
        end
        Net.remove_object(home_page_decorations.base_homepage_map_id, object_id)
    end
end

home_page_decorations.create_object_from_gid = function(area_id, object_gid, x, y, z)
    local decoration_info = home_page_decorations.gid[object_gid]
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
            gid = object_gid,
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

return home_page_decorations
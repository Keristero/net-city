--This script creates a list of decorations by loading the default map, then removing all the objects with names and saving their information.

local ezmemory = require('scripts/ezlibs-scripts/ezmemory')
local home_page_decorations = {}
home_page_decorations.base_homepage_map_id = 'base_homepage'
home_page_decorations.gid = {}
home_page_decorations.tiles = {}
home_page_decorations.objects = {}

local objects = Net.list_objects(home_page_decorations.base_homepage_map_id)
for index, object_id in ipairs(objects) do
    local object = Net.get_object_by_id(home_page_decorations.base_homepage_map_id, object_id)
    if object.name ~= "" then
        local new_item_id = ezmemory.create_or_update_item(object.name,"",false)
        local decoration_info = {
            name = object.name,
            class = object.class,
            custom_properties = object.custom_properties,
            itemized_id = new_item_id
        }
        home_page_decorations.gid[object.data.gid] = decoration_info
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

return home_page_decorations
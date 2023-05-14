local home_page_helpers = require("scripts/ezlibs-custom/home_page_helpers")
local ezmemory = require('scripts/ezlibs-scripts/ezmemory')

local function create_operation(hp)
    return {
        name="inspect object",
        tic_func=function()
            return nil
        end,
        tile_interact_func=function()
            return nil
        end,
        object_interact_func=function(event)
            local A_press = event.button == 0
            if A_press then
                local object = Net.get_object_by_id(hp.area_id,event.object_id)
                local first_gid = home_page_helpers.get_objects_first_gid(object)
                local decoration_info = home_page_helpers.gid[first_gid]
                if decoration_info then
                    hp:List_object_properties_to_player(event.object_id)
                end
            end
        end,
        cancel_func=function()
            return nil
        end
    }
end

return create_operation
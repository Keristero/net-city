local home_page_decorations = require("scripts/ezlibs-custom/home_page_decorations")
local ezmemory = require('scripts/ezlibs-scripts/ezmemory')

local function create_operation(hp)
    return {
        name="store object",
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
                local decoration_info = home_page_decorations.gid[object.data.gid]
                if decoration_info then
                    Net.remove_object(hp.area_id, event.object_id)
                    local new_item_count = ezmemory.give_player_item(event.player_id, decoration_info.name, 1)
                    print('DEBUG the player now has '..new_item_count)
                end
            end
        end,
        cancel_func=function()
            return nil
        end
    }
end

return create_operation
local create_moving_operation = require('scripts/ezlibs-custom/homepage_operations/moving')

local function create_operation(hp)
    return {
        name="move selection",
        tic_func=function()
            return nil
        end,
        tile_interact_func=function()
            return nil
        end,
        object_interact_func=function(event)
            local A_press = event.button == 0
            if A_press then
                hp:Set_current_operation(create_moving_operation(hp, hp.area_id,event.object_id))
            end
        end,
        cancel_func=function()
            return nil
        end
    }
end

return create_operation
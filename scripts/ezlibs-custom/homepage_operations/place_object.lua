local home_page_decorations = require("scripts/ezlibs-custom/home_page_decorations")
local ezmemory = require('scripts/ezlibs-scripts/ezmemory')

local function create_operation(hp)
    --TODO pop up a menu here with the list of objects in the player's storage that they can place, this operation will become an operation for placing that object until it is depleted
    return {
        name="store object",
        tic_func=function()
            return nil
        end,
        tile_interact_func=function(event)
            local A_press = event.button == 0
            if A_press then
                --Place the object
            end
        end,
        object_interact_func=function(event)
            return nil
        end,
        cancel_func=function()
            return nil
        end
    }
end

return create_operation
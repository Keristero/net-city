local home_page_decorations = require("scripts/ezlibs-custom/home_page_decorations")
local ezmemory = require('scripts/ezlibs-scripts/ezmemory')
local helpers = require('scripts/ezlibs-scripts/helpers')
local Direction = require("scripts/ezlibs-scripts/direction")

local function create_operation(hp,decoration_info)
    --TODO pop up a menu here with the list of objects in the player's storage that they can place, this operation will become an operation for placing that object until it is depleted
    local temporary_object_id = home_page_decorations.create_object_from_gid(hp.area_id, decoration_info.gid, 0,0,0)

    local function finish_placing()
        local temp_object_info = Net.get_object_by_id(hp.area_id, temporary_object_id)
        local new_object_id = Net.create_object(hp.area_id, temp_object_info)
        Net.remove_object(hp.area_id, temporary_object_id)
        print('finished placing object')
        ezmemory.remove_player_item(hp.editor_id, decoration_info.name, 1)
        local object_count = ezmemory.count_player_item(hp.editor_id, decoration_info.name)
        local next_operation = nil
        if object_count > 0 then
            --if the player still has more of this item, repeat the place operation
            next_operation = create_operation(hp,decoration_info)
        end
        hp:Set_current_operation(next_operation)
    end

    return {
        name="place object",
        tic_func=function()
            if not temporary_object_id then
                return
            end
            local player_position = Net.get_player_position(hp.editor_id)
            local player_facing = Net.get_player_direction(hp.editor_id)
            local direction_offset = Direction.to_vector(player_facing)
            local new_x = player_position.x + direction_offset.x
            local new_y = player_position.y + direction_offset.y
            local new_z = player_position.z
            Net.move_object(hp.area_id,temporary_object_id,new_x,new_y,new_z)
        end,
        tile_interact_func=function(event)
            local A_press = event.button == 0
            if A_press then
                finish_placing()
            end
        end,
        object_interact_func=function(event)
            local A_press = event.button == 0
            if A_press then
                finish_placing()
            end
        end,
        cancel_func=function()
            if temporary_object_id then
                Net.remove_object(hp.area_id, temporary_object_id)
            end
        end
    }
end

return create_operation